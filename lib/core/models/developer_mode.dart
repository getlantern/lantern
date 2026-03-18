class DeveloperMode {
  final bool testPlayPurchaseEnabled;
  final bool testStripePurchaseEnabled;

  const DeveloperMode({
    this.testStripePurchaseEnabled = false,
    this.testPlayPurchaseEnabled = false,
  });

  factory DeveloperMode.initial() => const DeveloperMode();

  DeveloperMode copyWith({
    bool? testPlayPurchaseEnabled,
    bool? testStripePurchaseEnabled,
  }) {
    return DeveloperMode(
      testPlayPurchaseEnabled:
          testPlayPurchaseEnabled ?? this.testPlayPurchaseEnabled,
      testStripePurchaseEnabled:
          testStripePurchaseEnabled ?? this.testStripePurchaseEnabled,
    );
  }

  Map<String, dynamic> toJson() => {
        'testPlayPurchaseEnabled': testPlayPurchaseEnabled,
        'testStripePurchaseEnabled': testStripePurchaseEnabled,
      };

  factory DeveloperMode.fromJson(Map<String, dynamic> json) => DeveloperMode(
        testPlayPurchaseEnabled: json['testPlayPurchaseEnabled'] == true,
        testStripePurchaseEnabled: json['testStripePurchaseEnabled'] == true,
      );
}
