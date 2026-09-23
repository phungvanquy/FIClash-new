//go:build xrayinterop

package main

import (
	"bytes"
	"context"
	"crypto/ecdh"
	"crypto/ecdsa"
	"crypto/elliptic"
	"crypto/rand"
	"crypto/tls"
	"crypto/x509"
	"crypto/x509/pkix"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"math/big"
	"net"
	"net/http"
	"net/http/httptest"
	"net/netip"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"strings"
	"testing"
	"time"

	"github.com/cloudflare/circl/sign/mldsa/mldsa65"
	"github.com/metacubex/mihomo/adapter"
	"github.com/metacubex/mihomo/component/resolver"
	C "github.com/metacubex/mihomo/constant"
)

const xrayTestUUID = "6a9ecf20-44b2-4fc2-a3a0-4dcda7b2c3eb"

type xrayCase struct {
	desktop      bool
	download     bool
	badDownload  bool
	name         string
	minimum      string
	maximum      string
	network      string
	fingerprint  string
	legacy       bool
	modern       bool
	wrongKey     bool
	wantFailure  bool
	wrongSNI     bool
	wrongShortID bool
	mldsa        string
	mode         string
	ipv6         bool
}

func xrayBinary(t *testing.T, version string) string {
	t.Helper()
	directory := os.Getenv("XRAY_INTEROP_DIR")
	if directory == "" {
		t.Fatal("XRAY_INTEROP_DIR is required; run python3 tool/xray_interop.py")
	}
	binary := filepath.Join(directory, version, "xray")
	if _, err := os.Stat(binary); err != nil {
		t.Fatal(err)
	}
	return binary
}

func xrayStart(t *testing.T, binary string, config map[string]any, address string) {
	t.Helper()
	dir := t.TempDir()
	encoded, err := json.Marshal(config)
	if err != nil {
		t.Fatal(err)
	}
	path := filepath.Join(dir, "config.json")
	if err := os.WriteFile(path, encoded, 0o600); err != nil {
		t.Fatal(err)
	}
	output, err := os.Create(filepath.Join(dir, "xray.log"))
	if err != nil {
		t.Fatal(err)
	}
	ctx, cancel := context.WithTimeout(context.Background(), 45*time.Second)
	command := exec.CommandContext(ctx, binary, "run", "-config", path)
	command.Stdout, command.Stderr = output, output
	if len(config["inbounds"].([]any)) > 1 {
		// The fixture's raw REALITY front doors must keep TLS framing during relay.
		command.Env = append(os.Environ(), "xray.buf.splice=disable")
	}
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
			t.Error("Xray did not exit after cancellation")
		}
		output.Close()
		if t.Failed() {
			data, _ := os.ReadFile(output.Name())
			t.Log(string(data))
		}
	})
	deadline := time.Now().Add(5 * time.Second)
	for time.Now().Before(deadline) {
		conn, err := net.DialTimeout("tcp", address, 100*time.Millisecond)
		if err == nil {
			conn.Close()
			return
		}
		time.Sleep(20 * time.Millisecond)
	}
	t.Fatal("Xray did not become ready")
}

func xrayPort(t *testing.T) int {
	t.Helper()
	listener, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatal(err)
	}
	port := listener.Addr().(*net.TCPAddr).Port
	listener.Close()
	return port
}

func xrayEcho(t *testing.T) *C.Metadata {
	t.Helper()
	listener, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { listener.Close() })
	go func() {
		for {
			conn, err := listener.Accept()
			if err != nil {
				return
			}
			go func() {
				defer conn.Close()
				conn.SetDeadline(time.Now().Add(30 * time.Second))
				io.Copy(conn, conn)
			}()
		}
	}()
	return &C.Metadata{NetWork: C.TCP, Type: C.INNER, DstIP: netip.MustParseAddr("127.0.0.1"), DstPort: uint16(listener.Addr().(*net.TCPAddr).Port)}
}

func xrayTransfer(proxy C.Proxy, destination *C.Metadata) error {
	ctx, cancel := context.WithTimeout(context.Background(), 20*time.Second)
	defer cancel()
	conn, err := proxy.DialContext(ctx, destination)
	if err != nil {
		return err
	}
	defer conn.Close()
	if err := conn.SetDeadline(time.Now().Add(20 * time.Second)); err != nil {
		return err
	}
	payload := make([]byte, 2048)
	if _, err := rand.Read(payload); err != nil {
		return err
	}
	if _, err := conn.Write(payload); err != nil {
		return err
	}
	response := make([]byte, len(payload))
	if _, err := io.ReadFull(conn, response); err != nil {
		return err
	}
	if !bytes.Equal(payload, response) {
		return fmt.Errorf("proxy response does not match echo payload")
	}
	return nil
}

