import 'dart:convert';

import '../../core/network/api_client.dart';

class Dataset {
  Dataset({
    required this.id,
    required this.filename,
    required this.type,
    required this.sizeBytes,
    required this.rows,
    required this.columnsCount,
    required this.version,
    required this.status,
    required this.profile,
    this.schemaWarning,
    this.fileAvailable,
    this.storageStatus = 'unknown',
  });
  final String id, filename, type, status;
  final int sizeBytes, rows, columnsCount, version;
  final Map<String, dynamic> profile;
  final String? schemaWarning;
  final bool? fileAvailable;
  final String storageStatus;
  bool get fileBlocked => fileAvailable == false ||
      ['missing', 'invalid_path', 'unavailable'].contains(storageStatus) ||
      ['missing', 'error', 'processing'].contains(status);
  String get storageMessage {
    if (storageStatus == 'missing' || status == 'missing' ||
        (fileAvailable == false &&
            !['invalid_path', 'unavailable'].contains(storageStatus))) {
      return 'Tệp không còn tồn tại — vui lòng tải lại';
    }
    if (storageStatus == 'invalid_path') {
      return 'Đường dẫn lưu trữ không hợp lệ. Liên hệ quản trị viên.';
    }
    if (storageStatus == 'unavailable') {
      return 'Kho lưu trữ chưa truy cập được. Vui lòng thử lại.';
    }
    if (fileBlocked) return 'Dataset chưa sẵn sàng để phân tích.';
    if (fileAvailable != true || storageStatus != 'available') {
      return 'Chưa xác nhận tệp còn tồn tại. Máy chủ sẽ kiểm tra khi sử dụng.';
    }
    return 'Tệp đang có trong kho lưu trữ.';
  }

  void requireUsable() {
    if (fileBlocked) {
      throw ApiFailure(storageMessage,
        code: storageStatus == 'missing' || status == 'missing' ||
            (fileAvailable == false &&
                !['invalid_path', 'unavailable'].contains(storageStatus))
            ? 'DATASET_003' : null);
    }
  }

  List<String> get numericColumns => columns.where((c) {
    final dtype = '${c['dtype'] ?? ''}'.toLowerCase();
    return RegExp(r'int|float|double|decimal|numeric|number').hasMatch(dtype) ||
        '${c['type_category'] ?? ''}'.contains('Numeric');
  }).map((c) => c['name'] as String).toList();
  List<Map<String, dynamic>> get columns => (profile['columns'] as List? ?? [])
      .whereType<Map<String, dynamic>>()
      .toList();
  bool get needsReview =>
      schemaWarning != null ||
      columns.isEmpty ||
      columns.any((c) => '${c['name']}'.startsWith('Unnamed')) ||
      profile.containsKey('error');
  factory Dataset.fromJson(Map<String, dynamic> j) {
    if (j['id'] is! String || j['filename'] is! String) {
      throw const ApiFailure('Thông tin dataset không hợp lệ.');
    }
    Map<String, dynamic> profile = {};
    String? warning;
    try {
      dynamic raw = j['schema_info'];
      if (raw is String) raw = jsonDecode(raw);
      if (raw is List) raw = <String, dynamic>{'columns': raw};
      if (raw == null) {
        warning = 'Chưa có schema.';
      } else if (raw is Map<String, dynamic> &&
          raw['columns'] is List &&
          (raw['columns'] as List).every(
            (c) => c is Map && c['name'] is String,
          )) {
        profile = raw;
      } else {
        warning = 'Schema trả về không hợp lệ.';
      }
    } on FormatException {
      warning = 'Không đọc được JSON schema.';
    }
    int integer(String key) {
      final v = j[key];
      if (v is! num || v < 0 || !v.isFinite || v != v.toInt()) {
        throw ApiFailure('Trường $key không hợp lệ.');
      }
      return v.toInt();
    }

    if (j['file_available'] != null && j['file_available'] is! bool ||
        j['storage_status'] != null && j['storage_status'] is! String) {
      throw const ApiFailure('Trạng thái kho lưu trữ không hợp lệ.');
    }
    return Dataset(
      id: j['id'] as String,
      filename: j['filename'] as String,
      type: j['file_type'] is String ? j['file_type'] as String : '',
      sizeBytes: integer('size_bytes'),
      rows: integer('row_count'),
      columnsCount: integer('column_count'),
      version: integer('version'),
      status: j['status'] is String ? j['status'] as String : 'unknown',
      profile: profile,
      schemaWarning: warning,
      fileAvailable: j['file_available'] as bool?,
      storageStatus: j['storage_status'] as String? ?? 'unknown',
    );
  }
}

class DatasetPage {
  const DatasetPage(this.items, this.count);
  final List<Dataset> items;
  final int count;
  factory DatasetPage.fromJson(Map<String, dynamic> j) {
    if (j['data'] is! List ||
        j['count'] is! int ||
        (j['count'] as int) < 0 ||
        !(j['data'] as List).every((v) => v is Map<String, dynamic>)) {
      throw const ApiFailure(
        'Danh sách dataset không đúng định dạng data/count.',
      );
    }
    return DatasetPage(
      (j['data'] as List)
          .map((v) => Dataset.fromJson(v as Map<String, dynamic>))
          .toList(),
      j['count'] as int,
    );
  }
}
