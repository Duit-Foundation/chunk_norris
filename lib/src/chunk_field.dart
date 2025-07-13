import 'dart:async';

import 'package:meta/meta.dart';

import 'state.dart';

/// A type-safe wrapper for individual fields in chunked JSON structures that load asynchronously.
///
/// ChunkField provides a robust abstraction for managing individual data fields that are
/// loaded progressively in chunks. It combines state management, type safety, and
/// asynchronous operations into a single cohesive interface that's easy to use and
/// integrate with progressive loading systems.
///
/// ## Key Features
/// - **Type Safety**: Generic type parameter ensures compile-time type checking
/// - **State Management**: Tracks loading state (pending, loaded, error) with clear transitions
/// - **Async Support**: Provides Future-based API for awaiting value resolution
/// - **Deserialization**: Optional custom deserializer for data transformation
/// - **Error Handling**: Comprehensive error tracking and reporting
/// - **Factory Methods**: Convenience constructors for common data types
///
/// ## State Lifecycle
/// The field follows a clear state machine:
/// ```
/// pending -> loaded (success)
/// pending -> error (failure)
/// any -> pending (reset)
/// ```
///
/// ## Usage Examples
///
/// ### Basic Usage
/// ```dart
/// // Create a field for a string value
/// final nameField = ChunkField<String>('user_name');
///
/// // Resolve with data when chunk arrives
/// nameField.resolve('John Doe');
///
/// // Access the value
/// print(nameField.value); // 'John Doe'
/// print(nameField.state); // ChunkState.loaded
/// ```
///
/// ### With Custom Deserializer
/// ```dart
/// // Create a field with custom deserialization
/// final userField = ChunkField<User>('user_123', (data) {
///   final map = data as Map<String, dynamic>;
///   return User.fromJson(map);
/// });
///
/// // Resolve with raw JSON data
/// userField.resolve({'name': 'Alice', 'age': 30});
///
/// // Access the typed value
/// final user = userField.value; // User object
/// ```
///
/// ### Async Operations
/// ```dart
/// final field = ChunkField<String>('async_data');
///
/// // Wait for the value asynchronously
/// final value = await field.future;
///
/// // Or check if ready
/// if (field.isResolved) {
///   print('Value: ${field.value}');
/// }
/// ```
///
/// ### Error Handling
/// ```dart
/// final field = ChunkField<int>('number', (data) {
///   if (data is! String) throw FormatException('Expected string');
///   return int.parse(data);
/// });
///
/// // This will trigger error state
/// field.resolve('invalid_number');
///
/// if (field.hasError) {
///   print('Error: ${field.error}');
/// }
/// ```
///
/// ## Factory Methods
/// Convenient factory methods for common data types:
/// - [ChunkField.string] - String values with toString conversion
/// - [ChunkField.integer] - Integer values with parsing
/// - [ChunkField.decimal] - Double values with parsing
/// - [ChunkField.boolean] - Boolean values with conversion
/// - [ChunkField.list] - List values with element deserialization
/// - [ChunkField.object] - Object values with custom deserialization
///
///
/// ## Performance Considerations
/// - Deserializers are called only once during resolution
/// - Value access after resolution is O(1)
/// - Future completion is handled efficiently
/// - Memory usage is minimal with lazy evaluation
///
/// See also:
/// - [ChunkState] for available states
/// - [ChunkCompleter] for lower-level completion handling
/// - [ChunkProcessor] for processing multiple chunks

final class ChunkField<T> {
  final String _placeholderId;
  final T Function(dynamic)? _deserializer;
  T? _value;
  ChunkState _state = ChunkState.pending;
  Object? _error;
  final _completer = Completer<T>();

