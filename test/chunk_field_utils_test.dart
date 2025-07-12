import 'package:chunk_norris/chunk_norris.dart';
import 'package:test/test.dart';

void main() {
  group('ChunkField utils tests', () {
    group('string', () {
      test('should create ChunkField for string', () {
        final field = ChunkField.string('test-id');
        
        expect(field.placeholderId, equals('test-id'));
        expect(field.state, equals(ChunkState.pending));
        expect(field.isResolved, isFalse);
      });

      test('should deserialize string data correctly', () {
        final field = ChunkField.string('test-id');
        
        field.resolve('test string');
        
        expect(field.isResolved, isTrue);
        expect(field.value, equals('test string'));
      });

      test('should convert non-string data to string', () {
        final field = ChunkField.string('test-id');
        
        field.resolve(123);
        
        expect(field.isResolved, isTrue);
        expect(field.value, equals('123'));
      });

      test('should handle null values', () {
        final field = ChunkField.string('test-id');
        
        field.resolve(null);
        
        expect(field.isResolved, isTrue);
        expect(field.value, equals('null'));
      });
    });

    group('integer', () {
      test('should create ChunkField for int', () {
        final field = ChunkField.integer('test-id');
        
        expect(field.placeholderId, equals('test-id'));
        expect(field.state, equals(ChunkState.pending));
        expect(field.isResolved, isFalse);
      });

      test('should deserialize int data correctly', () {
        final field = ChunkField.integer('test-id');
        
        field.resolve(42);
        
        expect(field.isResolved, isTrue);
        expect(field.value, equals(42));
      });

      test('should parse string to int', () {
        final field = ChunkField.integer('test-id');
        
        field.resolve('123');
        
        expect(field.isResolved, isTrue);
        expect(field.value, equals(123));
      });

      test('should parse negative numbers from string', () {
        final field = ChunkField.integer('test-id');
        
        field.resolve('-456');
        
        expect(field.isResolved, isTrue);
        expect(field.value, equals(-456));
      });

      test('should handle FormatException for invalid string', () async {
        final field = ChunkField.integer('test-id');
        
        field.resolve('not a number');
        
        expect(field.hasError, isTrue);
        expect(field.error, isA<FormatException>());
        
        await expectLater(field.future, throwsA(isA<FormatException>()));
      });

      test('should handle FormatException for unsupported type', () async {
        final field = ChunkField.integer('test-id');
        
        field.resolve(3.14);
        
        expect(field.hasError, isTrue);
        expect(field.error, isA<FormatException>());
        
        await expectLater(field.future, throwsA(isA<FormatException>()));
      });
    });

    group('decimal', () {
      test('should create ChunkField for double', () {
        final field = ChunkField.decimal('test-id');
        
        expect(field.placeholderId, equals('test-id'));
        expect(field.state, equals(ChunkState.pending));
        expect(field.isResolved, isFalse);
      });

      test('should deserialize double data correctly', () {
        final field = ChunkField.decimal('test-id');
        
        field.resolve(3.14);
        
        expect(field.isResolved, isTrue);
        expect(field.value, equals(3.14));
      });

      test('should convert int to double', () {
        final field = ChunkField.decimal('test-id');
        
        field.resolve(42);
        
        expect(field.isResolved, isTrue);
        expect(field.value, equals(42.0));
      });

      test('should parse string to double', () {
        final field = ChunkField.decimal('test-id');
        
        field.resolve('123.45');
        
        expect(field.isResolved, isTrue);
        expect(field.value, equals(123.45));
      });

      test('should parse negative numbers from string', () {
        final field = ChunkField.decimal('test-id');
        
        field.resolve('-123.45');
        
        expect(field.isResolved, isTrue);
        expect(field.value, equals(-123.45));
      });

      test('should parse scientific notation', () {
        final field = ChunkField.decimal('test-id');
        
        field.resolve('1.23e-4');
        
        expect(field.isResolved, isTrue);
        expect(field.value, equals(1.23e-4));
      });

      test('should handle FormatException for invalid string', () async {
        final field = ChunkField.decimal('test-id');
        
        field.resolve('not a number');
        
        expect(field.hasError, isTrue);
        expect(field.error, isA<FormatException>());
        
        await expectLater(field.future, throwsA(isA<FormatException>()));
      });

      test('should handle FormatException for unsupported type', () async {
        final field = ChunkField.decimal('test-id');
        
        field.resolve(true);
        
        expect(field.hasError, isTrue);
        expect(field.error, isA<FormatException>());
        
        await expectLater(field.future, throwsA(isA<FormatException>()));
      });
    });

    group('boolean', () {
      test('should create ChunkField for bool', () {
        final field = ChunkField.boolean('test-id');
        
        expect(field.placeholderId, equals('test-id'));
        expect(field.state, equals(ChunkState.pending));
        expect(field.isResolved, isFalse);
      });

      test('should deserialize bool data correctly', () {
        final field = ChunkField.boolean('test-id');
        
        field.resolve(true);
        
        expect(field.isResolved, isTrue);
        expect(field.value, equals(true));
      });

      test('should parse "true" string to true', () {
        final field = ChunkField.boolean('test-id');
        
        field.resolve('true');
        
        expect(field.isResolved, isTrue);
        expect(field.value, equals(true));
      });

      test('should parse "TRUE" string to true (case insensitive)', () {
        final field = ChunkField.boolean('test-id');
        
        field.resolve('TRUE');
        
        expect(field.isResolved, isTrue);
        expect(field.value, equals(true));
      });

      test('should parse "false" string to false', () {
        final field = ChunkField.boolean('test-id');
        
        field.resolve('false');
        
        expect(field.isResolved, isTrue);
        expect(field.value, equals(false));
      });

      test('should parse non-zero int to true', () {
        final field = ChunkField.boolean('test-id');
        
        field.resolve(1);
        
        expect(field.isResolved, isTrue);
        expect(field.value, equals(true));
      });

      test('should parse zero int to false', () {
        final field = ChunkField.boolean('test-id');
        
        field.resolve(0);
        
        expect(field.isResolved, isTrue);
        expect(field.value, equals(false));
      });

      test('should parse negative int to true', () {
        final field = ChunkField.boolean('test-id');
        
        field.resolve(-1);
        
        expect(field.isResolved, isTrue);
        expect(field.value, equals(true));
      });

      test('should handle FormatException for unsupported type', () async {
        final field = ChunkField.boolean('test-id');
        
        field.resolve(3.14);
        
        expect(field.hasError, isTrue);
        expect(field.error, isA<FormatException>());
        
        await expectLater(field.future, throwsA(isA<FormatException>()));
      });
    });

    group('list', () {
      test('should create ChunkField for list', () {
        final field = ChunkField.list<String>('test-id', (item) => item.toString());
        
        expect(field.placeholderId, equals('test-id'));
        expect(field.state, equals(ChunkState.pending));
        expect(field.isResolved, isFalse);
      });

      test('should deserialize list of strings correctly', () {
        final field = ChunkField.list<String>('test-id', (item) => item.toString());
        
        field.resolve(['one', 'two', 'three']);
        
        expect(field.isResolved, isTrue);
        expect(field.value, equals(['one', 'two', 'three']));
      });

      test('should apply item deserializer to each element', () {
        final field = ChunkField.list<int>('test-id', (item) => int.parse(item.toString()));
        
        field.resolve(['1', '2', '3']);
        
        expect(field.isResolved, isTrue);
        expect(field.value, equals([1, 2, 3]));
      });

      test('should handle empty list', () {
        final field = ChunkField.list<String>('test-id', (item) => item.toString());
        
        field.resolve([]);
        
        expect(field.isResolved, isTrue);
        expect(field.value, equals([]));
      });

      test('should handle mixed types with deserializer', () {
        final field = ChunkField.list<String>('test-id', (item) => item.toString());
        
        field.resolve([1, 'two', 3.14, true]);
        
        expect(field.isResolved, isTrue);
        expect(field.value, equals(['1', 'two', '3.14', 'true']));
      });

      test('should handle FormatException for non-list data', () async {
        final field = ChunkField.list<String>('test-id', (item) => item.toString());
        
        field.resolve('not a list');
        
        expect(field.hasError, isTrue);
        expect(field.error, isA<FormatException>());
        
        await expectLater(field.future, throwsA(isA<FormatException>()));
      });

      test('should propagate deserializer errors', () async {
        final field = ChunkField.list<int>('test-id', (item) => int.parse(item.toString()));
        
        field.resolve(['1', 'not a number', '3']);
        
        expect(field.hasError, isTrue);
        expect(field.error, isA<FormatException>());
        
        await expectLater(field.future, throwsA(isA<FormatException>()));
      });
    });

    group('object', () {
      test('should create ChunkField for object', () {
        final field = ChunkField.object<Map<String, String>>(
          'test-id', 
          (map) => map.map((key, value) => MapEntry(key, value.toString()))
        );
        
        expect(field.placeholderId, equals('test-id'));
        expect(field.state, equals(ChunkState.pending));
        expect(field.isResolved, isFalse);
      });

      test('should deserialize map correctly', () {
        final field = ChunkField.object<Map<String, String>>(
          'test-id',
          (map) => map.map((key, value) => MapEntry(key, value.toString()))
        );
        
        field.resolve({'name': 'John', 'age': 30});
        
        expect(field.isResolved, isTrue);
        expect(field.value, equals({'name': 'John', 'age': '30'}));
      });

      test('should handle custom object deserialization', () {
        final field = ChunkField.object<Person>(
          'test-id',
          (map) => Person(map['name'] as String, map['age'] as int)
        );
        
        field.resolve({'name': 'John', 'age': 30});
        
        expect(field.isResolved, isTrue);
        expect(field.value.name, equals('John'));
        expect(field.value.age, equals(30));
      });

      test('should handle empty map', () {
        final field = ChunkField.object<Map<String, String>>(
          'test-id',
          (map) => map.map((key, value) => MapEntry(key, value.toString()))
        );
        
        field.resolve(<String, dynamic>{});
        
        expect(field.isResolved, isTrue);
        expect(field.value, equals(<String, String>{}));
      });

      test('should handle FormatException for non-map data', () async {
        final field = ChunkField.object<Map<String, String>>(
          'test-id',
          (map) => map.map((key, value) => MapEntry(key, value.toString()))
        );
        
        field.resolve('not a map');
        
        expect(field.hasError, isTrue);
        expect(field.error, isA<FormatException>());
        
        await expectLater(field.future, throwsA(isA<FormatException>()));
      });

      test('should handle FormatException for wrong map type', () async {
        final field = ChunkField.object<Map<String, String>>(
          'test-id',
          (map) => map.map((key, value) => MapEntry(key, value.toString()))
        );
        
        field.resolve(<int, String>{1: 'value'});
        
        expect(field.hasError, isTrue);
        expect(field.error, isA<FormatException>());
        
        await expectLater(field.future, throwsA(isA<FormatException>()));
      });

      test('should propagate deserializer errors', () async {
        final field = ChunkField.object<Person>(
          'test-id',
          (map) => Person(map['name'] as String, map['age'] as int)
        );
        
        field.resolve({'name': 'John'});
        
        expect(field.hasError, isTrue);
        expect(field.error, isA<TypeError>());
        
        await expectLater(field.future, throwsA(isA<TypeError>()));
      });
    });
  });
}

// Helper class for testing object deserialization
class Person {
  final String name;
  final int age;
  
  Person(this.name, this.age);
  
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Person &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          age == other.age;
          
  @override
  int get hashCode => name.hashCode ^ age.hashCode;
}
