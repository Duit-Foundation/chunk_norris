import 'dart:async';

import 'package:chunk_norris/src/chunk_state_manager.dart';
import 'package:chunk_norris/src/placeholder_resolver.dart';
import 'package:chunk_norris/src/chunk_processor.dart';
import 'package:chunk_norris/src/state.dart';

/// A lightweight wrapper for progressive JSON hydration using chunked data loading.
///
/// ChunkJson provides a simple yet powerful interface for working with JSON structures
/// that contain placeholders which are resolved progressively as data chunks arrive.
/// It's designed for scenarios where you need direct access to JSON data without
/// the overhead of typed object deserialization.
///
/// ## Key Features
/// - **Progressive Resolution**: Handles JSON with placeholders that resolve over time
/// - **Direct JSON Access**: Map-like interface for immediate JSON data access
/// - **Flexible Value Access**: Supports both synchronous and asynchronous value retrieval
/// - **State Tracking**: Monitors loading states of individual placeholders
/// - **Stream Processing**: Processes streams of chunk data from various sources
/// - **Memory Efficient**: Minimal overhead compared to full object deserialization
/// - **Easy Integration**: Simple API that mimics standard Map operations
///
/// ## Architecture
/// ChunkJson coordinates these components:
/// ```
/// ChunkJson
/// ├── ChunkStateManager (placeholder state tracking)
/// ├── ChunkProcessor (incoming data processing)
/// ├── PlaceholderResolver (placeholder resolution logic)
/// └── JSON Map (raw data storage)
/// ```
///
/// ## Usage Patterns
///
/// ### Basic Progressive Loading
/// ```dart
/// // Initial JSON with placeholders
/// final json = {
///   'title': 'Article Title',
///   'content': '$123',
///   'author': '$456',
///   'metadata': {
///     'views': '$789',
///     'likes': 42
///   }
/// };
///
/// final chunkJson = ChunkJson.fromJson(json);
///
/// // Process chunks as they arrive
/// await chunkJson.processChunk({'123': 'This is the article content...'});
/// await chunkJson.processChunk({'456': 'John Doe'});
/// await chunkJson.processChunk({'789': 1500});
///
/// // Access resolved values
/// final title = chunkJson['title'];        // 'Article Title'
/// final content = chunkJson['content'];    // 'This is the article content...'
/// final author = chunkJson['author'];      // 'John Doe'
/// ```
///
/// ### Asynchronous Value Access
/// ```dart
/// final chunkJson = ChunkJson.fromJson(json);
///
/// // Wait for specific values
/// final content = await chunkJson.getValueAsync('content');
/// final author = await chunkJson.getValueAsync('author');
///
/// // Check loading states
/// if (chunkJson.getKeyState('content') == ChunkState.loaded) {
///   print('Content is ready: ${chunkJson['content']}');
/// }
/// ```
///
/// ### Stream Processing
/// ```dart
/// final chunkJson = ChunkJson.fromJson(json);
///
/// // Process stream of chunk data (e.g., from SSE)
/// chunkJson.processChunkStream(serverSentEventStream);
///
/// // Listen for updates
/// chunkJson.listenUpdateStream((chunk) {
///   print('New chunk received: $chunk');
/// });
///
/// // Wait for complete resolution
/// final resolvedData = await chunkJson.waitForAllChunks();
/// print('All data loaded: $resolvedData');
/// ```
///
/// ### Map-like Operations
/// ```dart
/// final chunkJson = ChunkJson.fromJson(json);
///
/// // Standard Map operations
/// chunkJson['newKey'] = 'newValue';
/// print(chunkJson.keys);
/// print(chunkJson.values);
/// print(chunkJson.length);
///
/// if (chunkJson.containsKey('author')) {
///   print('Author: ${chunkJson['author']}');
/// }
/// ```
///
/// ## Comparison with ChunkObject
/// - **ChunkJson**: Lightweight, direct JSON access, no deserialization overhead
/// - **ChunkObject**: Type-safe, object deserialization, more structured approach
/// - Choose ChunkJson for simple JSON manipulation
/// - Choose ChunkObject for complex typed objects
///
/// ## Performance Characteristics
/// - **Low Memory Overhead**: Minimal wrapper around JSON data
/// - **Fast Access**: Direct map-like operations
/// - **Lazy Resolution**: Placeholders resolved on-demand
/// - **Efficient Streaming**: Optimized for continuous data processing
///
/// ## Error Handling
/// - **Graceful Degradation**: Returns placeholders when data not available
/// - **State Tracking**: Monitors success/failure of individual chunks
/// - **Non-blocking**: Operations don't block on missing data
/// - **Resource Safety**: Proper cleanup with dispose()
///
/// ## Thread Safety
/// ChunkJson is designed to be thread-safe for concurrent chunk processing
/// while maintaining consistency in placeholder resolution.
///
/// See also:
/// - [ChunkObject] for typed object deserialization
/// - [ChunkStateManager] for state management
/// - [PlaceholderResolver] for placeholder resolution
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

  /// Creates a ChunkJson instance from initial JSON data.
  ///
  /// This factory method initializes a ChunkJson with all necessary components
  /// for progressive JSON loading. It automatically discovers and registers
  /// all placeholders found in the JSON structure.
  ///
  /// ## Parameters
  /// - [json]: The initial JSON data containing placeholders
  /// - [placeholderPattern]: Optional custom RegExp pattern for matching placeholders.
  ///   If not provided, uses the default pattern `^\$(\d+)$` which matches `$<numeric_id>`.
  ///
  /// ## Initialization Process
  /// 1. Creates internal components (resolver, state manager, processor)
  /// 2. Scans JSON for placeholders using pattern matching
  /// 3. Registers all discovered placeholders with the state manager
  /// 4. Sets up the infrastructure for chunk processing
  ///
  /// ## Placeholder Discovery
  /// The method recursively scans the JSON structure to find all placeholders:
  /// - In object values
  /// - In array elements
  /// - In nested structures
  /// - Follows the configured placeholder pattern
  ///
  /// ## Error Handling
  /// - Invalid JSON structures are handled gracefully
  /// - Malformed placeholders are ignored
  /// - Empty or null JSON is supported
  factory ChunkJson.fromJson(
    Map<String, dynamic> json, {
    RegExp? placeholderPattern,
  }) {
    final resolver =
        PlaceholderResolver(placeholderPattern: placeholderPattern);
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

  /// The original JSON data provided during initialization.
  ///
  /// This property returns the raw JSON structure that was passed to the
  /// constructor. It contains placeholders in their original form and
  /// is never modified during the chunk loading process.
  ///
  /// ## Returns
  /// The original [Map<String, dynamic>] containing placeholders
  ///
  /// ## Usage
  /// - Reference to original data structure
  /// - Debugging and inspection
  /// - Comparison with resolved data
  /// - Template for creating new instances
  ///
  /// ## Important Notes
  /// - This data is immutable and never changes
  /// - Placeholders remain in their original `$<id>` format
  /// - For current resolved state, use accessor methods or operators
  Map<String, dynamic> get json => _json;

  /// Retrieves a value with automatic placeholder resolution.
  ///
  /// This method provides direct access to JSON values with automatic
  /// placeholder resolution. If a value is a placeholder that has been
  /// resolved, it returns the resolved data. Otherwise, it returns the
  /// original value (including unresolved placeholders).
  ///
  /// ## Parameters
  /// - [key]: The key of the value to retrieve
  ///
  /// ## Returns
  /// - The resolved value if the placeholder has been resolved
  /// - The original placeholder string if not yet resolved
  /// - The original value if it's not a placeholder
  /// - `null` if the key doesn't exist
  ///
  /// ## Type Handling
  /// - Automatically handles Map type conversions
  /// - Preserves original data types
  /// - Ensures Map<String, dynamic> compatibility
  ///
  /// ## Performance
  /// - O(1) operation for direct key access
  /// - Minimal overhead for placeholder resolution
  /// - Efficient for repeated access
  dynamic getValue(String key) {
    final value = _json[key];
    final resolved = _resolver.resolvePlaceholders(value, _stateManager);

    // Ensure correct type for Map
    if (resolved is Map && resolved is! Map<String, dynamic>) {
      return Map<String, dynamic>.from(resolved);
    }

    return resolved;
  }

  /// Returns a Future that resolves when the specified key's value is loaded.
  ///
  /// This method provides asynchronous access to JSON values, allowing you
  /// to wait for placeholder resolution without blocking. If the value is
  /// not a placeholder, it returns immediately.
  ///
  /// ## Parameters
  /// - [key]: The key of the value to await
  ///
  /// ## Returns
  /// A [Future] that completes with:
  /// - The resolved value when the placeholder is resolved
  /// - The original value immediately if it's not a placeholder
  /// - An error if the placeholder resolution fails
  ///
  /// ## Usage Patterns
  /// - Waiting for specific data to load
  /// - Implementing async UI updates
  /// - Coordinating multiple data dependencies
  /// - Building reactive data flows
  ///
  /// ## Error Handling
  /// - Propagates errors from chunk processing
  /// - Handles invalid placeholder IDs gracefully
  /// - Supports timeout and cancellation patterns
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

  /// Returns the loading state for a specific key.
  ///
  /// This method checks the loading state of a value, which is useful for
  /// implementing loading indicators and conditional logic based on data
  /// availability.
  ///
  /// ## Parameters
  /// - [key]: The key to check the loading state for
  ///
  /// ## Returns
  /// The [ChunkState] of the value:
  /// - [ChunkState.pending]: If the value is an unresolved placeholder
  /// - [ChunkState.loaded]: If the value is resolved or not a placeholder
  /// - [ChunkState.error]: If the placeholder resolution failed
  ///
  /// ## Usage Patterns
  /// - Implementing loading states in UI
  /// - Conditional data processing
  /// - Progress tracking
  /// - Error handling and retry logic
  ///
  /// ## Important Notes
  /// - Non-placeholder values always return [ChunkState.loaded]
  /// - Invalid keys return [ChunkState.loaded] (not [ChunkState.pending])
  /// - State changes are reflected immediately after chunk processing
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

  /// Returns the fully resolved JSON data with all placeholders replaced.
  ///
  /// This method returns a complete JSON structure where all resolved
  /// placeholders are replaced with their actual values. Unresolved
  /// placeholders remain as placeholder strings.
  ///
  /// ## Returns
  /// A [Map<String, dynamic>] containing:
  /// - Original values for non-placeholder data
  /// - Resolved values for resolved placeholders
  /// - Placeholder strings for unresolved placeholders
  ///
  /// ## Usage Patterns
  /// - Getting snapshot of current state
  /// - Serializing partially loaded data
  /// - Debugging and inspection
  /// - Creating data backups
  ///
  /// ## Performance
  /// - Performs full placeholder resolution
  /// - Creates new Map instance (doesn't modify original)
  /// - Recursive resolution for nested structures
  ///
  /// ## Type Safety
  /// - Always returns Map<String, dynamic>
  /// - Handles type conversions automatically
  /// - Preserves nested structure integrity
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

  /// Waits for all placeholders to be resolved and returns the complete data.
  ///
  /// This method provides a convenient way to wait for all chunks to load
  /// before proceeding with data processing. It's particularly useful for
  /// scenarios where you need complete data before proceeding.
  ///
  /// ## Returns
  /// A [Future<Map<String, dynamic>>] that completes with the fully resolved
  /// JSON data when all placeholders have been resolved.
  ///
  /// ## Behavior
  /// - Returns immediately if no placeholders exist
  /// - Waits for all placeholder resolution
  /// - Does not wait for chunks that fail to load
  /// - Completes when all pending placeholders are resolved or failed
  ///
  /// ## Usage Patterns
  /// - Batch processing after complete load
  /// - Final data validation
  /// - Preparing data for serialization
  /// - Ensuring data completeness
  ///
  /// ## Error Handling
  /// - Continues waiting even if some chunks fail
  /// - Returns partial data if some placeholders fail
  /// - Propagates critical errors that prevent completion
  ///
  /// ## Performance
  /// - Efficient concurrent waiting
  /// - No polling or busy waiting
  /// - Minimal memory overhead
  Future<Map<String, dynamic>> waitForAllData() async {
    final placeholders = _resolver.findPlaceholders(_json);

    if (placeholders.isEmpty) {
      return _json;
    }

    // Wait for all placeholders to load
    final futures = placeholders.map((id) => _stateManager.getChunkFuture(id));
    await Future.wait(futures);

    return getResolvedData();
  }

  /// Subscribes to chunk update events with custom error and completion handling.
  ///
  /// This method provides a convenient way to listen for incoming chunk data
  /// with full control over event handling, including error and completion
  /// callbacks.
  ///
  /// ## Parameters
  /// - [onData]: Callback invoked for each chunk update
  /// - [onError]: Optional callback for handling errors
  /// - [onDone]: Optional callback for stream completion
  ///
  /// ## Returns
  /// A [StreamSubscription] that can be used to control the subscription
  ///
  /// ## Usage Patterns
  /// - Real-time UI updates
  /// - Logging and monitoring
  /// - Data validation and processing
  /// - Progress tracking
  ///
  /// ## Error Handling
  /// - Errors are forwarded to the [onError] callback
  /// - Stream remains active after non-fatal errors
  /// - Proper resource cleanup on completion
  StreamSubscription<Map<String, dynamic>> listenUpdateStream(
    void Function(Map<String, dynamic> chunk) onData, {
    void Function(Object error)? onError,
    void Function()? onDone,
  }) =>
      _processor.dataStream.listen(
        onData,
        onError: onError,
        onDone: onDone,
      );

  /// Processes an incoming chunk of data and updates resolved placeholders.
  ///
  /// This method handles individual chunk data by resolving placeholders
  /// and updating the internal state. It's the primary mechanism for
  /// providing data to the ChunkJson instance.
  ///
  /// This method is asynchronous and should be awaited to ensure proper
  /// completion of chunk processing and JSON updates.
  ///
  /// ## Parameters
  /// - [chunk]: A map containing placeholder IDs as keys and resolved data as values
  ///
  /// ## Processing Steps
  /// 1. Validates chunk data format
  /// 2. Resolves placeholders using the state manager
  /// 3. Updates internal state
  /// 4. Notifies listeners of updates
  ///
  /// ## Usage Patterns
  /// - Processing individual data chunks
  /// - Handling real-time updates
  /// - Batch processing of multiple chunks
  /// - Integration with data fetching logic
  ///
  /// ## Error Handling
  /// - Invalid chunk data is handled gracefully
  /// - Errors are propagated to stream listeners
  /// - Partial chunk processing is supported
  ///
  /// ## Example
  /// ```dart
  /// await chunkJson.processChunk({'123': 'John Doe'});
  /// ```
  Future<void> processChunk(Map<String, dynamic> chunk) =>
      _processor.processChunk(chunk);

  /// Processes a stream of JSON-encoded chunk data strings.
  ///
  /// This method provides a convenient way to handle continuous streams
  /// of chunk data, such as from Server-Sent Events or WebSocket connections.
  /// It automatically parses JSON strings and processes them as chunks.
  ///
  /// ## Parameters
  /// - [chunkStream]: A stream of JSON-encoded strings representing chunk data
  ///
  /// ## Processing Flow
  /// 1. Subscribes to the provided stream
  /// 2. Parses each JSON string into a chunk map
  /// 3. Processes each chunk using [processChunk]
  /// 4. Handles parsing errors gracefully
  ///
  /// ## Usage Patterns
  /// - Server-Sent Events integration
  /// - WebSocket data processing
  /// - File-based chunk streaming
  /// - Real-time data synchronization
  ///
  /// ## Error Handling
  /// - JSON parsing errors are captured and handled
  /// - Stream errors are forwarded to listeners
  /// - Processing continues despite individual chunk failures
  void processChunkStream(Stream<String> chunkStream) =>
      _processor.processChunkStream(chunkStream);

  /// Clears all chunk states and resets the instance to initial state.
  ///
  /// This method removes all resolved placeholder data and resets all
  /// chunks to their initial pending state. The original JSON structure
  /// remains unchanged.
  ///
  /// ## Effects
  /// - Clears all resolved placeholder data
  /// - Resets all chunk states to pending
  /// - Preserves original JSON structure
  /// - Notifies listeners of state changes
  ///
  /// ## Usage Scenarios
  /// - Restarting data loading process
  /// - Clearing cached data
  /// - Resetting for new data context
  /// - Testing and debugging
  void clear() {
    _stateManager.clear();
    // Re-register all placeholders to reset them to pending state
    final placeholders = _resolver.findPlaceholders(_json);
    for (final placeholder in placeholders) {
      _stateManager.registerPlaceholder(placeholder);
    }
  }

  /// Disposes of the ChunkJson instance and releases all resources.
  ///
  /// This method performs cleanup operations and should be called when
  /// the ChunkJson instance is no longer needed. It ensures proper
  /// resource management and prevents memory leaks.
  ///
  /// ## Cleanup Operations
  /// - Closes the chunk processor
  /// - Clears all state management data
  /// - Cancels active subscriptions
  /// - Releases internal resources
  ///
  /// ## Usage Guidelines
  /// - Call when instance is no longer needed
  /// - Required for proper resource management
  /// - After disposal, the instance should not be used
  /// - Essential in long-running applications
  void dispose() {
    _processor.close();
    _stateManager.clear();
  }

  /// Provides Map-like access to values using the [] operator.
  ///
  /// This operator allows accessing JSON values with automatic placeholder
  /// resolution using standard Map syntax. It's equivalent to calling
  /// [getValue] but with more convenient syntax.
  ///
  /// ## Parameters
  /// - [key]: The key of the value to retrieve
  ///
  /// ## Returns
  /// The resolved value with automatic placeholder resolution
  ///
  /// ## Usage
  /// ```dart
  /// final chunkJson = ChunkJson.fromJson({'name': '$123'});
  /// await chunkJson.processChunk({'123': 'John Doe'});
  ///
  /// final name = chunkJson['name']; // 'John Doe'
  /// ```
  dynamic operator [](String key) => getValue(key);

  /// Provides Map-like assignment of values using the []= operator.
  ///
  /// This operator allows setting JSON values using standard Map syntax.
  /// Note that this directly modifies the underlying JSON structure.
  ///
  /// ## Parameters
  /// - [key]: The key to set the value for
  /// - [value]: The value to set
  ///
  /// ## Usage
  /// ```dart
  /// final chunkJson = ChunkJson.fromJson({});
  /// chunkJson['name'] = 'John Doe';
  /// chunkJson['age'] = 30;
  /// ```
  ///
  /// ## Important Notes
  /// - This modifies the original JSON structure
  /// - Setting placeholders directly is supported
  /// - Changes are immediately reflected in the data
  void operator []=(String key, dynamic value) {
    _json[key] = value;
  }

  /// Checks if the JSON contains a specific key.
  ///
  /// This method provides Map-like interface for checking key existence
  /// in the JSON structure.
  ///
  /// ## Parameters
  /// - [key]: The key to check for existence
  ///
  /// ## Returns
  /// `true` if the key exists, `false` otherwise
  ///
  /// ## Usage
  /// ```dart
  /// final chunkJson = ChunkJson.fromJson({'name': 'John'});
  ///
  /// if (chunkJson.containsKey('name')) {
  ///   print('Name: ${chunkJson['name']}');
  /// }
  /// ```
  bool containsKey(String key) => _json.containsKey(key);

  /// Returns an iterable of all keys in the JSON structure.
  ///
  /// This property provides access to all keys in the JSON data,
  /// similar to the Map interface.
  ///
  /// ## Returns
  /// An [Iterable<String>] containing all keys
  ///
  /// ## Usage
  /// ```dart
  /// final chunkJson = ChunkJson.fromJson({'name': 'John', 'age': 30});
  ///
  /// for (final key in chunkJson.keys) {
  ///   print('$key: ${chunkJson[key]}');
  /// }
  /// ```
  Iterable<String> get keys => _json.keys;

  /// Returns an iterable of all values in the JSON structure with resolution.
  ///
  /// This property provides access to all values in the JSON data with
  /// automatic placeholder resolution applied. It's equivalent to calling
  /// [getValue] for each key.
  ///
  /// ## Returns
  /// An [Iterable<dynamic>] containing all resolved values
  ///
  /// ## Usage
  /// ```dart
  /// final chunkJson = ChunkJson.fromJson({'name': '$123', 'age': 30});
  /// await chunkJson.processChunk({'123': 'John Doe'});
  ///
  /// final values = chunkJson.values.toList();
  /// print(values); // ['John Doe', 30]
  /// ```
  ///
  /// ## Performance Note
  /// This operation resolves all placeholders, which may be expensive
  /// for large JSON structures. Consider caching results if needed.
  Iterable<dynamic> get values => _json.keys.map((key) => getValue(key));

  /// Checks if the JSON structure is empty.
  ///
  /// This property indicates whether the JSON contains any key-value pairs.
  ///
  /// ## Returns
  /// `true` if the JSON is empty, `false` otherwise
  ///
  /// ## Usage
  /// ```dart
  /// final chunkJson = ChunkJson.fromJson({});
  /// print(chunkJson.isEmpty); // true
  /// ```
  bool get isEmpty => _json.isEmpty;

  /// Checks if the JSON structure is not empty.
  ///
  /// This property indicates whether the JSON contains any key-value pairs.
  ///
  /// ## Returns
  /// `true` if the JSON is not empty, `false` otherwise
  ///
  /// ## Usage
  /// ```dart
  /// final chunkJson = ChunkJson.fromJson({'name': 'John'});
  /// print(chunkJson.isNotEmpty); // true
  /// ```
  bool get isNotEmpty => _json.isNotEmpty;

  /// Returns the number of key-value pairs in the JSON structure.
  ///
  /// This property provides the count of all keys in the JSON data,
  /// similar to the Map interface.
  ///
  /// ## Returns
  /// An [int] representing the number of key-value pairs
  ///
  /// ## Usage
  /// ```dart
  /// final chunkJson = ChunkJson.fromJson({'name': 'John', 'age': 30});
  /// print(chunkJson.length); // 2
  /// ```
  int get length => _json.length;

  /// Checks if all placeholders in the JSON have been resolved.
  ///
  /// This property indicates whether all placeholder values have been
  /// successfully resolved with actual data. It's useful for determining
  /// when the JSON structure is complete.
  ///
  /// ## Returns
  /// `true` if all placeholders are resolved or no placeholders exist,
  /// `false` if any placeholders remain unresolved
  ///
  /// ## Usage
  /// ```dart
  /// final json = {'title': 'Article', 'content': '$123'};
  /// final chunkJson = ChunkJson.fromJson(json);
  ///
  /// print(chunkJson.allChunksResolved); // false
  ///
  /// await chunkJson.processChunk({'123': 'Article content...'});
  /// print(chunkJson.allChunksResolved); // true
  /// ```
  ///
  /// ## Usage Patterns
  /// - Determining when data is complete
  /// - Conditional processing based on completion
  /// - Progress indicators
  /// - Final validation triggers
  ///
  /// ## Performance Note
  /// This property scans the JSON structure for placeholders on each access.
  /// Consider caching the result if called frequently.
  bool get allChunksResolved => !_stateManager.hasUnresolvedData;

  /// Returns a string representation of the resolved JSON data.
  @override
  String toString() => getResolvedData().toString();
}
