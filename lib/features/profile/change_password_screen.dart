import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/widgets/form_widgets.dart';
import '../../data/api/api_exception.dart';
import '../../data/repositories/profile_repository.dart';

/// The backend signs out every other device; this one stays signed in because the repository stores the
/// fresh token from the response.
class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _form = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _new = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;
  ApiException? _error;

  @override
  void dispose() {
    _current.dispose();
    _new.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || !_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final messenger = ScaffoldMessenger.of(context);
    try {
      await context.read<ProfileRepository>().changePassword(
            currentPassword: _current.text,
            newPassword: _new.text,
            confirmPassword: _confirm.text,
          );
      messenger.showSnackBar(
        const SnackBar(content: Text('Đổi mật khẩu thành công. Các thiết bị khác đã được đăng xuất.')),
      );
      if (mounted) context.pop();
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
      appBar: AppBar(title: const Text('Đổi mật khẩu')),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            PasswordField(
              controller: _current,
              label: 'Mật khẩu hiện tại',
              errorText: error?.fieldError('currentPassword'),
              validator: (v) => Validators.required(v, 'Mật khẩu hiện tại là bắt buộc.'),
            ),
            const SizedBox(height: 16),
            PasswordField(
              controller: _new,
              label: 'Mật khẩu mới (8–100 ký tự)',
              errorText: error?.fieldError('newPassword'),
              validator: Validators.newPassword,
              autofillHints: const [AutofillHints.newPassword],
            ),
            const SizedBox(height: 16),
            PasswordField(
              controller: _confirm,
              label: 'Xác nhận mật khẩu mới',
              errorText: error?.fieldError('confirmPassword'),
              validator: Validators.confirm(_new),
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
                  : const Text('Đổi mật khẩu'),
            ),
          ],
        ),
      ),
    );
  }
}
