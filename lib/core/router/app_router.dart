import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/analysis/analysis_screen.dart';
import '../../features/auth/auth_screens.dart';
import '../../features/datasets/dataset_screens.dart';
import '../../shared/layout/finai_shell.dart';
import '../auth/session.dart';

class _SessionRefresh extends ChangeNotifier {
  _SessionRefresh(Ref ref) {
    ref.listen(sessionProvider, (_, _) => notifyListeners());
    ref.listen(sessionBootstrapProvider, (_, _) => notifyListeners());
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = _SessionRefresh(ref);
  final router = GoRouter(
    initialLocation: '/',
    refreshListenable: refresh,
    redirect: (context, state) {
      final bootstrap = ref.read(sessionBootstrapProvider);
      if (bootstrap.isLoading || bootstrap.hasError) {
        return state.uri.path == '/session' ? null : '/session';
      }
      final signedIn = ref.read(sessionProvider) != null;
      if (!signedIn) return state.uri.path == '/sign-in' ? null : '/sign-in';
      if (state.uri.path == '/sign-in' || state.uri.path == '/session') {
        return '/';
      }
      return null;
    },
    errorBuilder: (context, state) => Scaffold(
      appBar: AppBar(title: const Text('Không tìm thấy trang')),
      body: Center(
        child: TextButton(
          onPressed: () => context.go('/'),
          child: const Text('Về tổng quan'),
        ),
      ),
    ),
    routes: [
      GoRoute(path: '/session', builder: (_, _) => const SessionGateScreen()),
      GoRoute(path: '/sign-in', builder: (_, _) => const SignInScreen()),
      ShellRoute(
        builder: (_, state, child) =>
            FinaiShell(location: state.uri.path, child: child),
        routes: [
          GoRoute(path: '/', builder: (_, _) => const FinaiOverviewScreen()),
          GoRoute(
            path: '/datasets',
            builder: (_, _) => const DatasetListScreen(),
          ),
          GoRoute(
            path: '/datasets/:id',
            builder: (_, s) => DatasetDetailScreen(id: s.pathParameters['id']!),
          ),
          GoRoute(
            path: '/analysis/:id',
            builder: (_, s) => AnalysisScreen(id: s.pathParameters['id']!),
          ),
          GoRoute(
            path: '/settings',
            builder: (_, _) => const FinaiSettingsScreen(),
          ),
        ],
      ),
    ],
  );
  ref.onDispose(() {
    router.dispose();
    refresh.dispose();
  });
  return router;
});
