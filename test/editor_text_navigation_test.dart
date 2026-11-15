import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bisho_ide/core/services/editor_text_navigation.dart';

void main() {
  group('EditorTextNavigation', () {
    test('selects the word under the caret', () {
      expect(
        EditorTextNavigation.selectCurrentWord('final currentName = 42;', 9),
        const TextSelection(baseOffset: 6, extentOffset: 17),
      );
    });

    test('selects the previous word when caret is at its end', () {
      expect(
        EditorTextNavigation.selectCurrentWord('hello world', 5),
        const TextSelection(baseOffset: 0, extentOffset: 5),
      );
    });

    test('returns a collapsed selection when no word is available', () {
      expect(
        EditorTextNavigation.selectCurrentWord('   ', 1),
        const TextSelection.collapsed(offset: 1),
      );
    });

    test('finds line start and end without including newline', () {
      const source = 'first line\nsecond';
      expect(EditorTextNavigation.lineStart(source, 13), 11);
      expect(EditorTextNavigation.lineEnd(source, 3), 10);
      expect(EditorTextNavigation.moveToLineBoundary(source, 13, end: true), 17);
    });

    test('replaces a selection with multi-line clipboard content', () {
      final result = EditorTextNavigation.replaceSelection(
        'before selected after',
        const TextSelection(baseOffset: 7, extentOffset: 15),
        'first line\nsecond line',
      );
      expect(result.text, 'before first line\nsecond line after');
      expect(result.selection.extentOffset, 29);
    });

    test('moves to previous and next word boundaries', () {
      const source = 'alpha   beta_gamma end';
      expect(EditorTextNavigation.moveByWord(source, 8, forward: true), 19);
      expect(EditorTextNavigation.moveByWord(source, 12, forward: false), 8);
    });
  });
}
