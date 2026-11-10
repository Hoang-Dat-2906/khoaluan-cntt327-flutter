import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/session.dart';
import '../../core/network/api_client.dart';
import '../../shared/widgets/finai_design.dart';
import 'dataset_file_picker.dart';
import 'dataset_repository.dart';

class WorkbookImportScreen extends ConsumerStatefulWidget {
  const WorkbookImportScreen({super.key, required this.file});
  final SelectedDatasetFile file;
  @override
  ConsumerState<WorkbookImportScreen> createState() =>
      _WorkbookImportScreenState();
}

class _WorkbookImportScreenState extends ConsumerState<WorkbookImportScreen> {
  final _description = TextEditingController();
  final _selected = <String>{}, _saved = <String>{}, _mergeTables = <String>{};
  late final Future<Map<String, dynamic>> _inspection = ref
      .read(datasetRepositoryProvider)
      .inspect(widget.file.name, widget.file.bytes);
  bool _busy = false, _merge = false;
  String? _message;

  @override
  void dispose() {
    _description.dispose();
    super.dispose();
  }

  bool _valid(Map sheet) =>
      sheet['is_empty'] != true &&
      sheet['has_header'] == true &&
      sheet['missing_summary'] is Map &&
      (sheet['missing_summary'] as Map)['affected_rows'] == 0;

