import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kite/core/network/api_client.dart';
import 'package:kite/features/analysis/analysis_result.dart';
import 'package:kite/features/datasets/dataset.dart';
import 'package:kite/features/datasets/dataset_repository.dart';

Map<String, dynamic> datasetJson({Object? schema}) => {
  'id': 'synthetic-dataset',
  'filename': 'synthetic.csv',
  'file_type': 'csv',
  'size_bytes': 20,
  'row_count': 2,
  'column_count': 2,
  'version': 1,
  'status': 'ready',
  'schema_info':
      schema ??
      jsonEncode({
        'columns': [
          {'name': 'date', 'dtype': 'str'},
          {'name': 'revenue', 'dtype': 'int64'},
        ],
      }),
};
void main() {
  test('data/count and schema JSON string parse', () {
    final page = DatasetPage.fromJson({
      'data': [datasetJson()],
      'count': 1,
    });
    expect(page.items.single.columns.length, 2);
    expect(page.count, 1);
  });
  test('schema supports object and list', () {
    expect(
      Dataset.fromJson(
        datasetJson(
          schema: {
            'columns': [
              {'name': 'Sales'},
            ],
          },
        ),
      ).columns.single['name'],
      'Sales',
    );
    expect(
      Dataset.fromJson(
        datasetJson(
          schema: [
            {'name': 'Sales'},
          ],
        ),
      ).columns.single['name'],
      'Sales',
    );
  });
  test('invalid or null schema warns instead of claiming clean', () {
    expect(
      Dataset.fromJson({...datasetJson(), 'schema_info': null}).needsReview,
      isTrue,
    );
    expect(
      Dataset.fromJson(datasetJson(schema: 'broken JSON')).needsReview,
      isTrue,
    );
    expect(
      Dataset.fromJson(
        datasetJson(
          schema: {
            'columns': [1],
          },
        ),
      ).needsReview,
      isTrue,
    );
  });
  test('Unnamed headers require review', () {
    expect(
      Dataset.fromJson(
        datasetJson(
          schema: {
            'columns': [
              {'name': 'Unnamed: 1'},
            ],
          },
        ),
      ).needsReview,
      isTrue,
    );
  });
  test('malformed data envelope is not an empty success', () {
    expect(
      () => DatasetPage.fromJson({'data': 'wrong', 'count': 0}),
      throwsA(isA<ApiFailure>()),
    );
  });
  test('API origin prevents credentials and doubled path', () {
    for (final origin in [
      '',
      'http://user:secret@host',
      'http://host/api/v1',
      'http://host?token=value',
    ]) {
      final api = ApiClient(baseUrl: origin);
      addTearDown(api.close);
      expect(() => api.uri('datasets/'), throwsA(isA<ApiFailure>()));
    }
  });
  test('download 404 never posts to AI', () async {
    final methods = <String>[];
    final api = ApiClient(
      baseUrl: 'http://example.invalid',
      client: MockClient((r) async {
        methods.add(r.method);
        return http.Response('', 404);
      }),
    )..setToken('synthetic');
    addTearDown(api.close);
    await expectLater(
      DatasetRepository(api)
          .analyze(Dataset.fromJson(datasetJson()), 'test', ['date']),
      throwsA(isA<ApiFailure>().having((e) => e.status, 'status', 404)),
    );
    expect(methods, ['GET']);
  });
  test(
    'compatibility analysis uses bearer download and multipart fields',
    () async {
      final api = ApiClient(
        baseUrl: 'http://example.invalid',
        client: MockClient((r) async {
          expect(r.headers['Authorization'], 'Bearer synthetic');
          if (r.method == 'GET') {
            expect(r.url.path, endsWith('/download'));
            return http.Response('date,revenue\n1,10', 200);
          }
          expect(r.url.path, '/api/v1/files/upload');
          expect(r.headers['content-type'], contains('multipart/form-data'));
          expect(r.body, contains('name="scope_columns"'));
          expect(r.body, contains('date,revenue'));
          expect(r.body, contains('Câu hỏi'));
          expect(r.body, contains('synthetic.csv'));
          return http.Response(
            jsonEncode({
              'execution_status': 'success',
              'security_status': 'passed',
              'stdout': '10',
            }),
            200,
          );
        }),
      )..setToken('synthetic');
      addTearDown(api.close);
      final result = await DatasetRepository(api).analyze(
        Dataset.fromJson(datasetJson()),
        'Câu hỏi',
        ['date', 'revenue'],
      );
      expect(result.successful, isTrue);
      expect(result.datasetId, 'synthetic-dataset');
    },
  );
  test('empty selection and comma in column fail before networking', () async {
    var calls = 0;
    final api = ApiClient(
      baseUrl: 'http://example.invalid',
      client: MockClient((_) async {
        calls++;
        return http.Response('', 500);
      }),
    )..setToken('synthetic');
    addTearDown(api.close);
    final repo = DatasetRepository(api);
    final data = Dataset.fromJson(datasetJson());
    await expectLater(repo.analyze(data, 'q', []), throwsA(isA<ApiFailure>()));
    await expectLater(
      repo.analyze(data, 'q', ['Sales, net']),
      throwsA(isA<ApiFailure>()),
    );
    expect(calls, 0);
  });
  test('late 401 does not invalidate a newer session', () async {
    final pending = Completer<http.Response>();
    var expired = false;
    final api = ApiClient(
      baseUrl: 'http://example.invalid',
      client: MockClient((_) => pending.future),
    )..setToken('old');
    addTearDown(api.close);
    api.onUnauthorized = (_) => expired = true;
    final request = api.jsonRequest('users/me');
    api.setToken('new');
    pending.complete(http.Response('', 401));
    await expectLater(request, throwsA(isA<ApiFailure>()));
    expect(expired, isFalse);
  });
  test('timeout is explicit and not automatically retried', () async {
    var calls = 0;
    final pending = Completer<http.Response>();
    final api = ApiClient(
      baseUrl: 'http://example.invalid',
      client: MockClient((_) {
        calls++;
        return pending.future;
      }),
    )..setToken('synthetic');
    addTearDown(api.close);
    await expectLater(
      api.send(
        http.Request('GET', api.uri('datasets/')),
        timeout: const Duration(milliseconds: 10),
      ),
      throwsA(isA<ApiFailure>()),
    );
    expect(calls, 1);
    pending.complete(http.Response('{}', 200));
  });
  test('response size is limited', () async {
    final api = ApiClient(
      baseUrl: 'http://example.invalid',
      client: MockClient((_) async => http.Response('123456', 200)),
    )..setToken('synthetic');
    addTearDown(api.close);
    await expectLater(
      api.send(http.Request('GET', api.uri('datasets/')), maxBytes: 3),
      throwsA(isA<ApiFailure>()),
    );
  });
  test('result never treats passed security alone as success', () {
    for (final j in [
      {'security_status': 'passed', 'execution_status': 'error'},
      {'security_status': 'passed', 'execution_status': 'idle'},
      {'security_status': 'blocked', 'execution_status': 'success'},
      {
        'security_status': 'passed',
        'execution_status': 'success',
        'execution_error': 'failed',
      },
      {'security_status': 'passed'},
    ]) {
      expect(AnalysisResult.fromJson(j, 'd', 'q').successful, isFalse);
    }
  });
  test('invalid response field is rejected', () {
    expect(
      () => AnalysisResult.fromJson({'stdout': 123}, 'd', 'q'),
      throwsA(isA<ApiFailure>()),
    );
    expect(
      () => ApiClient.decodeObject(utf8.encode('not json')),
      throwsA(isA<ApiFailure>()),
    );
  });
  test('bad Base64 fails explicitly', () {
    expect(
      () => AnalysisResult.fromJson(
        {'chart_image': '%%%bad'},
        'd',
        'q',
      ).inlineChart(),
      throwsA(isA<ApiFailure>()),
    );
  });
  test('external chart URL rejected before bearer can leak', () async {
    final api = ApiClient(baseUrl: 'http://example.invalid')
      ..setToken('synthetic');
    addTearDown(api.close);
    await expectLater(
      DatasetRepository(api).chart('https://other.invalid/chart.png'),
      throwsA(isA<ApiFailure>()),
    );
  });
}
