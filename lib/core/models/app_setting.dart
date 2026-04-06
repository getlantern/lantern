import 'package:lantern/core/common/common.dart';

class AppSetting {
  final bool isPro;
  final bool isSplitTunnelingOn;
  final String locale;
  final String themeMode;
  final String environment;
  final String oAuthToken;
  final String oAuthLoginProvider;
  final bool userLoggedIn;
  final bool blockAds;
  final String email;
  final bool showSplashScreen;
  final bool telemetryDialogDismissed;
  final bool telemetryConsent;
  final bool successfulConnection;
  final String routingModeRaw;
  final String dataCapThreshold;
  final bool onboardingCompleted;

  const AppSetting({
    this.isPro = false,
    this.isSplitTunnelingOn = false,
    this.themeMode = 'system',
    this.environment = 'prod',
    this.userLoggedIn = false,
    this.oAuthToken = '',
    this.oAuthLoginProvider = '',
    this.blockAds = false,
    this.email = '',
    this.locale = 'en_US',
    this.showSplashScreen = true,
    this.telemetryDialogDismissed = false,
    this.telemetryConsent = false,
    this.successfulConnection = false,
    this.routingModeRaw = 'full_tunnel',
    this.dataCapThreshold = '',
    this.onboardingCompleted = false,
  });

  AppSetting copyWith({
    bool? newPro,
    bool? newIsSpiltTunnelingOn,
    String? newLocale,
    String? themeMode,
    String? environment,
    bool? userLoggedIn,
    bool? blockAds,
    String? oAuthToken,
    String? oAuthLoginProvider,
    String? email,
    bool? showSplashScreen,
    bool? showTelemetryDialog,
    bool? telemetryConsent,
    bool? successfulConnection,
    String? routingModeRaw,
    String? dataCapThreshold,
    bool? onboardingCompleted,
  }) {
    return AppSetting(
      isPro: newPro ?? isPro,
      isSplitTunnelingOn: newIsSpiltTunnelingOn ?? isSplitTunnelingOn,
      locale: newLocale ?? locale,
      themeMode: themeMode ?? this.themeMode,
      environment: environment ?? this.environment,
      blockAds: blockAds ?? this.blockAds,
      userLoggedIn: userLoggedIn ?? this.userLoggedIn,
      oAuthToken: oAuthToken ?? this.oAuthToken,
      oAuthLoginProvider: oAuthLoginProvider ?? this.oAuthLoginProvider,
      email: email ?? this.email,
      showSplashScreen: showSplashScreen ?? this.showSplashScreen,
      telemetryDialogDismissed: showTelemetryDialog ?? telemetryDialogDismissed,
      telemetryConsent: telemetryConsent ?? this.telemetryConsent,
      successfulConnection: successfulConnection ?? this.successfulConnection,
      routingModeRaw: routingModeRaw ?? this.routingModeRaw,
      dataCapThreshold: dataCapThreshold ?? this.dataCapThreshold,
      onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
    );
  }

  RoutingMode get routingMode => RoutingModeX.fromRaw(routingModeRaw);

  Map<String, dynamic> toJson() => {
    'isPro': isPro,
    'isSplitTunnelingOn': isSplitTunnelingOn,
    'themeMode': themeMode,
    'environment': environment,
    'userLoggedIn': userLoggedIn,
    'oAuthToken': oAuthToken,
    'oAuthLoginProvider': oAuthLoginProvider,
    'blockAds': blockAds,
    'email': email,
    'locale': locale,
    'showSplashScreen': showSplashScreen,
    'telemetryDialogDismissed': telemetryDialogDismissed,
    'telemetryConsent': telemetryConsent,
    'successfulConnection': successfulConnection,
    'routingModeRaw': routingModeRaw,
    'dataCapThreshold': dataCapThreshold,
    'onboardingCompleted': onboardingCompleted,
  };

  factory AppSetting.fromJson(Map<String, dynamic> json) => AppSetting(
    isPro: json['isPro'] == true,
    isSplitTunnelingOn: json['isSplitTunnelingOn'] == true,
    themeMode: (json['themeMode'] ?? 'system').toString(),
    environment: (json['environment'] ?? 'prod').toString(),
    userLoggedIn: json['userLoggedIn'] == true,
    oAuthToken: (json['oAuthToken'] ?? '').toString(),
    oAuthLoginProvider: (json['oAuthLoginProvider'] ?? '').toString(),
    blockAds: json['blockAds'] == true,
    email: (json['email'] ?? '').toString(),
    locale: (json['locale'] ?? 'en_US').toString(),
    showSplashScreen: json['showSplashScreen'] != false,
    telemetryDialogDismissed: json['telemetryDialogDismissed'] == true,
    telemetryConsent: json['telemetryConsent'] == true,
    successfulConnection: json['successfulConnection'] == true,
    routingModeRaw: (json['routingModeRaw'] ?? 'full_tunnel').toString(),
    dataCapThreshold: (json['dataCapThreshold'] ?? '').toString(),
    onboardingCompleted: json['onboardingCompleted'] == true,
  );

  bool get isSSOUser => oAuthToken.isNotEmpty && oAuthLoginProvider.isNotEmpty;

  AppSetting clearAuthSessionData({bool clearEmail = true}) {
    return copyWith(
      newPro: false,
      userLoggedIn: false,
      oAuthToken: '',
      oAuthLoginProvider: '',
      email: clearEmail ? '' : email,
    );
  }
}
