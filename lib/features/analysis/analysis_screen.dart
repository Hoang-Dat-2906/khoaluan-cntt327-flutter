import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kite_ui/kite_ui.dart';

import '../../core/auth/session.dart';
import '../../core/network/api_client.dart';
import '../datasets/dataset.dart';
import '../datasets/dataset_repository.dart';
import '../datasets/dataset_screens.dart';
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

class AnalysisScreen extends ConsumerStatefulWidget {
  const AnalysisScreen({super.key, required this.id});
  final String id;
  @override
  ConsumerState<AnalysisScreen> createState() => _AnalysisScreenState();
}

class _AnalysisScreenState extends ConsumerState<AnalysisScreen> {
  final _query = TextEditingController();
  Set<String>? _selected;
  AnalysisResult? _result;
  String? _error;
  bool _busy = false;
  int _request = 0;
  @override
  void didUpdateWidget(covariant AnalysisScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.id != widget.id) {
      _request++;
      _selected = null;
      _result = null;
      _error = null;
      _busy = false;
      _query.clear();
    }
  }

  @override
  void dispose() {
    _request++;
    _query.dispose();
    super.dispose();
  }

  Future<void> _analyze(Dataset dataset, List<String> columns) async {
    if (_busy) return;
    if (_query.text.trim().isEmpty || columns.isEmpty) {
      setState(() => _error = 'Hãy nhập câu hỏi và chọn ít nhất một cột.');
      return;
    }
    final user = ref.read(sessionProvider);
    final request = ++_request;
    setState(() {
      _busy = true;
      _result = null;
      _error = null;
    });
    try {
      final result = await ref
          .read(datasetRepositoryProvider)
          .analyze(dataset, _query.text, columns);
      if (mounted && request == _request && ref.read(sessionProvider) == user) {
        setState(() => _result = result);
      }
    } on ApiFailure catch (e) {
      if (mounted && request == _request && ref.read(sessionProvider) == user) {
        setState(() => _error = e.message);
      }
    } catch (_) {
      if (mounted && request == _request && ref.read(sessionProvider) == user) {
        setState(
          () => _error =
              'Không đọc được kết quả phân tích. Vui lòng kiểm tra backend.',
        );
      }
    } finally {
      if (mounted && request == _request) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => ref
      .watch(datasetDetailProvider(widget.id))
      .when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => LoadFailure(
          error: e,
          retry: () => ref.invalidate(datasetDetailProvider(widget.id)),
        ),
        data: (d) {
          final names = d.columns.map((c) => c['name'] as String).toSet();
          final selected = _selected ?? names;
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                'Phân tích dữ liệu',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(d.filename),
              if (d.needsReview)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    'Cần kiểm tra cấu trúc dữ liệu trước khi tin cậy kết quả phân tích.',
                    style: TextStyle(color: Colors.deepOrange),
                  ),
                ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Expanded(child: Text('Chọn cột')),
                  TextButton(
                    onPressed: _busy
                        ? null
                        : () => setState(
                            () => _selected = selected.length == names.length
                                ? {}
                                : {...names},
                          ),
                    child: Text(
                      selected.length == names.length
                          ? 'Bỏ chọn tất cả'
                          : 'Chọn tất cả',
                    ),
                  ),
                ],
              ),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: names
                    .map(
                      (name) => FilterChip(
                        label: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 250),
                          child: Text(name, overflow: TextOverflow.ellipsis),
                        ),
                        selected: selected.contains(name),
                        onSelected: _busy
                            ? null
                            : (value) => setState(() {
                                _selected = {...selected};
                                if (value) {
                                  _selected!.add(name);
                                } else {
                                  _selected!.remove(name);
                                }
                              }),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _query,
                enabled: !_busy,
                minLines: 3,
                maxLines: 6,
                decoration: const InputDecoration(
                  labelText: 'Câu hỏi tiếng Việt',
                  hintText: 'Bạn cần tìm hiểu gì từ dữ liệu?',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: _busy ? null : () => _query.text = 'Hiển thị 5 dòng đầu, mô tả các cột và chỉ rõ dữ liệu thiếu. Chỉ dùng dữ liệu trong file, không tạo số liệu thay thế.',
                child: const Text('Gợi ý: xem dữ liệu và các cột'),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              const SizedBox(height: 12),
              KiteButton(
                enabled: !_busy && d.status != 'error',
                onPressed: () => _analyze(d, selected.toList()),
                child: Text(
                  _busy ? 'Đang phân tích trên máy chủ…' : 'Phân tích ngay',
                ),
              ),
              if (_busy)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Column(
                    children: [
                      LinearProgressIndicator(),
                      SizedBox(height: 8),
                      Text(
                        'Có thể mất vài phút. Không gửi lại yêu cầu trong khi đang chờ.',
                      ),
                    ],
                  ),
                ),
              if (_result != null) ...[
                const SizedBox(height: 24),
                AnalysisResultView(result: _result!),
              ],
            ],
          );
        },
      );
}

class AnalysisResultView extends StatelessWidget {
  const AnalysisResultView({super.key, required this.result});
  final AnalysisResult result;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text('Kết quả phân tích', style: Theme.of(context).textTheme.titleLarge),
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
            label: Text(result.executionLabel),
          ),
          Chip(label: Text(result.securityLabel)),
        ],
      ),
      if (result.timeMs != null)
        Text(
          'Thời gian thực thi trên máy chủ: ${result.timeMs!.toStringAsFixed(1)} ms',
        ),
      const SizedBox(height: 12),
      const Text(
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
      SelectableText(
        result.stdout.isEmpty
            ? 'Máy chủ chưa trả kết quả số liệu.'
            : safeTechnicalText(result.stdout),
      ),
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
            child: SelectableText(
              result.code.isEmpty
                  ? 'Không có mã Python.'
                  : safeTechnicalText(result.code, maxLength: 120000),
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
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
          const Text('Biểu đồ do máy chủ trả về • chụm hai ngón để phóng to'),
          SizedBox(
            height: 300,
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
