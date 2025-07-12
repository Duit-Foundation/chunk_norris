import 'dart:async';

import 'package:meta/meta.dart';

import 'state.dart';

/// [ChunkField] represents a single field in a chunked JSON structure that may be loaded asynchronously.
///
/// It tracks the state of the field (pending, loaded, or error), holds the resolved value (if available),
/// and provides a [Future] for awaiting the value. Optionally, a deserializer can be provided to convert
/// the raw chunk data into the desired type.
///
/// Typical usage:
/// ```dart
/// final field = ChunkField<String>('1', (data) => data as String);
/// // Later, when the chunk arrives:
/// field.resolve('some data');
/// // Access the value:
/// final value = field.value; // 'some data'
/// ```
///
/// - [placeholderId]: The unique identifier for the placeholder/chunk.
/// - [deserializer]: Optional function to convert the raw chunk data to type [T].
/// - [state]: The current loading state of the field.
/// - [isResolved]: Whether the field has been successfully loaded.
/// - [hasError]: Whether the field failed to load.
/// - [error]: The error object if loading failed.
/// - [value]: The resolved value (throws if not loaded or error).
/// - [valueOrNull]: The resolved value or null if not loaded or error.
/// - [future]: A [Future] that completes when the value is loaded or fails with error.
///
/// Use [resolve] to provide the loaded data, or [reject] to signal an error.

final class ChunkField<T> {
  final String _placeholderId;
  final T Function(dynamic)? _deserializer;
  T? _value;
  ChunkState _state = ChunkState.pending;
  Object? _error;
  final Completer<T> _completer = Completer<T>();

  ChunkField(this._placeholderId, [this._deserializer]);

  String get placeholderId => _placeholderId;

  ChunkState get state => _state;

  bool get isResolved => _state == ChunkState.loaded;

  bool get hasError => _state == ChunkState.error;

  Object? get error => _error;

  @internal
  T Function(dynamic)? get deserializer => _deserializer;

  T get value {
    if (_state == ChunkState.error) {
      throw StateError('Chunk failed to load: $_error');
    }
    if (_state != ChunkState.loaded) {
      throw StateError(
          'Chunk not yet resolved. Use valueOrNull or await future.');
    }
    return _value as T;
  }

  T? get valueOrNull => _value;

  Future<T> get future => _completer.future;

  void resolve(dynamic data) {
    if (_completer.isCompleted) return;

    try {
      final T typedValue;

      if (data is T) {
        typedValue = data;
      } else if (_deserializer != null) {
        typedValue = _deserializer(data);
      } else {
        throw ArgumentError(
          'Cannot cast ${data.runtimeType} to $T. '
          'Provide a deserializer function.',
        );
      }

      _value = typedValue;
      _state = ChunkState.loaded;
      _completer.complete(typedValue);
    } catch (error, stackTrace) {
      _reject(error, stackTrace);
    }
  }

  void _reject(Object error, [StackTrace? stackTrace]) {
    if (_completer.isCompleted) return;

    _error = error;
    _state = ChunkState.error;
    _completer.completeError(error, stackTrace);
  }

  void reset() {
    _value = null;
    _state = ChunkState.pending;
    _error = null;
  }

  @override
  String toString() {
    switch (_state) {
      case ChunkState.pending:
        return 'ChunkField<$T>(pending: \$$_placeholderId)';
      case ChunkState.loaded:
        return 'ChunkField<$T>(loaded: $_value)';
      case ChunkState.error:
        return 'ChunkField<$T>(error: $_error)';
    }
  }

  static ChunkField<String> string(String placeholderId) =>
      ChunkField<String>(placeholderId, (data) => data.toString());

  /// Создает поле для числа
  static ChunkField<int> integer(String placeholderId) =>
      ChunkField<int>(placeholderId, (data) {
        if (data is int) return data;
        if (data is String) return int.parse(data);
        throw FormatException('Cannot parse $data as int');
      });

  /// Создает поле для числа с плавающей точкой
  static ChunkField<double> decimal(String placeholderId) =>
      ChunkField<double>(placeholderId, (data) {
        if (data is double) return data;
        if (data is int) return data.toDouble();
        if (data is String) return double.parse(data);
        throw FormatException('Cannot parse $data as double');
      });

  /// Создает поле для булева значения
  static ChunkField<bool> boolean(String placeholderId) =>
      ChunkField<bool>(placeholderId, (data) {
        if (data is bool) return data;
        if (data is String) return data.toLowerCase() == 'true';
        if (data is int) return data != 0;
        throw FormatException('Cannot parse $data as bool');
      });

  /// Создает поле для списка с десериализацией элементов
  static ChunkField<List<T>> list<T>(
    String placeholderId,
    T Function(dynamic) itemDeserializer,
  ) =>
      ChunkField<List<T>>(placeholderId, (data) {
        if (data is! List) {
          throw FormatException('Expected List, got ${data.runtimeType}');
        }
        return data.map(itemDeserializer).toList();
      });

  /// Создает поле для объекта с кастомной десериализацией
  static ChunkField<T> object<T>(
    String placeholderId,
    T Function(Map<String, dynamic>) deserializer,
  ) =>
      ChunkField<T>(placeholderId, (data) {
        if (data is! Map<String, dynamic>) {
          throw FormatException(
            'Expected Map<String, dynamic>, got ${data.runtimeType}',
          );
        }
        return deserializer(data);
      });
}
