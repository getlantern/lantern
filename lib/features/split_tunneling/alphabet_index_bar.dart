import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/features/split_tunneling/utils/split_tunnel_app_utils.dart';

/// Vertical A-Z strip pinned to the edge of a list, like the one in the
/// system contacts app. [currentLetter] is the letter at the top of the list
/// and is highlighted; while the user taps or drags over the strip, the letter
/// under the pointer takes over the highlight and is reported through
/// [onLetterSelected] (snapped to the nearest letter that has entries).
class AlphabetIndexBar extends StatefulWidget {
  final Set<String> availableLetters;
  final String? currentLetter;
  final ValueChanged<String> onLetterSelected;

  const AlphabetIndexBar({
    super.key,
    required this.availableLetters,
    required this.currentLetter,
    required this.onLetterSelected,
  });

  static const width = 28.0;

  @override
  State<AlphabetIndexBar> createState() => _AlphabetIndexBarState();
}

class _AlphabetIndexBarState extends State<AlphabetIndexBar> {
  String? _pressed;

  void _select(double dy, double letterHeight) {
    final letters = alphabetIndexLetters;
    final raw = (dy / letterHeight).floor().clamp(0, letters.length - 1);
    final letter = _nearestAvailable(raw);
    if (letter == null || letter == _pressed) {
      return;
    }
    setState(() => _pressed = letter);
    HapticFeedback.selectionClick();
    widget.onLetterSelected(letter);
  }

  /// The tapped letter if it has entries, else the closest one that does,
  /// searching downwards first so a gap jumps forward like Contacts does.
  String? _nearestAvailable(int index) {
    final letters = alphabetIndexLetters;
    for (var offset = 0; offset < letters.length; offset++) {
      for (final candidate in [index + offset, index - offset]) {
        if (candidate < 0 || candidate >= letters.length) continue;
        if (widget.availableLetters.contains(letters[candidate])) {
          return letters[candidate];
        }
      }
    }
    return null;
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
        final count = alphabetIndexLetters.length;
        final letterHeight = math.min(20.0, constraints.maxHeight / count);
        final fontSize = math.min(11.0, letterHeight * 0.6);

        return Align(
          alignment: Alignment.centerRight,
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
              height: letterHeight * count,
              child: Column(
                children: [
                  for (final letter in alphabetIndexLetters)
                    _IndexLetter(
                      letter: letter,
                      height: letterHeight,
                      fontSize: fontSize,
                      available: widget.availableLetters.contains(letter),
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
  final bool available;
  final bool highlighted;

  const _IndexLetter({
    required this.letter,
    required this.height,
    required this.fontSize,
    required this.available,
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
                  fontWeight: highlighted ? FontWeight.w700 : FontWeight.w500,
                  color: highlighted
                      ? context.textInverse
                      : available
                      ? context.textSecondary
                      : context.textDisabled,
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
