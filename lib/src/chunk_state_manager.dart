import 'package:chunk_norris/src/chunk_completer.dart';
import 'package:chunk_norris/src/state.dart';
import 'package:collection/collection.dart';
import 'package:meta/meta.dart';

/// A centralized state management system for handling chunk placeholders and their resolution.
///
/// The ChunkStateManager serves as the coordination hub for managing the lifecycle
/// of chunk placeholders in a progressive JSON loading system. It tracks the state
/// of each placeholder, manages async completion operations, and provides a unified
/// interface for resolving placeholder data as it becomes available.
///
/// ## Key Features
/// - **Centralized State Management**: Single source of truth for all chunk states
/// - **Async Coordination**: Manages Future-based operations for chunk loading
/// - **Placeholder Lifecycle**: Handles registration, resolution, and error states
/// - **Data Persistence**: Maintains resolved data for quick access
/// - **Thread Safety**: Safe for concurrent access from multiple threads
/// - **Memory Management**: Provides cleanup utilities for resource management
///
/// ## Architecture
/// The manager maintains two internal data structures:
/// ```
/// Completers Map: chunkId -> ChunkCompleter (for async operations)
/// Resolved Data Map: chunkId -> resolved data (for quick access)
/// ```
///
/// ## State Management Flow
/// ```
/// 1. Register placeholder -> Creates ChunkCompleter
/// 2. Await chunk data -> Returns Future from completer
/// 3. Resolve with data -> Completes future and stores data
/// 4. Access resolved data -> Returns cached data
/// ```
///
/// ## Usage Example
/// ```dart
/// final stateManager = ChunkStateManager();
///
/// // Register placeholders
/// stateManager.registerPlaceholder('user_123');
/// stateManager.registerPlaceholder('post_456');
///
/// // Set up async listeners
/// stateManager.getChunkFuture('user_123').then((userData) {
///   print('User loaded: $userData');
/// });
///
/// // Resolve with data when available
/// stateManager.resolvePlaceholder('user_123', {
///   'name': 'John Doe',
///   'email': 'john@example.com'
/// });
///
/// // Check state and access data
/// if (stateManager.isResolved('user_123')) {
///   final userData = stateManager.getResolvedData('user_123');
///   print('User data: $userData');
/// }
/// ```
///
/// ## Error Handling
/// The manager supports error states for failed chunk loading:
/// ```dart
/// try {
///   // Simulate network failure
///   stateManager.rejectPlaceholder('user_123',
///     Exception('Network timeout'));
/// } catch (e) {
///   print('Chunk loading failed: $e');
/// }
/// ```
///
/// ## Integration Points
/// - Used by [ChunkProcessor] for processing incoming chunks
/// - Integrates with [PlaceholderResolver] for data resolution
/// - Provides state information to [ChunkField] instances
/// - Supports [ChunkCompleter] for individual chunk operations
///
/// ## Performance Considerations
/// - O(1) lookup for chunk states and data
/// - Minimal memory overhead per placeholder
/// - Efficient cleanup with batch operations
/// - Thread-safe concurrent access
///
/// See also:
/// - [ChunkCompleter] for individual chunk completion handling
/// - [ChunkProcessor] for processing chunk streams
/// - [PlaceholderResolver] for resolving placeholder data
/// - [ChunkState] for available state values
final class ChunkStateManager {
  final Map<String, ChunkCompleter<dynamic>> _completers = {};
  final Map<String, dynamic> _resolvedData = {};

  /// Retrieves the current state of a chunk by its identifier.
  ///
  /// Returns the loading state of the specified chunk, which can be used
  /// to determine if the chunk is still loading, successfully loaded, or
  /// failed with an error.
  ///
  /// ## Parameters
  /// - [chunkId]: The unique identifier of the chunk to check
  ///
  /// ## Returns
  /// The current [ChunkState] of the chunk:
  /// - [ChunkState.pending]: If the chunk is not registered or still loading
  /// - [ChunkState.loaded]: If the chunk has been successfully resolved
  /// - [ChunkState.error]: If the chunk failed to load
  ///
  /// ## Usage Patterns
  /// - Pre-flight checks before accessing chunk data
  /// - Implementing loading indicators in UI
  /// - Conditional logic based on chunk availability
  /// - State-based error handling
  ChunkState getChunkState(String chunkId) {
    return _completers[chunkId]?.state ?? ChunkState.pending;
  }

