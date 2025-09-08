import 'package:lantern/core/common/app_eum.dart';
import 'package:objectbox/objectbox.dart';

@Entity()
class AppSetting {
  @Id()
  int id;

  bool isPro;
  bool isSplitTunnelingOn;
  BypassListOption bypassList;
  SplitTunnelingMode splitTunnelingMode;
  String locale;
  String oAuthToken;
  bool userLoggedIn;
  bool blockAds;
  String email;
  bool showSplashScreen;

  AppSetting({
    this.id = 0,
    this.isPro = false,
    this.isSplitTunnelingOn = false,
    this.userLoggedIn = false,
    this.splitTunnelingMode = SplitTunnelingMode.automatic,
    this.oAuthToken = '',
    this.blockAds = false,
    this.bypassList = BypassListOption.global,
    this.email = '',
    this.locale = 'en_US',
    this.showSplashScreen = true,
  });

  AppSetting copyWith({
    bool? newPro,
    bool? newIsSpiltTunnelingOn,
    String? newLocale,
    bool? userLoggedIn,
    bool? blockAds,
    String? oAuthToken,
    String? email,
    SplitTunnelingMode? newSplitTunnelingMode,
    BypassListOption? newBypassList,
    bool? showSplashScreen,
  }) {
    return AppSetting(
      id: id,
      isPro: newPro ?? isPro,
      bypassList: newBypassList ?? bypassList,
      isSplitTunnelingOn: newIsSpiltTunnelingOn ?? isSplitTunnelingOn,
      locale: newLocale ?? locale,
      blockAds: blockAds ?? this.blockAds,
      splitTunnelingMode: newSplitTunnelingMode ?? splitTunnelingMode,
      userLoggedIn: userLoggedIn ?? this.userLoggedIn,
      oAuthToken: oAuthToken ?? this.oAuthToken,
      email: email ?? this.email,
      showSplashScreen: showSplashScreen ?? this.showSplashScreen,
    );
  }
}
