package main

import (
	"context"
	"fmt"
	"net"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"strings"
	"testing"
	"time"

	C "github.com/metacubex/mihomo/constant"
	"github.com/metacubex/mihomo/listener"
)

func TestPreparedActivationAndSnapshotRestoration(t *testing.T) {
	mode := os.Getenv("FLCLASH_PREPARED_ACTIVATION_TEST")
	if mode == "" {
		for _, mode := range []string{"restore", "restore-fails", "disconnected-inbounds"} {
			t.Run(mode, func(t *testing.T) {
				ctx, cancel := context.WithTimeout(context.Background(), 15*time.Second)
				defer cancel()
				command := exec.CommandContext(ctx, os.Args[0], "-test.run=^TestPreparedActivationAndSnapshotRestoration$")
				command.Env = append(os.Environ(), "FLCLASH_PREPARED_ACTIVATION_TEST="+mode)
				if output, err := command.CombinedOutput(); err != nil {
					t.Fatalf("isolated activation: %v\n%s", err, output)
				}
			})
		}
		return
	}
	if mode == "disconnected-inbounds" {
		testDisconnectedInbounds(t)
		return
	}

	free, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatal(err)
	}
	oldPort := free.Addr().(*net.TCPAddr).Port
	_ = free.Close()
	directory, params := stagedTestCandidate(t, candidateProxy+"mixed-port: "+strconv.Itoa(oldPort)+"\n")
	prepared, err := handlePrepareConfig(params)
	if err != nil {
		t.Fatal(err)
	}
	if _, err := handleActivateConfig(&ActivateConfigParams{Prepared: PreparedConfigRef{Handle: prepared.Handle, Revision: prepared.Revision}}); err != nil {
		t.Fatal(err)
	}
	if isRunning.Load() || listener.GetPorts().MixedPort != 0 {
		t.Fatal("disconnected activation started a listener")
	}
	if !handleStartListener() || listener.GetPorts().MixedPort != oldPort {
		t.Fatal("initial snapshot could not start")
	}
	defer handleShutdown()
	blocked, err := net.ListenPacket("udp", "127.0.0.1:0")
	if err != nil {
		t.Fatal(err)
	}
	defer blocked.Close()
	blockedPort := blocked.LocalAddr().(*net.UDPAddr).Port
	const replacementGeneration = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
	replacementDirectory := filepath.Join(C.Path.HomeDir(), "profiles", "generations", replacementGeneration)
	if err := os.Mkdir(replacementDirectory, 0700); err != nil {
		t.Fatal(err)
	}
	replacement := strings.ReplaceAll(candidateProxy, "Candidate", "Replacement") + "mixed-port: " + strconv.Itoa(blockedPort) + "\n"
	if err := os.WriteFile(filepath.Join(replacementDirectory, "effective.yaml"), []byte(replacement), 0600); err != nil {
		t.Fatal(err)
	}
	prepared, err = handlePrepareConfig(&PrepareConfigParams{Generation: replacementGeneration, Revision: 43})
	if err != nil {
		t.Fatal(err)
	}
	if _, err := handleActivateConfig(&ActivateConfigParams{Prepared: PreparedConfigRef{Handle: prepared.Handle, Revision: prepared.Revision}}); err == nil {
		t.Fatal("failed listener activation reported success")
	}
	if _, ok := preparations.entries[prepared.Handle]; ok {
		t.Fatal("failed activation retained a reusable handle")
	}
	if mode == "restore-fails" {
		if err := os.Rename(filepath.Join(directory, "effective.yaml"), filepath.Join(directory, "missing-for-test.yaml")); err != nil {
			t.Fatal(err)
		}
	}
	err = applyConfig(&SetupParams{Generation: params.Generation, Revision: params.Revision})
	if mode == "restore-fails" {
		if err == nil {
			t.Fatal("missing previous snapshot was reported as restored")
		}
		return
	}
	if err != nil {
		t.Fatalf("restore snapshot: %v", err)
	}
	if currentConfig.Proxies["Candidate"] == nil || currentConfig.Proxies["Replacement"] != nil || listener.GetPorts().MixedPort != oldPort || !isRunning.Load() {
		t.Fatal("restoration lost configuration or running intent")
	}
}

func testDisconnectedInbounds(t *testing.T) {
	t.Helper()
	freePort := func() int {
		l, err := net.Listen("tcp", "127.0.0.1:0")
		if err != nil {
			t.Fatal(err)
		}
		port := l.Addr().(*net.TCPAddr).Port
		_ = l.Close()
		return port
	}
	port, namedPort := freePort(), freePort()
	body := candidateProxy + fmt.Sprintf("tunnels:\n  - network: [tcp]\n    address: 127.0.0.1:%d\n    target: 127.0.0.1:9\n    proxy: Candidate\nlisteners:\n  - name: custom\n    type: mixed\n    port: %d\n    listen: 127.0.0.1\niptables: {enable: true}\n", port, namedPort)
	_, params := stagedTestCandidate(t, body)
	prepared, err := handlePrepareConfig(params)
	if err != nil {
		t.Fatal(err)
	}
	defer handleShutdown()
	if _, err := handleActivateConfig(&ActivateConfigParams{Prepared: PreparedConfigRef{Handle: prepared.Handle, Revision: prepared.Revision}}); err != nil {
		t.Fatal(err)
	}
	assertBindable := func() {
		for _, port := range []int{port, namedPort} {
			l, err := net.Listen("tcp", fmt.Sprintf("127.0.0.1:%d", port))
			if err != nil {
				t.Fatalf("disconnected custom listener is still bound: %v", err)
			}
			_ = l.Close()
		}
	}
	assertBindable()
	if handleStartListener() {
		t.Fatal("invalid iptables activation did not return failure")
	}
	if !handleStopListener() {
		t.Fatal("stop failed")
	}
	assertBindable()
}
