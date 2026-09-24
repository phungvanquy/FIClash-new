package main

import (
	"encoding/base64"
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"regexp"
	"strings"
	"sync"
	"syscall"
	"time"

	"github.com/metacubex/mihomo/adapter"
	"github.com/metacubex/mihomo/adapter/outboundgroup"
	"github.com/metacubex/mihomo/common/utils"
	"github.com/metacubex/mihomo/config"
	C "github.com/metacubex/mihomo/constant"
	P "github.com/metacubex/mihomo/constant/provider"
	"github.com/metacubex/mihomo/hub"
	"gopkg.in/yaml.v3"
)

type PrepareConfigParams struct {
	Generation string `json:"generation"`
	Revision   int64  `json:"revision"`
	Probe      bool   `json:"probe,omitempty"`
}

type PreparedConfigRef struct {
	Handle   string `json:"handle"`
	Revision int64  `json:"revision"`
}

type ActivateConfigParams struct {
	Prepared PreparedConfigRef `json:"prepared"`
	Setup    SetupParams       `json:"setup"`
}

type PreparedServer struct {
	ID       string `json:"id"`
	Name     string `json:"name"`
	Target   string `json:"target"`
	Type     string `json:"type"`
	Provider string `json:"provider,omitempty"`
}

type PreparedConfigResult struct {
	Handle     string           `json:"handle"`
	Generation string           `json:"generation"`
	Revision   int64            `json:"revision"`
	Servers    []PreparedServer `json:"servers"`
}

type ActivatedConfigResult struct {
	Generation string `json:"generation"`
	Revision   int64  `json:"revision"`
}

type preparedEntry struct {
	params      PrepareConfigParams
	baseVersion uint64
	created     time.Time
	config      *config.PreparedConfig
}

var preparations = struct {
	sync.Mutex
	version          uint64
	activeGeneration string
	entries          map[string]*preparedEntry
}{entries: make(map[string]*preparedEntry)}

var generationPattern = regexp.MustCompile(`^[a-f0-9]{32}$`)

var errStalePreparation = errors.New("prepared configuration is stale or unavailable")
var errCoreNotInitialized = errors.New("core is not initialized")

type configPreparationError struct {
	Stage string
	Err   error
}

func (e *configPreparationError) Error() string { return e.Err.Error() }
func (e *configPreparationError) Unwrap() error { return e.Err }

func preparationFailureDetails(err error) map[string]any {
	details := make(map[string]any)
	var preparation *configPreparationError
	if errors.As(err, &preparation) {
		details["stage"] = preparation.Stage
	}
	var errno syscall.Errno
	if errors.As(err, &errno) {
		details["osError"] = uint64(errno)
	}
	return details
}

type candidateResourceRequired struct {
	Name string
}

func (e *candidateResourceRequired) Error() string {
	return "candidate geodata resource required: " + e.Name
}

func candidateDirectory(home, generation string) (string, error) {
	if !generationPattern.MatchString(generation) {
		return "", errors.New("invalid content generation")
	}
	root := filepath.Join(home, "profiles", "generations")
	path := filepath.Join(root, generation)
	if err := confinedCandidatePath(home, path); err != nil {
		return "", err
	}
	return path, nil
}

func confinedCandidatePath(root, path string) error {
	root, err := filepath.Abs(root)
	if err != nil {
		return err
	}
	path, err = filepath.Abs(path)
	if err != nil {
		return err
	}
	rel, err := filepath.Rel(root, path)
	if err != nil || rel == "." || rel == ".." || strings.HasPrefix(rel, ".."+string(filepath.Separator)) {
		return errors.New("candidate path escapes its generation")
	}
	for entry := path; entry != root; entry = filepath.Dir(entry) {
		info, err := os.Lstat(entry)
		if err != nil {
			return err
		}
		if info.Mode()&os.ModeSymlink != 0 {
			return errors.New("candidate path contains a symbolic link")
		}
	}
	return nil
}

