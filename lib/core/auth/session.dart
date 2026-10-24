import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../network/api_client.dart';
import 'token_store.dart';

@immutable
class SessionUser {
  const SessionUser({
    required this.id,
    required this.name,
    required this.email,
    this.role = 'User',
  });
  final String id;
  final String name;
  final String email;
  final String role;
  String get initials => name
      .trim()
      .split(RegExp(r'\s+'))
      .take(2)
      .map((p) => p.isEmpty ? '' : p[0].toUpperCase())
      .join();
  factory SessionUser.fromJson(Map<String, dynamic> j) {
    if (j['id'] is! String ||
        j['email'] is! String ||
        j['is_superuser'] is! bool ||
        j['is_active'] != true) {
      throw const ApiFailure(
        'Thông tin tài khoản trả về không hợp lệ hoặc tài khoản đã bị khóa.',
      );
    }
    return SessionUser(
      id: j['id'] as String,
      email: j['email'] as String,
      name:
          (j['full_name'] is String &&
              (j['full_name'] as String).trim().isNotEmpty)
          ? j['full_name'] as String
          : j['email'] as String,
      role: j['is_superuser'] == true ? 'Admin' : 'User',
    );
  }
}

final tokenStoreProvider = Provider<TokenStore>(
  (ref) => const SecureTokenStore(),
);
final apiClientProvider = Provider<ApiClient>((ref) {
  final api = ApiClient(baseUrl: const String.fromEnvironment('API_BASE_URL'));
  ref.onDispose(api.close);
  return api;
});
final sessionProvider = NotifierProvider<SessionController, SessionUser?>(
  SessionController.new,
);
final sessionBootstrapProvider = FutureProvider<void>(
  (ref) => ref.read(sessionProvider.notifier).restore(),
  retry: (_, _) => null,
);

class SessionController extends Notifier<SessionUser?> {
  int _revision = 0;
  bool _alive = true;
  late TokenStore _store;
  Future<void> _queue = Future.value();
  ApiClient get _api => ref.read(apiClientProvider);
  bool get isSignedIn => state != null;
  @override
  SessionUser? build() {
    final api = ref.read(apiClientProvider);
    _store = ref.read(tokenStoreProvider);
    api.onUnauthorized = (stamp) {
      if (_alive && stamp == api.generation) {
        unawaited(signOut().catchError((Object _) {}));
      }
    };
    ref.onDispose(() {
      _alive = false;
      _revision++;
      api.onUnauthorized = null;
    });
    return null;
  }

  bool _current(int version) => _alive && _revision == version;
  Future<void> _storage(Future<void> Function() action) {
    final next = _queue.then((_) => action());
    _queue = next.catchError((Object _) {});
    return next;
  }

  Future<void> restore() async {
    final version = ++_revision;
    try {
      final token = await _store.read();
      if (!_current(version) || token == null || token.isEmpty) return;
      final user = SessionUser.fromJson(
        await _api.jsonRequest('users/me', authenticated: false, bearer: token),
      );
      if (!_current(version)) return;
      _api.setToken(token);
      state = user;
    } on ApiFailure catch (e) {
      if (!_current(version)) return;
      if (e.status == 401 || e.status == 403) {
        await signOut();
        return;
      }
      rethrow;
    } catch (_) {
      if (_current(version)) {
        throw const ApiFailure(
          'Không đọc được phiên đăng nhập an toàn. Vui lòng thử lại.',
        );
      }
    }
  }

  Future<void> signIn({required String email, required String password}) async {
    final version = ++_revision;
    final login = await _api.jsonRequest(
      'login/access-token',
      method: 'POST',
      authenticated: false,
      form: {'username': email.trim(), 'password': password},
    );
    final token = login['access_token'];
    if (token is! String || token.isEmpty) {
      throw const ApiFailure('Máy chủ không trả token hợp lệ.');
    }
    if (!_current(version)) return;
    final user = SessionUser.fromJson(
      await _api.jsonRequest('users/me', authenticated: false, bearer: token),
    );
    if (!_current(version)) return;
    try {
      await _storage(() async {
        if (_current(version)) await _store.write(token);
      });
    } catch (_) {
      throw const ApiFailure('Không lưu được phiên vào bộ nhớ an toàn.');
    }
    if (!_current(version)) return;
    _api.setToken(token);
    state = user;
  }

  Future<void> signOut() async {
    ++_revision;
    _api.setToken(null);
    state = null;
    try {
      await _storage(_store.clear);
    } catch (_) {
      throw const ApiFailure(
        'Đã thoát phiên hiện tại nhưng chưa xóa được token lưu trên thiết bị. Hãy thử đăng xuất lại.',
      );
    }
  }
}
