//go:build xrayinterop

package main

import (
	"bytes"
	"context"
	"crypto/sha256"
	"crypto/x509"
	"encoding/base64"
	"encoding/hex"
	"encoding/pem"
	"fmt"
	"net"
	"net/http/httptest"
	"net/netip"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"testing"
	"time"

	"github.com/metacubex/mihomo/adapter"
	C "github.com/metacubex/mihomo/constant"
	"github.com/metacubex/mlkem"
)

func xrayCertificate(t *testing.T) (map[string]any, string) {
	t.Helper()
	server := httptest.NewTLSServer(nil)
	defer server.Close()
	certificate := server.TLS.Certificates[0]
	key, err := x509.MarshalPKCS8PrivateKey(certificate.PrivateKey)
	if err != nil {
		t.Fatal(err)
	}
	dir := t.TempDir()
	certPath, keyPath := filepath.Join(dir, "certificate.pem"), filepath.Join(dir, "key.pem")
	if err := os.WriteFile(certPath, pem.EncodeToMemory(&pem.Block{Type: "CERTIFICATE", Bytes: certificate.Certificate[0]}), 0o600); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(keyPath, pem.EncodeToMemory(&pem.Block{Type: "PRIVATE KEY", Bytes: key}), 0o600); err != nil {
		t.Fatal(err)
	}
	hash := sha256.Sum256(certificate.Certificate[0])
	return map[string]any{"certificates": []any{map[string]any{"certificateFile": certPath, "keyFile": keyPath}}}, hex.EncodeToString(hash[:])
}

func xrayUDPTransfer(t *testing.T, proxy C.Proxy) error {
	t.Helper()
	listener, err := net.ListenPacket("udp", "127.0.0.1:0")
	if err != nil {
		t.Fatal(err)
	}
	defer listener.Close()
	go func() {
		buffer := make([]byte, 4096)
		for {
			n, addr, err := listener.ReadFrom(buffer)
			if err != nil {
				return
			}
			listener.WriteTo(buffer[:n], addr)
		}
	}()
	addr := listener.LocalAddr().(*net.UDPAddr)
	destination := &C.Metadata{NetWork: C.UDP, Type: C.INNER, DstIP: netip.MustParseAddr("127.0.0.1"), DstPort: uint16(addr.Port)}
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	conn, err := proxy.ListenPacketContext(ctx, destination)
	if err != nil {
		return err
	}
	defer conn.Close()
	conn.SetDeadline(time.Now().Add(10 * time.Second))
	payload := []byte("xudp authenticated datagram")
	if _, err := conn.WriteTo(payload, addr); err != nil {
		return err
	}
	buffer := make([]byte, 4096)
	n, _, err := conn.ReadFrom(buffer)
	if err != nil {
		return err
	}
	if !bytes.Equal(buffer[:n], payload) {
		return fmt.Errorf("datagram payload mismatch")
	}
	return nil
}

func xrayTransport(t *testing.T, version, protocol, network, encryption, rtt string, udp bool) {
	t.Helper()
	port := xrayPort(t)
	client := map[string]any{"id": xrayTestUUID}
	settings := map[string]any{"clients": []any{client}}
	stream := map[string]any{"network": network, "security": "tls"}
	tlsSettings, fingerprint := xrayCertificate(t)
	stream["tlsSettings"] = tlsSettings
	proxyMap := map[string]any{"name": "transport", "type": protocol, "server": "127.0.0.1", "port": port, "uuid": xrayTestUUID, "tls": true, "servername": "example.com", "fingerprint": fingerprint, "network": network, "udp": true}
	switch protocol {
	case "vless":
		settings["decryption"] = "none"
	case "vmess":
		proxyMap["cipher"] = "auto"
		proxyMap["alterId"] = 0
	case "trojan":
		client["password"] = "interop-password"
		proxyMap["password"] = "interop-password"
	}
	switch network {
	case "ws":
		stream["wsSettings"] = map[string]any{"path": "/ws"}
		proxyMap["ws-opts"] = map[string]any{"path": "/ws"}
	case "grpc":
		stream["grpcSettings"] = map[string]any{"serviceName": "interop"}
		proxyMap["grpc-opts"] = map[string]any{"grpc-service-name": "interop"}
	}
	if encryption != "" {
		key, err := mlkem.GenerateKey768()
		if err != nil {
			t.Fatal(err)
		}
		settings["decryption"] = "mlkem768x25519plus." + encryption + ".600s." + base64.RawURLEncoding.EncodeToString(key.Bytes())
		proxyMap["encryption"] = "mlkem768x25519plus." + encryption + "." + rtt + "." + base64.RawURLEncoding.EncodeToString(key.EncapsulationKey().Bytes())
	}
	if udp {
		proxyMap["packet-encoding"] = "xudp"
	}
	config := map[string]any{"log": map[string]any{"loglevel": "debug"}, "inbounds": []any{map[string]any{"listen": "127.0.0.1", "port": port, "protocol": protocol, "settings": settings, "streamSettings": stream}}, "outbounds": []any{xrayFreedom(version)}}
	xrayStart(t, xrayBinary(t, version), config, net.JoinHostPort("127.0.0.1", strconv.Itoa(port)))
	proxy, err := adapter.ParseProxy(proxyMap)
	if err != nil {
		t.Fatal(err)
	}
	defer proxy.Close()
	destination := xrayEcho(t)
	for range 2 {
		if err := xrayTransfer(proxy, destination); err != nil {
			t.Fatal(err)
		}
	}
	if udp {
		if err := xrayUDPTransfer(t, proxy); err != nil {
			t.Fatal(err)
		}
	}
}

func TestXrayTransports(t *testing.T) {
	versions := strings.Split(os.Getenv("XRAY_INTEROP_VERSIONS"), ",")
	if versions[0] == "" {
		t.Fatal("XRAY_INTEROP_VERSIONS is required")
	}
	if os.Getenv("XRAY_INTEROP_BASELINE") == "1" {
		t.Skip("baseline only records REALITY")
	}
	for _, version := range versions {
		if version == "1.8.24" {
			continue
		}
		for _, protocol := range []string{"vless", "vmess", "trojan"} {
			for _, network := range []string{"tcp", "ws", "grpc"} {
				if protocol == "vmess" && network == "grpc" || protocol == "trojan" && network == "ws" {
					continue
				}
				t.Run(version+"/"+protocol+"-"+network, func(t *testing.T) { xrayTransport(t, version, protocol, network, "", "", false) })
			}
		}
		for _, mode := range []string{"native", "xorpub", "random"} {
			for _, rtt := range []string{"0rtt", "1rtt"} {
				t.Run(version+"/encryption-"+mode+"-"+rtt, func(t *testing.T) { xrayTransport(t, version, "vless", "tcp", mode, rtt, false) })
			}
		}
		t.Run(version+"/xudp", func(t *testing.T) { xrayTransport(t, version, "vless", "tcp", "", "", true) })
	}
}