func xrayReality(t *testing.T, version string, item xrayCase) error {
	t.Helper()
	target := httptest.NewUnstartedServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Write([]byte("REALITY fallback is not an echo destination"))
	}))
	target.EnableHTTP2 = true
	target.Config.ErrorLog = log.New(io.Discard, "", 0)
	target.TLS = &tls.Config{MinVersion: tls.VersionTLS13}
	// REALITY needs a target certificate record large enough for its ML-DSA signature.
	if item.mldsa != "" {
		private, err := ecdsa.GenerateKey(elliptic.P256(), rand.Reader)
		if err != nil {
			t.Fatal(err)
		}
		template := &x509.Certificate{SerialNumber: big.NewInt(1), DNSNames: []string{"example.test"}, NotBefore: time.Now().Add(-time.Hour), NotAfter: time.Now().Add(time.Hour), ExtraExtensions: []pkix.Extension{{Id: []int{1, 3, 6, 1, 4, 1, 55555, 1}, Value: make([]byte, 4096)}}}
		der, err := x509.CreateCertificate(rand.Reader, template, template, &private.PublicKey, private)
		if err != nil {
			t.Fatal(err)
		}
		target.TLS.Certificates = []tls.Certificate{{Certificate: [][]byte{der}, PrivateKey: private}}
	}
	target.StartTLS()
	t.Cleanup(target.Close)
	key, err := ecdh.X25519().GenerateKey(rand.Reader)
	if err != nil {
		t.Fatal(err)
	}
	host := "127.0.0.1"
	if item.ipv6 {
		previous := resolver.DisableIPv6
		resolver.DisableIPv6 = false
		t.Cleanup(func() { resolver.DisableIPv6 = previous })
		host = "::1"
	}
	port := xrayPort(t)
	reality := map[string]any{
		"dest": target.Listener.Addr().String(), "serverNames": []string{"example.test"},
		"privateKey": base64.RawURLEncoding.EncodeToString(key.Bytes()), "shortIds": []string{"aabb"},
	}
	if item.minimum != "" {
		reality["minClientVer"] = item.minimum
	}
	if item.maximum != "" {
		reality["maxClientVer"] = item.maximum
	}
	network := item.network
	if network == "" {
		network = "tcp"
	}
	client := map[string]any{"id": xrayTestUUID}
	stream := map[string]any{"network": network, "security": "reality", "realitySettings": reality}
	proxyMap := map[string]any{
		"name": "interop", "type": "vless", "server": host, "port": port,
		"uuid": xrayTestUUID, "tls": true, "servername": "example.test",
		"client-fingerprint": "chrome", "network": network,
	}
	if network == "tcp" {
		client["flow"] = "xtls-rprx-vision"
		proxyMap["flow"] = "xtls-rprx-vision"
	} else {
		stream["xhttpSettings"] = map[string]any{"path": "/interop", "mode": "auto"}
		proxyMap["xhttp-opts"] = map[string]any{"path": "/interop", "mode": "auto"}
	}
	if item.mode != "" {
		proxyMap["xhttp-opts"].(map[string]any)["mode"] = item.mode
	}
	if item.ipv6 {
		delete(proxyMap, "servername")
		reality["serverNames"] = []string{""}
	}
	if item.wrongSNI {
		proxyMap["servername"] = "wrong.test"
	}
	if item.fingerprint == "default" {
		delete(proxyMap, "client-fingerprint")
	} else if item.fingerprint != "" {
		proxyMap["client-fingerprint"] = item.fingerprint
	}
	publicKey := key.PublicKey().Bytes()
	if item.wrongKey {
		wrong, _ := ecdh.X25519().GenerateKey(rand.Reader)
		publicKey = wrong.PublicKey().Bytes()
	}
	opts := map[string]any{"public-key": base64.RawURLEncoding.EncodeToString(publicKey), "short-id": "aabb"}
	if item.legacy {
		opts["support-x25519mlkem768"] = false
	} else if item.modern {
		opts["support-x25519mlkem768"] = true
	}
	if item.wrongShortID {
		opts["short-id"] = "ccdd"
	}
	if item.mldsa != "" {
		var seed [mldsa65.SeedSize]byte
		rand.Read(seed[:])
		if item.mldsa != "absent" {
			reality["mldsa65Seed"] = base64.RawURLEncoding.EncodeToString(seed[:])
		}
		if item.mldsa == "wrong" {
			seed[0] ^= 1
		}
		public, _ := mldsa65.NewKeyFromSeed(&seed)
		encoded, _ := public.MarshalBinary()
		if item.mldsa != "omitted" {
			opts["mldsa65-verify"] = base64.RawURLEncoding.EncodeToString(encoded)
		}
		if item.mldsa == "malformed" {
			opts["mldsa65-verify"] = "YQ"
		}
	}
	proxyMap["reality-opts"] = opts
	config := map[string]any{
		"log": map[string]any{"loglevel": "debug"},
		"inbounds": []any{map[string]any{
			"listen": host, "port": port, "protocol": "vless",
			"settings": map[string]any{"clients": []any{client}, "decryption": "none"}, "streamSettings": stream,
		}},
		"outbounds": []any{xrayFreedom(version)},
	}
	if item.download || item.ipv6 {
		xrayIndependentDownload(t, config, proxyMap, target.Listener.Addr().String(), item.badDownload)
	}
	xrayStart(t, xrayBinary(t, version), config, net.JoinHostPort(host, strconv.Itoa(port)))
	if item.desktop {
		return xrayDesktopTransfer(t, proxyMap, xrayEcho(t))
	}
	proxy, err := adapter.ParseProxy(proxyMap)
	if err != nil {
		return err
	}
	defer proxy.Close()
	return xrayTransfer(proxy, xrayEcho(t))
}

