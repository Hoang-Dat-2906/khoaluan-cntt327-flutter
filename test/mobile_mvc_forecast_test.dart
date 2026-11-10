import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kite/core/network/api_client.dart';
import 'package:kite/features/analysis/analysis_result.dart';
import 'package:kite/features/datasets/dataset.dart';
import 'package:kite/features/datasets/dataset_repository.dart';
import 'package:kite/features/forecast/forecast.dart';
import 'package:kite/features/forecast/forecast_repository.dart';

import 'finai_contract_test.dart' show datasetJson;

// Synthetic fixtures; no production credentials, HTTP server, Gemini or plugins.
Map<String, dynamic> forecastJson() => {
  'status': 'success',
  'dataset_name': 'synthetic.csv',
  'execution_time_ms': 12,
  'data': {
    'target_column': 'revenue',
    'date_column': 'date',
    'model_type': 'linear_regression',
    'metrics': {'mae': 1, 'rmse': 2, 'mape': null, 'r2': 0.8},
    'historical_table': [
      {'period': '2025-01', 'actual_value': 0, 'fitted_value': 1},
      {'period': '2025-02', 'actual_value': 20, 'fitted_value': 19},
    ],
    'forecast_table': [
      for (var i = 0; i < 3; i++)
        {
          'period': '2025-0${i + 3}',
          'forecast_value': 30 + i * 10,
          'lower_bound': 25 + i * 10,
          'upper_bound': 35 + i * 10,
        },
    ],
    'chart_image': null,
  },
};

