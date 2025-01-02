import 'package:characters/characters.dart';

String addNonBreakingSpaces(String text) {
  return Characters(text).toList().join('\u{200B}');
}
