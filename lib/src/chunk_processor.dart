import 'dart:async';
import 'dart:convert';

import 'package:chunk_norris/src/index.dart';

/// A processor for handling progressive chunk data loading and state management.
///
/// This class serves as the central orchestrator for processing chunks of data
/// as they arrive, managing their state transitions, and broadcasting updates
/// to listeners. It integrates with [ChunkStateManager] to handle placeholder
/// resolution and provides a stream-based interface for real-time data updates.
///
/// ## Key Features
/// - Asynchronous chunk processing with state management
/// - Stream-based data broadcasting to multiple listeners
/// - Automatic JSON parsing for string-based chunks
/// - Error handling and propagation
/// - Resource cleanup and lifecycle management
///
/// ## Architecture
/// The processor operates as a bridge between data sources and consumers:
/// ```
/// Data Source -> ChunkProcessor -> ChunkStateManager -> Placeholders
///                      |
///                      v
///                 DataStream -> UI/Consumers
/// ```
///
/// ## Usage Example
/// ```dart
/// final stateManager = ChunkStateManager();
/// final processor = ChunkProcessor(stateManager);
///
/// // Listen to data updates
/// processor.dataStream.listen((chunk) {
///   print('New chunk received: $chunk');
/// });
///
/// // Process individual chunks
/// await processor.processChunk({
///   'user_123': {'name': 'Alice', 'age': 30},
///   'post_456': {'title': 'Hello World', 'content': '...'}
/// });
///
/// // Or process a stream of JSON strings
/// processor.processChunkStream(jsonChunkStream);
///
/// // Clean up when done
/// processor.close();
/// ```
///
/// ## Error Handling
/// All errors during processing are captured and forwarded to the data stream,
/// allowing consumers to handle them appropriately without crashing the processor.
///
/// ## Thread Safety
/// The processor is designed to be thread-safe and can handle concurrent
/// chunk processing operations.
///
/// See also:
/// - [ChunkStateManager] for placeholder state management
/// - [ChunkCompleter] for individual chunk completion handling
final class ChunkProcessor {
  final ChunkStateManager _stateManager;
  final _dataController = StreamController<Map<String, dynamic>>.broadcast();

  /// Creates a new chunk processor with the specified state manager.
  ///
  /// The [stateManager] is used to track and resolve placeholders as chunks
  /// are processed. It should be the same instance used across the application
  /// for consistent state management.
  ///
  /// ## Parameters
  /// - [stateManager]: The state manager instance for handling placeholder resolution
  ChunkProcessor(this._stateManager);

  /// A broadcast stream that emits processed chunk data to all listeners.
  ///
  /// This stream provides real-time updates whenever new chunks are processed.
  /// Each emission contains the raw chunk data as a [Map<String, dynamic>]
  /// where keys are chunk identifiers and values are the resolved data.
  ///
  /// ## Stream Characteristics
  /// - Broadcast stream (supports multiple listeners)
  /// - Emits [Map<String, dynamic>] for each processed chunk
  /// - Forwards errors from processing operations
  /// - Closes when [close] is called
  ///
  /// ## Usage Example
  /// ```dart
  /// processor.dataStream.listen(
  ///   (chunk) {
  ///     print('Received chunk: $chunk');
  ///     // Update UI with new data
  ///   },
  ///   onError: (error) {
  ///     print('Processing error: $error');
  ///     // Handle error appropriately
  ///   },
  ///   onDone: () {
  ///     print('Processing completed');
  ///   }
  /// );
  /// ```
  Stream<Map<String, dynamic>> get dataStream => _dataController.stream;

