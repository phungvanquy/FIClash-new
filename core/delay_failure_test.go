package main

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"net"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/metacubex/mihomo/constant"
	"github.com/metacubex/mihomo/tunnel"
)

func TestNodeLatencyOverRealLoopbackProbes(t *testing.T) {
	tunnel.UpdateProxies(map[string]constant.Proxy{"probe": namedProxy("probe")}, nil)
	t.Cleanup(func() { tunnel.UpdateProxies(nil, nil); settleMessageBatcher() })
	for _, latency := range []time.Duration{0, 80 * time.Millisecond} {
		t.Run(latency.String(), func(t *testing.T) {
			server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
				time.Sleep(latency)
				w.WriteHeader(http.StatusNoContent)
			}))
			defer server.Close()
			result := handleTestDelay(&TestDelayParams{ProxyName: "probe", TestUrl: server.URL, Timeout: 2000})
			if result == nil || result.Failure != "" || result.Value < 1 {
				t.Fatalf("successful probe = %+v", result)
			}
			if result.Value < int32(latency.Milliseconds()) {
				t.Fatalf("slow probe = %d, want >= %d", result.Value, latency.Milliseconds())
			}
		})
	}
	blackHole := blackHoleServer(t)
	timeout := handleTestDelay(&TestDelayParams{ProxyName: "probe", TestUrl: "http://" + blackHole.String(), Timeout: 40})
	if timeout == nil || timeout.Failure != "timeout" || timeout.Value != -1 {
		t.Fatalf("timeout probe = %+v", timeout)
	}
	listener, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatal(err)
	}
	address := listener.Addr().String()
	listener.Close()
	unreachable := handleTestDelay(&TestDelayParams{ProxyName: "probe", TestUrl: "http://" + address, Timeout: 1000})
	if unreachable == nil || unreachable.Failure != "unreachable" {
		t.Fatalf("unreachable probe = %+v", unreachable)
	}
}

func TestDelayFailureClassification(t *testing.T) {
	for _, value := range []string{"", "not a URL", "file:///tmp/config", "https:///missing-host"} {
		if validDelayTestURL(value) {
			t.Fatalf("accepted invalid probe URL %q", value)
		}
	}
	if !validDelayTestURL("https://probe.test/check?code=abc") {
		t.Fatal("rejected HTTP probe URL")
	}
	for _, tc := range []struct {
		name string
		err  error
		want string
	}{
		{"deadline", context.DeadlineExceeded, "timeout"},
		{"wrapped deadline", fmt.Errorf("probe: %w", context.DeadlineExceeded), "timeout"},
		{"network timeout", &net.DNSError{IsTimeout: true}, "timeout"},
		{"offline", &net.DNSError{IsNotFound: true}, "unreachable"},
		{"refused", errors.New("connection refused"), "unreachable"},
		{"cancelled", context.Canceled, "test_failed"},
	} {
		t.Run(tc.name, func(t *testing.T) {
			if got := delayFailure(context.Background(), tc.err); got != tc.want {
				t.Fatalf("got %q, want %q", got, tc.want)
			}
		})
	}
	ctx, cancel := context.WithDeadline(context.Background(), time.Now().Add(-time.Second))
	defer cancel()
	if got := delayFailure(ctx, errors.New("closed")); got != "timeout" {
		t.Fatalf("expired probe reported %q", got)
	}
}

func TestDelayFailureWireCompatibility(t *testing.T) {
	data, err := json.Marshal(Delay{Name: "node", Url: "https://probe.test", Value: -1, Failure: "timeout"})
	if err != nil {
		t.Fatal(err)
	}
	if string(data) != `{"url":"https://probe.test","name":"node","value":-1,"failure":"timeout"}` {
		t.Fatal(string(data))
	}
	data, err = json.Marshal(Delay{Name: "node", Url: "https://probe.test", Value: 20})
	if err != nil {
		t.Fatal(err)
	}
	var fields map[string]any
	if err := json.Unmarshal(data, &fields); err != nil {
		t.Fatal(err)
	}
	if _, exists := fields["failure"]; exists {
		t.Fatal("success acquired a failure field")
	}
}
