import 'dart:async';

import 'package:chunk_norris/src/chunk_state_manager.dart';
import 'package:chunk_norris/src/placeholder_resolver.dart';
import 'package:chunk_norris/src/processor.dart';
import 'package:chunk_norris/src/state.dart';

/// ChunkJson is the main class for progressive JSON hydration using chunked data.
///
/// It allows you to initialize with a JSON containing placeholders (e.g., "\$1", "\$2"),
/// and then incrementally resolve those placeholders as data chunks arrive.
///
/// - Use [ChunkJson.fromJson] to create an instance from your initial JSON.
/// - Use [processChunk] to provide new data chunks and resolve placeholders.
/// - Use [getValue] to access values with automatic placeholder resolution.
/// - Use [getResolvedData] to get the fully resolved JSON (if all placeholders are filled).
/// - Use [updateStream] to listen for updates when new chunks are processed.
/// - Use [errorStream] to listen for errors during chunk processing.
/// - Use [processChunkStream] to process a stream of chunked data (e.g., from SSE).
/// - Use [waitForAllChunks] to await until all placeholders are resolved.
/// - Call [dispose] to clean up resources when done.
///
/// Example usage:
/// ```dart
/// final chunkJson = ChunkJson.fromJson(initialJson);
/// chunkJson.processChunk({'1': 'data'});
/// final resolved = chunkJson.getResolvedData();
/// chunkJson.dispose();
/// ```
final class ChunkJson {
  final Map<String, dynamic> _json;
  final ChunkStateManager _stateManager;
  final ChunkProcessor _processor;
  final PlaceholderResolver _resolver;

  ChunkJson._(
    this._json,
    this._stateManager,
    this._processor,
    this._resolver,
  );

  /// Create a ChunkJson instance from an initial JSON.
  factory ChunkJson.fromJson(Map<String, dynamic> json) {
    const resolver = PlaceholderResolver();
    final stateManager = ChunkStateManager();
    final processor = ChunkProcessor(stateManager);
    final chunkJson = ChunkJson._(
      json,
      stateManager,
      processor,
      resolver,
    );

    // Find all placeholders and register them
    final placeholders = resolver.findPlaceholders(json);
    for (final placeholder in placeholders) {
      stateManager.registerPlaceholder(placeholder);
    }

    return chunkJson;
  }

  /// Get the original JSON.
  Map<String, dynamic> get json => _json;

  /// Get a value with automatic placeholder resolution.
  dynamic getValue(String key) {
    final value = _json[key];
    final resolved = _resolver.resolvePlaceholders(value, _stateManager);

    // Ensure correct type for Map
    if (resolved is Map && resolved is! Map<String, dynamic>) {
      return Map<String, dynamic>.from(resolved);
    }

    return resolved;
  }

  /// Get a Future for waiting for a value to load.
  Future<dynamic> getValueAsync(String key) async {
    final value = _json[key];

    if (_resolver.isPlaceholder(value)) {
      final id = _resolver.extractPlaceholderId(value);
      if (id != null) {
        return _stateManager.getChunkFuture(id);
      }
    }

    return value;
  }

  /// Get the loading state for a key.
  ChunkState getKeyState(String key) {
    final value = _json[key];

    if (_resolver.isPlaceholder(value)) {
      final id = _resolver.extractPlaceholderId(value);
      if (id != null) {
        return _stateManager.getChunkState(id);
      }
    }

    return ChunkState.loaded;
  }

  /// Get the fully resolved data.
  Map<String, dynamic> getResolvedData() {
    final resolved = _resolver.resolvePlaceholders(_json, _stateManager);

    if (resolved is Map<String, dynamic>) {
      return resolved;
    } else if (resolved is Map) {
      return Map<String, dynamic>.from(resolved);
    } else {
      return <String, dynamic>{};
    }
  }

  /// Wait for all chunks to load.
  Future<Map<String, dynamic>> waitForAllChunks() async {
    final placeholders = _resolver.findPlaceholders(_json);

    if (placeholders.isEmpty) {
      return _json;
    }

    // Wait for all placeholders to load
    final futures = placeholders.map((id) => _stateManager.getChunkFuture(id));
    await Future.wait(futures);

    return getResolvedData();
  }

  /// Get the stream of data updates.
  Stream<Map<String, dynamic>> get updateStream => _processor.dataStream;

  /// Get the stream of errors.
  Stream<String> get errorStream => _processor.errorStream;

  /// Process an incoming chunk of data.
  void processChunk(Map<String, dynamic> chunk) =>
      _processor.processChunk(chunk);

  /// Process a stream of chunks.
  void processChunkStream(Stream<String> chunkStream) =>
      _processor.processChunkStream(chunkStream);

  /// Clear all states.
  void clear() => _stateManager.clear();

  /// Dispose of the ChunkJson instance.
  void dispose() {
    _processor.close();
    _stateManager.clear();
  }

  /// Поддержка [] оператора для доступа к значениям
  dynamic operator [](String key) => getValue(key);

  /// Поддержка []= оператора для установки значений
  void operator []=(String key, dynamic value) {
    _json[key] = value;
  }

  /// Поддержка containsKey
  bool containsKey(String key) => _json.containsKey(key);

  /// Получить все ключи
  Iterable<String> get keys => _json.keys;

  /// Получить все значения (разрешенные)
  Iterable<dynamic> get values => _json.keys.map((key) => getValue(key));

  /// Проверить, пуст ли JSON
  bool get isEmpty => _json.isEmpty;

  /// Проверить, не пуст ли JSON
  bool get isNotEmpty => _json.isNotEmpty;

  /// Получить количество ключей
  int get length => _json.length;

  /// Проверить, разрешены ли все чанки
  bool get allChunksResolved {
    final placeholders = _resolver.findPlaceholders(_json);

    if (placeholders.isEmpty) {
      return true;
    }

    return placeholders
        .every((id) => _stateManager.getChunkState(id) == ChunkState.loaded);
  }

  @override
  String toString() => getResolvedData().toString();
}
