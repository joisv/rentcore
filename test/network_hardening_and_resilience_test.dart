import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:sewakasir/core/network/api_client.dart';
import 'package:sewakasir/core/utils/debounced_search_controller.dart';
import 'package:sewakasir/features/notifications/models/notification_item.dart';
import 'package:sewakasir/features/notifications/providers/notification_provider.dart';

typedef _MockFetchHandler = Future<ResponseBody> Function(
  RequestOptions options,
  int callIndex,
);

class _MockHttpClientAdapter implements HttpClientAdapter {
  final _MockFetchHandler handler;
  int callCount = 0;

  _MockHttpClientAdapter(this.handler);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    callCount++;
    return handler(options, callCount);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _jsonResponse(
  Map<String, dynamic> body,
  int statusCode, {
  Map<String, List<String>>? headers,
}) {
  return ResponseBody.fromString(
    jsonEncode(body),
    statusCode,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
      ...?headers,
    },
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    ApiClient.isLoggingOut = false;
  });

  group('ApiClient Safe Exponential Backoff Retry', () {
    test(
      'retries idempotent GET on 503 with 1s -> 2s exponential backoff and resolves on 3rd attempt',
      () async {
        final recordedDelays = <Duration>[];
        final adapter = _MockHttpClientAdapter((options, call) async {
          if (call <= 2) {
            return _jsonResponse({'message': 'Service Unavailable'}, 503);
          }
          return _jsonResponse({'success': true, 'data': ['ok']}, 200);
        });

        final dio = ApiClient.createDioForTesting(
          adapter: adapter,
          sleep: (delay) async => recordedDelays.add(delay),
        );

        final response = await dio.get('/bookings');

        expect(response.statusCode, 200);
        expect(response.data['success'], isTrue);
        expect(adapter.callCount, 3);
        expect(recordedDelays, [
          const Duration(seconds: 1),
          const Duration(seconds: 2),
        ]);
      },
    );

    test(
      'stops after max 2 retries on persistent GET 503 and returns human-readable ApiException',
      () async {
        final recordedDelays = <Duration>[];
        final adapter = _MockHttpClientAdapter((options, call) async {
          return _jsonResponse({'message': 'Service Unavailable'}, 503);
        });

        final dio = ApiClient.createDioForTesting(
          adapter: adapter,
          sleep: (delay) async => recordedDelays.add(delay),
        );

        DioException? caught;
        try {
          await dio.get('/assets');
        } on DioException catch (e) {
          caught = e;
        }

        expect(caught, isNotNull);
        expect(adapter.callCount, 3); // 1 initial + 2 retries
        expect(recordedDelays, [
          const Duration(seconds: 1),
          const Duration(seconds: 2),
        ]);
        expect(caught!.error, isA<ApiException>());
        expect(
          ApiClient.extractErrorMessage(caught),
          ApiException.serverErrorMessage,
        );
      },
    );

    test(
      'respects Retry-After header in seconds on GET 429',
      () async {
        final recordedDelays = <Duration>[];
        final adapter = _MockHttpClientAdapter((options, call) async {
          if (call == 1) {
            return _jsonResponse(
              {'message': 'Too Many Requests'},
              429,
              headers: {
                'retry-after': ['4'],
              },
            );
          }
          return _jsonResponse({'success': true}, 200);
        });

        final dio = ApiClient.createDioForTesting(
          adapter: adapter,
          sleep: (delay) async => recordedDelays.add(delay),
        );

        final response = await dio.get('/customers');
        expect(response.statusCode, 200);
        expect(adapter.callCount, 2);
        expect(recordedDelays, [const Duration(seconds: 4)]);
      },
    );

    test(
      'NEVER retries unsafe POST/PUT/DELETE mutations on 503 or timeout',
      () async {
        final recordedDelays = <Duration>[];
        final adapter = _MockHttpClientAdapter((options, call) async {
          return _jsonResponse({'message': 'Service Unavailable'}, 503);
        });

        final dio = ApiClient.createDioForTesting(
          adapter: adapter,
          sleep: (delay) async => recordedDelays.add(delay),
        );

        await expectLater(
          () => dio.post('/bookings', data: {'customer_name': 'Budi'}),
          throwsA(isA<DioException>()),
        );

        expect(adapter.callCount, 1);
        expect(recordedDelays, isEmpty);

        await expectLater(
          () => dio.put('/assets/1', data: {'status': 'ready'}),
          throwsA(isA<DioException>()),
        );
        expect(adapter.callCount, 2);
        expect(recordedDelays, isEmpty);

        await expectLater(
          () => dio.delete('/assets/1'),
          throwsA(isA<DioException>()),
        );
        expect(adapter.callCount, 3);
        expect(recordedDelays, isEmpty);
      },
    );

    test('retries GET on connection timeout up to 2 times', () async {
      final recordedDelays = <Duration>[];
      final adapter = _MockHttpClientAdapter((options, call) async {
        if (call == 1) {
          throw DioException(
            requestOptions: options,
            type: DioExceptionType.connectionTimeout,
          );
        }
        return _jsonResponse({'success': true}, 200);
      });

      final dio = ApiClient.createDioForTesting(
        adapter: adapter,
        sleep: (delay) async => recordedDelays.add(delay),
      );

      final response = await dio.get('/dashboard/kpi');
      expect(response.statusCode, 200);
      expect(adapter.callCount, 2);
      expect(recordedDelays, [const Duration(seconds: 1)]);
    });
  });

  group('ApiException Centralized Human-Readable Error Mapping', () {
    test('maps 401 and triggers onUnauthorized session logout callback', () async {
      bool unauthorizedCalled = false;
      final adapter = _MockHttpClientAdapter((options, call) async {
        return _jsonResponse({'message': 'Unauthenticated.'}, 401);
      });

      final dio = ApiClient.createDioForTesting(
        adapter: adapter,
        sleep: (_) async {},
        onUnauthorized: () => unauthorizedCalled = true,
      );

      DioException? caught;
      try {
        await dio.get('/auth/me');
      } on DioException catch (e) {
        caught = e;
      }

      expect(unauthorizedCalled, isTrue);
      expect(caught, isNotNull);
      expect(caught!.error, isA<ApiException>());
      expect(
        ApiClient.extractErrorMessage(caught),
        'Sesi login Anda telah berakhir. Silakan masuk kembali.',
      );
    });

    test('maps 403, 404, 422, 429, 500, 502, 503, and timeout/socket errors cleanly', () {
      final req = RequestOptions(path: '/bookings');

      DioException statusErr(int code, [dynamic data]) => DioException(
            requestOptions: req,
            response: Response(
              requestOptions: req,
              statusCode: code,
              data: data,
            ),
            type: DioExceptionType.badResponse,
          );

      expect(
        ApiClient.mapDioException(statusErr(403)).message,
        'Anda tidak memiliki izin untuk melakukan tindakan ini.',
      );
      expect(
        ApiClient.mapDioException(statusErr(404)).message,
        'Data yang diminta tidak ditemukan atau sudah diperbarui.',
      );
      expect(
        ApiClient.mapDioException(
          statusErr(422, {
            'message': 'The given data was invalid.',
            'errors': {
              'customer_phone': ['Nomor WhatsApp pelanggan wajib diisi.'],
            },
          }),
        ).message,
        'Nomor WhatsApp pelanggan wajib diisi.',
      );
      expect(
        ApiClient.mapDioException(statusErr(429)).message,
        'Terlalu banyak permintaan. Tunggu beberapa detik lalu coba lagi.',
      );
      expect(
        ApiClient.mapDioException(statusErr(500)).message,
        'Server sedang mengalami gangguan sementara. Silakan coba beberapa saat lagi.',
      );
      expect(
        ApiClient.mapDioException(statusErr(502)).message,
        'Server sedang mengalami gangguan sementara. Silakan coba beberapa saat lagi.',
      );
      expect(
        ApiClient.mapDioException(statusErr(503)).message,
        'Server sedang mengalami gangguan sementara. Silakan coba beberapa saat lagi.',
      );

      final timeoutErr = DioException(
        requestOptions: req,
        type: DioExceptionType.connectionTimeout,
      );
      expect(
        ApiClient.mapDioException(timeoutErr).message,
        'Koneksi internet tidak stabil. Periksa jaringan Anda dan coba lagi.',
      );

      final socketErr = DioException(
        requestOptions: req,
        type: DioExceptionType.unknown,
        error: const SocketException('Network is unreachable'),
      );
      expect(
        ApiClient.mapDioException(socketErr).message,
        'Koneksi internet tidak stabil. Periksa jaringan Anda dan coba lagi.',
      );
    });
  });

  group('DebouncedSearchController (350ms + CancelToken)', () {
    test('coalesces rapid keystrokes within 350ms into a single search request', () async {
      final controller = DebouncedSearchController();
      addTearDown(controller.dispose);

      final dispatched = <String>[];

      controller.run('i', (q, _) => dispatched.add(q));
      await Future<void>.delayed(const Duration(milliseconds: 100));
      controller.run('ip', (q, _) => dispatched.add(q));
      await Future<void>.delayed(const Duration(milliseconds: 100));
      controller.run('iph', (q, _) => dispatched.add(q));
      await Future<void>.delayed(const Duration(milliseconds: 100));
      controller.run('  iphone 16  ', (q, _) => dispatched.add(q));

      // Still before 350ms since last keystroke -> nothing fired yet
      await Future<void>.delayed(const Duration(milliseconds: 200));
      expect(dispatched, isEmpty);

      // After 350ms window -> only latest trimmed query dispatched once
      await Future<void>.delayed(const Duration(milliseconds: 220));
      expect(dispatched, ['iphone 16']);
    });

    test('cancels in-flight CancelToken when a newer search query is entered', () async {
      final controller = DebouncedSearchController(
        delay: const Duration(milliseconds: 50),
      );
      addTearDown(controller.dispose);

      CancelToken? firstToken;
      CancelToken? secondToken;

      controller.run('sony', (_, token) => firstToken = token);
      await Future<void>.delayed(const Duration(milliseconds: 80));

      expect(firstToken, isNotNull);
      expect(firstToken!.isCancelled, isFalse);

      // User types a new query while first request is still in-flight
      controller.run('canon', (_, token) => secondToken = token);

      // First token is aborted IMMEDIATELY before second debounce even fires
      expect(firstToken!.isCancelled, isTrue);

      await Future<void>.delayed(const Duration(milliseconds: 80));
      expect(secondToken, isNotNull);
      expect(secondToken!.isCancelled, isFalse);
      expect(secondToken, isNot(same(firstToken)));
    });
  });

  group('Optimistic Notification Read State & Rollback', () {
    late HttpClientAdapter originalAdapter;

    setUp(() {
      originalAdapter = ApiClient().dio.httpClientAdapter;
    });

    tearDown(() {
      ApiClient().dio.httpClientAdapter = originalAdapter;
    });

    test('markAsRead updates unread badge optimistically and rolls back cleanly on API failure', () async {
      final completer = Completer<ResponseBody>();
      ApiClient().dio.httpClientAdapter = _MockHttpClientAdapter((options, _) {
        return completer.future;
      });

      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(notificationProvider.notifier);
      final now = DateTime.now();
      notifier.state = NotificationState(
        unreadCount: 2,
        notifications: [
          NotificationItem(
            id: 10,
            businessId: 1,
            category: 'rental',
            type: 'rental.overdue',
            title: 'Overdue 1',
            body: 'Body 1',
            readAt: null,
            createdAt: now,
          ),
          NotificationItem(
            id: 11,
            businessId: 1,
            category: 'rental',
            type: 'rental.overdue',
            title: 'Overdue 2',
            body: 'Body 2',
            readAt: null,
            createdAt: now,
          ),
        ],
      );

      final future = notifier.markAsRead(10);

      // Optimistic state is applied IMMEDIATELY before HTTP resolves
      expect(container.read(notificationProvider).unreadCount, 1);
      expect(
        container.read(notificationProvider).notifications.first.isRead,
        isTrue,
      );

      // Simulate server 500 failure -> must roll back cleanly
      completer.complete(_jsonResponse({'message': 'Server error'}, 500));
      await future;

      expect(container.read(notificationProvider).unreadCount, 2);
      expect(
        container.read(notificationProvider).notifications.first.isRead,
        isFalse,
      );
    });

    test('markAllAsRead updates unreadCount to 0 optimistically and rolls back on failure', () async {
      final completer = Completer<ResponseBody>();
      ApiClient().dio.httpClientAdapter = _MockHttpClientAdapter((options, _) {
        return completer.future;
      });

      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(notificationProvider.notifier);
      final now = DateTime.now();
      notifier.state = NotificationState(
        unreadCount: 2,
        notifications: [
          NotificationItem(
            id: 20,
            businessId: 1,
            category: 'transfer',
            type: 'transfer.requested',
            title: 'Transfer 1',
            body: 'Body 1',
            readAt: null,
            createdAt: now,
          ),
          NotificationItem(
            id: 21,
            businessId: 1,
            category: 'transfer',
            type: 'transfer.requested',
            title: 'Transfer 2',
            body: 'Body 2',
            readAt: null,
            createdAt: now,
          ),
        ],
      );

      final future = notifier.markAllAsRead();

      // Optimistic state immediately clears unread count and marks items read
      expect(container.read(notificationProvider).unreadCount, 0);
      expect(
        container.read(notificationProvider).notifications.every((n) => n.isRead),
        isTrue,
      );

      // Simulate server 500 failure -> must roll back cleanly
      completer.complete(_jsonResponse({'message': 'Server error'}, 500));
      final ok = await future;

      expect(ok, isFalse);
      expect(container.read(notificationProvider).unreadCount, 2);
      expect(
        container.read(notificationProvider).notifications.every((n) => !n.isRead),
        isTrue,
      );
    });
  });

  group('Android Release HTTPS Security Configuration', () {
    test('release manifest and network_security_config enforce HTTPS while debug allows local HTTP', () {
      final mainManifest =
          File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
      final mainNetConfig = File(
        'android/app/src/main/res/xml/network_security_config.xml',
      ).readAsStringSync();
      final debugManifest =
          File('android/app/src/debug/AndroidManifest.xml').readAsStringSync();
      final debugNetConfig = File(
        'android/app/src/debug/res/xml/network_security_config.xml',
      ).readAsStringSync();

      expect(mainManifest, contains('android:usesCleartextTraffic="false"'));
      expect(mainNetConfig, contains('cleartextTrafficPermitted="false"'));
      expect(mainNetConfig, isNot(contains('<certificates src="user"')));

      expect(debugManifest, contains('android:usesCleartextTraffic="true"'));
      expect(debugNetConfig, contains('cleartextTrafficPermitted="true"'));
    });
  });
}
