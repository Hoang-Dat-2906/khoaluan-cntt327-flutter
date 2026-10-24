import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kite/core/auth/session.dart';
import 'package:kite/core/auth/token_store.dart';
import 'package:kite/core/network/api_client.dart';

class MemoryTokenStore implements TokenStore {
  String? token;
  @override
  Future<String?> read() async => token;
  @override
  Future<void> write(String value) async {
    token = value;
  }

  @override
  Future<void> clear() async {
    token = null;
  }
}

const fixtureUser = {
  'id': 'synthetic-user',
  'email': 'tester@example.invalid',
  'full_name': 'Test User',
  'is_active': true,
  'is_superuser': false,
};
void main() {
  late ProviderContainer container;
  late MemoryTokenStore store;
  late ApiClient api;
  ProviderContainer setup(
    Future<http.Response> Function(http.Request) handler,
  ) {
    store = MemoryTokenStore();
    api = ApiClient(
      baseUrl: 'http://example.invalid',
      client: MockClient(handler),
    );
    container = ProviderContainer(
      overrides: [
        apiClientProvider.overrideWithValue(api),
        tokenStoreProvider.overrideWithValue(store),
      ],
    );
    addTearDown(() {
      container.dispose();
      api.close();
    });
    return container;
  }

  Future<http.Response> success(http.Request r) async {
    if (r.url.path.endsWith('access-token')) {
      expect(
        r.headers['content-type'],
        contains('application/x-www-form-urlencoded'),
      );
      expect(r.bodyFields['username'], 'tester@example.invalid');
      expect(r.bodyFields['password'], 'p&+ test');
      return http.Response('{"access_token":"synthetic-token"}', 200);
    }
    expect(r.headers['Authorization'], 'Bearer synthetic-token');
    return http.Response(jsonEncode(fixtureUser), 200);
  }

  test('real contract login and safe token store then logout', () async {
    setup(success);
    expect(container.read(sessionProvider), isNull);
    final controller = container.read(sessionProvider.notifier);
    await controller.signIn(
      email: 'tester@example.invalid',
      password: 'p&+ test',
    );
    expect(container.read(sessionProvider)!.name, 'Test User');
    expect(container.read(sessionProvider)!.role, 'User');
    expect(store.token, 'synthetic-token');
    await controller.signOut();
    expect(store.token, isNull);
    expect(container.read(sessionProvider), isNull);
  });
  test('wrong credentials HTTP 400 are not accepted', () async {
    setup((_) async => http.Response('private backend detail', 400));
    await expectLater(
      container
          .read(sessionProvider.notifier)
          .signIn(email: 'bad', password: 'bad'),
      throwsA(isA<ApiFailure>().having((e) => e.status, 'status', 400)),
    );
    expect(container.read(sessionProvider), isNull);
    expect(store.token, isNull);
  });
  test('restore stored token obtains real user', () async {
    setup(success);
    store.token = 'synthetic-token';
    await container.read(sessionBootstrapProvider.future);
    expect(container.read(sessionProvider)!.email, fixtureUser['email']);
  });
  test('restore 401 deletes expired credential', () async {
    setup((_) async => http.Response('', 401));
    store.token = 'expired';
    await container.read(sessionBootstrapProvider.future);
    expect(store.token, isNull);
    expect(container.read(sessionProvider), isNull);
  });
  test('restore network failure keeps token for retry', () async {
    setup((_) async => throw http.ClientException('network'));
    store.token = 'synthetic-token';
    await expectLater(
      container.read(sessionBootstrapProvider.future),
      throwsA(isA<ApiFailure>()),
    );
    expect(store.token, 'synthetic-token');
    expect(container.read(sessionProvider), isNull);
  });
  test('late login cannot restore user after logout', () async {
    final response = Completer<http.Response>();
    setup((_) => response.future);
    final controller = container.read(sessionProvider.notifier);
    final login = controller.signIn(
      email: 'tester@example.invalid',
      password: 'p',
    );
    await controller.signOut();
    response.complete(http.Response('{"access_token":"late"}', 200));
    await expectLater(login, throwsA(isA<ApiFailure>()));
    expect(store.token, isNull);
    expect(container.read(sessionProvider), isNull);
  });
  test('initials derive from authenticated user name', () {
    expect(SessionUser.fromJson(fixtureUser).initials, 'TU');
  });
}
