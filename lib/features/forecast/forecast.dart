import '../../core/network/api_client.dart';

class ForecastPoint {
  const ForecastPoint(
    this.period,
    this.value, {
    this.fitted,
    this.lower,
    this.upper,
  });
  final String period;
  final double value;
  final double? fitted, lower, upper;
}

class ForecastResult {
  const ForecastResult({
    required this.datasetId,
    required this.datasetName,
    required this.target,
    required this.model,
    required this.metrics,
    required this.actual,
    required this.future,
    this.chart,
    this.timeMs,
    this.methodName,
    this.summary,
    this.growth,
  });
  final String datasetId, datasetName, target, model;
  final Map<String, double?> metrics;
  final List<ForecastPoint> actual, future;
  final String? chart;
  final double? timeMs;
  final String? methodName, summary;
  final double? growth;

  bool get containsZeroActual => actual.any((point) => point.value == 0);
  static double? finite(Object? value) =>
      value is num && value.isFinite ? value.toDouble() : null;

  factory ForecastResult.fromJson(Map<String, dynamic> json, String datasetId) {
    final data = json['data'];
    if (json['status'] != 'success' ||
        data is! Map<String, dynamic> ||
        json['dataset_name'] is! String ||
        data['target_column'] is! String ||
        data['model_type'] is! String ||
        data['metrics'] is! Map) {
      throw const ApiFailure('Kết quả dự báo không đúng cấu trúc.');
    }
    List<ForecastPoint> points(String key, bool future) {
      final list = data[key];
      if (list is! List || list.isEmpty || list.length > 10000) {
        throw const ApiFailure('Dự báo chưa có bảng dữ liệu hợp lệ.');
      }
      return list
          .map((row) {
            if (row is! Map ||
                row['period'] is! String ||
                (row['period'] as String).trim().isEmpty) {
              throw const ApiFailure('Kỳ dự báo không hợp lệ.');
            }
            final value = finite(
              row[future ? 'forecast_value' : 'actual_value'],
            );
            if (value == null)
              throw const ApiFailure('Giá trị dự báo không hợp lệ.');
            return ForecastPoint(
              row['period'] as String,
              value,
              fitted: finite(row['fitted_value']),
              lower: finite(row['lower_bound']),
              upper: finite(row['upper_bound']),
            );
          })
          .toList(growable: false);
    }

    final metrics = data['metrics'] as Map;
    final chart = data['chart_image'];
    if (chart != null && chart is! String) {
      throw const ApiFailure('Định dạng ảnh dự báo không hợp lệ.');
    }
    final time = finite(json['execution_time_ms']);
    return ForecastResult(
      datasetId: datasetId,
      datasetName: json['dataset_name'] as String,
      target: data['target_column'] as String,
      model: data['model_type'] as String,
      metrics: {
        for (final key in ['mae', 'rmse', 'mape', 'r2'])
          key: finite(metrics[key]),
      },
      actual: points('historical_table', false),
      future: points('forecast_table', true),
      chart: chart is String && chart.isNotEmpty ? chart : null,
      timeMs: time != null && time >= 0 ? time : null,
      methodName: data['model_method_name'] is String
          ? data['model_method_name'] as String
          : null,
      summary: data['summary'] is String ? data['summary'] as String : null,
      growth: finite(data['growth_rate_pct'] ?? metrics['growth_rate_pct']),
    );
  }
}
