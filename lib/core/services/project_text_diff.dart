/// Line-oriented text comparison for editor buffers.
/// Uses an LCS table for bounded inputs and a safe replacement fallback for
/// very large comparisons to avoid unbounded memory use on mobile devices.
enum TextDiffKind { unchanged, added, removed }

class TextDiffLine {
  final TextDiffKind kind;
  final String text;
  final int? oldLine;
  final int? newLine;

  const TextDiffLine({required this.kind, required this.text,
    this.oldLine, this.newLine});
}

class ProjectTextDiffReport {
  final List<TextDiffLine> lines;
  final bool usedFallback;
  ProjectTextDiffReport(Iterable<TextDiffLine> lines,
      {this.usedFallback = false}) : lines = List.unmodifiable(lines);

  int get addedCount => lines.where((line) => line.kind == TextDiffKind.added).length;
  int get removedCount => lines.where((line) => line.kind == TextDiffKind.removed).length;
  int get unchangedCount => lines.where((line) => line.kind == TextDiffKind.unchanged).length;
  bool get hasChanges => addedCount > 0 || removedCount > 0;
}

class ProjectTextDiff {
  const ProjectTextDiff();
  static const int maxLcsCells = 250000;

  ProjectTextDiffReport compare(String before, String after) {
    final oldLines = _split(before);
    final newLines = _split(after);
    if (oldLines.length * newLines.length > maxLcsCells) {
      return _fallback(oldLines, newLines);
    }

    final rows = oldLines.length + 1;
    final cols = newLines.length + 1;
    final table = List<List<int>>.generate(rows, (_) => List<int>.filled(cols, 0));
    for (var i = oldLines.length - 1; i >= 0; i--) {
      for (var j = newLines.length - 1; j >= 0; j--) {
        table[i][j] = oldLines[i] == newLines[j]
            ? table[i + 1][j + 1] + 1
            : (table[i + 1][j] >= table[i][j + 1]
                ? table[i + 1][j] : table[i][j + 1]);
      }
    }

    final result = <TextDiffLine>[];
    var i = 0;
    var j = 0;
    while (i < oldLines.length || j < newLines.length) {
      if (i < oldLines.length && j < newLines.length && oldLines[i] == newLines[j]) {
        result.add(TextDiffLine(kind: TextDiffKind.unchanged,
            text: oldLines[i], oldLine: i + 1, newLine: j + 1));
        i++; j++;
      } else if (i < oldLines.length &&
          (j == newLines.length || table[i + 1][j] >= table[i][j + 1])) {
        result.add(TextDiffLine(kind: TextDiffKind.removed,
            text: oldLines[i], oldLine: i + 1));
        i++;
      } else {
        result.add(TextDiffLine(kind: TextDiffKind.added,
            text: newLines[j], newLine: j + 1));
        j++;
      }
    }
    return ProjectTextDiffReport(result);
  }

  List<String> _split(String value) {
    if (value.isEmpty) return const [];
    return value.replaceAll('\r\n', '\n').replaceAll('\r', '\n').split('\n');
  }

  ProjectTextDiffReport _fallback(List<String> oldLines, List<String> newLines) {
    var prefix = 0;
    while (prefix < oldLines.length && prefix < newLines.length &&
        oldLines[prefix] == newLines[prefix]) { prefix++; }
    var suffix = 0;
    while (suffix < oldLines.length - prefix && suffix < newLines.length - prefix &&
        oldLines[oldLines.length - 1 - suffix] == newLines[newLines.length - 1 - suffix]) {
      suffix++;
    }
    final result = <TextDiffLine>[];
    for (var i = 0; i < prefix; i++) {
      result.add(TextDiffLine(kind: TextDiffKind.unchanged, text: oldLines[i],
          oldLine: i + 1, newLine: i + 1));
    }
    for (var i = prefix; i < oldLines.length - suffix; i++) {
      result.add(TextDiffLine(kind: TextDiffKind.removed, text: oldLines[i], oldLine: i + 1));
    }
    for (var i = prefix; i < newLines.length - suffix; i++) {
      result.add(TextDiffLine(kind: TextDiffKind.added, text: newLines[i], newLine: i + 1));
    }
    for (var offset = suffix; offset > 0; offset--) {
      final oldIndex = oldLines.length - offset;
      final newIndex = newLines.length - offset;
      result.add(TextDiffLine(kind: TextDiffKind.unchanged, text: oldLines[oldIndex],
          oldLine: oldIndex + 1, newLine: newIndex + 1));
    }
    return ProjectTextDiffReport(result, usedFallback: true);
  }
}
