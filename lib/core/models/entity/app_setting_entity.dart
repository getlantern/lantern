import 'package:lantern/core/common/common.dart';
import 'package:objectbox/objectbox.dart';

@Entity()
class AppSetting {
  @Id()
  int id;

  bool isPro;
  bool isSplitTunnelingOn;
  String locale;
  String oAuthToken;
  String oAuthLoginProvider;
  bool userLoggedIn;
  bool blockAds;
  String email;
  bool showSplashScreen;
  bool telemetryDialogDismissed;
  bool telemetryConsent;
  bool successfulConnection;
  String routingModeRaw;
  String dataCapThreshold;
  bool onboardingCompleted;
  String themeMode;
  String environment;

  AppSetting({
    this.id = 0,
    this.isPro = false,
    this.isSplitTunnelingOn = false,
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
    this.themeMode = 'system',
    this.environment = 'prod',
  });

  AppSetting copyWith({
    bool? newPro,
    bool? newIsSpiltTunnelingOn,
    String? newLocale,
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
    String? themeMode,
    String? environment,
  }) {
    return AppSetting(
      id: id,
      isPro: newPro ?? isPro,
      isSplitTunnelingOn: newIsSpiltTunnelingOn ?? isSplitTunnelingOn,
      locale: newLocale ?? locale,
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
      themeMode: themeMode ?? this.themeMode,
      environment: environment ?? this.environment,
    );
  }

  /// True only when the user authenticated via OAuth AND the provider is known.
  /// If oAuthLoginProvider is empty (legacy install), treat as non-SSO to avoid
  /// blocking account deletion for users who haven't re-logged in.
  bool get isSSOUser => oAuthToken.isNotEmpty && oAuthLoginProvider.isNotEmpty;

  RoutingMode get routingMode => RoutingModeX.fromRaw(routingModeRaw);
  set routingMode(RoutingMode mode) => routingModeRaw = mode.key;
}
