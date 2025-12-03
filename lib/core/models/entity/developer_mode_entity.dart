import 'package:objectbox/objectbox.dart';

@Entity()
class DeveloperModeEntity {
  @Id()
  int id = 0;

  bool testPlayPurchaseEnabled;

  bool testStripePurchaseEnabled;

  DeveloperModeEntity({
    this.testStripePurchaseEnabled = false,
    this.testPlayPurchaseEnabled = false,
  });

  factory DeveloperModeEntity.initial() {
    return DeveloperModeEntity(
      testPlayPurchaseEnabled: false,
      testStripePurchaseEnabled: false,
    );
  }

  DeveloperModeEntity copyWith({
    bool? testPlayPurchaseEnabled,
    bool? testStripePurchaseEnabled,
  }) {
    return DeveloperModeEntity(
      testPlayPurchaseEnabled:
          testPlayPurchaseEnabled ?? this.testPlayPurchaseEnabled,
      testStripePurchaseEnabled:
          testStripePurchaseEnabled ?? this.testStripePurchaseEnabled,
    );
  }
}
