package main

import (
	"errors"
	"os"
	"path/filepath"
	"reflect"
	"strings"
	"testing"
	"time"

	"github.com/metacubex/mihomo/config"
	C "github.com/metacubex/mihomo/constant"
	"github.com/metacubex/mihomo/tunnel"
)

const candidateGeneration = "0123456789abcdef0123456789abcdef"
const candidateProxy = "proxies:\n  - {name: Candidate, type: socks5, server: 127.0.0.1, port: 1080}\n"

func stagedTestCandidate(t *testing.T, yaml string) (string, *PrepareConfigParams) {
	t.Helper()
	home := t.TempDir()
	previousHome, previousInit := C.Path.HomeDir(), isInit.Load()
	previousNames, previousMode := config.GetProxyNameList(), tunnel.Mode()
	C.SetHomeDir(home)
	isInit.Store(true)
	resetPreparations()
	t.Cleanup(func() {
		resetPreparations()
		C.SetHomeDir(previousHome)
		isInit.Store(previousInit)
		config.SetProxyNameList(previousNames)
		tunnel.SetMode(previousMode)
	})
	directory := filepath.Join(home, "profiles", "generations", candidateGeneration)
	if err := os.MkdirAll(directory, 0o700); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(directory, "effective.yaml"), []byte(yaml), 0o600); err != nil {
		t.Fatal(err)
	}
	return directory, &PrepareConfigParams{Generation: candidateGeneration, Revision: 42}
}

func TestCandidateFailuresPreserveActiveRuntime(t *testing.T) {
	cases := map[string]string{
		"malformed YAML":      "proxies: [",
		"unsupported adapter": "proxies: [{name: Candidate, type: not-a-protocol}]",
		"missing reference":   candidateProxy + "proxy-groups: [{name: Group, type: select, proxies: [Missing]}]",
		"late invalid rule":   candidateProxy + "mode: direct\nrules: [INVALID-RULE,example.test,DIRECT]",
		"missing provider":    candidateProxy + "proxy-providers: {Remote: {type: http, url: 'https://example.invalid/config'}}",
		"empty inventory":     "proxies: [{name: Local, type: direct}]",
	}
	for name, yaml := range cases {
		t.Run(name, func(t *testing.T) {
			_, params := stagedTestCandidate(t, yaml)
			tunnel.SetMode(tunnel.Rule)
			config.SetProxyNameList([]string{"Existing"})
			previousConfig := currentConfig
			if result, err := handlePrepareConfig(params); err == nil || result != nil {
				t.Fatalf("prepare = %v, %v", result, err)
			}
			if tunnel.Mode() != tunnel.Rule || !reflect.DeepEqual(config.GetProxyNameList(), []string{"Existing"}) || currentConfig != previousConfig {
				t.Fatal("rejected candidate changed active runtime")
			}
			if len(preparations.entries) != 0 {
				t.Fatal("rejected candidate leaked its handle")
			}
		})
	}
}

func TestPrepareAndDiscardAreRevisionScoped(t *testing.T) {
	_, params := stagedTestCandidate(t, candidateProxy)
	prepared, err := handlePrepareConfig(params)
	if err != nil {
		t.Fatal(err)
	}
	if prepared.Handle == "" || prepared.Revision != 42 || len(prepared.Servers) != 1 || prepared.Servers[0].Name != "Candidate" {
		t.Fatalf("unexpected preparation: %+v", prepared)
	}
	if _, err := handleDiscardConfig(&PreparedConfigRef{Handle: prepared.Handle, Revision: 41}); err == nil {
		t.Fatal("discard accepted a different revision")
	}
	ref := &PreparedConfigRef{Handle: prepared.Handle, Revision: 42}
	if discarded, err := handleDiscardConfig(ref); !discarded || err != nil {
		t.Fatalf("discard = %v, %v", discarded, err)
	}
	if discarded, err := handleDiscardConfig(ref); discarded || err != nil {
		t.Fatalf("repeat discard = %v, %v", discarded, err)
	}
	if _, err := handleActivateConfig(&ActivateConfigParams{Prepared: *ref}); err == nil {
		t.Fatal("discarded candidate activated")
	}
}

