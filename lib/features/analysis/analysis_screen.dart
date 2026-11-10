import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/session.dart';
import '../../core/network/api_client.dart';
import '../../shared/widgets/finai_design.dart';
import '../datasets/dataset.dart';
import '../datasets/dataset_repository.dart';
import '../datasets/dataset_screens.dart';
import '../forecast/forecast_repository.dart';
import 'analysis_result.dart';

String safeTechnicalText(String source, {int maxLength = 50000}) {
  var text = source
      .replaceAll(RegExp(r'AIza[\w-]+'), '[API KEY ĐÃ ẨN]')
      .replaceAll(
        RegExp(r'Bearer\s+[A-Za-z0-9._~+/-]+', caseSensitive: false),
        'Bearer [TOKEN ĐÃ ẨN]',
      )
      .replaceAll(
        RegExp(r'eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+'),
        '[JWT ĐÃ ẨN]',
      );
  if (text.length > maxLength) {
    text =
        '${text.substring(0, maxLength)}\n[Nội dung đã giới hạn độ dài trên mobile]';
  }
  return text;
}

class AnalysisScreen extends ConsumerWidget {
  const AnalysisScreen({super.key, this.id});
  final String? id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(sessionProvider);
    return _AnalysisWorkspace(key: ValueKey((user?.id, id)), initialId: id);
  }
}

class _AnalysisWorkspace extends ConsumerStatefulWidget {
  const _AnalysisWorkspace({super.key, this.initialId});
  final String? initialId;
  @override
  ConsumerState<_AnalysisWorkspace> createState() => _AnalysisWorkspaceState();
}

class _AnalysisWorkspaceState extends ConsumerState<_AnalysisWorkspace> {
  final _query = TextEditingController();
  final _scroll = ScrollController();
  final _conversations =
      <
        String,
        List<({String question, AnalysisResult? result, String? error})>
      >{};
  final _pending = <String, String>{};
  final _blocked = <String>{};
  final _scopes = <String, Set<String>>{};
  String? _selectedId;
  String? get _id => widget.initialId ?? _selectedId;

