import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/session.dart';
import '../../core/network/api_client.dart';
import '../datasets/dataset.dart';
import 'forecast.dart';

class ForecastRepository {
  ForecastRepository(this.api);
  final ApiClient api;
  static const models = [
    'linear_regression',
    'polynomial_trend',
    'exponential_smoothing',
    'arima',
    'lstm_neural_trend',
  ];

  Future<ForecastResult> predict(
    Dataset dataset, {
    required String target,
    required String? date,
    required int horizon,
    String model = 'linear_regression',
  }) async {
    dataset.requireUsable();
    final names = dataset.columns.map((column) => column['name']).toSet();
    if (!dataset.numericColumns.contains(target) ||
        (date != null && !names.contains(date)) ||
        date == target ||
        horizon < 1 ||
        horizon > 12 ||
        !models.contains(model)) {
      throw const ApiFailure(
        'Chọn cột số, số kỳ từ 1 đến 12 và cột thời gian khác cột số nếu có.',
      );
    }
    final json = await api.jsonRequest(
      'forecast/predict',
      method: 'POST',
      timeout: const Duration(minutes: 2),
      jsonBody: {
        'dataset_id': dataset.id,
        'target_column': target,
        'date_column': date,
        'horizon': horizon,
        'model_type': model,
      },
    );
    final result = ForecastResult.fromJson(json, dataset.id);
    if (result.target != target ||
        result.model != model ||
        result.future.length != horizon) {
      throw const ApiFailure('Kết quả dự báo không khớp yêu cầu đã gửi.');
    }
    return result;
  }

  Future<Map<String, dynamic>> recommendations(String id) async => _data(
    await api.jsonRequest(
      'forecast/recommendations/${Uri.encodeComponent(id)}',
    ),
  );

  Future<Map<String, dynamic>> cluster(
    Dataset dataset,
    List<String> features,
    int clusters,
    String? idColumn,
  ) {
    dataset.requireUsable();
    if (features.toSet().length < 2 ||
        !features.every(dataset.numericColumns.contains) ||
        clusters < 2 ||
        clusters > 6 ||
        (idColumn != null &&
            !dataset.columns.any((column) => column['name'] == idColumn))) {
      throw const ApiFailure('Chọn ít nhất hai cột số và từ 2 đến 6 cụm.');
    }
    return _run('analytics/clustering', dataset.id, {
      'features': features,
      'n_clusters': clusters,
      'id_column': idColumn,
    });
  }

  Future<Map<String, dynamic>> classify(
    Dataset dataset,
    String target,
    List<String> features,
    double testSize,
  ) {
    dataset.requireUsable();
    final names = dataset.columns.map((column) => column['name']).toSet();
    if (!names.contains(target) ||
        features.isEmpty ||
        !features.every(names.contains) ||
        features.contains(target) ||
        !testSize.isFinite ||
        testSize < .15 ||
        testSize > .4) {
      throw const ApiFailure(
        'Chọn biến đích, các cột đặc trưng khác biến đích và tập kiểm tra từ 15–40%.',
      );
    }
    return _run('forecast/classification', dataset.id, {
      'target_column': target,
      'feature_columns': features,
      'test_size': testSize,
    });
  }

  Future<Map<String, dynamic>> _run(
    String path,
    String id,
    Map<String, dynamic> fields,
  ) async => _data(
    await api.jsonRequest(
      path,
      method: 'POST',
      timeout: const Duration(minutes: 2),
      jsonBody: {'dataset_id': id, ...fields},
    ),
  );

  Map<String, dynamic> _data(Map<String, dynamic> response) {
    final data = response['data'];
    if (response['status'] != 'success' || data is! Map<String, dynamic>) {
      throw const ApiFailure('Kết quả mô hình không đúng cấu trúc.');
    }
    return data;
  }
}

// Results remain in the route state; no cross-session forecast cache.
final forecastRepositoryProvider = Provider<ForecastRepository>(
  (ref) => ForecastRepository(ref.watch(apiClientProvider)),
);
final recommendationsProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>, String>((ref, id) {
      ref.watch(sessionProvider);
      return ref.watch(forecastRepositoryProvider).recommendations(id);
    }, retry: (_, _) => null);
