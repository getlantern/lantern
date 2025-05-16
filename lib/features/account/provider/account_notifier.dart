import 'package:fpdart/src/either.dart';
import 'package:fpdart/src/unit.dart';
import 'package:lantern/core/utils/failure.dart';
import 'package:lantern/lantern/lantern_service_notifier.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'account_notifier.g.dart';

@Riverpod()
class AccountNotifier extends _$AccountNotifier {
  @override
  Future<void> build() async {}

  Future<Either<Failure, Unit>> showManageSubscriptionAppStore() async {
    return await ref.read(lanternServiceProvider).showManageSubscriptions();
  }
}
