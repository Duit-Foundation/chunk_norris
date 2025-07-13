## 1.0.0

- **Progressive JSON hydration**: Load JSON data incrementally as chunks arrive
- **Placeholder system**: Use `$1`, `$2`, etc. as placeholders that get resolved dynamically
- **Type safety**: Strongly typed access with `ChunkObject` and automatic deserialization
- **ChunkField API**: Type-safe fields with built-in deserializers (string, integer, decimal, boolean, list, object)
- **State management**: Track loading states (pending, loaded, error) for each chunk
- **Streaming support**: Built-in support for data streams (SSE, WebSockets)
- **Error handling**: Comprehensive error handling with fallback mechanisms
- **Resource management**: Proper disposal and cleanup of resources
