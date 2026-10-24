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
    if (query.trim().isEmpty || columns.isEmpty) {
      throw const ApiFailure('Hãy nhập câu hỏi và chọn ít nhất một cột.');
    }
    if (columns.any((c) => c.contains(','))) {
      throw const ApiFailure(
        'API hiện tại chưa hỗ trợ chọn tên cột chứa dấu phẩy. Cần backend hỗ trợ danh sách cột JSON.',
      );
    }
    if (dataset.sizeBytes > ApiClient.maxFileBytes) {
      throw const ApiFailure('Chỉ phân tích file tối đa 15 MB trên mobile.');
    }
    if (!RegExp(
      r'\.(csv|xlsx|xls)$',
      caseSensitive: false,
    ).hasMatch(dataset.filename)) {
      throw const ApiFailure('Định dạng dataset chưa được hỗ trợ.');
    }
    final stamp = api.generation;
    // Compatibility mode, verified against the currently available OpenAPI.
    final bytes = await api.send(
      http.Request(
        'GET',
        api.uri('datasets/${Uri.encodeComponent(dataset.id)}/download'),
      ),
      maxBytes: ApiClient.maxFileBytes,
    );
    if (bytes.isEmpty) throw const ApiFailure('File dữ liệu rỗng.');
    if (api.generation != stamp) {
      throw const ApiFailure('Phiên làm việc đã thay đổi.');
    }
    final request = http.MultipartRequest('POST', api.uri('files/upload'))
      ..fields.addAll({
        'query': query.trim(),
        'scope_columns': columns.join(','),
      })
      ..files.add(
        http.MultipartFile.fromBytes(
          'file',
          bytes,
          filename: dataset.filename.replaceAll(RegExp(r'[/\\]'), '_'),
        ),
      );
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
