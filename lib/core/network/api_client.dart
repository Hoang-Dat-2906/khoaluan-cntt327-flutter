import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

class ApiFailure implements Exception {
  const ApiFailure(this.message, {this.status, this.code});
  final String message;
  final int? status;
  final String? code;
  bool get invalidSession => status == 401 ||
      (status == 403 && code == 'AUTH_008');

  // Deliberately allowlist messages: provider detail may contain secrets/paths.
  factory ApiFailure.fromResponse(int status, List<int> body) {
    String? code;
    if (body.length <= 16384) {
      try {
        final object = jsonDecode(utf8.decode(body));
        if (object is Map && object['code'] is String &&
            RegExp(r'^[A-Z]+_[0-9]{3}$').hasMatch(object['code'] as String)) {
          code = object['code'] as String;
        }
      } on FormatException {
        // Non-JSON proxy/server errors use the HTTP fallback below.
      }
    }
    final known = <String, String>{
      'AUTH_001': 'Email hoặc mật khẩu không đúng.',
      'AUTH_003': 'Tài khoản đã bị khóa. Liên hệ quản trị viên.',
      'AUTH_008': 'Phiên đăng nhập không hợp lệ. Vui lòng đăng nhập lại.',
      'DATASET_001': 'Không tìm thấy dataset. Vui lòng tải lại danh sách.',
      'DATASET_002': 'Bạn không có quyền truy cập dataset này.',
      'DATASET_003': 'Tệp không còn tồn tại — vui lòng tải lại',
      'DATASET_004': 'Không đọc được dữ liệu. Kiểm tra cấu trúc tệp.',
      'DATASET_006': 'Đường dẫn lưu trữ không hợp lệ. Liên hệ quản trị viên.',
      'DATASET_007': 'Chưa lưu được tệp. Vui lòng thử lại.',
      'DATASET_008': 'Kho lưu trữ chưa truy cập được. Vui lòng thử lại.',
      'ANALYSIS_001': 'Không đọc được dữ liệu. Kiểm tra định dạng tệp.',
      'ANALYSIS_002': 'Không thực hiện được phân tích. Kiểm tra cột, số kỳ và dữ liệu đầu vào.',
      'FILE_001': 'Chỉ hỗ trợ định dạng CSV, XLSX hoặc XLS.',
    };
    final fallback = switch (status) {
      400 => 'Yêu cầu không hợp lệ hoặc thông tin đăng nhập không đúng.',
      401 => 'Phiên đăng nhập hết hạn. Vui lòng đăng nhập lại.',
      403 => 'Bạn không có quyền thực hiện thao tác này.',
      404 => 'Không tìm thấy dữ liệu hoặc chức năng trên máy chủ.',
      413 => 'File vượt giới hạn dung lượng máy chủ.',
      422 => 'Dữ liệu gửi lên không đúng định dạng yêu cầu.',
      429 => 'Máy chủ đang giới hạn yêu cầu. Vui lòng thử lại sau.',
      _ => 'Máy chủ chưa xử lý được yêu cầu (HTTP $status).',
    };
    return ApiFailure(known[code] ?? fallback, status: status, code: code);
  }
  @override
  String toString() => message;
}

class ApiClient {
  ApiClient({required String baseUrl, http.Client? client})
    : baseUrl = baseUrl.replaceAll(RegExp(r'/+$'), ''),
      _client = client ?? http.Client();
  final String baseUrl;
  final http.Client _client;
  static const maxFileBytes = 15 * 1024 * 1024;
  String? _token;
  int generation = 0;
  void Function(int)? onUnauthorized;
  void setToken(String? token) {
    _token = token;
    generation++;
  }

  void close() => _client.close();

  Uri uri(String path) {
    final origin = Uri.tryParse(baseUrl);
    if (origin == null ||
        !['http', 'https'].contains(origin.scheme) ||
        origin.host.isEmpty ||
        origin.userInfo.isNotEmpty ||
        (origin.path.isNotEmpty && origin.path != '/') ||
        origin.hasQuery ||
        origin.hasFragment) {
      throw const ApiFailure(
        'API_BASE_URL phải là địa chỉ máy chủ, không kèm /api/v1 hoặc thông tin đăng nhập.',
      );
    }
    return Uri.parse('$baseUrl/api/v1/$path');
  }

