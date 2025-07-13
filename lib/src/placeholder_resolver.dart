import 'package:chunk_norris/src/chunk_state_manager.dart';

/// A utility class for managing and resolving placeholder values in progressive JSON data.
///
/// The PlaceholderResolver provides comprehensive functionality for working with
/// placeholder values in JSON structures during progressive loading scenarios.
/// It can identify, extract, find, and resolve placeholders with efficient caching
/// to optimize performance in large-scale data processing.
///
/// ## Placeholder Format
/// By default, placeholders follow the format `$<id>` where `<id>` is a numeric identifier:
/// - `$123` - Valid placeholder with ID "123"
/// - `$0` - Valid placeholder with ID "0"
/// - `$abc` - Invalid (non-numeric ID)
/// - `prefix$123` - Invalid (has prefix)
///
/// Custom placeholder patterns can be provided via the constructor parameter.
/// The pattern must include a capture group for the placeholder ID.
///
/// ## Key Features
/// - Pattern recognition for placeholder identification
/// - Configurable placeholder patterns via custom RegExp
/// - Recursive traversal of complex data structures
/// - Efficient caching mechanism for resolved data
/// - Support for nested Maps and Lists
/// - Integration with ChunkStateManager for state-aware resolution
///
/// ## Usage Example
/// ```dart
/// // Using default pattern
/// final resolver = PlaceholderResolver();
/// final stateManager = ChunkStateManager();
///
/// // Using custom pattern
/// final customResolver = PlaceholderResolver(
///   placeholderPattern: RegExp(r'^\{id:(\d+)\}$'),
/// );
///
/// // Sample data with placeholders
/// final data = {
///   'user': '$123',
///   'posts': ['$456', '$789'],
///   'profile': {
///     'avatar': '$999',
///     'name': 'John Doe'
///   }
/// };
///
/// // Find all placeholders
/// final placeholders = resolver.findPlaceholders(data);
/// print(placeholders); // {'123', '456', '789', '999'}
///
/// // Resolve placeholders (assumes data is loaded in stateManager)
/// final resolved = resolver.resolvePlaceholders(data, stateManager);
/// ```
///
/// ## Performance Optimization
/// - Built-in caching reduces redundant processing
/// - Cache invalidation based on state changes
/// - Lazy evaluation of complex structures
///
/// See also:
/// - [ChunkStateManager] for managing placeholder states
/// - [ChunkProcessor] for processing data with placeholders
final class PlaceholderResolver {
  final Map<String, dynamic> _resolutionCache = {};
  final RegExp _placeholderRegex;

  /// Creates a new PlaceholderResolver instance.
  ///
  /// The resolver is initialized with an empty cache and is ready to process
  /// placeholder data immediately.
  ///
  /// ## Parameters
  /// - [placeholderPattern]: Optional custom RegExp pattern for matching placeholders.
  ///   If not provided, uses the default pattern `^\$(\d+)$` which matches `$<numeric_id>`.
  ///   Custom patterns should include a capture group for the placeholder ID.
  ///
  /// ## Examples
  /// ```dart
  /// // Using default pattern (matches $123, $0, etc.)
  /// final resolver = PlaceholderResolver();
  ///
  /// // Using custom pattern (matches {id:123}, {id:0}, etc.)
  /// final customResolver = PlaceholderResolver(
  ///   placeholderPattern: RegExp(r'^\{id:(\d+)\}$'),
  /// );
  ///
  /// // Using custom pattern (matches @var123, @var0, etc.)
  /// final varResolver = PlaceholderResolver(
  ///   placeholderPattern: RegExp(r'^@var(\d+)$'),
  /// );
  /// ```
  PlaceholderResolver({
    RegExp? placeholderPattern,
  }) : _placeholderRegex = placeholderPattern ?? RegExp(r'^\$(\d+)$');

  /// Determines if a given value is a placeholder.
  ///
  /// A value is considered a placeholder if it's a string that matches
  /// the configured placeholder pattern.
  ///
  /// ## Parameters
  /// - [value]: The value to check for placeholder format
  ///
  /// ## Returns
  /// `true` if the value is a placeholder, `false` otherwise
  bool isPlaceholder(dynamic value) =>
      value is String && _placeholderRegex.hasMatch(value);

