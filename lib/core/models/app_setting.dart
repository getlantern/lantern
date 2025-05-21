import 'package:objectbox/objectbox.dart';

@Entity()
class AppSetting {
  @Id()
  int id;

  bool isPro;
  bool isSpiltTunnelingOn;
  String splitTunnelingMode;
  String locale;
  String oAuthToken;
  bool userLoggedIn;

  AppSetting({
    this.id = 0,
    this.isPro = false,
    this.isSpiltTunnelingOn = false,
    this.userLoggedIn = false,
    this.splitTunnelingMode = 'Automatic',
    this.oAuthToken = '',
    this.locale = 'en_US',
  });

  AppSetting copyWith({
    bool? newPro,
    bool? newIsSpiltTunnelingOn,
    String? newLocale,
    String? newSplitTunnelingMode,
    bool? userLoggedIn,
    String? oAuthToken,
  }) {
    return AppSetting(
      id: id,
      isPro: newPro ?? isPro,
      isSpiltTunnelingOn: newIsSpiltTunnelingOn ?? isSpiltTunnelingOn,
      locale: newLocale ?? locale,
      splitTunnelingMode: newSplitTunnelingMode ?? splitTunnelingMode,
      userLoggedIn: userLoggedIn ?? this.userLoggedIn,
      oAuthToken: oAuthToken ?? this.oAuthToken,
    );
  }
}