  /// Creates a new ChunkField with the specified placeholder ID and optional deserializer.
  ///
  /// The field is initialized in [ChunkState.pending] state and will remain in that
  /// state until [resolve] is called with data or an error occurs during resolution.
  ///
  /// ## Parameters
  /// - [placeholderId]: Unique identifier for the placeholder/chunk this field represents
  /// - [deserializer]: Optional function to convert raw chunk data to type [T]
  ///
  /// ## Type Safety
  /// If no deserializer is provided, the raw data must be directly assignable to type [T].
  /// Otherwise, a deserializer function must be provided to handle the type conversion.
  ChunkField(
    this._placeholderId, [
    this._deserializer,
  ]);

  /// The unique identifier for the placeholder/chunk this field represents.
  ///
  /// This ID is used to match incoming chunk data with the appropriate field
  /// and should remain constant throughout the field's lifecycle.
  ///
  /// ## Usage
  /// - Matching incoming chunks to fields
  /// - Debugging and logging
  /// - State management integration
  String get placeholderId => _placeholderId;

  /// The current loading state of the field.
  ///
  /// Returns one of:
  /// - [ChunkState.pending]: Initial state, data not yet loaded
  /// - [ChunkState.loaded]: Data successfully loaded and available
  /// - [ChunkState.error]: Loading failed with an error
  ///
  /// ## Usage
  /// ```dart
  /// final field = ChunkField<String>('data');
  ///
  /// switch (field.state) {
  ///   case ChunkState.pending:
  ///     print('Still loading...');
  ///     break;
  ///   case ChunkState.loaded:
  ///     print('Data: ${field.value}');
  ///     break;
  ///   case ChunkState.error:
  ///     print('Error: ${field.error}');
  ///     break;
  /// }
  /// ```
  ChunkState get state => _state;

  /// Whether the field has been successfully loaded with data.
  ///
  /// Returns `true` if the field is in [ChunkState.loaded] state,
  /// `false` otherwise. This is a convenience method equivalent to
  /// checking `state == ChunkState.loaded`.
  ///
  /// ## Usage
  /// ```dart
  /// final field = ChunkField<String>('data');
  ///
  /// if (field.isResolved) {
  ///   print('Value: ${field.value}');
  /// } else {
  ///   print('Still loading...');
  /// }
  /// ```
  bool get isResolved => _state == ChunkState.loaded;

  /// Whether the field failed to load due to an error.
  ///
  /// Returns `true` if the field is in [ChunkState.error] state,
  /// `false` otherwise. This is a convenience method equivalent to
  /// checking `state == ChunkState.error`.
  ///
  /// ## Usage
  /// ```dart
  /// final field = ChunkField<int>('number');
  ///
  /// if (field.hasError) {
  ///   print('Loading failed: ${field.error}');
  /// }
  /// ```
  bool get hasError => _state == ChunkState.error;

  /// The error that occurred during loading, if any.
  ///
  /// Returns the error object if the field is in [ChunkState.error] state,
  /// `null` otherwise. The error can be used for logging, user feedback,
  /// or error recovery strategies.
  ///
  /// ## Usage
  /// ```dart
  /// final field = ChunkField<User>('user');
  ///
  /// if (field.hasError) {
  ///   final error = field.error;
  ///   logger.error('Failed to load user: $error');
  /// }
  /// ```
  Object? get error => _error;

  /// The resolved value if loaded, or `null` if not loaded or error occurred.
  ///
  /// This is a safe way to access the field's value without risking exceptions.
  /// Returns the typed value if the field is in [ChunkState.loaded] state,
  /// `null` otherwise.
  ///
  /// ## Usage
  /// ```dart
  /// final field = ChunkField<String>('data');
  ///
  /// final value = field.valueOrNull;
  /// if (value != null) {
  ///   print('Data: $value');
  /// }
  /// ```
  T? get valueOrNull => _value;

  /// A Future that completes when the field is resolved or fails with an error.
  ///
  /// This Future completes with the resolved value when [resolve] is called,
  /// or completes with an error when resolution fails. It's the primary way
  /// to await field resolution asynchronously.
  ///
  /// ## Usage
  /// ```dart
  /// final field = ChunkField<String>('data');
  ///
  /// try {
  ///   final value = await field.future;
  ///   print('Loaded: $value');
  /// } catch (error) {
  ///   print('Failed: $error');
  /// }
  /// ```
  ///
  /// ## Important Notes
  /// - The Future completes exactly once
  /// - Multiple awaits on the same Future are safe
  /// - The Future never completes if the field is reset
  Future<T> get future => _completer.future;