func TestFreshCandidateUsesBundledGeodata(t *testing.T) {
	for _, mode := range []string{"false", "true"} {
		t.Run(mode, func(t *testing.T) {
			directory, params := stagedTestCandidate(t, candidateProxy+"geodata-mode: "+mode+"\nrules: [\"GEOSITE,cn,DIRECT\", \"GEOIP,cn,DIRECT\", \"IP-ASN,13335,DIRECT\", \"MATCH,DIRECT\"]\n")
			if err := os.Mkdir(filepath.Join(directory, "geo"), 0o700); err != nil {
				t.Fatal(err)
			}
			for name, asset := range map[string]string{"GeoSite.dat": "GEOSITE.dat", "GeoIP.dat": "GEOIP.dat", "Country.mmdb": "GEOIP.metadb", "ASN.mmdb": "ASN.mmdb"} {
				data, err := os.ReadFile(filepath.Join("..", "assets", "data", asset))
				if err != nil {
					t.Fatal(err)
				}
				if err := os.WriteFile(filepath.Join(directory, "geo", name), data, 0o600); err != nil {
					t.Fatal(err)
				}
			}
			if _, err := handlePrepareConfig(params); err != nil {
				t.Fatal(err)
			}
		})
	}
}

func TestReinitializationInvalidatesPreparedHandles(t *testing.T) {
	_, params := stagedTestCandidate(t, candidateProxy)
	prepared, err := handlePrepareConfig(params)
	if err != nil {
		t.Fatal(err)
	}
	handleInitClash(&InitParams{HomeDir: C.Path.HomeDir()})
	if _, err := handleActivateConfig(&ActivateConfigParams{Prepared: PreparedConfigRef{Handle: prepared.Handle, Revision: 42}}); err == nil {
		t.Fatal("handle survived core initialization")
	}
	if len(preparations.entries) != 0 {
		t.Fatal("reinitialization leaked candidates")
	}
}

func TestPreparedHandleExpiresBeforeActivation(t *testing.T) {
	_, params := stagedTestCandidate(t, candidateProxy)
	prepared, err := handlePrepareConfig(params)
	if err != nil {
		t.Fatal(err)
	}
	preparations.entries[prepared.Handle].created = time.Now().Add(-11 * time.Minute)
	if _, err := handleActivateConfig(&ActivateConfigParams{Prepared: PreparedConfigRef{Handle: prepared.Handle, Revision: prepared.Revision}}); err == nil {
		t.Fatal("expired handle activated")
	}
	if len(preparations.entries) != 0 {
		t.Fatal("expired handle retained resources")
	}
}

func TestSettingsChangesInvalidatePreparedCandidates(t *testing.T) {
	_, params := stagedTestCandidate(t, candidateProxy)
	prepared, err := handlePrepareConfig(params)
	if err != nil {
		t.Fatal(err)
	}
	previous, previousRunning := currentConfig, isRunning.Load()
	currentConfig = &config.Config{General: &config.General{}}
	isRunning.Store(false)
	t.Cleanup(func() { currentConfig = previous; isRunning.Store(previousRunning) })
	if err := updateConfig(&UpdateParams{}); err != nil {
		t.Fatal(err)
	}
	if _, err := handleActivateConfig(&ActivateConfigParams{Prepared: PreparedConfigRef{Handle: prepared.Handle, Revision: prepared.Revision}}); err == nil {
		t.Fatal("candidate survived newer settings")
	}
}

