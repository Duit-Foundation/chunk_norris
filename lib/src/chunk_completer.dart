import 'dart:async';

import 'package:chunk_norris/src/state.dart';

/// A specialized completer for managing asynchronous chunk loading operations
/// in progressive JSON processing.
///
/// This class provides a stateful wrapper around Dart's [Completer] to handle
/// chunk loading with explicit state management and error tracking. It ensures
/// thread-safe completion of asynchronous operations while maintaining the
/// current loading state.
///
/// ## Features
/// - Type-safe generic implementation
/// - State tracking ([ChunkState.pending], [ChunkState.loaded], [ChunkState.error])
/// - Error information preservation
/// - Prevention of multiple completions
/// - Thread-safe operation
///
/// ## Usage Example
/// ```dart
/// final completer = ChunkCompleter<Map<String, dynamic>>();
///
/// // Start async operation
/// loadChunkData().then((data) {
///   completer.complete(data);
/// }).catchError((error) {
///   completer.completeError(error);
/// });
///
/// // Wait for completion
/// final result = await completer.future;
/// print('State: ${completer.state}'); // ChunkState.loaded
/// ```
///
/// ## State Management
/// The completer maintains one of three states:
/// - [ChunkState.pending]: Initial state, waiting for completion
/// - [ChunkState.loaded]: Successfully completed with data
/// - [ChunkState.error]: Completed with error
///
/// See also:
/// - [ChunkState] for available states
/// - [Completer] for underlying completion mechanism
final class ChunkCompleter<T> {
  final Completer<T> _completer = Completer<T>();
  ChunkState _state = ChunkState.pending;
  Object? _error;

  /// Returns a [Future] that completes when the chunk loading operation finishes.
  ///
  /// This future will complete with the loaded data of type [T] when [complete]
  /// is called, or complete with an error when [completeError] is called.
  Future<T> get future => _completer.future;

  /// Returns the current loading state of the chunk operation.
  ///
  /// The state transitions through the following lifecycle:
  /// 1. [ChunkState.pending] - Initial state, operation not completed
  /// 2. [ChunkState.loaded] - Operation completed successfully
  /// 3. [ChunkState.error] - Operation completed with error
  ///
  /// This property is useful for:
  /// - Checking operation status before awaiting
  /// - Implementing loading indicators
  /// - Debugging and logging
  ChunkState get state => _state;

  /// Returns the error that occurred during loading, if any.
  ///
  /// This property is only populated when the completer is completed with an error
  /// via [completeError]. It returns `null` if the operation hasn't failed or
  /// hasn't completed yet.
  Object? get error => _error;

  /// Completes the chunk loading operation with the provided data.
  ///
  /// This method transitions the completer from [ChunkState.pending] to
  /// [ChunkState.loaded] and fulfills the [future] with the given data.
  void complete(T data) {
    if (_completer.isCompleted) return;
    _state = ChunkState.loaded;
    _completer.complete(data);
  }

  /// Completes the chunk loading operation with an error.
  ///
  /// This method transitions the completer from [ChunkState.pending] to
  /// [ChunkState.error] and causes the [future] to complete with the specified error.
  ///
  /// ## Behavior
  /// - Sets state to [ChunkState.error]
  /// - Stores the error in [error] property
  /// - Completes the underlying [Future] with error
  /// - Ignores subsequent calls if already completed (idempotent)
  /// - Thread-safe operation
  ///
  /// ## Parameters
  /// - [error]: The error object that caused the failure
  /// - [stackTrace]: Optional stack trace for debugging (recommended)
  void completeError(Object error, [StackTrace? stackTrace]) {
    if (_completer.isCompleted) return;
    _state = ChunkState.error;
    _error = error;
    _completer.completeError(error, stackTrace);
  }
}
