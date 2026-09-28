import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lantern/core/common/common.dart';

/// Vertical index strip pinned to the edge of a list, like the one in the
/// system contacts app. [letters] are the letters that have entries, in
/// display order. Tapping or dragging over the strip reports the letter under
/// the pointer through [onLetterSelected].
class AlphabetIndexBar extends StatefulWidget {
  final List<String> letters;
  final ValueChanged<String> onLetterSelected;

  const AlphabetIndexBar({
    super.key,
    required this.letters,
    required this.onLetterSelected,
  });

  static const width = 16.0;
  static const minLetterHeight = 8.0;

  @override
  State<AlphabetIndexBar> createState() => _AlphabetIndexBarState();
}

class _AlphabetIndexBarState extends State<AlphabetIndexBar> {
  String? _pressed;

  void _select(double dy, double letterHeight) {
    final letters = widget.letters;
    if (letters.isEmpty) return;
    final index = (dy / letterHeight).floor().clamp(0, letters.length - 1);
    final letter = letters[index];
    if (letter == _pressed) return;
    _pressed = letter;
    HapticFeedback.selectionClick();
    widget.onLetterSelected(letter);
  }

  void _release() => _pressed = null;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final count = math.max(widget.letters.length, 1);
        final letterHeight = math.min(22.0, constraints.maxHeight / count);
        if (letterHeight < AlphabetIndexBar.minLetterHeight) {
          return const SizedBox.shrink();
        }
        final fontSize = math.min(10.5, letterHeight * 0.58);

        return Align(
          alignment: Alignment.topRight,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (d) => _select(d.localPosition.dy, letterHeight),
            onTapUp: (_) => _release(),
            onTapCancel: _release,
            onVerticalDragStart: (d) =>
                _select(d.localPosition.dy, letterHeight),
            onVerticalDragUpdate: (d) =>
                _select(d.localPosition.dy, letterHeight),
            onVerticalDragEnd: (_) => _release(),
            onVerticalDragCancel: _release,
            child: SizedBox(
              width: AlphabetIndexBar.width,
              height: letterHeight * widget.letters.length,
              child: Column(
                children: [
                  for (final letter in widget.letters)
                    SizedBox(
                      height: letterHeight,
                      child: Center(
                        child: Text(
                          letter,
                          style: TextStyle(
                            fontSize: fontSize,
                            fontWeight: FontWeight.w600,
                            color: context.textSecondary,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
