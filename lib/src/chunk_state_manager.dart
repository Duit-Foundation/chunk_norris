import 'package:chunk_norris/src/chunk_completer.dart';
import 'package:chunk_norris/src/state.dart';

/// Менеджер состояния чанков
final class ChunkStateManager {
  final Map<String, ChunkCompleter<dynamic>> _completers = {};
  final Map<String, dynamic> _resolvedData = {};

  /// Получить состояние чанка по идентификатору
  ChunkState getChunkState(String chunkId) {
    return _completers[chunkId]?.state ?? ChunkState.pending;
  }

  /// Получить Future для ожидания загрузки чанка
  Future<dynamic> getChunkFuture(String chunkId) {
    return _completers[chunkId]?.future ?? Future.value(null);
  }

  /// Зарегистрировать плейсхолдер
  void registerPlaceholder(String chunkId) {
    if (!_completers.containsKey(chunkId)) {
      _completers[chunkId] = ChunkCompleter<dynamic>();
    }
  }

  /// Разрешить плейсхолдер с данными
  void resolvePlaceholder(String chunkId, dynamic data) {
    _resolvedData[chunkId] = data;
    _completers[chunkId]?.complete(data);
  }

  /// Разрешить плейсхолдер с ошибкой
  void rejectPlaceholder(String chunkId, Object error, [StackTrace? stackTrace]) {
    _completers[chunkId]?.completeError(error, stackTrace);
  }

  /// Получить разрешенные данные
  dynamic getResolvedData(String chunkId) {
    return _resolvedData[chunkId];
  }

  /// Проверить, разрешен ли плейсхолдер
  bool isResolved(String chunkId) {
    return _resolvedData.containsKey(chunkId);
  }

  /// Очистить все состояния
  void clear() {
    _completers.clear();
    _resolvedData.clear();
  }
}