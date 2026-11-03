import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kite_ui/kite_ui.dart';

import '../../core/auth/session.dart';
import '../../core/network/api_client.dart';
import '../../shared/widgets/finai_design.dart';
import 'dataset.dart';
import 'dataset_file_picker.dart';
import 'dataset_repository.dart';

class LoadFailure extends StatelessWidget {
  const LoadFailure({super.key, required this.error, required this.retry});
  final Object error;
  final VoidCallback retry;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.cloud_off_rounded, size: 48, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 12),
          Text(
            error is ApiFailure
                ? (error as ApiFailure).message
                : 'Không đọc được dữ liệu. Vui lòng thử lại.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          FilledButton(onPressed: retry, child: const Text('Thử lại')),
        ],
      ),
    ),
  );
}


class FinaiOverviewScreen extends ConsumerWidget {
  const FinaiOverviewScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(sessionProvider);
    final datasets = ref.watch(datasetsProvider);
    return ListView(padding: const EdgeInsets.fromLTRB(20, 12, 20, 32), children: [
      Text('Xin chào, ${user?.name ?? ""}', style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 16),
      FinaiHero(title: 'Hiểu dữ liệu.\nMở hướng đi mới.',
        subtitle: 'Từ bảng dữ liệu đến góc nhìn hữu ích. Bắt đầu bằng một câu hỏi của bạn.',
        action: FilledButton(style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: FinaiColors.blue),
          onPressed: () => context.go('/datasets'), child: const Text('Mở kho dữ liệu'))),
      const SizedBox(height: 24),
      Text('Không gian dữ liệu', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 12),
      datasets.when(
        loading: () => const FinaiPanel(child: LinearProgressIndicator()),
        error: (e, _) => LoadFailure(error: e, retry: () => ref.invalidate(datasetsProvider)),
        data: (page) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          FinaiPanel(child: Row(children: [
            Container(padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: Theme.of(context).colorScheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(18)),
              child: Icon(Icons.folder_copy_outlined, color: Theme.of(context).colorScheme.onSecondaryContainer)),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${page.count} tệp được phép truy cập', style: Theme.of(context).textTheme.titleMedium),
              Text('Sẵn trong không gian tài khoản', style: TextStyle(color: FinaiColors.muted(context))),
            ])),
          ])),
          if (page.items.isNotEmpty) ...[
            const SizedBox(height: 24),
            Text('Khám phá tệp của bạn', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            ...page.items.take(2).map((d) => FinaiDatasetTile(dataset: d,
              onTap: () => context.go('/datasets/${Uri.encodeComponent(d.id)}'))),
          ] else const FinaiNotice('Kho dữ liệu còn trống. Tải một tệp CSV hoặc Excel để bắt đầu.'),
        ]),
      ),
      const SizedBox(height: 24),
      Text('Bạn muốn làm gì hôm nay?', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 12),
      _OverviewAction(title: 'Phân tích bằng câu hỏi', subtitle: 'Chọn tệp và hỏi bằng tiếng Việt.',
        icon: Icons.auto_awesome_rounded, color: FinaiColors.blue, onTap: () => context.go('/datasets')),
      _OverviewAction(title: 'Khám phá xu hướng', subtitle: 'Dự báo từ chuỗi dữ liệu theo thời gian.',
        icon: Icons.insights_rounded, color: FinaiColors.violet, onTap: () => context.go('/forecast')),
      const FinaiNotice('Kết quả là công cụ hỗ trợ. Hãy đối chiếu dữ liệu gốc và cách tổng hợp trước khi ra quyết định.'),
    ]);
  }
}

class _OverviewAction extends StatelessWidget {
  const _OverviewAction({required this.title, required this.subtitle, required this.icon, required this.color, required this.onTap});
  final String title, subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(bottom: 12),
    child: Material(color: FinaiColors.surface(context), borderRadius: BorderRadius.circular(22),
      child: InkWell(borderRadius: BorderRadius.circular(22), onTap: onTap,
        child: Padding(padding: const EdgeInsets.all(18), child: Row(children: [
          Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: color.withValues(alpha: .12),
            borderRadius: BorderRadius.circular(15)), child: Icon(icon, color: FinaiColors.dark(context)
                ? Theme.of(context).colorScheme.primary : color)),
          const SizedBox(width: 14), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: Theme.of(context).textTheme.titleSmall), const SizedBox(height: 4),
            Text(subtitle, style: TextStyle(color: FinaiColors.muted(context))),
          ])), const SizedBox(width: 8), const Icon(Icons.chevron_right_rounded, size: 20),
        ]))),
    ));
}