  /// Internal access to the deserializer function.
  ///
  /// This is used internally by the framework and should not be accessed
  /// directly in normal usage scenarios.
  @internal
  T Function(dynamic)? get deserializer => _deserializer;

  /// The resolved value of the field.
  ///
  /// Returns the typed value if the field is in [ChunkState.loaded] state.
  /// Throws a [StateError] if the field is not yet resolved or if an error
  /// occurred during loading.
  ///
  /// ## Exceptions
  /// - [StateError]: If field is not loaded or has error
  ///
  /// ## Usage
  /// ```dart
  /// final field = ChunkField<String>('data');
  ///
  /// // Safe usage with state check
  /// if (field.isResolved) {
  ///   final value = field.value; // Safe
  /// }
  ///
  /// // Or use valueOrNull for null-safe access
  /// final value = field.valueOrNull;
  /// ```
  ///
  /// ## Alternative Access Methods
  /// - Use [valueOrNull] for null-safe access
  /// - Use [future] for async access
  /// - Check [isResolved] before accessing
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

  /// Resolves the field with the provided data.
  ///
  /// This method processes the incoming data, applies deserialization if needed,
  /// and transitions the field to [ChunkState.loaded] state. If deserialization
  /// fails, the field transitions to [ChunkState.error] state instead.
  ///
  /// ## Parameters
  /// - [data]: The raw data to resolve the field with
  ///
  /// ## Resolution Process
  /// 1. Check if data is already of type [T] - use directly
  /// 2. If deserializer is provided - apply deserialization
  /// 3. If neither works - throw ArgumentError
  /// 4. Store resolved value and complete Future
  /// 5. Handle any errors during the process
  ///
  /// ## Type Conversion
  /// The method handles type conversion in the following order:
  /// - Direct type match (data is T)
  /// - Custom deserializer (if provided)
  /// - Error if neither applies
  ///
  /// ## Examples
  /// ```dart
  /// // Direct type match
  /// final stringField = ChunkField<String>('name');
  /// stringField.resolve('John Doe'); // Works directly
  ///
  /// // With deserializer
  /// final userField = ChunkField<User>('user', User.fromJson);
  /// userField.resolve({'name': 'Alice', 'age': 30}); // Deserializes
  ///
  /// // Error case
  /// final intField = ChunkField<int>('number');
  /// intField.resolve('not_a_number'); // Throws ArgumentError
  /// ```
  ///
  /// ## Error Handling
  /// - ArgumentError: If data cannot be converted to type [T]
  /// - Any exceptions from custom deserializer
  /// - All errors result in [ChunkState.error] state
  @internal
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

  /// Internal method to reject the field with an error.
  ///
  /// This method transitions the field to [ChunkState.error] state and
  /// completes the Future with the provided error. It's used internally
  /// when resolution fails.
  ///
  /// ## Parameters
  /// - [error]: The error that caused the rejection
  /// - [stackTrace]: Optional stack trace for debugging
  void _reject(Object error, [StackTrace? stackTrace]) {
    if (_completer.isCompleted) return;

    _error = error;
    _state = ChunkState.error;
    _completer.completeError(error, stackTrace);
  }

  /// Resets the field to its initial pending state.
  ///
  /// This method clears any resolved value or error and returns the field
  /// to [ChunkState.pending] state. Note that this does not reset the
  /// internal Completer, so the [future] will remain completed if it
  /// was previously resolved.
  void reset() {
    _value = null;
    _state = ChunkState.pending;
    _error = null;
  }

  /// Returns a string representation of the field's current state.
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

