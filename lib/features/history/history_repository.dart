import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/session.dart';
import '../../core/network/api_client.dart';

class HistoryRecord {
  HistoryRecord(this.json) {
    if (json['id'] is! String ||
        json['dataset_name'] is! String ||
        json['query'] is! String ||
        json['status'] is! String) {
      throw const ApiFailure('Dữ liệu lịch sử không hợp lệ.');
    }
  }
  final Map<String, dynamic> json;
  String get id => json['id'] as String;
  String text(String key) => json[key] is String ? json[key] as String : '';
  String get date {
    final parsed = DateTime.tryParse(text('created_at'))?.toLocal();
    if (parsed == null) return 'Chưa có thời gian';
    String pad(int n) => n.toString().padLeft(2, '0');
    return '${pad(parsed.day)}/${pad(parsed.month)}/${parsed.year} ${pad(parsed.hour)}:${pad(parsed.minute)}';
  }
}

class HistoryPage {
  HistoryPage(this.records, this.count);
  final List<HistoryRecord> records;
  final int count;
}

class HistoryRepository {
  HistoryRepository(this.api);
  final ApiClient api;
  static const pageSize = 20;
  Future<HistoryPage> list({
    int skip = 0,
    String search = '',
    String status = '',
  }) async {
    final query = Uri(
      queryParameters: {
        'skip': '$skip',
        'limit': '$pageSize',
        if (search.trim().isNotEmpty) 'search': search.trim(),
        if (status.isNotEmpty) 'status_filter': status,
      },
    ).query;
    final json = await api.jsonRequest('history/?$query');
    if (json['data'] is! List ||
        json['count'] is! int ||
        (json['count'] as int) < 0) {
      throw const ApiFailure('Danh sách lịch sử không hợp lệ.');
    }
    final records = (json['data'] as List).map((item) {
      if (item is! Map<String, dynamic>) {
        throw const ApiFailure('Bản ghi lịch sử không hợp lệ.');
      }
      return HistoryRecord(item);
    }).toList();
    return HistoryPage(records, json['count'] as int);
  }

  Future<HistoryRecord> detail(String id) async => HistoryRecord(
    await api.jsonRequest('history/${Uri.encodeComponent(id)}'),
  );
}

final historyRepositoryProvider = Provider<HistoryRepository>(
  (ref) => HistoryRepository(ref.watch(apiClientProvider)),
);
