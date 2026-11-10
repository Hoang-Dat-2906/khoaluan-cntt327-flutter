import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/session.dart';
import '../../core/network/api_client.dart';
import '../../shared/widgets/finai_design.dart';

enum AccountFormKind { profile, password, register, recover, reset }

class AccountFormScreen extends ConsumerStatefulWidget {
  const AccountFormScreen({super.key, required this.kind, this.token});
  final AccountFormKind kind;
  final String? token;

  @override
  ConsumerState<AccountFormScreen> createState() => _AccountFormScreenState();
}

class _AccountFormScreenState extends ConsumerState<AccountFormScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController(),
      _email = TextEditingController(),
      _current = TextEditingController(),
      _password = TextEditingController(),
      _repeat = TextEditingController(),
      _token = TextEditingController();
  String? _notice;
  bool _busy = false, _saved = false;
  AccountFormKind get _kind => widget.kind;
  bool get _nameField =>
      _kind == AccountFormKind.profile || _kind == AccountFormKind.register;
  bool get _passwordField => const [
    AccountFormKind.password,
    AccountFormKind.register,
    AccountFormKind.reset,
  ].contains(_kind);

  @override
  void initState() {
    super.initState();
    if (_kind == AccountFormKind.profile) {
      final user = ref.read(sessionProvider);
      _name.text = user?.name ?? '';
      _email.text = user?.email ?? '';
    }
    _token.text = widget.token ?? '';
  }

  @override
  void dispose() {
    for (final controller in [
      _name,
      _email,
      _current,
      _password,
      _repeat,
      _token,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || !_form.currentState!.validate()) return;
    final api = ref.read(apiClientProvider);
    final session = ref.read(sessionProvider.notifier);
    final generation = api.generation;
    bool current() => mounted && api.generation == generation;
    setState(() {
      _busy = true;
      _notice = null;
      _saved = false;
    });
    try {
      switch (_kind) {
        case AccountFormKind.profile:
          await session.updateProfile(_name.text, _email.text);
        case AccountFormKind.password:
          await session.changePassword(_current.text, _password.text);
        case AccountFormKind.register:
          await api.jsonRequest(
            'users/signup',
            method: 'POST',
            authenticated: false,
            jsonBody: {
              'email': _email.text.trim(),
              'full_name': _name.text.trim(),
              'password': _password.text,
            },
          );
        case AccountFormKind.recover:
          await api.jsonRequest(
            'password-recovery/${Uri.encodeComponent(_email.text.trim())}',
            method: 'POST',
            authenticated: false,
          );
        case AccountFormKind.reset:
          await api.jsonRequest(
            'reset-password/',
            method: 'POST',
            authenticated: false,
            jsonBody: {
              'token': _token.text.trim(),
              'new_password': _password.text,
            },
          );
      }
      if (current()) {
        _current.clear();
        _password.clear();
        _repeat.clear();
        _token.clear();
        setState(() {
          _saved = true;
          _notice = _kind == AccountFormKind.recover
              ? 'Đã gửi yêu cầu. Hãy kiểm tra email để đặt lại mật khẩu.'
              : 'Đã lưu thành công.';
        });
      }
    } catch (e) {
      if (current())
        setState(
          () => _notice = e is ApiFailure
              ? e.message
              : 'Không hoàn tất được yêu cầu.',
        );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    bool password = false,
    TextInputType? keyboard,
    String? Function(String?)? validate,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextFormField(
      controller: controller,
      obscureText: password,
      enabled: !_busy,
      keyboardType: keyboard,
      autocorrect: !password,
      enableSuggestions: !password,
      decoration: InputDecoration(labelText: label),
      validator: validate,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final title = switch (_kind) {
      AccountFormKind.profile => 'Thông tin cá nhân',
      AccountFormKind.password => 'Đổi mật khẩu',
      AccountFormKind.register => 'Đăng ký',
      AccountFormKind.recover => 'Quên mật khẩu',
      AccountFormKind.reset => 'Đặt lại mật khẩu',
    };
    ref.listen(sessionProvider, (before, after) {
      if (before?.id != after?.id && ModalRoute.of(context)?.isCurrent == true)
        Navigator.pop(context);
    });
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              FinaiHeading(
                title: title,
                subtitle: 'Tài khoản dùng chung với FinAI Web.',
                icon: Icons.manage_accounts_outlined,
              ),
              if (_nameField)
                _field(
                  _name,
                  'Họ và tên',
                  validate: (v) => (v?.trim().length ?? 0) > 255
                      ? 'Họ và tên tối đa 255 ký tự.'
                      : null,
                ),
              if (_nameField || _kind == AccountFormKind.recover)
                _field(
                  _email,
                  'Email',
                  keyboard: TextInputType.emailAddress,
                  validate: (v) =>
                      RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                              .hasMatch(v?.trim() ?? '') &&
                          (v?.trim().length ?? 0) <= 255
                      ? null
                      : 'Nhập địa chỉ email hợp lệ.',
                ),
              if (_kind == AccountFormKind.reset)
                _field(
                  _token,
                  'Mã đặt lại mật khẩu',
                  password: true,
                  validate: (v) => (v?.trim().isEmpty ?? true)
                      ? 'Nhập mã trong liên kết từ email.'
                      : null,
                ),
              if (_kind == AccountFormKind.password)
                _field(
                  _current,
                  'Mật khẩu hiện tại',
                  password: true,
                  validate: (v) =>
                      (v?.isEmpty ?? true) ? 'Nhập mật khẩu hiện tại.' : null,
                ),
              if (_passwordField) ...[
                _field(
                  _password,
                  'Mật khẩu mới',
                  password: true,
                  validate: (v) =>
                      (v?.length ?? 0) < 8 || (v?.length ?? 0) > 128
                      ? 'Dùng mật khẩu từ 8 đến 128 ký tự.'
                      : null,
                ),
                _field(
                  _repeat,
                  'Xác nhận mật khẩu',
                  password: true,
                  validate: (v) =>
                      v == _password.text ? null : 'Mật khẩu chưa khớp.',
                ),
              ],
              if (_notice != null) FinaiNotice(_notice!, error: !_saved),
              if (_saved)
                OutlinedButton(
                  onPressed: () => Navigator.maybePop(context),
                  child: const Text('Quay lại'),
                )
              else
                FilledButton(
                  onPressed: _busy ? null : _submit,
                  child: Text(_busy ? 'Đang xử lý…' : title),
                ),
              if (_kind == AccountFormKind.recover)
                TextButton(
                  onPressed: _busy
                      ? null
                      : () => Navigator.push(
                          context,
                          MaterialPageRoute<void>(
                            builder: (_) => const AccountFormScreen(
                              kind: AccountFormKind.reset,
                            ),
                          ),
                        ),
                  child: const Text('Tôi đã có mã đặt lại mật khẩu'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
