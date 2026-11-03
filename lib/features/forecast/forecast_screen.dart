import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/session.dart';
import '../../core/network/api_client.dart';
import '../../shared/widgets/finai_design.dart';
import '../analysis/analysis_result.dart';
import '../analysis/analysis_screen.dart';
import '../datasets/dataset.dart';
import '../datasets/dataset_repository.dart';
import '../datasets/dataset_screens.dart';
import 'forecast.dart';
import 'forecast_repository.dart';

class ForecastPickerScreen extends ConsumerWidget {
  const ForecastPickerScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => ref.watch(datasetsProvider).when(
    loading: () => const Center(child: CircularProgressIndicator()),
    error: (error, _) => LoadFailure(error: error,
        retry: () => ref.invalidate(datasetsProvider)),
    data: (page) => ListView(padding: const EdgeInsets.all(20), children: [
      const FinaiHeading(title: 'Khám phá xu hướng', subtitle: 'Chọn dữ liệu để nhìn về những kỳ tiếp theo.', icon: Icons.insights_rounded),
      const Text('Chọn bảng có mỗi dòng là một kỳ, cột thời gian và cột giá trị số. '
          'Dữ liệu SEC nhiều chỉ tiêu cần được chuẩn bị ở backend trước.'),
      if (page.items.isEmpty) const Text('Chưa có dataset. Hãy tải dữ liệu lên Kho dữ liệu.'),
      const SizedBox(height: 16),
      ...page.items.map((dataset) => FinaiDatasetTile(dataset: dataset, enabled: !dataset.fileBlocked,
        onTap: () => context.go('/forecast/${Uri.encodeComponent(dataset.id)}'))),
      if (page.count > page.items.length) TextButton(
        onPressed: () => context.go('/datasets'),
        child: const Text('Xem thêm dataset trong Kho dữ liệu'),
      ),
    ]),
  );
}

class ForecastScreen extends ConsumerStatefulWidget {
  const ForecastScreen({super.key, required this.id});
  final String id;
  @override
  ConsumerState<ForecastScreen> createState() => _ForecastScreenState();
}

class _ForecastScreenState extends ConsumerState<ForecastScreen> {
  String? _target, _date, _error;
  String _model = 'linear_regression';
  int _horizon = 3, _revision = 0;
  bool _busy = false, _storageBlocked = false;
  ForecastResult? _result;

