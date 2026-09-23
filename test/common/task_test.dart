import 'dart:io';
import 'dart:convert';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart';
import 'package:yaml/yaml.dart';

int _double(int value) => value * 2;

void main() {
  group('managed VPN configuration', () {
    const generation = '0123456789abcdef0123456789abcdef';
    const prefix = '__flclash_${generation}_';
    const testUrl = 'https://www.gstatic.com/generate_204';
    final catalog = [
      const VpnServer(
        id: 'inline/U2hhcmVk',
        name: 'Shared',
        target: 'Shared',
        type: 'Socks5',
      ),
      const VpnServer(
        id: 'provider/WnVsdQ/U2hhcmVk',
        name: 'Shared',
        target: 'Shared',
        type: 'Socks5',
        provider: 'Zulu',
      ),
      const VpnServer(
        id: 'provider/WnVsdQ/bmFtZVsxXWAuKg',
        name: 'name[1]`.*',
        target: 'name[1]`.*',
        type: 'Socks5',
        provider: 'Zulu',
      ),
      const VpnServer(
        id: 'provider/QWxwaGE/U2hhcmVk',
        name: 'Shared',
        target: 'Shared',
        type: 'Socks5',
        provider: 'Alpha',
      ),
    ];

    Map<String, dynamic> source() =>
        jsonDecode(
              jsonEncode(
                loadYaml(
                  File('test/fixtures/vpn_inventory.yaml').readAsStringSync(),
                ),
              ),
            )
            as Map<String, dynamic>;

    test('matches the shared Core routing fixture without mutating source', () {
      final raw = source();
      final before = jsonEncode(raw);
      final result = buildVpnConfiguration(
        source: raw,
        catalog: catalog,
        generation: generation,
        testUrl: testUrl,
      );
      expect(
        result.effective,
        loadYaml(File('test/fixtures/vpn_managed.yaml').readAsStringSync()),
      );
      expect(jsonEncode(raw), before);
      expect(result.servers.map((server) => server.target), [
        'Shared',
        '${prefix}server_1',
        '${prefix}server_2',
        '${prefix}server_3',
      ]);
      expect(result.selectedMap, {
        '${prefix}select': '${prefix}auto',
        'GLOBAL': '${prefix}select',
      });
    });

    test('allocates around source collisions and retains fallback order', () {
      final raw = source();
      (raw['proxy-groups'] as List).add({
        'name': '${prefix}auto',
        'type': 'select',
        'proxies': ['Shared'],
      });
      final result = buildVpnConfiguration(
        source: raw,
        catalog: catalog,
        generation: generation,
        testUrl: testUrl,
        selection: const VpnSelection.fallback(),
      );
      expect(result.groups.auto, '${prefix}auto_1');
      final groups = result.effective['proxy-groups'] as List;
      final auto =
          groups.firstWhere((item) => item['name'] == result.groups.auto)
              as Map;
      final fallback =
          groups.firstWhere((item) => item['name'] == result.groups.fallback)
              as Map;
      expect(auto['proxies'], fallback['proxies']);
      expect(
        auto['proxies'],
        result.servers.map((server) => server.target).toList(),
      );
      expect(auto['empty-fallback'], 'REJECT');
      expect(fallback['empty-fallback'], 'REJECT');
      expect(
        result.selectedMap[result.groups.selector],
        result.groups.fallback,
      );
    });

    test(
      'preserves advanced routing and protocol fields across mode builds',
      () {
        final raw = source();
        final proxy = (raw['proxies'] as List).first as Map;
        proxy['network'] = 'ws';
        proxy['ws-opts'] = {
          'path': '/api?token=a%2Bb',
          'headers': {'Host': 'example.test'},
        };
        proxy['reality-opts'] = {
          'public-key': 'opaque',
          'short-id': '00',
          'support-x25519mlkem768': false,
          'mldsa65-verify': 'verification-key',
        };
        proxy['flow'] = 'xtls-rprx-vision';
        proxy['encryption'] = 'opaque-encryption-settings';
        proxy['packet-encoding'] = 'xudp';
        proxy['xhttp-opts'] = {
          'path': '/upload',
          'mode': 'packet-up',
          'headers': {'X-Interop': 'preserved'},
          'download-settings': {
            'server': 'download.example.test',
            'servername': 'download-sni.example.test',
            'client-fingerprint': 'safari',
            'reality-opts': {
              'public-key': 'download-public-key',
              'short-id': 'aabb',
              'support-x25519mlkem768': true,
              'mldsa65-verify': 'download-verification-key',
            },
          },
        };
        final originalGlobal = {
          'name': 'GLOBAL',
          'type': 'select',
          'proxies': ['Outer'],
        };
        (raw['proxy-groups'] as List).add(originalGlobal);
        const advancedSelections = {'Outer': 'Nested', 'GLOBAL': 'Outer'};
        final simple = buildVpnConfiguration(
          source: raw,
          catalog: catalog,
          generation: generation,
          testUrl: testUrl,
          selection: VpnSelection.server(catalog.last.id),
          advancedSelections: advancedSelections,
        );
        expect(simple.effective['mode'], 'global');
        expect(simple.selectedMap['GLOBAL'], simple.groups.selector);
        expect(
          simple.selectedMap[simple.groups.selector],
          simple.servers.last.target,
        );
        final custom = buildVpnConfiguration(
          source: raw,
          catalog: catalog,
          generation: generation,
          testUrl: testUrl,
          routing: VpnRoutingMode.custom,
          advancedMode: Mode.rule,
          advancedSelections: advancedSelections,
        );
        expect(custom.effective['mode'], 'rule');
        expect(custom.effective['rules'], raw['rules']);
        expect(
          (custom.effective['proxy-groups'] as List)
              .where((item) => item['name'] == 'GLOBAL')
              .single,
          originalGlobal,
        );
        expect(custom.selectedMap['GLOBAL'], 'Outer');
        expect(simple.effective['proxies'], raw['proxies']);
        expect(custom.effective['proxies'], raw['proxies']);
        expect(advancedSelections, {'Outer': 'Nested', 'GLOBAL': 'Outer'});
      },
    );

    test(
      'retains identity across generations and replaces missing selection with Auto',
      () {
        final raw = source();
        final selected = VpnSelection.server(catalog.last.id);
        final refreshed = buildVpnConfiguration(
          source: raw,
          catalog: catalog,
          generation: 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
          testUrl: testUrl,
          selection: selected,
        );
        expect(refreshed.selection, selected);
        expect(
          refreshed.selectedMap[refreshed.groups.selector],
          refreshed.servers.last.target,
        );
        final missing = buildVpnConfiguration(
          source: raw,
          catalog: catalog.sublist(0, 3),
          generation: generation,
          testUrl: testUrl,
          selection: selected,
        );
        expect(missing.selection, const VpnSelection.auto());
      },
    );

    test('rejects empty or ambiguous catalogs', () {
      for (final invalid in [
        <VpnServer>[],
        [catalog.first, catalog.first],
      ]) {
        expect(
          () => buildVpnConfiguration(
            source: source(),
            catalog: invalid,
            generation: generation,
            testUrl: testUrl,
          ),
          throwsFormatException,
        );
      }
    });
  });

  test('encoding helpers round-trip structured data', () async {
    final encoded = await encodeJSONTask({
      'name': 'FlClash',
      'values': [1, true, null],
    });
    final decoded = await decodeJSONTask<Map<String, dynamic>>(encoded);

    expect(decoded['name'], 'FlClash');
    expect(decoded['values'], [1, true, null]);
    expect(await encodeYamlTask({'enabled': true}), contains('enabled: true'));
    expect(await encodeMD5Task('abc'), '900150983cd24fb0d6963f7d28e17f72');
  });

  test('toGroupsTask converts, selects, and sorts core proxy data', () async {
    final proxies = <String, dynamic>{
      'Selector': {
        'name': 'Selector',
        'type': 'Selector',
        'now': 'Beta',
        'all': ['Zulu', 'Beta', 'missing'],
      },
      'Direct': {'name': 'Direct', 'type': 'Direct'},
      'Zulu': {'name': 'Zulu', 'type': 'Direct'},
      'Beta': {'name': 'Beta', 'type': 'Direct'},
    };
    final groups = await toGroupsTask(
      ComputeGroupsState(
        proxiesData: ProxiesData(
          all: const ['Selector', 'Direct'],
          proxies: proxies,
        ),
        sortType: ProxiesSortType.name,
        delayMap: const {},
        selectedMap: const {'Selector': 'Beta'},
        defaultTestUrl: 'https://example.com/generate_204',
      ),
    );

    expect(groups, hasLength(1));
    expect(groups.single.name, 'Selector');
    expect(groups.single.all.map((proxy) => proxy.name), ['Beta', 'Zulu']);
  });

  test(
    'clashConfigTask parses core config data off the main isolate',
    () async {
      final configMap = <String, dynamic>{
        'proxies': [
          {'name': 'Alpha', 'type': 'ss'},
          {'name': 'Beta', 'type': 'vmess'},
        ],
        'proxy-groups': [
          {
            'name': 'Auto',
            'type': 'url-test',
            'proxies': ['Alpha', 'Beta'],
          },
        ],
        'rules': ['DOMAIN,example.com,Auto'],
        'proxy-providers': {
          'provider': {'type': 'http'},
        },
        'rule-providers': {
          'ruleSet': {'type': 'http'},
        },
        'sub-rules': {'nested': []},
      };

      final clashConfig = await clashConfigTask(configMap);

      expect(clashConfig.proxies.map((item) => item.name), ['Alpha', 'Beta']);
      expect(clashConfig.proxyGroups.single.type, GroupType.URLTest);
      expect(clashConfig.rules.single.ruleTarget, 'Auto');
      expect(clashConfig.rules.single.content, 'example.com');
      expect(clashConfig.proxyProviders, ['provider']);
      expect(clashConfig.ruleProviders, ['ruleSet']);
      expect(clashConfig.subRules, ['nested']);
      expect(clashConfig.proxyTypeMap, {
        'Alpha': 'ss',
        'Beta': 'vmess',
        'Auto': 'url-test',
      });
    },
  );

  test('buildClashConfig indexes group types by their clash value', () {
    final clashConfig = buildClashConfig(<String, dynamic>{
      'proxies': [
        {'name': 'Alpha', 'type': 'ss'},
      ],
      'proxy-groups': [
        {
          'name': 'Fallback',
          'type': 'fallback',
          'proxies': ['Alpha'],
        },
      ],
    });

    expect(clashConfig.proxyTypeMap, {'Alpha': 'ss', 'Fallback': 'fallback'});
    expect(clashConfig.rules, isEmpty);
  });

  test('toGroupsTask leaves the source proxy map untouched', () async {
    final proxies = <String, dynamic>{
      'Selector': {
        'name': 'Selector',
        'type': 'Selector',
        'all': ['Beta'],
      },
      'Beta': {'name': 'Beta', 'type': 'Direct'},
    };
    final state = ComputeGroupsState(
      proxiesData: ProxiesData(all: const ['Selector'], proxies: proxies),
      sortType: ProxiesSortType.none,
      delayMap: const {},
      selectedMap: const {},
      defaultTestUrl: '',
    );

    await buildGroups(state);
    await buildGroups(state);

    expect(proxies['Selector']['all'], ['Beta']);
  });

  test('toGroupsTask returns empty data without proxies', () async {
    final groups = await toGroupsTask(
      const ComputeGroupsState(
        proxiesData: ProxiesData(proxies: {}, all: []),
        sortType: ProxiesSortType.none,
        delayMap: {},
        selectedMap: {},
        defaultTestUrl: '',
      ),
    );

    expect(groups, isEmpty);
  });

  test(
    'makeRealProfileTask normalizes runtime config and added rules',
    () async {
      final rawConfig = await decodeJSONTask<Map<String, dynamic>>(
        await encodeJSONTask({
          'dns': {
            'enable': true,
            'nameserver': ['1.1.1.1'],
          },
          'sniffer': {
            'sniff': {
              'HTTP': {
                'ports': [80, '443'],
              },
            },
          },
          'proxy-providers': {
            'remote': {'type': 'http', 'url': 'https://example.com/proxy.yaml'},
            'file': {'type': 'file', 'path': './local.yaml'},
          },
          'rule-providers': {
            'remote': {'type': 'http', 'url': 'https://example.com/rule.yaml'},
          },
          'rules': ['DOMAIN,existing.example,DIRECT', 'MATCH,Original'],
        }),
      );
      final result = await makeRealProfileTask(
        MakeRealProfileState(
          profilesPath: '/profiles',
          profileId: 7,
          rawConfig: rawConfig,
          realPatchConfig: const PatchClashConfig(
            mixedPort: 7893,
            port: 7890,
            socksPort: 7891,
            redirPort: 7892,
            tproxyPort: 7894,
            allowLan: true,
            ipv6: true,
            hosts: {'router.local': '192.168.1.1,192.168.1.2'},
          ),
          overrideDns: false,
          appendSystemDns: true,
          proxyGroups: const [],
          rules: const [],
          addedRules: const [
            Rule(
              ruleAction: RuleAction.DOMAIN_SUFFIX,
              content: 'added.example',
              ruleTarget: 'MATCH',
            ),
          ],
          defaultUA: 'FlClash-Test',
        ),
      );
      final config = loadYaml(result.yaml) as YamlMap;

      expect(result.md5, hasLength(32));
      expect(config['mixed-port'], 7893);
      expect(config['allow-lan'], true);
      expect(config['global-ua'], 'FlClash-Test');
      expect(config['profile']['store-selected'], false);
      expect(
        config['dns']['nameserver'],
        containsAll(['1.1.1.1', 'system://']),
      );
      expect(config['hosts']['router.local'], ['192.168.1.1', '192.168.1.2']);
      expect(config['sniffer']['sniff']['HTTP']['ports'], ['80', '443']);
      expect(
        config['proxy-providers']['remote']['path'],
        startsWith('/profiles/providers/7/proxies/'),
      );
      expect(
        config['rule-providers']['remote']['path'],
        startsWith('/profiles/providers/7/rules/'),
      );
      expect(config['rules'], [
        'DOMAIN-SUFFIX,added.example,Original',
        'DOMAIN,existing.example,DIRECT',
        'MATCH,Original',
      ]);
    },
  );

  test(
    'makeRealProfileTask routes MATCH placeholders to matchTarget',
    () async {
      final rawConfig = await decodeJSONTask<Map<String, dynamic>>(
        await encodeJSONTask({
          'proxies': [],
          'rules': ['DOMAIN,existing.example,DIRECT', 'MATCH,Original'],
        }),
      );
      final state = MakeRealProfileState(
        profilesPath: '/profiles',
        profileId: 7,
        rawConfig: rawConfig,
        realPatchConfig: const PatchClashConfig(),
        overrideDns: false,
        appendSystemDns: false,
        proxyGroups: const [],
        rules: const [],
        addedRules: const [
          Rule(
            ruleAction: RuleAction.DOMAIN_SUFFIX,
            content: 'added.example',
            ruleTarget: 'MATCH',
          ),
        ],
        defaultUA: 'FlClash-Test',
        matchTarget: 'HK',
      );

      final overridden = await makeRealProfileTask(state);
      expect((loadYaml(overridden.yaml) as YamlMap)['rules'], [
        'DOMAIN-SUFFIX,added.example,HK',
        'DOMAIN,existing.example,DIRECT',
        'MATCH,Original',
      ]);

      final blank = await makeRealProfileTask(state.copyWith(matchTarget: ' '));
      expect(
        (loadYaml(blank.yaml) as YamlMap)['rules'].first,
        'DOMAIN-SUFFIX,added.example,Original',
      );
    },
  );

  // The core re-reads these two keys out of the generated config on every
  // profile apply and adopts whatever it finds, so a subscription that ships
  // them would otherwise decide whether GEO databases auto-update — including
  // switching the updater back on after the user turned it off.
  test(
    'makeRealProfileTask lets the app setting own the geo updater',
    () async {
      final rawConfig = await decodeJSONTask<Map<String, dynamic>>(
        await encodeJSONTask({
          'geo-auto-update': true,
          'geo-update-interval': 6,
        }),
      );

      final result = await makeRealProfileTask(
        MakeRealProfileState(
          profilesPath: '/profiles',
          profileId: 11,
          rawConfig: rawConfig,
          realPatchConfig: const PatchClashConfig(
            geoAutoUpdate: false,
            geoUpdateInterval: 48,
          ),
          overrideDns: false,
          appendSystemDns: false,
          proxyGroups: const [],
          rules: const [],
          addedRules: const [],
          defaultUA: 'FlClash-Test',
        ),
      );
      final config = loadYaml(result.yaml) as YamlMap;

      expect(config['geo-auto-update'], false);
      expect(config['geo-update-interval'], 48);
    },
  );

  // A profile-shipped loopback skip-auth-prefixes would bypass the credentials.
  test('makeRealProfileTask lets the app own local authentication', () async {
    final rawConfig = await decodeJSONTask<Map<String, dynamic>>(
      await encodeJSONTask({
        'authentication': ['subscription:injected'],
        'skip-auth-prefixes': ['127.0.0.1/32'],
      }),
    );
    final state = MakeRealProfileState(
      profilesPath: '/profiles',
      profileId: 12,
      rawConfig: rawConfig,
      realPatchConfig: const PatchClashConfig(),
      overrideDns: false,
      appendSystemDns: false,
      proxyGroups: const [],
      rules: const [],
      addedRules: const [],
      defaultUA: 'FlClash-Test',
      authentication: const ['user:pass'],
    );

    final enabled = await makeRealProfileTask(state);
    final enabledConfig = loadYaml(enabled.yaml) as YamlMap;
    expect(enabledConfig['authentication'], ['user:pass']);
    expect(enabledConfig['skip-auth-prefixes'], isEmpty);

    final disabled = await makeRealProfileTask(
      state.copyWith(authentication: const []),
    );
    final disabledConfig = loadYaml(disabled.yaml) as YamlMap;
    expect(disabledConfig['authentication'], isEmpty);
    expect(disabledConfig['skip-auth-prefixes'], isEmpty);
  });

  test('makeRealProfileTask overrides DNS and explicit custom data', () async {
    final result = await makeRealProfileTask(
      const MakeRealProfileState(
        profilesPath: '/profiles',
        profileId: 9,
        rawConfig: {},
        realPatchConfig: PatchClashConfig(),
        overrideDns: true,
        appendSystemDns: false,
        proxyGroups: [
          ProxyGroup(
            id: 1,
            name: 'Select',
            type: GroupType.Selector,
            proxies: ['DIRECT'],
          ),
        ],
        rules: [
          Rule(
            ruleAction: RuleAction.DOMAIN,
            content: 'custom.example',
            ruleTarget: 'DIRECT',
          ),
        ],
        addedRules: [],
        defaultUA: 'Fallback-UA',
      ),
    );
    final config = loadYaml(result.yaml) as YamlMap;

    expect(config['dns']['enable'], true);
    expect(config['dns']['nameserver'], isNot(contains('system://')));
    expect(config['proxy-groups'], hasLength(1));
    expect(config['rules'], ['DOMAIN,custom.example,DIRECT']);
  });

  test('makeRealProfileTask keeps the DNS keys it cannot edit', () async {
    final rawConfig = await decodeJSONTask<Map<String, dynamic>>(
      await encodeJSONTask({
        'dns': {
          'enable': false,
          'direct-nameserver': ['223.5.5.5'],
          'proxy-server-nameserver-policy': {
            'www.example.com': ['8.8.8.8'],
          },
          'nameserver': ['9.9.9.9'],
        },
        'proxy-providers': {
          'first': {'type': 'http', 'url': 'https://example.com/shared.yaml'},
          'second': {'type': 'http', 'url': 'https://example.com/shared.yaml'},
        },
      }),
    );

    final result = await makeRealProfileTask(
      MakeRealProfileState(
        profilesPath: '/profiles',
        profileId: 13,
        rawConfig: rawConfig,
        realPatchConfig: const PatchClashConfig(),
        overrideDns: false,
        appendSystemDns: false,
        proxyGroups: const [],
        rules: const [],
        addedRules: const [],
        defaultUA: 'FlClash-Test',
      ),
    );
    final config = loadYaml(result.yaml) as YamlMap;

    expect(config['dns']['direct-nameserver'], ['223.5.5.5']);
    expect(config['dns']['proxy-server-nameserver-policy'], {
      'www.example.com': ['8.8.8.8'],
    });
    expect(config['dns']['nameserver'], isNot(contains('system://')));
    expect(
      config['proxy-providers']['first']['path'],
      isNot(config['proxy-providers']['second']['path']),
    );
  });

  group('makeRealProfileTask interface-name mode', () {
    Future<YamlMap> runWith(PatchClashConfig realPatchConfig) async {
      final rawConfig = await decodeJSONTask<Map<String, dynamic>>(
        await encodeJSONTask({'interface-name': 'en0'}),
      );

      final result = await makeRealProfileTask(
        MakeRealProfileState(
          profilesPath: '/profiles',
          profileId: 13,
          rawConfig: rawConfig,
          realPatchConfig: realPatchConfig,
          overrideDns: false,
          appendSystemDns: false,
          proxyGroups: const [],
          rules: const [],
          addedRules: const [],
          defaultUA: 'FlClash-Test',
        ),
      );
      return loadYaml(result.yaml) as YamlMap;
    }

    // Default mode, so a subscription value must not survive into the
    // generated config.
    test('clear forces interface-name empty', () async {
      final config = await runWith(const PatchClashConfig());

      expect(config['interface-name'], '');
    });

    test('follow leaves the profile value untouched', () async {
      final config = await runWith(
        const PatchClashConfig(interfaceNameMode: InterfaceNameMode.follow),
      );

      expect(config['interface-name'], 'en0');
    });

    test('custom writes the configured interface name', () async {
      final config = await runWith(
        const PatchClashConfig(
          interfaceNameMode: InterfaceNameMode.custom,
          interfaceName: 'eth0',
        ),
      );

      expect(config['interface-name'], 'eth0');
    });
  });

  group('makeRealProfileTask legacy provider file migration', () {
    late Directory tempDir;
    const url = 'https://example.com/proxy.yaml';
    const name = 'remote';

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('task_test_providers');
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    Future<({String legacyPath, String newPath})> runMigration({
      bool staging = false,
    }) async {
      final providerDir = join(
        tempDir.path,
        providersDirectoryName,
        '17',
        proxiesProviderDirectoryName,
      );
      final legacyPath = join(providerDir, url.toMd5());
      final newPath = join(providerDir, '$name@$url'.toMd5());

      final result = await makeRealProfileTask(
        MakeRealProfileState(
          profilesPath: tempDir.path,
          profileId: 17,
          rawConfig: {
            'proxy-providers': {
              name: {'type': 'http', 'url': url},
            },
          },
          realPatchConfig: const PatchClashConfig(),
          overrideDns: false,
          appendSystemDns: false,
          proxyGroups: const [],
          rules: const [],
          addedRules: const [],
          defaultUA: 'FlClash-Test',
          confineProviderPaths: !staging,
        ),
      );
      final config = loadYaml(result.yaml) as YamlMap;
      expect(config['proxy-providers'][name]['path'], staging ? null : newPath);
      return (legacyPath: legacyPath, newPath: newPath);
    }

    test('renames a file cached under the legacy url-only key', () async {
      final providerDir = join(
        tempDir.path,
        providersDirectoryName,
        '17',
        proxiesProviderDirectoryName,
      );
      await Directory(providerDir).create(recursive: true);
      final legacyFile = File(join(providerDir, url.toMd5()));
      await legacyFile.writeAsString('cached-provider-data');

      final paths = await runMigration();

      expect(File(paths.newPath).existsSync(), isTrue);
      expect(await File(paths.newPath).readAsString(), 'cached-provider-data');
      expect(File(paths.legacyPath).existsSync(), isFalse);
    });

    test('is a no-op when no legacy file exists', () async {
      final paths = await runMigration();

      expect(File(paths.legacyPath).existsSync(), isFalse);
      expect(File(paths.newPath).existsSync(), isFalse);
    });

    test(
      'staging never migrates or rewrites the live provider cache',
      () async {
        final providerDir = join(
          tempDir.path,
          providersDirectoryName,
          '17',
          proxiesProviderDirectoryName,
        );
        await Directory(providerDir).create(recursive: true);
        final legacyFile = File(join(providerDir, url.toMd5()));
        await legacyFile.writeAsString('live-provider-data');

        final paths = await runMigration(staging: true);

        expect(File(paths.newPath).existsSync(), isFalse);
        expect(await legacyFile.readAsString(), 'live-provider-data');
      },
    );
  });

  test('log and list tasks produce stable mapped output', () async {
    final logs = [
      const Log(
        logLevel: LogLevel.info,
        payload: 'first',
        dateTime: '2026-07-26 10:00:00',
      ),
      const Log(
        logLevel: LogLevel.error,
        payload: 'second',
        dateTime: '2026-07-26 10:00:01',
      ),
    ];

    final encoded = await encodeLogsTask(logs);

    expect(encoded, contains('first'));
    expect(encoded, contains('\n'));
    expect(await mapListTask([1, 2, 3], _double), [2, 4, 6]);
  });
}
