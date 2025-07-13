import 'dart:async';

import 'package:chunk_norris/chunk_norris.dart';
import 'package:test/test.dart';

// Test models
class User {
  final String name;
  final int age;
  final String email;

  User({required this.name, required this.age, required this.email});

  factory User.fromJson(Map<String, dynamic> json) => User(
        name: json['name'],
        age: json['age'],
        email: json['email'],
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is User &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          age == other.age &&
          email == other.email;

  @override
  int get hashCode => name.hashCode ^ age.hashCode ^ email.hashCode;

  @override
  String toString() => 'User(name: $name, age: $age, email: $email)';
}

class Product {
  final String title;
  final double price;
  final bool available;

  Product({required this.title, required this.price, required this.available});

  factory Product.fromJson(Map<String, dynamic> json) => Product(
        title: json['title'],
        price: json['price'],
        available: json['available'],
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Product &&
          runtimeType == other.runtimeType &&
          title == other.title &&
          price == other.price &&
          available == other.available;

  @override
  int get hashCode => title.hashCode ^ price.hashCode ^ available.hashCode;

  @override
  String toString() =>
      'Product(title: $title, price: $price, available: $available)';
}

void main() {
  group('ChunkObject', () {
    group('initialization', () {
      test('should initialize with JSON without placeholders', () async {
        final json = {
          'name': 'John Doe',
          'age': 30,
          'email': 'john@example.com',
        };

        final userObject = ChunkObject.fromJson(json, User.fromJson);

        expect(userObject.allChunksResolved, isTrue);
        expect(userObject.chunkFields, isEmpty);

        final user = userObject.getData();
        expect(user.name, equals('John Doe'));
        expect(user.age, equals(30));
        expect(user.email, equals('john@example.com'));
      });

      test('should initialize with JSON containing placeholders', () async {
        final json = {
          'name': '\$123',
          'age': 30,
          'email': '\$456',
        };

        final userObject = ChunkObject.fromJson(json, User.fromJson);

        expect(userObject.allChunksResolved, isFalse);
        expect(userObject.chunkFields, isEmpty);
      });

      test('should initialize with chunk fields', () async {
        final json = {
          'name': '\$123',
          'age': 30,
          'email': '\$456',
        };

        final nameField = ChunkField<String>('123');
        final emailField = ChunkField<String>('456');

        final userObject = ChunkObject.fromJson(
          json,
          User.fromJson,
          chunkFields: {
            'name': nameField,
            'email': emailField,
          },
        );

        expect(userObject.allChunksResolved, isFalse);
        expect(userObject.chunkFields, hasLength(2));
        expect(userObject.chunkFields['name'], equals(nameField));
        expect(userObject.chunkFields['email'], equals(emailField));
      });

      test('should initialize with custom placeholder pattern', () async {
        final json = {
          'name': '{{123}}',
          'age': 30,
          'email': '{{456}}',
        };

        final userObject = ChunkObject.fromJson(
          json,
          User.fromJson,
          placeholderPattern: RegExp(r'^\{\{(\d+)\}\}$'),
        );

        expect(userObject.allChunksResolved, isFalse);
      });
    });

    group('chunk processing', () {
      test('should process single chunk', () async {
        final json = {
          'name': '\$123',
          'age': 30,
          'email': 'john@example.com',
        };

        final userObject = ChunkObject.fromJson(json, User.fromJson);

        expect(userObject.allChunksResolved, isFalse);
        expect(userObject.getDataOrNull(), isNull);

        await userObject.processChunk({'123': 'John Doe'});

        expect(userObject.allChunksResolved, isTrue);
        final user = userObject.getData();
        expect(user.name, equals('John Doe'));
        expect(user.age, equals(30));
        expect(user.email, equals('john@example.com'));
      });

      test('should process multiple chunks', () async {
        final json = {
          'name': '\$123',
          'age': 30,
          'email': '\$456',
        };

        final userObject = ChunkObject.fromJson(json, User.fromJson);

        expect(userObject.allChunksResolved, isFalse);

        await userObject.processChunk({'123': 'John Doe'});
        expect(userObject.allChunksResolved, isFalse);

        await userObject.processChunk({'456': 'john@example.com'});
        expect(userObject.allChunksResolved, isTrue);

        final user = userObject.getData();
        expect(user.name, equals('John Doe'));
        expect(user.age, equals(30));
        expect(user.email, equals('john@example.com'));
      });

      test('should handle chunk stream', () async {
        final json = {
          'name': '\$123',
          'age': 30,
          'email': '\$456',
        };

        final userObject = ChunkObject.fromJson(json, User.fromJson);

        final controller = StreamController<String>();
        userObject.processChunkStream(controller.stream);

        controller.add('{"123": "John Doe"}');
        controller.add('{"456": "john@example.com"}');

        await Future.delayed(Duration(milliseconds: 10));

        expect(userObject.allChunksResolved, isTrue);
        final user = userObject.getData();
        expect(user.name, equals('John Doe'));
        expect(user.email, equals('john@example.com'));

        controller.close();
      });
    });

    group('data access', () {
      test('should return null when data is not ready', () async {
        final json = {
          'name': '\$123',
          'age': 30,
          'email': '\$456',
        };

        final userObject = ChunkObject.fromJson(json, User.fromJson);

        expect(userObject.getDataOrNull(), isNull);
      });

      test('should return partial data when possible', () async {
        final json = {
          'name': '\$123',
          'age': 30,
          'email': 'john@example.com',
        };

        final userObject = ChunkObject.fromJson(json, User.fromJson);

        // Should return null because deserializer expects valid name
        expect(userObject.getDataOrNull(), isNull);

        await userObject.processChunk({'123': 'John Doe'});

        final user = userObject.getData();
        expect(user.name, equals('John Doe'));
        expect(user.age, equals(30));
        expect(user.email, equals('john@example.com'));
      });

      test('should throw error when getData called on incomplete data', () async {
        final json = {
          'name': '\$123',
          'age': 30,
          'email': '\$456',
        };

        final userObject = ChunkObject.fromJson(json, User.fromJson);

        expect(() => userObject.getData(), throwsStateError);
      });

      test('should wait for data asynchronously', () async {
        final json = {
          'name': '\$123',
          'age': 30,
          'email': '\$456',
        };

        final userObject = ChunkObject.fromJson(json, User.fromJson);

        final userFuture = userObject.waitForData();

        // Process chunks after a delay
        Timer(Duration(milliseconds: 10), () async {
          await userObject.processChunk({'123': 'John Doe'});
        });

        Timer(Duration(milliseconds: 20), () async {
          await userObject.processChunk({'456': 'john@example.com'});
        });

        final user = await userFuture;
        expect(user.name, equals('John Doe'));
        expect(user.age, equals(30));
        expect(user.email, equals('john@example.com'));
      });
    });

    group('chunk fields', () {
      test('should resolve chunk fields', () async {
        final json = {
          'name': '\$123',
          'age': 30,
          'email': '\$456',
        };

        final nameField = ChunkField.string('123');
        final emailField = ChunkField.string('456');

        final userObject = ChunkObject.fromJson(
          json,
          User.fromJson,
          chunkFields: {
            'name': nameField,
            'email': emailField,
          },
        );

        expect(userObject.isFieldReady('name'), isFalse);
        // expect(userObject.isFieldReady('email'), isFalse);
        // expect(userObject.getFieldState('name'), equals(ChunkState.pending));
        // expect(userObject.getFieldState('email'), equals(ChunkState.pending));

        await userObject.processChunk({'123': 'John Doe'});

        // Add a small delay to allow async processing
        await Future.delayed(Duration(milliseconds: 100));

        expect(userObject.isFieldReady('name'), isTrue);
        expect(userObject.isFieldReady('email'), isFalse);
        expect(userObject.getFieldState('name'), equals(ChunkState.loaded));
        expect(userObject.getFieldState('email'), equals(ChunkState.pending));
        expect(nameField.value, equals('John Doe'));
        expect(emailField.isResolved, isFalse);

        await userObject.processChunk({'456': 'john@example.com'});
        await Future.delayed(Duration(milliseconds: 100));

        expect(userObject.isFieldReady('email'), isTrue);
        expect(userObject.getFieldState('email'), equals(ChunkState.loaded));
        expect(emailField.value, equals('john@example.com'));
      });

      test('should get chunk field by key', () async {
        final json = {
          'name': '\$123',
          'age': 30,
          'email': '\$456',
        };

        final nameField = ChunkField<String>('123');
        final emailField = ChunkField<String>('456');

        final userObject = ChunkObject.fromJson(
          json,
          User.fromJson,
          chunkFields: {
            'name': nameField,
            'email': emailField,
          },
        );

        final retrievedNameField = userObject.getChunkField<String>('name');
        expect(retrievedNameField, equals(nameField));

        final retrievedEmailField = userObject.getChunkField<String>('email');
        expect(retrievedEmailField, equals(emailField));
      });

      test('should throw error when getting non-existent field', () async {
        final json = {
          'name': '\$123',
          'age': 30,
          'email': '\$456',
        };

        final userObject = ChunkObject.fromJson(json, User.fromJson);

        expect(() => userObject.getChunkField('nonexistent'), throwsStateError);
      });

      test('should handle chunk field deserializers', () async {
        final json = {
          'title': '\$123',
          'price': '\$456',
          'available': true,
        };

        final titleField = ChunkField<String>('123');
        final priceField =
            ChunkField<double>('456', (data) => double.parse(data));

        final productObject = ChunkObject.fromJson(
          json,
          Product.fromJson,
          chunkFields: {
            'title': titleField,
            'price': priceField,
          },
        );

        await productObject.processChunk({'123': 'Test Product'});
        await productObject.processChunk({'456': 29.99});

        expect(await titleField.future, equals('Test Product'));
        expect(await priceField.future, equals(29.99));

        final product = await productObject.waitForData();
        expect(product.title, equals('Test Product'));
        expect(product.price, equals(29.99));
        expect(product.available, isTrue);
      });
    });

    group('streams', () {
      test('should emit object updates', () async {
        final json = {
          'name': '\$123',
          'age': 30,
          'email': '\$456',
        };

        final userObject = ChunkObject.fromJson(json, User.fromJson);

        final updates = <User>[];
        final subscription = userObject.listenObjectUpdate((user) {
          updates.add(user);
        });

        // Process chunks with delays
        Timer(Duration(milliseconds: 10), () async {
          await userObject.processChunk({'123': 'John Doe'});
        });

        Timer(Duration(milliseconds: 20), () async {
          await userObject.processChunk({'456': 'john@example.com'});
        });

        await Future.delayed(Duration(milliseconds: 50));

        expect(updates, hasLength(1));
        expect(updates[0].name, equals('John Doe'));
        expect(updates[0].email, equals('john@example.com'));

        subscription.cancel();
      });

      test('should emit object resolution only when complete', () async {
        final json = {
          'name': '\$123',
          'age': 30,
          'email': '\$456',
        };

        final userObject = ChunkObject.fromJson(json, User.fromJson);

        final resolvedUsers = <User>[];
        final subscription = userObject.listenObjectResolve((user) {
          resolvedUsers.add(user);
        });

        // Process first chunk
        Timer(Duration(milliseconds: 10), () async {
          await userObject.processChunk({'123': 'John Doe'});
        });

        await Future.delayed(Duration(milliseconds: 20));
        expect(resolvedUsers, isEmpty);

        // Process second chunk
        Timer(Duration(milliseconds: 10), () async {
          await userObject.processChunk({'456': 'john@example.com'});
        });

        await Future.delayed(Duration(milliseconds: 20));
        expect(resolvedUsers, hasLength(1));
        expect(resolvedUsers[0].name, equals('John Doe'));
        expect(resolvedUsers[0].email, equals('john@example.com'));

        subscription.cancel();
      });

      test('should emit raw chunk updates', () async {
        final json = {
          'name': '\$123',
          'age': 30,
          'email': '\$456',
        };

        final userObject = ChunkObject.fromJson(json, User.fromJson);

        final chunks = <Map<String, dynamic>>[];
        final subscription = userObject.listenRawChunkUpdate((chunk) {
          chunks.add(chunk);
        });

        await userObject.processChunk({'123': 'John Doe'});
        await userObject.processChunk({'456': 'john@example.com'});

        await Future.delayed(Duration(milliseconds: 10));

        expect(chunks, hasLength(2));
        expect(chunks[0], equals({'123': 'John Doe'}));
        expect(chunks[1], equals({'456': 'john@example.com'}));

        subscription.cancel();
      });

      test('should emit chunk states', () async {
        final json = {
          'name': '\$123',
          'age': 30,
          'email': '\$456',
        };

        final nameField = ChunkField<String>('123');
        final emailField = ChunkField<String>('456');

        final userObject = ChunkObject.fromJson(
          json,
          User.fromJson,
          chunkFields: {
            'name': nameField,
            'email': emailField,
          },
        );

        final states = <Map<String, ChunkState>>[];
        final subscription = userObject.listenChunkStates((state) {
          states.add(state);
        });

        await userObject.processChunk({'123': 'John Doe'});
        await userObject.processChunk({'456': 'john@example.com'});

        await Future.delayed(Duration(milliseconds: 10));

        expect(states, hasLength(2));
        expect(states[0]['name'], equals(ChunkState.loaded));
        expect(states[0]['email'], equals(ChunkState.pending));
        expect(states[1]['name'], equals(ChunkState.loaded));
        expect(states[1]['email'], equals(ChunkState.loaded));

        subscription.cancel();
      });

      test('should emit parsed chunk updates with deserializers', () async {
        final json = {
          'title': '\$123',
          'price': '\$456',
          'available': true,
        };

        final priceField =
            ChunkField<double>('456', (data) => double.parse(data));

        final productObject = ChunkObject.fromJson(
          json,
          Product.fromJson,
          chunkFields: {
            'price': priceField,
          },
        );

        final parsedChunks = <dynamic>[];
        final subscription = productObject.listenChunkUpdate((chunk) {
          parsedChunks.add(chunk);
        });

        await productObject.processChunk({'123': 'Test Product'});
        await productObject.processChunk({'456': '29.99'});

        expect(parsedChunks, hasLength(2));
        expect(parsedChunks[0], equals('Test Product'));
        expect(parsedChunks[1], equals(29.99));

        subscription.cancel();
      });
    });

    group('caching', () {
      test('should cache deserialized result', () async {
        final json = {
          'name': 'John Doe',
          'age': 30,
          'email': 'john@example.com',
        };

        final userObject = ChunkObject.fromJson(json, User.fromJson);

        final user1 = userObject.getData();
        final user2 = userObject.getData();

        expect(identical(user1, user2), isTrue);
      });
    });

    group('state management', () {
      test('should report chunk states correctly', () async {
        final json = {
          'name': '\$123',
          'age': 30,
          'email': '\$456',
        };

        final nameField = ChunkField<String>('123');
        final emailField = ChunkField<String>('456');

        final userObject = ChunkObject.fromJson(
          json,
          User.fromJson,
          chunkFields: {
            'name': nameField,
            'email': emailField,
          },
        );

        expect(userObject.getFieldState('name'), equals(ChunkState.pending));
        expect(userObject.getFieldState('email'), equals(ChunkState.pending));
        expect(userObject.getFieldState('nonexistent'),
            equals(ChunkState.pending));

        await userObject.processChunk({'123': 'John Doe'});

        expect(userObject.getFieldState('name'), equals(ChunkState.loaded));
        expect(userObject.getFieldState('email'), equals(ChunkState.pending));
      });

      test('should clear all states', () async {
        final json = {
          'name': '\$123',
          'age': 30,
          'email': '\$456',
        };

        final nameField = ChunkField<String>('123');
        final emailField = ChunkField<String>('456');

        final userObject = ChunkObject.fromJson(
          json,
          User.fromJson,
          chunkFields: {
            'name': nameField,
            'email': emailField,
          },
        );

        await userObject.processChunk({'123': 'John Doe'});
        await userObject.processChunk({'456': 'john@example.com'});

        expect(userObject.allChunksResolved, isTrue);
        expect(nameField.isResolved, isTrue);
        expect(emailField.isResolved, isTrue);

        userObject.clear();

        expect(userObject.allChunksResolved, isFalse);
        expect(nameField.isResolved, isFalse);
        expect(emailField.isResolved, isFalse);
      });
    });

    group('error handling', () {
      test('should handle deserialization errors', () async {
        final json = {
          'name': 'John Doe',
          'age': 'invalid_age',
          'email': 'john@example.com',
        };

        final userObject = ChunkObject.fromJson(json, User.fromJson);

        expect(() => userObject.getData(), throwsStateError);
      });
    });

    group('disposal', () {
      test('should dispose resources properly', () async {
        final json = {
          'name': '\$123',
          'age': 30,
          'email': '\$456',
        };

        final userObject = ChunkObject.fromJson(json, User.fromJson);

        expect(userObject.chunkFields, isEmpty);

        userObject.dispose();

        expect(userObject.chunkFields, isEmpty);
      });
    });

    group('toString', () {
      test('should provide meaningful string representation when resolved', () async {
        final json = {
          'name': 'John Doe',
          'age': 30,
          'email': 'john@example.com',
        };

        final userObject = ChunkObject.fromJson(json, User.fromJson);

        final stringRepresentation = userObject.toString();

        expect(stringRepresentation, contains('ChunkObject<User>'));
        expect(stringRepresentation, contains('resolved:'));
        expect(stringRepresentation, contains('John Doe'));
      });

      test('should provide meaningful string representation when pending', () async {
        final json = {
          'name': '\$123',
          'age': 30,
          'email': '\$456',
        };

        final nameField = ChunkField<String>('123');
        final emailField = ChunkField<String>('456');

        final userObject = ChunkObject.fromJson(
          json,
          User.fromJson,
          chunkFields: {
            'name': nameField,
            'email': emailField,
          },
        );

        final stringRepresentation = userObject.toString();

        expect(stringRepresentation, contains('ChunkObject<User>'));
        expect(stringRepresentation, contains('pending:'));
        expect(stringRepresentation, contains('name'));
        expect(stringRepresentation, contains('email'));
      });
    });

    group('edge cases', () {
      test('should handle empty JSON', () async {
        final userObject = ChunkObject.fromJson(
            {},
            (_) => User(
                  name: 'default',
                  age: 0,
                  email: 'default@example.com',
                ));

        expect(userObject.allChunksResolved, isTrue);
        final user = userObject.getData();
        expect(user.name, equals('default'));
      });

      test('should handle nested placeholders', () async {
        final json = {
          'name': 'John Doe',
          'age': 30,
          'email': 'john@example.com',
          'metadata': {
            'avatar': '\$123',
            'settings': {
              'theme': '\$456',
            },
          },
        };

        final userObject = ChunkObject.fromJson(json, (json) => json);

        expect(userObject.allChunksResolved, isFalse);

        await userObject.processChunk({'123': 'avatar.jpg'});
        expect(userObject.allChunksResolved, isFalse);

        await userObject.processChunk({'456': 'dark'});
        expect(userObject.allChunksResolved, isTrue);

        final result = userObject.getData();
        expect(result['metadata']['avatar'], equals('avatar.jpg'));
        expect(result['metadata']['settings']['theme'], equals('dark'));
      });

      test('should handle complex nested structures', () async {
        final json = {
          'users': [
            {'name': '\$123', 'age': 30},
            {'name': 'Jane', 'age': '\$456'},
          ],
          'metadata': {
            'count': 2,
            'filter': '\$789',
          },
        };

        final userObject = ChunkObject.fromJson(json, (json) => json);

        expect(userObject.allChunksResolved, isFalse);

        await userObject.processChunk({'123': 'John'});
        await userObject.processChunk({'456': 25});
        await userObject.processChunk({'789': 'active'});

        expect(userObject.allChunksResolved, isTrue);

        final result = userObject.getData();
        expect(result['users'][0]['name'], equals('John'));
        expect(result['users'][1]['age'], equals(25));
        expect(result['metadata']['filter'], equals('active'));
      });
    });
  });
}
