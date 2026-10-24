import 'dart:convert';
import 'dart:typed_data';

import '../../core/network/api_client.dart';

class AnalysisResult {
  const AnalysisResult({
    required this.datasetId,
    required this.question,
    required this.stdout,
    required this.code,
    required this.execution,
    required this.security,
    required this.error,
    required this.chart,
    this.timeMs,
  });
  final String datasetId, question, stdout, code, execution, security, error;
  final String? chart;
  final double? timeMs;
  bool get successful =>
      execution == 'success' && error.trim().isEmpty && security != 'blocked';
  String get executionLabel => successful
      ? 'Thực thi thành công'
      : switch (execution) {
          'error' => 'Thực thi thất bại',
          'idle' => 'Chưa thực thi',
          'success' => 'Trạng thái mâu thuẫn — cần kiểm tra',
          _ => 'Chưa xác định trạng thái thực thi',
        };
  String get securityLabel => switch (security) {
    'passed' => 'Đã vượt kiểm tra bảo mật',
    'blocked' => 'Bị chặn bởi kiểm tra bảo mật',
    _ => 'Chưa xác định kiểm tra bảo mật',
  };
  factory AnalysisResult.fromJson(
    Map<String, dynamic> j,
    String datasetId,
    String question,
  ) {
    String text(String key, [String fallback = '']) {
      final v = j[key];
      if (v == null) return fallback;
      if (v is! String) {
        throw ApiFailure('Trường $key trong kết quả không hợp lệ.');
      }
      return v;
    }

    final duration = j['execution_time_ms'];
    if (duration != null &&
        (duration is! num || !duration.isFinite || duration < 0)) {
      throw const ApiFailure('Thời gian thực thi không hợp lệ.');
    }
    final chart = text('chart_image');
    return AnalysisResult(
      datasetId: datasetId,
      question: question,
      stdout: text('stdout'),
      code: text('ai_code'),
      execution: text('execution_status', 'unknown'),
      security: text('security_status', 'unknown'),
      error: text('execution_error'),
      chart: chart.isEmpty ? null : chart,
      timeMs: (duration as num?)?.toDouble(),
    );
  }
  Uint8List? inlineChart() {
    final source = chart;
    if (source == null || source.isEmpty) return null;
    if (Uri.tryParse(source)?.hasScheme == true &&
        !source.startsWith('data:')) {
      return null;
    }
    final raw = source.startsWith('data:') ? source.split(',').last : source;
    if (source.startsWith('data:') &&
        !source.startsWith('data:image/png;base64,') &&
        !source.startsWith('data:image/jpeg;base64,')) {
      throw const ApiFailure('Định dạng ảnh chưa được hỗ trợ.');
    }
    if (raw.length > 7 * 1024 * 1024) {
      throw const ApiFailure('Ảnh vượt giới hạn dung lượng.');
    }
    try {
      return base64Decode(raw);
    } on FormatException {
      throw const ApiFailure('Ảnh biểu đồ không phải Base64 hợp lệ.');
    }
  }
}
