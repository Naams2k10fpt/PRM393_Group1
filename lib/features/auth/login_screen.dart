import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/form_widgets.dart';
import '../../data/api/api_exception.dart';
import '../../data/repositories/auth_repository.dart';
import 'auth_controller.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  ApiException? _error;

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
      // On success the router leaves this screen.
      await context.read<AuthController>().login(_email.text, _password.text);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resendVerification() async {
    await _runAndShow(() => context.read<AuthRepository>().resendVerification(_email.text));
  }

  Future<void> _forgotPassword() async {
    final email = await showDialog<String>(
      context: context,
      builder: (context) => _ForgotPasswordDialog(initialEmail: _email.text.trim()),
    );
    if (email == null || !mounted) return;
    await _runAndShow(() => context.read<AuthRepository>().forgotPassword(email));
  }

  Future<void> _runAndShow(Future<String> Function() call) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final message = await call();
      messenger.showSnackBar(SnackBar(content: Text(message)));
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final error = _error;

    return Scaffold(
      body: SafeArea(
        child: Form(
          key: _form,
          child: AutofillGroup(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
              children: [
                const Icon(Icons.school_rounded, size: 64, color: AppColors.accent),
                const SizedBox(height: 12),
                Text(
                  'Đăng nhập',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 32),
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
                  label: 'Mật khẩu',
                  errorText: error?.fieldError('password'),
                  validator: (v) => Validators.required(v, 'Mật khẩu là bắt buộc.'),
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _submit(),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(onPressed: _forgotPassword, child: const Text('Quên mật khẩu?')),
                ),
                if (error != null && error.fieldErrors.isEmpty) ...[
                  ErrorBanner(
                    message: error.message,
                    action: error.code == 'email_not_confirmed'
                        ? TextButton(
                            onPressed: _resendVerification,
                            child: const Text('Gửi lại email xác minh'),
                          )
                        : null,
                  ),
                  const SizedBox(height: 16),
                ],
                FilledButton(
                  onPressed: _busy ? null : _submit,
                  child: _busy
                      ? const SizedBox.square(dimension: 22, child: CircularProgressIndicator(strokeWidth: 2.5))
                      : const Text('Đăng nhập'),
                ),
                const SizedBox(height: 16),
                Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    const Text('Chưa có tài khoản?'),
                    TextButton(onPressed: () => context.push(AppRoutes.register), child: const Text('Đăng ký')),
                  ],
                ),
                const Divider(height: 32),
                OutlinedButton.icon(
                  onPressed: () => context.push(AppRoutes.kahoot),
                  icon: const Icon(Icons.sports_esports_outlined),
                  label: const Text('Vào phòng Kahoot (không cần tài khoản)'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ForgotPasswordDialog extends StatefulWidget {
  const _ForgotPasswordDialog({required this.initialEmail});

  final String initialEmail;

  @override
  State<_ForgotPasswordDialog> createState() => _ForgotPasswordDialogState();
}

class _ForgotPasswordDialogState extends State<_ForgotPasswordDialog> {
  final _form = GlobalKey<FormState>();
  late final _email = TextEditingController(text: widget.initialEmail);

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  void _send() {
    if (_form.currentState!.validate()) Navigator.pop(context, _email.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Quên mật khẩu'),
      content: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Nhập email tài khoản. Bạn sẽ nhận liên kết đặt lại mật khẩu (mở trên trình duyệt).'),
            const SizedBox(height: 16),
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              validator: Validators.email,
              onFieldSubmitted: (_) => _send(),
              decoration: const InputDecoration(labelText: 'Email'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Hủy')),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
          onPressed: _send,
          child: const Text('Gửi'),
        ),
      ],
    );
  }
}
