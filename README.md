# Chunk Norris 🥋

> **Chuck Norris doesn't wait for JSON to load. JSON loads instantly when Chuck Norris needs it.**
>
> That's exactly what this library does - it loads JSON so fast, it's almost supernatural!

---

**Chunk Norris** is a powerful Dart library for progressive JSON hydration. It allows you to work with JSON data that arrives in chunks, using placeholders that get resolved as data becomes available. Perfect for streaming APIs, Server-Sent Events, and any scenario where you need to handle partial data loading.

## 🚀 Features

- **Progressive Loading**: Load JSON data incrementally as chunks arrive
- **Placeholder System**: Use `$1`, `$2`, etc. as placeholders that get resolved dynamically
- **Type Safety**: Strongly typed access to your data with automatic deserialization
- **Streaming Support**: Built-in support for data streams (SSE, WebSockets, etc.)
- **State Management**: Track loading states (pending, loaded, error) for each chunk
- **Flexible API**: Work with raw JSON or strongly typed objects
- **Error Handling**: Comprehensive error handling with fallback mechanisms

## 📦 Installation

Add this to your `pubspec.yaml`:

```yaml
dependencies:
  chunk_norris: ^1.0.0
```

## 🎯 Quick Start

### Basic ChunkJson Usage

```dart
import 'package:chunk_norris/chunk_norris.dart';

void main() async {
  // Initialize with JSON containing placeholders
  final chunkJson = ChunkJson.fromJson({
    'name': 'John Doe',
    'age': 30,
    'address': '\$1',  // Placeholder for chunk with ID "1"
    'metadata': '\$2', // Placeholder for chunk with ID "2"
  });

  // Listen for updates
  chunkJson.updateStream.listen((updatedData) {
    print('Data updated: $updatedData');
  });

  // Process incoming chunks
  await Future.delayed(Duration(seconds: 1));
  chunkJson.processChunk({
    '1': {'street': '123 Main St', 'city': 'Anytown'}
  });

  await Future.delayed(Duration(seconds: 1));
  chunkJson.processChunk({
    '2': {'source': 'api', 'timestamp': '2024-01-01T12:00:00Z'}
  });

  // Wait for all chunks to load
  final resolvedData = await chunkJson.waitForAllChunks();
  print('All chunks loaded: $resolvedData');

  // Clean up
  chunkJson.dispose();
}
```

### Typed ChunkObject Usage

```dart
import 'package:chunk_norris/chunk_norris.dart';

class User {
  final String name;
  final int age;
  final Address address;
  final Map<String, dynamic> metadata;

  User({
    required this.name,
    required this.age,
    required this.address,
    required this.metadata,
  });

  factory User.fromJson(Map<String, dynamic> json) => User(
    name: json['name'],
    age: json['age'],
    address: Address.fromJson(json['address']),
    metadata: json['metadata'],
  );
}

class Address {
  final String street;
  final String city;

  Address({required this.street, required this.city});
  
  factory Address.fromJson(Map<String, dynamic> json) => Address(
    street: json['street'],
    city: json['city'],
  );
}

void main() async {
  final userObject = ChunkObject.fromJson(
    {
      'name': 'John Doe',
      'age': 30,
      'address': '\$1',
      'metadata': '\$2',
    },
    User.fromJson,
    chunkFields: {
      'address': ChunkField.object<Address>('1', Address.fromJson),
      'metadata': ChunkField('2', (data) => data as Map<String, dynamic>),
    },
  );

  // Listen for complete object resolution
  userObject.listenObjectResolve((user) {
    print('User fully loaded: ${user.name}, ${user.address.street}');
  });

  // Process chunks
  userObject.processChunk({
    '1': {'street': '123 Main St', 'city': 'Anytown'}
  });

  userObject.processChunk({
    '2': {'source': 'api', 'timestamp': '2024-01-01T12:00:00Z'}
  });

  // Wait for all data
  await userObject.waitForData();
  final user = userObject.getData();
  print('Final user: $user');

  userObject.dispose();
}
```

## 🔧 Advanced Features

### Working with ChunkField

`ChunkField` provides type-safe access to chunked data with built-in deserializers:

```dart
// Built-in field types
final stringField = ChunkField.string('1');
final intField = ChunkField.integer('2');
final doubleField = ChunkField.decimal('3');
final boolField = ChunkField.boolean('4');
final listField = ChunkField.list<String>('5', (item) => item.toString());
final objectField = ChunkField.object<User>('6', User.fromJson);

// Custom deserializer
final customField = ChunkField<DateTime>('7', (data) {
  return DateTime.parse(data.toString());
});

// Check field state
print('Field state: ${stringField.state}');
print('Is resolved: ${stringField.isResolved}');
print('Has error: ${stringField.hasError}');

// Get value (throws if not loaded)
final value = stringField.value;

// Get value safely
final safeValue = stringField.valueOrNull;

// Wait for value
final futureValue = await stringField.future;
```

### Streaming Data Processing

```dart
// Process streaming data (e.g., Server-Sent Events)
final chunkJson = ChunkJson.fromJson(initialData);

// Convert SSE stream to chunk stream
final sseStream = EventSource('/api/stream');
final chunkStream = sseStream.map((event) => event.data);

// Process the stream
chunkJson.processChunkStream(chunkStream);
```

### State Management

```dart
final chunkJson = ChunkJson.fromJson(dataWithPlaceholders);

// Check individual key states
final keyState = chunkJson.getKeyState('address');
print('Address loading state: $keyState');

// Check if all chunks are resolved
print('All loaded: ${chunkJson.allChunksResolved}');

// Wait for specific value
final address = await chunkJson.getValueAsync('address');
```

