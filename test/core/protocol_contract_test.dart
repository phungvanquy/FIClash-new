import 'dart:convert';
import 'dart:io';

import 'package:fl_clash/core/event.dart';
import 'package:fl_clash/core/desktop/model.dart';
import 'package:fl_clash/core/interface.dart';
import 'package:fl_clash/core/method.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

class _RecordingCoreHandler extends CoreHandlerInterface {
  final Map<CoreMethod, Object?> calls = {};

  @override
  Future<CoreLifecycleResult> start() async => const CoreLifecycleResult(
    revision: 1,
    outcome: CoreLifecycleOutcome.applied,
  );

  @override
  Future<CoreLifecycleResult> restart() => start();

  @override
  Future<CoreLifecycleResult> stop() => start();

  @override
  Future<CoreLifecycleResult> close() => start();

  @override
  Future<T?> invokeMethod<T>({
    required CoreMethod method,
    Object? arguments,
    Duration? timeout,
  }) async {
    calls[method] = arguments;
    final result = switch (method) {
      CoreMethod.initClash => true as T,
      CoreMethod.getRunState => {
        'session': 'native-session',
        'revision': 9,
        'requested': true,
        'active': true,
        'suspended': false,
        'tun': false,
        'mixedPort': 7890,
        'generation': '0123456789abcdef0123456789abcdef',
        'configRevision': 42,
      },
      CoreMethod.getTraffic ||
      CoreMethod.getTotalTraffic => {'up': 12, 'down': 34},
      CoreMethod.asyncTestDelay => {
        'name': 'DIRECT',
        'url': 'https://example.com',
        'value': 42,
      },
      CoreMethod.getConnections => {
        'connections': [
          {
            'id': 'connection-1',
            'metadata': {'network': 'tcp'},
            'upload': 0,
            'download': 0,
            'start': '2024-01-01',
            'chains': ['DIRECT'],
            'rule': 'DIRECT',
            'rulePayload': '',
          },
        ],
      },
      CoreMethod.getExternalProviders => [
        {
          'name': 'provider-1',
          'type': 'Proxy',
          'count': 1,
          'vehicle-type': 'HTTP',
          'update-at': '2024-01-01T00:00:00.000Z',
        },
      ],
      CoreMethod.getExternalProvider => {
        'name': 'provider-1',
        'type': 'Proxy',
        'count': 1,
        'vehicle-type': 'HTTP',
        'update-at': '2024-01-01T00:00:00.000Z',
      },
      CoreMethod.getConfig => {
        'mode': 'rule',
        'rule': ['MATCH,DIRECT'],
      },
      CoreMethod.getMemory => 2048,
      _ => '',
    };
    return result as T;
  }
}

class _FailingConfigCoreHandler extends _RecordingCoreHandler {
  @override
  Future<T?> invokeMethod<T>({
    required CoreMethod method,
    Object? arguments,
    Duration? timeout,
  }) async {
    if (method == CoreMethod.getConfig) {
      throw const CoreMethodException(
        code: 'core_error',
        message: 'config not found',
        details: {'path': '/missing.yaml'},
      );
    }
    return super.invokeMethod(
      method: method,
      arguments: arguments,
      timeout: timeout,
    );
  }
}

class _EmptyConfigCoreHandler extends _RecordingCoreHandler {
  @override
  Future<T?> invokeMethod<T>({
    required CoreMethod method,
    Object? arguments,
    Duration? timeout,
  }) async {
    if (method == CoreMethod.getConfig) {
      return null;
    }
    return super.invokeMethod(
      method: method,
      arguments: arguments,
      timeout: timeout,
    );
  }
}

class _PreparedCoreHandler extends _RecordingCoreHandler {
  _PreparedCoreHandler(this.fixture, {this.empty = false, this.error});

  final Map<String, dynamic> fixture;
  final bool empty;
  final CoreMethodException? error;

  @override
  Future<T?> invokeMethod<T>({
    required CoreMethod method,
    Object? arguments,
    Duration? timeout,
  }) async {
    calls[method] = arguments;
    if (error case final error?) throw error;
    if (empty) return null;
    final key = switch (method) {
      CoreMethod.prepareConfig => 'preparedResponse',
      CoreMethod.activateConfig => 'activatedResponse',
      CoreMethod.discardConfig => 'discardedResponse',
      _ => throw StateError('Unexpected method $method'),
    };
    return (fixture[key] as Map)['result'] as T;
  }
}