  @override
  void dispose() {
    _query.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _toLatest() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _ask(Dataset dataset) async {
    final question = _query.text.trim();
    final id = dataset.id;
    if (question.isEmpty || _pending.containsKey(id)) return;
    final api = ref.read(apiClientProvider);
    final generation = api.generation;
    bool current() => mounted && api.generation == generation;
    setState(() {
      _pending[id] = question;
      _query.clear();
    });
    _toLatest();
    AnalysisResult? result;
    String? error;
    try {
      result = await ref
          .read(datasetRepositoryProvider)
          .analyze(dataset, question, _scopes[id]?.toList() ?? const []);
    } on ApiFailure catch (e) {
      error = e.message;
      if (current() &&
          [
            'DATASET_001',
            'DATASET_003',
            'DATASET_006',
            'DATASET_008',
          ].contains(e.code)) {
        _blocked.add(id);
      }
    } catch (_) {
      error = 'Không đọc được kết quả phân tích.';
    }
    if (!current()) return;
    setState(() {
      _pending.remove(id);
      (_conversations[id] ??= []).add((
        question: question,
        result: result,
        error: error,
      ));
    });
    if (_id == id) _toLatest();
  }

  @override
  Widget build(BuildContext context) {
    final id = _id;
    final datasets = widget.initialId == null
        ? ref.watch(datasetsProvider)
        : null;
    final detail = id == null ? null : ref.watch(datasetDetailProvider(id));
    final dataset = detail?.asData?.value;
    final pending = _pending[id];
    final canSend =
        dataset != null &&
        !dataset.fileBlocked &&
        !_blocked.contains(id) &&
        pending == null;
    return Column(
      children: [
        Expanded(
          child: ListView(
            controller: _scroll,
            padding: const EdgeInsets.all(16),
            children: [
              const FinaiHeading(
                title: 'Trợ lý phân tích',
                subtitle: 'Chọn tập dữ liệu và đặt câu hỏi.',
                icon: Icons.auto_awesome_rounded,
              ),
              if (datasets != null)
                datasets.when(
                  loading: () => const LinearProgressIndicator(),
                  error: (e, _) => LoadFailure(
                    error: e,
                    retry: () => ref.invalidate(datasetsProvider),
                  ),
                  data: (page) => page.items.isEmpty
                      ? TextButton(
                          onPressed: () => context.go('/datasets'),
                          child: const Text('Tải tệp lên Kho dữ liệu'),
                        )
                      : DropdownButtonFormField<String>(
                          key: ValueKey(id),
                          initialValue: page.items.any((d) => d.id == id)
                              ? id
                              : null,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Tập dữ liệu',
                          ),
                          items: [
                            for (final d in page.items)
                              DropdownMenuItem(
                                value: d.id,
                                child: Text(
                                  d.filename,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                          ],
                          onChanged: (value) => setState(() {
                            _selectedId = value;
                            _query.clear();
                          }),
                        ),
                ),
              if (id != null && detail != null)
                detail.when(
                  loading: () => const LinearProgressIndicator(),
                  error: (e, _) => LoadFailure(
                    error: e,
                    retry: () => ref.invalidate(datasetDetailProvider(id)),
                  ),
                  data: (d) => Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (widget.initialId != null)
                        Text(
                          d.filename,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      if (d.fileBlocked || _blocked.contains(id))
                        FinaiNotice(
                          d.fileBlocked ? d.storageMessage : 'Không truy cập được tệp. Hãy tải lại trạng thái.',
                          warning: true,
                        ),
                      TextButton(
                        onPressed: pending != null
                            ? null
                            : () {
                                setState(() => _blocked.remove(id));
                                ref.invalidate(datasetDetailProvider(id));
                              },
                        child: const Text('Tải lại trạng thái dataset'),
                      ),
                      if (d.columns.isNotEmpty)
                        ExpansionTile(
                          title: const Text('Phạm vi cột (mặc định tất cả)'),
                          children: [
                            Wrap(
                              spacing: 6,
                              children: [
                                for (final column in d.columns)
                                  FilterChip(
                                    label: Text('${column['name']}'),
                                    selected:
                                        _scopes[id]?.contains(column['name']) ??
                                        false,
                                    onSelected:
                                        canSend &&
                                            !(column['name'] as String)
                                                .contains(',')
                                        ? (selected) {
                                            setState(() {
                                              final scope = _scopes[id] ??= {};
                                              if (selected) {
                                                scope.add(
                                                  column['name'] as String,
                                                );
                                              } else {
                                                scope.remove(column['name']);
                                              }
                                            });
                                          }
                                        : null,
                                  ),
                              ],
                            ),
                          ],
                        ),
                      if (!d.fileBlocked)
                        AnalysisSuggestions(
                          dataset: d,
                          onChoose: canSend
                              ? (text) => _query.text = text
                              : null,
                        ),
                    ],
                  ),
                ),
              for (final turn
                  in _conversations[id] ??
                      const <
                        ({
                          String question,
                          AnalysisResult? result,
                          String? error,
                        })
                      >[]) ...[
                Align(
                  alignment: Alignment.centerRight,
                  child: Chip(label: Text(turn.question)),
                ),
                if (turn.result case final result?)
                  FinaiPanel(child: AnalysisResultView(result: result)),
                if (turn.error case final error?)
                  FinaiNotice(error, error: true),
                const SizedBox(height: 12),
              ],
              if (pending != null) ...[
                Text(pending),
                const LinearProgressIndicator(),
                const Text('Đang phân tích trên máy chủ…'),
              ],
            ],
          ),
        ),
        if (dataset != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _query,
                    enabled: canSend,
                    maxLength: 1000,
                    minLines: 1,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      hintText: 'Nhập câu hỏi về dữ liệu',
                      counterText: '',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  tooltip: 'Phân tích ngay',
                  icon: const Icon(Icons.send),
                  onPressed: canSend ? () => _ask(dataset) : null,
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class AnalysisSuggestions extends ConsumerWidget {
  const AnalysisSuggestions({
    super.key,
    required this.dataset,
    required this.onChoose,
  });
  final Dataset dataset;
  final ValueChanged<String>? onChoose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recommendations = ref.watch(recommendationsProvider(dataset.id));
    return ExpansionTile(
      title: const Text('Câu hỏi và thuật toán gợi ý'),
      children: [
        ListTile(
          title: const Text('Kiểm tra dữ liệu thiếu'),
          onTap: onChoose == null
              ? null
              : () => onChoose!(
                  'Hiển thị 5 dòng đầu và chỉ ra các giá trị còn thiếu.',
                ),
        ),
        recommendations.when(
          loading: () => const LinearProgressIndicator(),
          error: (_, _) => TextButton(
            onPressed: () =>
                ref.invalidate(recommendationsProvider(dataset.id)),
            child: const Text('Tải lại gợi ý'),
          ),
          data: (data) => Column(
            children: [
              for (final item
                  in (data['recommendations'] as List? ?? const [])
                      .whereType<Map>())
                ListTile(
                  title: Text('${item['algorithm_name']}'),
                  subtitle: Text('${item['reason'] ?? ''}'),
                  onTap: onChoose == null
                      ? null
                      : () {
                          final features =
                              (item['suggested_features'] as List?)?.join(
                                ', ',
                              ) ??
                              '';
                          final target = item['suggested_target'];
                          final date = item['suggested_date'];
                          final horizon = item['suggested_horizon'];
                          onChoose!(
                            'Hãy dùng ${item['algorithm_name']} để phân tích dữ liệu.'
                            '${target == null ? '' : ' Chỉ tiêu: $target.'}'
                            '${date == null ? '' : ' Cột thời gian: $date.'}'
                            '${features.isEmpty ? '' : ' Đặc trưng: $features.'}'
                            '${horizon == null ? '' : ' Số kỳ hoặc cụm theo gợi ý: $horizon.'}',
                          );
                        },
                ),
              TextButton(
                onPressed: () =>
                    context.go('/forecast/${Uri.encodeComponent(dataset.id)}'),
                child: const Text('Mở công cụ chạy mô hình'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class AnalysisMarkdown extends StatelessWidget {
  const AnalysisMarkdown(this.source, {super.key});
  final String source;

  @override
  Widget build(BuildContext context) {
    final lines = safeTechnicalText(source).split('\n');
    final children = <Widget>[];
    var code = false;
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (line.trimLeft().startsWith('```')) {
        code = !code;
        continue;
      }
      if (!code &&
          line.trim().startsWith('|') &&
          i + 1 < lines.length &&
          RegExp(r'^\s*\|[ :|\-]+\|\s*$').hasMatch(lines[i + 1])) {
        List<String> cells(String text) {
          final row = text.trim();
          final body = row.endsWith('|') && row.length > 1
              ? row.substring(1, row.length - 1)
              : row.substring(1);
          return body.split('|').map((cell) => cell.trim()).toList();
        }

        final headers = cells(line);
        if (headers.isNotEmpty) {
          final rows = <DataRow>[];
          i += 2;
          while (i < lines.length && lines[i].trim().startsWith('|')) {
            final values = cells(lines[i++]);
            rows.add(
              DataRow(
                cells: List.generate(
                  headers.length,
                  (j) => DataCell(Text(j < values.length ? values[j] : '')),
                ),
              ),
            );
          }
          i--;
          children.add(
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: headers
                    .map((h) => DataColumn(label: Text(h)))
                    .toList(),
                rows: rows,
              ),
            ),
          );
          continue;
        }
      }
      final heading = !code && RegExp(r'^#{1,6}\s').hasMatch(line);
      children.add(
        SelectableText(
          code
              ? line
              : line
                    .replaceFirst(RegExp(r'^#{1,6}\s+'), '')
                    .replaceFirst(RegExp(r'^\s*[-*]\s+'), '• ')
                    .replaceAll('**', ''),
          style: heading
              ? Theme.of(context).textTheme.titleMedium
              : code
              ? const TextStyle(fontFamily: 'monospace')
              : null,
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }
}

class AnalysisExportButton extends ConsumerStatefulWidget {
  const AnalysisExportButton({super.key, required this.filename});
  final String filename;
  @override
  ConsumerState<AnalysisExportButton> createState() =>
      _AnalysisExportButtonState();
}

class _AnalysisExportButtonState extends ConsumerState<AnalysisExportButton> {
  bool _busy = false;
  Future<void> _save() async {
    setState(() => _busy = true);
    final api = ref.read(apiClientProvider);
    final generation = api.generation;
    try {
      final bytes = await ref
          .read(datasetRepositoryProvider)
          .exportFile(widget.filename);
      if (!mounted || api.generation != generation) return;
      await FilePicker.platform.saveFile(
        fileName: widget.filename,
        bytes: bytes,
      );
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e is ApiFailure ? e.message : 'Không lưu được tệp xuất.',
            ),
          ),
        );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => TextButton.icon(
    onPressed: _busy ? null : _save,
    icon: const Icon(Icons.download),
    label: Text(_busy ? 'Đang tải…' : 'Tải ${widget.filename}'),
  );
}

class AnalysisResultView extends ConsumerWidget {
  const AnalysisResultView({super.key, required this.result});
  final AnalysisResult result;
  @override
  Widget build(BuildContext context, WidgetRef ref) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const FinaiHeading(
        title: 'Kết quả phân tích',
        subtitle: 'Số liệu và biểu đồ từ yêu cầu của bạn.',
        icon: Icons.insights_rounded,
      ),
      const SizedBox(height: 8),
      Text('Câu hỏi: ${result.question}'),
      const SizedBox(height: 12),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          Chip(
            avatar: Icon(
              result.successful
                  ? Icons.check_circle_outline
                  : Icons.info_outline,
              size: 18,
            ),
            backgroundColor:
                (result.successful
                        ? Theme.of(context).colorScheme.secondary
                        : Theme.of(context).colorScheme.error)
                    .withValues(alpha: .1),
            label: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 215),
              child: Text(result.executionLabel),
            ),
          ),
          Chip(
            label: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 240),
              child: Text(result.securityLabel),
            ),
          ),
        ],
      ),
      if (result.timeMs != null)
        Text(
          'Thời gian thực thi trên máy chủ: ${result.timeMs!.toStringAsFixed(1)} ms',
        ),
      const SizedBox(height: 12),
      const FinaiNotice(
        'Trạng thái thực thi không chứng minh số liệu đúng nghiệp vụ. Đối chiếu kỳ, đơn vị và dữ liệu nguồn.',
      ),
      if (!result.successful)
        const Padding(
          padding: EdgeInsets.only(top: 12),
          child: Text(
            'Phân tích chưa hoàn tất hoặc có trạng thái cần kiểm tra. Xem chi tiết kỹ thuật bên dưới.',
            style: TextStyle(color: Colors.deepOrange),
          ),
        ),
      const SizedBox(height: 16),
      if (result.validation.isNotEmpty)
        Text('Kiểm tra từ máy chủ: ${result.validation}'),
      if (result.scope.isNotEmpty) Text('Cột: ${result.scope.join(', ')}'),
      FinaiSection(
        title: 'Số liệu & diễn giải',
        child: AnalysisMarkdown(
          result.summary.isNotEmpty
              ? result.summary
              : result.stdout.isNotEmpty
              ? result.stdout
              : 'Máy chủ chưa trả kết quả số liệu.',
        ),
      ),
      if (result.stdout.isNotEmpty && result.stdout != result.summary)
        ExpansionTile(
          title: const Text('Kết quả thực thi'),
          children: [FinaiMono(safeTechnicalText(result.stdout))],
        ),
      if (result.steps.isNotEmpty)
        ExpansionTile(
          title: Text('Các bước Agent (${result.steps.length})'),
          children: [
            for (final step in result.steps)
              ListTile(
                title: Text(safeTechnicalText('${step['tool'] ?? 'Agent'}')),
                subtitle: Text(
                  safeTechnicalText('${step['output_preview'] ?? ''}'),
                ),
              ),
          ],
        ),
      if (result.exportName case final name?)
        AnalysisExportButton(filename: name),
      if (result.chart != null) ...[
        const SizedBox(height: 16),
        ResultChart(key: ValueKey(result.chart), result: result),
      ],
      ExpansionTile(
        tilePadding: EdgeInsets.zero,
        title: const Text('Mã Python và chi tiết kỹ thuật'),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: result.code.isEmpty
                  ? null
                  : () async {
                      await Clipboard.setData(
                        ClipboardData(
                          text: safeTechnicalText(
                            result.code,
                            maxLength: 120000,
                          ),
                        ),
                      );
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Đã sao chép mã Python'),
                          ),
                        );
                      }
                    },
              icon: const Icon(Icons.copy),
              label: const Text('Sao chép mã Python'),
            ),
          ),
          if (result.error.isNotEmpty)
            SelectableText(
              safeTechnicalText(result.error, maxLength: 8000),
              style: const TextStyle(color: Colors.red),
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: FinaiMono(
              result.code.isEmpty
                  ? 'Không có mã Python.'
                  : safeTechnicalText(result.code, maxLength: 120000),
              technical: true,
            ),
          ),
        ],
      ),
    ],
  );
}

