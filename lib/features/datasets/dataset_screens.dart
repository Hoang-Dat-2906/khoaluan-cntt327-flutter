import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kite_ui/kite_ui.dart';

import '../../core/auth/session.dart';
import '../../core/network/api_client.dart';
import 'dataset.dart';
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
          const Icon(Icons.error_outline, size: 40),
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
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          'Xin chào, ${user?.name ?? ""}',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 12),
        const Text(
          'Chọn dữ liệu doanh nghiệp và đặt câu hỏi bằng tiếng Việt. Phân tích được thực hiện trên máy chủ.',
        ),
        const SizedBox(height: 20),
        KiteCard(
          title: 'Kho dữ liệu',
          child: datasets.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(12),
              child: LinearProgressIndicator(),
            ),
            error: (e, _) => LoadFailure(
              error: e,
              retry: () => ref.invalidate(datasetsProvider),
            ),
            data: (page) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${page.count} tệp được phép truy cập',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Số liệu lấy từ API thật. Chọn một tệp để xem schema và bắt đầu phân tích.',
                ),
                const SizedBox(height: 12),
                KiteButton(
                  onPressed: () => context.go('/datasets'),
                  child: const Text('Mở kho dữ liệu'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'Lưu ý: mã Python chạy thành công không đảm bảo số liệu đã đúng nghiệp vụ. Hãy đối chiếu dữ liệu gốc và cách tổng hợp.',
        ),
      ],
    );
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
      final picked = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv', 'xlsx', 'xls'],
        withData: false,
        withReadStream: true,
      );
      if (picked == null || !mounted || ref.read(sessionProvider) != user) {
        return;
      }
      final file = picked.files.single;
      if (file.size <= 0 || file.size > ApiClient.maxFileBytes) {
        throw const ApiFailure('Chọn file có dữ liệu, tối đa 15 MB.');
      }
      final stream = file.readStream;
      if (stream == null) {
        throw const ApiFailure('Không đọc được file đã chọn.');
      }
      // Enforce limit while reading, not only trusting the reported size.
      final chunks = <int>[];
      await for (final chunk in stream) {
        if (chunks.length + chunk.length > ApiClient.maxFileBytes) {
          throw const ApiFailure('File vượt 15 MB.');
        }
        chunks.addAll(chunk);
      }
      if (!mounted || ref.read(sessionProvider) != user) return;
      final dataset = await repo.upload(file.name, Uint8List.fromList(chunks));
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
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Chưa tải được trang tiếp theo.');
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
              Text(
                'Kho dữ liệu',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              KiteButton(
                enabled: !_uploading,
                onPressed: _upload,
                child: Text(
                  _uploading ? 'Đang tải tệp…' : 'Tải CSV / Excel lên kho',
                ),
              ),
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
                    Text('${data.count} tệp • đang hiển thị ${all.length}'),
                    if (all.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'Chưa có dữ liệu. Hãy tải tệp mới lên kho.',
                        ),
                      ),
                    ...all.map(
                      (d) => Card(
                        child: ListTile(
                          isThreeLine: true,
                          leading: const Icon(Icons.description_outlined),
                          title: Text(
                            d.filename,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            '${d.type.toUpperCase()} • v${d.version} • ${d.rows} dòng / ${d.columnsCount} cột\n${d.sizeBytes} byte • ${d.status}',
                          ),
                          onTap: () => context.go(
                            '/datasets/${Uri.encodeComponent(d.id)}',
                          ),
                        ),
                      ),
                    ),
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
            Text(d.filename, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              'Phiên bản ${d.version} • ${d.rows} dòng • ${d.columnsCount} cột\n${d.sizeBytes} byte • Trạng thái: ${d.status}',
            ),
            const SizedBox(height: 12),
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
              enabled: d.status != 'error' && d.columns.isNotEmpty,
              onPressed: () =>
                  context.go('/analysis/${Uri.encodeComponent(d.id)}'),
              child: const Text('Đặt câu hỏi phân tích'),
            ),
            const SizedBox(height: 20),
            Text('Các cột', style: Theme.of(context).textTheme.titleLarge),
            ...d.columns.map(
              (c) => Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
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
