import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:radix_icons/radix_icons.dart';

import '../../core/router/app_router.dart';
import '../../core/widgets/brand_logo.dart';
import '../../core/widgets/form_widgets.dart';
import '../../data/api/api_exception.dart';
import '../../data/repositories/auth_repository.dart';

/// Registration does not sign in: the backend requires a confirmed email first, so success leads to the
/// "check your inbox" screen.
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _form = GlobalKey<FormState>();
  final _username = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;
  ApiException? _error;

  @override
  void dispose() {
    for (final c in [_username, _email, _password, _confirm]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || !_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final message = await context.read<AuthRepository>().register(
            username: _username.text,
            email: _email.text,
            password: _password.text,
            confirmPassword: _confirm.text,
          );
      if (!mounted) return;
      context.pushReplacement(AppRoutes.checkEmail, extra: CheckEmailArgs(_email.text.trim(), message));
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final error = _error;

    return Scaffold(
      appBar: AppBar(title: const Text('Đăng ký')),
      body: SafeArea(
        child: Form(
          key: _form,
          child: AutofillGroup(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
              children: [
                const Center(child: BrandEmblem(size: 68)),
                const SizedBox(height: 16),
                Text(
                  'Tạo tài khoản QuizMS',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                ),
                const SizedBox(height: 28),
                TextFormField(
                  controller: _username,
                  textInputAction: TextInputAction.next,
                  autocorrect: false,
                  autofillHints: const [AutofillHints.newUsername],
                  validator: Validators.username,
                  decoration: InputDecoration(
                    labelText: 'Tên người dùng',
                    errorText: error?.fieldError('username'),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autocorrect: false,
                  autofillHints: const [AutofillHints.email],
                  validator: Validators.email,
                  decoration: InputDecoration(labelText: 'Email', errorText: error?.fieldError('email')),
                ),
                const SizedBox(height: 16),
                PasswordField(
                  controller: _password,
                  label: 'Mật khẩu (8–100 ký tự)',
                  errorText: error?.fieldError('password'),
                  validator: Validators.newPassword,
                  autofillHints: const [AutofillHints.newPassword],
                ),
                const SizedBox(height: 16),
                PasswordField(
                  controller: _confirm,
                  label: 'Xác nhận mật khẩu',
                  errorText: error?.fieldError('confirmPassword'),
                  validator: Validators.confirm(_password),
                  autofillHints: const [AutofillHints.newPassword],
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _submit(),
                ),
                const SizedBox(height: 24),
                if (error != null && error.fieldErrors.isEmpty) ...[
                  ErrorBanner(message: error.message),
                  const SizedBox(height: 16),
                ],
                FilledButton(
                  onPressed: _busy ? null : _submit,
                  child: _busy
                      ? const SizedBox.square(dimension: 22, child: CircularProgressIndicator(strokeWidth: 2.5))
                      : const Text('Đăng ký'),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => context.canPop() ? context.pop() : context.go(AppRoutes.login),
                  child: const Text('Đã có tài khoản? Đăng nhập'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class CheckEmailArgs {
  const CheckEmailArgs(this.email, this.message);

  final String email;
  final String message;
}

/// After registering: tells the user to confirm their email, offers to resend it.
class CheckEmailScreen extends StatelessWidget {
  const CheckEmailScreen({super.key, required this.args});

  final CheckEmailArgs args;

  Future<void> _resend(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final message = await context.read<AuthRepository>().resendVerification(args.email);
      messenger.showSnackBar(SnackBar(content: Text(message)));
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Xác minh email')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Icon(RadixIcons.Envelope_Closed, size: 72, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 16),
            Text(args.message, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              'Mở liên kết trong email gửi tới ${args.email}, rồi quay lại đăng nhập.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            FilledButton(onPressed: () => context.go(AppRoutes.login), child: const Text('Đến trang đăng nhập')),
            const SizedBox(height: 8),
            TextButton(onPressed: () => _resend(context), child: const Text('Gửi lại email xác minh')),
          ],
        ),
      ),
    );
  }
}
