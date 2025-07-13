import 'dart:async';

import 'package:collection/collection.dart';

import 'chunk_state_manager.dart';
import 'placeholder_resolver.dart';
import 'processor.dart';
import 'state.dart';
import 'chunk_field.dart';

/// A high-level abstraction for managing progressive JSON data with typed object deserialization.
///
/// ChunkObject provides a sophisticated interface for handling complex JSON structures
/// that load progressively through chunks. It combines the power of placeholder resolution
/// with type-safe deserialization, caching, and comprehensive state management.
///
/// ## Key Features
/// - **Type-Safe Deserialization**: Generic type parameter ensures compile-time type safety
/// - **Progressive Loading**: Handles JSON with placeholders that resolve over time
/// - **Intelligent Caching**: Automatic cache invalidation and result caching
/// - **ChunkField Integration**: Supports typed field access with custom deserializers
/// - **Stream-Based Updates**: Multiple stream interfaces for different update patterns
/// - **State Management**: Comprehensive tracking of chunk loading states
/// - **Error Handling**: Robust error handling with fallback mechanisms
/// - **Resource Management**: Proper cleanup and disposal patterns
///
/// ## Architecture
/// ChunkObject orchestrates several components:
/// ```
/// ChunkObject<T>
/// ├── ChunkStateManager (state tracking)
/// ├── ChunkProcessor (data processing)
/// ├── PlaceholderResolver (placeholder resolution)
/// ├── ChunkField Map (typed field access)
/// └── Deserializer Function (JSON → T conversion)
/// ```
///
/// ## Usage Patterns
///
/// ### Basic Usage
/// ```dart
/// // Define your data model
/// class User {
///   final String name;
///   final int age;
///   final String email;
///
///   User({required this.name, required this.age, required this.email});
///
///   factory User.fromJson(Map<String, dynamic> json) => User(
///     name: json['name'],
///     age: json['age'],
///     email: json['email'],
///   );
/// }
///
/// // Create chunk object from JSON with placeholders
/// final json = {
///   'name': '$123',
///   'age': 30,
///   'email': '$456'
/// };
///
/// final userObject = ChunkObject.fromJson(json, User.fromJson);
///
/// // Process incoming chunks
/// userObject.processChunk({'123': 'John Doe'});
/// userObject.processChunk({'456': 'john@example.com'});
///
/// // Get typed data
/// final user = userObject.getData(); // User instance
/// ```
///
/// ### With ChunkFields
/// ```dart
/// final nameField = ChunkField.string('123');
/// final emailField = ChunkField.string('456');
///
/// final userObject = ChunkObject.fromJson(
///   json,
///   User.fromJson,
///   chunkFields: {
///     'name': nameField,
///     'email': emailField,
///   },
/// );
///
/// // Access typed fields
/// final name = await nameField.future;
/// final email = await emailField.future;
/// ```
///
/// ### Stream-Based Updates
/// ```dart
/// // Listen for object updates
/// userObject.listenObjectUpdate((user) {
///   print('User updated: ${user.name}');
/// });
///
/// // Listen for complete resolution
/// userObject.listenObjectResolve((user) {
///   print('User fully loaded: $user');
/// });
///
/// // Listen for chunk states
/// userObject.listenChunkStates((states) {
///   print('Chunk states: $states');
/// });
/// ```
///
/// ## Stream Interfaces
/// ChunkObject provides several stream interfaces:
/// - **Raw Chunk Updates**: Raw chunk data as it arrives
/// - **Parsed Chunk Updates**: Chunks with field-specific deserialization
/// - **Object Updates**: Typed object instances on each update
/// - **Object Resolution**: Typed object only when fully resolved
/// - **State Updates**: Chunk state changes
///
/// ## Performance Considerations
/// - **Intelligent Caching**: Results are cached until invalidated
/// - **Partial Deserialization**: Attempts deserialization with partial data
/// - **Lazy Evaluation**: Streams are computed on-demand
/// - **Memory Management**: Proper resource cleanup with dispose()
///
/// ## Error Handling
/// - **Graceful Degradation**: Falls back to partial data when possible
/// - **Type Safety**: Validates deserialization results
/// - **State Tracking**: Maintains error states per chunk
/// - **Exception Safety**: Prevents crashes from invalid data
///
/// See also:
/// - [ChunkField] for typed field access
/// - [ChunkStateManager] for state management
/// - [ChunkProcessor] for data processing
/// - [PlaceholderResolver] for placeholder resolution
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

  /// Creates a ChunkObject from JSON data with optional typed chunk fields.
  ///
  /// This factory method initializes a complete ChunkObject with all necessary
  /// components for progressive JSON loading. It automatically discovers placeholders
  /// in the JSON structure and sets up the required infrastructure.
  ///
  /// ## Parameters
  /// - [json]: The initial JSON data containing placeholders
  /// - [deserializer]: Function to convert resolved JSON to type [T]
  /// - [chunkFields]: Optional map of named chunk fields for typed access
  /// - [placeholderPattern]: Optional custom RegExp pattern for matching placeholders.
  ///   If not provided, uses the default pattern `^\$(\d+)$` which matches `$<numeric_id>`.
  ///
  /// ## Type Parameters
  /// - [T]: The target type for deserialization
  ///
  /// ## Initialization Process
  /// 1. Creates internal components (resolver, state manager, processor)
  /// 2. Discovers placeholders in the JSON structure
  /// 3. Registers chunk fields if provided
  /// 4. Sets up automatic chunk update handling
  /// 5. Configures stream subscriptions
  ///
  /// ## Examples
  /// ```dart
  /// // Basic usage with default pattern
  /// final userObject = ChunkObject.fromJson(
  ///   {'name': '$123', 'age': 30},
  ///   (json) => User.fromJson(json),
  /// );
  ///
  /// // With custom pattern
  /// final userObject = ChunkObject.fromJson(
  ///   {'name': '{id:123}', 'age': 30},
  ///   (json) => User.fromJson(json),
  ///   placeholderPattern: RegExp(r'^\{id:(\d+)\}$'),
  /// );
  ///
  /// // With chunk fields
  /// final userObject = ChunkObject.fromJson(
  ///   {'name': '$123', 'email': '$456'},
  ///   User.fromJson,
  ///   chunkFields: {
  ///     'name': ChunkField.string('123'),
  ///     'email': ChunkField.string('456'),
  ///   },
  /// );
  /// ```
  ///
  /// ## ChunkField Integration
  /// When chunk fields are provided:
  /// - They're automatically registered with the state manager
  /// - Provide typed access to individual fields
  /// - Support custom deserialization per field
  /// - Enable field-specific error handling
  factory ChunkObject.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) deserializer, {
    Map<String, ChunkField>? chunkFields,
    RegExp? placeholderPattern,
  }) {
    final resolver =
        PlaceholderResolver(placeholderPattern: placeholderPattern);
    final stateManager = ChunkStateManager();
    final processor = ChunkProcessor(stateManager);

    final jsonObject = ChunkObject._(
      json,
      deserializer,
      stateManager,
      processor,
      resolver,
    );

    final placeholders = resolver.findPlaceholders(json);

    // Register chunk fields if provided
    if (chunkFields != null) {
      jsonObject._chunkFields = chunkFields
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
    processor.dataStream.listen(jsonObject._handleChunkUpdate);

    return jsonObject;
  }

  /// An unmodifiable map of all registered chunk fields.
  ///
  /// This property provides access to the typed chunk fields that were
  /// registered during initialization or added later. Each field provides
  /// type-safe access to specific parts of the JSON structure.
  ///
  /// ## Returns
  /// An unmodifiable [Map<String, ChunkField>] where:
  /// - Keys are field names/identifiers
  /// - Values are [ChunkField] instances
  ///
  /// ## Usage
  /// ```dart
  /// final fields = userObject.chunkFields;
  ///
  /// // Check if a field exists
  /// if (fields.containsKey('name')) {
  ///   final nameField = fields['name'];
  ///   print('Name field state: ${nameField.state}');
  /// }
  ///
  /// // Iterate over all fields
  /// for (final entry in fields.entries) {
  ///   print('${entry.key}: ${entry.value.state}');
  /// }
  /// ```
  ///
  /// ## Field Access
  /// - Use [getChunkField] for typed field access
  /// - Use [registerChunkField] to add new fields
  /// - Use field-specific methods for state checking
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
      _objectUpdateStream.listen(
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
  Stream<T> get _objectUpdateStream => _processor.dataStream
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
  bool _hasMinimalDataForDeserialization(Map<String, dynamic> json) =>
      json.values.any((value) => !_resolver.isPlaceholder(value));

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
