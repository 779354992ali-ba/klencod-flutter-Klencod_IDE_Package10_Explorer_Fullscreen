import 'package:flutter/services.dart';

/// Pure text/selection helpers for predictable editor navigation.
class EditorTextNavigation {
  const EditorTextNavigation._();

  static TextSelection selectCurrentWord(String text, int rawOffset) {
    if (text.isEmpty) return const TextSelection.collapsed(offset: 0);
    final offset = rawOffset.clamp(0, text.length).toInt();
    final isWord = RegExp(r'[A-Za-z0-9_]').hasMatch;
    var pivot = offset;
    if (pivot == text.length || (pivot < text.length && !isWord(text[pivot]))) {
      if (pivot > 0 && isWord(text[pivot - 1])) {
        pivot--;
      } else {
        while (pivot < text.length && !isWord(text[pivot])) {
          pivot++;
        }
      }
    }
    if (pivot >= text.length || !isWord(text[pivot])) {
      return TextSelection.collapsed(offset: offset);
    }
    var start = pivot;
    var end = pivot + 1;
    while (start > 0 && isWord(text[start - 1])) {
      start--;
    }
    while (end < text.length && isWord(text[end])) {
      end++;
    }
    return TextSelection(baseOffset: start, extentOffset: end);
  }

  static int lineStart(String text, int rawOffset) {
    final offset = rawOffset.clamp(0, text.length).toInt();
    return text.lastIndexOf('\n', offset - 1) + 1;
  }

  static int lineEnd(String text, int rawOffset) {
    final offset = rawOffset.clamp(0, text.length).toInt();
    final next = text.indexOf('\n', offset);
    return next < 0 ? text.length : next;
  }

  static int moveToLineBoundary(String text, int rawOffset, {required bool end}) {
    return end ? lineEnd(text, rawOffset) : lineStart(text, rawOffset);
  }

  static TextEditingValue replaceSelection(
    String text,
    TextSelection selection,
    String replacement,
  ) {
    final start = selection.isValid
        ? selection.start.clamp(0, text.length).toInt()
        : text.length;
    final end = selection.isValid
        ? selection.end.clamp(start, text.length).toInt()
        : start;
    final updated = text.replaceRange(start, end, replacement);
    return TextEditingValue(
      text: updated,
      selection: TextSelection.collapsed(offset: start + replacement.length),
    );
  }

  static int moveByWord(String text, int rawOffset, {required bool forward}) {
    var offset = rawOffset.clamp(0, text.length).toInt();
    final isWord = RegExp(r'[A-Za-z0-9_]').hasMatch;
    if (forward) {
      while (offset < text.length && isWord(text[offset])) {
        offset++;
      }
      while (offset < text.length && !isWord(text[offset])) {
        offset++;
      }
    } else {
      while (offset > 0 && !isWord(text[offset - 1])) {
        offset--;
      }
      while (offset > 0 && isWord(text[offset - 1])) {
        offset--;
      }
    }
    return offset;
  }
}
