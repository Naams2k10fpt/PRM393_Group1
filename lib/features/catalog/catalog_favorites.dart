import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/config/app_config.dart';

enum FavoriteKind { subject, deck }

class CatalogFavorites extends ChangeNotifier {
  CatalogFavorites(String userId, FavoriteKind kind)
    : _key =
          'catalog.favorites.v1.${jsonEncode([AppConfig.baseUrl, userId, kind.name])}';

  final String _key;
  Set<String> _ids = {};
  bool _writing = false;
  bool _disposed = false;

  bool contains(String id) => _ids.contains(id);

  List<T> ordered<T>(List<T> items, String Function(T) idOf) => [
    ...items.where((item) => contains(idOf(item))),
    ...items.where((item) => !contains(idOf(item))),
  ];

  Future<void> restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _publish(prefs.getStringList(_key)?.toSet() ?? {});
    } catch (_) {
      // The catalog remains usable if local preferences are unavailable.
    }
  }

  Future<void> toggle(String id) async {
    if (_writing) return;
    _writing = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final next = prefs.getStringList(_key)?.toSet() ?? <String>{};
      if (!next.remove(id)) next.add(id);
      try {
        if (!await prefs.setStringList(_key, next.toList())) {
          throw StateError('Could not save favorites');
        }
      } catch (_) {
        await prefs.reload();
        rethrow;
      }
      _publish(next);
    } finally {
      _writing = false;
    }
  }

  void _publish(Set<String> ids) {
    if (_disposed) return;
    _ids = ids;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

class CatalogFavoriteButton extends StatelessWidget {
  const CatalogFavoriteButton({
    super.key,
    required this.favorites,
    required this.id,
    required this.name,
  });

  final CatalogFavorites favorites;
  final String id;
  final String name;

  @override
  Widget build(BuildContext context) {
    final selected = favorites.contains(id);
    final theme = Theme.of(context);
    return IconButton(
      style: IconButton.styleFrom(
        minimumSize: const Size.square(36),
        padding: EdgeInsets.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      tooltip: selected ? 'Bỏ yêu thích: $name' : 'Yêu thích: $name',
      isSelected: selected,
      icon: Icon(
        Icons.star_border_rounded,
        color: theme.colorScheme.onSurfaceVariant,
      ),
      selectedIcon: Icon(
        Icons.star_rounded,
        color: theme.brightness == Brightness.dark
            ? Colors.amber
            : const Color(0xFF965600),
      ),
      onPressed: () async {
        try {
          await favorites.toggle(id);
        } catch (_) {
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Chưa lưu được yêu thích. Hãy thử lại.'),
            ),
          );
        }
      },
    );
  }
}
