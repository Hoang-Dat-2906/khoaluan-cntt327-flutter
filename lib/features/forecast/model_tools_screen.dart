import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/session.dart';
import '../../core/network/api_client.dart';
import '../../shared/widgets/data_fields.dart';
import '../../shared/widgets/finai_design.dart';
import '../analysis/analysis_result.dart';
import '../analysis/analysis_screen.dart';
import '../datasets/dataset.dart';
import 'forecast_repository.dart';

class ModelTools extends ConsumerWidget {
  const ModelTools({
    super.key,
    required this.dataset,
    required this.onForecast,
  });
  final Dataset dataset;
  final ValueChanged<Map>? onForecast;

  void _open(BuildContext context, bool classification, [Map? suggestion]) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _ModelScreen(
          dataset: dataset,
          classification: classification,
          suggestion: suggestion,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (dataset.fileBlocked) return const SizedBox.shrink();
    final suggestions = ref.watch(recommendationsProvider(dataset.id));
    return Column(
      children: [
        Wrap(
          spacing: 8,
          children: [
            OutlinedButton(
              onPressed: () => _open(context, false),
              child: const Text('Phân cụm'),
            ),
            OutlinedButton(
              onPressed: () => _open(context, true),
              child: const Text('Phân loại'),
            ),
          ],
        ),
        ExpansionTile(
          title: const Text('Gợi ý thuật toán'),
          children: [
            suggestions.when(
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => ListTile(
                title: Text(
                  e is ApiFailure ? e.message : 'Không tải được gợi ý.',
                ),
                trailing: IconButton(
                  tooltip: 'Tải lại',
                  icon: const Icon(Icons.refresh),
                  onPressed: () =>
                      ref.invalidate(recommendationsProvider(dataset.id)),
                ),
              ),
              data: (data) => Column(
                children: [
                  if (data['type_label'] != null) Text('${data['type_label']}'),
                  for (final item
                      in (data['recommendations'] as List? ?? const [])
                          .whereType<Map>())
                    ListTile(
                      title: Text('${item['algorithm_name']}'),
                      subtitle: Text('${item['reason'] ?? ''}'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: switch (item['task_type']) {
                        'time_series_forecast' =>
                          onForecast == null ? null : () => onForecast!(item),
                        'clustering' => () => _open(context, false, item),
                        'classification' => () => _open(context, true, item),
                        _ => null,
                      },
                    ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ModelScreen extends ConsumerStatefulWidget {
  const _ModelScreen({
    required this.dataset,
    required this.classification,
    this.suggestion,
  });
  final Dataset dataset;
  final bool classification;
  final Map? suggestion;
  @override
  ConsumerState<_ModelScreen> createState() => _ModelScreenState();
}

class _ModelScreenState extends ConsumerState<_ModelScreen> {
  String? _target, _idColumn, _error;
  final _features = <String>{};
  int _clusters = 3;
  double _testSize = .25;
  bool _busy = false;
  Map<String, dynamic>? _result;

  List<String> get _columns => widget.dataset.columns
      .map((c) => c['name'] as String)
      .where((name) => name.isNotEmpty)
      .toSet()
      .toList();
  List<String> get _available => widget.classification
      ? _columns
      : widget.dataset.numericColumns.toSet().toList();

  @override
  void initState() {
    super.initState();
    final suggestion = widget.suggestion;
    final target = suggestion?['suggested_target'];
    if (widget.classification && _columns.contains(target))
      _target = target as String;
    final features = suggestion?['suggested_features'];
    if (features is List)
      _features.addAll(
        features.whereType<String>().where(
          (name) => _available.contains(name) && name != _target,
        ),
      );
    final clusters = suggestion?['suggested_horizon'];
    if (!widget.classification && clusters is int)
      _clusters = clusters.clamp(2, 6);
  }

  Future<void> _run() async {
    if (_busy) return;
    final repo = ref.read(forecastRepositoryProvider);
    final generation = repo.api.generation;
    bool current() => mounted && repo.api.generation == generation;
    setState(() {
      _busy = true;
      _result = null;
      _error = null;
    });
    try {
      final features = _features.toList();
      final result = widget.classification
          ? await repo.classify(widget.dataset, _target!, features, _testSize)
          : await repo.cluster(widget.dataset, features, _clusters, _idColumn);
      if (current()) setState(() => _result = result);
    } catch (e) {
      if (current())
        setState(
          () => _error = e is ApiFailure
              ? e.message
              : 'Không đọc được kết quả mô hình.',
        );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(sessionProvider, (before, after) {
      if (before?.id != after?.id && ModalRoute.of(context)?.isCurrent == true)
        Navigator.pop(context);
    });
    final classification = widget.classification;
    final title = classification ? 'Phân loại' : 'Phân cụm';
    final result = _result;
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            FinaiHeading(
              title: title,
              subtitle: widget.dataset.filename,
              icon: Icons.analytics_outlined,
            ),
            DropdownButtonFormField<String>(
              initialValue: classification ? _target : _idColumn ?? '',
              isExpanded: true,
              decoration: InputDecoration(
                labelText: classification
                    ? 'Biến đích nhị phân'
                    : 'Cột định danh (tùy chọn)',
              ),
              items: [
                if (!classification)
                  const DropdownMenuItem(value: '', child: Text('Không chọn')),
                for (final name in _columns)
                  DropdownMenuItem(
                    value: name,
                    child: Text(name, overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: _busy
                  ? null
                  : (value) => setState(() {
                      if (classification) {
                        _target = value;
                        _features.remove(value);
                      } else {
                        _idColumn = value == '' ? null : value;
                        _features.remove(value);
                      }
                      _result = null;
                    }),
            ),
            const SizedBox(height: 12),
            FinaiSection(
              title: 'Chọn đặc trưng',
              child: Wrap(
                spacing: 8,
                children: [
                  for (final name in _available.where(
                    (name) => name != _target && name != _idColumn,
                  ))
                    FilterChip(
                      label: Text(name),
                      selected: _features.contains(name),
                      onSelected: _busy
                          ? null
                          : (checked) => setState(() {
                              if (checked) {
                                _features.add(name);
                              } else {
                                _features.remove(name);
                              }
                              _result = null;
                            }),
                    ),
                ],
              ),
            ),
            if (classification) ...[
              Text('Tập kiểm tra: ${(_testSize * 100).round()}%'),
              Slider(
                min: .15,
                max: .4,
                divisions: 5,
                value: _testSize,
                onChanged: _busy
                    ? null
                    : (value) => setState(() {
                        _testSize = value;
                        _result = null;
                      }),
              ),
            ] else
              DropdownButtonFormField<int>(
                initialValue: _clusters,
                decoration: const InputDecoration(labelText: 'Số cụm'),
                items: [
                  for (var i = 2; i <= 6; i++)
                    DropdownMenuItem(value: i, child: Text('$i')),
                ],
                onChanged: _busy
                    ? null
                    : (value) => setState(() {
                        _clusters = value!;
                        _result = null;
                      }),
              ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed:
                  _busy ||
                      (classification
                          ? _target == null || _features.isEmpty
                          : _features.length < 2)
                  ? null
                  : _run,
              child: Text('Chạy ${title.toLowerCase()}'),
            ),
            if (_busy) const LinearProgressIndicator(),
            if (_error != null) FinaiNotice(_error!, error: true),
            if (result != null) ...[
              if (result['summary'] case final String summary)
                AnalysisMarkdown(summary),
              FinaiSection(
                title: 'Kết quả',
                child: DataFields(
                  Map.of(result)
                    ..remove('chart_image')
                    ..remove('summary'),
                  labels: const {
                    'silhouette_score': 'Điểm Silhouette',
                    'quality_rating': 'Chất lượng phân cụm',
                    'cluster_stats': 'Đặc trưng từng cụm',
                    'sample_data': 'Dữ liệu mẫu',
                    'classes': 'Các lớp',
                    'metrics': 'Chỉ số đánh giá',
                    'confusion_matrix': 'Ma trận nhầm lẫn',
                    'odds_ratios': 'Tỷ số odds',
                  },
                ),
              ),
              if (result['chart_image'] case final String chart)
                ResultChart(
                  key: ValueKey(chart),
                  result: AnalysisResult(
                    datasetId: widget.dataset.id,
                    question: title,
                    stdout: '',
                    code: '',
                    execution: 'success',
                    security: 'unknown',
                    error: '',
                    chart: chart,
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
