package main

import (
	"encoding/json"
	"os"
	"reflect"
	"testing"
)

func TestPreparedConfigProtocolContract(t *testing.T) {
	buf, err := os.ReadFile("../test/fixtures/core_protocol.json")
	if err != nil {
		t.Fatal(err)
	}
	var fixture map[string]json.RawMessage
	if err := json.Unmarshal(buf, &fixture); err != nil {
		t.Fatal(err)
	}
	requests := []struct {
		key    string
		method CoreMethod
		params any
	}{
		{"prepareCall", prepareConfigMethod, &PrepareConfigParams{}},
		{"activateCall", activateConfigMethod, &ActivateConfigParams{}},
		{"discardCall", discardConfigMethod, &PreparedConfigRef{}},
	}
	for _, request := range requests {
		t.Run(request.key, func(t *testing.T) {
			var call MethodCall
			if err := json.Unmarshal(fixture[request.key], &call); err != nil {
				t.Fatal(err)
			}
			if call.Method != request.method {
				t.Fatalf("method = %s", call.Method)
			}
			if err := call.decodeArguments(request.params); err != nil {
				t.Fatal(err)
			}
			assertProtocolJSON(t, call.Arguments, request.params)
		})
	}
	results := []struct {
		key    string
		result any
	}{
		{"preparedResponse", &PreparedConfigResult{}},
		{"activatedResponse", &ActivatedConfigResult{}},
		{"discardedResponse", new(bool)},
		{"runStateResponse", &CoreRunObservation{}},
	}
	for _, result := range results {
		t.Run(result.key, func(t *testing.T) {
			var envelope struct {
				Result json.RawMessage `json:"result"`
			}
			if err := json.Unmarshal(fixture[result.key], &envelope); err != nil {
				t.Fatal(err)
			}
			if err := json.Unmarshal(envelope.Result, result.result); err != nil {
				t.Fatal(err)
			}
			assertProtocolJSON(t, envelope.Result, result.result)
		})
	}
}

func assertProtocolJSON(t *testing.T, expected json.RawMessage, value any) {
	t.Helper()
	encoded, err := json.Marshal(value)
	if err != nil {
		t.Fatal(err)
	}
	var want, got any
	if err := json.Unmarshal(expected, &want); err != nil {
		t.Fatal(err)
	}
	if err := json.Unmarshal(encoded, &got); err != nil {
		t.Fatal(err)
	}
	if !reflect.DeepEqual(want, got) {
		t.Fatalf("wire value = %s, want %s", encoded, expected)
	}
}
