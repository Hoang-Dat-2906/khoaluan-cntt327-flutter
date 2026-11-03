import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/session.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../widgets/finai_design.dart';

class FinaiShell extends StatelessWidget {
  const FinaiShell({super.key, required this.child, required this.location});
  final Widget child;
  final String location;
  @override
  Widget build(BuildContext context) {
    final selected =
        location.startsWith('/datasets') || location.startsWith('/analysis')
        ? 1
        : location.startsWith('/forecast')
        ? 2
        : location.startsWith('/history')
        ? 3
        : location == '/settings'
        ? 4
        : 0;
    void navigate(int index) =>
        context.go(['/', '/datasets', '/forecast', '/history', '/settings'][index]);
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 72,
        leading: location.startsWith('/datasets/') || location.startsWith('/analysis/') || location.startsWith('/forecast/')
            ? IconButton(tooltip: 'Quay lại', icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () => context.go(location.startsWith('/forecast/') ? '/forecast' : '/datasets'))
            : null,
        title: const Row(children: [FinaiMark(size: 36), SizedBox(width: 10),
          Flexible(child: Text('FinAI Mobile', overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800)))]),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: selected,
        onDestinationSelected: navigate,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Tổng quan',
          ),
          NavigationDestination(
            icon: Icon(Icons.storage_outlined),
            selectedIcon: Icon(Icons.storage_rounded),
            label: 'Dữ liệu',
          ),
          NavigationDestination(
            icon: Icon(Icons.trending_up),
            selectedIcon: Icon(Icons.insights_rounded),
            label: 'Dự báo',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_rounded),
            label: 'Lịch sử',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings_rounded),
            label: 'Cài đặt',
          ),
        ],
      ),
      body: SafeArea(child: Align(alignment: Alignment.topCenter,
        child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 860), child: child))),
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
          child: SingleChildScrollView(
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
                      FinaiMark(size: 64),
                      SizedBox(height: 24),
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

    return ListView(padding: const EdgeInsets.fromLTRB(20, 12, 20, 32), children: [
      const FinaiHeading(title: 'Không gian của bạn', subtitle: 'Tài khoản, giao diện và kết nối.', icon: Icons.tune_rounded),
      FinaiPanel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        CircleAvatar(radius: 30, backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          child: Text(user?.initials ?? 'F', style: TextStyle(fontSize: 22,
              fontWeight: FontWeight.w800, color: Theme.of(context).colorScheme.onPrimaryContainer))),
        const SizedBox(height: 16),
        Text(user?.name ?? '', style: Theme.of(context).textTheme.titleLarge),
        Text(user?.email ?? '', style: TextStyle(color: FinaiColors.muted(context))),
        const SizedBox(height: 10),
        Chip(avatar: const Icon(Icons.verified_user_outlined, size: 16), label: Text('Vai trò: ${user?.role ?? ""}')),
      ])),
      const SizedBox(height: 16),
      FinaiSection(title: 'Giao diện', child: SwitchListTile.adaptive(
        contentPadding: EdgeInsets.zero, secondary: const Icon(Icons.dark_mode_outlined),
        title: const Text('Giao diện tối'), subtitle: const Text('Dễ nhìn khi làm việc vào ban đêm'),
        value: ref.watch(themeProvider).mode == ThemeMode.dark,
        onChanged: (dark) => ref.read(themeProvider.notifier).setMode(dark ? ThemeMode.dark : ThemeMode.light))),
      FinaiSection(title: 'Kết nối máy chủ', child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('Máy chủ API', style: TextStyle(color: FinaiColors.muted(context))),
        const SizedBox(height: 8),
        SelectableText(safeUrl.isEmpty ? 'Chưa cấu hình API_BASE_URL' : safeUrl),
        const FinaiNotice('Dữ liệu và quyền truy cập được dùng chung với FinAI Web.'),
      ])),
      if (_error != null) FinaiNotice(_error!, error: true),
      OutlinedButton.icon(style: OutlinedButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
        onPressed: () async {
          try {
            await ref.read(sessionProvider.notifier).signOut();
          } on ApiFailure catch (e) {
            if (mounted) { setState(() => _error = e.message); }
          }
        }, icon: const Icon(Icons.logout_rounded), label: const Text('Đăng xuất')),
      const SizedBox(height: 24),
      Text('Phát triển từ Kite của Colorlib, giấy phép MIT. Phần nghiệp vụ FinAI do nhóm CNTT-KLCN327 tích hợp.',
        textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: FinaiColors.muted(context))),
    ]);
  }
}
