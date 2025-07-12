import 'dart:async';

import 'package:collection/collection.dart';

import 'chunk_state_manager.dart';
import 'placeholder_resolver.dart';
import 'processor.dart';
import 'state.dart';
import 'chunk_field.dart';

final class ChunkObject<T> {
  final Map<String, dynamic> _initialJson;
  final T Function(Map<String, dynamic>) _deserializer;
  final ChunkStateManager _stateManager;
  final ChunkProcessor _processor;
  final PlaceholderResolver _resolver;
  late final Map<String, ChunkField> _chunkFields;

  T? _cachedResult;
  bool _isCacheValid = false;

  ChunkObject._(
    this._initialJson,
    this._deserializer,
    this._stateManager,
    this._processor,
    this._resolver,
  );

  factory ChunkObject.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) deserializer, {
    Map<String, ChunkField>? chunkFields,
  }) {
    const resolver = PlaceholderResolver();
    final stateManager = ChunkStateManager();
    final processor = ChunkProcessor(stateManager);

    final typedJson = ChunkObject._(
      json,
      deserializer,
      stateManager,
      processor,
      resolver,
    );

    final placeholders = resolver.findPlaceholders(json);

    // Регистрируем чанк поля если предоставлены
    if (chunkFields != null) {
      typedJson._chunkFields = chunkFields
        ..forEach((key, value) {
          stateManager.registerPlaceholder(value.placeholderId);
          placeholders.remove(value.placeholderId);
        });
      for (final placeholderId in placeholders) {
        stateManager.registerPlaceholder(placeholderId);
      }
    } else {
      for (final placeholderId in placeholders) {
        stateManager.registerPlaceholder(placeholderId);
      }
    }

    // Подписываемся на обновления процессора
    processor.dataStream.listen(typedJson._handleChunkUpdate);

    return typedJson;
  }

  /// Исходный JSON
  Map<String, dynamic> get initialJson => _initialJson;

  /// Зарегистрированные чанк поля
  Map<String, ChunkField> get chunkFields => Map.unmodifiable(_chunkFields);

  /// Поток чанков с предварительным парсингом: если для ключа есть ChunkField с десериализатором, то парсит значение
  Stream<dynamic> get _chunkUpdateStream => _processor.dataStream.map((chunk) {
        dynamic result;
        chunk.forEach((key, value) {
          final field = _chunkFields.values.firstWhereOrNull(
            (f) => f.placeholderId == key,
          );

          if (field != null) {
            if (field.isResolved) {
              result = field.value;
              return;
            }

            try {
              result = field.deserializer!.call(value);
            } catch (e) {
              result = value; // fallback
            }
          } else {
            result = value;
          }
        });
        return result;
      });

  StreamSubscription<dynamic> listenChunkUpdate(
    void Function(dynamic) onData, {
    Function(Object)? onError,
    void Function()? onDone,
  }) =>
      _chunkUpdateStream.listen(
        onData,
        onError: onError,
        onDone: onDone,
      );

  StreamSubscription<T> listenObjectResolve(
    void Function(T) onData, {
    Function(Object)? onError,
    void Function()? onDone,
  }) =>
      _fullyResolvedStream.listen(
        onData,
        onError: onError,
        onDone: onDone,
      );

  StreamSubscription<dynamic> listenRawChunkUpdate(
    void Function(dynamic) onData, {
    Function(Object)? onError,
    void Function()? onDone,
  }) =>
      _processor.dataStream.listen(
        onData,
        onError: onError,
        onDone: onDone,
      );

  StreamSubscription<T> listenObjectUpdate(
    void Function(T) onData, {
    Function(Object)? onError,
    void Function()? onDone,
  }) =>
      _typedUpdateStream.listen(
        onData,
        onError: onError,
        onDone: onDone,
      );

  StreamSubscription<Map<String, ChunkState>> listenChunkStates(
    void Function(Map<String, ChunkState>) onData, {
    Function(Object)? onError,
    void Function()? onDone,
  }) =>
      _chunkStatesStream.listen(
        onData,
        onError: onError,
        onDone: onDone,
      );

  /// Поток обновлений типизированных данных
  /// Эмитит события при каждом обновлении чанка
  Stream<T> get _typedUpdateStream => _processor.dataStream
      .map((_) => getDataOrNull())
      .where((data) => data != null)
      .cast<T>();

  /// Поток, который эмитит только когда ВСЕ чанки разрешены
  Stream<T> get _fullyResolvedStream => _processor.dataStream
      .skipWhile((_) => !allChunksResolved)
      .map((_) => getData());

  /// Поток состояний чанков
  Stream<Map<String, ChunkState>> get _chunkStatesStream =>
      _processor.dataStream.map((_) => _getChunkStates());

  /// Проверяет, все ли чанки разрешены
  bool get allChunksResolved {
    final states = _getChunkStates();
    return states.values.every((state) => state == ChunkState.loaded);
  }

  /// Регистрирует чанк поле для типизированного доступа
  void registerChunkField(String key, ChunkField field) {
    _chunkFields[key] = field;
    _stateManager.registerPlaceholder(field.placeholderId);
    _invalidateCache();
  }

  /// Получает чанк поле по ключу
  ChunkField getChunkField<V>(String key) {
    final field = _chunkFields[key];
    if (field is ChunkField<V>) {
      return field;
    }
    throw StateError('Chunk field $key not found');
  }

  /// Обрабатывает входящий чанк данных
  void processChunk(Map<String, dynamic> chunk) =>
      _processor.processChunk(chunk);

  /// Обрабатывает поток чанков
  void processChunkStream(Stream<String> chunkStream) =>
      _processor.processChunkStream(chunkStream);

  /// Получает типизированные данные (throw если не все чанки загружены)
  T getData() {
    if (_isCacheValid && _cachedResult != null) {
      return _cachedResult!;
    }

    final resolvedJson = _getResolvedJson();
    try {
      final result = _deserializer(resolvedJson);
      _cachedResult = result;
      _isCacheValid = true;
      return result;
    } catch (error) {
      throw StateError('Failed to deserialize data: $error');
    }
  }

  /// Получает типизированные данные или null если не готово
  T? getDataOrNull() {
    try {
      // Проверяем, можно ли десериализовать с текущими данными
      final resolvedJson = _getResolvedJson();

      // Проверяем, остались ли неразрешенные плейсхолдеры
      final hasUnresolvedPlaceholders =
          _resolver.findPlaceholders(resolvedJson).isNotEmpty;

      // Если есть неразрешенные плейсхолдеры, пытаемся частичную десериализацию
      if (hasUnresolvedPlaceholders) {
        // Проверяем, есть ли хотя бы базовые поля для десериализации
        if (!_hasMinimalDataForDeserialization(resolvedJson)) {
          return null;
        }
      }

      final result = _deserializer(resolvedJson);

      // Обновляем кеш только если все чанки разрешены
      if (!hasUnresolvedPlaceholders) {
        _cachedResult = result;
        _isCacheValid = true;
      }

      return result;
    } catch (_) {
      return null;
    }
  }

  /// Проверяет, есть ли минимальные данные для десериализации
  bool _hasMinimalDataForDeserialization(Map<String, dynamic> json) {
    // Проверяем, что основные поля (не плейсхолдеры) присутствуют
    // Это помогает избежать десериализации с критически важными плейсхолдерами
    return json.values.any((value) => !_resolver.isPlaceholder(value));
  }

  /// Получает карту состояний всех чанков
  Map<String, ChunkState> _getChunkStates() {
    final states = <String, ChunkState>{};

    // Состояния из зарегистрированных полей
    for (final entry in _chunkFields.entries) {
      states[entry.key] = entry.value.state;
    }

    // Состояния из placeholder resolver (fallback)
    final placeholders = _resolver.findPlaceholders(_initialJson);
    for (final placeholderId in placeholders) {
      final state = _stateManager.getChunkState(placeholderId);
      states[placeholderId] = state;
    }

    return states;
  }

  /// Ожидает загрузки всех чанков и возвращает типизированные данные
  Future<T> waitForData() async {
    if (allChunksResolved) {
      return getData();
    }

    // Ждем все поля чанков
    if (_chunkFields.isNotEmpty) {
      await Future.wait(_chunkFields.values.map((field) => field.future));
    } else {
      // Fallback к обычному ожиданию
      final placeholders = _resolver.findPlaceholders(_initialJson);
      final futures =
          placeholders.map((id) => _stateManager.getChunkFuture(id));
      await Future.wait(futures);
    }

    return getData();
  }

  /// Проверяет, готово ли конкретное поле
  bool isFieldReady(String fieldKey) {
    final field = _chunkFields[fieldKey];
    return field?.isResolved ?? false;
  }

  /// Получает состояние конкретного поля
  ChunkState getFieldState(String fieldKey) {
    final field = _chunkFields[fieldKey];
    return field?.state ?? ChunkState.pending;
  }

  /// Получает ошибку поля (если есть)
  Object? getFieldError(String fieldKey) {
    final field = _chunkFields[fieldKey];
    return field?.error;
  }

  /// Сбрасывает все состояния
  void clear() {
    _stateManager.clear();
    for (final field in _chunkFields.values) {
      field.reset();
    }
    _invalidateCache();
  }

  /// Освобождает ресурсы
  void dispose() {
    _processor.close();
    _stateManager.clear();
    _chunkFields.clear();
  }

  /// Обрабатывает обновление чанка
  void _handleChunkUpdate(Map<String, dynamic> chunk) {
    _invalidateCache();

    // Обновляем соответствующие чанк поля
    for (final entry in chunk.entries) {
      final field = _chunkFields.values
          .where((f) => f.placeholderId == entry.key)
          .firstOrNull;

      if (field != null && !field.isResolved) {
        field.resolve(entry.value);
      } else {
        // Если поле не было явно создано, просто обновляем stateManager
        _stateManager.resolvePlaceholder(entry.key, entry.value);
      }
    }
  }

  /// Получает разрешенный JSON
  Map<String, dynamic> _getResolvedJson() {
    final resolved = _resolver.resolvePlaceholders(_initialJson, _stateManager);

    if (resolved is Map<String, dynamic>) {
      return resolved;
    } else if (resolved is Map) {
      return Map<String, dynamic>.from(resolved);
    } else {
      throw StateError('Resolved data is not a Map');
    }
  }

  /// Инвалидирует кеш
  void _invalidateCache() {
    _isCacheValid = false;
    _cachedResult = null;
  }

  @override
  String toString() {
    if (allChunksResolved) {
      return 'ChunkObject<$T>(resolved: ${getData()})';
    } else {
      final pendingFields = _chunkFields.entries
          .where((entry) => !entry.value.isResolved)
          .map((entry) => entry.key)
          .toList();
      return 'ChunkObject<$T>(pending: $pendingFields)';
    }
  }
}
