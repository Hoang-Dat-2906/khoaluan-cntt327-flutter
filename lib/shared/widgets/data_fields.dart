import 'package:flutter/material.dart';

/// Renders nested server reports without interpreting strings as HTML or links.
class DataFields extends StatelessWidget {
  const DataFields(
    this.values, {
    super.key,
    this.labels = const {},
    this.depth = 0,
  });
  final Map values;
  final Map<String, String> labels;
  final int depth;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (final entry in values.entries)
        _field(
          context,
          labels[entry.key] ?? entry.key.toString().replaceAll('_', ' '),
          entry.value,
        ),
    ],
  );

  Widget _field(BuildContext context, String name, Object? value) {
    if (value is Map && depth < 6) {
      return ExpansionTile(
        title: Text(name),
        children: [DataFields(value, labels: labels, depth: depth + 1)],
      );
    }
    if (value is List && depth < 6) {
      return ExpansionTile(
        title: Text('$name (${value.length})'),
        children: [
          for (final item in value.take(50))
            if (item is Map)
              DataFields(item, labels: labels, depth: depth + 1)
            else
              Padding(
                padding: const EdgeInsets.all(6),
                child: SelectableText(item?.toString() ?? '—'),
              ),
          if (value.length > 50) const Text('Đang hiển thị 50 mục đầu.'),
        ],
      );
    }
    final text = value?.toString() ?? '—';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: SelectableText(
        '$name: ${text.length > 4000 ? '${text.substring(0, 4000)}…' : text}',
      ),
    );
  }
}

Future<bool> confirmFinaiAction(
  BuildContext context, {
  required String title,
  required String description,
  required String action,
}) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(description),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(action),
          ),
        ],
      ),
    ) ??
    false;
