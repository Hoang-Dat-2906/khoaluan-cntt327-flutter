import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/session.dart';
import '../../core/network/api_client.dart';
import '../../shared/widgets/finai_design.dart';
import 'account_form.dart';

class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});
  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false, _obscure = true;
  String? _error;
  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || !_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(sessionProvider.notifier)
          .signIn(email: _email.text, password: _password.text);
    } on ApiFailure catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Không đăng nhập được. Vui lòng thử lại.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: FinaiColors.dark(context)
              ? const [Color(0xFF090D16), Color(0xFF0F172A), Color(0xFF042F2E)]
              : const [Color(0xFFF8FAFC), Color(0xFFFFFFFF), Color(0xFFF0FDFA)],
        ),
      ),
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Center(child: FinaiMark(size: 68)),
                  const SizedBox(height: 18),
                  Text(
                    'FinAI Mobile',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Dữ liệu rõ ràng. Góc nhìn thông minh.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: FinaiColors.muted(context)),
                  ),
                  const SizedBox(height: 28),
                  FinaiPanel(
                    child: AutofillGroup(
                      child: Form(
                        key: _form,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'Chào mừng trở lại',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Đăng nhập để tiếp tục khám phá dữ liệu của bạn.',
                              style: TextStyle(
                                color: FinaiColors.muted(context),
                              ),
                            ),
                            const SizedBox(height: 24),
                            TextFormField(
                              controller: _email,
                              enabled: !_busy,
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.next,
                              autocorrect: false,
                              autofillHints: const [AutofillHints.username],
                              decoration: const InputDecoration(
                                labelText: 'Email',
                                hintText: 'Địa chỉ email của bạn',
                                prefixIcon: Icon(Icons.alternate_email_rounded),
                              ),
                              validator: (v) =>
                                  RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                                      .hasMatch(v?.trim() ?? '')
                                  ? null
                                  : 'Nhập email hợp lệ',
                            ),
                            const SizedBox(height: 18),
                            TextFormField(
                              controller: _password,
                              enabled: !_busy,
                              obscureText: _obscure,
                              autofillHints: const [AutofillHints.password],
                              textInputAction: TextInputAction.done,
                              onFieldSubmitted: (_) => _submit(),
                              decoration: InputDecoration(
                                labelText: 'Mật khẩu',
                                prefixIcon: const Icon(
                                  Icons.lock_outline_rounded,
                                ),
                                suffixIcon: IconButton(
                                  tooltip: _obscure
                                      ? 'Hiện mật khẩu'
                                      : 'Ẩn mật khẩu',
                                  onPressed: _busy
                                      ? null
                                      : () => setState(
                                          () => _obscure = !_obscure,
                                        ),
                                  icon: Icon(
                                    _obscure
                                        ? Icons.visibility_outlined
                                        : Icons.visibility_off_outlined,
                                  ),
                                ),
                              ),
                              validator: (v) => v == null || v.isEmpty
                                  ? 'Nhập mật khẩu'
                                  : null,
                            ),
                            if (_error != null)
                              FinaiNotice(_error!, error: true),
                            const SizedBox(height: 24),
                            FilledButton(
                              onPressed: _busy ? null : _submit,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  if (_busy) ...[
                                    const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                  ],
                                  Flexible(
                                    child: Text(
                                      _busy ? 'Đang đăng nhập…' : 'Đăng nhập',
                                    ),
                                  ),
                                  if (!_busy) ...[
                                    const SizedBox(width: 10),
                                    const Icon(
                                      Icons.arrow_forward_rounded,
                                      size: 18,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            Wrap(
                              spacing: 8,
                              children: [
                                for (final (kind, label) in [
                                  (AccountFormKind.recover, 'Quên mật khẩu'),
                                  (AccountFormKind.register, 'Tạo tài khoản'),
                                ])
                                  TextButton(
                                    onPressed: _busy
                                        ? null
                                        : () => Navigator.of(context).push(
                                            MaterialPageRoute<void>(
                                              builder: (_) =>
                                                  AccountFormScreen(kind: kind),
                                            ),
                                          ),
                                    child: Text(label),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.verified_user_outlined,
                        size: 18,
                        color: Theme.of(context).colorScheme.secondary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Sử dụng tài khoản đã được cấp trên hệ thống Web. Dữ liệu và quyền truy cập dùng chung.',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: FinaiColors.muted(context)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
