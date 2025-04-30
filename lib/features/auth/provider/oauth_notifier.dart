import 'package:fpdart/src/either.dart';
import 'package:lantern/core/utils/failure.dart';
import 'package:lantern/lantern/lantern_service_notifier.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'oauth_notifier.g.dart';

@Riverpod()
class OAuthNotifier extends _$OAuthNotifier {
  @override
  Future<void> build() async {
    // Initialize any necessary state or perform setup here
  }

  Future<Either<Failure, String>> oAuthLogin(String provider) async {
    return ref.read(lanternServiceProvider).getOAuthLoginUrl(provider);
  }
}
