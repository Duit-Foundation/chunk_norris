import 'package:chunk_norris/src/chunk_state_manager.dart';
import 'package:chunk_norris/src/placeholder_resolver.dart';
import 'package:test/test.dart';

void main() {
  group('PlaceholderResolver caching tests', () {
    late PlaceholderResolver resolver;
    late ChunkStateManager stateManager;

    setUp(() {
      resolver = PlaceholderResolver();
      stateManager = ChunkStateManager();
    });

    test('should cache resolution results', () {
      // Prepare data
      final data = {
        'user': {
          'name': 'John',
          'avatar': '\$1',
          'posts': '\$2',
        },
        'settings': {
          'theme': 'dark',
          'notifications': '\$3',
        },
      };

      // Register placeholders
      stateManager.registerPlaceholder('1');
      stateManager.registerPlaceholder('2');
      stateManager.registerPlaceholder('3');

      // Resolve some placeholders
      stateManager.resolvePlaceholder('1', 'avatar_url.png');
      stateManager.resolvePlaceholder('2', ['post1', 'post2']);

      // First call - should execute resolution and save to cache
      final result1 = resolver.resolvePlaceholders(data, stateManager);

      // Second call - should return result from cache
      final result2 = resolver.resolvePlaceholders(data, stateManager);

      // Check that results are identical
      expect(result1, equals(result2));
      expect(result1['user']['avatar'], equals('avatar_url.png'));
      expect(result1['user']['posts'], equals(['post1', 'post2']));
      expect(result1['settings']['notifications'],
          equals('\$3')); // Unresolved placeholder
    });

    test('should work with custom RegExp pattern', () {
      // Create resolver with custom pattern
      final customResolver = PlaceholderResolver(
        placeholderPattern: RegExp(r'^\{id:(\d+)\}$'),
      );

      // Prepare data with custom pattern
      final data = {
        'user': {
          'name': 'John',
          'avatar': '{id:1}',
          'posts': '{id:2}',
        },
        'settings': {
          'theme': 'dark',
          'notifications': '{id:3}',
        },
      };

      // Register placeholders
      stateManager.registerPlaceholder('1');
      stateManager.registerPlaceholder('2');
      stateManager.registerPlaceholder('3');

      // Resolve some placeholders
      stateManager.resolvePlaceholder('1', 'custom_avatar.png');
      stateManager.resolvePlaceholder('2', ['custom_post1', 'custom_post2']);

      // First call - should execute resolution and save to cache
      final result1 = customResolver.resolvePlaceholders(data, stateManager);

      // Second call - should return result from cache
      final result2 = customResolver.resolvePlaceholders(data, stateManager);

      // Check that results are identical
      expect(result1, equals(result2));
      expect(result1['user']['avatar'], equals('custom_avatar.png'));
      expect(
          result1['user']['posts'], equals(['custom_post1', 'custom_post2']));
      expect(result1['settings']['notifications'],
          equals('{id:3}')); // Unresolved placeholder
    });

    test('should find placeholders with custom pattern', () {
      // Create resolver with custom pattern
      final customResolver = PlaceholderResolver(
        placeholderPattern: RegExp(r'^\{id:(\d+)\}$'),
      );

      // Prepare data with custom pattern
      final data = {
        'user': '{id:123}',
        'posts': ['{id:456}', '{id:789}', 'regular_string'],
        'nested': {'avatar': '{id:999}', 'count': 42}
      };

      // Find placeholders
      final placeholders = customResolver.findPlaceholders(data);

      // Check that correct placeholders are found
      expect(placeholders, containsAll(['123', '456', '789', '999']));
      expect(placeholders.length, equals(4));
    });

    test('should identify placeholders with custom pattern', () {
      // Create resolver with custom pattern
      final customResolver = PlaceholderResolver(
        placeholderPattern: RegExp(r'^\{id:(\d+)\}$'),
      );

      // Test various values
      expect(customResolver.isPlaceholder('{id:123}'), isTrue);
      expect(customResolver.isPlaceholder('{id:0}'), isTrue);
      expect(customResolver.isPlaceholder('{id:abc}'), isFalse);
      expect(customResolver.isPlaceholder('prefix{id:123}'), isFalse);
      expect(customResolver.isPlaceholder('\$123'), isFalse);
      expect(customResolver.isPlaceholder('regular_string'), isFalse);
    });

    test('should extract placeholder IDs with custom pattern', () {
      // Create resolver with custom pattern
      final customResolver = PlaceholderResolver(
        placeholderPattern: RegExp(r'^\{id:(\d+)\}$'),
      );

      // Test ID extraction
      expect(customResolver.extractPlaceholderId('{id:123}'), equals('123'));
      expect(customResolver.extractPlaceholderId('{id:0}'), equals('0'));
      expect(customResolver.extractPlaceholderId('{id:abc}'), isNull);
      expect(customResolver.extractPlaceholderId('prefix{id:123}'), isNull);
      expect(customResolver.extractPlaceholderId('\$123'), isNull);
      expect(customResolver.extractPlaceholderId('regular_string'), isNull);
    });

    test('should invalidate cache when placeholder states change', () {
      final data = {
        'value': '\$1',
        'static': 'unchanged',
      };

      // Register placeholder
      stateManager.registerPlaceholder('1');

      // First call - placeholder not yet resolved
      final result1 = resolver.resolvePlaceholders(data, stateManager);
      expect(result1['value'], equals('\$1'));

      // Resolve placeholder
      stateManager.resolvePlaceholder('1', 'resolved_value');

      // Second call - should return updated result
      final result2 = resolver.resolvePlaceholders(data, stateManager);
      expect(result2['value'], equals('resolved_value'));
      expect(result2['static'], equals('unchanged'));
    });

    test('should work with cache disabled', () {
      final data = {
        'value': '\$1',
      };

      stateManager.registerPlaceholder('1');
      stateManager.resolvePlaceholder('1', 'test_value');

      // Call without caching
      final result1 =
          resolver.resolvePlaceholders(data, stateManager, useCache: false);
      final result2 =
          resolver.resolvePlaceholders(data, stateManager, useCache: false);

      // Results should be identical, but cache should not be used
      expect(result1, equals(result2));
      expect(result1['value'], equals('test_value'));
    });

    test('should handle nested structures in cache', () {
      final data = {
        'level1': {
          'level2': {
            'level3': ['\$1', '\$2', 'static'],
          },
        },
      };

      stateManager.registerPlaceholder('1');
      stateManager.registerPlaceholder('2');
      stateManager.resolvePlaceholder('1', 'deep_value1');
      stateManager.resolvePlaceholder('2', 'deep_value2');

      // First call
      final result1 = resolver.resolvePlaceholders(data, stateManager);

      // Second call - should use cache
      final result2 = resolver.resolvePlaceholders(data, stateManager);

      expect(result1, equals(result2));
      expect(result1['level1']['level2']['level3'],
          equals(['deep_value1', 'deep_value2', 'static']));
    });

    test('should clear cache when clearCache is called', () {
      final data = {
        'value': '\$1',
      };

      stateManager.registerPlaceholder('1');
      stateManager.resolvePlaceholder('1', 'cached_value');

      // First call - fill cache
      final result1 = resolver.resolvePlaceholders(data, stateManager);
      expect(result1['value'], equals('cached_value'));

      // Clear cache
      resolver.clearCache();

      // Change state
      stateManager.resolvePlaceholder('1', 'new_value');

      // Second call - should return updated result
      final result2 = resolver.resolvePlaceholders(data, stateManager);
      expect(result2['value'], equals('new_value'));
    });

    test('should handle complex data structures with multiple placeholders',
        () {
      final data = {
        'users': [
          {'name': 'John', 'id': '\$1'},
          {'name': 'Jane', 'id': '\$2'},
        ],
        'metadata': {
          'count': '\$3',
          'lastUpdate': '\$4',
        },
        'config': {
          'theme': 'dark',
          'features': ['\$5', 'standard_feature'],
        },
      };

      // Register placeholders
      for (int i = 1; i <= 5; i++) {
        stateManager.registerPlaceholder(i.toString());
      }

      // Resolve placeholders
      stateManager.resolvePlaceholder('1', 'user_1');
      stateManager.resolvePlaceholder('2', 'user_2');
      stateManager.resolvePlaceholder('3', 42);
      stateManager.resolvePlaceholder('4', '2023-01-01');
      stateManager.resolvePlaceholder('5', 'premium_feature');

      // First call
      final result1 = resolver.resolvePlaceholders(data, stateManager);

      // Second call - should use cache
      final result2 = resolver.resolvePlaceholders(data, stateManager);

      expect(result1, equals(result2));
      expect(result1['users'][0]['id'], equals('user_1'));
      expect(result1['users'][1]['id'], equals('user_2'));
      expect(result1['metadata']['count'], equals(42));
      expect(result1['metadata']['lastUpdate'], equals('2023-01-01'));
      expect(result1['config']['features'],
          equals(['premium_feature', 'standard_feature']));
    });

    test('should cache different data structures separately', () {
      final data1 = {'value': '\$1'};
      final data2 = {'different': '\$1'};

      stateManager.registerPlaceholder('1');
      stateManager.resolvePlaceholder('1', 'test_value');

      // Resolve both data sets
      final result1 = resolver.resolvePlaceholders(data1, stateManager);
      final result2 = resolver.resolvePlaceholders(data2, stateManager);

      // Check that results are correct and different
      expect(result1['value'], equals('test_value'));
      expect(result2['different'], equals('test_value'));
      expect(result1.containsKey('different'), isFalse);
      expect(result2.containsKey('value'), isFalse);
    });
  });
}
