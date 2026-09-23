//go:build xrayinterop && linux

package main

import (
	"context"
	"encoding/json"
	"fmt"
	"net"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"strings"
	"testing"
	"time"

	"github.com/metacubex/mihomo/adapter"
	C "github.com/metacubex/mihomo/constant"
)

func xrayDesktopTransfer(t *testing.T, proxyMap map[string]any, destination *C.Metadata) error {
	t.Helper()
	binary, err := filepath.Abs(os.Getenv("FLCLASH_INTEROP_CORE"))
	if err != nil {
		t.Fatal(err)
	}
	home := t.TempDir()
	socket := filepath.Join(home, "ipc.sock")
	listener, err := net.ListenUnix("unix", &net.UnixAddr{Name: socket, Net: "unix"})
	if err != nil {
		t.Fatal(err)
	}
	defer listener.Close()
	listener.SetDeadline(time.Now().Add(10 * time.Second))
	output, err := os.Create(filepath.Join(home, "core.log"))
	if err != nil {
		t.Fatal(err)
	}
	ctx, cancel := context.WithTimeout(context.Background(), 90*time.Second)
	command := exec.CommandContext(ctx, binary, socket)
	command.Stdout, command.Stderr = output, output
	if err := command.Start(); err != nil {
		cancel()
		output.Close()
		t.Fatal(err)
	}
	done := make(chan error, 1)
	go func() { done <- command.Wait() }()
	t.Cleanup(func() {
		cancel()
		select {
		case <-done:
		case <-time.After(5 * time.Second):
			t.Error("desktop Core failed to exit")
		}
		output.Close()
		if t.Failed() {
			data, _ := os.ReadFile(output.Name())
			t.Log(string(data))
		}
	})
	conn, err := listener.AcceptUnix()
	if err != nil {
		t.Fatal(err)
	}
	defer conn.Close()
	sequence := 0
	call := func(method string, args any) (json.RawMessage, *MethodError) {
		sequence++
		id := strconv.Itoa(sequence)
		request, err := json.Marshal(map[string]any{"id": id, "method": method, "arguments": args})
		if err != nil {
			t.Fatal(err)
		}
		conn.SetDeadline(time.Now().Add(15 * time.Second))
		if _, err := writeFrame(conn, request); err != nil {
			t.Fatal(err)
		}
		for {
			data, err := readFrame(conn)
			if err != nil {
				t.Fatal(err)
			}
			var response struct {
				ID     string          `json:"id"`
				Result json.RawMessage `json:"result"`
				Error  *MethodError    `json:"error"`
			}
			if err := json.Unmarshal(data, &response); err != nil {
				t.Fatal(err)
			}
			if response.ID == id {
				return response.Result, response.Error
			}
		}
	}
	mustCall := func(method string, args any) json.RawMessage {
		result, failure := call(method, args)
		if failure != nil {
			t.Fatalf("%s: %+v", method, failure)
		}
		return result
	}
	mustCall("initClash", map[string]any{"home-dir": home, "version": 1})
	port := xrayPort(t)
	stage := func(generation string, profile any) {
		dir := filepath.Join(home, "profiles", "generations", generation)
		if err := os.MkdirAll(dir, 0o700); err != nil {
			t.Fatal(err)
		}
		data, err := json.Marshal(profile)
		if err != nil {
			t.Fatal(err)
		}
		if err := os.WriteFile(filepath.Join(dir, "effective.yaml"), data, 0o600); err != nil {
			t.Fatal(err)
		}
	}
	generation := "11111111111111111111111111111111"
	stage(generation, map[string]any{"proxies": []any{proxyMap}, "rules": []string{"MATCH,interop"}, "mode": "rule", "mixed-port": port, "log-level": "warning"})
	result := mustCall("prepareConfig", map[string]any{"generation": generation, "revision": 1})
	var prepared PreparedConfigResult
	if err := json.Unmarshal(result, &prepared); err != nil {
		t.Fatal(err)
	}
	mustCall("activateConfig", map[string]any{"prepared": map[string]any{"handle": prepared.Handle, "revision": 1}, "setup": map[string]any{"generation": generation, "revision": 1}})
	if string(mustCall("startListener", nil)) != "true" {
		t.Fatal("desktop Core did not start its listener")
	}
	socks, err := adapter.ParseProxy(map[string]any{"name": "native", "type": "socks5", "server": "127.0.0.1", "port": port})
	if err != nil {
		t.Fatal(err)
	}
	defer socks.Close()
	if err := xrayTransfer(socks, destination); err != nil {
		return err
	}
	rejected := "22222222222222222222222222222222"
	stage(rejected, map[string]any{"proxies": []any{map[string]any{"name": "invalid", "type": "vless", "server": "127.0.0.1", "port": 443, "uuid": xrayTestUUID, "tls": true, "reality-opts": map[string]any{"public-key": "malformed"}}}})
	if _, failure := call("prepareConfig", map[string]any{"generation": rejected, "revision": 2}); failure == nil {
		t.Fatal("native Core accepted invalid replacement")
	}
	if err := xrayTransfer(socks, destination); err != nil {
		return fmt.Errorf("working profile lost after rejection: %w", err)
	}
	mustCall("stopListener", nil)
	if stopped, err := net.DialTimeout("tcp", net.JoinHostPort("127.0.0.1", strconv.Itoa(port)), time.Second); err == nil {
		stopped.Close()
		t.Fatal("stopped Core retained its listener")
	}
	if string(mustCall("startListener", nil)) != "true" {
		t.Fatal("desktop Core did not restart its listener")
	}
	if err := xrayTransfer(socks, destination); err != nil {
		return err
	}
	mustCall("shutdown", nil)
	return nil
}

func TestXrayNativeCore(t *testing.T) {
	if os.Getenv("FLCLASH_INTEROP_CORE") == "" {
		t.Skip("set FLCLASH_INTEROP_CORE to the built Linux Core for native IPC/profile smoke tests")
	}
	for _, version := range strings.Split(os.Getenv("XRAY_INTEROP_VERSIONS"), ",") {
		if version != "26.3.27" && version != "26.9.9" {
			continue
		}
		for _, network := range []string{"tcp", "xhttp"} {
			t.Run(version+"/"+network, func(t *testing.T) {
				if err := xrayReality(t, version, xrayCase{network: network, minimum: "26.3.27", desktop: true}); err != nil {
					t.Fatal(err)
				}
			})
		}
	}
}
