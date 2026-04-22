class DeveloperMode {
  final bool enabled;
  final bool testPlayPurchaseEnabled;
  final bool testStripePurchaseEnabled;

  const DeveloperMode({
    this.enabled = false,
    this.testStripePurchaseEnabled = false,
    this.testPlayPurchaseEnabled = false,
  });

  factory DeveloperMode.initial() => const DeveloperMode();

  DeveloperMode copyWith({
    bool? enabled,
    bool? testPlayPurchaseEnabled,
    bool? testStripePurchaseEnabled,
  }) {
    return DeveloperMode(
      enabled: enabled ?? this.enabled,
      testPlayPurchaseEnabled:
          testPlayPurchaseEnabled ?? this.testPlayPurchaseEnabled,
      testStripePurchaseEnabled:
          testStripePurchaseEnabled ?? this.testStripePurchaseEnabled,
    );
  }

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'testPlayPurchaseEnabled': testPlayPurchaseEnabled,
        'testStripePurchaseEnabled': testStripePurchaseEnabled,
      };

  factory DeveloperMode.fromJson(Map<String, dynamic> json) => DeveloperMode(
        enabled: json['enabled'] == true,
        testPlayPurchaseEnabled: json['testPlayPurchaseEnabled'] == true,
        testStripePurchaseEnabled: json['testStripePurchaseEnabled'] == true,
      );
}
