import 'dart:async';
import 'dart:convert';

import 'package:chunk_norris/chunk_norris.dart';
import 'package:test/test.dart';

void main() {
  group('ChunkJson', () {
    group('initialization', () {
      test('should initialize with empty JSON', () async {
        final chunkJson = ChunkJson.fromJson({});

        expect(chunkJson.json, equals({}));
        expect(chunkJson.isEmpty, isTrue);
        expect(chunkJson.isNotEmpty, isFalse);
        expect(chunkJson.length, equals(0));
        expect(chunkJson.allChunksResolved, isTrue);
      });

      test('should initialize with JSON without placeholders', () async {
        final json = {
          'title': 'Test Title',
          'value': 42,
          'active': true,
        };
        final chunkJson = ChunkJson.fromJson(json);

        expect(chunkJson.json, equals(json));
        expect(chunkJson.length, equals(3));
        expect(chunkJson.allChunksResolved, isTrue);
      });

      test('should initialize with JSON containing placeholders', () async {
        final json = {
          'title': 'Test Title',
          'content': '\$123',
          'author': '\$456',
          'metadata': {'views': '\$789', 'likes': 42}
        };
        final chunkJson = ChunkJson.fromJson(json);

        expect(chunkJson.json, equals(json));
        expect(chunkJson.length, equals(4));
        expect(chunkJson.allChunksResolved, isFalse);
      });

      test('should initialize with custom placeholder pattern', () async {
        final json = {
          'title': 'Test Title',
          'content': '{{123}}',
          'author': '{{456}}',
        };
        final chunkJson = ChunkJson.fromJson(
          json,
          placeholderPattern: RegExp(r'^\{\{(\d+)\}\}$'),
        );

        expect(chunkJson.json, equals(json));
        expect(chunkJson.allChunksResolved, isFalse);
      });

      test('should preserve original JSON structure', () async {
        final json = {
          'title': 'Test Title',
          'content': '\$123',
          'nested': {
            'value': '\$456',
            'array': ['\$789', 'static']
          }
        };
        final chunkJson = ChunkJson.fromJson(json);

        expect(chunkJson.json, equals(json));
        // ChunkJson uses the same reference to the original JSON
        expect(chunkJson.json, same(json));
      });
    });

    group('getValue', () {
      test('should return non-placeholder values directly', () async {
        final json = {
          'title': 'Test Title',
          'value': 42,
          'active': true,
        };
        final chunkJson = ChunkJson.fromJson(json);

        expect(chunkJson.getValue('title'), equals('Test Title'));
        expect(chunkJson.getValue('value'), equals(42));
        expect(chunkJson.getValue('active'), equals(true));
      });

      test('should return placeholder strings for unresolved placeholders',
          () async {
        final json = {
          'title': 'Test Title',
          'content': '\$123',
          'author': '\$456',
        };
        final chunkJson = ChunkJson.fromJson(json);

        expect(chunkJson.getValue('title'), equals('Test Title'));
        expect(chunkJson.getValue('content'), equals('\$123'));
        expect(chunkJson.getValue('author'), equals('\$456'));
      });

      test('should return resolved values for resolved placeholders', () async {
        final json = {
          'title': 'Test Title',
          'content': '\$123',
          'author': '\$456',
        };
        final chunkJson = ChunkJson.fromJson(json);

        chunkJson
            .processChunk({'123': 'This is the content', '456': 'John Doe'});

        expect(chunkJson.getValue('title'), equals('Test Title'));
        expect(chunkJson.getValue('content'), equals('This is the content'));
        expect(chunkJson.getValue('author'), equals('John Doe'));
      });

      test('should return null for non-existent keys', () async {
        final chunkJson = ChunkJson.fromJson({'title': 'Test'});

        expect(chunkJson.getValue('nonExistent'), isNull);
      });

      test('should handle nested structures correctly', () async {
        final json = {
          'metadata': {'views': '\$123', 'likes': 42},
          'tags': ['\$456', 'static']
        };
        final chunkJson = ChunkJson.fromJson(json);

        await chunkJson.processChunk({'123': 1500, '456': 'dynamic-tag'});

        final metadata = chunkJson.getValue('metadata');
        expect(metadata['views'], equals(1500));
        expect(metadata['likes'], equals(42));

        final tags = chunkJson.getValue('tags');
        expect(tags[0], equals('dynamic-tag'));
        expect(tags[1], equals('static'));
      });
    });

    group('getValueAsync', () {
      test('should return non-placeholder values immediately', () async {
        final json = {
          'title': 'Test Title',
          'value': 42,
        };
        final chunkJson = ChunkJson.fromJson(json);

        final title = await chunkJson.getValueAsync('title');
        final value = await chunkJson.getValueAsync('value');

        expect(title, equals('Test Title'));
        expect(value, equals(42));
      });

      test('should wait for placeholder resolution', () async {
        final json = {
          'title': 'Test Title',
          'content': '\$123',
        };
        final chunkJson = ChunkJson.fromJson(json);

        // Start async operation
        final contentFuture = chunkJson.getValueAsync('content');

        // Process chunk after a delay
        Timer(Duration(milliseconds: 100), () async {
          await chunkJson.processChunk({'123': 'Resolved content'});
        });

        final content = await contentFuture;
        expect(content, equals('Resolved content'));
      });

      test('should handle multiple concurrent async requests', () async {
        final json = {
          'content': '\$123',
          'author': '\$456',
        };
        final chunkJson = ChunkJson.fromJson(json);

        // Start multiple async operations
        final contentFuture = chunkJson.getValueAsync('content');
        final authorFuture = chunkJson.getValueAsync('author');

        // Process chunks
        Timer(Duration(milliseconds: 50), () async {
          await chunkJson.processChunk({'123': 'Content here'});
        });

        Timer(Duration(milliseconds: 100), () async {
          await chunkJson.processChunk({'456': 'Author name'});
        });

        final results = await Future.wait([contentFuture, authorFuture]);

        expect(results[0], equals('Content here'));
        expect(results[1], equals('Author name'));
      });
    });

    group('getKeyState', () {
      test('should return loaded for non-placeholder values', () async {
        final json = {
          'title': 'Test Title',
          'value': 42,
        };
        final chunkJson = ChunkJson.fromJson(json);

        expect(chunkJson.getKeyState('title'), equals(ChunkState.loaded));
        expect(chunkJson.getKeyState('value'), equals(ChunkState.loaded));
      });

      test('should return pending for unresolved placeholders', () async {
        final json = {
          'content': '\$123',
          'author': '\$456',
        };
        final chunkJson = ChunkJson.fromJson(json);

        expect(chunkJson.getKeyState('content'), equals(ChunkState.pending));
        expect(chunkJson.getKeyState('author'), equals(ChunkState.pending));
      });

      test('should return loaded for resolved placeholders', () async {
        final json = {
          'content': '\$123',
          'author': '\$456',
        };
        final chunkJson = ChunkJson.fromJson(json);

        await chunkJson.processChunk({'123': 'Content here'});

        expect(chunkJson.getKeyState('content'), equals(ChunkState.loaded));
        expect(chunkJson.getKeyState('author'), equals(ChunkState.pending));
      });

      test('should return loaded for non-existent keys', () async {
        final chunkJson = ChunkJson.fromJson({'title': 'Test'});

        expect(chunkJson.getKeyState('nonExistent'), equals(ChunkState.loaded));
      });
    });

    group('processChunk', () {
      test('should resolve placeholders with chunk data', () async {
        final json = {
          'title': 'Test Title',
          'content': '\$123',
          'author': '\$456',
        };
        final chunkJson = ChunkJson.fromJson(json);

        await chunkJson.processChunk({'123': 'This is the content'});

        expect(chunkJson.getValue('content'), equals('This is the content'));
        expect(
            chunkJson.getValue('author'), equals('\$456')); // Still unresolved
      });

      test('should handle multiple chunks', () async {
        final json = {
          'content': '\$123',
          'author': '\$456',
        };
        final chunkJson = ChunkJson.fromJson(json);

        await chunkJson.processChunk({'123': 'First content'});
        await chunkJson.processChunk({'456': 'John Doe'});

        expect(chunkJson.getValue('content'), equals('First content'));
        expect(chunkJson.getValue('author'), equals('John Doe'));
      });

      test('should handle chunk with multiple placeholders', () async {
        final json = {
          'content': '\$123',
          'author': '\$456',
          'title': '\$789',
        };
        final chunkJson = ChunkJson.fromJson(json);

        await chunkJson.processChunk(
            {'123': 'Content here', '456': 'Author name', '789': 'Title text'});

        expect(chunkJson.getValue('content'), equals('Content here'));
        expect(chunkJson.getValue('author'), equals('Author name'));
        expect(chunkJson.getValue('title'), equals('Title text'));
      });

      test('should handle empty chunks gracefully', () async {
        final json = {'content': '\$123'};
        final chunkJson = ChunkJson.fromJson(json);

        await chunkJson.processChunk({});

        expect(chunkJson.getValue('content'), equals('\$123'));
      });

      test('should handle chunks with non-existent placeholder IDs', () async {
        final json = {'content': '\$123'};
        final chunkJson = ChunkJson.fromJson(json);

        await chunkJson.processChunk({'999': 'Some data'});

        expect(chunkJson.getValue('content'), equals('\$123'));
      });
    });

    group('processChunkStream', () {
      test('should process stream of JSON strings', () async {
        final json = {
          'content': '\$123',
          'author': '\$456',
        };
        final chunkJson = ChunkJson.fromJson(json);

        final controller = StreamController<String>();
        chunkJson.processChunkStream(controller.stream);

        // Send JSON chunks
        controller.add('{"123": "Stream content"}');
        controller.add('{"456": "Stream author"}');

        // Wait for processing
        await Future.delayed(Duration(milliseconds: 100));

        expect(chunkJson.getValue('content'), equals('Stream content'));
        expect(chunkJson.getValue('author'), equals('Stream author'));

        await controller.close();
      });

      test('should handle malformed JSON gracefully', () async {
        final json = {'content': '\$123'};
        final chunkJson = ChunkJson.fromJson(json);

        final controller = StreamController<String>();
        chunkJson.processChunkStream(controller.stream);

        // Send malformed JSON
        controller.add('{"invalid": json}');
        controller.add('{"123": "Valid content"}');

        await Future.delayed(Duration(milliseconds: 100));

        expect(chunkJson.getValue('content'), equals('Valid content'));

        await controller.close();
      });
    });

    group('getResolvedData', () {
      test('should return resolved data with all placeholders replaced',
          () async {
        final json = {
          'title': 'Test Title',
          'content': '\$123',
          'author': '\$456',
          'metadata': {'views': '\$789', 'likes': 42}
        };
        final chunkJson = ChunkJson.fromJson(json);

        await chunkJson.processChunk(
            {'123': 'Content here', '456': 'John Doe', '789': 1500});

        final resolved = chunkJson.getResolvedData();

        expect(resolved['title'], equals('Test Title'));
        expect(resolved['content'], equals('Content here'));
        expect(resolved['author'], equals('John Doe'));
        expect(resolved['metadata']['views'], equals(1500));
        expect(resolved['metadata']['likes'], equals(42));
      });

      test('should return original data when no placeholders exist', () async {
        final json = {
          'title': 'Test Title',
          'value': 42,
          'active': true,
        };
        final chunkJson = ChunkJson.fromJson(json);

        final resolved = chunkJson.getResolvedData();

        expect(resolved, equals(json));
      });

      test('should return mixed resolved and unresolved data', () async {
        final json = {
          'title': 'Test Title',
          'content': '\$123',
          'author': '\$456',
        };
        final chunkJson = ChunkJson.fromJson(json);

        await chunkJson.processChunk({'123': 'Content here'});

        final resolved = chunkJson.getResolvedData();

        expect(resolved['title'], equals('Test Title'));
        expect(resolved['content'], equals('Content here'));
        expect(resolved['author'], equals('\$456')); // Still unresolved
      });
    });

    group('waitForAllChunks', () {
      test('should return immediately when no placeholders exist', () async {
        final json = {
          'title': 'Test Title',
          'value': 42,
        };
        final chunkJson = ChunkJson.fromJson(json);

        final result = await chunkJson.waitForAllData();

        expect(result, equals(json));
      });

      test('should wait for all placeholders to be resolved', () async {
        final json = {
          'content': '\$123',
          'author': '\$456',
        };
        final chunkJson = ChunkJson.fromJson(json);

        // Start waiting
        final resultFuture = chunkJson.waitForAllData();

        // Process chunks after delays
        Timer(Duration(milliseconds: 50), () async {
          await chunkJson.processChunk({'123': 'Content here'});
        });

        Timer(Duration(milliseconds: 100), () async {
          await chunkJson.processChunk({'456': 'Author name'});
        });

        final result = await resultFuture;

        expect(result['content'], equals('Content here'));
        expect(result['author'], equals('Author name'));
      });

      test('should handle concurrent waitForAllChunks calls', () async {
        final json = {
          'content': '\$123',
          'author': '\$456',
        };
        final chunkJson = ChunkJson.fromJson(json);

        // Start multiple waiting operations
        final result1Future = chunkJson.waitForAllData();
        final result2Future = chunkJson.waitForAllData();

        // Process chunks
        Timer(Duration(milliseconds: 50), () async {
          await chunkJson
              .processChunk({'123': 'Content here', '456': 'Author name'});
        });

        final results = await Future.wait([result1Future, result2Future]);

        expect(results[0]['content'], equals('Content here'));
        expect(results[1]['content'], equals('Content here'));
      });
    });

    group('listenUpdateStream', () {
      test('should notify listeners when chunks are processed', () async {
        final json = {'content': '\$123'};
        final chunkJson = ChunkJson.fromJson(json);

        final receivedChunks = <Map<String, dynamic>>[];
        final subscription = chunkJson.listenUpdateStream(
          (chunk) => receivedChunks.add(chunk),
        );

        await chunkJson.processChunk({'123': 'Content here'});
        await chunkJson.processChunk({'456': 'Other data'});

        await Future.delayed(Duration(milliseconds: 100));

        expect(receivedChunks.length, equals(2));
        expect(receivedChunks[0], equals({'123': 'Content here'}));
        expect(receivedChunks[1], equals({'456': 'Other data'}));

        subscription?.cancel();
      });

      test('should handle errors through onError callback', () async {
        final json = {'content': '\$123'};
        final chunkJson = ChunkJson.fromJson(json);

        final receivedErrors = <Object>[];
        final subscription = chunkJson.listenUpdateStream(
          (chunk) {},
          onError: (error) => receivedErrors.add(error),
        );

        // Force an error by processing malformed chunk stream
        final controller = StreamController<String>();
        chunkJson.processChunkStream(controller.stream);

        controller.add('invalid json');
        await Future.delayed(Duration(milliseconds: 100));

        expect(receivedErrors.length, greaterThan(0));

        subscription?.cancel();
        await controller.close();
      });
    });

    group('Map-like interface', () {
      test('should support [] operator', () async {
        final json = {
          'title': 'Test Title',
          'content': '\$123',
        };
        final chunkJson = ChunkJson.fromJson(json);

        await chunkJson.processChunk({'123': 'Content here'});

        expect(chunkJson['title'], equals('Test Title'));
        expect(chunkJson['content'], equals('Content here'));
        expect(chunkJson['nonExistent'], isNull);
      });

      test('should support []= operator', () async {
        final chunkJson = ChunkJson.fromJson({});

        chunkJson['title'] = 'Test Title';
        chunkJson['value'] = 42;

        expect(chunkJson['title'], equals('Test Title'));
        expect(chunkJson['value'], equals(42));
      });

      test('should support containsKey', () async {
        final json = {
          'title': 'Test Title',
          'content': '\$123',
        };
        final chunkJson = ChunkJson.fromJson(json);

        expect(chunkJson.containsKey('title'), isTrue);
        expect(chunkJson.containsKey('content'), isTrue);
        expect(chunkJson.containsKey('nonExistent'), isFalse);
      });

      test('should support keys property', () async {
        final json = {
          'title': 'Test Title',
          'content': '\$123',
          'value': 42,
        };
        final chunkJson = ChunkJson.fromJson(json);

        final keys = chunkJson.keys.toList();

        expect(keys.length, equals(3));
        expect(keys.contains('title'), isTrue);
        expect(keys.contains('content'), isTrue);
        expect(keys.contains('value'), isTrue);
      });

      test('should support values property with resolution', () async {
        final json = {
          'title': 'Test Title',
          'content': '\$123',
          'value': 42,
        };
        final chunkJson = ChunkJson.fromJson(json);

        await chunkJson.processChunk({'123': 'Content here'});

        final values = chunkJson.values.toList();

        expect(values.length, equals(3));
        expect(values.contains('Test Title'), isTrue);
        expect(values.contains('Content here'), isTrue);
        expect(values.contains(42), isTrue);
      });

      test('should support isEmpty and isNotEmpty properties', () async {
        final emptyJson = ChunkJson.fromJson({});
        final nonEmptyJson = ChunkJson.fromJson({'title': 'Test'});

        expect(emptyJson.isEmpty, isTrue);
        expect(emptyJson.isNotEmpty, isFalse);
        expect(nonEmptyJson.isEmpty, isFalse);
        expect(nonEmptyJson.isNotEmpty, isTrue);
      });

      test('should support length property', () async {
        final json = {
          'title': 'Test Title',
          'content': '\$123',
          'value': 42,
        };
        final chunkJson = ChunkJson.fromJson(json);

        expect(chunkJson.length, equals(3));

        chunkJson['newKey'] = 'newValue';
        expect(chunkJson.length, equals(4));
      });
    });

    group('allChunksResolved', () {
      test('should return true when no placeholders exist', () async {
        final json = {
          'title': 'Test Title',
          'value': 42,
        };
        final chunkJson = ChunkJson.fromJson(json);

        expect(chunkJson.allChunksResolved, isTrue);
      });

      test('should return false when placeholders exist', () async {
        final json = {
          'title': 'Test Title',
          'content': '\$123',
          'author': '\$456',
        };
        final chunkJson = ChunkJson.fromJson(json);

        expect(chunkJson.allChunksResolved, isFalse);
      });

      test('should return false when some placeholders are resolved', () async {
        final json = {
          'title': 'Test Title',
          'content': '\$123',
          'author': '\$456',
        };
        final chunkJson = ChunkJson.fromJson(json);

        await chunkJson.processChunk({'123': 'Content here'});

        expect(chunkJson.allChunksResolved, isFalse);
      });

      test('should return true when all placeholders are resolved', () async {
        final json = {
          'title': 'Test Title',
          'content': '\$123',
          'author': '\$456',
        };
        final chunkJson = ChunkJson.fromJson(json);

        await chunkJson
            .processChunk({'123': 'Content here', '456': 'Author name'});

        expect(chunkJson.allChunksResolved, isTrue);
      });

      test('should return true for empty JSON', () async {
        final chunkJson = ChunkJson.fromJson({});

        expect(chunkJson.allChunksResolved, isTrue);
      });
    });

    group('clear', () {
      test('should reset all chunk states to pending', () async {
        final json = {
          'content': '\$123',
          'author': '\$456',
        };
        final chunkJson = ChunkJson.fromJson(json);

        await chunkJson
            .processChunk({'123': 'Content here', '456': 'Author name'});

        expect(chunkJson.allChunksResolved, isTrue);
        expect(chunkJson.getValue('content'), equals('Content here'));

        chunkJson.clear();

        expect(chunkJson.getValue('content'), equals('\$123'));
        expect(chunkJson.allChunksResolved, isFalse);
      });

      test('should preserve original JSON structure', () async {
        final json = {
          'title': 'Test Title',
          'content': '\$123',
        };
        final chunkJson = ChunkJson.fromJson(json);

        await chunkJson.processChunk({'123': 'Content here'});
        chunkJson.clear();

        expect(chunkJson.json, equals(json));
      });
    });

    group('dispose', () {
      test('should properly dispose resources', () async {
        final json = {
          'content': '\$123',
          'author': '\$456',
        };
        final chunkJson = ChunkJson.fromJson(json);

        await chunkJson.processChunk({'123': 'Content here'});

        // Should not throw
        chunkJson.dispose();

        // After dispose, the instance should still be accessible but not processing
        expect(chunkJson.json, equals(json));
      });
    });

    group('toString', () {
      test('should return string representation of resolved data', () async {
        final json = {
          'title': 'Test Title',
          'content': '\$123',
        };
        final chunkJson = ChunkJson.fromJson(json);

        await chunkJson.processChunk({'123': 'Content here'});

        final string = chunkJson.toString();

        expect(string.contains('Test Title'), isTrue);
        expect(string.contains('Content here'), isTrue);
        expect(string.contains('\$123'), isFalse);
      });
    });

    group('error handling', () {
      test('should handle null values gracefully', () async {
        final json = {
          'title': null,
          'content': '\$123',
        };
        final chunkJson = ChunkJson.fromJson(json);

        expect(chunkJson.getValue('title'), isNull);
        expect(chunkJson.getKeyState('title'), equals(ChunkState.loaded));
      });

      test('should handle nested null values', () async {
        final json = {
          'metadata': {'views': null, 'likes': '\$123'}
        };
        final chunkJson = ChunkJson.fromJson(json);

        final metadata = chunkJson.getValue('metadata');
        expect(metadata['views'], isNull);
        expect(metadata['likes'], equals('\$123'));
      });

      test('should handle array with placeholders', () async {
        final json = {
          'tags': ['\$123', 'static', '\$456']
        };
        final chunkJson = ChunkJson.fromJson(json);

        await chunkJson.processChunk({'123': 'dynamic1', '456': 'dynamic2'});

        final tags = chunkJson.getValue('tags');
        expect(tags[0], equals('dynamic1'));
        expect(tags[1], equals('static'));
        expect(tags[2], equals('dynamic2'));
      });
    });
  });
}
