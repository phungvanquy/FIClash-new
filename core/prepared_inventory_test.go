package main

import (
	"os"
	"reflect"
	"strings"
	"testing"

	"github.com/metacubex/mihomo/adapter"
	"github.com/metacubex/mihomo/adapter/outboundgroup"
	"github.com/metacubex/mihomo/config"
	C "github.com/metacubex/mihomo/constant"
	P "github.com/metacubex/mihomo/constant/provider"
)

func TestPreparedInventoryPreservesSourceIdentityAndOrder(t *testing.T) {
	buf, err := os.ReadFile("../test/fixtures/vpn_inventory.yaml")
	if err != nil {
		t.Fatal(err)
	}
	_, params := stagedTestCandidate(t, string(buf))
	result, err := handlePrepareConfig(params)
	if err != nil {
		t.Fatal(err)
	}
	var names, providers, ids []string
	for _, server := range result.Servers {
		names = append(names, server.Name)
		providers = append(providers, server.Provider)
		ids = append(ids, server.ID)
	}
	if !reflect.DeepEqual(names, []string{"Shared", "Shared", "name[1]`.*", "Shared"}) ||
		!reflect.DeepEqual(providers, []string{"", "Zulu", "Zulu", "Alpha"}) {
		t.Fatalf("inventory = %+v", result.Servers)
	}
	seen := make(map[string]bool)
	for _, id := range ids {
		if seen[id] {
			t.Fatalf("ambiguous identity %s", id)
		}
		seen[id] = true
	}
}

func TestPreparedInventoryRejectsAmbiguousProviderMembers(t *testing.T) {
	_, params := stagedTestCandidate(t, `proxy-providers:
  Remote:
    type: inline
    payload:
      - {name: same, type: socks5, server: 127.0.0.1, port: 1080}
      - {name: same, type: socks5, server: 127.0.0.1, port: 1081}
`)
	if _, err := handlePrepareConfig(params); err == nil {
		t.Fatal("ambiguous inline provider accepted")
	}
}

func TestPreparedManagedTargetsResolveToExactProviderMembers(t *testing.T) {
	buf, err := os.ReadFile("../test/fixtures/vpn_managed.yaml")
	if err != nil {
		t.Fatal(err)
	}
	_, params := stagedTestCandidate(t, string(buf))
	result, err := handlePrepareConfig(params)
	if err != nil {
		t.Fatal(err)
	}
	const prefix = "__flclash_0123456789abcdef0123456789abcdef_"
	err = preparations.entries[result.Handle].config.Inspect(func(cfg *config.Config) error {
		want := []C.Proxy{cfg.Proxies["Shared"], cfg.Providers["Zulu"].Proxies()[0], cfg.Providers["Zulu"].Proxies()[1], cfg.Providers["Alpha"].Proxies()[0]}
		targets := []string{"Shared", prefix + "server_1", prefix + "server_2", prefix + "server_3"}
		global := cfg.Proxies["GLOBAL"].Unwrap(nil, false)
		if global.Name() != prefix+"select" || cfg.General.Mode.String() != "global" {
			t.Fatal("GLOBAL does not route through managed selector")
		}
		selector := global.(*adapter.Proxy).ProxyAdapter.(*outboundgroup.Selector)
		for i, target := range targets {
			if err := selector.Set(target); err != nil {
				t.Fatal(err)
			}
			resolved := selector.Unwrap(nil, false)
			if i > 0 {
				resolved = resolved.Unwrap(nil, false)
			}
			if resolved != want[i] {
				t.Fatalf("%s selected another endpoint", target)
			}
		}
		for _, name := range []string{prefix + "auto", prefix + "fallback"} {
			group := cfg.Proxies[name].(*adapter.Proxy).ProxyAdapter.(interface{ Proxies() []C.Proxy })
			var actual []string
			for _, proxy := range group.Proxies() {
				actual = append(actual, proxy.Name())
			}
			if !reflect.DeepEqual(actual, targets) {
				t.Fatalf("%s inventory = %v", name, actual)
			}
		}
		return nil
	})
	if err != nil {
		t.Fatal(err)
	}
}

func TestCandidateProviderOrderSupportsYamlMerges(t *testing.T) {
	order, err := candidateProviderOrder([]byte("defaults: &defaults {Zulu: {}, Alpha: {}}\nproxy-providers: {<<: *defaults, Last: {}}\n"))
	if err != nil || !reflect.DeepEqual(order, []string{"Zulu", "Alpha", "Last"}) {
		t.Fatalf("order = %v, %v", order, err)
	}
}

func TestInventoryProbeCannotActivate(t *testing.T) {
	directory, params := stagedTestCandidate(t, candidateProxy)
	if err := os.Rename(directory+"/effective.yaml", directory+"/candidate.yaml"); err != nil {
		t.Fatal(err)
	}
	params.Probe = true
	result, err := handlePrepareConfig(params)
	if err != nil {
		t.Fatal(err)
	}
	if _, err := handleActivateConfig(&ActivateConfigParams{Prepared: PreparedConfigRef{Handle: result.Handle, Revision: result.Revision}}); err == nil || !strings.Contains(err.Error(), "probe") {
		t.Fatalf("probe activation = %v", err)
	}
}

func TestPreparedProvidersHaveGenerationScopedRuntimeNames(t *testing.T) {
	buf, err := os.ReadFile("../test/fixtures/vpn_inventory.yaml")
	if err != nil {
		t.Fatal(err)
	}
	_, params := stagedTestCandidate(t, string(buf))
	result, err := handlePrepareConfig(params)
	if err != nil {
		t.Fatal(err)
	}
	err = preparations.entries[result.Handle].config.Inspect(func(cfg *config.Config) error {
		for key, provider := range cfg.Providers {
			if provider.VehicleType() == P.Compatible {
				continue
			}
			if !strings.HasPrefix(provider.Name(), "__flclash_"+candidateGeneration+"_proxy_") {
				t.Fatalf("unscoped provider %q: %s", key, provider.Name())
			}
		}
		return nil
	})
	if err != nil {
		t.Fatal(err)
	}
}

func TestGenerationSetupNeverFallsBackToRootConfiguration(t *testing.T) {
	directory, params := stagedTestCandidate(t, candidateProxy)
	previous := currentConfig
	if err := os.WriteFile(directory+"/effective.yaml", []byte("proxies: ["), 0600); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(C.Path.HomeDir()+"/config.yaml", []byte(candidateProxy), 0600); err != nil {
		t.Fatal(err)
	}
	if err := applyConfig(&SetupParams{Generation: params.Generation, Revision: params.Revision}); err == nil {
		t.Fatal("invalid generation silently applied a fallback")
	}
	if currentConfig != previous {
		t.Fatal("failed generation setup replaced active config")
	}
}
