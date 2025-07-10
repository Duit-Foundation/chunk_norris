import 'dart:async';

import 'package:chunk_norris/src/chunk_state_manager.dart';
import 'package:chunk_norris/src/placeholder_resolver.dart';
import 'package:chunk_norris/src/processor.dart';
import 'package:chunk_norris/src/state.dart';

// /// Класс для работы с Progressive JSON
// final class ChunkJson {
//   final Map<String, dynamic> _json;
//   final ChunkStateManager _stateManager;
//   final ChunkProcessor _processor;
//   final PlaceholderResolver _resolver;

//   /// Приватный конструктор
//   ChunkJson._(
//     this._json,
//     this._stateManager,
//     this._processor,
//     this._resolver,
//   );

//   /// Создать ChunkJson из начального JSON
//   factory ChunkJson.fromJson(Map<String, dynamic> json) {
//     const resolver = PlaceholderResolver();
//     final stateManager = ChunkStateManager();
//     final processor = ChunkProcessor(stateManager);
//     final chunkJson = ChunkJson._(
//       json,
//       stateManager,
//       processor,
//       resolver,
//     );

//     // Найти все плейсхолдеры и зарегистрировать их
//     final placeholders = resolver.findPlaceholders(json);
//     for (final placeholder in placeholders) {
//       stateManager.registerPlaceholder(placeholder);
//     }

//     return chunkJson;
//   }

//   /// Получить процессор чанков
//   ChunkProcessor get processor => _processor;

//   /// Получить менеджер состояний
//   ChunkStateManager get stateManager => _stateManager;

//   /// Получить доступ к исходному JSON
//   Map<String, dynamic> get json => _json;

//   /// Получить значение с автоматическим разрешением плейсхолдеров
//   dynamic getValue(String key) {
//     final value = _json[key];
//     final resolved = _resolver.resolvePlaceholders(value, _stateManager);

//     // Обеспечиваем правильную типизацию для Map
//     if (resolved is Map && resolved is! Map<String, dynamic>) {
//       return Map<String, dynamic>.from(resolved);
//     }

//     return resolved;
//   }

//   /// Получить Future для ожидания загрузки значения
//   Future<dynamic> getValueAsync(String key) async {
//     final value = _json[key];

//     if (_resolver.isPlaceholder(value)) {
//       final id = _resolver.extractPlaceholderId(value);
//       if (id != null) {
//         return _stateManager.getChunkFuture(id);
//       }
//     }

//     return value;
//   }

//   /// Получить состояние загрузки для ключа
//   ChunkState getKeyState(String key) {
//     final value = _json[key];

//     if (_resolver.isPlaceholder(value)) {
//       final id = _resolver.extractPlaceholderId(value);
//       if (id != null) {
//         return _stateManager.getChunkState(id);
//       }
//     }

//     return ChunkState.loaded;
//   }

//   /// Получить полностью разрешенные данные
//   Map<String, dynamic> getResolvedData() {
//     final resolved = _resolver.resolvePlaceholders(_json, _stateManager);

//     if (resolved is Map<String, dynamic>) {
//       return resolved;
//     } else if (resolved is Map) {
//       return Map<String, dynamic>.from(resolved);
//     } else {
//       return <String, dynamic>{};
//     }
//   }

//   /// Ожидать загрузки всех чанков
//   Future<Map<String, dynamic>> waitForAllChunks() async {
//     final placeholders = _resolver.findPlaceholders(_json);

//     if (placeholders.isEmpty) {
//       return _json;
//     }

//     // Ожидать загрузки всех плейсхолдеров
//     final futures = placeholders.map((id) => _stateManager.getChunkFuture(id));
//     await Future.wait(futures);

//     return getResolvedData();
//   }

//   /// Получить поток обновлений данных
//   Stream<Map<String, dynamic>> get updateStream => _processor.dataStream;

//   /// Получить поток ошибок
//   Stream<String> get errorStream => _processor.errorStream;

//   /// Обработать входящий чанк данных
//   void processChunk(Map<String, dynamic> chunk) {
//     _processor.processChunk(chunk);
//   }

//   /// Обработать поток чанков
//   void processChunkStream(Stream<String> chunkStream) {
//     _processor.processChunkStream(chunkStream);
//   }

//   /// Очистить все состояния
//   void clear() {
//     _stateManager.clear();
//   }