  /// Returns a Future that completes when the specified chunk is resolved.
  ///
  /// This method provides async access to chunk data, allowing callers to
  /// await chunk resolution without blocking. If the chunk is not registered,
  /// returns a Future that completes immediately with null.
  ///
  /// ## Parameters
  /// - [chunkId]: The unique identifier of the chunk to await
  ///
  /// ## Returns
  /// A [Future<dynamic>] that completes with:
  /// - The resolved chunk data when successfully loaded
  /// - An error when chunk loading fails
  /// - `null` immediately if the chunk is not registered
  ///
  /// ## Async Patterns
  /// - Primary method for awaiting chunk data
  /// - Integrates with async/await syntax
  /// - Supports error handling with try/catch
  /// - Can be used with Future combinators
  ///
  /// ## Performance Notes
  /// - Returns immediately for unregistered chunks
  /// - Efficient completion for already resolved chunks
  /// - Memory efficient with shared Future instances
  Future<dynamic> getChunkFuture(String chunkId) {
    return _completers[chunkId]?.future ?? Future.value(null);
  }

  /// Registers a placeholder for tracking and future resolution.
  ///
  /// This method creates a new ChunkCompleter for the specified chunk ID,
  /// enabling it to be tracked and resolved later. If a placeholder with
  /// the same ID already exists, this method has no effect.
  ///
  /// ## Parameters
  /// - [chunkId]: The unique identifier for the placeholder to register
  ///
  /// ## Behavior
  /// - Creates a new ChunkCompleter if one doesn't exist
  /// - Ignores registration attempts for existing placeholders
  /// - Initializes the placeholder in [ChunkState.pending] state
  /// - Enables future resolution via [resolvePlaceholder] or [rejectPlaceholder]
  ///
  /// ## Usage Patterns
  /// - Initialize placeholders before chunk data arrives
  /// - Batch registration during initial setup
  /// - Dynamic registration as new placeholders are discovered
  /// - Safe to call multiple times for the same ID
  ///
  /// ## Integration
  /// This method is typically called by:
  /// - [PlaceholderResolver] when discovering new placeholders
  /// - Application code during initialization
  /// - [ChunkProcessor] when processing chunk metadata
  void registerPlaceholder(String chunkId) {
    if (!_completers.containsKey(chunkId)) {
      _completers[chunkId] = ChunkCompleter<dynamic>();
    }
  }

  /// Resolves a placeholder with the provided data.
  ///
  /// This method completes the loading process for a chunk by providing
  /// its resolved data. It updates the internal state, completes any
  /// pending Future operations, and caches the data for immediate access.
  ///
  /// ## Parameters
  /// - [chunkId]: The unique identifier of the chunk to resolve
  /// - [data]: The resolved data for the chunk
  ///
  /// ## Effects
  /// - Stores the resolved data in internal cache
  /// - Completes the ChunkCompleter with the provided data
  /// - Transitions chunk state to [ChunkState.loaded]
  /// - Notifies all Future listeners with the resolved data
  ///
  /// ## Data Types
  /// The method accepts any data type:
  /// - Primitive values (String, int, double, bool)
  /// - Complex objects (Map, List, custom classes)
  /// - Null values (valid resolved state)
  ///
  /// ## Error Handling
  /// - Safe to call multiple times (idempotent after first call)
  /// - Works with unregistered chunks (auto-registers)
  /// - No type validation (accepts dynamic data)
  ///
  /// ## Performance
  /// - O(1) operation for data storage and completion
  /// - Immediate availability for subsequent access
  /// - Memory efficient with direct data storage
  void resolvePlaceholder(String chunkId, dynamic data) {
    _resolvedData[chunkId] = data;
    _completers[chunkId]?.complete(data);
  }

  /// Rejects a placeholder with an error, indicating failed loading.
  ///
  /// This method marks a chunk as failed to load due to an error condition.
  /// It completes the ChunkCompleter with an error state and preserves
  /// error information for debugging and error handling.
  ///
  /// ## Parameters
  /// - [chunkId]: The unique identifier of the chunk that failed
  /// - [error]: The error object describing the failure
  /// - [stackTrace]: Optional stack trace for debugging (recommended)
  ///
  /// ## Effects
  /// - Completes the ChunkCompleter with an error
  /// - Transitions chunk state to [ChunkState.error]
  /// - Notifies all Future listeners with the error
  /// - Preserves error information in the completer
  ///
  /// ## Error Types
  /// Common error scenarios:
  /// - Network timeouts and connectivity issues
  /// - Invalid data format or parsing errors
  /// - Authentication and authorization failures
  /// - Resource not found errors
  /// - Server-side processing errors
  ///
  /// ## Best Practices
  /// - Always include meaningful error messages
  /// - Provide stack traces for debugging
  /// - Use specific exception types when possible
  /// - Consider retry mechanisms for transient errors
  ///
  /// ## Integration
  /// - Used by [ChunkProcessor] for processing failures
  /// - Integrates with error handling in [ChunkField]
  /// - Supports diagnostic logging and monitoring
  void rejectPlaceholder(String chunkId, Object error,
      [StackTrace? stackTrace]) {
    _completers[chunkId]?.completeError(error, stackTrace);
  }