void main() {
  group('prepared configuration contract', () {
    late Map<String, dynamic> fixture;

    setUp(() async {
      fixture =
          jsonDecode(
                await File('test/fixtures/core_protocol.json').readAsString(),
              )
              as Map<String, dynamic>;
    });

    test('requests and responses match the shared Go fixture', () async {
      final handler = _PreparedCoreHandler(fixture);
      final prepare = PrepareConfigParams.fromJson(
        fixture['prepareCall']['arguments'] as Map<String, dynamic>,
      );
      final activate = ActivateConfigParams.fromJson(
        fixture['activateCall']['arguments'] as Map<String, dynamic>,
      );
      final discard = PreparedConfigRef.fromJson(
        fixture['discardCall']['arguments'] as Map<String, dynamic>,
      );
      final prepared = await handler.prepareConfig(prepare);
      final activated = await handler.activateConfig(activate);
      expect(await handler.discardConfig(discard), isTrue);
      expect(prepared.toJson(), fixture['preparedResponse']['result']);
      expect(activated.toJson(), fixture['activatedResponse']['result']);
      for (final entry in {
        CoreMethod.prepareConfig: 'prepareCall',
        CoreMethod.activateConfig: 'activateCall',
        CoreMethod.discardConfig: 'discardCall',
      }.entries) {
        final call = CoreMethodCall.fromJson(
          fixture[entry.value] as Map<String, dynamic>,
        );
        expect(call.method, entry.key);
        expect(handler.calls[entry.key], call.arguments);
      }
    });

    test('missing replies cannot be mistaken for success', () async {
      final handler = _PreparedCoreHandler(fixture, empty: true);
      final calls = [
        () => handler.prepareConfig(
          const PrepareConfigParams(generation: 'candidate', revision: 1),
        ),
        () => handler.activateConfig(
          const ActivateConfigParams(
            prepared: PreparedConfigRef(handle: 'handle', revision: 1),
            setup: SetupParams(selectedMap: {}, testUrl: 'test'),
          ),
        ),
        () => handler.discardConfig(
          const PreparedConfigRef(handle: 'handle', revision: 1),
        ),
      ];
      for (final call in calls) {
        await expectLater(
          call(),
          throwsA(
            isA<CoreMethodException>().having(
              (error) => error.code,
              'code',
              'no_response',
            ),
          ),
        );
      }
    });

    test('preparation retains structured failure details', () async {
      const error = CoreMethodException(
        code: 'prepare_failed',
        message: 'invalid provider',
        details: {'revision': 42},
      );
      final handler = _PreparedCoreHandler(fixture, error: error);
      await expectLater(
        handler.prepareConfig(
          const PrepareConfigParams(generation: 'candidate', revision: 42),
        ),
        throwsA(same(error)),
      );
    });
  });

  test('method call keeps structured arguments', () async {
    final fixture =
        json.decode(
              await File('test/fixtures/core_protocol.json').readAsString(),
            )
            as Map<String, dynamic>;
    final call = CoreMethodCall.fromJson(
      Map<String, Object?>.from(fixture['methodCall'] as Map),
    );

    expect(call.method, CoreMethod.updateConfig);
    expect(call.arguments, isA<Map<String, dynamic>>());
    expect((call.arguments as Map)['mixed-port'], 7890);
    expect(call.toJson(), containsPair('arguments', call.arguments));
    expect(call.toJson(), isNot(contains('data')));
  });

  test('core interface sends structured request parameters', () async {
    final handler = _RecordingCoreHandler();

    await handler.init(const InitParams(homeDir: '/tmp/flclash', version: 35));
    await handler.setupConfig(
      const SetupParams(selectedMap: {'GLOBAL': 'DIRECT'}, testUrl: 'test'),
    );
    await handler.changeProxy(
      const ChangeProxyParams(groupName: 'GLOBAL', proxyName: 'DIRECT'),
    );
    await handler.sideLoadExternalProvider(providerName: 'provider', data: 'x');
    await handler.asyncTestDelay('https://example.com', 'DIRECT');
    await handler.clearEffect(42);

    for (final method in [
      CoreMethod.initClash,
      CoreMethod.setupConfig,
      CoreMethod.changeProxy,
      CoreMethod.sideLoadExternalProvider,
      CoreMethod.asyncTestDelay,
    ]) {
      expect(handler.calls[method], isA<Map>());
    }
    expect(handler.calls[CoreMethod.clearEffect], 42);
  });

  test('event contract accepts batches and legacy single events', () async {
    final fixture =
        json.decode(
              await File('test/fixtures/core_protocol.json').readAsString(),
            )
            as Map<String, dynamic>;
    final call = CoreMethodCall.fromJson(
      Map<String, Object?>.from(fixture['eventCall'] as Map),
    );

    final events = coreEventsFromData(call.arguments);
    expect(events, hasLength(2));
    expect(events.first.type, CoreEventType.loaded);
    expect(events.last.type, CoreEventType.delay);

    final legacy = coreEventsFromData({'type': 'loaded', 'data': 'provider-b'});
    expect(legacy.single.data, 'provider-b');
  });

  test('event contract skips malformed entries without dropping the batch', () {
    final events = coreEventsFromData([
      {'type': 'loaded', 'data': 'provider-a'},
      {'type': 'invalid-event', 'data': null},
      {'type': 'loaded', 'data': 'provider-b'},
    ]);

    expect(events.map((event) => event.data), ['provider-a', 'provider-b']);
  });

  test('core interface converts structured method results', () async {
    final handler = _RecordingCoreHandler();

    expect(await handler.getTraffic(false), const Traffic(up: 12, down: 34));
    expect(
      await handler.getTotalTraffic(false),
      const Traffic(up: 12, down: 34),
    );
    expect(
      await handler.asyncTestDelay('https://example.com', 'DIRECT'),
      const Delay(name: 'DIRECT', url: 'https://example.com', value: 42),
    );
    expect((await handler.getConnections()).single.id, 'connection-1');
    expect((await handler.getExternalProviders()).single.name, 'provider-1');
    expect(
      (await handler.getExternalProvider('provider-1'))?.name,
      'provider-1',
    );
    expect(await handler.getConfig('/config.yaml'), {
      'mode': 'rule',
      'rule': ['MATCH,DIRECT'],
    });
    expect(await handler.getMemory(), 2048);
  });

  test('getConfig preserves structured core errors', () async {
    final handler = _FailingConfigCoreHandler();

    await expectLater(
      handler.getConfig('/missing.yaml'),
      throwsA(
        isA<CoreMethodException>()
            .having((error) => error.code, 'code', 'core_error')
            .having((error) => error.details, 'details', {
              'path': '/missing.yaml',
            }),
      ),
    );
  });

  test('getConfig rejects empty transport results', () async {
    final handler = _EmptyConfigCoreHandler();

    await expectLater(
      handler.getConfig('/config.yaml'),
      throwsA(
        isA<CoreMethodException>().having(
          (error) => error.code,
          'code',
          'empty_result',
        ),
      ),
    );
  });

  test('passive run-state RPC uses the shared Go observation shape', () async {
    final fixture =
        jsonDecode(
              await File('test/fixtures/core_protocol.json').readAsString(),
            )
            as Map<String, dynamic>;
    final handler = _RecordingCoreHandler();
    final state = await handler.getRunState();
    expect(
      state,
      CoreRunObservation.fromJson(fixture['runStateResponse']['result']),
    );
    expect(handler.calls.keys, [CoreMethod.getRunState]);
    expect(handler.calls[CoreMethod.getRunState], isNull);
    final events = coreEventsFromData({
      'type': 'runState',
      'data': state.toJson(),
    });
    expect(events.single.type, CoreEventType.runState);
    expect(CoreRunObservation.fromJson(events.single.data), state);
  });

  test('method response separates result and structured errors', () async {
    final fixture =
        json.decode(
              await File('test/fixtures/core_protocol.json').readAsString(),
            )
            as Map<String, dynamic>;
    final success = CoreMethodResponse.fromJson(
      Map<String, Object?>.from(fixture['successResponse'] as Map),
    );
    final structured = CoreMethodResponse.fromJson(
      Map<String, Object?>.from(fixture['structuredResponse'] as Map),
    );
    final failure = CoreMethodResponse.fromJson(
      Map<String, Object?>.from(fixture['errorResponse'] as Map),
    );

    expect(success.unwrap<String>(), '');
    expect(success.toJson(), containsPair('result', ''));
    expect(structured.result, isA<Map>());
    expect(structured.result, isNot(isA<String>()));
    expect(structured.unwrap<Map<String, dynamic>>()?['up'], 12);
    expect(
      () => failure.unwrap<Object?>(),
      throwsA(
        isA<CoreMethodException>()
            .having((error) => error.code, 'code', 'core_error')
            .having((error) => error.message, 'message', 'config not found'),
      ),
    );
    expect(failure.toJson(), contains('error'));
    expect(failure.toJson(), isNot(contains('code')));
  });
}
