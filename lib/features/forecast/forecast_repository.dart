import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/session.dart';
import '../../core/network/api_client.dart';
import '../datasets/dataset.dart';
import 'forecast.dart';

class ForecastRepository {
  ForecastRepository(this.api);
  final ApiClient api;
  static const models = ['linear_regression', 'polynomial_trend', 'exponential_smoothing'];

  Future<ForecastResult> predict(Dataset dataset, {
    required String target, required String date, required int horizon,
    String model = 'linear_regression',
  }) async {
    dataset.requireUsable();
    final names = dataset.columns.map((column) => column['name']).toSet();
    if (!dataset.numericColumns.contains(target) || !names.contains(date) ||
        date == target || horizon < 1 || horizon > 12 || !models.contains(model)) {
      throw const ApiFailure('Chọn cột số, cột thời gian khác nhau và số kỳ từ 1 đến 12.');
    }
    final json = await api.jsonRequest('forecast/predict', method: 'POST',
      timeout: const Duration(minutes: 2), jsonBody: {
        'dataset_id': dataset.id, 'target_column': target, 'date_column': date,
        'horizon': horizon, 'model_type': model,
      });
    final result = ForecastResult.fromJson(json, dataset.id);
    if (result.target != target || result.model != model || result.future.length != horizon) {
      throw const ApiFailure('Kết quả dự báo không khớp yêu cầu đã gửi.');
    }
    return result;
  }
}

// Results remain in the route state; no cross-session forecast cache.
final forecastRepositoryProvider = Provider<ForecastRepository>(
  (ref) => ForecastRepository(ref.watch(apiClientProvider)),
);
