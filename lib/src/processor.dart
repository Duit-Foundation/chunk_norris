import 'dart:async';
import 'dart:convert';

import 'package:chunk_norris/src/chunk_state_manager.dart';

typedef ChunkResolver = void Function(
  String chunkId,
  dynamic data,
);

final class ChunkProcessor {
  final ChunkStateManager _stateManager;
  final _dataController = StreamController<Map<String, dynamic>>.broadcast();

  ChunkProcessor(this._stateManager);

  /// Поток обновленных данных
  Stream<Map<String, dynamic>> get dataStream => _dataController.stream;

  /// Обработать чанк данных
  void processChunk(Map<String, dynamic> chunk) {
    try {
      // Обработать каждый элемент в чанке
      chunk.forEach((chunkId, data) {
        _stateManager.resolvePlaceholder(chunkId, data);
      });

      // Уведомить о новых данных
      _dataController.add(chunk);
    } catch (e, s) {
      _dataController.addError(e, s);
    }
  }

  /// Обработать поток чанков
  void processChunkStream(Stream<String> chunkStream) {
    chunkStream.listen(
      (chunkData) {
        try {
          final chunk = jsonDecode(chunkData) as Map<String, dynamic>;
          processChunk(chunk);
        } catch (e, s) {
          _dataController.addError(e, s);
        }
      },
      onError: (e, s) {
        _dataController.addError(e, s);
      },
    );
  }

  /// Закрыть процессор
  void close() {
    _dataController.close();
  }
}