//   /// Закрыть все потоки и освободить ресурсы
//   void dispose() {
//     _processor.close();
//     _stateManager.clear();
//     json
//       ..remove("processor")
//       ..remove("stateManager")
//       ..remove("resolver");
//   }

//   /// Поддержка [] оператора для доступа к значениям
//   dynamic operator [](String key) => getValue(key);

//   /// Поддержка []= оператора для установки значений
//   void operator []=(String key, dynamic value) {
//     _json[key] = value;
//   }

//   /// Поддержка containsKey
//   bool containsKey(String key) => _json.containsKey(key);

//   /// Получить все ключи
//   Iterable<String> get keys => _json.keys;

//   /// Получить все значения (разрешенные)
//   Iterable<dynamic> get values => _json.keys.map((key) => getValue(key));

//   /// Проверить, пуст ли JSON
//   bool get isEmpty => _json.isEmpty;

//   /// Проверить, не пуст ли JSON
//   bool get isNotEmpty => _json.isNotEmpty;

//   /// Получить количество ключей
//   int get length => _json.length;

//   @override
//   String toString() => _json.toString();
// }

extension type XJson._(Map<String, dynamic> json) implements Map<String, dynamic> {
  factory XJson(final Map<String, dynamic> data) {
    const resolver = PlaceholderResolver();
    final stateManager = ChunkStateManager();
    final processor = ChunkProcessor(stateManager);

    data["processor"] = processor;
    data["stateManager"] = stateManager;
    data["resolver"] = resolver;

    // Найти все плейсхолдеры и зарегистрировать их
    final placeholders = resolver.findPlaceholders(data);
    for (final placeholder in placeholders) {
      stateManager.registerPlaceholder(placeholder);
    }

    return XJson._(data);
  }

  PlaceholderResolver get _resolver => json["resolver"];
  ChunkStateManager get _stateManager => json["stateManager"];
  ChunkProcessor get _processor => json["processor"];
  Stream<Map<String, dynamic>> get updateStream => _processor.dataStream;
  Stream<String> get errorStream => _processor.errorStream;

  /// Закрыть все потоки и освободить ресурсы
  void dispose() {
    _processor.close();
    _stateManager.clear();
    json
      ..remove("processor")
      ..remove("stateManager")
      ..remove("resolver");
  }

  ChunkState getKeyState(String key) {
    final value = json[key];

    if (_resolver.isPlaceholder(value)) {
      final id = _resolver.extractPlaceholderId(value);
      if (id != null) {
        return _stateManager.getChunkState(id);
      }
    }

    return ChunkState.loaded;
  }

  /// Получить полностью разрешенные данные
  Map<String, dynamic> getResolvedData() {
    final resolved = _resolver.resolvePlaceholders(json, _stateManager);

    if (resolved is Map<String, dynamic>) {
      return resolved;
    } else if (resolved is Map) {
      return Map<String, dynamic>.from(resolved);
    } else {
      return <String, dynamic>{};
    }
  }

  Future<Map<String, dynamic>> waitForAllChunks() async {
    final placeholders = _resolver.findPlaceholders(json);

    if (placeholders.isEmpty) {
      return json;
    }

    // Ожидать загрузки всех плейсхолдеров
    final futures = placeholders.map((id) => _stateManager.getChunkFuture(id));
    await Future.wait(futures);

    return getResolvedData();
  }

  /// Обработать входящий чанк данных
  void processChunk(Map<String, dynamic> chunk) =>
      _processor.processChunk(chunk);

  /// Обработать поток чанков
  void processChunkStream(Stream<String> chunkStream) =>
      _processor.processChunkStream(chunkStream);

  /// Получить значение с автоматическим разрешением плейсхолдеров
  dynamic getValue(String key) {
    final value = json[key];
    final resolved = _resolver.resolvePlaceholders(value, _stateManager);

    // Обеспечиваем правильную типизацию для Map
    if (resolved is Map && resolved is! Map<String, dynamic>) {
      return Map<String, dynamic>.from(resolved);
    }

    return resolved;
  }

  /// Получить Future для ожидания загрузки значения
  Future<dynamic> getValueAsync(String key) async {
    final value = json[key];

    if (_resolver.isPlaceholder(value)) {
      final id = _resolver.extractPlaceholderId(value);
      if (id != null) {
        return _stateManager.getChunkFuture(id);
      }
    }

    return value;
  }
}

void main() {
  final x = XJson({});

  print(x._processor);
}
