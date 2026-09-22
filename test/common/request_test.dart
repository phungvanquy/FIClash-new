import 'dart:async';

import 'package:dio/dio.dart';
import 'package:fl_clash/common/request.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _SubscriptionClient extends Mock implements Dio {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => registerFallbackValue(CancelToken()));

  test(
    'VPN resource downloads preserve tokens, headers, and cancellation',
    () async {
      final client = _SubscriptionClient();
      final cancel = CancelToken();
      const url = 'https://example.test/sub?token=a%2Bb&extra=%252F';
      Options? options;
      when(
        () => client.get<List<int>>(
          url,
          cancelToken: any(named: 'cancelToken'),
          options: any(named: 'options'),
        ),
      ).thenAnswer((invocation) async {
        options = invocation.namedArguments[#options] as Options;
        return Response(
          data: [1, 2, 3],
          requestOptions: RequestOptions(path: url),
          headers: Headers.fromMap({
            'content-disposition': ['attachment; filename="VPN config.yaml"'],
            'subscription-userinfo': [
              'upload=1; broken; download=invalid; total=200',
            ],
          }),
        );
      });
      final response = await Request(subscriptionClient: client)
          .fetchVpnResource(url, {
            'Authorization': ['token'],
          }, cancel);
      expect(response.bytes, [1, 2, 3]);
      expect(response.filename, 'VPN config.yaml');
      expect(response.subscriptionInfo!.upload, 1);
      expect(response.subscriptionInfo!.download, 0);
      expect(response.subscriptionInfo!.total, 200);
      expect(options!.headers, {
        'Authorization': ['token'],
      });
      expect(options!.responseType, ResponseType.bytes);
      verify(
        () => client.get<List<int>>(
          url,
          cancelToken: any(named: 'cancelToken'),
          options: any(named: 'options'),
        ),
      ).called(1);
    },
  );

  test(
    'download deadline cancels HTTP without cancelling the parent request',
    () async {
      final client = _SubscriptionClient();
      final parent = CancelToken();
      final pending = Completer<Response<List<int>>>();
      late CancelToken transfer;
      when(
        () => client.get<List<int>>(
          any(),
          cancelToken: any(named: 'cancelToken'),
          options: any(named: 'options'),
        ),
      ).thenAnswer((call) {
        transfer = call.namedArguments[#cancelToken] as CancelToken;
        return pending.future;
      });
      await expectLater(
        Request(
          subscriptionClient: client,
          vpnDownloadTimeout: const Duration(milliseconds: 10),
        ).fetchVpnResource('https://example.test/slow', const {}, parent),
        throwsA(isA<TimeoutException>()),
      );
      expect(transfer.isCancelled, isTrue);
      expect(parent.isCancelled, isFalse);
      pending.complete(
        Response(
          data: [1],
          requestOptions: RequestOptions(path: '/slow'),
        ),
      );
    },
  );

  test('parent cancellation reaches the in-flight HTTP transfer', () async {
    final client = _SubscriptionClient();
    final parent = CancelToken();
    late CancelToken transfer;
    when(
      () => client.get<List<int>>(
        any(),
        cancelToken: any(named: 'cancelToken'),
        options: any(named: 'options'),
      ),
    ).thenAnswer((call) async {
      transfer = call.namedArguments[#cancelToken] as CancelToken;
      throw await transfer.whenCancel;
    });
    final pending = Request(
      subscriptionClient: client,
    ).fetchVpnResource('https://example.test/slow', const {}, parent);
    final expectation = expectLater(pending, throwsA(isA<DioException>()));
    parent.cancel();
    await expectation;
    expect(transfer.isCancelled, isTrue);
  });

  test('getTextResponseForUrl propagates the typed DioException', () async {
    // flutter_test's mocked HttpClient answers every request with HTTP 400,
    // which Dio surfaces as a badResponse DioException.
    await expectLater(
      request.getTextResponseForUrl('http://127.0.0.1/anything'),
      throwsA(
        isA<DioException>().having(
          (e) => e.type,
          'type',
          DioExceptionType.badResponse,
        ),
      ),
    );
  });

  test('getFileResponseForUrl propagates the typed DioException', () async {
    await expectLater(
      request.getFileResponseForUrl('http://127.0.0.1/anything'),
      throwsA(
        isA<DioException>().having(
          (e) => e.type,
          'type',
          DioExceptionType.badResponse,
        ),
      ),
    );
  });
}