void main() {
  test('MVC access-token failure differs from dataset permission', () {
    final auth = ApiFailure.fromResponse(
      403,
      utf8.encode('{"code":"AUTH_008"}'),
    );
    final permission = ApiFailure.fromResponse(
      403,
      utf8.encode('{"code":"DATASET_002"}'),
    );
    expect(auth.invalidSession, isTrue);
    expect(permission.invalidSession, isFalse);
    expect(permission.code, 'DATASET_002');
  });
  test('malformed and oversized error bodies never expose raw detail', () {
    for (final text in [
      '<html>private detail</html>',
      '{"code":12}',
      '{"message":"private detail","detail":"internal/path"}',
      'x' * 17000,
    ]) {
      final error = ApiFailure.fromResponse(500, utf8.encode(text));
      expect(error.code, isNull);
      expect(error.message, isNot(contains('private')));
      expect(error.message, isNot(contains('internal/path')));
    }
    final missing = ApiFailure.fromResponse(
      404,
      utf8.encode('{"code":"DATASET_003"}'),
    );
    expect(missing.message, 'Tệp không còn tồn tại — vui lòng tải lại');
  });
  test('only 403 AUTH_008 invalidates protected request session', () async {
    var code = 'DATASET_002';
    final stamps = <int>[];
    final api = ApiClient(
      baseUrl: 'http://example.invalid',
      client: MockClient(
        (_) async => http.Response(jsonEncode({'code': code}), 403),
      ),
    )..setToken('synthetic');
    addTearDown(api.close);
    api.onUnauthorized = stamps.add;
    await expectLater(
      api.jsonRequest('datasets/id'),
      throwsA(isA<ApiFailure>()),
    );
    expect(stamps, isEmpty);
    code = 'AUTH_008';
    await expectLater(
      api.jsonRequest('datasets/id'),
      throwsA(isA<ApiFailure>()),
    );
    expect(stamps, [api.generation]);
  });
  test('late 403 cannot clear a newer token', () async {
    final pending = Completer<http.Response>();
    var cleared = false;
    final api = ApiClient(
      baseUrl: 'http://example.invalid',
      client: MockClient((_) => pending.future),
    )..setToken('old');
    addTearDown(api.close);
    api.onUnauthorized = (_) => cleared = true;
    final request = api.jsonRequest('datasets/id');
    api.setToken('new');
    pending.complete(http.Response('{"code":"AUTH_008"}', 403));
    await expectLater(request, throwsA(isA<ApiFailure>()));
    expect(cleared, isFalse);
  });
  test(
    'storage unknown remains unknown; explicit missing blocks all analysis',
    () async {
      final unknown = Dataset.fromJson(datasetJson());
      expect(unknown.fileAvailable, isNull);
      expect(unknown.storageMessage, contains('Chưa xác nhận'));
      var calls = 0;
      final api = ApiClient(
        baseUrl: 'http://example.invalid',
        client: MockClient((_) async {
          calls++;
          return http.Response('{}', 200);
        }),
      )..setToken('synthetic');
      addTearDown(api.close);
      for (final overrides in [
        {'file_available': false},
        {'status': 'missing'},
        {'storage_status': 'invalid_path'},
        {'storage_status': 'unavailable'},
      ]) {
        final dataset = Dataset.fromJson({...datasetJson(), ...overrides});
        expect(dataset.fileBlocked, isTrue);
        await expectLater(
          DatasetRepository(api).analyze(dataset, 'q', ['date']),
          throwsA(isA<ApiFailure>()),
        );
        await expectLater(
          ForecastRepository(api)
              .predict(dataset, target: 'revenue', date: 'date', horizon: 3),
          throwsA(isA<ApiFailure>()),
        );
      }
      expect(calls, 0);
    },
  );
  test('analysis preserves backend DATASET_003 without retry', () async {
    final methods = <String>[];
    final api = ApiClient(
      baseUrl: 'http://example.invalid',
      client: MockClient((r) async {
        methods.add(r.method);
        return http.Response('{"code":"DATASET_003"}', 404);
      }),
    )..setToken('synthetic');
    addTearDown(api.close);
    await expectLater(
      DatasetRepository(api)
          .analyze(Dataset.fromJson(datasetJson()), 'q', ['date']),
      throwsA(isA<ApiFailure>().having((e) => e.code, 'code', 'DATASET_003')),
    );
    expect(methods, ['POST']);
  });
  test(
    'forecast uses JSON and Bearer, parses actual/fitted and nullable metrics',
    () async {
      final api = ApiClient(
        baseUrl: 'http://example.invalid',
        client: MockClient((r) async {
          expect(r.url.path, '/api/v1/forecast/predict');
          expect(r.headers['Authorization'], 'Bearer synthetic');
          expect(r.headers['content-type'], contains('application/json'));
          expect(jsonDecode(r.body), {
            'dataset_id': 'synthetic-dataset',
            'target_column': 'revenue',
            'date_column': 'date',
            'horizon': 3,
            'model_type': 'linear_regression',
          });
          return http.Response(jsonEncode(forecastJson()), 200);
        }),
      )..setToken('synthetic');
      addTearDown(api.close);
      final result = await ForecastRepository(api).predict(
        Dataset.fromJson(datasetJson()),
        target: 'revenue',
        date: 'date',
        horizon: 3,
      );
      expect(result.future.length, 3);
      expect(result.actual.first.fitted, 1);
      expect(result.containsZeroActual, isTrue);
      expect(result.metrics['mape'], isNull);
      expect(result.timeMs, 12);
    },
  );
  test(
    'forecast rejects malformed tables; nonfinite metrics remain unavailable',
    () {
      final data = forecastJson();
      final body = data['data'] as Map<String, dynamic>;
      (body['metrics'] as Map)['mae'] = double.nan;
      (body['metrics'] as Map)['rmse'] = double.infinity;
      final parsed = ForecastResult.fromJson(data, 'd');
      expect(parsed.metrics['mae'], isNull);
      expect(parsed.metrics['rmse'], isNull);
      body['forecast_table'] = <Map<String, dynamic>>[];
      expect(
        () => ForecastResult.fromJson(data, 'd'),
        throwsA(isA<ApiFailure>()),
      );
      expect(
        () => ForecastResult.fromJson({'status': 'success'}, 'd'),
        throwsA(isA<ApiFailure>()),
      );
    },
  );
  test('invalid forecast form fails without HTTP', () async {
    var calls = 0;
    final api = ApiClient(
      baseUrl: 'http://example.invalid',
      client: MockClient((_) async {
        calls++;
        return http.Response('{}', 200);
      }),
    )..setToken('synthetic');
    addTearDown(api.close);
    final repo = ForecastRepository(api);
    for (final horizon in [0, 13]) {
      await expectLater(
        repo.predict(
          Dataset.fromJson(datasetJson()),
          target: 'revenue',
          date: 'date',
          horizon: horizon,
        ),
        throwsA(isA<ApiFailure>()),
      );
    }
    await expectLater(
      repo.predict(
        Dataset.fromJson(datasetJson()),
        target: 'date',
        date: 'date',
        horizon: 3,
      ),
      throwsA(isA<ApiFailure>()),
    );
    expect(calls, 0);
  });
  test('forecast from previous session is discarded', () async {
    final pending = Completer<http.Response>();
    final api = ApiClient(
      baseUrl: 'http://example.invalid',
      client: MockClient((_) => pending.future),
    )..setToken('old');
    addTearDown(api.close);
    final request = ForecastRepository(api).predict(
      Dataset.fromJson(datasetJson()),
      target: 'revenue',
      date: 'date',
      horizon: 3,
    );
    api.setToken('new');
    pending.complete(http.Response(jsonEncode(forecastJson()), 200));
    await expectLater(request, throwsA(isA<ApiFailure>()));
  });
  test(
    'POST timeout does not retry and late auth error has no side effect',
    () async {
      final pending = Completer<http.Response>();
      var calls = 0;
      var expired = false;
      final api = ApiClient(
        baseUrl: 'http://example.invalid',
        client: MockClient((_) {
          calls++;
          return pending.future;
        }),
      )..setToken('synthetic');
      addTearDown(api.close);
      api.onUnauthorized = (_) => expired = true;
      await expectLater(
        api.jsonRequest(
          'forecast/predict',
          method: 'POST',
          jsonBody: {},
          timeout: const Duration(milliseconds: 5),
        ),
        throwsA(isA<ApiFailure>()),
      );
      pending.complete(http.Response('{"code":"AUTH_008"}', 403));
      await Future<void>.delayed(Duration.zero);
      expect(calls, 1);
      expect(expired, isFalse);
    },
  );
  test('upload uses multipart once; invalid extension does not send', () async {
    var calls = 0;
    final api = ApiClient(
      baseUrl: 'http://example.invalid',
      client: MockClient((r) async {
        calls++;
        expect(r.url.path, '/api/v1/datasets/upload');
        expect(r.headers['content-type'], contains('multipart/form-data'));
        return http.Response(jsonEncode(datasetJson()), 200);
      }),
    )..setToken('synthetic');
    addTearDown(api.close);
    final repo = DatasetRepository(api);
    expect(
      (await repo.upload('synthetic.csv', Uint8List.fromList([1]))).id,
      'synthetic-dataset',
    );
    await expectLater(
      repo.upload('wrong.exe', Uint8List.fromList([1])),
      throwsA(isA<ApiFailure>()),
    );
    expect(calls, 1);
  });
  test('idle Gemini response cannot become successful execution', () {
    final result = AnalysisResult.fromJson(
      {
        'execution_status': 'idle',
        'ai_code': '# provider error',
        'security_status': 'passed',
      },
      'd',
      'q',
    );
    expect(result.successful, isFalse);
    expect(result.executionLabel, contains('không có kết quả'));
  });
}