  /// Extracts the placeholder ID from a placeholder value.
  ///
  /// If the value is a valid placeholder, returns the ID portion from the first
  /// capture group of the configured RegExp pattern.
  /// Returns `null` if the value is not a placeholder.
  ///
  /// ## Parameters
  /// - [value]: The value to extract the placeholder ID from
  ///
  /// ## Returns
  /// The placeholder ID as a string, or `null` if not a placeholder
  String? extractPlaceholderId(dynamic value) {
    if (!isPlaceholder(value)) return null;
    final match = _placeholderRegex.firstMatch(value as String);
    return match?.group(1);
  }

  /// Recursively finds all placeholder IDs in a data structure.
  ///
  /// Traverses the provided data structure (Maps, Lists, and primitive values)
  /// to identify all placeholder values and extract their IDs using the configured
  /// RegExp pattern.
  ///
  /// ## Parameters
  /// - [data]: The data structure to search for placeholders
  ///
  /// ## Returns
  /// A [Set<String>] containing all unique placeholder IDs found
  ///
  /// ## Supported Data Types
  /// - Maps: Traverses all values recursively
  /// - Lists: Traverses all elements recursively
  /// - Primitives: Checks if the value itself is a placeholder
  ///
  /// ## Example
  /// ```dart
  /// // Using default pattern
  /// final resolver = PlaceholderResolver();
  ///
  /// final data = {
  ///   'user': '$123',
  ///   'posts': ['$456', '$789', 'regular_string'],
  ///   'nested': {
  ///     'avatar': '$999',
  ///     'count': 42
  ///   }
  /// };
  ///
  /// final placeholders = resolver.findPlaceholders(data);
  /// print(placeholders); // {'123', '456', '789', '999'}
  ///
  /// // Using custom pattern
  /// final customResolver = PlaceholderResolver(
  ///   placeholderPattern: RegExp(r'^\{id:(\d+)\}$'),
  /// );
  ///
  /// final customData = {
  ///   'user': '{id:123}',
  ///   'posts': ['{id:456}', '{id:789}', 'regular_string'],
  ///   'nested': {
  ///     'avatar': '{id:999}',
  ///     'count': 42
  ///   }
  /// };
  ///
  /// final customPlaceholders = customResolver.findPlaceholders(customData);
  /// print(customPlaceholders); // {'123', '456', '789', '999'}
  /// ```
  ///
  /// ## Performance Note
  /// This method performs a deep traversal of the data structure.
  /// For large datasets, consider caching results or using selective scanning.
  Set<String> findPlaceholders(dynamic data) {
    final Set<String> placeholders = {};

    void traverse(dynamic value) {
      if (isPlaceholder(value)) {
        final id = extractPlaceholderId(value);
        if (id != null) placeholders.add(id);
      } else if (value is Map) {
        value.values.forEach(traverse);
      } else if (value is List) {
        value.forEach(traverse);
      }
    }

    traverse(data);
    return placeholders;
  }

  /// Creates a cache key based on data and resolved placeholder states.
  ///
  /// Generates a unique cache key by combining the hash of the input data
  /// with the hash of currently resolved placeholder states. This ensures
  /// cache invalidation when either the data or resolution state changes.
  ///
  /// ## Parameters
  /// - [data]: The data to create cache key for
  /// - [stateManager]: The state manager with current resolution states
  ///
  /// ## Returns
  /// A string cache key in the format `<data_hash>:<states_hash>`
  String _createCacheKey(dynamic data, ChunkStateManager stateManager) {
    final dataHash = data.hashCode;
    final resolvedIds = stateManager.resolvedPlaceholderIds;
    final resolvedStatesHash = resolvedIds.hashCode;
    return '$dataHash:$resolvedStatesHash';
  }

  /// Clears the internal resolution cache.
  ///
  /// This method removes all cached resolution results, forcing subsequent
  /// calls to [resolvePlaceholders] to perform fresh resolution operations.
  /// Useful for memory management or when resolution logic changes.
  void clearCache() {
    _resolutionCache.clear();
  }

