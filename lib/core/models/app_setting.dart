import 'package:objectbox/objectbox.dart';

@Entity()
class AppSetting {
  @Id()
  int id;

  bool isPro;
  bool isSpiltTunnelingOn;
  String splitTunnelingMode;
  String locale;

  AppSetting({
    this.id = 0,
    this.isPro = false,
    this.isSpiltTunnelingOn = false,
    this.splitTunnelingMode = 'Automatic',
    this.locale = 'en_US',
  });

  AppSetting copyWith({
    bool? newPro,
    bool? newIsSpiltTunnelingOn,
    String? newLocale,
    String? newSplitTunnelingMode,
  }) {
    return AppSetting(
      id: id,
      isPro: newPro ?? isPro,
      isSpiltTunnelingOn: newIsSpiltTunnelingOn ?? isSpiltTunnelingOn,
      locale: newLocale ?? locale,
      splitTunnelingMode: newSplitTunnelingMode ?? splitTunnelingMode,
    );
  }
}
