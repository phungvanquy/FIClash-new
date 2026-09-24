package main

import (
	"encoding/json"
	"errors"
	"os"
	"path/filepath"
	"testing"
)

func TestAppCandidatePreparation(t *testing.T) {
	requestPath := os.Getenv("FLCLASH_PREPARATION_REQUEST")
	if requestPath == "" {
		t.Skip("requires a candidate staged by Flutter")
	}
	var request struct {
		Home   string              `json:"home"`
		Params PrepareConfigParams `json:"params"`
	}
	data, err := os.ReadFile(requestPath)
	if err != nil {
		t.Fatal(err)
	}
	if err := json.Unmarshal(data, &request); err != nil {
		t.Fatal(err)
	}
	handleInitClash(&InitParams{HomeDir: request.Home})
	defer resetPreparations()
	result, err := handlePrepareConfig(&request.Params)
	response := MethodResponse{Result: result}
	if err != nil {
		response.Error = &MethodError{Code: "prepare_failed", Message: err.Error(), Details: preparationFailureDetails(err)}
		var required *candidateResourceRequired
		if errors.As(err, &required) {
			response.Error.Code = "resource_required"
			response.Error.Details = map[string]string{"resource": required.Name}
		}
	}
	data, err = response.JSON()
	if err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(request.Home, "response.json"), data, 0o600); err != nil {
		t.Fatal(err)
	}
}
