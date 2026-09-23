//go:build xrayinterop

package main

import (
	"crypto/ecdh"
	"crypto/rand"
	"encoding/base64"
	"net"
	"net/http"
	"net/http/httptest"
	"net/http/httputil"
	"net/url"
	"strconv"
	"sync/atomic"
	"testing"
)

func xrayIndependentDownload(t *testing.T, config, proxy map[string]any, target string, invalid bool) {
	t.Helper()
	server := proxy["server"].(string)
	inbounds := config["inbounds"].([]any)
	backend := inbounds[0].(map[string]any)
	stream := backend["streamSettings"].(map[string]any)
	uploadReality := stream["realitySettings"]
	delete(stream, "realitySettings")
	stream["security"] = "none"
	backendURL, err := url.Parse("http://" + net.JoinHostPort(server, strconv.Itoa(backend["port"].(int))))
	if err != nil {
		t.Fatal(err)
	}
	reverse := httputil.NewSingleHostReverseProxy(backendURL)
	protocols := new(http.Protocols)
	protocols.SetUnencryptedHTTP2(true)
	transport := &http.Transport{Protocols: protocols}
	reverse.Transport = transport
	t.Cleanup(transport.CloseIdleConnections)
	var uploads, downloads atomic.Int32
	guard := httptest.NewUnstartedServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		expected := "upload"
		if r.Method == "GET" {
			expected = "download"
		}
		if server == "::1" && expected == "upload" && r.Host != "[::1]" {
			http.Error(w, "invalid IPv6 authority", http.StatusBadRequest)
			return
		}
		if r.Header.Get("X-Interop") != expected {
			http.Error(w, "missing direction header", http.StatusForbidden)
			return
		}
		if expected == "upload" {
			uploads.Add(1)
		} else {
			downloads.Add(1)
		}
		reverse.ServeHTTP(w, r)
	}))
	guard.Config.Protocols = protocols
	guard.Start()
	t.Cleanup(guard.Close)
	guardPort := guard.Listener.Addr().(*net.TCPAddr).Port
	uploadPort, downloadPort := xrayPort(t), xrayPort(t)
	key, err := ecdh.X25519().GenerateKey(rand.Reader)
	if err != nil {
		t.Fatal(err)
	}
	downloadReality := map[string]any{"dest": target, "serverNames": []string{"download.test"}, "privateKey": base64.RawURLEncoding.EncodeToString(key.Bytes()), "shortIds": []string{"ccdd"}}
	for _, front := range []struct {
		port    int
		reality any
	}{{uploadPort, uploadReality}, {downloadPort, downloadReality}} {
		inbounds = append(inbounds, map[string]any{"listen": server, "port": front.port, "protocol": "dokodemo-door", "settings": map[string]any{"address": "127.0.0.1", "port": guardPort, "network": "tcp"}, "streamSettings": map[string]any{"network": "tcp", "security": "reality", "realitySettings": front.reality}})
	}
	config["inbounds"] = inbounds
	proxy["port"] = uploadPort
	options := proxy["xhttp-opts"].(map[string]any)
	options["headers"] = map[string]any{"X-Interop": "upload"}
	downloadOptions := map[string]any{"public-key": base64.RawURLEncoding.EncodeToString(key.PublicKey().Bytes()), "short-id": "ccdd"}
	if invalid {
		downloadOptions["short-id"] = "aabb"
	}
	options["download-settings"] = map[string]any{"server": server, "port": downloadPort, "tls": true, "servername": "download.test", "client-fingerprint": "safari", "reality-opts": downloadOptions, "headers": map[string]any{"X-Interop": "download"}}
	t.Cleanup(func() {
		if !invalid && (uploads.Load() == 0 || downloads.Load() == 0) {
			t.Error("independent XHTTP headers did not reach both authenticated connections")
		}
	})
}