func stagedCandidateFile(root, path string) error {
	if err := confinedCandidatePath(root, path); err != nil {
		return err
	}
	info, err := os.Stat(path)
	if err != nil {
		return err
	}
	if !info.Mode().IsRegular() {
		return errors.New("candidate resource is not a regular file")
	}
	return nil
}

func validateCandidateResources(raw *config.RawConfig, directory string) error {
	for _, providers := range []map[string]map[string]any{raw.ProxyProvider, raw.RuleProvider} {
		for name, mapping := range providers {
			kind, _ := mapping["type"].(string)
			if kind == "inline" {
				continue
			}
			path, _ := mapping["path"].(string)
			if path == "" {
				return fmt.Errorf("provider %s has no staged path", name)
			}
			if err := stagedCandidateFile(directory, C.Path.Resolve(path)); err != nil {
				return fmt.Errorf("provider %s: %w", name, err)
			}
		}
	}
	return nil
}

func preparedServers(raw *config.RawConfig, cfg *config.Config, providerOrder []string) ([]PreparedServer, error) {
	var servers []PreparedServer
	identities := make(map[string]bool)
	appendServer := func(proxy C.Proxy, provider string) error {
		if proxy == nil || proxy.Type() < C.Shadowsocks {
			return nil
		}
		id := "inline/" + base64.RawURLEncoding.EncodeToString([]byte(proxy.Name()))
		if provider != "" {
			id = "provider/" + base64.RawURLEncoding.EncodeToString([]byte(provider)) + "/" + base64.RawURLEncoding.EncodeToString([]byte(proxy.Name()))
		}
		if identities[id] {
			return fmt.Errorf("ambiguous server identity in provider %s: %s", provider, proxy.Name())
		}
		identities[id] = true
		servers = append(servers, PreparedServer{ID: id, Name: proxy.Name(), Target: proxy.Name(), Type: proxy.Type().String(), Provider: provider})
		return nil
	}
	for _, mapping := range raw.Proxy {
		name, _ := mapping["name"].(string)
		if err := appendServer(cfg.Proxies[name], ""); err != nil {
			return nil, err
		}
	}
	for _, name := range providerOrder {
		pd := cfg.Providers[name]
		if pd == nil || pd.VehicleType() == P.Compatible {
			return nil, fmt.Errorf("provider %s is shadowed by a proxy group", name)
		}
		for _, proxy := range pd.Proxies() {
			if err := appendServer(proxy, name); err != nil {
				return nil, err
			}
		}
	}
	return servers, nil
}

func candidateProviderOrder(buf []byte) ([]string, error) {
	var document yaml.Node
	if err := yaml.Unmarshal(buf, &document); err != nil {
		return nil, err
	}
	var names []string
	if len(document.Content) != 1 || document.Content[0].Kind != yaml.MappingNode {
		return nil, errors.New("configuration must be a mapping")
	}
	var visit func(*yaml.Node) error
	seen := make(map[string]bool)
	visiting := make(map[*yaml.Node]bool)
	visit = func(node *yaml.Node) error {
		if visiting[node] {
			return errors.New("recursive provider mapping")
		}
		visiting[node] = true
		defer delete(visiting, node)
		if node.Kind == yaml.AliasNode {
			return visit(node.Alias)
		}
		if node.Kind == yaml.SequenceNode {
			for _, child := range node.Content {
				if err := visit(child); err != nil {
					return err
				}
			}
			return nil
		}
		if node.Kind != yaml.MappingNode {
			return errors.New("provider definitions must be a mapping")
		}
		for i := 0; i < len(node.Content); i += 2 {
			key, value := node.Content[i], node.Content[i+1]
			if key.Tag == "!!merge" {
				if err := visit(value); err != nil {
					return err
				}
			} else if !seen[key.Value] {
				seen[key.Value] = true
				names = append(names, key.Value)
			}
		}
		return nil
	}
	root := document.Content[0]
	for i := 0; i < len(root.Content); i += 2 {
		if root.Content[i].Value == "proxy-providers" {
			if err := visit(root.Content[i+1]); err != nil {
				return nil, err
			}
		}
	}
	return names, nil
}