class FinaiDatasetTile extends StatelessWidget {
  const FinaiDatasetTile({super.key, required this.dataset, required this.onTap, this.enabled = true});
  final Dataset dataset;
  final VoidCallback onTap;
  final bool enabled;
  @override
  Widget build(BuildContext context) {
    final d = dataset;
    final color = Theme.of(context).colorScheme.secondary;
    return Padding(padding: const EdgeInsets.only(bottom: 12),
      child: Material(color: FinaiColors.surface(context), borderRadius: BorderRadius.circular(22),
        child: InkWell(onTap: enabled ? onTap : null, borderRadius: BorderRadius.circular(22),
          child: Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: color.withValues(alpha: .1), borderRadius: BorderRadius.circular(15)),
                child: Icon(Icons.table_chart_outlined, color: color)),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(d.filename, style: Theme.of(context).textTheme.titleSmall), const SizedBox(height: 5),
                Text('${d.type.toUpperCase()} • v${d.version} • ${d.sizeBytes} byte',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: FinaiColors.muted(context))),
              ])), const SizedBox(width: 6), const Icon(Icons.chevron_right_rounded, size: 20),
            ]),
            const SizedBox(height: 14),
            Wrap(spacing: 8, runSpacing: 6, children: [
              Text('${d.rows} dòng', style: Theme.of(context).textTheme.labelMedium),
              Text('• ${d.columnsCount} cột', style: Theme.of(context).textTheme.labelMedium),
              Text('• ${d.status}', style: Theme.of(context).textTheme.labelMedium),
            ]),
            const SizedBox(height: 8),
            Text(d.storageMessage, style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: d.fileBlocked ? Theme.of(context).colorScheme.error : FinaiColors.muted(context))),
          ]))),
      ));
  }
}

class DatasetListScreen extends ConsumerStatefulWidget {
  const DatasetListScreen({super.key});
  @override
  ConsumerState<DatasetListScreen> createState() => _DatasetListScreenState();
}

