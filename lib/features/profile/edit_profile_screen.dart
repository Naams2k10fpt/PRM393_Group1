import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/widgets/form_widgets.dart';
import '../../data/api/api_exception.dart';
import '../../data/repositories/profile_repository.dart';
import '../auth/auth_controller.dart';

/// Username and avatar URL. Email cannot be changed (same as the website).
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _username;
  late final TextEditingController _avatarUrl;
  bool _busy = false;
  ApiException? _error;

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthController>().user;
    _username = TextEditingController(text: user?.username);
    _avatarUrl = TextEditingController(text: user?.avatarUrl);
  }

  @override
  void dispose() {
    _username.dispose();
    _avatarUrl.dispose();
    super.dispose();
  }

  static String? _validateUrl(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return null;
    if (v.length > 500) return 'URL avatar không được vượt quá 500 ký tự.';
    final uri = Uri.tryParse(v);
    return uri != null && uri.hasScheme && (uri.scheme == 'http' || uri.scheme == 'https') && uri.host.isNotEmpty
        ? null
        : 'URL avatar không hợp lệ.';
  }

  Future<void> _save() async {
    if (_busy || !_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final auth = context.read<AuthController>();
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    try {
      final user = await context
          .read<ProfileRepository>()
          .updateProfile(username: _username.text, avatarUrl: _avatarUrl.text);
      auth.updateUser(user);
      router.pop();
      messenger.showSnackBar(const SnackBar(content: Text('Đã cập nhật hồ sơ.')));
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
      appBar: AppBar(title: const Text('Sửa hồ sơ')),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            TextFormField(
              controller: _username,
              textInputAction: TextInputAction.next,
              autocorrect: false,
              validator: Validators.username,
              decoration: InputDecoration(labelText: 'Tên người dùng', errorText: error?.fieldError('username')),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _avatarUrl,
              keyboardType: TextInputType.url,
              textInputAction: TextInputAction.done,
              autocorrect: false,
              validator: _validateUrl,
              onFieldSubmitted: (_) => _save(),
              decoration: InputDecoration(
                labelText: 'URL ảnh đại diện (không bắt buộc)',
                hintText: 'https://…',
                errorText: error?.fieldError('avatarUrl'),
              ),
            ),
            const SizedBox(height: 24),
            if (error != null && error.fieldErrors.isEmpty) ...[
              ErrorBanner(message: error.message),
              const SizedBox(height: 16),
            ],
            FilledButton(
              onPressed: _busy ? null : _save,
              child: _busy
                  ? const SizedBox.square(dimension: 22, child: CircularProgressIndicator(strokeWidth: 2.5))
                  : const Text('Lưu'),
            ),
          ],
        ),
      ),
    );
  }
}
