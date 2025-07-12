/// Represents the current state of a chunk loading operation.
///
/// This enum is used throughout the progressive JSON loading system to track
/// the lifecycle of asynchronous chunk operations. It provides a clear state
/// machine for managing data loading processes.
///
/// ## State Transitions
/// The typical state flow is:
/// ```
/// pending -> loaded (success)
/// pending -> error (failure)
/// ```
///
/// ## Usage Example
/// ```dart
/// ChunkState currentState = ChunkState.pending;
///
/// switch (currentState) {
///   case ChunkState.pending:
///     showLoadingIndicator();
///     break;
///   case ChunkState.loaded:
///     displayData();
///     break;
///   case ChunkState.error:
///     showErrorMessage();
///     break;
/// }
/// ```
///
/// See also:
/// - [ChunkCompleter] for managing state transitions
enum ChunkState {
  /// Initial state indicating that the chunk loading operation has not yet completed.
  ///
  /// This is the default state when a chunk operation is created but hasn't
  /// finished loading data or encountered an error.
  ///
  /// ## Characteristics
  /// - Initial state for all chunk operations
  /// - Indicates operation is in progress
  /// - Can transition to either [loaded] or [error]
  /// - Used for displaying loading indicators
  pending,

  /// State indicating that the chunk loading operation completed successfully.
  ///
  /// This state means the data has been successfully loaded and is available
  /// for use. The operation cannot transition to any other state after reaching
  /// this state.
  ///
  /// ## Characteristics
  /// - Terminal state (no further transitions)
  /// - Data is available and ready for use
  /// - Indicates successful completion
  /// - Used for rendering loaded content
  loaded,

  /// State indicating that the chunk loading operation failed with an error.
  ///
  /// This state means the loading operation encountered an error and could not
  /// complete successfully. Error details are typically stored separately.
  ///
  /// ## Characteristics
  /// - Terminal state (no further transitions)
  /// - Indicates operation failure
  /// - Error information available via error property
  /// - Used for displaying error messages or retry options
  error,
}
