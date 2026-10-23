import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/router/app_router.dart';
import '../../core/widgets/brand_logo.dart';
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

  void _fillCredentials(String email, String password) {
    setState(() {
      _email.text = email;
      _password.text = password;
      _error = null;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Đã chọn tài khoản mẫu: $email'),
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final error = _error;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: Form(
          key: _form,
          child: AutofillGroup(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
              children: [
                const SizedBox(height: 8),
                const Center(child: BrandEmblem(size: 76)),
                const SizedBox(height: 14),
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0x1F38BDF8) : const Color(0x140284C7),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: isDark ? const Color(0x3338BDF8) : const Color(0x280284C7),
                      ),
                    ),
                    child: Text(
                      'NỀN TẢNG ÔN THI THẾ HỆ MỚI',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                        color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Đăng nhập QuizMS',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Nhập thông tin hoặc chọn tài khoản mẫu để trải nghiệm',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 18),

                // One-touch Demo Quick-Fill Bar
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    ActionChip(
                      avatar: const Icon(Icons.school_outlined, size: 16),
                      label: const Text('Học sinh Test', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      onPressed: () => _fillCredentials('student@quizms.com', 'Student@123456'),
                    ),
                    ActionChip(
                      avatar: const Icon(Icons.admin_panel_settings_outlined, size: 16),
                      label: const Text('Admin Test', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      onPressed: () => _fillCredentials('admin@quizms.com', 'Admin@123456'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Elevated Glassmorphism Form Card
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xB8111827) : const Color(0xF5FFFFFF),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isDark ? const Color(0x2EBAE3FA) : const Color(0x1F0F172A),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: isDark ? Colors.black.withOpacity(0.35) : Colors.black.withOpacity(0.05),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextFormField(
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        autocorrect: false,
                        autofillHints: const [AutofillHints.email],
                        validator: Validators.email,
                        decoration: InputDecoration(
                          labelText: 'Email',
                          prefixIcon: const Icon(Icons.email_outlined, size: 20),
                          errorText: error?.fieldError('email'),
                        ),
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
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: _busy
                            ? const SizedBox.square(dimension: 22, child: CircularProgressIndicator(strokeWidth: 2.5))
                            : const Text('Đăng nhập', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      ),
                    ],
                  ),
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
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () => context.push(AppRoutes.kahoot),
                  icon: const Icon(Icons.sports_esports_outlined),
                  label: const Text('Vào phòng Kahoot (không cần tài khoản)'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 24),

                // Platform Highlights Micro-Ribbon
                Center(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: [
                      _featurePill(Icons.bolt, 'Kahoot Realtime', isDark),
                      _featurePill(Icons.layers_outlined, 'SRS Spaced', isDark),
                      _featurePill(Icons.forum_outlined, 'Chat Nhóm', isDark),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _featurePill(IconData icon, String text, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: isDark ? const Color(0x1AFFFFFF) : const Color(0x0A000000),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: isDark ? const Color(0x1FBAE3FA) : const Color(0x0F0F172A),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: isDark ? const Color(0xFFC7D3EA) : const Color(0xFF475569)),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: isDark ? const Color(0xFFC7D3EA) : const Color(0xFF475569),
            ),
          ),
        ],
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
