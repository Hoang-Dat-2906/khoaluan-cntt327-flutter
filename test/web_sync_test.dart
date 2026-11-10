import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kite/core/auth/session.dart';
import 'package:kite/core/network/api_client.dart';
import 'package:kite/features/analysis/analysis_screen.dart';
import 'package:kite/features/datasets/dataset.dart';
import 'package:kite/features/datasets/dataset_file_picker.dart';
import 'package:kite/features/datasets/dataset_repository.dart';
import 'package:kite/features/datasets/workbook_import_screen.dart';
import 'package:kite/features/forecast/forecast_repository.dart';
import 'package:kite/features/history/history_screen.dart';
import 'package:kite/shared/widgets/finai_design.dart';

import 'finai_contract_test.dart' show datasetJson;

http.Response jsonResponse(Object body, [int status = 200]) =>
    http.Response.bytes(
      utf8.encode(jsonEncode(body)),
      status,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

void main() {
  for (final (width, brightness) in [
    (360.0, Brightness.light),
    (430.0, Brightness.dark),
  ]) {
    testWidgets(
      'chat composer remains visible with keyboard at ${width.toInt()}dp',
      (tester) async {
        tester.view.physicalSize = Size(width, 820);
        tester.view.devicePixelRatio = 1;
        tester.view.viewInsets = const FakeViewPadding(bottom: 280);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetViewInsets);
        final dataset = Dataset.fromJson(datasetJson());
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              datasetDetailProvider(dataset.id)
                  .overrideWith((_) async => dataset),
              recommendationsProvider(dataset.id)
                  .overrideWith((_) async => {'recommendations': []}),
            ],
            child: MaterialApp(
              theme: FinaiColors.theme(brightness),
              home: Scaffold(body: AnalysisScreen(id: dataset.id)),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(TextField).hitTestable(), findsOneWidget);
        expect(find.byTooltip('Phân tích ngay').hitTestable(), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
  test('missing API origin is different from invalid origin', () {
    final missing = ApiClient(baseUrl: '');
    final invalid = ApiClient(baseUrl: 'http://localhost:8000/api/v1');
    addTearDown(missing.close);
    addTearDown(invalid.close);
    expect(
      () => missing.uri('users/me'),
      throwsA(
        isA<ApiFailure>().having(
          (e) => e.message,
          'message',
          startsWith('Chưa cấu hình'),
        ),
      ),
    );
    expect(
      () => invalid.uri('users/me'),
      throwsA(
        isA<ApiFailure>().having(
          (e) => e.message,
          'message',
          startsWith('Địa chỉ máy chủ không hợp lệ'),
        ),
      ),
    );
  });

  test(
    'export uses only the configured origin and rejects path traversal',
    () async {
      var calls = 0;
      final api = ApiClient(
        baseUrl: 'http://localhost:8000',
        client: MockClient((request) async {
          calls++;
          expect(request.url.origin, 'http://localhost:8000');
          expect(request.url.path, '/api/v1/files/download-export/result.csv');
          expect(request.headers['Authorization'], 'Bearer synthetic');
          return http.Response('amount\n12', 200);
        }),
      )..setToken('synthetic');
      addTearDown(api.close);
      final repo = DatasetRepository(api);
      expect(
        () => repo.exportFile('../result.csv'),
        throwsA(isA<ApiFailure>()),
      );
      expect(
        () => repo.exportFile('https://untrusted.invalid/result.csv'),
        throwsA(isA<ApiFailure>()),
      );
      expect(utf8.decode(await repo.exportFile('result.csv')), 'amount\n12');
      expect(calls, 1);
    },
  );

  test(
    'recommendations use the dataset route and preserve nullable suggestions',
    () async {
      final api = ApiClient(
        baseUrl: 'http://localhost:8000',
        client: MockClient((request) async {
          expect(request.method, 'GET');
          expect(
            request.url.path,
            '/api/v1/forecast/recommendations/synthetic-dataset',
          );
          return jsonResponse({
            'status': 'success',
            'data': {
              'recommendations': [
                {'algorithm_id': 'linear_regression', 'suggested_date': null},
              ],
            },
          });
        }),
      )..setToken('synthetic');
      addTearDown(api.close);
      final data = await ForecastRepository(api)
          .recommendations('synthetic-dataset');
      expect(
        (data['recommendations'] as List).single['suggested_date'],
        isNull,
      );
    },
  );

  testWidgets('partial workbook import retries only the unsaved sheet', (
    tester,
  ) async {
    final imports = <String>[];
    final api = ApiClient(
      baseUrl: 'http://localhost:8000',
      client: MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.headers['Authorization'], 'Bearer synthetic');
        expect(request.body, contains('filename="sample.xlsx"'));
        if (request.url.path.endsWith('/inspect-workbook')) {
          return jsonResponse({
            'sheets': [
              for (final name in ['Sales', 'Costs'])
                {
                  'name': name,
                  'has_header': true,
                  'missing_summary': {'affected_rows': 0},
                },
            ],
          });
        }
        expect(request.url.path, '/api/v1/datasets/upload-interactive');
        expect(request.body, contains('name="config"'));
        final name = request.body.contains('"selected_sheet":"Sales"')
            ? 'Sales'
            : 'Costs';
        imports.add(name);
        if (imports.length == 2)
          return jsonResponse({'code': 'DATASET_004'}, 400);
        return jsonResponse(datasetJson());
      }),
    )..setToken('synthetic');
    addTearDown(api.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [apiClientProvider.overrideWithValue(api)],
        child: MaterialApp(
          home: WorkbookImportScreen(
            file: SelectedDatasetFile(
              'sample.xlsx',
              Uint8List.fromList([1, 2, 3]),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sales'));
    await tester.tap(find.text('Costs'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Nhập 2 sheet'));
    await tester.tap(find.text('Nhập 2 sheet'));
    await tester.pumpAndSettle();
    expect(find.text('Đã lưu: Sales'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Nhập 1 sheet'),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Nhập 1 sheet'));
    await tester.pumpAndSettle();
    expect(imports, ['Sales', 'Costs', 'Costs']);
  });

  testWidgets('deleting history refreshes both statistics and list', (
    tester,
  ) async {
    var statsCalls = 0, listCalls = 0;
    var deleted = false;
    final api = ApiClient(
      baseUrl: 'http://localhost:8000',
      client: MockClient((request) async {
        if (request.url.path.endsWith('/stats')) {
          statsCalls++;
          return jsonResponse({
            'total_queries': deleted ? 0 : 1,
            'success_rate_pct': 100,
          });
        }
        if (request.method == 'DELETE') {
          expect(request.url.path, '/api/v1/history/record-1');
          deleted = true;
          return jsonResponse({'message': 'Đã xóa'});
        }
        listCalls++;
        return jsonResponse({
          'data': [
            if (!deleted)
              {
                'id': 'record-1',
                'dataset_name': 'sample.csv',
                'query': 'Doanh thu',
                'status': 'success',
              },
          ],
          'count': deleted ? 0 : 1,
        });
      }),
    )..setToken('synthetic');
    addTearDown(api.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [apiClientProvider.overrideWithValue(api)],
        child: const MaterialApp(home: Scaffold(body: HistoryScreen())),
      ),
    );
    await tester.pumpAndSettle();
    final delete = find.byTooltip('Xóa bản ghi');
    await tester.ensureVisible(delete);
    await tester.tap(delete);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Xóa'));
    await tester.pumpAndSettle();
    expect(deleted, isTrue);
    expect(statsCalls, 2);
    expect(listCalls, 2);
    expect(find.text('sample.csv'), findsNothing);
  });
}
