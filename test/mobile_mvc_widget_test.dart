import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kite/core/network/api_client.dart';
import 'package:kite/features/auth/auth_screens.dart';
import 'package:kite/features/datasets/dataset.dart';
import 'package:kite/features/datasets/dataset_file_picker.dart';
import 'package:kite/features/datasets/dataset_repository.dart';
import 'package:kite/features/datasets/dataset_screens.dart';
import 'package:kite/features/forecast/forecast.dart';
import 'package:kite/features/forecast/forecast_screen.dart';
import 'package:kite/shared/widgets/finai_design.dart';
import 'package:kite_ui/kite_ui.dart';
import 'package:kite_ui/shadcn.dart';

import 'finai_contract_test.dart' show datasetJson;
import 'mobile_mvc_forecast_test.dart' show forecastJson;

class CancelPicker implements DatasetFilePicker {
  int calls = 0;
  @override
  Future<SelectedDatasetFile?> pick() async { calls++; return null; }
}

class RejectingPicker implements DatasetFilePicker {
  @override
  Future<SelectedDatasetFile?> pick() async => throw const ApiFailure('Không đọc được file đã chọn.');
}

void main() {
  for (final brightness in [Brightness.light, Brightness.dark]) {
    testWidgets('long dataset name wraps in ${brightness.name} theme at 360dp', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final data = Dataset.fromJson({
        ...datasetJson(),
        'filename': 'Bao_cao_doanh_thu_chi_phi_tong_hop_nhieu_chi_nhanh_nam_2025.csv',
      });
      var opened = false;
      await tester.pumpWidget(MaterialApp(theme: FinaiColors.theme(brightness),
        home: Scaffold(body: SingleChildScrollView(child: Padding(
          padding: const EdgeInsets.all(20),
          child: FinaiDatasetTile(dataset: data, onTap: () => opened = true),
        ))),
      ));
      await tester.pumpAndSettle();
      expect(find.text(data.filename), findsOneWidget);
      await tester.tap(find.text(data.filename));
      expect(opened, isTrue);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('login scrolls to password with keyboard and larger text', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    tester.view.viewInsets = const FakeViewPadding(bottom: 280);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpWidget(ProviderScope(child: MaterialApp(
      theme: FinaiColors.theme(Brightness.light),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(1.3)),
        child: child!,
      ),
      home: const SignInScreen(),
    )));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byType(FilledButton));
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();
    expect(find.text('Nhập email hợp lệ'), findsOneWidget);
    expect(find.text('Nhập mật khẩu'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('missing dataset disables analysis and forecast at 360dp', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final data = Dataset.fromJson({...datasetJson(), 'file_available': false, 'status': 'missing'});
    await tester.pumpWidget(ProviderScope(overrides: [
      datasetDetailProvider('synthetic-dataset').overrideWith((ref) async => data),
    ], child: const ShadApp(home: Scaffold(body: DatasetDetailScreen(id: 'synthetic-dataset')))));
    await tester.pumpAndSettle();
    expect(find.text('Tệp không còn tồn tại — vui lòng tải lại'), findsOneWidget);
    final action = find.ancestor(of: find.text('Dự báo chỉ tiêu'), matching: find.byType(TextButton));
    expect(tester.widget<TextButton>(action).onPressed, isNull);
    final analyze = find.ancestor(
      of: find.text('Đặt câu hỏi phân tích'), matching: find.byType(KiteButton),
    );
    expect(tester.widget<KiteButton>(analyze).enabled, isFalse);
    expect(tester.takeException(), isNull);
  });
  testWidgets('forecast form remains disabled before column selection', (tester) async {
    final data = Dataset.fromJson(datasetJson());
    await tester.pumpWidget(ProviderScope(overrides: [
      datasetDetailProvider('synthetic-dataset').overrideWith((ref) async => data),
    ], child: const ShadApp(home: Scaffold(body: ForecastScreen(id: 'synthetic-dataset')))));
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed, isNull);
    expect(find.text('Cột chỉ tiêu số'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('forecast labels fitted and unavailable MAPE truthfully', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(ShadApp(home: Scaffold(body: SingleChildScrollView(
      child: ForecastResultView(result: ForecastResult.fromJson(forecastJson(), 'd')),
    ))));
    await tester.pumpAndSettle();
    expect(find.text('MAPE: Không xác định'), findsOneWidget);
    expect(find.textContaining('chưa đánh giá trên tập kiểm tra'), findsOneWidget);
    expect(find.textContaining('Có actual bằng 0.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('picker cancellation does not invoke native plugin', (tester) async {
    final picker = CancelPicker();
    await tester.pumpWidget(ProviderScope(overrides: [
      datasetFilePickerProvider.overrideWithValue(picker),
      datasetsProvider.overrideWith((ref) async => const DatasetPage([], 0)),
    ], child: const ShadApp(home: Scaffold(body: DatasetListScreen()))));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tải CSV / Excel lên kho'));
    await tester.pumpAndSettle();
    expect(picker.calls, 1);
    expect(find.text('Tải CSV / Excel lên kho'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('picker failure is displayed without reporting upload success', (tester) async {
    await tester.pumpWidget(ProviderScope(overrides: [
      datasetFilePickerProvider.overrideWithValue(RejectingPicker()),
      datasetsProvider.overrideWith((ref) async => const DatasetPage([], 0)),
    ], child: const ShadApp(home: Scaffold(body: DatasetListScreen()))));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tải CSV / Excel lên kho'));
    await tester.pumpAndSettle();
    expect(find.text('Không đọc được file đã chọn.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
