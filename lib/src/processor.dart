import 'dart:async';
import 'dart:convert';

import 'package:chunk_norris/src/chunk_state_manager.dart';

/// Процессор чанков
final class ChunkProcessor {
  final ChunkStateManager _stateManager;
  final StreamController<Map<String, dynamic>> _dataController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<String> _errorController =
      StreamController<String>.broadcast();

  ChunkProcessor(this._stateManager);

  /// Поток обновленных данных
  Stream<Map<String, dynamic>> get dataStream => _dataController.stream;

  /// Поток ошибок
  Stream<String> get errorStream => _errorController.stream;

  /// Обработать чанк данных
  void processChunk(Map<String, dynamic> chunk) {
    try {
      // Обработать каждый элемент в чанке
      chunk.forEach((chunkId, data) {
        _stateManager.resolvePlaceholder(chunkId, data);
      });

      // Уведомить о новых данных
      _dataController.add(chunk);
    } catch (e) {
      _errorController.add('Error processing chunk: $e');
    }
  }

  /// Обработать поток чанков
  void processChunkStream(Stream<String> chunkStream) {
    chunkStream.listen(
      (chunkData) {
        try {
          final chunk = jsonDecode(chunkData) as Map<String, dynamic>;
          processChunk(chunk);
        } catch (e) {
          _errorController.add('Error parsing chunk: $e');
        }
      },
      onError: (error) {
        _errorController.add('Stream error: $error');
      },
    );
  }

  /// Закрыть процессор
  void close() {
    _dataController.close();
    _errorController.close();
  }
}