  /// Processes a single chunk of data and resolves associated placeholders.
  ///
  /// This method takes a chunk represented as a [Map<String, dynamic>] where
  /// each key-value pair represents a chunk identifier and its resolved data.
  /// It updates the state manager with the new data and broadcasts the chunk
  /// to all stream listeners.
  ///
  /// ## Processing Steps
  /// 1. Iterates through each chunk identifier and data pair
  /// 2. Resolves placeholders in the state manager
  /// 3. Broadcasts the chunk data to listeners
  /// 4. Handles any errors that occur during processing
  ///
  /// ## Parameters
  /// - [chunk]: A map containing chunk identifiers as keys and resolved data as values
  ///
  /// ## Example
  /// ```dart
  /// await processor.processChunk({
  ///   'user_123': {
  ///     'id': 123,
  ///     'name': 'John Doe',
  ///     'email': 'john@example.com'
  ///   },
  ///   'profile_456': {
  ///     'userId': 123,
  ///     'avatar': 'https://example.com/avatar.jpg'
  ///   }
  /// });
  /// ```
  ///
  /// ## Error Handling
  /// Any errors during processing are caught and forwarded to the data stream
  /// as error events, ensuring the processor remains stable and responsive.
  ///
  /// ## Asynchronous Processing
  /// This method is asynchronous and should be awaited to ensure proper
  /// completion of chunk processing and notification of listeners.
  ///
  /// ## Example
  /// ```dart
  /// await processor.processChunk({
  ///   'user_123': {'name': 'Alice', 'age': 30},
  ///   'post_456': {'title': 'Hello World', 'content': '...'}
  /// });
  /// ```
  Future<void> processChunk(Map<String, dynamic> chunk) async {
    try {
      // Process each element in chunk
      chunk.forEach((chunkId, data) {
        _stateManager.resolvePlaceholder(chunkId, data);
      });

      // Notify about new data
      _dataController.add(chunk);

      // Allow microtasks to process
      await Future.delayed(Duration.zero);
    } catch (e, s) {
      _dataController.addError(e, s);
    }
  }

  /// Adds an error to the data controller.
  ///
  /// This method is used to add an error to the data controller, which will
  /// be forwarded to all listeners.
  ///
  /// ## Parameters
  /// - [error]: The error to add to the data controller
  /// - [stackTrace]: The stack trace of the error
  ///
  /// ## Usage
  /// ```dart
  /// processor.addError(error);
  /// ```
  void addError(Object error, [StackTrace? stackTrace]) =>
      _dataController.addError(error, stackTrace);

  /// Processes a stream of JSON-encoded chunk data strings.
  ///
  /// This method subscribes to a stream of JSON strings, automatically parses
  /// each string into a chunk map, and processes it using [processChunk].
  /// It's designed for scenarios where chunk data arrives as serialized JSON
  /// from network sources, files, or other streaming data sources.
  ///
  /// ## Processing Flow
  /// 1. Subscribes to the provided stream
  /// 2. Parses each JSON string into a [Map<String, dynamic>]
  /// 3. Calls [processChunk] with the parsed data (awaited internally)
  /// 4. Handles JSON parsing errors and stream errors
  ///
  /// ## Parameters
  /// - [chunkStream]: A stream of JSON-encoded strings representing chunk data
  ///
  /// ## Expected JSON Format
  /// Each JSON string should represent an object with chunk identifiers as keys:
  /// ```json
  /// {
  ///   "user_123": {"name": "Alice", "age": 30},
  ///   "post_456": {"title": "Hello", "content": "World"}
  /// }
  /// ```
  ///
  /// ## Example
  /// ```dart
  /// final Stream<String> jsonStream = getChunkStream();
  /// processor.processChunkStream(jsonStream);
  ///
  /// // The processor will automatically handle:
  /// // - JSON parsing
  /// // - Chunk processing
  /// // - Error handling
  /// // - Broadcasting updates
  /// ```
  ///
  /// ## Error Handling
  /// - JSON parsing errors are caught and forwarded to the data stream
  /// - Stream errors are automatically forwarded to listeners
  /// - The processor remains active even if individual chunks fail
  ///
  /// ## Important Notes
  /// - The stream subscription is managed internally
  /// - Multiple stream subscriptions can be active simultaneously
  /// - Call [close] to properly clean up resources when done
  void processChunkStream(Stream<String> chunkStream) => chunkStream.listen(
        (chunkData) async {
          try {
            final chunk = jsonDecode(chunkData) as Map<String, dynamic>;
            await processChunk(chunk);
          } catch (e, s) {
            _dataController.addError(e, s);
          }
        },
        onError: (e, s) => _dataController.addError(e, s),
      );

  /// Closes the processor and cleans up all resources.
  ///
  /// This method should be called when the processor is no longer needed
  /// to properly release resources and notify listeners that no more data
  /// will be processed. After calling this method, the processor should
  /// not be used for further operations.
  ///
  /// ## Cleanup Operations
  /// - Closes the internal data stream controller
  /// - Notifies all listeners that the stream has ended
  /// - Releases internal resources
  void close() => _dataController.close();
}
