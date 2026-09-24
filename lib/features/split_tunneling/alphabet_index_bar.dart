import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lantern/core/common/common.dart';

/// Vertical index strip pinned to the edge of a list, like the one in the
/// system contacts app. [letters] are the letters that have entries, in
/// display order. [currentLetter] is the letter at the top of the list and is
/// highlighted; while the user taps or drags over the strip, the letter under
/// the pointer takes over the highlight and is reported through
/// [onLetterSelected].
class AlphabetIndexBar extends StatefulWidget {
  final List<String> letters;
  final String? currentLetter;
  final ValueChanged<String> onLetterSelected;

  const AlphabetIndexBar({
    super.key,
    required this.letters,
    required this.currentLetter,
    required this.onLetterSelected,
  });

  static const width = 16.0;

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
    setState(() => _pressed = letter);
    HapticFeedback.selectionClick();
    widget.onLetterSelected(letter);
  }

  void _release() {
    if (_pressed != null) {
      setState(() => _pressed = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final highlighted = _pressed ?? widget.currentLetter;

    return LayoutBuilder(
      builder: (context, constraints) {
        final count = math.max(widget.letters.length, 1);
        final letterHeight = math.min(22.0, constraints.maxHeight / count);
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
                    _IndexLetter(
                      letter: letter,
                      height: letterHeight,
                      fontSize: fontSize,
                      highlighted: letter == highlighted,
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

class _IndexLetter extends StatelessWidget {
  final String letter;
  final double height;
  final double fontSize;
  final bool highlighted;

  const _IndexLetter({
    required this.letter,
    required this.height,
    required this.fontSize,
    required this.highlighted,
  });

  static const _duration = Duration(milliseconds: 180);

  @override
  Widget build(BuildContext context) {
    final pill = math.min(height, AlphabetIndexBar.width) - 2;

    return SizedBox(
      height: height,
      child: Center(
        child: AnimatedContainer(
          duration: _duration,
          curve: Curves.easeOut,
          width: pill,
          height: pill,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: highlighted ? context.textLink : Colors.transparent,
          ),
          child: Center(
            child: AnimatedScale(
              duration: _duration,
              curve: Curves.easeOutBack,
              scale: highlighted ? 1.35 : 1.0,
              child: AnimatedDefaultTextStyle(
                duration: _duration,
                style: TextStyle(
                  fontSize: fontSize,
                  fontWeight: highlighted ? FontWeight.w700 : FontWeight.w600,
                  color: highlighted
                      ? context.textInverse
                      : context.textSecondary,
                ),
                child: Text(letter),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
