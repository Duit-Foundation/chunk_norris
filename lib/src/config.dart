final class Config {
  final Pattern chunkPlaceholderFormat;

  Config._({
    required this.chunkPlaceholderFormat,
  });

  factory Config.defaultConfig() => Config._(
        chunkPlaceholderFormat: RegExp(r'^\$(\d+)$'),
      );
}
