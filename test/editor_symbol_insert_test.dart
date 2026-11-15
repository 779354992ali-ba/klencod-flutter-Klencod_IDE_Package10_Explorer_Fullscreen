import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bisho_ide/core/services/editor_symbol_insert.dart';

void main() {
  group('EditorSymbolInsert', () {
    test('inserts paired brackets and keeps cursor inside', () {
      final result = EditorSymbolInsert.apply(
        text: 'ab',
        selection: const TextSelection.collapsed(offset: 1),
        symbol: '(',
      );
      expect(result.text, 'a()b');
      expect(result.selection, const TextSelection.collapsed(offset: 2));
    });

    test('wraps selected text with paired symbols', () {
      final result = EditorSymbolInsert.apply(
        text: 'hello world',
        selection: const TextSelection(baseOffset: 6, extentOffset: 11),
        symbol: '[',
      );
      expect(result.text, 'hello [world]');
      expect(result.selection, const TextSelection.collapsed(offset: 13));
    });

    test('inserts tab indentation as two spaces', () {
      final result = EditorSymbolInsert.apply(
        text: 'xy',
        selection: const TextSelection.collapsed(offset: 1),
        symbol: 'TAB',
      );
      expect(result.text, 'x  y');
      expect(result.selection, const TextSelection.collapsed(offset: 3));
    });

    test('inserts plain symbols at the cursor', () {
      final result = EditorSymbolInsert.apply(
        text: 'ab',
        selection: const TextSelection.collapsed(offset: 1),
        symbol: ';',
      );
      expect(result.text, 'a;b');
      expect(result.selection, const TextSelection.collapsed(offset: 2));
    });
  });
}