func xrayFreedom(version string) map[string]any {
	outbound := map[string]any{"protocol": "freedom"}
	if version != "26.3.27" && version != "1.8.24" {
		outbound["settings"] = map[string]any{"finalRules": []any{map[string]any{"action": "allow", "ip": []string{"127.0.0.0/8", "::1/128"}}}}
	}
	return outbound
}

func TestXrayReality(t *testing.T) {
	versions := strings.Split(os.Getenv("XRAY_INTEROP_VERSIONS"), ",")
	if versions[0] == "" {
		t.Fatal("XRAY_INTEROP_VERSIONS is required")
	}
	baseline := os.Getenv("XRAY_INTEROP_BASELINE") == "1"
	for _, version := range versions {
		cases := []xrayCase{{name: "default"}}
		if version == "1.8.24" {
			cases = []xrayCase{{name: "legacy", legacy: true, fingerprint: "chrome120"}}
		} else {
			cases = append(cases, xrayCase{name: "minimum", minimum: "26.3.27"}, xrayCase{name: "xhttp", network: "xhttp"})
		}
		if !baseline && version != "1.8.24" {
			cases = append(cases,
				xrayCase{name: "xhttp-minimum", minimum: "26.3.27", network: "xhttp"},
				xrayCase{name: "maximum-accepted", maximum: "26.3.27"},
				xrayCase{name: "minimum-rejected", minimum: "26.3.28", wantFailure: true},
				xrayCase{name: "maximum-rejected", maximum: "26.3.26", wantFailure: true},
				xrayCase{name: "wrong-key", wrongKey: true, wantFailure: true},
				xrayCase{name: "wrong-short-id", wrongShortID: true, wantFailure: true},
				xrayCase{name: "wrong-sni", wrongSNI: true, wantFailure: true},
				xrayCase{name: "explicit-modern", modern: true},
				xrayCase{name: "old-fingerprint", fingerprint: "chrome120", wantFailure: true},
			)
			for _, fp := range []string{"default", "firefox", "safari", "random"} {
				cases = append(cases, xrayCase{name: "fingerprint-" + fp, fingerprint: fp})
			}
			if version == "26.3.27" || version == "26.9.9" {
				for _, mode := range []string{"packet-up", "stream-up", "stream-one"} {
					cases = append(cases, xrayCase{name: "xhttp-" + mode, network: "xhttp", mode: mode})
				}
				cases = append(cases, xrayCase{name: "xhttp-ipv6", network: "xhttp", mode: "packet-up", ipv6: true},
					xrayCase{name: "xhttp-independent-download", network: "xhttp", mode: "packet-up", download: true},
					xrayCase{name: "xhttp-invalid-download", network: "xhttp", mode: "packet-up", download: true, badDownload: true, wantFailure: true})
				for _, verification := range []string{"valid", "wrong", "absent", "omitted", "malformed"} {
					cases = append(cases, xrayCase{name: "mldsa-" + verification, mldsa: verification, wantFailure: verification != "valid" && verification != "omitted"})
				}
			}
			if strings.HasPrefix(version, "26.9") {
				cases = append(cases, xrayCase{name: "legacy-rejected", legacy: true, wantFailure: true})
			}
		}
		for _, item := range cases {
			t.Run(version+"/"+item.name, func(t *testing.T) {
				err := xrayReality(t, version, item)
				if baseline {
					t.Logf("BASELINE version=%s case=%s success=%t error=%v", version, item.name, err == nil, err)
					return
				}
				if item.wantFailure {
					if err == nil {
						t.Fatal("expected authentication failure")
					}
				} else if err != nil {
					t.Fatal(err)
				}
			})
		}
	}
}
