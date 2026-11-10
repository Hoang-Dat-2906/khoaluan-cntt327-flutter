import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../core/auth/session.dart';
import '../../core/network/api_client.dart';
import '../analysis/analysis_result.dart';
import 'dataset.dart';

class DatasetRepository {
  DatasetRepository(this.api);
  final ApiClient api;
  Future<DatasetPage> list({int skip = 0}) async => DatasetPage.fromJson(
    await api.jsonRequest('datasets/?skip=$skip&limit=100'),
  );
  Future<Dataset> detail(String id) async => Dataset.fromJson(
    await api.jsonRequest('datasets/${Uri.encodeComponent(id)}'),
  );
  Future<Dataset> upload(String filename, Uint8List bytes) async {
    if (!RegExp(
      r'\.(csv|xlsx|xls)$',
      caseSensitive: false,
    ).hasMatch(filename)) {
      throw const ApiFailure('Chỉ hỗ trợ CSV, XLSX hoặc XLS.');
    }
    if (bytes.isEmpty || bytes.length > ApiClient.maxFileBytes) {
      throw const ApiFailure('File phải có dữ liệu và không vượt 15 MB.');
    }
    final request = http.MultipartRequest('POST', api.uri('datasets/upload'))
      ..files.add(
        http.MultipartFile.fromBytes('file', bytes, filename: filename),
      );
    return Dataset.fromJson(
      ApiClient.decodeObject(
        await api.send(request, timeout: const Duration(seconds: 60)),
      ),
    );
  }

  Future<AnalysisResult> analyze(
    Dataset dataset,
    String query,
    List<String> columns,
  ) async {
    dataset.requireUsable();
    if (query.trim().isEmpty) {
      throw const ApiFailure('Hãy nhập câu hỏi phân tích.');
    }
    final names = dataset.columns.map((c) => c['name']).toSet();
    if (columns.any((c) => !names.contains(c))) {
      throw const ApiFailure(
        'Cột đã chọn không còn trong schema. Hãy tải lại dataset.',
      );
    }
    if (columns.any((c) => c.contains(','))) {
      throw const ApiFailure(
        'API hiện tại chưa hỗ trợ chọn tên cột chứa dấu phẩy. Cần backend hỗ trợ danh sách cột JSON.',
      );
    }
    final request =
        http.MultipartRequest(
            'POST',
            api.uri('files/analyze-dataset-conversational'),
          )
          ..fields.addAll({
            'dataset_id': dataset.id,
            'query': query.trim(),
            if (columns.isNotEmpty) 'scope_columns': columns.join(','),
          });
    final response = await api.send(
      request,
      timeout: const Duration(minutes: 6),
    );
    return AnalysisResult.fromJson(
      ApiClient.decodeObject(response),
      dataset.id,
      query.trim(),
    );
  }

  Future<Map<String, dynamic>> _workbookRequest(
    String path,
    String filename,
    Uint8List bytes, {
    Map<String, String> fields = const {},
  }) async {
    if (!RegExp(
          r'\.(csv|xlsx|xls)$',
          caseSensitive: false,
        ).hasMatch(filename) ||
        bytes.isEmpty ||
        bytes.length > ApiClient.maxFileBytes) {
      throw const ApiFailure(
        'Chọn tệp CSV, XLSX hoặc XLS có dữ liệu và không vượt 15 MB.',
      );
    }
    final request = http.MultipartRequest('POST', api.uri(path))
      ..fields.addAll(fields)
      ..files.add(
        http.MultipartFile.fromBytes('file', bytes, filename: filename),
      );
    return ApiClient.decodeObject(
      await api.send(request, timeout: const Duration(minutes: 2)),
    );
  }

  Future<Map<String, dynamic>> inspect(String filename, Uint8List bytes) =>
      _workbookRequest('datasets/inspect-workbook', filename, bytes);

  Future<Dataset> importWorkbook(
    String filename,
    Uint8List bytes,
    Map<String, dynamic> config, {
    String description = '',
  }) async => Dataset.fromJson(
    await _workbookRequest(
      'datasets/upload-interactive',
      filename,
      bytes,
      fields: {
        'config': jsonEncode(config),
        if (description.trim().isNotEmpty) 'description': description.trim(),
      },
    ),
  );

  String _path(String id) => 'datasets/${Uri.encodeComponent(id)}';
  Future<Map<String, dynamic>> quality(String id) =>
      api.jsonRequest('${_path(id)}/quality-report');
  Future<Map<String, dynamic>> schema(String id) =>
      api.jsonRequest('${_path(id)}/schema-analysis');
  Future<Dataset> clean(String id) async => Dataset.fromJson(
    await api.jsonRequest(
      '${_path(id)}/clean',
      method: 'POST',
      timeout: const Duration(minutes: 2),
    ),
  );
  Future<void> delete(String id) async =>
      api.jsonRequest(_path(id), method: 'DELETE');
  Future<Map<String, dynamic>> bulkDelete(List<String> ids) => api.jsonRequest(
    'datasets/bulk-delete',
    method: 'POST',
    jsonBody: {'ids': ids},
  );
  Future<Uint8List> download(String id) => api.send(
    http.Request('GET', api.uri('${_path(id)}/download')),
    maxBytes: ApiClient.maxFileBytes,
  );

  Future<Uint8List> exportFile(String filename) {
    if (filename.isEmpty ||
        filename == '.' ||
        filename == '..' ||
        RegExp(r'[/\\\x00-\x1f]').hasMatch(filename)) {
      throw const ApiFailure('Tên tệp xuất không hợp lệ.');
    }
    return api.send(
      http.Request(
        'GET',
        api.uri('files/download-export/${Uri.encodeComponent(filename)}'),
      ),
      maxBytes: ApiClient.maxFileBytes,
    );
  }

  Future<Uint8List> chart(String source) async {
    final target = Uri.tryParse(source);
    final origin = Uri.tryParse(api.baseUrl);
    if (target == null || origin == null) {
      throw const ApiFailure('Địa chỉ ảnh không hợp lệ.');
    }
    final resolved = origin.resolveUri(target);
    if (!['http', 'https'].contains(resolved.scheme) ||
        resolved.origin != origin.origin ||
        resolved.userInfo.isNotEmpty) {
      throw const ApiFailure('Ảnh ngoài máy chủ API không được tự động tải.');
    }
    return api.send(http.Request('GET', resolved), maxBytes: 5 * 1024 * 1024);
  }
}

final datasetRepositoryProvider = Provider<DatasetRepository>(
  (ref) => DatasetRepository(ref.watch(apiClientProvider)),
);
final datasetsProvider = FutureProvider.autoDispose<DatasetPage>((ref) {
  final user = ref.watch(sessionProvider);
  if (user == null) throw const ApiFailure('Vui lòng đăng nhập.');
  return ref.watch(datasetRepositoryProvider).list();
}, retry: (_, _) => null);
final datasetDetailProvider = FutureProvider.autoDispose
    .family<Dataset, String>((ref, id) {
      if (ref.watch(sessionProvider) == null) {
        throw const ApiFailure('Vui lòng đăng nhập.');
      }
      return ref.watch(datasetRepositoryProvider).detail(id);
    }, retry: (_, _) => null);
