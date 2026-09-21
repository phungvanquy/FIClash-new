package main

import (
	"context"
	"net"
	"os"
	"os/exec"
	"strconv"
	"testing"
	"time"
)

func TestRunStateReflectsListenersWithoutChangingIntent(t *testing.T) {
	if os.Getenv("FLCLASH_RUN_STATE_TEST") == "" {
		ctx, cancel := context.WithTimeout(context.Background(), 15*time.Second)
		defer cancel()
		command := exec.CommandContext(ctx, os.Args[0], "-test.run=^TestRunStateReflectsListenersWithoutChangingIntent$")
		command.Env = append(os.Environ(), "FLCLASH_RUN_STATE_TEST=1")
		if output, err := command.CombinedOutput(); err != nil {
			t.Fatalf("isolated run-state test: %v\n%s", err, output)
		}
		return
	}
	initial := handleGetRunState()
	if initial.Session == "" || initial.Active || initial.Requested || initial.Tun {
		t.Fatalf("Core readiness is not a running VPN: %+v", initial)
	}
	if handleStartListener() {
		t.Fatal("listener start without a configuration succeeded")
	}
	missing := handleGetRunState()
	if missing.Failure != "missing_configuration" || missing.Active {
		t.Fatalf("missing configuration was not observed: %+v", missing)
	}
	free, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatal(err)
	}
	port := free.Addr().(*net.TCPAddr).Port
	_ = free.Close()
	_, params := stagedTestCandidate(t, candidateProxy+"mixed-port: "+strconv.Itoa(port)+"\n")
	prepared, err := handlePrepareConfig(params)
	if err != nil {
		t.Fatal(err)
	}
	if _, err = handleActivateConfig(&ActivateConfigParams{Prepared: PreparedConfigRef{Handle: prepared.Handle, Revision: prepared.Revision}}); err != nil {
		t.Fatal(err)
	}
	defer handleShutdown()
	configured := handleGetRunState()
	if configured.Active || configured.Requested || configured.MixedPort != 0 || configured.Generation != params.Generation {
		t.Fatalf("offline activation changed run intent: %+v", configured)
	}
	if !handleStartListener() {
		t.Fatal("start failed")
	}
	running := handleGetRunState()
	if !running.Active || !running.Requested || running.Tun || running.MixedPort != port || running.Failure != "" || running.Revision <= configured.Revision {
		t.Fatalf("real listener not reflected: %+v", running)
	}
	if repeated := handleGetRunState(); repeated != running {
		t.Fatal("passive query changed observation or run intent")
	}
	handleSuspend(true)
	suspended := handleGetRunState()
	if !suspended.Suspended || !suspended.Requested || suspended.Revision <= running.Revision {
		t.Fatalf("suspension lost run intent: %+v", suspended)
	}
	handleSuspend(false)
	if !handleStopListener() {
		t.Fatal("stop failed")
	}
	stopped := handleGetRunState()
	if stopped.Active || stopped.Tun || stopped.Requested || stopped.MixedPort != 0 || stopped.Revision <= suspended.Revision {
		t.Fatalf("stop still reports active listeners: %+v", stopped)
	}
	blocked, err := net.ListenPacket("udp", "127.0.0.1:"+strconv.Itoa(port))
	if err != nil {
		t.Fatal(err)
	}
	defer blocked.Close()
	if handleStartListener() {
		t.Fatal("UDP bind failure reported success")
	}
	failed := handleGetRunState()
	if failed.Active || failed.MixedPort != 0 || failed.Failure != "listener_failed" || !failed.Requested {
		t.Fatalf("failed listener reported connected: %+v", failed)
	}
}
