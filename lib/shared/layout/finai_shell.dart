import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/session.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_theme.dart';

class FinaiShell extends StatelessWidget {
  const FinaiShell({super.key, required this.child, required this.location});
  final Widget child;
  final String location;
  @override
  Widget build(BuildContext context) {
    final selected =
        location.startsWith('/datasets') || location.startsWith('/analysis')
        ? 1
        : location == '/settings'
        ? 2
        : 0;
    void navigate(int index) =>
        context.go(['/', '/datasets', '/settings'][index]);
    return Scaffold(
      appBar: AppBar(title: const Text('FinAI Mobile')),
      bottomNavigationBar: NavigationBar(
        selectedIndex: selected,
        onDestinationSelected: navigate,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            label: 'Tổng quan',
          ),
          NavigationDestination(
            icon: Icon(Icons.storage_outlined),
            label: 'Dữ liệu',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            label: 'Cài đặt',
          ),
        ],
      ),
      body: SafeArea(child: child),
    );
  }
}

class SessionGateScreen extends ConsumerWidget {
  const SessionGateScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bootstrap = ref.watch(sessionBootstrapProvider);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: bootstrap.hasError
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        bootstrap.error is ApiFailure
                            ? (bootstrap.error as ApiFailure).message
                            : 'Chưa khôi phục được phiên làm việc.',
                      ),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: () =>
                            ref.invalidate(sessionBootstrapProvider),
                        child: const Text('Thử lại'),
                      ),
                      TextButton(
                        onPressed: () async {
                          try {
                            await ref.read(sessionProvider.notifier).signOut();
                            ref.invalidate(sessionBootstrapProvider);
                          } catch (_) {
                            /* The retry above remains available if secure storage fails. */
                          }
                        },
                        child: const Text('Xóa phiên và đăng nhập lại'),
                      ),
                    ],
                  )
                : const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('Đang kiểm tra phiên đăng nhập…'),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

class FinaiSettingsScreen extends ConsumerStatefulWidget {
  const FinaiSettingsScreen({super.key});
  @override
  ConsumerState<FinaiSettingsScreen> createState() =>
      _FinaiSettingsScreenState();
}

class _FinaiSettingsScreenState extends ConsumerState<FinaiSettingsScreen> {
  String? _error;
  @override
  Widget build(BuildContext context) {
    final user = ref.watch(sessionProvider);
    final api = ref.watch(apiClientProvider);
    final url = Uri.tryParse(api.baseUrl);
    final safeUrl =
        url != null && url.userInfo.isEmpty && !url.hasQuery && !url.hasFragment
        ? api.baseUrl
        : 'Cấu hình URL không hợp lệ';
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text('Tài khoản', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        Text(user?.name ?? ''),
        Text(user?.email ?? ''),
        Text('Vai trò: ${user?.role ?? ""}'),
        const Divider(height: 32),
        const Text('Máy chủ API'),
        SelectableText(
          safeUrl.isEmpty ? 'Chưa cấu hình API_BASE_URL' : safeUrl,
        ),
        const SizedBox(height: 12),
        const Text(
          'Chế độ phân tích: tải dataset rồi gửi multipart tới backend. Chưa có API phân tích theo dataset_id hoặc dự báo.',
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Giao diện tối'),
          value: ref.watch(themeProvider).mode == ThemeMode.dark,
          onChanged: (dark) => ref
              .read(themeProvider.notifier)
              .setMode(dark ? ThemeMode.dark : ThemeMode.light),
        ),
        if (_error != null)
          Text(_error!, style: const TextStyle(color: Colors.red)),
        FilledButton.icon(
          onPressed: () async {
            try {
              await ref.read(sessionProvider.notifier).signOut();
            } on ApiFailure catch (e) {
              if (mounted) setState(() => _error = e.message);
            }
          },
          icon: const Icon(Icons.logout),
          label: const Text('Đăng xuất'),
        ),
        const SizedBox(height: 20),
        const Text(
          'Phát triển từ Kite của Colorlib, giấy phép MIT. Phần nghiệp vụ FinAI do nhóm CNTT-KLCN327 tích hợp.',
        ),
      ],
    );
  }
}
