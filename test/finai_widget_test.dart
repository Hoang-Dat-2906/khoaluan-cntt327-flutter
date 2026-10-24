import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kite/app.dart';
import 'package:kite/core/auth/session.dart';
import 'package:kite/core/network/api_client.dart';
import 'package:kite/features/analysis/analysis_result.dart';
import 'package:kite/features/analysis/analysis_screen.dart';

import 'session_test.dart' show MemoryTokenStore;

void main() {
  testWidgets(
    '360dp login validates without overflow and no template auth shortcuts',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [tokenStoreProvider.overrideWithValue(MemoryTokenStore())],
          child: const KiteApp(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('FinAI Mobile'), findsOneWidget);
      expect(find.text('Đăng nhập'), findsOneWidget);
      expect(
        find.text('Any email works — this is the mock provider.'),
        findsNothing,
      );
      await tester.tap(find.text('Đăng nhập'));
      await tester.pumpAndSettle();
      expect(find.text('Nhập email hợp lệ'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('failed execution is not presented as a success', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final result = AnalysisResult.fromJson(
      {
        'execution_status': 'error',
        'security_status': 'passed',
        'execution_error': 'missing column',
      },
      'd',
      'q',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: AnalysisResultView(result: result),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Thực thi thất bại'), findsOneWidget);
    expect(find.text('Thực thi thành công'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'authenticated route shows real dataset and logout clears session',
    (tester) async {
      final api = ApiClient(
        baseUrl: 'http://example.invalid',
        client: MockClient(
          (r) async => http.Response(
            r.url.path.endsWith('users/me')
                ? '{"id":"u","email":"test@example.invalid","full_name":"Test User","is_active":true,"is_superuser":false}'
                : '{"data":[],"count":0}',
            200,
          ),
        ),
      );
      final store = MemoryTokenStore()..token = 'synthetic';
      addTearDown(api.close);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            apiClientProvider.overrideWithValue(api),
            tokenStoreProvider.overrideWithValue(store),
          ],
          child: const KiteApp(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('0 tệp được phép truy cập'), findsOneWidget);
      await tester.tap(find.text('Cài đặt'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Đăng xuất'));
      await tester.pumpAndSettle();
      expect(find.text('Đăng nhập'), findsOneWidget);
      expect(store.token, isNull);
      expect(tester.takeException(), isNull);
    },
  );
}
