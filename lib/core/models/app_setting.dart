import 'package:lantern/core/models/relay_stats.dart';

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
  // Lifetime running total of peers this device has helped. Survives
  // restarts so the "Total people helped to date" stat in the
  // Unbounded tab can keep climbing — that's the spec wording in the
  // Figma. ShareNotifier seeds totalCount from this on build, and
  // writes back each time the count increments.
  final int unboundedTotalHelped;
  // Lifetime Unbounded bytes relayed (down: to the people helped, up: from
  // them) and the per-country breakdown behind Advanced stats. Written by
  // ShareNotifier on a throttle, not on every snapshot.
  final int unboundedBytesDown;
  final int unboundedBytesUp;
  final Map<String, RelayCountryStats> unboundedCountryStats;
  // The backend epoch and byte counters already folded into the totals
  // above, so a restarted app resumes counting where it left off.
  final String unboundedRelayEpoch;
  final int unboundedRelayMarkDown;
  final int unboundedRelayMarkUp;

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
    this.unboundedAutoEnable = false,
    this.unboundedHidden = false,
    this.unboundedWelcomeSeen = false,
    this.unboundedTotalHelped = 0,
    this.unboundedBytesDown = 0,
    this.unboundedBytesUp = 0,
    this.unboundedCountryStats = const {},
    this.unboundedRelayEpoch = '',
    this.unboundedRelayMarkDown = 0,
    this.unboundedRelayMarkUp = 0,
  });

  /// Whether the app points at the staging backend. The notifier writes
  /// 'stage'; 'staging' is accepted for older stored settings.
  bool get isStaging => environment == 'stage' || environment == 'staging';

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
    int? unboundedTotalHelped,
    int? unboundedBytesDown,
    int? unboundedBytesUp,
    Map<String, RelayCountryStats>? unboundedCountryStats,
    String? unboundedRelayEpoch,
    int? unboundedRelayMarkDown,
    int? unboundedRelayMarkUp,
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
      unboundedTotalHelped:
          unboundedTotalHelped ?? this.unboundedTotalHelped,
      unboundedBytesDown: unboundedBytesDown ?? this.unboundedBytesDown,
      unboundedBytesUp: unboundedBytesUp ?? this.unboundedBytesUp,
      unboundedCountryStats:
          unboundedCountryStats ?? this.unboundedCountryStats,
      unboundedRelayEpoch: unboundedRelayEpoch ?? this.unboundedRelayEpoch,
      unboundedRelayMarkDown:
          unboundedRelayMarkDown ?? this.unboundedRelayMarkDown,
      unboundedRelayMarkUp: unboundedRelayMarkUp ?? this.unboundedRelayMarkUp,
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
        'unboundedTotalHelped': unboundedTotalHelped,
        'unboundedBytesDown': unboundedBytesDown,
        'unboundedBytesUp': unboundedBytesUp,
        'unboundedCountryStats':
            RelayCountryStats.mapToJson(unboundedCountryStats),
        'unboundedRelayEpoch': unboundedRelayEpoch,
        'unboundedRelayMarkDown': unboundedRelayMarkDown,
        'unboundedRelayMarkUp': unboundedRelayMarkUp,
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
        // Opt-in: auto-enable only when the user explicitly turned it on.
        // Missing/unset means manual — Unbounded does not start on its own
        // until the user enables it (toggle) or opts into auto-enable.
        unboundedAutoEnable: json['unboundedAutoEnable'] == true,
        unboundedHidden: json['unboundedHidden'] == true,
        unboundedWelcomeSeen: json['unboundedWelcomeSeen'] == true,
        unboundedTotalHelped:
            (json['unboundedTotalHelped'] as num?)?.toInt() ?? 0,
        unboundedBytesDown:
            (json['unboundedBytesDown'] as num?)?.toInt() ?? 0,
        unboundedBytesUp: (json['unboundedBytesUp'] as num?)?.toInt() ?? 0,
        unboundedCountryStats:
            RelayCountryStats.mapFromJson(json['unboundedCountryStats']),
        unboundedRelayEpoch: (json['unboundedRelayEpoch'] ?? '').toString(),
        unboundedRelayMarkDown:
            (json['unboundedRelayMarkDown'] as num?)?.toInt() ?? 0,
        unboundedRelayMarkUp:
            (json['unboundedRelayMarkUp'] as num?)?.toInt() ?? 0,
      );
}
