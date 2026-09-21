import 'package:dio/dio.dart';
import 'package:fl_clash/common/request.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _SubscriptionClient extends Mock implements Dio {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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
          cancelToken: cancel,
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
          cancelToken: cancel,
          options: any(named: 'options'),
        ),
      ).called(1);
    },
  );

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