  Future<void> _import() async {
    if (_busy || _selected.isEmpty) return;
    final repo = ref.read(datasetRepositoryProvider);
    final generation = repo.api.generation;
    final file = widget.file;
    final sheets = _selected.difference(_saved).toList();
    final configs = _merge
        ? [
            (
              names: sheets,
              config: <String, dynamic>{
                'multi_sheet_action': 'merge',
                'sheets_to_merge': sheets,
              },
            ),
          ]
        : [
            for (final name in sheets)
              (
                names: [name],
                config: <String, dynamic>{
                  'selected_sheet': name,
                  'header_mode': 'detected',
                  if (_mergeTables.contains(name))
                    'selected_table_id': 'merge_tables',
                },
              ),
          ];
    final description = _description.text;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      for (final task in configs) {
        if (!mounted || repo.api.generation != generation) return;
        await repo.importWorkbook(file.name, file.bytes, {
          ...task.config,
          'drop_empty_rows': true,
          'drop_any_missing_rows': false,
          'missing_choice': 'keep_raw',
        }, description: description);
        if (!mounted || repo.api.generation != generation) return;
        setState(() {
          _saved.addAll(task.names);
          _selected.removeAll(task.names);
        });
        ref.invalidate(datasetsProvider);
      }
      if (mounted) setState(() => _message = 'Đã nhập xong các sheet đã chọn.');
    } catch (e) {
      if (mounted && repo.api.generation == generation) {
        ref.invalidate(datasetsProvider);
        setState(
          () => _message =
              '${e is ApiFailure ? e.message : 'Không nhập được tệp.'} '
              'Đã xác nhận lưu ${_saved.length} sheet. Kiểm tra kho trước khi thử lại nếu kết nối bị gián đoạn.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(sessionProvider, (before, after) {
      if (before?.id != after?.id &&
          ModalRoute.of(context)?.isCurrent == true) {
        Navigator.of(context).pop();
      }
    });
    return PopScope(
      canPop: !_busy,
      child: Scaffold(
        appBar: AppBar(title: const Text('Kiểm tra trước khi nhập')),
        body: SafeArea(
          child: FutureBuilder<Map<String, dynamic>>(
            future: _inspection,
            builder: (context, snapshot) {
              if (snapshot.hasError)
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: FinaiNotice(
                    snapshot.error is ApiFailure
                        ? (snapshot.error as ApiFailure).message
                        : 'Không kiểm tra được tệp.',
                    error: true,
                  ),
                );
              if (!snapshot.hasData)
                return const Center(child: CircularProgressIndicator());
              final data = snapshot.data!;
              final sheets = (data['sheets'] as List? ?? const [])
                  .whereType<Map>()
                  .where((sheet) => sheet['name'] is String)
                  .toList();
              final groups =
                  (data['mergeable_sheet_groups'] as List? ?? const [])
                      .whereType<Map>();
              final compatible =
                  _selected.length > 1 &&
                  groups.any(
                    (group) =>
                        group['sheet_names'] is List &&
                        _selected.every(
                          (name) =>
                              (group['sheet_names'] as List).contains(name),
                        ),
                  );
              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  FinaiHeading(
                    title: widget.file.name,
                    subtitle: '${sheets.length} sheet',
                    icon: Icons.fact_check_outlined,
                  ),
                  if (sheets.isEmpty)
                    const FinaiNotice(
                      'Máy chủ không tìm thấy sheet để nhập.',
                      warning: true,
                    ),
                  TextField(
                    controller: _description,
                    enabled: !_busy,
                    maxLength: 500,
                    decoration: const InputDecoration(
                      labelText: 'Mô tả (tùy chọn)',
                    ),
                  ),
                  for (final sheet in sheets) _sheetCard(sheet),
                  if (compatible)
                    SwitchListTile(
                      value: _merge,
                      title: const Text('Gộp các sheet đã chọn'),
                      onChanged: _busy
                          ? null
                          : (value) => setState(() => _merge = value),
                    ),
                  if (_saved.isNotEmpty) Text('Đã lưu: ${_saved.join(', ')}'),
                  if (_message != null) FinaiNotice(_message!),
                  if (_busy) const LinearProgressIndicator(),
                  FilledButton(
                    onPressed: _busy || _selected.isEmpty ? null : _import,
                    child: Text(
                      _busy ? 'Đang lưu…' : 'Nhập ${_selected.length} sheet',
                    ),
                  ),
                  if (!_busy && _saved.isNotEmpty)
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Về Kho dữ liệu'),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _sheetCard(Map sheet) {
    final name = sheet['name'] as String;
    final missing = sheet['missing_summary'] as Map?;
    final valid = _valid(sheet);
    final reason = sheet['is_empty'] == true
        ? 'Sheet rỗng'
        : sheet['has_header'] != true
        ? 'Thiếu header'
        : !valid
        ? 'Có ô thiếu hoặc chưa xác định được chất lượng'
        : 'Có thể nhập';
    return Card(
      child: Column(
        children: [
          CheckboxListTile(
            value: _saved.contains(name) || _selected.contains(name),
            title: Text(name),
            subtitle: Text(_saved.contains(name) ? 'Đã lưu' : reason),
            onChanged: !valid || _busy || _saved.contains(name)
                ? null
                : (checked) => setState(() {
                    if (checked == true) {
                      _selected.add(name);
                    } else {
                      _selected.remove(name);
                    }
                    _merge = false;
                  }),
          ),
          ExpansionTile(
            title: const Text('Xem cấu trúc và mẫu'),
            children: [
              ListTile(
                title: Text(
                  '${sheet['row_count'] ?? '—'} dòng • ${sheet['column_count'] ?? '—'} cột',
                ),
                subtitle: Text(
                  'Header: ${sheet['header_type'] ?? '—'} • Ô thiếu: ${missing?['total_missing'] ?? '—'}',
                ),
              ),
              for (final region
                  in (sheet['table_regions'] as List? ?? const [])
                      .whereType<Map>())
                ListTile(
                  dense: true,
                  title: Text('Vùng bảng ${region['range'] ?? '—'}'),
                  subtitle: Text(
                    (region['headers'] as List? ?? const []).join(', '),
                  ),
                ),
              if (valid && sheet['is_multi_table'] == true)
                CheckboxListTile(
                  title: const Text('Gộp các bảng trong sheet'),
                  value: _mergeTables.contains(name),
                  onChanged: _busy || _saved.contains(name)
                      ? null
                      : (checked) => setState(() {
                          if (checked == true) {
                            _mergeTables.add(name);
                          } else {
                            _mergeTables.remove(name);
                          }
                        }),
                ),
              for (final row
                  in (sheet['sample_data'] as List? ?? const [])
                      .whereType<Map>()
                      .take(5))
                ListTile(
                  dense: true,
                  title: Text(
                    row.entries
                        .map((e) => '${e.key}: ${e.value ?? '—'}')
                        .join(' · '),
                  ),
                ),
              for (final cell
                  in (sheet['missing_cells'] as List? ?? const [])
                      .whereType<Map>()
                      .take(15))
                ListTile(
                  dense: true,
                  title: Text('Ô thiếu ở cột ${cell['column_name'] ?? '—'}'),
                  subtitle: Text(
                    'Chỉ số dòng trong dữ liệu: ${cell['row_index'] ?? '—'}',
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
