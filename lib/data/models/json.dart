/// Small readers the catalogue models share.
///
/// The PRN232 REST API is not deployed yet: only the web MVC app answers on the
/// Render host, `/swagger` and every `/api/*` path return 404. The exact field
/// names are therefore unconfirmed, so each reader takes a few likely spellings
/// and uses the first key that is present. Once the API is live, open
/// `<backend>/swagger` and cut each list down to the real name.
class Json {
  Json._();

  static Object? _first(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      final value = json[key];
      if (value != null) return value;
    }
    return null;
  }

  /// Ids arrive as an int (EF Core identity) or a String (GUID). Routes and
  /// widget keys want a String either way, so every model exposes one.
  static String id(Map<String, dynamic> json, [List<String> keys = const ['id']]) =>
      _first(json, keys)?.toString() ?? '';

  static String string(Map<String, dynamic> json, List<String> keys, {String fallback = ''}) {
    final value = _first(json, keys);
    if (value == null) return fallback;
    return value is String ? value : value.toString();
  }

  /// Empty strings come back as null, so the UI can treat "missing" as one case.
  static String? stringOrNull(Map<String, dynamic> json, List<String> keys) {
    final value = _first(json, keys);
    if (value == null) return null;
    final text = value is String ? value : value.toString();
    return text.trim().isEmpty ? null : text;
  }

  static int integer(Map<String, dynamic> json, List<String> keys, {int fallback = 0}) {
    final value = _first(json, keys);
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? fallback;
    return fallback;
  }

  static bool boolean(Map<String, dynamic> json, List<String> keys, {bool fallback = false}) {
    final value = _first(json, keys);
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) return value.toLowerCase() == 'true';
    return fallback;
  }

  /// A list endpoint may answer with a bare array or wrap it in a paging envelope
  /// (`{ items: [...], total: 42 }`). Both shapes end up as a list of objects here.
  static List<Map<String, dynamic>> objects(
    Object? body, [
    List<String> wrapperKeys = const ['items', 'data', 'results', 'value'],
  ]) {
    if (body is List) {
      return body.whereType<Map<String, dynamic>>().toList();
    }
    if (body is Map<String, dynamic>) {
      final inner = _first(body, wrapperKeys);
      if (inner is List) return inner.whereType<Map<String, dynamic>>().toList();
    }
    return const [];
  }
}