  /// Creates a field for string values with automatic toString conversion.
  ///
  /// This factory method creates a ChunkField that converts incoming data
  /// to string using the `toString()` method. It's useful for fields that
  /// should accept various data types and convert them to string representation.
  ///
  /// ## Parameters
  /// - [placeholderId]: The unique identifier for the placeholder/chunk
  ///
  /// ## Examples
  /// ```dart
  /// final nameField = ChunkField.string('user_name');
  ///
  /// nameField.resolve('John Doe');      // String -> 'John Doe'
  /// nameField.resolve(123);             // int -> '123'
  /// nameField.resolve(true);            // bool -> 'true'
  /// nameField.resolve({'key': 'val'});  // Map -> '{key: val}'
  /// ```
  ///
  /// ## Type Safety
  /// The deserializer calls `toString()` on the incoming data, so it will
  /// never throw conversion errors but may produce unexpected string representations
  /// for complex objects.
  static ChunkField<String> string(String placeholderId) =>
      ChunkField<String>(placeholderId, (data) => data.toString());

  /// Creates a field for integer values with automatic parsing.
  ///
  /// This factory method creates a ChunkField that handles integer conversion
  /// from various input types. It supports direct int values and string parsing.
  ///
  /// ## Parameters
  /// - [placeholderId]: The unique identifier for the placeholder/chunk
  ///
  /// ## Supported Conversions
  /// - `int` values are returned directly
  /// - `String` values are parsed using `int.parse()`
  /// - Other types throw [FormatException]
  ///
  /// ## Examples
  /// ```dart
  /// final ageField = ChunkField.integer('user_age');
  ///
  /// ageField.resolve(25);        // int -> 25
  /// ageField.resolve('30');      // String -> 30
  /// ageField.resolve('abc');     // Throws FormatException
  /// ageField.resolve(3.14);      // Throws FormatException
  /// ```
  ///
  /// ## Error Handling
  /// - [FormatException]: If the data cannot be parsed as an integer
  static ChunkField<int> integer(String placeholderId) =>
      ChunkField<int>(placeholderId, (data) {
        if (data is int) return data;
        if (data is String) return int.parse(data);
        throw FormatException('Cannot parse $data as int');
      });

  /// Creates a field for floating-point numbers with automatic parsing.
  ///
  /// This factory method creates a ChunkField that handles double conversion
  /// from various numeric input types. It supports direct double values,
  /// int to double conversion, and string parsing.
  ///
  /// ## Parameters
  /// - [placeholderId]: The unique identifier for the placeholder/chunk
  ///
  /// ## Supported Conversions
  /// - `double` values are returned directly
  /// - `int` values are converted to double using `toDouble()`
  /// - `String` values are parsed using `double.parse()`
  /// - Other types throw [FormatException]
  ///
  /// ## Examples
  /// ```dart
  /// final priceField = ChunkField.decimal('product_price');
  ///
  /// priceField.resolve(19.99);     // double -> 19.99
  /// priceField.resolve(20);        // int -> 20.0
  /// priceField.resolve('15.50');   // String -> 15.5
  /// priceField.resolve('abc');     // Throws FormatException
  /// ```
  ///
  /// ## Error Handling
  /// - [FormatException]: If the data cannot be parsed as a double
  static ChunkField<double> decimal(String placeholderId) =>
      ChunkField<double>(placeholderId, (data) {
        if (data is double) return data;
        if (data is int) return data.toDouble();
        if (data is String) return double.parse(data);
        throw FormatException('Cannot parse $data as double');
      });

