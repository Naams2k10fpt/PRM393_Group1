import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/config/app_config.dart';
import '../../data/repositories/catalog_repository.dart';

class CatalogFavorites extends ChangeNotifier {
  CatalogFavorites(this._repository, this._accountId, this._kind);

  final CatalogRepository _repository;
  final String _accountId;
  final FavoriteKind _kind;
  final String _backend = AppConfig.baseUrl;
  Set<String> _ids = {};
  Future<void>? _restoring;
  bool _loaded = false;
  bool _writing = false;
  bool _disposed = false;

  String _legacyKey(FavoriteKind kind) =>
      'catalog.favorites.v1.${jsonEncode([_backend, _accountId, kind.name])}';

  bool contains(String id) => _ids.contains(id);

  List<T> ordered<T>(List<T> items, String Function(T) idOf) => [
    ...items.where((item) => contains(idOf(item))),
    ...items.where((item) => !contains(idOf(item))),
  ];

  Future<void> restore() async {
    if (_writing) return;
    try {
      await _reload();
    } catch (_) {
      // Keep the last visible stars. Refreshing or tapping a star can retry.
    }
  }

  Future<void> _reload() =>
      _restoring ??= _load().whenComplete(() => _restoring = null);

  Future<void> _load() async {
    SharedPreferences? prefs;
    try {
      prefs = await SharedPreferences.getInstance();
    } catch (_) {
      // Account favorites can still load without local storage.
    }
    if (_disposed) return;
    if (prefs != null) await _importLegacy(prefs);
    if (_disposed) return;

    final ids = await _repository.favoriteIds(_kind);
    _loaded = true;
    _publish(ids);
  }

  Future<void> _importLegacy(SharedPreferences prefs) async {
    final legacyIds = prefs.getStringList(_legacyKey(_kind));
    if (!_loaded && legacyIds != null) _publish(legacyIds.toSet());

    // Import both lists so a user only has to open the upgraded app once.
    await Future.wait(
      FavoriteKind.values.map((kind) async {
        final key = _legacyKey(kind);
        final ids = prefs.getStringList(key);
        if (ids == null || ids.isEmpty) return;
        await _repository.importFavorites(_accountId, kind, ids);
        try {
          await prefs.remove(key);
        } catch (_) {
          // The server can safely accept the same import again.
        }
      }),
    );
  }

  Future<void> toggle(String id) async {
    if (_writing) return;
    _writing = true;
    final favorite = !contains(id);
    try {
      if (!_loaded || _restoring != null) await _reload();
      if (_disposed) return;
      await _repository.setFavorite(_accountId, _kind, id, favorite);
      final next = _ids.toSet();
      favorite ? next.add(id) : next.remove(id);
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
    return Padding(
      padding: const EdgeInsets.all(6),
      child: IconButton(
        style: IconButton.styleFrom(
          iconSize: 24,
          minimumSize: const Size.square(24),
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
      ),
    );
  }
}
