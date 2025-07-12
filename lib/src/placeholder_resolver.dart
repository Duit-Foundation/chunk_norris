import 'package:chunk_norris/src/chunk_state_manager.dart';

final class PlaceholderResolver {
  const PlaceholderResolver();

  static final RegExp _placeholderRegex = RegExp(r'^\$(\d+)$');

  bool isPlaceholder(dynamic value) =>
      value is String && _placeholderRegex.hasMatch(value);

  String? extractPlaceholderId(dynamic value) {
    if (!isPlaceholder(value)) return null;
    final match = _placeholderRegex.firstMatch(value as String);
    return match?.group(1);
  }

  Set<String> findPlaceholders(dynamic data) {
    final Set<String> placeholders = {};

    void traverse(dynamic value) {
      if (isPlaceholder(value)) {
        final id = extractPlaceholderId(value);
        if (id != null) placeholders.add(id);
      } else if (value is Map) {
        value.values.forEach(traverse);
      } else if (value is List) {
        value.forEach(traverse);
      }
    }

    traverse(data);
    return placeholders;
  }

  dynamic resolvePlaceholders(
    dynamic data,
    ChunkStateManager stateManager,
  ) {
    if (isPlaceholder(data)) {
      final id = extractPlaceholderId(data);
      if (id != null && stateManager.isResolved(id)) {
        return stateManager.getResolvedData(id);
      }
      return data;
    } else if (data is Map<String, dynamic>) {
      return data.map((key, value) =>
          MapEntry(key, resolvePlaceholders(value, stateManager)));
    } else if (data is Map) {
      return Map<String, dynamic>.from(data).map((key, value) =>
          MapEntry(key, resolvePlaceholders(value, stateManager)));
    } else if (data is List) {
      return data
          .map((item) => resolvePlaceholders(item, stateManager))
          .toList();
    }
    return data;
  }
}