func reservePreparation(params PrepareConfigParams) (string, *preparedEntry, error) {
	preparations.Lock()
	defer preparations.Unlock()
	for handle, entry := range preparations.entries {
		if entry.config != nil && time.Since(entry.created) > 10*time.Minute {
			_ = entry.config.Close()
			delete(preparations.entries, handle)
		}
	}
	if params.Generation == preparations.activeGeneration {
		return "", nil, errors.New("generation is already active")
	}
	for _, entry := range preparations.entries {
		if entry.params.Generation == params.Generation {
			return "", nil, errors.New("generation is already being prepared")
		}
	}
	if len(preparations.entries) >= 8 {
		return "", nil, errors.New("too many prepared configurations")
	}
	handle := utils.NewUUIDV4().String()
	entry := &preparedEntry{params: params, baseVersion: preparations.version, created: time.Now()}
	preparations.entries[handle] = entry
	return handle, entry, nil
}

func handlePrepareConfig(params *PrepareConfigParams) (*PreparedConfigResult, error) {
	configMu.Lock()
	defer configMu.Unlock()
	return prepareConfigLocked(params)
}

func prepareConfigLocked(params *PrepareConfigParams) (_ *PreparedConfigResult, err error) {
	stage := "initialization"
	defer func() {
		if err != nil {
			err = &configPreparationError{Stage: stage, Err: err}
		}
	}()
	if params.Revision <= 0 {
		return nil, errors.New("invalid profile revision")
	}
	initialized, home := isInit.Load(), C.Path.HomeDir()
	if !initialized {
		return nil, errCoreNotInitialized
	}
	stage = "candidate_path"
	directory, err := candidateDirectory(home, params.Generation)
	if err != nil {
		return nil, err
	}
	stage = "reservation"
	handle, entry, err := reservePreparation(*params)
	if err != nil {
		return nil, err
	}
	accepted := false
	defer func() {
		if !accepted {
			preparations.Lock()
			delete(preparations.entries, handle)
			preparations.Unlock()
		}
	}()
	stage = "candidate_read"
	path := filepath.Join(directory, "effective.yaml")
	if params.Probe {
		path = filepath.Join(directory, "candidate.yaml")
	}
	if err := stagedCandidateFile(directory, path); err != nil {
		return nil, err
	}
	buf, err := os.ReadFile(path)
	if err != nil {
		return nil, err
	}
	stage = "config_decode"
	raw, err := config.UnmarshalRawConfig(buf)
	if err != nil {
		return nil, err
	}
	stage = "provider_paths"
	if err := validateCandidateResources(raw, directory); err != nil {
		return nil, err
	}
	stage = "provider_order"
	providerOrder, err := candidateProviderOrder(buf)
	if err != nil {
		return nil, err
	}
	stage = "config_parse"
	var required *candidateResourceRequired
	prepared, err := config.PrepareRawConfig(raw, config.PrepareOptions{ProviderNamespace: params.Generation, ResolveGeodata: func(name string) (string, error) {
		path := filepath.Join(directory, "geo", name)
		if err := stagedCandidateFile(directory, path); err != nil {
			if errors.Is(err, os.ErrNotExist) {
				required = &candidateResourceRequired{Name: name}
				return "", required
			}
			return "", err
		}
		return path, nil
	}})
	if err != nil {
		if required != nil {
			return nil, required
		}
		return nil, err
	}
	defer func() {
		if !accepted {
			_ = prepared.Close()
		}
	}()
	stage = "server_inventory"
	var servers []PreparedServer
	if err := prepared.Inspect(func(cfg *config.Config) error {
		servers, err = preparedServers(raw, cfg, providerOrder)
		if err != nil {
			return err
		}
		if len(servers) == 0 {
			return errors.New("configuration contains no usable proxy servers")
		}
		return nil
	}); err != nil {
		return nil, err
	}
	preparations.Lock()
	defer preparations.Unlock()
	if preparations.entries[handle] != entry || preparations.version != entry.baseVersion {
		return nil, errors.New("preparation was superseded")
	}
	entry.config = prepared
	accepted = true
	return &PreparedConfigResult{Handle: handle, Generation: params.Generation, Revision: params.Revision, Servers: servers}, nil
}

