import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/session.dart';
import '../../core/network/api_client.dart';
import '../../shared/widgets/finai_design.dart';
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
  @override
  void initState() {
    super.initState();
    _page = _load();
  }

  Future<HistoryPage> _load() => ref
      .read(historyRepositoryProvider)
      .list(skip: _skip, search: _search.text, status: _status);
  void _reload({bool reset = false}) {
    setState(() {
      if (reset) _skip = 0;
      _page = _load();
    });
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(sessionProvider, (_, _) => _reload(reset: true));
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const FinaiHeading(
          title: 'Lịch sử phân tích',
          subtitle: 'Xem lại kết quả đã lưu, dùng chung với FinAI Web.',
          icon: Icons.history_rounded,
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
              onPressed: () => _reload(),
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
                      leading: Icon(
                        record.text('status') == 'success'
                            ? Icons.check_circle_outline
                            : Icons.error_outline,
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
                      trailing: const Icon(Icons.chevron_right),
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
            Text(historyStatusLabel(record.text('status'))),
            const SizedBox(height: 12),
            Text(safeTechnicalText(record.text('query'))),
            if (record.text('scope_columns').isNotEmpty)
              Text('Cột phân tích: ${record.text('scope_columns')}'),
            Text(
              'Thời gian: ${result.timeMs ?? 0} ms • Bộ nhớ: ${record.json['memory_mb'] ?? 0} MB',
            ),
            if (result.error.isNotEmpty)
              FinaiNotice(safeTechnicalText(result.error), error: true),
            const SizedBox(height: 16),
            FinaiSection(
              title: 'Kết quả',
              child: FinaiMono(
                result.stdout.isEmpty
                    ? 'Không có kết quả văn bản.'
                    : safeTechnicalText(result.stdout),
              ),
            ),
            if (result.chart != null) ResultChart(result: result),
            ExpansionTile(
              title: const Text('Mã Python'),
              children: [
                FinaiMono(safeTechnicalText(result.code), technical: true),
              ],
            ),
          ],
        );
      },
    ),
  );
}