  /// Resolves placeholders in data using the provided state manager.
  ///
  /// This is the main method for transforming data with placeholders into
  /// resolved data. It recursively traverses the data structure, replacing
  /// placeholder values with their resolved counterparts from the state manager.
  ///
  /// ## Parameters
  /// - [data]: The data structure containing placeholders to resolve
  /// - [stateManager]: The state manager containing resolved placeholder data
  /// - [useCache]: Whether to use caching for performance optimization (default: true)
  ///
  /// ## Returns
  /// A new data structure with placeholders replaced by resolved values
  ///
  /// ## Resolution Behavior
  /// - Resolved placeholders are replaced with their actual data
  /// - Unresolved placeholders remain as placeholder strings
  /// - Non-placeholder values are returned unchanged
  /// - Complex structures (Maps/Lists) are recursively processed
  ///
  /// ## Example
  /// ```dart
  /// // Using default pattern
  /// final resolver = PlaceholderResolver();
  /// final stateManager = ChunkStateManager();
  ///
  /// // Setup resolved data
  /// stateManager.resolvePlaceholder('123', {'name': 'John', 'age': 30});
  /// stateManager.resolvePlaceholder('456', 'Hello World');
  ///
  /// final data = {
  ///   'user': '$123',
  ///   'message': '$456',
  ///   'pending': '$789', // Not resolved yet
  ///   'static': 'unchanged'
  /// };
  ///
  /// final resolved = resolver.resolvePlaceholders(data, stateManager);
  /// print(resolved);
  /// // {
  /// //   'user': {'name': 'John', 'age': 30},
  /// //   'message': 'Hello World',
  /// //   'pending': '$789',
  /// //   'static': 'unchanged'
  /// // }
  ///
  /// // Using custom pattern
  /// final customResolver = PlaceholderResolver(
  ///   placeholderPattern: RegExp(r'^\{id:(\d+)\}$'),
  /// );
  ///
  /// final customData = {
  ///   'user': '{id:123}',
  ///   'message': '{id:456}',
  ///   'pending': '{id:789}', // Not resolved yet
  ///   'static': 'unchanged'
  /// };
  ///
  /// final customResolved = customResolver.resolvePlaceholders(customData, stateManager);
  /// print(customResolved);
  /// // {
  /// //   'user': {'name': 'John', 'age': 30},
  /// //   'message': 'Hello World',
  /// //   'pending': '{id:789}',
  /// //   'static': 'unchanged'
  /// // }
  /// ```
  ///
  /// ## Caching
  /// - Enables automatic caching by default for performance
  /// - Cache keys are based on data content and resolution state
  /// - Disable caching for dynamic resolution scenarios
  ///
  /// ## Performance Considerations
  /// - Caching significantly improves performance for repeated operations
  /// - Deep data structures may have processing overhead
  /// - Consider using [clearCache] for memory management
  dynamic resolvePlaceholders(
    dynamic data,
    ChunkStateManager stateManager, {
    bool useCache = true,
  }) {
    if (useCache) {
      final cacheKey = _createCacheKey(data, stateManager);
      if (_resolutionCache.containsKey(cacheKey)) {
        return _resolutionCache[cacheKey];
      }
    }

    final result = _resolvePlaceholdersInternal(data, stateManager);

    if (useCache) {
      final cacheKey = _createCacheKey(data, stateManager);
      _resolutionCache[cacheKey] = result;
    }

    return result;
  }

  /// Internal method for resolving placeholders without caching.
  ///
  /// This method performs the actual resolution logic without any caching
  /// mechanism. It's used internally by [resolvePlaceholders] and should
  /// not be called directly in most cases.
  ///
  /// ## Parameters
  /// - [data]: The data structure to resolve placeholders in
  /// - [stateManager]: The state manager containing resolved data
  ///
  /// ## Returns
  /// The resolved data structure with placeholders replaced
  ///
  /// ## Resolution Algorithm
  /// 1. If data is a placeholder and resolved: return resolved data
  /// 2. If data is a placeholder but not resolved: return original placeholder
  /// 3. If data is a Map: recursively resolve all values
  /// 4. If data is a List: recursively resolve all elements
  /// 5. Otherwise: return data unchanged
  dynamic _resolvePlaceholdersInternal(
    dynamic data,
    ChunkStateManager stateManager,
  ) {
    if (isPlaceholder(data)) {
      final id = extractPlaceholderId(data);
      if (id != null && stateManager.isResolved(id)) {
        return stateManager.getResolvedData(id);
      }
      return data;
    } else if (data is Map<String, dynamic>) {
      return data.map((key, value) =>
          MapEntry(key, _resolvePlaceholdersInternal(value, stateManager)));
    } else if (data is Map) {
      return Map<String, dynamic>.from(data).map((key, value) =>
          MapEntry(key, _resolvePlaceholdersInternal(value, stateManager)));
    } else if (data is List) {
      return data
          .map((item) => _resolvePlaceholdersInternal(item, stateManager))
          .toList();
    }
    return data;
  }
}
