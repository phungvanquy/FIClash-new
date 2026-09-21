package main

import (
	"github.com/metacubex/mihomo/common/utils"
	"github.com/metacubex/mihomo/listener"
)

type CoreRunObservation struct {
	Session        string `json:"session"`
	Revision       uint64 `json:"revision"`
	Requested      bool   `json:"requested"`
	Active         bool   `json:"active"`
	Suspended      bool   `json:"suspended"`
	Tun            bool   `json:"tun"`
	MixedPort      int    `json:"mixedPort"`
	Generation     string `json:"generation,omitempty"`
	ConfigRevision int64  `json:"configRevision,omitempty"`
	Failure        string `json:"failure,omitempty"`
}

var runObservation = CoreRunObservation{Session: utils.NewUUIDV4().String()}
var activeSnapshotGeneration string
var activeSnapshotRevision int64

// The configuration lock covers both listener convergence and its observation.
func publishRunState(failure string) {
	state := listener.GetRuntimeState()
	runObservation = CoreRunObservation{
		Session:        runObservation.Session,
		Revision:       runObservation.Revision + 1,
		Requested:      isRunning.Load(),
		Active:         state.Active,
		Suspended:      isSuspended.Load(),
		Tun:            state.Tun,
		MixedPort:      state.MixedPort,
		Generation:     activeSnapshotGeneration,
		ConfigRevision: activeSnapshotRevision,
		Failure:        failure,
	}
	sendMessage(Message{Type: RunStateMessage, Data: runObservation})
}

func handleGetRunState() CoreRunObservation {
	configMu.Lock()
	defer configMu.Unlock()
	return runObservation
}
