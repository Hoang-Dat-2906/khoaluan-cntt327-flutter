import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/session.dart';
import '../../core/network/api_client.dart';
import '../../shared/widgets/data_fields.dart';
import '../../shared/widgets/finai_design.dart';
import 'dataset.dart';
import 'dataset_repository.dart';

class DatasetActions extends ConsumerStatefulWidget {
  const DatasetActions({super.key, required this.dataset});
  final Dataset dataset;
  @override
  ConsumerState<DatasetActions> createState() => _DatasetActionsState();
}

class _DatasetActionsState extends ConsumerState<DatasetActions> {
  bool _busy = false;
  String? _error;
  Future<void> _run(String action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final d = widget.dataset;
    final repo = ref.read(datasetRepositoryProvider);
    final generation = repo.api.generation;
    bool current() => mounted && repo.api.generation == generation;
    try {
      switch (action) {
        case 'download':
          final bytes = await repo.download(d.id);
          if (current())
            await FilePicker.platform.saveFile(
              fileName: d.filename,
              bytes: bytes,
            );
        case 'clean':
          if (!await confirmFinaiAction(
                context,
                title: 'Làm sạch dữ liệu',
                description:
                    'Máy chủ sẽ xử lý và cập nhật phiên bản của ${d.filename}.',
                action: 'Làm sạch',
              ) ||
              !current())
            return;
          await repo.clean(d.id);
          if (!current()) return;
          ref.invalidate(datasetsProvider);
          ref.invalidate(datasetDetailProvider(d.id));
        case 'delete':
          if (!await confirmFinaiAction(
                context,
                title: 'Xóa tập dữ liệu',
                description: 'Xóa ${d.filename} khỏi kho dùng chung với Web?',
                action: 'Xóa',
              ) ||
              !current())
            return;
          await repo.delete(d.id);
          if (!current()) return;
          ref.invalidate(datasetsProvider);
          context.go('/datasets');
        case 'quality':
        case 'schema':
          final isQuality = action == 'quality';
          final data = isQuality
              ? await repo.quality(d.id)
              : await repo.schema(d.id);
          if (!current()) return;
          final profile = data['quality_profile'];
          final report = isQuality && profile is Map ? profile : data;
          await _show(
            isQuality ? 'Chất lượng dữ liệu' : 'Phân tích cấu trúc',
            report,
          );
        case 'preview':
          final raw = await repo.api.jsonRequest(
            'datasets/${Uri.encodeComponent(d.id)}',
          );
          if (!current()) return;
          final encoded = raw['sample_data'];
          final sample = encoded is String ? jsonDecode(encoded) : encoded;
          await _show(
            'Xem trước',
            sample is Map ? sample : {'Dòng dữ liệu': sample},
          );
      }
    } catch (e) {
      if (current())
        setState(
          () => _error = e is ApiFailure
              ? e.message
              : 'Không hoàn tất được thao tác.',
        );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _show(String title, Map report) => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: DataFields(
            report,
            labels: const {
              'columns': 'Các cột',
              'health_score': 'Điểm chất lượng',
              'total_missing_cells': 'Ô thiếu',
              'duplicate_rows': 'Dòng trùng',
              'recommendations': 'Khuyến nghị',
            },
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Đóng'),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    ref.watch(sessionProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          children: [
            for (final (key, label, icon) in [
              ('preview', 'Xem trước', Icons.preview_outlined),
              ('quality', 'Chất lượng', Icons.fact_check_outlined),
              ('schema', 'Cấu trúc', Icons.schema_outlined),
              ('download', 'Tải xuống', Icons.download_outlined),
              ('clean', 'Làm sạch', Icons.cleaning_services_outlined),
              ('delete', 'Xóa', Icons.delete_outline),
            ])
              TextButton.icon(
                onPressed:
                    _busy ||
                        (widget.dataset.fileBlocked &&
                            ['download', 'schema', 'clean'].contains(key))
                    ? null
                    : () => _run(key),
                icon: Icon(icon),
                label: Text(label),
              ),
          ],
        ),
        if (_busy) const LinearProgressIndicator(),
        if (_error != null) FinaiNotice(_error!, error: true),
      ],
    );
  }
}
