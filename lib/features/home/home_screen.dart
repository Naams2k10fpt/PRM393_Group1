import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/brand_logo.dart';
import '../../core/widgets/form_widgets.dart';
import '../../data/api/api_exception.dart';
import '../../data/models/subject.dart';
import '../../data/repositories/catalog_repository.dart';
import '../auth/auth_controller.dart';
import '../profile/profile_screen.dart';
import 'widgets/subject_card.dart';

/// Landing screen: the subjects the user can study, plus the entry into a live
/// Kahoot room. Loads its own state the way the auth screens do, rather than
/// through a provider, because nothing outside this screen needs the list.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _busy = true;
  ApiException? _error;
  List<Subject> _subjects = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final catalog = context.read<CatalogRepository>();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final subjects = await catalog.subjects();
      if (!mounted) return;
      setState(() {
        _subjects = subjects;
        _busy = false;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthController>().user;

    return Scaffold(
      appBar: AppBar(
        title: const BrandLogo(size: 32, showText: true),
        actions: [
          ValueListenableBuilder<ThemeMode>(
            valueListenable: AppTheme.themeModeNotifier,
            builder: (context, mode, _) {
              final isDark = mode == ThemeMode.dark;
              return IconButton(
                tooltip: isDark ? 'Chế độ Sáng' : 'Chế độ Tối',
                icon: Icon(isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined),
                onPressed: AppTheme.toggleTheme,
              );
            },
          ),
          if (user != null)
            IconButton(
              tooltip: 'Hồ sơ',
              icon: UserAvatar(user: user, radius: 16),
              onPressed: () => context.push(AppRoutes.profile),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          // Always scrollable, so pull-to-refresh works even when the list is
          // short or an error left it empty.
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            if (user != null) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Chào ${user.username}',
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Hôm nay học gì nào?',
                          style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0x1AF59E0B),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: const Color(0x4DF59E0B)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('🔥', style: TextStyle(fontSize: 14)),
                        SizedBox(width: 4),
                        Text(
                          '5 ngày',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFF59E0B),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
            ],
            Card(
              child: ListTile(
                leading: const Icon(Icons.sports_esports_outlined, color: Color(0xFF663AF3)),
                title: const Text('Kahoot Live'),
                subtitle: const Text('Nhập mã PIN hoặc quét QR để vào phòng'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push(AppRoutes.kahoot),
              ),
            ),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.quiz_outlined),
                    title: const Text('Quiz cá nhân'),
                    subtitle: const Text('Làm bài, xem kết quả và lịch sử'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push(AppRoutes.quiz),
                  ),
                ),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.forum_outlined),
                    title: const Text('Nhóm học'),
                    subtitle: const Text('Tham gia và trò chuyện thời gian thực'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push(AppRoutes.groups),
                  ),
                ),
                const SizedBox(height: 24),
                Text('Môn học', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 12),
                ..._subjectSection(),
              ],
            ),
          ),
        );
  }

  List<Widget> _subjectSection() {
    if (_busy) {
      return const [
        Padding(
          padding: EdgeInsets.symmetric(vertical: 48),
          child: Center(child: CircularProgressIndicator()),
        ),
      ];
    }

    final error = _error;
    if (error != null) {
      return [
        ErrorBanner(
          message: error.message,
          action: TextButton(onPressed: _load, child: const Text('Thử lại')),
        ),
      ];
    }

    if (_subjects.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 48),
          child: Builder(
            builder: (context) {
              final color = Theme.of(context).colorScheme.onSurfaceVariant;
              return Column(
                children: [
                  Icon(Icons.inbox_outlined, size: 40, color: color),
                  const SizedBox(height: 12),
                  Text(
                    'Chưa có môn học nào.',
                    style: TextStyle(color: color),
                  ),
                ],
              );
            },
          ),
        ),
      ];
    }

    return [
      GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _subjects.length,
        // A fixed column count plus an aspect ratio makes every card as tall as
        // half the viewport is wide, which is fine on a phone and absurd on a
        // desktop browser. Sizing by extent keeps the card the same height
        // everywhere and simply fits more columns on a wide screen.
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 220,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          mainAxisExtent: 160,
        ),
        itemBuilder: (context, index) {
          final subject = _subjects[index];
          return SubjectCard(
            subject: subject,
            // The name rides along so the deck list can title itself without a second request.
            onTap:
                () => context.push(
                  AppRoutes.decksFor(subject.id),
                  extra: subject.name,
                ),
          );
        },
      ),
    ];
  }
}
