/// Enforces conservative resource limits while staging a SAF project for
/// WebView preview. This protects the editor from unbounded recursive copies.
class PreviewProjectGuard {
  PreviewProjectGuard({
    this.maxDepth = 32,
    this.maxEntries = 3000,
    this.maxFileBytes = 32 * 1024 * 1024,
    this.maxTotalBytes = 128 * 1024 * 1024,
  });

  final int maxDepth;
  final int maxEntries;
  final int maxFileBytes;
  final int maxTotalBytes;

  int entries = 0;
  int totalBytes = 0;

  void checkDepth(int depth) {
    if (depth > maxDepth) {
      throw StateError('Project directory depth exceeds $maxDepth.');
    }
  }

  void registerEntry() {
    entries++;
    if (entries > maxEntries) {
      throw StateError('Project contains more than $maxEntries entries.');
    }
  }

  void registerFileBytes(int byteCount) {
    if (byteCount < 0) {
      throw ArgumentError.value(byteCount, 'byteCount');
    }
    if (byteCount > maxFileBytes) {
      throw StateError('A project resource exceeds the per-file preview limit.');
    }
    if (totalBytes + byteCount > maxTotalBytes) {
      throw StateError('Project resources exceed the total preview limit.');
    }
    totalBytes += byteCount;
  }
}