class _DatasetListScreenState extends ConsumerState<DatasetListScreen> {
  bool _uploading = false, _moreBusy = false;
  String? _error;
  final List<Dataset> _more = [];
  Future<void> _upload() async {
    if (_uploading) return;
    final user = ref.read(sessionProvider);
    final repo = ref.read(datasetRepositoryProvider);
    setState(() {
      _uploading = true;
      _error = null;
    });
    try {
      final file = await ref.read(datasetFilePickerProvider).pick();
      if (file == null || !mounted || ref.read(sessionProvider) != user) return;
      final dataset = await repo.upload(file.name, file.bytes);
      if (!mounted || ref.read(sessionProvider) != user) return;
      ref.invalidate(datasetsProvider);
      _more.clear();
      context.go('/datasets/${Uri.encodeComponent(dataset.id)}');
    } on ApiFailure catch (e) {
      if (mounted && ref.read(sessionProvider) == user) {
        setState(() => _error = e.message);
      }
    } catch (_) {
      if (mounted && ref.read(sessionProvider) == user) {
        setState(
          () => _error =
              'Không tải được tệp. Kiểm tra quyền đọc và kết nối mạng.',
        );
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _next(int skip) async {
    final user = ref.read(sessionProvider);
    setState(() {
      _moreBusy = true;
      _error = null;
    });
    try {
      final page = await ref.read(datasetRepositoryProvider).list(skip: skip);
      if (mounted && ref.read(sessionProvider) == user) {
        setState(() {
          final ids = _more.map((e) => e.id).toSet();
          _more.addAll(page.items.where((e) => !ids.contains(e.id)));
        });
      }
    } on ApiFailure catch (e) {
      if (mounted && ref.read(sessionProvider) == user) {
        setState(() => _error = e.message);
      }
    } catch (_) {
      if (mounted && ref.read(sessionProvider) == user) {
        setState(() => _error = 'Chưa tải được trang tiếp theo.');
      }
    } finally {
      if (mounted) setState(() => _moreBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final page = ref.watch(datasetsProvider);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const FinaiHeading(title: 'Kho dữ liệu', subtitle: 'Tất cả tệp của bạn, trong một không gian.', icon: Icons.folder_copy_outlined),
              FilledButton.icon(
                onPressed: _uploading ? null : _upload,
                icon: const Icon(Icons.cloud_upload_outlined),
                label: Text(_uploading ? 'Đang tải tệp…' : 'Tải CSV / Excel lên kho'),
              ),
              const SizedBox(height: 6),
              Text('CSV, XLSX hoặc XLS • Tối đa 15 MB', textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: FinaiColors.muted(context))),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: page.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => LoadFailure(
              error: e,
              retry: () => ref.invalidate(datasetsProvider),
            ),
            data: (data) {
              final all = {
                ...{for (final d in data.items) d.id: d},
                ...{for (final d in _more) d.id: d},
              }.values.toList();
              return RefreshIndicator(
                onRefresh: () async {
                  setState(_more.clear);
                  ref.invalidate(datasetsProvider);
                  await ref.read(datasetsProvider.future);
                },
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    Text('${data.count} tệp • đang hiển thị ${all.length}',
                        style: TextStyle(color: FinaiColors.muted(context))),
                    const SizedBox(height: 12),
                    if (all.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'Chưa có dữ liệu. Hãy tải tệp mới lên kho.',
                        ),
                      ),
                    ...all.map((d) => FinaiDatasetTile(dataset: d,
                      onTap: () => context.go('/datasets/${Uri.encodeComponent(d.id)}'))),
                    if (all.length < data.count)
                      TextButton(
                        onPressed: _moreBusy ? null : () => _next(all.length),
                        child: Text(_moreBusy ? 'Đang tải…' : 'Tải thêm'),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class DatasetDetailScreen extends ConsumerWidget {
  const DatasetDetailScreen({super.key, required this.id});
  final String id;
  @override
  Widget build(BuildContext context, WidgetRef ref) => ref
      .watch(datasetDetailProvider(id))
      .when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => LoadFailure(
          error: e,
          retry: () => ref.invalidate(datasetDetailProvider(id)),
        ),
        data: (d) => ListView(
          padding: const EdgeInsets.all(20),
          children: [
            FinaiHeading(title: d.filename, subtitle: '${d.type.toUpperCase()} • Phiên bản ${d.version}', icon: Icons.table_chart_outlined),
            FinaiMetrics(values: {'Số dòng': '${d.rows}', 'Số cột': '${d.columnsCount}',
              'Dung lượng': '${d.sizeBytes} byte', 'Trạng thái': d.status}),
            const SizedBox(height: 12),
            FinaiNotice(d.storageMessage, warning: d.fileBlocked),
            TextButton(
              onPressed: () => ref.invalidate(datasetDetailProvider(id)),
              child: const Text('Kiểm tra lại dataset'),
            ),
            const Text(
              'Thông tin schema/quality bên dưới được lưu tại lúc upload hoặc làm sạch; không phải kiểm chứng lại nội dung tệp.',
            ),
            if (d.needsReview)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'Cần kiểm tra cấu trúc dữ liệu. ${d.schemaWarning ?? "Có cột chưa được nhận diện hoặc schema có lỗi."}',
                  style: const TextStyle(color: Colors.deepOrange),
                ),
              ),
            const SizedBox(height: 12),
            KiteButton(
              enabled: !d.fileBlocked && d.columns.isNotEmpty,
              onPressed: () =>
                  context.go('/analysis/${Uri.encodeComponent(d.id)}'),
              child: const Flexible(
                child: Padding(padding: EdgeInsets.symmetric(vertical: 4),
                  child: Text('Đặt câu hỏi phân tích', textAlign: TextAlign.center)),
              ),
            ),
            TextButton.icon(
              onPressed: d.fileBlocked ? null : () =>
                  context.go('/forecast/${Uri.encodeComponent(d.id)}'),
              icon: const Icon(Icons.trending_up),
              label: const Text('Dự báo chỉ tiêu'),
            ),
            const SizedBox(height: 20),
            Text('Các cột', style: Theme.of(context).textTheme.titleLarge),
            ...d.columns.map(
              (c) => Padding(
                padding: const EdgeInsets.only(top: 12),
                child: FinaiPanel(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${c['name']}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text('Kiểu: ${c['dtype'] ?? "Chưa xác định"}'),
                      Text(
                        'Thiếu: ${c['missing_count'] ?? "Chưa có thông tin"}',
                      ),
                      if (c['sample_values'] is List)
                        Text(
                          'Ví dụ: ${(c['sample_values'] as List).take(3).join("; ")}',
                        ),
                    ],
                  ),
                ),
              ),
            ),
            if (d.profile['recommendations'] is List) ...[
              const SizedBox(height: 12),
              const Text('Khuyến nghị từ backend'),
              ...(d.profile['recommendations'] as List).map(
                (r) => Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text('$r'),
                ),
              ),
            ],
          ],
        ),
      );
}
