import 'package:lantern/lantern/lantern_ffi_service.dart';

extension PointerExtension on Pointer<Char> {
  /// Converts a [Pointer] to a [String].
  String toDartString() {
    return cast<Utf8>().toDartString();
  }
}
