import 'package:chunk_norris/src/chunk_completer.dart';
import 'package:chunk_norris/src/state.dart';
import 'package:meta/meta.dart';

/// Chunk state manager
final class ChunkStateManager {
  final Map<String, ChunkCompleter<dynamic>> _completers = {};
  final Map<String, dynamic> _resolvedData = {};

  /// Get chunk state by identifier
  ChunkState getChunkState(String chunkId) {
    return _completers[chunkId]?.state ?? ChunkState.pending;
  }

  /// Get Future for awaiting chunk loading
  Future<dynamic> getChunkFuture(String chunkId) {
    return _completers[chunkId]?.future ?? Future.value(null);
  }

  /// Register placeholder
  void registerPlaceholder(String chunkId) {
    if (!_completers.containsKey(chunkId)) {
      _completers[chunkId] = ChunkCompleter<dynamic>();
    }
  }

  /// Resolve placeholder with data
  void resolvePlaceholder(String chunkId, dynamic data) {
    _resolvedData[chunkId] = data;
    _completers[chunkId]?.complete(data);
  }

  /// Resolve placeholder with error
  void rejectPlaceholder(String chunkId, Object error, [StackTrace? stackTrace]) {
    _completers[chunkId]?.completeError(error, stackTrace);
  }

  /// Get resolved data
  dynamic getResolvedData(String chunkId) {
    return _resolvedData[chunkId];
  }

  /// Check if placeholder is resolved
  bool isResolved(String chunkId) {
    return _resolvedData.containsKey(chunkId);
  }

  @internal
  Set<String> get resolvedPlaceholderIds => _resolvedData.keys.toSet();

  /// Clear all states
  void clear() {
    _completers.clear();
    _resolvedData.clear();
  }
}