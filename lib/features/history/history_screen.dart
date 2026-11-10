import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/session.dart';
import '../../core/network/api_client.dart';
import '../../shared/widgets/finai_design.dart';
import '../../shared/widgets/data_fields.dart';
import '../analysis/analysis_result.dart';
import '../analysis/analysis_screen.dart';
import 'history_repository.dart';

String historyStatusLabel(String status) => switch (status) {
  'success' => 'Thành công',
  'error' => 'Thất bại',
  'idle' => 'Chưa thực thi',
  _ => 'Chưa xác định',
};

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});
  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  final _search = TextEditingController();
  String _status = '';
  int _skip = 0;
  late Future<HistoryPage> _page;
  late Future<Map<String, dynamic>> _stats;
  final _selection = <String>{};
  bool _deleting = false;
  String? _actionMessage;
  @override
  void initState() {
    super.initState();
    _page = _load();
    _stats = ref.read(historyRepositoryProvider).stats();
  }

  Future<HistoryPage> _load() => ref
      .read(historyRepositoryProvider)
      .list(skip: _skip, search: _search.text, status: _status);
  void _reload({bool reset = false, bool stats = false}) {
    setState(() {
      if (reset) _skip = 0;
      _selection.clear();
      _page = _load();
      if (stats) _stats = ref.read(historyRepositoryProvider).stats();
    });
  }

  Future<void> _delete({String? id, bool all = false}) async {
    if (_deleting) return;
    final ids = id != null ? [id] : _selection.toList();
    if (!all && ids.isEmpty) return;
    final user = ref.read(sessionProvider);
    final repo = ref.read(historyRepositoryProvider);
    final generation = repo.api.generation;
    bool current() => mounted && generation == repo.api.generation;
    setState(() {
      _deleting = true;
      _actionMessage = null;
    });
    try {
      final scope = all
          ? user?.role == 'Admin'
                ? 'toàn bộ lịch sử của mọi người dùng'
                : 'toàn bộ lịch sử của bạn'
          : '${ids.length} bản ghi đã chọn';
      if (!await confirmFinaiAction(
            context,
            title: 'Xóa lịch sử',
            description: 'Xóa $scope khỏi hệ thống dùng chung với Web?',
            action: 'Xóa',
          ) ||
          !current())
        return;
      final result = all
          ? await repo.clear()
          : id != null
          ? await repo.delete(id)
          : await repo.bulkDelete(ids);
      if (current()) {
        _actionMessage = result['message'] is String
            ? result['message'] as String
            : 'Đã cập nhật lịch sử.';
        _reload(reset: true, stats: true);
      }
    } catch (e) {
      if (current()) {
        _actionMessage = e is ApiFailure
            ? e.message
            : 'Không xóa được lịch sử.';
        _reload(reset: true, stats: true);
      }
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(sessionProvider, (before, after) {
      if (before?.id != after?.id) {
        _actionMessage = null;
        _reload(reset: true, stats: true);
      }
    });
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const FinaiHeading(
          title: 'Lịch sử phân tích',
          subtitle: 'Xem lại kết quả đã lưu, dùng chung với FinAI Web.',
          icon: Icons.history_rounded,
        ),
        FutureBuilder<Map<String, dynamic>>(
          future: _stats,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done)
              return const LinearProgressIndicator();
            if (!snapshot.hasData)
              return TextButton(
                onPressed: () => _reload(stats: true),
                child: const Text('Tải lại thống kê'),
              );
            final stats = snapshot.data!;
            String metric(String key, [String unit = '']) =>
                stats[key] is num ? '${stats[key]}$unit' : '—';
            return FinaiMetrics(
              values: {
                'Tổng truy vấn': metric('total_queries'),
                'Thành công': metric('success_rate_pct', '%'),
                'Thời gian TB': metric('avg_time_ms', ' ms'),
                'Bộ nhớ TB': metric('avg_memory_mb', ' MB'),
              },
            );
          },
        ),
        if (_actionMessage != null) FinaiNotice(_actionMessage!),
        Wrap(
          spacing: 8,
          children: [
            if (_selection.isNotEmpty)
              TextButton(
                onPressed: _deleting ? null : () => _delete(),
                child: Text('Xóa ${_selection.length} bản ghi'),
              ),
            TextButton(
              onPressed: _deleting ? null : () => _delete(all: true),
              child: const Text('Xóa toàn bộ'),
            ),
          ],
        ),
        TextField(
          controller: _search,
          onSubmitted: (_) => _reload(reset: true),
          decoration: InputDecoration(
            labelText: 'Tìm tên dữ liệu hoặc câu hỏi',
            suffixIcon: IconButton(
              tooltip: 'Tìm kiếm',
              icon: const Icon(Icons.search),
              onPressed: () => _reload(reset: true),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          children: [
            for (final entry in {
              '': 'Tất cả',
              'success': 'Thành công',
              'error': 'Thất bại',
              'idle': 'Chưa thực thi',
            }.entries)
              ChoiceChip(
                label: Text(entry.value),
                selected: _status == entry.key,
                onSelected: (_) {
                  _status = entry.key;
                  _reload(reset: true);
                },
              ),
            IconButton(
              tooltip: 'Tải lại lịch sử',
              onPressed: () => _reload(stats: true),
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        FutureBuilder<HistoryPage>(
          future: _page,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            if (snapshot.hasError) {
              return Column(
                children: [
                  FinaiNotice(
                    snapshot.error is ApiFailure
                        ? (snapshot.error as ApiFailure).message
                        : 'Không tải được lịch sử.',
                    error: true,
                  ),
                  TextButton(
                    onPressed: () => _reload(),
                    child: const Text('Thử lại'),
                  ),
                ],
              );
            }
            final page = snapshot.data!;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('${page.count} kết quả'),
                if (page.records.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'Chưa có lịch sử phù hợp. Các lần phân tích được máy chủ lưu sẽ xuất hiện tại đây.',
                    ),
                  ),
                for (final record in page.records)
                  Card(
                    child: ListTile(
                      isThreeLine: true,
                      leading: Checkbox(
                        value: _selection.contains(record.id),
                        semanticLabel: 'Chọn bản ghi',
                        onChanged: _deleting
                            ? null
                            : (value) => setState(() {
                                if (value == true) {
                                  _selection.add(record.id);
                                } else {
                                  _selection.remove(record.id);
                                }
                              }),
                      ),
                      title: Text(
                        record.text('dataset_name'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        '${record.text('query')}\n${record.date} • ${historyStatusLabel(record.text('status'))}',
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: IconButton(
                        tooltip: 'Xóa bản ghi',
                        icon: const Icon(Icons.delete_outline),
                        onPressed: _deleting
                            ? null
                            : () => _delete(id: record.id),
                      ),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => HistoryDetailScreen(id: record.id),
                        ),
                      ),
                    ),
                  ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: _skip == 0
                          ? null
                          : () {
                              _skip -= HistoryRepository.pageSize;
                              _reload();
                            },
                      child: const Text('Trang trước'),
                    ),
                    Text('Trang ${_skip ~/ HistoryRepository.pageSize + 1}'),
                    TextButton(
                      onPressed:
                          _skip + HistoryRepository.pageSize >= page.count
                          ? null
                          : () {
                              _skip += HistoryRepository.pageSize;
                              _reload();
                            },
                      child: const Text('Trang sau'),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class HistoryDetailScreen extends ConsumerStatefulWidget {
  const HistoryDetailScreen({super.key, required this.id});
  final String id;
  @override
  ConsumerState<HistoryDetailScreen> createState() =>
      _HistoryDetailScreenState();
}

class _HistoryDetailScreenState extends ConsumerState<HistoryDetailScreen> {
  String _tab = 'Tổng quan';
  @override
  void initState() {
    super.initState();
    ref.listenManual(sessionProvider, (previous, next) {
      if (previous != next && mounted) Navigator.of(context).pop();
    });
  }

  late Future<HistoryRecord> _record = ref
      .read(historyRepositoryProvider)
      .detail(widget.id);
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Chi tiết lịch sử')),
    body: FutureBuilder<HistoryRecord>(
      future: _record,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  snapshot.error is ApiFailure
                      ? (snapshot.error as ApiFailure).message
                      : 'Không tải được chi tiết.',
                ),
                TextButton(
                  onPressed: () => setState(() {
                    _record = ref
                        .read(historyRepositoryProvider)
                        .detail(widget.id);
                  }),
                  child: const Text('Thử lại'),
                ),
              ],
            ),
          );
        }
        final record = snapshot.data!;
        final result = AnalysisResult.fromJson(
          {
            ...record.json,
            'execution_status': record.text('status'),
            'execution_error': record.text('error_message'),
          },
          record.text('dataset_id'),
          record.text('query'),
        );
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            FinaiHeading(
              title: record.text('dataset_name'),
              subtitle: record.date,
              icon: Icons.history,
            ),
            Wrap(
              spacing: 8,
              children: [
                for (final tab in [
                  'Tổng quan',
                  'Kết quả',
                  'Mã Python',
                  if (result.chart != null) 'Biểu đồ',
                ])
                  ChoiceChip(
                    label: Text(tab),
                    selected: _tab == tab,
                    onSelected: (_) => setState(() => _tab = tab),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (_tab == 'Tổng quan') ...[
              Text(historyStatusLabel(record.text('status'))),
              Text(safeTechnicalText(record.text('query'))),
              if (record.text('scope_columns').isNotEmpty)
                Text('Cột phân tích: ${record.text('scope_columns')}'),
              Text(
                'Thời gian: ${result.timeMs ?? '—'} ms • Bộ nhớ: ${record.json['memory_mb'] ?? '—'} MB',
              ),
              if (result.error.isNotEmpty)
                FinaiNotice(safeTechnicalText(result.error), error: true),
              if (result.stdout.isNotEmpty)
                FinaiSection(
                  title: 'Kết quả đã lưu',
                  child: AnalysisMarkdown(result.stdout),
                ),
            ],
            if (_tab == 'Biểu đồ' && result.chart != null)
              ResultChart(result: result),
            if (_tab == 'Kết quả' || _tab == 'Mã Python')
              _copyable(
                _tab == 'Kết quả' ? result.stdout : result.code,
                technical: _tab == 'Mã Python',
              ),
          ],
        );
      },
    ),
  );

  Widget _copyable(String content, {required bool technical}) {
    final text = safeTechnicalText(content);
    return FinaiSection(
      title: _tab,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextButton.icon(
            icon: const Icon(Icons.copy),
            label: const Text('Sao chép'),
            onPressed: text.isEmpty
                ? null
                : () async {
                    await Clipboard.setData(ClipboardData(text: text));
                    if (mounted)
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Đã sao chép.')),
                      );
                  },
          ),
          if (text.isEmpty)
            const Text('Bản ghi không có nội dung này.')
          else if (technical)
            FinaiMono(text, technical: true)
          else
            AnalysisMarkdown(text),
        ],
      ),
    );
  }
}
