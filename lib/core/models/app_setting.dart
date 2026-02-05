import 'package:lantern/core/common/common.dart';

class AppSetting {
  final bool isPro;
  final bool isSplitTunnelingOn;
  final String locale;
  final String oAuthToken;
  final bool userLoggedIn;
  final bool blockAds;
  final String email;
  final bool showSplashScreen;
  final bool telemetryDialogDismissed;
  final bool telemetryConsent;
  final bool successfulConnection;
  final String routingModeRaw;
  final String dataCapThreshold;

  const AppSetting({
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
    this.routingModeRaw = 'full_tunnel',
    this.dataCapThreshold = '',
  });

  AppSetting copyWith({
    bool? newPro,
    bool? newIsSpiltTunnelingOn,
    String? newLocale,
    bool? userLoggedIn,
    bool? blockAds,
    String? oAuthToken,
    String? email,
    bool? showSplashScreen,
    bool? showTelemetryDialog,
    bool? telemetryConsent,
    bool? successfulConnection,
    String? routingModeRaw,
    String? dataCapThreshold,
  }) {
    return AppSetting(
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
      routingModeRaw: routingModeRaw ?? this.routingModeRaw,
      dataCapThreshold: dataCapThreshold ?? this.dataCapThreshold,
    );
  }

  RoutingMode get routingMode => RoutingModeX.fromRaw(routingModeRaw);

  Map<String, dynamic> toJson() => {
        'isPro': isPro,
        'isSplitTunnelingOn': isSplitTunnelingOn,
        'userLoggedIn': userLoggedIn,
        'oAuthToken': oAuthToken,
        'blockAds': blockAds,
        'email': email,
        'locale': locale,
        'showSplashScreen': showSplashScreen,
        'telemetryDialogDismissed': telemetryDialogDismissed,
        'telemetryConsent': telemetryConsent,
        'successfulConnection': successfulConnection,
        'routingModeRaw': routingModeRaw,
        'dataCapThreshold': dataCapThreshold,
      };

  factory AppSetting.fromJson(Map<String, dynamic> json) => AppSetting(
        isPro: json['isPro'] == true,
        isSplitTunnelingOn: json['isSplitTunnelingOn'] == true,
        userLoggedIn: json['userLoggedIn'] == true,
        oAuthToken: (json['oAuthToken'] ?? '').toString(),
        blockAds: json['blockAds'] == true,
        email: (json['email'] ?? '').toString(),
        locale: (json['locale'] ?? 'en_US').toString(),
        showSplashScreen: json['showSplashScreen'] != false,
        telemetryDialogDismissed: json['telemetryDialogDismissed'] == true,
        telemetryConsent: json['telemetryConsent'] == true,
        successfulConnection: json['successfulConnection'] == true,
        routingModeRaw: (json['routingModeRaw'] ?? 'full_tunnel').toString(),
        dataCapThreshold: (json['dataCapThreshold'] ?? '').toString(),
      );
}