### Error Handling

```dart
final chunkObject = ChunkObject.fromJson(
  initialData,
  User.fromJson,
  chunkFields: chunkFields,
);

// Listen for errors
chunkObject.listenObjectResolve(
  (user) => print('Success: $user'),
  onError: (error) => print('Error: $error'),
  onDone: () => print('Stream closed'),
);

// Handle partial data
final partialUser = chunkObject.getDataOrNull();
if (partialUser != null) {
  print('Partial data available: $partialUser');
}
```

## 🎛️ API Reference

### ChunkJson

| Method | Description |
|--------|-------------|
| `ChunkJson.fromJson(Map<String, dynamic> json)` | Create instance from JSON with placeholders |
| `getValue(String key)` | Get resolved value for key |
| `getValueAsync(String key)` | Get Future for value |
| `getKeyState(String key)` | Get loading state for key |
| `getResolvedData()` | Get fully resolved JSON |
| `processChunk(Map<String, dynamic> chunk)` | Process incoming chunk |
| `processChunkStream(Stream<String> stream)` | Process chunk stream |
| `waitForAllChunks()` | Wait for all chunks to load |
| `updateStream` | Stream of data updates |
| `dispose()` | Clean up resources |

### ChunkObject<T>

| Method | Description |
|--------|-------------|
| `ChunkObject.fromJson(json, deserializer, {chunkFields})` | Create typed object instance |
| `getData()` | Get fully resolved object (throws if not ready) |
| `getDataOrNull()` | Get object or null if not ready |
| `processChunk(Map<String, dynamic> chunk)` | Process incoming chunk |
| `listenObjectResolve(callback)` | Listen for full object resolution |
| `listenObjectUpdate(callback)` | Listen for any object updates |
| `listenChunkUpdate(callback)` | Listen for chunk updates |
| `waitForData()` | Wait for all data to load |
| `allChunksResolved` | Check if all chunks are loaded |

### ChunkField<T>

| Property/Method | Description |
|----------------|-------------|
| `state` | Current loading state |
| `isResolved` | Whether field is loaded |
| `hasError` | Whether field has error |
| `value` | Get resolved value (throws if not ready) |
| `valueOrNull` | Get resolved value or null |
| `future` | Future that completes when loaded |
| `resolve(data)` | Resolve field with data |

### ChunkState

| State | Description |
|-------|-------------|
| `ChunkState.pending` | Data not yet loaded |
| `ChunkState.loaded` | Data successfully loaded |
| `ChunkState.error` | Error occurred during loading |

## 🎨 Custom Placeholder Patterns

By default, Chunk Norris uses the pattern `$<id>` for placeholders (e.g., `$123`, `$456`). You can customize this pattern by providing a custom RegExp to match your specific needs.

### Using Custom Patterns

```dart
// Default pattern: $123, $456, etc.
final chunkJson = ChunkJson.fromJson({
  'user': '$123',
  'posts': '$456',
});

// Custom pattern: {id:123}, {id:456}, etc.
final customChunkJson = ChunkJson.fromJson({
  'user': '{id:123}',
  'posts': '{id:456}',
}, placeholderPattern: RegExp(r'^\{id:(\d+)\}$'));

// Custom pattern: @var123, @var456, etc.
final varChunkJson = ChunkJson.fromJson({
  'user': '@var123',
  'posts': '@var456',
}, placeholderPattern: RegExp(r'^@var(\d+)$'));
```

### Custom Patterns with ChunkObject

```dart
final userObject = ChunkObject.fromJson(
  {
    'name': '{id:123}',
    'email': '{id:456}',
    'profile': '{id:789}',
  },
  (json) => User.fromJson(json),
  placeholderPattern: RegExp(r'^\{id:(\d+)\}$'),
  chunkFields: {
    'name': ChunkField.string('123'),
    'email': ChunkField.string('456'),
    'profile': ChunkField.object<UserProfile>('789', UserProfile.fromJson),
  },
);
```

### Pattern Requirements

Your custom RegExp pattern must:

- Include exactly one capture group `()` for the placeholder ID
- Match the complete placeholder string (use `^` and `$` anchors)
- Extract a unique identifier from the first capture group

### Pattern Examples

| Pattern | RegExp | Matches | Extracts |
|---------|--------|---------|----------|
| Default | `^\$(\d+)$` | `$123`, `$456` | `123`, `456` |
| Braces | `^\{id:(\d+)\}$` | `{id:123}`, `{id:456}` | `123`, `456` |
| Variables | `^@var(\d+)$` | `@var123`, `@var456` | `123`, `456` |
| Custom | `^placeholder_(\w+)$` | `placeholder_user`, `placeholder_posts` | `user`, `posts` |

## 🌟 Use Cases

### Server-Sent Events, WebSockets (SSE, WS)

Perfect for real-time data streaming where the initial response contains a skeleton and subsequent events fill in the details.

### Progressive Web Apps

Load critical data first, then enhance with additional information as it becomes available.

### API Optimization

Reduce initial response times by sending partial data immediately and streaming the rest.

### Data Aggregation from Multiple Sources

Combine data from different sources (databases, APIs, files) into a single unified model. Load available data immediately and fill in missing pieces as they become available from slower sources.

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## 📝 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

**Remember**: When Chuck Norris needs JSON data, it loads instantly. When you need JSON data, use Chunk Norris! 🥋