func handleActivateConfig(params *ActivateConfigParams) (*ActivatedConfigResult, error) {
	configMu.Lock()
	defer configMu.Unlock()
	return activateConfigLocked(params)
}

func activateConfigLocked(params *ActivateConfigParams) (*ActivatedConfigResult, error) {
	preparations.Lock()
	defer preparations.Unlock()
	entry := preparations.entries[params.Prepared.Handle]
	if entry != nil && time.Since(entry.created) > 10*time.Minute {
		delete(preparations.entries, params.Prepared.Handle)
		if entry.config != nil {
			_ = entry.config.Close()
		}
		entry = nil
	}
	if entry == nil || entry.config == nil || entry.params.Revision != params.Prepared.Revision || entry.baseVersion != preparations.version || !isInit.Load() {
		return nil, errStalePreparation
	}
	if entry.params.Probe {
		return nil, errors.New("inventory probe cannot be activated")
	}
	if err := entry.config.Inspect(func(cfg *config.Config) error {
		for group, target := range params.Setup.SelectedMap {
			proxy, ok := cfg.Proxies[group].(*adapter.Proxy)
			if !ok {
				continue
			}
			selector, ok := proxy.ProxyAdapter.(outboundgroup.SelectAble)
			if !ok {
				continue
			}
			if err := selector.Set(target); err != nil && (group == "GLOBAL" || strings.HasPrefix(group, "__flclash_"+entry.params.Generation+"_")) {
				return fmt.Errorf("invalid selection for %s: %w", group, err)
			}
		}
		return nil
	}); err != nil {
		return nil, err
	}
	applied := false
	defer func() {
		delete(preparations.entries, params.Prepared.Handle)
		preparations.version++
		if applied {
			preparations.activeGeneration = entry.params.Generation
		} else {
			_ = entry.config.Close()
		}
	}()
	var listenerError error
	err := entry.config.Activate(func(cfg *config.Config) {
		applied = true
		setTestURL(params.Setup.TestURL)
		currentConfig = cfg
		activeSnapshotGeneration = entry.params.Generation
		activeSnapshotRevision = entry.params.Revision
		hub.ApplyConfig(cfg)
		patchSelectGroup(params.Setup.SelectedMap)
		listenerError = updateListeners(cfg)
		reconcileGeoUpdater()
	})
	if err = errors.Join(err, listenerError); err != nil {
		return nil, err
	}
	return &ActivatedConfigResult{Generation: entry.params.Generation, Revision: entry.params.Revision}, nil
}

func handleDiscardConfig(params *PreparedConfigRef) (bool, error) {
	preparations.Lock()
	defer preparations.Unlock()
	entry := preparations.entries[params.Handle]
	if entry == nil {
		return false, nil
	}
	if entry.params.Revision != params.Revision {
		return false, errors.New("prepared revision does not match")
	}
	delete(preparations.entries, params.Handle)
	if entry.config != nil {
		return true, entry.config.Close()
	}
	return true, nil
}

func resetPreparations() {
	invalidatePreparations(true)
}

func invalidatePreparations(resetActive bool) {
	preparations.Lock()
	defer preparations.Unlock()
	preparations.version++
	if resetActive {
		preparations.activeGeneration = ""
	}
	for _, entry := range preparations.entries {
		if entry.config != nil {
			_ = entry.config.Close()
		}
	}
	clear(preparations.entries)
}