func TestCandidateResourcesRejectEscapesAndNonFiles(t *testing.T) {
	directory, params := stagedTestCandidate(t, candidateProxy)
	for _, generation := range []string{"../outside", strings.Repeat("a", 31), strings.Repeat("A", 32)} {
		if _, err := candidateDirectory(C.Path.HomeDir(), generation); err == nil {
			t.Fatalf("accepted generation %q", generation)
		}
	}
	if err := stagedCandidateFile(directory, directory); err == nil {
		t.Fatal("accepted directory as a resource")
	}
	outside := filepath.Join(t.TempDir(), "provider.yaml")
	if err := os.WriteFile(outside, []byte("proxies: []"), 0o600); err != nil {
		t.Fatal(err)
	}
	if err := stagedCandidateFile(directory, outside); err == nil {
		t.Fatal("accepted external provider")
	}
	link := filepath.Join(directory, "linked.yaml")
	if err := os.Symlink(outside, link); err == nil {
		if err := stagedCandidateFile(directory, link); err == nil {
			t.Fatal("accepted symbolic link")
		}
	}
	providerDir := filepath.Join(directory, "provider-dir")
	if err := os.Mkdir(providerDir, 0o700); err != nil {
		t.Fatal(err)
	}
	yaml := candidateProxy + "proxy-providers: {Remote: {type: file, path: '" + filepath.ToSlash(providerDir) + "'}}"
	if err := os.WriteFile(filepath.Join(directory, "effective.yaml"), []byte(yaml), 0o600); err != nil {
		t.Fatal(err)
	}
	if _, err := handlePrepareConfig(params); err == nil {
		t.Fatal("accepted non-file provider")
	}
}

func TestCandidateRequestsMissingGeodataWithoutLoadingGlobalFiles(t *testing.T) {
	for _, rules := range []string{
		"rules: ['GEOSITE,test,Candidate']",
		"rule-providers: {Test: {type: inline, behavior: classical, payload: ['GEOSITE,test']}}\nrules: ['RULE-SET,Test,Candidate']",
	} {
		t.Run(rules, func(t *testing.T) {
			_, params := stagedTestCandidate(t, candidateProxy+rules)
			_, err := handlePrepareConfig(params)
			var required *candidateResourceRequired
			if !errors.As(err, &required) || required.Name != "GeoSite.dat" {
				t.Fatalf("missing resource = %v", err)
			}
			if len(preparations.entries) != 0 {
				t.Fatal("resource request leaked candidate")
			}
		})
	}
}

func TestMalformedRealityProviderPreservesActiveRuntime(t *testing.T) {
	for _, suffix := range []string{"&support-x25519mlkem768=invalid", "&pqv=YQ"} {
		t.Run(suffix, func(t *testing.T) {
			directory, params := stagedTestCandidate(t, candidateProxy)
			providerPath := filepath.Join(directory, "provider.txt")
			const valid = "vless://6a9ecf20-44b2-4fc2-a3a0-4dcda7b2c3eb@127.0.0.1:443?security=reality&pbk=ppQ9FwLrLIa0AOrp1WvcyiaQ37vg2WSy_CD4bIdiTUw#valid"
			invalid := strings.Replace(valid, "#valid", suffix+"#invalid", 1)
			if err := os.WriteFile(providerPath, []byte(valid+"\n"+invalid), 0o600); err != nil {
				t.Fatal(err)
			}
			yaml := candidateProxy + "proxy-providers: {Remote: {type: file, path: '" + filepath.ToSlash(providerPath) + "'}}"
			if err := os.WriteFile(filepath.Join(directory, "effective.yaml"), []byte(yaml), 0o600); err != nil {
				t.Fatal(err)
			}
			tunnel.SetMode(tunnel.Rule)
			config.SetProxyNameList([]string{"Existing"})
			previous := currentConfig
			if result, err := handlePrepareConfig(params); err == nil || result != nil {
				t.Fatalf("accepted malformed provider: %v, %v", result, err)
			}
			if currentConfig != previous || tunnel.Mode() != tunnel.Rule || !reflect.DeepEqual(config.GetProxyNameList(), []string{"Existing"}) || len(preparations.entries) != 0 {
				t.Fatal("failed provider replaced active runtime or leaked preparation")
			}
		})
	}
}
