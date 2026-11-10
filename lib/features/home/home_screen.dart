import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/config/app_updates.dart';
import '../../core/router/app_router.dart';
import '../../core/widgets/app_update_widgets.dart';
import '../../core/widgets/brand_logo.dart';
import '../../core/widgets/form_widgets.dart';
import '../../data/api/api_exception.dart';
import '../../data/models/subject.dart';
import '../../data/repositories/catalog_repository.dart';
import '../auth/auth_controller.dart';
import '../catalog/catalog_favorites.dart';
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
  late final _favorites = CatalogFavorites(
    context.read<AuthController>().user!.id,
    FavoriteKind.subject,
  );

  @override
  void initState() {
    super.initState();
    _favorites.restore();
    _load();
  }

  @override
  void dispose() {
    _favorites.dispose();
    super.dispose();
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
              Column(
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
              ).animate().fadeIn(duration: 350.ms).slideY(begin: 0.08, end: 0, curve: Curves.easeOutCubic),
              const SizedBox(height: 18),
            ],
            if (context.read<AppUpdates?>() != null) const AppUpdateNotice(),
            Text('Môn học', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            ..._subjectSection(),
            const SizedBox(height: 24),
            Text('Tiện ích học tập', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5),
                ),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                leading: Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(LucideIcons.bookOpen, color: Theme.of(context).colorScheme.primary, size: 22),
                ),
                title: const Text('Quiz cá nhân', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Làm bài, xem kết quả và lịch sử'),
                trailing: const Icon(LucideIcons.chevronRight),
                onTap: () => context.push(AppRoutes.quiz),
              ),
            ).animate().fadeIn(duration: 350.ms, delay: 140.ms).slideY(begin: 0.08, end: 0, curve: Curves.easeOutCubic),
            const SizedBox(height: 4),
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(
                  color: Color(0x4D663AF3),
                  width: 1.2,
                ),
              ),
              color: const Color(0x0F663AF3),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                leading: Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF663AF3), Color(0xFF8B5CF6)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(LucideIcons.gamepad2, color: Colors.white, size: 22),
                ),
                title: const Text('Kahoot Live', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('Nhập mã PIN hoặc quét QR để vào phòng'),
                trailing: const Icon(LucideIcons.chevronRight),
                onTap: () => context.push(AppRoutes.kahoot),
              ),
            ).animate().fadeIn(duration: 350.ms, delay: 80.ms).slideY(begin: 0.08, end: 0, curve: Curves.easeOutCubic),
            const SizedBox(height: 4),
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5),
                ),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                leading: Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: Colors.teal.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(LucideIcons.messageCircle, color: Colors.teal, size: 22),
                ),
                title: const Text('Nhóm học', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Tham gia và trò chuyện thời gian thực'),
                trailing: const Icon(LucideIcons.chevronRight),
                onTap: () => context.push(AppRoutes.groups),
              ),
            ).animate().fadeIn(duration: 350.ms, delay: 200.ms).slideY(begin: 0.08, end: 0, curve: Curves.easeOutCubic),
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
                  Icon(LucideIcons.archive, size: 40, color: color),
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
      ListenableBuilder(
        listenable: _favorites,
        builder: (context, _) {
          final subjects = _favorites.ordered(
            _subjects,
            (subject) => subject.id,
          );
          return GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: subjects.length,
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
              final subject = subjects[index];
              return SubjectCard(
                key: ValueKey(subject.id),
                subject: subject,
                favorite: CatalogFavoriteButton(
                  favorites: _favorites,
                  id: subject.id,
                  name: subject.name,
                ),
                index: index,
                // The name rides along so the deck list can title itself without a second request.
                onTap: () => context.push(
                  AppRoutes.decksFor(subject.id),
                  extra: subject.name,
                ),
              );
            },
          );
        },
      ),
    ];
  }
}