  @override
  void didUpdateWidget(covariant ForecastScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.id != widget.id) {
      _revision++;
      _target = _date = _error = null;
      _result = null;
      _busy = _storageBlocked = false;
    }
  }

  @override
  void dispose() {
    _revision++;
    super.dispose();
  }

  Future<void> _predict(Dataset dataset) async {
    if (_busy || _target == null || _date == null) return;
    final user = ref.read(sessionProvider);
    final generation = ref.read(apiClientProvider).generation;
    final stamp = ++_revision;
    bool current() => mounted && stamp == _revision &&
        ref.read(sessionProvider) == user &&
        ref.read(apiClientProvider).generation == generation;
    setState(() { _busy = true; _error = null; _result = null; });
    try {
      final result = await ref.read(forecastRepositoryProvider).predict(dataset,
          target: _target!, date: _date!, horizon: _horizon, model: _model);
      if (current()) {
        setState(() => _result = result);
      }
    } on ApiFailure catch (error) {
      if (current()) {
        setState(() {
          _error = error.message;
          if (['DATASET_001', 'DATASET_003', 'DATASET_006', 'DATASET_008'].contains(error.code)) {
            _storageBlocked = true;
          }
        });
      }
    } catch (_) {
      if (current()) {
        setState(() => _error = 'Chưa đọc được kết quả dự báo. Kiểm tra backend.');
      }
    } finally {
      if (current()) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => ref.watch(datasetDetailProvider(widget.id)).when(
    loading: () => const Center(child: CircularProgressIndicator()),
    error: (error, _) => LoadFailure(error: error,
        retry: () => ref.invalidate(datasetDetailProvider(widget.id))),
    data: (dataset) {
      final names = dataset.columns.map((c) => c['name'] as String).toSet().toList();
      final numeric = dataset.numericColumns.toSet().toList();
      final target = numeric.contains(_target) ? _target : null;
      final date = names.contains(_date) ? _date : null;
      final enabled = !_busy && !_storageBlocked && !dataset.fileBlocked;
      return ListView(padding: const EdgeInsets.all(20), children: [
        FinaiHeading(title: 'Dự báo chỉ tiêu', subtitle: dataset.filename, icon: Icons.insights_rounded),
        FinaiNotice(dataset.storageMessage, warning: dataset.fileBlocked),
        if (dataset.needsReview) const Text('Cần kiểm tra cấu trúc dữ liệu trước khi dự báo.'),
        TextButton(onPressed: _busy ? null : () {
          setState(() { _storageBlocked = false; _result = null; });
          ref.invalidate(datasetDetailProvider(widget.id));
        }, child: const Text('Tải lại trạng thái dataset')),
        if (numeric.isEmpty) const Text('Chưa nhận diện được cột số. Kiểm tra schema và kiểu dữ liệu.'),
        FinaiSection(title: 'Chọn dữ liệu dự báo', step: '1',
          subtitle: 'Một cột giá trị số và một cột thời gian.',
          child: Column(children: [
        DropdownButtonFormField<String>(
          key: ValueKey('target-${widget.id}-$target'), initialValue: target,
          isExpanded: true, decoration: const InputDecoration(labelText: 'Cột chỉ tiêu số'),
          items: numeric.map((name) => DropdownMenuItem(value: name,
              child: Text(name, overflow: TextOverflow.ellipsis))).toList(),
          onChanged: enabled ? (value) => setState(() { _target = value; _result = null; }) : null,
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          key: ValueKey('date-${widget.id}-$date'), initialValue: date,
          isExpanded: true, decoration: const InputDecoration(labelText: 'Cột thời gian'),
          items: names.map((name) => DropdownMenuItem(value: name,
              child: Text(name, overflow: TextOverflow.ellipsis))).toList(),
          onChanged: enabled ? (value) => setState(() { _date = value; _result = null; }) : null,
        ),
        const SizedBox(height: 12),
        ])),
        FinaiSection(title: 'Thiết lập dự báo', step: '2',
          subtitle: 'Chọn số kỳ và mô hình phù hợp với dữ liệu.',
          child: Column(children: [
        DropdownButtonFormField<int>(initialValue: _horizon,
          decoration: const InputDecoration(labelText: 'Số kỳ dự báo (1–12)'),
          items: List.generate(12, (i) => DropdownMenuItem(value: i + 1, child: Text('${i + 1}'))),
          onChanged: enabled ? (value) => setState(() { _horizon = value!; _result = null; }) : null,
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(initialValue: _model, isExpanded: true,
          decoration: const InputDecoration(labelText: 'Mô hình trên máy chủ'),
          items: const [
            DropdownMenuItem(value: 'linear_regression', child: Text('Hồi quy tuyến tính')),
            DropdownMenuItem(value: 'polynomial_trend', child: Text('Xu hướng đa thức')),
            DropdownMenuItem(value: 'exponential_smoothing', child: Text('San bằng mũ')),
          ],
          onChanged: enabled ? (value) => setState(() { _model = value!; _result = null; }) : null,
        ),
        ])),
        const FinaiNotice('Hãy dùng dữ liệu theo tháng đã được kiểm tra. Máy chủ chưa tự xử lý đúng '
            'mọi bảng nhiều chỉ tiêu hoặc nhiều kỳ chồng lấn.', warning: true),
        if (_error != null) Padding(padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(_error!, style: const TextStyle(color: Colors.deepOrange))),
        FilledButton(onPressed: enabled && target != null && date != null && target != date
            ? () => _predict(dataset) : null,
            child: Text(_busy ? 'Đang dự báo trên máy chủ…' : 'Dự báo')),
        if (_busy) const Padding(padding: EdgeInsets.all(12), child: LinearProgressIndicator()),
        if (_result != null) ForecastResultView(result: _result!),
      ]);
    },
  );
}

class ForecastResultView extends StatelessWidget {
  const ForecastResultView({super.key, required this.result});
  final ForecastResult result;
  static String number(double? value) => value == null ? 'Không xác định' : value.toStringAsFixed(2);
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const SizedBox(height: 20),
      FinaiHeading(title: 'Kết quả: ${result.target}', subtitle: 'Dự báo và đánh giá từ máy chủ.', icon: Icons.query_stats_rounded),
      Text('Dataset: ${result.datasetName} • Mô hình: ${result.model}'),
      const Text('MAE/RMSE/MAPE/R² được tính trên dữ liệu huấn luyện (actual/fitted), '
          'chưa đánh giá trên tập kiểm tra theo thời gian. Đây không phải cam kết độ chính xác tương lai.'),
      const SizedBox(height: 16),
      LayoutBuilder(builder: (context, constraints) => Wrap(spacing: 12, runSpacing: 12,
        children: result.metrics.entries.map((entry) => SizedBox(
          width: constraints.maxWidth < 320 ? constraints.maxWidth : (constraints.maxWidth - 12) / 2,
          child: FinaiPanel(padding: const EdgeInsets.all(16), child: Text('${entry.key.toUpperCase()}: '
              '${number(entry.value)}${entry.key == 'mape' && entry.value != null ? '%' : ''}',
              style: Theme.of(context).textTheme.titleSmall)),
        )).toList())),
      const SizedBox(height: 16),
      if (result.containsZeroActual) const Text('Có actual bằng 0. Backend bỏ các điểm 0 khi tính MAPE; '
          'trường hợp tất cả actual bằng 0 có thể trả 0%. Không xem đây là dự báo hoàn hảo.'),
      if (result.timeMs != null) Text('Thời gian máy chủ: ${number(result.timeMs)} ms'),
      const Text('Khoảng dưới/trên là ước lượng từ backend, chưa được kiểm định độ bao phủ 95%.'),
      const SizedBox(height: 12),
      const FinaiHeading(title: 'Các kỳ tiếp theo', subtitle: 'Các kỳ tương lai • đơn vị theo cột dữ liệu gốc', icon: Icons.calendar_month_outlined),
      FinaiPanel(padding: const EdgeInsets.all(4), child: SingleChildScrollView(scrollDirection: Axis.horizontal, child: DataTable(columns: const [
        DataColumn(label: Text('Kỳ')), DataColumn(label: Text('Dự báo')),
        DataColumn(label: Text('Cận dưới')), DataColumn(label: Text('Cận trên')),
      ], rows: result.future.map((point) => DataRow(cells: [
        DataCell(Text(point.period)), DataCell(Text(number(point.value))),
        DataCell(Text(number(point.lower))), DataCell(Text(number(point.upper))),
      ])).toList()))),
      const SizedBox(height: 20),
      if (result.chart != null) ResultChart(
        key: ValueKey('${result.datasetId}-${result.chart}'),
        result: AnalysisResult(datasetId: result.datasetId, question: '', stdout: '', code: '',
            execution: 'unknown', security: 'unknown', error: '', chart: result.chart),
      ) else const Text('Máy chủ chưa trả ảnh biểu đồ.'),
      ExpansionTile(title: const Text('Dữ liệu lịch sử: actual và fitted'), children: [
        const Text('Fitted là giá trị khớp trên tập huấn luyện, không phải dự báo ngoài mẫu.'),
        FinaiMono(result.actual.map((point) => '${point.period}: '
            'actual=${number(point.value)}; fitted=${number(point.fitted)}').join('\n')),
      ]),
    ],
  );
}
