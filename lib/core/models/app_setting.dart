class AppSetting {
  final String locale;
  final String themeMode;
  final String environment;
  final bool userLoggedIn;
  final bool showSplashScreen;
  final bool telemetryDialogDismissed;
  final bool successfulConnection;
  final String dataCapThreshold;
  final bool onboardingCompleted;
  // Unbounded preferences. autoEnable: turn the peer share on whenever
  // the VPN connects (defaults on per the Figma spec). hideTab: hide
  // the Unbounded tab + collapse the tab bar when the user doesn't
  // want to see it. welcomeSeen: tracks the first-visit info popup so
  // we only show it once. All persisted across launches.
  final bool unboundedAutoEnable;
  final bool unboundedHidden;
  final bool unboundedWelcomeSeen;

  const AppSetting({
    this.themeMode = 'system',
    this.environment = 'prod',
    this.userLoggedIn = false,
    this.locale = 'en_US',
    this.showSplashScreen = true,
    this.telemetryDialogDismissed = false,
    this.successfulConnection = false,
    this.dataCapThreshold = '',
    this.onboardingCompleted = false,
    this.unboundedAutoEnable = true,
    this.unboundedHidden = false,
    this.unboundedWelcomeSeen = false,
  });

  AppSetting copyWith({
    String? newLocale,
    String? themeMode,
    String? environment,
    bool? userLoggedIn,
    bool? showSplashScreen,
    bool? showTelemetryDialog,
    bool? successfulConnection,
    String? dataCapThreshold,
    bool? onboardingCompleted,
    bool? unboundedAutoEnable,
    bool? unboundedHidden,
    bool? unboundedWelcomeSeen,
  }) {
    return AppSetting(
      locale: newLocale ?? locale,
      themeMode: themeMode ?? this.themeMode,
      environment: environment ?? this.environment,
      userLoggedIn: userLoggedIn ?? this.userLoggedIn,
      showSplashScreen: showSplashScreen ?? this.showSplashScreen,
      telemetryDialogDismissed: showTelemetryDialog ?? telemetryDialogDismissed,
      successfulConnection: successfulConnection ?? this.successfulConnection,
      dataCapThreshold: dataCapThreshold ?? this.dataCapThreshold,
      onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
      unboundedAutoEnable: unboundedAutoEnable ?? this.unboundedAutoEnable,
      unboundedHidden: unboundedHidden ?? this.unboundedHidden,
      unboundedWelcomeSeen: unboundedWelcomeSeen ?? this.unboundedWelcomeSeen,
    );
  }

  Map<String, dynamic> toJson() => {
        'themeMode': themeMode,
        'environment': environment,
        'userLoggedIn': userLoggedIn,
        'locale': locale,
        'showSplashScreen': showSplashScreen,
        'telemetryDialogDismissed': telemetryDialogDismissed,
        'successfulConnection': successfulConnection,
        'dataCapThreshold': dataCapThreshold,
        'onboardingCompleted': onboardingCompleted,
        'unboundedAutoEnable': unboundedAutoEnable,
        'unboundedHidden': unboundedHidden,
        'unboundedWelcomeSeen': unboundedWelcomeSeen,
      };

  factory AppSetting.fromJson(Map<String, dynamic> json) => AppSetting(
        themeMode: (json['themeMode'] ?? 'system').toString(),
        environment: (json['environment'] ?? 'prod').toString(),
        userLoggedIn: json['userLoggedIn'] == true,
        locale: (json['locale'] ?? 'en_US').toString(),
        showSplashScreen: json['showSplashScreen'] != false,
        telemetryDialogDismissed: json['telemetryDialogDismissed'] == true,
        successfulConnection: json['successfulConnection'] == true,
        dataCapThreshold: (json['dataCapThreshold'] ?? '').toString(),
        onboardingCompleted: json['onboardingCompleted'] == true,
        // Default to true when missing (first-time post-upgrade users
        // should get the auto-enable behaviour the spec calls for).
        unboundedAutoEnable: json['unboundedAutoEnable'] != false,
        unboundedHidden: json['unboundedHidden'] == true,
        unboundedWelcomeSeen: json['unboundedWelcomeSeen'] == true,
      );
}
