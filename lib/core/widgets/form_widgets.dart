import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../theme/app_theme.dart';

/// Password input with a show/hide toggle (same behaviour as the website's password fields).
class PasswordField extends StatefulWidget {
  const PasswordField({
    super.key,
    required this.controller,
    required this.label,
    this.errorText,
    this.validator,
    this.textInputAction = TextInputAction.next,
    this.onSubmitted,
    this.autofillHints = const [AutofillHints.password],
  });

  final TextEditingController controller;
  final String label;
  final String? errorText;
  final FormFieldValidator<String>? validator;
  final TextInputAction textInputAction;
  final ValueChanged<String>? onSubmitted;
  final Iterable<String> autofillHints;

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool _visible = false;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      obscureText: !_visible,
      autocorrect: false,
      enableSuggestions: false,
      autofillHints: widget.autofillHints,
      textInputAction: widget.textInputAction,
      onFieldSubmitted: widget.onSubmitted,
      validator: widget.validator,
      decoration: InputDecoration(
        labelText: widget.label,
        errorText: widget.errorText,
        errorMaxLines: 2,
        suffixIcon: IconButton(
          tooltip: _visible ? 'Ẩn mật khẩu' : 'Hiện mật khẩu',
          icon: Icon(_visible ? LucideIcons.eyeOff : LucideIcons.eye),
          onPressed: () => setState(() => _visible = !_visible),
        ),
      ),
    );
  }
}

/// Error box above a form's submit button, with an optional action (e.g. "resend verification email").
class ErrorBanner extends StatelessWidget {
  const ErrorBanner({super.key, required this.message, this.action});

  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.danger.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.danger.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(LucideIcons.triangleAlert, color: AppColors.danger, size: 20),
              const SizedBox(width: 8),
              Expanded(child: Text(message, semanticsLabel: 'Lỗi: $message')),
            ],
          ),
          if (action != null) Align(alignment: Alignment.centerRight, child: action),
        ],
      ),
    );
  }
}

/// Client-side checks mirroring the backend's rules, so most mistakes are caught before a request.
class Validators {
  Validators._();

  static final _email = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  static String? email(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Email là bắt buộc.';
    if (!_email.hasMatch(v)) return 'Email không hợp lệ.';
    return null;
  }

  static String? required(String? value, String message) => (value ?? '').isEmpty ? message : null;

  static String? username(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Tên người dùng là bắt buộc.';
    if (v.length < 3 || v.length > 100) return 'Tên người dùng phải từ 3 đến 100 ký tự.';
    return null;
  }

  static String? newPassword(String? value) {
    final v = value ?? '';
    if (v.isEmpty) return 'Mật khẩu là bắt buộc.';
    if (v.length < 8 || v.length > 100) return 'Mật khẩu phải có từ 8 đến 100 ký tự.';
    return null;
  }

  static FormFieldValidator<String> confirm(TextEditingController password) =>
      (value) => value != password.text ? 'Mật khẩu xác nhận không khớp.' : null;
}
