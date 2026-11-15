/// Lightweight, dependency-free statistics for the currently open editor tabs.
/// These metrics describe only the supplied sources; they do not scan disk.
class WorkspaceMetrics {
  final int fileCount;
  final int lineCount;
  final int wordCount;
  final int characterCount;

  const WorkspaceMetrics({
    required this.fileCount,
    required this.lineCount,
    required this.wordCount,
    required this.characterCount,
  });

  factory WorkspaceMetrics.fromSources(Iterable<String> sources) {
    var files = 0;
    var lines = 0;
    var words = 0;
    var characters = 0;

    for (final source in sources) {
      files++;
      characters += source.length;
      lines += source.isEmpty ? 1 : '\n'.allMatches(source).length + 1;
      words += RegExp(r'\S+').allMatches(source).length;
    }

    return WorkspaceMetrics(
      fileCount: files,
      lineCount: lines,
      wordCount: words,
      characterCount: characters,
    );
  }
}
