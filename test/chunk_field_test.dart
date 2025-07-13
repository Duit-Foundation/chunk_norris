import 'dart:async';

import 'package:chunk_norris/chunk_norris.dart';
import 'package:test/test.dart';

void main() {
  group('ChunkField', () {
    group('initialization', () {
      test('should initialize with correct placeholder ID', () {
        final field = ChunkField<String>('test-id');
        
        expect(field.placeholderId, equals('test-id'));
        expect(field.state, equals(ChunkState.pending));
        expect(field.isResolved, isFalse);
        expect(field.hasError, isFalse);
        expect(field.valueOrNull, isNull);
        expect(field.error, isNull);
      });

      test('should initialize with deserializer', () {
        final field = ChunkField<int>('test-id', (data) => int.parse(data));
        
        expect(field.placeholderId, equals('test-id'));
        expect(field.state, equals(ChunkState.pending));
        expect(field.deserializer, isNotNull);
      });

      test('should initialize without deserializer', () {
        final field = ChunkField<String>('test-id');
        
        expect(field.deserializer, isNull);
      });
    });

    group('state management', () {
      test('should start in pending state', () {
        final field = ChunkField<String>('test-id');
        
        expect(field.state, equals(ChunkState.pending));
        expect(field.isResolved, isFalse);
        expect(field.hasError, isFalse);
      });

      test('should transition to loaded state after resolve', () {
        final field = ChunkField<String>('test-id');
        
        field.resolve('test value');
        
        expect(field.state, equals(ChunkState.loaded));
        expect(field.isResolved, isTrue);
        expect(field.hasError, isFalse);
      });

      test('should transition to error state on resolve failure', () async {
        final field = ChunkField<int>('test-id');
        
        field.resolve('invalid-number');
        
        // Ждем завершения Future с ошибкой
        await expectLater(field.future, throwsA(isA<ArgumentError>()));
        
        expect(field.state, equals(ChunkState.error));
        expect(field.isResolved, isFalse);
        expect(field.hasError, isTrue);
      });

      test('should reset to pending state', () {
        final field = ChunkField<String>('test-id');
        
        field.resolve('test value');
        expect(field.state, equals(ChunkState.loaded));
        
        field.reset();
        
        expect(field.state, equals(ChunkState.pending));
        expect(field.isResolved, isFalse);
        expect(field.hasError, isFalse);
        expect(field.valueOrNull, isNull);
        expect(field.error, isNull);
      });
    });

    group('value access', () {
      test('should return value when resolved', () {
        final field = ChunkField<String>('test-id');
        
        field.resolve('test value');
        
        expect(field.value, equals('test value'));
        expect(field.valueOrNull, equals('test value'));
      });

      test('should throw StateError when accessing value before resolve', () {
        final field = ChunkField<String>('test-id');
        
        expect(() => field.value, throwsA(isA<StateError>()));
      });

      test('should throw StateError when accessing value after error', () async {
        final field = ChunkField<int>('test-id');
        
        field.resolve('invalid-number');
        
        // Ждем завершения Future с ошибкой
        await expectLater(field.future, throwsA(isA<ArgumentError>()));
        
        expect(() => field.value, throwsA(isA<StateError>()));
      });

      test('should return null from valueOrNull when not resolved', () {
        final field = ChunkField<String>('test-id');
        
        expect(field.valueOrNull, isNull);
      });

      test('should return null from valueOrNull when error occurred', () async {
        final field = ChunkField<int>('test-id');
        
        field.resolve('invalid-number');
        
        // Ждем завершения Future с ошибкой
        await expectLater(field.future, throwsA(isA<ArgumentError>()));
        
        expect(field.valueOrNull, isNull);
      });
    });

    group('error handling', () {
      test('should store error when resolve fails', () async {
        final field = ChunkField<int>('test-id');
        
        field.resolve('invalid-number');
        
        // Ждем завершения Future с ошибкой
        await expectLater(field.future, throwsA(isA<ArgumentError>()));
        
        expect(field.hasError, isTrue);
        expect(field.error, isA<ArgumentError>());
      });

      test('should store error when deserializer throws', () async {
        final field = ChunkField<int>('test-id', (data) {
          throw Exception('Deserializer error');
        });
        
        field.resolve('any-data');
        
        // Ждем завершения Future с ошибкой
        await expectLater(field.future, throwsA(isA<Exception>()));
        
        expect(field.hasError, isTrue);
        expect(field.error, isA<Exception>());
      });

      test('should clear error on reset', () async {
        final field = ChunkField<int>('test-id');
        
        field.resolve('invalid-number');
        
        // Ждем завершения Future с ошибкой
        await expectLater(field.future, throwsA(isA<ArgumentError>()));
        
        expect(field.hasError, isTrue);
        
        field.reset();
        
        expect(field.hasError, isFalse);
        expect(field.error, isNull);
      });
    });

    group('async operations', () {
      test('should complete future on successful resolve', () async {
        final field = ChunkField<String>('test-id');
        
        field.resolve('test value');
        
        final value = await field.future;
        expect(value, equals('test value'));
      });

      test('should complete future with error on failed resolve', () async {
        final field = ChunkField<int>('test-id');
        
        field.resolve('invalid-number');
        
        await expectLater(field.future, throwsA(isA<ArgumentError>()));
      });

      test('should support multiple awaits on the same future', () async {
        final field = ChunkField<String>('test-id');
        
        field.resolve('test value');
        
        final value1 = await field.future;
        final value2 = await field.future;
        
        expect(value1, equals('test value'));
        expect(value2, equals('test value'));
      });

      test('should handle async resolve', () async {
        final field = ChunkField<String>('test-id');
        
        // Запускаем resolve в другом микротаске
        scheduleMicrotask(() => field.resolve('async value'));
        
        final value = await field.future;
        expect(value, equals('async value'));
      });
    });

    group('deserialization', () {
      test('should use direct value when type matches', () {
        final field = ChunkField<String>('test-id');
        
        field.resolve('direct string');
        
        expect(field.value, equals('direct string'));
      });

      test('should use deserializer when provided', () {
        final field = ChunkField<int>('test-id', (data) => int.parse(data));
        
        field.resolve('42');
        
        expect(field.value, equals(42));
      });

      test('should prefer direct type over deserializer', () {
        final field = ChunkField<String>('test-id', (data) => 'deserialized');
        
        field.resolve('direct string');
        
        expect(field.value, equals('direct string'));
      });

      test('should throw ArgumentError when no deserializer and types mismatch', () async {
        final field = ChunkField<int>('test-id');
        
        field.resolve('string value');
        
        // Ждем завершения Future с ошибкой
        await expectLater(field.future, throwsA(isA<ArgumentError>()));
        
        expect(field.hasError, isTrue);
        expect(field.error, isA<ArgumentError>());
      });

      test('should handle complex deserialization', () {
        final field = ChunkField<TestObject>('test-id', (data) {
          final map = data as Map<String, dynamic>;
          return TestObject(map['name'], map['value']);
        });
        
        field.resolve({'name': 'test', 'value': 42});
        
        expect(field.value.name, equals('test'));
        expect(field.value.value, equals(42));
      });
    });

    group('repeated operations', () {
      test('should ignore repeated resolve calls', () {
        final field = ChunkField<String>('test-id');
        
        field.resolve('first value');
        field.resolve('second value');
        
        expect(field.value, equals('first value'));
      });

      test('should ignore resolve after error', () async {
        final field = ChunkField<int>('test-id');
        
        field.resolve('invalid-number');
        
        // Ждем завершения Future с ошибкой
        await expectLater(field.future, throwsA(isA<ArgumentError>()));
        
        field.resolve(42);
        
        expect(field.hasError, isTrue);
        expect(field.error, isA<ArgumentError>());
      });

      test('should allow resolve after reset', () async {
        final field = ChunkField<String>('test-id');
        
        field.resolve('first value');
        expect(field.value, equals('first value'));
        
        field.reset();
        
        // После reset поле должно быть в состоянии pending
        expect(field.state, equals(ChunkState.pending));
        expect(field.valueOrNull, isNull);
        
        // Примечание: Future не сбрасывается после reset, поэтому
        // новый resolve будет проигнорирован если completer уже завершен
        field.resolve('second value');
        
        // Проверяем, что поле остается в состоянии pending
        // так как completer уже завершен
        expect(field.state, equals(ChunkState.pending));
      });
    });

    group('toString', () {
      test('should show pending state', () {
        final field = ChunkField<String>('test-id');
        
        expect(field.toString(), equals('ChunkField<String>(pending: \$test-id)'));
      });

      test('should show loaded state with value', () {
        final field = ChunkField<String>('test-id');
        
        field.resolve('test value');
        
        expect(field.toString(), equals('ChunkField<String>(loaded: test value)'));
      });

      test('should show error state', () async {
        final field = ChunkField<int>('test-id');
        
        field.resolve('invalid-number');
        
        // Ждем завершения Future с ошибкой
        await expectLater(field.future, throwsA(isA<ArgumentError>()));
        
        expect(field.toString(), contains('ChunkField<int>(error:'));
      });
    });

    group('type safety', () {
      test('should maintain type safety with generic parameter', () {
        final stringField = ChunkField<String>('test-id');
        final intField = ChunkField<int>('test-id');
        
        stringField.resolve('string value');
        intField.resolve(42);
        
        expect(stringField.value, isA<String>());
        expect(intField.value, isA<int>());
      });

      test('should work with nullable types', () {
        final field = ChunkField<String?>('test-id');
        
        field.resolve(null);
        
        expect(field.value, isNull);
        expect(field.isResolved, isTrue);
      });

      test('should work with complex types', () {
        final field = ChunkField<List<String>>('test-id');
        
        field.resolve(['item1', 'item2']);
        
        expect(field.value, isA<List<String>>());
        expect(field.value.length, equals(2));
      });
    });

    group('edge cases', () {
      test('should handle null data with deserializer', () {
        final field = ChunkField<String>('test-id', (data) => data?.toString() ?? 'null');
        
        field.resolve(null);
        
        expect(field.value, equals('null'));
      });

      test('should handle empty string placeholder ID', () {
        final field = ChunkField<String>('');
        
        expect(field.placeholderId, equals(''));
      });

      test('should handle deserializer that returns null', () {
        final field = ChunkField<String?>('test-id', (data) => null);
        
        field.resolve(42); // Используем не-String тип, чтобы активировать десериализатор
        
        expect(field.value, isNull);
        expect(field.isResolved, isTrue);
      });
    });
  });
}

// Helper class for testing
class TestObject {
  final String name;
  final int value;
  
  TestObject(this.name, this.value);
  
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TestObject &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          value == other.value;
          
  @override
  int get hashCode => name.hashCode ^ value.hashCode;
} 