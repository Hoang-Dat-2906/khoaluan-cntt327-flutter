import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';

class SelectedDatasetFile {
  const SelectedDatasetFile(this.name, this.bytes);
  final String name;
  final Uint8List bytes;
}

abstract interface class DatasetFilePicker {
  Future<SelectedDatasetFile?> pick();
}

class NativeDatasetFilePicker implements DatasetFilePicker {
  @override
  Future<SelectedDatasetFile?> pick() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom, allowedExtensions: ['csv', 'xlsx', 'xls'],
      withData: false, withReadStream: true,
    );
    if (picked == null) return null;
    if (picked.files.length != 1) throw const ApiFailure('Chọn một tệp dữ liệu.');
    final file = picked.files.single;
    if (file.size <= 0 || file.size > ApiClient.maxFileBytes) {
      throw const ApiFailure('Chọn file có dữ liệu, tối đa 15 MB.');
    }
    final stream = file.readStream;
    if (stream == null) throw const ApiFailure('Không đọc được file đã chọn.');
    final bytes = BytesBuilder(copy: false);
    await for (final chunk in stream) {
      if (bytes.length + chunk.length > ApiClient.maxFileBytes) {
        throw const ApiFailure('File vượt 15 MB.');
      }
      bytes.add(chunk);
    }
    return SelectedDatasetFile(file.name, bytes.takeBytes());
  }
}

final datasetFilePickerProvider = Provider<DatasetFilePicker>(
  (ref) => NativeDatasetFilePicker(),
);