class ResultChart extends ConsumerStatefulWidget {
  const ResultChart({super.key, required this.result});
  final AnalysisResult result;
  @override
  ConsumerState<ResultChart> createState() => _ResultChartState();
}

class _ResultChartState extends ConsumerState<ResultChart> {
  late final Future<Uint8List> _image = _load();
  Future<Uint8List> _load() async {
    final inline = widget.result.inlineChart();
    if (inline != null) return inline;
    return ref.read(datasetRepositoryProvider).chart(widget.result.chart!);
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Uint8List>(
    future: _image,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return const Text(
          'Không hiển thị được ảnh biểu đồ: dữ liệu ảnh không hợp lệ hoặc không được phép truy cập.',
        );
      }
      if (!snapshot.hasData) {
        return const Center(child: CircularProgressIndicator());
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const FinaiHeading(
            title: 'Biểu đồ',
            subtitle: 'Biểu đồ do máy chủ trả về • chụm hai ngón để phóng to',
            icon: Icons.bar_chart_rounded,
          ),
          TextButton.icon(
            icon: const Icon(Icons.open_in_full_rounded, size: 18),
            label: const Text('Mở toàn màn hình'),
            onPressed: () async {
              await showDialog<void>(
                context: context,
                builder: (dialogContext) => Dialog.fullscreen(
                  child: Scaffold(
                    appBar: AppBar(
                      title: const Text('Biểu đồ'),
                      leading: IconButton(
                        tooltip: 'Đóng biểu đồ',
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.of(dialogContext).pop(),
                      ),
                    ),
                    body: SafeArea(
                      child: ColoredBox(
                        color: Colors.white,
                        child: SizedBox.expand(
                          child: InteractiveViewer(
                            minScale: .5,
                            maxScale: 8,
                            child: Center(
                              child: Image.memory(
                                snapshot.data!,
                                fit: BoxFit.contain,
                                errorBuilder: (_, _, _) => const Text(
                                  'Nội dung trả về không phải ảnh hợp lệ.',
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          Container(
            height: 320,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 5,
              child: Center(
                child: Image.memory(
                  snapshot.data!,
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) =>
                      const Text('Nội dung trả về không phải ảnh hợp lệ.'),
                ),
              ),
            ),
          ),
        ],
      );
    },
  );
}
