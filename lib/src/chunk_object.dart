import 'dart:async';

import 'package:collection/collection.dart';

import 'chunk_state_manager.dart';
import 'placeholder_resolver.dart';
import 'processor.dart';
import 'state.dart';
import 'chunk_field.dart';

final class ChunkObject<T> {
  final Map<String, dynamic> _initialJson;
  final T Function(Map<String, dynamic>) _deserializer;
  final ChunkStateManager _stateManager;
  final ChunkProcessor _processor;
  final PlaceholderResolver _resolver;
  late final Map<String, ChunkField> _chunkFields;

  T? _cachedResult;
  bool _isCacheValid = false;

  ChunkObject._(
    this._initialJson,
    this._deserializer,
    this._stateManager,
    this._processor,
    this._resolver,
  );

  factory ChunkObject.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) deserializer, {
    Map<String, ChunkField>? chunkFields,
  }) {
    final resolver = PlaceholderResolver();
    final stateManager = ChunkStateManager();
    final processor = ChunkProcessor(stateManager);

    final typedJson = ChunkObject._(
      json,
      deserializer,
      stateManager,
      processor,
      resolver,
    );

    final placeholders = resolver.findPlaceholders(json);

    // Register chunk fields if provided
    if (chunkFields != null) {
      typedJson._chunkFields = chunkFields
        ..forEach((key, value) {
          stateManager.registerPlaceholder(value.placeholderId);
          placeholders.remove(value.placeholderId);
        });
      for (final placeholderId in placeholders) {
        stateManager.registerPlaceholder(placeholderId);
      }
    } else {
      for (final placeholderId in placeholders) {
        stateManager.registerPlaceholder(placeholderId);
      }
    }

    // Subscribe to processor updates
    processor.dataStream.listen(typedJson._handleChunkUpdate);

    return typedJson;
  }

  /// Original JSON
  Map<String, dynamic> get initialJson => _initialJson;

  /// Registered chunk fields
  Map<String, ChunkField> get chunkFields => Map.unmodifiable(_chunkFields);

  /// Stream of chunks with preliminary parsing: if there is a ChunkField with deserializer for the key, then parses the value
  Stream<dynamic> get _chunkUpdateStream => _processor.dataStream.map((chunk) {
        dynamic result;
        chunk.forEach((key, value) {
          final field = _chunkFields.values.firstWhereOrNull(
            (f) => f.placeholderId == key,
          );

          if (field != null) {
            if (field.isResolved) {
              result = field.value;
              return;
            }

            try {
              result = field.deserializer!.call(value);
            } catch (e) {
              result = value; // fallback
            }
          } else {
            result = value;
          }
        });
        return result;
      });

  StreamSubscription<dynamic> listenChunkUpdate(
    void Function(dynamic) onData, {
    Function(Object)? onError,
    void Function()? onDone,
  }) =>
      _chunkUpdateStream.listen(
        onData,
        onError: onError,
        onDone: onDone,
      );

  StreamSubscription<T> listenObjectResolve(
    void Function(T) onData, {
    Function(Object)? onError,
    void Function()? onDone,
  }) =>
      _fullyResolvedStream.listen(
        onData,
        onError: onError,
        onDone: onDone,
      );

  StreamSubscription<dynamic> listenRawChunkUpdate(
    void Function(dynamic) onData, {
    Function(Object)? onError,
    void Function()? onDone,
  }) =>
      _processor.dataStream.listen(
        onData,
        onError: onError,
        onDone: onDone,
      );

  StreamSubscription<T> listenObjectUpdate(
    void Function(T) onData, {
    Function(Object)? onError,
    void Function()? onDone,
  }) =>
      _typedUpdateStream.listen(
        onData,
        onError: onError,
        onDone: onDone,
      );

  StreamSubscription<Map<String, ChunkState>> listenChunkStates(
    void Function(Map<String, ChunkState>) onData, {
    Function(Object)? onError,
    void Function()? onDone,
  }) =>
      _chunkStatesStream.listen(
        onData,
        onError: onError,
        onDone: onDone,
      );

  /// Stream of typed data updates
  /// Emits events on each chunk update
  Stream<T> get _typedUpdateStream => _processor.dataStream
      .map((_) => getDataOrNull())
      .where((data) => data != null)
      .cast<T>();

  /// Stream that emits only when ALL chunks are resolved
  Stream<T> get _fullyResolvedStream => _processor.dataStream
      .skipWhile((_) => !allChunksResolved)
      .map((_) => getData());

  /// Stream of chunk states
  Stream<Map<String, ChunkState>> get _chunkStatesStream =>
      _processor.dataStream.map((_) => _getChunkStates());

  /// Checks if all chunks are resolved
  bool get allChunksResolved {
    final states = _getChunkStates();
    return states.values.every((state) => state == ChunkState.loaded);
  }

  /// Registers chunk field for typed access
  void registerChunkField(String key, ChunkField field) {
    _chunkFields[key] = field;
    _stateManager.registerPlaceholder(field.placeholderId);
    _invalidateCache();
  }

  /// Gets chunk field by key
  ChunkField<V> getChunkField<V>(String key) {
    final field = _chunkFields[key];
    if (field is ChunkField<V>) {
      return field;
    }
    throw StateError('Chunk field $key not found');
  }

  /// Processes incoming chunk data
  void processChunk(Map<String, dynamic> chunk) =>
      _processor.processChunk(chunk);

  /// Processes chunk stream
  void processChunkStream(Stream<String> chunkStream) =>
      _processor.processChunkStream(chunkStream);

  /// Gets typed data (throws if not all chunks are loaded)
  T getData() {
    if (_isCacheValid && _cachedResult != null) {
      return _cachedResult!;
    }

    final resolvedJson = _getResolvedJson();
    try {
      final result = _deserializer(resolvedJson);
      _cachedResult = result;
      _isCacheValid = true;
      return result;
    } catch (error) {
      throw StateError('Failed to deserialize data: $error');
    }
  }

  /// Gets typed data or null if not ready
  T? getDataOrNull() {
    try {
      // Check if we can deserialize with current data
      final resolvedJson = _getResolvedJson();

      // Check if there are unresolved placeholders
      final hasUnresolvedPlaceholders =
          _resolver.findPlaceholders(resolvedJson).isNotEmpty;

      // If there are unresolved placeholders, try partial deserialization
      if (hasUnresolvedPlaceholders) {
        // Check if there are at least basic fields for deserialization
        if (!_hasMinimalDataForDeserialization(resolvedJson)) {
          return null;
        }
      }

      final result = _deserializer(resolvedJson);

      // Update cache only if all chunks are resolved
      if (!hasUnresolvedPlaceholders) {
        _cachedResult = result;
        _isCacheValid = true;
      }

      return result;
    } catch (_) {
      return null;
    }
  }

  /// Checks if there are minimal data for deserialization
  bool _hasMinimalDataForDeserialization(Map<String, dynamic> json) {
    // Check that main fields (not placeholders) are present
    // This helps avoid deserialization with critically important placeholders
    return json.values.any((value) => !_resolver.isPlaceholder(value));
  }

  /// Gets a map of all chunk states
  Map<String, ChunkState> _getChunkStates() {
    final states = <String, ChunkState>{};

    // States from registered fields
    for (final entry in _chunkFields.entries) {
      states[entry.key] = entry.value.state;
    }

    // States from placeholder resolver (fallback)
    final placeholders = _resolver.findPlaceholders(_initialJson);
    for (final placeholderId in placeholders) {
      final state = _stateManager.getChunkState(placeholderId);
      states[placeholderId] = state;
    }

    return states;
  }

  /// Awaits all chunks to load and returns typed data
  Future<T> waitForData() async {
    if (allChunksResolved) {
      return getData();
    }

    // Wait for all chunk fields
    if (_chunkFields.isNotEmpty) {
      await Future.wait(_chunkFields.values.map((field) => field.future));
    } else {
      // Fallback to regular waiting
      final placeholders = _resolver.findPlaceholders(_initialJson);
      final futures =
          placeholders.map((id) => _stateManager.getChunkFuture(id));
      await Future.wait(futures);
    }

    return getData();
  }

  /// Checks if a specific field is ready
  bool isFieldReady(String fieldKey) {
    final field = _chunkFields[fieldKey];
    return field?.isResolved ?? false;
  }

  /// Gets the state of a specific field
  ChunkState getFieldState(String fieldKey) {
    final field = _chunkFields[fieldKey];
    return field?.state ?? ChunkState.pending;
  }

  /// Gets field error (if any)
  Object? getFieldError(String fieldKey) {
    final field = _chunkFields[fieldKey];
    return field?.error;
  }

  /// Resets all states
  void clear() {
    _stateManager.clear();
    for (final field in _chunkFields.values) {
      field.reset();
    }
    _invalidateCache();
  }

  /// Releases resources
  void dispose() {
    _processor.close();
    _stateManager.clear();
    _chunkFields.clear();
  }

  /// Handles chunk update
  void _handleChunkUpdate(Map<String, dynamic> chunk) {
    _invalidateCache();

    // Обновляем соответствующие чанк поля
    for (final entry in chunk.entries) {
      final field = _chunkFields.values
          .where((f) => f.placeholderId == entry.key)
          .firstOrNull;

      if (field != null && !field.isResolved) {
        field.resolve(entry.value);
      } else {
        // If field was not explicitly created, just update stateManager
        _stateManager.resolvePlaceholder(entry.key, entry.value);
      }
    }
  }

  /// Gets resolved JSON
  Map<String, dynamic> _getResolvedJson() {
    final resolved = _resolver.resolvePlaceholders(_initialJson, _stateManager);

    if (resolved is Map<String, dynamic>) {
      return resolved;
    } else if (resolved is Map) {
      return Map<String, dynamic>.from(resolved);
    } else {
      throw StateError('Resolved data is not a Map');
    }
  }

  /// Invalidates cache
  void _invalidateCache() {
    _isCacheValid = false;
    _cachedResult = null;
  }

  @override
  String toString() {
    if (allChunksResolved) {
      return 'ChunkObject<$T>(resolved: ${getData()})';
    } else {
      final pendingFields = _chunkFields.entries
          .where((entry) => !entry.value.isResolved)
          .map((entry) => entry.key)
          .toList();
      return 'ChunkObject<$T>(pending: $pendingFields)';
    }
  }
}
