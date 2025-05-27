import 'package:lantern/core/utils/url_utils.dart';
import 'package:lantern/lantern/lantern_service_notifier.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'account_notifier.g.dart';

@Riverpod()
class AccountNotifier extends _$AccountNotifier {
  @override
  Future<void> build() async {}

  void openAppleSubscriptions() async {
    final result =
        await ref.read(lanternServiceProvider).showManageSubscriptions();

    result.fold((failure) {
      UrlUtils.openUrl("https://apps.apple.com/account/subscriptions");
    }, (_) {});
  }
}
