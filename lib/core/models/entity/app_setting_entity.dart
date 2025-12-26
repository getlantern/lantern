import 'package:lantern/core/common/app_eum.dart';
import 'package:objectbox/objectbox.dart';

@Entity()
class AppSetting {
  @Id()
  int id;

  bool isPro;
  bool isSplitTunnelingOn;
  String bypassListRaw;
  String splitTunnelingModeRaw;
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
    this.splitTunnelingModeRaw = 'automatic',
    this.oAuthToken = '',
    this.blockAds = false,
    this.bypassListRaw = '',
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
    SplitTunnelingMode? newSplitTunnelingMode,
    List<BypassListOption>? newBypassList,
    bool? showSplashScreen,
    bool? showTelemetryDialog,
    bool? telemetryConsent,
    bool? successfulConnection,
  }) {
    return AppSetting(
      id: id,
      isPro: newPro ?? isPro,
      bypassListRaw:
          newBypassList?.map((e) => e.value).join(',') ?? bypassListRaw,
      isSplitTunnelingOn: newIsSpiltTunnelingOn ?? isSplitTunnelingOn,
      locale: newLocale ?? locale,
      blockAds: blockAds ?? this.blockAds,
      splitTunnelingModeRaw:
          newSplitTunnelingMode?.value ?? splitTunnelingModeRaw,
      userLoggedIn: userLoggedIn ?? this.userLoggedIn,
      oAuthToken: oAuthToken ?? this.oAuthToken,
      email: email ?? this.email,
      showSplashScreen: showSplashScreen ?? this.showSplashScreen,
      telemetryDialogDismissed: showTelemetryDialog ?? telemetryDialogDismissed,
      telemetryConsent: telemetryConsent ?? this.telemetryConsent,
      successfulConnection: successfulConnection ?? this.successfulConnection,
    );
  }

  SplitTunnelingMode get splitTunnelingMode =>
      splitTunnelingModeRaw.toSplitTunnelingMode;

  set splitTunnelingMode(SplitTunnelingMode mode) =>
      splitTunnelingModeRaw = mode.value;

  List<BypassListOption> get bypassList {
    if (bypassListRaw.isEmpty) return [];
    return bypassListRaw.split(',').map((e) => e.toBypassList).toList();
  }

  set bypassList(List<BypassListOption> list) {
    bypassListRaw = list.map((e) => e.value).join(',');
  }
}