  Future<Uint8List> send(
    http.BaseRequest request, {
    bool authenticated = true,
    String? bearer,
    Duration timeout = const Duration(seconds: 25),
    int maxBytes = 8 * 1024 * 1024,
  }) async {
    final stamp = generation;
    if (authenticated && (_token == null || _token!.isEmpty)) {
      throw const ApiFailure('Vui lòng đăng nhập lại.', status: 401);
    }
    request.followRedirects = false;
    final credential = bearer ?? (authenticated ? _token : null);
    if (credential != null) {
      request.headers['Authorization'] = 'Bearer $credential';
    }
    request.headers['Accept'] = 'application/json';
    var waiting = true;
    try {
      return await (() async {
        final response = await _client.send(request);
        if (stamp != generation) {
          throw const ApiFailure('Phiên làm việc đã thay đổi.');
        }
        if (response.statusCode >= 300) {
          final errorBytes = BytesBuilder(copy: false);
          // Consume once, stop at 16 KiB even for chunked/misreported responses.
          await for (final chunk in response.stream) {
            final remaining = 16384 - errorBytes.length;
            if (chunk.length > remaining) {
              // Incomplete/oversized bodies must not be trusted as JSON.
              errorBytes.add(List<int>.filled(16385 - errorBytes.length, 0));
              break;
            }
            errorBytes.add(chunk);
          }
          if (stamp != generation) {
            throw const ApiFailure('Phiên làm việc đã thay đổi.');
          }
          final failure = ApiFailure.fromResponse(
            response.statusCode, errorBytes.takeBytes(),
          );
          if (waiting && authenticated && failure.invalidSession) {
            onUnauthorized?.call(stamp);
          }
          throw failure;
        }
        if ((response.contentLength ?? 0) > maxBytes) {
          unawaited(response.stream.listen((_) {}).cancel());
          throw const ApiFailure('Dữ liệu trả về vượt giới hạn dung lượng.');
        }
        final builder = BytesBuilder(copy: false);
        await for (final chunk in response.stream) {
          if (builder.length + chunk.length > maxBytes) {
            throw const ApiFailure('Dữ liệu trả về vượt giới hạn dung lượng.');
          }
          builder.add(chunk);
        }
        if (stamp != generation) {
          throw const ApiFailure('Phiên làm việc đã thay đổi.');
        }
        return builder.takeBytes();
      })().timeout(timeout);
    } on TimeoutException {
      throw const ApiFailure(
        'Hết thời gian chờ. Máy chủ có thể vẫn đang xử lý; không gửi lại liên tục.',
      );
    } on http.ClientException {
      throw const ApiFailure(
        'Không kết nối được máy chủ. Kiểm tra mạng và API_BASE_URL.',
      );
    } finally {
      waiting = false;
    }
  }

  Future<Map<String, dynamic>> jsonRequest(
    String path, {
    String method = 'GET',
    Map<String, String>? form,
    Map<String, dynamic>? jsonBody,
    Duration timeout = const Duration(seconds: 25),
    bool authenticated = true,
    String? bearer,
  }) async {
    final request = http.Request(method, uri(path));
    if (form != null && jsonBody != null) {
      throw const ApiFailure('Không thể gửi đồng thời form và JSON.');
    }
    if (form != null) request.bodyFields = form;
    if (jsonBody != null) {
      request.headers['Content-Type'] = 'application/json; charset=utf-8';
      request.body = jsonEncode(jsonBody);
    }
    final bytes = await send(
      request,
      authenticated: authenticated,
      bearer: bearer,
      timeout: timeout,
    );
    return decodeObject(bytes);
  }

  static Map<String, dynamic> decodeObject(List<int> bytes) {
    try {
      final value = jsonDecode(utf8.decode(bytes));
      if (value is! Map<String, dynamic>) throw const FormatException();
      return value;
    } on FormatException {
      throw const ApiFailure('Máy chủ trả dữ liệu không đúng cấu trúc JSON.');
    }
  }
}
