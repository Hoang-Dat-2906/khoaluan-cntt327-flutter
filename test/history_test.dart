import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kite/core/auth/session.dart';
import 'package:kite/core/network/api_client.dart';
import 'package:kite/features/history/history_repository.dart';
import 'package:kite/features/history/history_screen.dart';
import 'package:kite/shared/layout/finai_shell.dart';

Map<String, dynamic> record() => {
  'id': 'history-1',
  'dataset_name': 'sales.csv',
  'query': 'Tổng doanh thu',
  'status': 'success',
  'stdout': 'Tổng: 100',
  'ai_code': 'print(100)',
  'execution_time_ms': 12.0,
  'memory_mb': 24.5,
  'chart_image': null,
  'created_at': '2026-11-03T08:00:00Z',
  'dataset_id': null,
};

void main() {
  test(
    'history uses authenticated backend filters, pagination and detail',
    () async {
      final api = ApiClient(
        baseUrl: 'http://localhost:8000',
        client: MockClient((request) async {
          expect(request.headers['Authorization'], 'Bearer test-token');
          if (request.url.path.endsWith('/history/')) {
            expect(request.url.queryParameters, {
              'skip': '20',
              'limit': '20',
              'search': 'doanh thu & lãi',
              'status_filter': 'success',
            });
            return http.Response(
              jsonEncode({
                'data': [record()],
                'count': 21,
              }),
              200,
              headers: {'content-type': 'application/json; charset=utf-8'},
            );
          }
          expect(request.url.path, '/api/v1/history/history-1');
          return http.Response(
            jsonEncode(record()),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      )..setToken('test-token');
      addTearDown(api.close);
      final repository = HistoryRepository(api);
      final page = await repository.list(
        skip: 20,
        search: 'doanh thu & lãi',
        status: 'success',
      );
      expect(page.count, 21);
      expect(
        (await repository.detail(page.records.single.id)).text('stdout'),
        'Tổng: 100',
      );
    },
  );

  testWidgets('history opens saved result without generating new analysis', (
    tester,
  ) async {
    final api = ApiClient(
      baseUrl: 'http://localhost:8000',
      client: MockClient((request) async {
        expect(request.method, 'GET');
        return http.Response(
          jsonEncode(
            request.url.path.endsWith('/history/')
                ? {
                    'data': [record()],
                    'count': 1,
                  }
                : record(),
          ),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    )..setToken('test-token');
    addTearDown(api.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [apiClientProvider.overrideWithValue(api)],
        child: const MaterialApp(home: Scaffold(body: HistoryScreen())),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('sales.csv'), findsOneWidget);
    await tester.tap(find.text('sales.csv'));
    await tester.pumpAndSettle();
    expect(find.text('Chi tiết lịch sử'), findsOneWidget);
    expect(find.text('Tổng: 100'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('mobile navigation includes history at narrow width', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      const MaterialApp(
        home: FinaiShell(location: '/history', child: SizedBox()),
      ),
    );
    expect(find.text('Lịch sử'), findsOneWidget);
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      3,
    );
    expect(tester.takeException(), isNull);
  });
}
