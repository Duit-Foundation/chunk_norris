import 'dart:async';

import 'package:chunk_norris/src/state.dart';

/// Completer для управления ожиданием чанков
final class ChunkCompleter<T> {
  final Completer<T> _completer = Completer<T>();
  ChunkState _state = ChunkState.pending;
  Object? _error;

  /// Получить Future для ожидания загрузки данных
  Future<T> get future => _completer.future;

  /// Текущее состояние загрузки
  ChunkState get state => _state;

  /// Ошибка загрузки (если есть)
  Object? get error => _error;

  /// Завершить загрузку с данными
  void complete(T data) {
    if (_completer.isCompleted) return;
    _state = ChunkState.loaded;
    _completer.complete(data);
  }

  /// Завершить загрузку с ошибкой
  void completeError(Object error, [StackTrace? stackTrace]) {
    if (_completer.isCompleted) return;
    _state = ChunkState.error;
    _error = error;
    _completer.completeError(error, stackTrace);
  }
}