  /// Creates a field for boolean values with flexible conversion.
  ///
  /// This factory method creates a ChunkField that handles boolean conversion
  /// from various input types using common boolean representation patterns.
  ///
  /// ## Parameters
  /// - [placeholderId]: The unique identifier for the placeholder/chunk
  ///
  /// ## Supported Conversions
  /// - `bool` values are returned directly
  /// - `String` values: 'true' (case-insensitive) -> true, others -> false
  /// - `int` values: 0 -> false, non-zero -> true
  /// - Other types throw [FormatException]
  ///
  /// ## Examples
  /// ```dart
  /// final activeField = ChunkField.boolean('is_active');
  ///
  /// activeField.resolve(true);       // bool -> true
  /// activeField.resolve('true');     // String -> true
  /// activeField.resolve('TRUE');     // String -> true
  /// activeField.resolve('false');    // String -> false
  /// activeField.resolve('anything'); // String -> false
  /// activeField.resolve(1);          // int -> true
  /// activeField.resolve(0);          // int -> false
  /// activeField.resolve(-5);         // int -> true
  /// ```
  ///
  /// ## Error Handling
  /// - [FormatException]: If the data type is not supported for boolean conversion
  static ChunkField<bool> boolean(String placeholderId) =>
      ChunkField<bool>(placeholderId, (data) {
        if (data is bool) return data;
        if (data is String) return data.toLowerCase() == 'true';
        if (data is int) return data != 0;
        throw FormatException('Cannot parse $data as bool');
      });

  /// Creates a field for list values with custom element deserialization.
  ///
  /// This factory method creates a ChunkField that handles list conversion
  /// where each element is processed through a custom deserializer function.
  /// It's useful for lists containing complex objects or requiring type conversion.
  ///
  /// ## Parameters
  /// - [placeholderId]: The unique identifier for the placeholder/chunk
  /// - [itemDeserializer]: Function to deserialize each list element
  ///
  /// ## Type Parameters
  /// - [T]: The type of elements in the resulting list
  ///
  /// ## Examples
  /// ```dart
  /// // List of strings
  /// final tagsField = ChunkField.list<String>('tags', (item) => item.toString());
  /// tagsField.resolve(['dart', 'flutter', 'programming']);
  ///
  /// // List of custom objects
  /// final usersField = ChunkField.list<User>('users', (item) {
  ///   return User.fromJson(item as Map<String, dynamic>);
  /// });
  /// usersField.resolve([
  ///   {'name': 'Alice', 'age': 30},
  ///   {'name': 'Bob', 'age': 25}
  /// ]);
  ///
  /// // List of numbers
  /// final numbersField = ChunkField.list<int>('numbers', (item) => int.parse(item.toString()));
  /// numbersField.resolve([1, '2', 3.0]); // -> [1, 2, 3]
  /// ```
  ///
  /// ## Error Handling
  /// - [FormatException]: If the data is not a List
  /// - Any errors from the item deserializer function
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

  /// Creates a field for object values with custom deserialization.
  ///
  /// This factory method creates a ChunkField that handles object conversion
  /// from Map<String, dynamic> to custom types using a provided deserializer.
  /// It's the primary way to create fields for complex objects and data models.
  ///
  /// ## Parameters
  /// - [placeholderId]: The unique identifier for the placeholder/chunk
  /// - [deserializer]: Function to deserialize the Map to type [T]
  ///
  /// ## Type Parameters
  /// - [T]: The type of the resulting object
  ///
  /// ## Examples
  /// ```dart
  /// // User object
  /// final userField = ChunkField.object<User>('user', (data) {
  ///   return User.fromJson(data);
  /// });
  /// userField.resolve({'name': 'Alice', 'age': 30, 'email': 'alice@example.com'});
  ///
  /// // Product object
  /// final productField = ChunkField.object<Product>('product', (data) {
  ///   return Product(
  ///     id: data['id'],
  ///     name: data['name'],
  ///     price: data['price'].toDouble(),
  ///   );
  /// });
  /// productField.resolve({'id': 1, 'name': 'Widget', 'price': 9.99});
  ///
  /// // Configuration object
  /// final configField = ChunkField.object<AppConfig>('config', AppConfig.fromMap);
  /// configField.resolve({'theme': 'dark', 'notifications': true});
  /// ```
  ///
  /// ## Error Handling
  /// - [FormatException]: If the data is not a Map<String, dynamic>
  /// - Any errors from the deserializer function
  ///
  /// ## Best Practices
  /// - Use named constructors or factory methods for deserializers
  /// - Handle null values appropriately in the deserializer
  /// - Validate required fields in the deserializer
  /// - Consider using code generation for complex objects
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