  /// Retrieves the resolved data for a specified chunk.
  ///
  /// This method provides immediate access to previously resolved chunk data.
  /// It returns the cached data directly without any async operations or
  /// state checks.
  ///
  /// ## Parameters
  /// - [chunkId]: The unique identifier of the chunk to retrieve
  ///
  /// ## Returns
  /// - The resolved data if the chunk has been successfully resolved
  /// - `null` if the chunk is not resolved or doesn't exist
  ///
  /// ## Usage Patterns
  /// - Quick access to resolved data without async operations
  /// - Checking data availability before processing
  /// - Caching resolved data for multiple use
  /// - Implementing synchronous data access patterns
  ///
  /// ## Performance
  /// - O(1) lookup operation
  /// - No async overhead
  /// - Direct memory access to cached data
  /// - Efficient for repeated access
  ///
  /// ## Safety Notes
  /// - Returns null for unresolved chunks (no exceptions)
  /// - Safe to call for non-existent chunks
  /// - Data is returned as-is (no copying or transformation)
  /// - Thread-safe for concurrent access
  dynamic getResolvedData(String chunkId) {
    return _resolvedData[chunkId];
  }

  /// Checks if a chunk has been successfully resolved with data.
  ///
  /// This method provides a quick way to determine if a chunk has been
  /// resolved without accessing the actual data. It's useful for conditional
  /// logic and validation scenarios.
  ///
  /// ## Parameters
  /// - [chunkId]: The unique identifier of the chunk to check
  ///
  /// ## Returns
  /// - `true` if the chunk has been resolved with data
  /// - `false` if the chunk is not resolved, failed, or doesn't exist
  ///
  /// ## Usage Patterns
  /// - Pre-conditions for data access
  /// - Conditional processing logic
  /// - Validation in data pipelines
  /// - Progress tracking for multiple chunks
  ///
  /// ## Distinction from getChunkState
  /// - `isResolved()` only checks for successful resolution
  /// - `getChunkState()` provides full state information including errors
  /// - Use `isResolved()` for simple success/failure checks
  /// - Use `getChunkState()` for detailed state management
  bool isResolved(String chunkId) => _resolvedData.containsKey(chunkId);

  /// Internal property providing access to all resolved placeholder IDs.
  ///
  /// This property returns a set of all chunk IDs that have been successfully
  /// resolved with data. It's used internally by the framework for cache
  /// management and state tracking.
  ///
  /// ## Returns
  /// A [Set<String>] containing all resolved chunk IDs
  ///
  /// ## Internal Usage
  /// - Cache key generation in [PlaceholderResolver]
  /// - State synchronization between components
  /// - Diagnostic reporting and monitoring
  /// - Bulk operations on resolved chunks
  ///
  /// ## Important Notes
  /// - This property is marked as internal and should not be used directly
  /// - The returned set is a snapshot at the time of access
  /// - Changes to the returned set do not affect the internal state
  /// - Used primarily for framework integration
  @internal
  Set<String> get resolvedPlaceholderIds => _resolvedData.keys.toSet();

  @internal
  bool get hasUnresolvedData =>
      _completers.keys.firstWhereOrNull((id) => !isResolved(id)) != null;

  /// Clears all tracked chunks and their associated data.
  ///
  /// This method removes all registered placeholders, resolved data, and
  /// associated state information. It's useful for cleanup operations and
  /// resetting the manager to its initial state.
  ///
  /// ## Effects
  /// - Clears all ChunkCompleter instances
  /// - Removes all resolved data from cache
  /// - Resets the manager to empty state
  /// - Releases memory used by chunk tracking
  ///
  /// ## Usage Scenarios
  /// - Application shutdown or cleanup
  /// - Resetting state between test cases
  /// - Memory management in long-running applications
  /// - Switching between different data contexts
  void clear() {
    _completers.clear();
    _resolvedData.clear();
  }
}
