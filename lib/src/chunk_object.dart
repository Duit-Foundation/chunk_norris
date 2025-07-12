import 'dart:async';

import 'package:meta/meta.dart';

import 'chunk_state_manager.dart';
import 'placeholder_resolver.dart';
import 'processor.dart';
import 'state.dart';
import 'chunk_field.dart';

extension type ReadOnlyMap<K, V>(Map<K, V> map) implements Map<K, V> {
  operator []=(K key, V value) => throw UnimplementedError();
  @redeclare
  void addAll(Map<K, V> other) => throw UnimplementedError();

  @redeclare
  void remove(K key) => throw UnimplementedError();

  @redeclare
  void clear() => throw UnimplementedError();

  @redeclare
  void update(K key, V value) => throw UnimplementedError();

  @redeclare
  void updateAll(Map<K, V> other) => throw UnimplementedError();

  @redeclare
  void removeWhere(bool Function(K key, V value) test) =>
      throw UnimplementedError();
}

/// Типизированная версия ChunkJson для полной типобезопасности
///
/// Обеспечивает автоматическую десериализацию типов
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

  /// Создает типизированный ChunkJson из JSON и десериализатора
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

    // Регистрируем чанк поля если предоставлены
    if (chunkFields != null) {
      typedJson._chunkFields = chunkFields
        ..forEach((key, value) {
          stateManager.registerPlaceholder(value.placeholderId);
        });
    } else {
      // Автоматически находим плейсхолдеры
      final placeholders = resolver.findPlaceholders(json);
      for (final placeholderId in placeholders) {
        stateManager.registerPlaceholder(placeholderId);
      }
    }

    // Подписываемся на обновления процессора
    processor.dataStream.listen((chunk) {
      typedJson._handleChunkUpdate(chunk);
    });

    return typedJson;
  }

  /// Исходный JSON
  Map<String, dynamic> get initialJson => _initialJson;

  /// Зарегистрированные чанк поля
  ReadOnlyMap<String, ChunkField> get chunkFields => ReadOnlyMap(_chunkFields);

  /// Поток обновлений типизированных данных
  /// Эмитит события при каждом обновлении чанка
  Stream<T> get typedUpdateStream => _processor.dataStream
      .map((_) => getTypedDataOrNull())
      .where((data) => data != null)
      .cast<T>();

  /// Поток, который эмитит только когда ВСЕ чанки разрешены
  Stream<T> get fullyResolvedStream => _processor.dataStream
      .where((_) => allChunksResolved)
      .map((_) => getTypedData());

  /// Поток состояний чанков
  Stream<Map<String, ChunkState>> get chunkStatesStream =>
      _processor.dataStream.map((_) => _getChunkStates());

  /// Поток ошибок
  Stream<String> get errorStream => _processor.errorStream;

  /// Проверяет, все ли чанки разрешены
  bool get allChunksResolved {
    if (_chunkFields.isNotEmpty) {
      return _chunkFields.values.every((field) => field.isResolved);
    }

    // Fallback к обычной проверке плейсхолдеров
    final placeholders = _resolver.findPlaceholders(_initialJson);
    return placeholders
        .every((id) => _stateManager.getChunkState(id) == ChunkState.loaded);
  }

  /// Регистрирует чанк поле для типизированного доступа
  void registerChunkField(String key, ChunkField field) {
    _chunkFields[key] = field;
    _stateManager.registerPlaceholder(field.placeholderId);
    _invalidateCache();
  }

  /// Получает чанк поле по ключу
  ChunkField<V>? getChunkField<V>(String key) {
    final field = _chunkFields[key];
    if (field is ChunkField<V>) {
      return field;
    }
    return null;
  }

  /// Обрабатывает входящий чанк данных
  void processChunk(Map<String, dynamic> chunk) {
    _processor.processChunk(chunk);
  }

  /// Обрабатывает поток чанков
  void processChunkStream(Stream<String> chunkStream) {
    _processor.processChunkStream(chunkStream);
  }

  /// Обрабатывает типизированный чанк
  void processTypedChunk<V>(String chunkId, V data) {
    final field = _chunkFields.values
        .where((f) => f.placeholderId == chunkId)
        .firstOrNull;

    if (field != null) {
      field.resolve(data);
    }

    // Также обрабатываем через обычный процессор
    processChunk({chunkId: data});
  }

  /// Получает типизированные данные (throw если не все чанки загружены)
  T getTypedData() {
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
  T? getTypedDataOrNull() {
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
      if (!states.values.any((state) => state != ChunkState.pending)) {
        states[placeholderId] = _stateManager.getChunkState(placeholderId);
      }
    }

    return states;
  }

  /// Ожидает загрузки всех чанков и возвращает типизированные данные
  Future<T> waitForTypedData() async {
    if (allChunksResolved) {
      return getTypedData();
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

    return getTypedData();
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
      return 'TypedChunkJson<$T>(resolved: ${getTypedData()})';
    } else {
      final pendingFields = _chunkFields.entries
          .where((entry) => !entry.value.isResolved)
          .map((entry) => entry.key)
          .toList();
      return 'TypedChunkJson<$T>(pending: $pendingFields)';
    }
  }
}

// /// Builder для удобного создания типизированных ChunkJson
// class TypedChunkJsonBuilder<T> {
//   final Map<String, dynamic> _json = {};
//   final Map<String, ChunkField> _fields = {};
//   final T Function(Map<String, dynamic>) _deserializer;

//   TypedChunkJsonBuilder(this._deserializer);

//   /// Добавляет обычное поле
//   TypedChunkJsonBuilder<T> addField(String key, dynamic value) {
//     _json[key] = value;
//     return this;
//   }

//   /// Добавляет типизированное чанк поле
//   TypedChunkJsonBuilder<T> addChunkField<V>(String key, ChunkField<V> field) {
//     _json[key] = '\$${field.placeholderId}';
//     _fields[key] = field;
//     return this;
//   }

//   /// Строит TypedChunkJson
//   ChunkObject<T> build() {
//     return ChunkObject.fromJson(_json, _deserializer, chunkFields: _fields);
//   }
// }
