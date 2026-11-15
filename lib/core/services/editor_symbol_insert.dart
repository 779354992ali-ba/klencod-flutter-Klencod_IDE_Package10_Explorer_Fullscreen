import 'package:flutter/services.dart';

/// Builds a safe text edit for the mobile editor's symbol bar.
class EditorSymbolInsert {
  static const Map<String, String> _pairs = <String, String>{
    '(': ')',
    '[': ']',
    '{': '}',
    "'": "'",
    '"': '"',
    '`': '`',
  };

  static TextEditingValue apply({
    required String text,
    required TextSelection selection,
    required String symbol,
  }) {
    final safeSelection = selection.isValid
        ? TextSelection(
            baseOffset: selection.baseOffset.clamp(0, text.length).toInt(),
            extentOffset: selection.extentOffset.clamp(0, text.length).toInt(),
          )
        : TextSelection.collapsed(offset: text.length);

    final start = safeSelection.start;
    final end = safeSelection.end;
    final selected = text.substring(start, end);
    final closing = _pairs[symbol];

    if (closing != null) {
      final replacement = '$symbol$selected$closing';
      final nextText = text.replaceRange(start, end, replacement);
      final cursor = selected.isEmpty
          ? start + symbol.length
          : start + replacement.length;
      return TextEditingValue(
        text: nextText,
        selection: TextSelection.collapsed(offset: cursor),
      );
    }

    final insertion = symbol == 'TAB' ? '  ' : symbol;
    final nextText = text.replaceRange(start, end, insertion);
    final cursor = start + insertion.length;
    return TextEditingValue(
      text: nextText,
      selection: TextSelection.collapsed(offset: cursor),
    );
  }
}
