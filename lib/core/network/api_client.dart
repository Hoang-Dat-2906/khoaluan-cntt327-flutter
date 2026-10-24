import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

class ApiFailure implements Exception {
  const ApiFailure(this.message, {this.status});
  final String message;
  final int? status;
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
    try {
      return await (() async {
        final response = await _client.send(request);
        if (stamp != generation) {
          throw const ApiFailure('Phiên làm việc đã thay đổi.');
        }
        if (response.statusCode == 401 && authenticated) {
          onUnauthorized?.call(stamp);
        }
        if (response.statusCode >= 300) {
          // Never forward raw backend tracebacks, credentials or API-provider errors.
          unawaited(response.stream.listen((_) {}).cancel());
          throw ApiFailure(switch (response.statusCode) {
            400 => 'Yêu cầu không hợp lệ hoặc thông tin đăng nhập không đúng.',
            401 => 'Phiên đăng nhập hết hạn. Vui lòng đăng nhập lại.',
            403 => 'Bạn không có quyền truy cập dữ liệu này.',
            404 =>
              'Không tìm thấy dữ liệu hoặc file đã không còn trên máy chủ.',
            413 => 'File vượt giới hạn dung lượng máy chủ.',
            422 => 'Dữ liệu gửi lên không đúng định dạng yêu cầu.',
            429 => 'Máy chủ đang giới hạn yêu cầu. Vui lòng thử lại sau.',
            _ =>
              'Máy chủ chưa xử lý được yêu cầu (HTTP ${response.statusCode}).',
          }, status: response.statusCode);
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
    }
  }

  Future<Map<String, dynamic>> jsonRequest(
    String path, {
    String method = 'GET',
    Map<String, String>? form,
    bool authenticated = true,
    String? bearer,
  }) async {
    final request = http.Request(method, uri(path));
    if (form != null) request.bodyFields = form;
    final bytes = await send(
      request,
      authenticated: authenticated,
      bearer: bearer,
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
