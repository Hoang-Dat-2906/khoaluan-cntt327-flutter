// Explicit live smoke test. Credentials come only from the current process.
// Runs exactly one small synthetic analysis and deletes only its own dataset.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:kite/core/network/api_client.dart';
import 'package:kite/features/datasets/dataset.dart';
import 'package:kite/features/datasets/dataset_repository.dart';

void main() {
  final env = Platform.environment;
  test(
    'live FastAPI upload analysis chart and cleanup',
    () async {
      final api = ApiClient(
        baseUrl: env['API_BASE_URL'] ?? 'http://localhost:8000',
      );
      Dataset? created;
      final checks = <String, Object>{};
      try {
        final login = await api.jsonRequest(
          'login/access-token',
          method: 'POST',
          authenticated: false,
          form: {
            'username': env['FINAI_TEST_EMAIL']!,
            'password': env['FINAI_TEST_PASSWORD']!,
          },
        );
        if (login['access_token'] is! String) {
          throw const ApiFailure('No valid token.');
        }
        api.setToken(login['access_token'] as String);
        await api.jsonRequest('users/me');
        checks['login_and_user'] = 'PASS';
        final repo = DatasetRepository(api);
        await repo.list();
        checks['dataset_list'] = 'PASS';
        created = await repo.upload(
          'finai_smoke_${DateTime.now().millisecondsSinceEpoch}.csv',
          Uint8List.fromList(
            utf8.encode(
              'month,revenue,cost\n2025-01,10,5\n2025-02,20,8\n2025-03,30,12\n',
            ),
          ),
        );
        final detail = await repo.detail(created.id);
        if (detail.rows != 3 || detail.columnsCount != 3) {
          throw const ApiFailure('Unexpected uploaded schema.');
        }
        checks['upload_and_detail'] = 'PASS';
        final analysis = await repo.analyze(
          detail,
          'Đọc file CSV này. In tổng cột revenue bằng print. Vẽ doanh thu theo month và lưu output.png. Chỉ dùng dữ liệu trong file. Không tạo dữ liệu thay thế.',
          ['month', 'revenue', 'cost'],
        );
        checks['execution'] = analysis.execution;
        checks['security'] = analysis.security;
        checks['stdout_contains_expected_total_60'] = RegExp(r'\b60(?:\.0)?\b')
            .hasMatch(analysis.stdout);
        checks['chart_bytes_received'] =
            (analysis.inlineChart()?.length ?? 0) > 0;
        expect(analysis.successful, isTrue);
        expect(checks['stdout_contains_expected_total_60'], isTrue);
        expect(checks['chart_bytes_received'], isTrue);
      } on ApiFailure catch (e) {
        checks['failure'] = e.status == null
            ? 'API or analysis failure; no sensitive detail logged'
            : 'HTTP ${e.status}';
        fail('Live API smoke failed; no sensitive detail logged.');
      } catch (_) {
        checks['failure'] =
            'Smoke assertion failed; no sensitive detail logged';
        rethrow;
      } finally {
        if (created != null) {
          try {
            await api.jsonRequest(
              'datasets/${Uri.encodeComponent(created.id)}',
              method: 'DELETE',
            );
            checks['cleanup_own_dataset'] = 'PASS';
          } catch (_) {
            checks['cleanup_own_dataset'] = 'FAIL';
            fail('Could not remove the dataset created by this test.');
          }
        }
        api.setToken(null);
        api.close();
        stdout.writeln(const JsonEncoder.withIndent('  ').convert(checks));
      }
    },
    skip:
        (env['FINAI_TEST_EMAIL'] ?? '').isEmpty ||
        (env['FINAI_TEST_PASSWORD'] ?? '').isEmpty,
  );
}
