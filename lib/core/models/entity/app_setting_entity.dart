import 'package:lantern/core/common/app_eum.dart';
import 'package:objectbox/objectbox.dart';

@Entity()
class AppSetting {
  @Id()
  int id;

  bool isPro;
  bool isSplitTunnelingOn;
  String locale;
  String oAuthToken;
  bool userLoggedIn;
  bool blockAds;
  String email;
  bool showSplashScreen;
  bool telemetryDialogDismissed;
  bool telemetryConsent;
  bool successfulConnection;

  AppSetting({
    this.id = 0,
    this.isPro = false,
    this.isSplitTunnelingOn = false,
    this.userLoggedIn = false,

    this.oAuthToken = '',
    this.blockAds = false,
    this.email = '',
    this.locale = 'en_US',
    this.showSplashScreen = true,
    this.telemetryDialogDismissed = false,
    this.telemetryConsent = false,
    this.successfulConnection = false,
  });

  AppSetting copyWith({
    bool? newPro,
    bool? newIsSpiltTunnelingOn,
    String? newLocale,
    bool? userLoggedIn,
    bool? blockAds,
    String? oAuthToken,
    String? email,
    List<BypassListOption>? newBypassList,
    bool? showSplashScreen,
    bool? showTelemetryDialog,
    bool? telemetryConsent,
    bool? successfulConnection,
  }) {
    return AppSetting(
      id: id,
      isPro: newPro ?? isPro,

      isSplitTunnelingOn: newIsSpiltTunnelingOn ?? isSplitTunnelingOn,
      locale: newLocale ?? locale,
      blockAds: blockAds ?? this.blockAds,

      userLoggedIn: userLoggedIn ?? this.userLoggedIn,
      oAuthToken: oAuthToken ?? this.oAuthToken,
      email: email ?? this.email,
      showSplashScreen: showSplashScreen ?? this.showSplashScreen,
      telemetryDialogDismissed: showTelemetryDialog ?? telemetryDialogDismissed,
      telemetryConsent: telemetryConsent ?? this.telemetryConsent,
      successfulConnection: successfulConnection ?? this.successfulConnection,
    );
  }



}
