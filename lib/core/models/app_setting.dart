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
      );
}
