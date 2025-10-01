import 'package:fpdart/fpdart.dart';
import 'package:lantern/core/utils/failure.dart';
import 'package:lantern/lantern/lantern_service_notifier.dart';
import 'package:lantern/lantern/protos/protos/auth.pb.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'auth_notifier.g.dart';

@Riverpod(keepAlive: true)
class AuthNotifier extends _$AuthNotifier {
  @override
  Future<void> build() async {
    // Initialize any necessary state or perform setup here
  }

  Future<Either<Failure, String>> oAuthLogin(String provider) async {
    return ref.read(lanternServiceProvider).getOAuthLoginUrl(provider);
  }

  Future<Either<Failure, UserResponse>> oAuthLoginCallback(
      String authToken) async {
    return ref.read(lanternServiceProvider).oAuthLoginCallback(authToken);
  }

  Future<Either<Failure, UserResponse>> signInWithEmail(
      String email, String password) async {
    return ref.read(lanternServiceProvider).login(
          email: email,
          password: password,
        );
  }

  Future<Either<Failure, Unit>> signUpWithEmail(
      String email, String password) async {
    return ref.read(lanternServiceProvider).signUp(
          email: email,
          password: password,
        );
  }

  //Forgot password
  Future<Either<Failure, Unit>> startRecoveryByEmail(String email) async {
    return ref.read(lanternServiceProvider).startRecoveryByEmail(email);
  }

  Future<Either<Failure, Unit>> validateRecoveryCode(
      String email, String code) async {
    return ref.read(lanternServiceProvider).validateRecoveryCode(
          email: email,
          code: code,
        );
  }

  Future<Either<Failure, Unit>> completeRecoveryByEmail(
      String email, String newPassword, String code) async {
    return ref.read(lanternServiceProvider).completeRecoveryByEmail(
          email: email,
          newPassword: newPassword,
          code: code,
        );
  }

  Future<Either<Failure, String>> startChangeEmail(
      String newEmail, String password) async {
    return ref
        .read(lanternServiceProvider)
        .startChangeEmail(newEmail, password);
  }

  Future<Either<Failure, String>> completeChangeEmail(
      String newEmail, String password, String code) async {
    return ref.read(lanternServiceProvider).completeChangeEmail(
        newEmail: newEmail, password: password, code: code);
  }

  Future<Either<Failure, UserResponse>> deleteAccount(
      String email, String password) async {
    return ref
        .read(lanternServiceProvider)
        .deleteAccount(password: password, email: email);
  }

  Future<Either<Failure, String>> deviceRemove(String deviceID) async {
    return ref.read(lanternServiceProvider).deviceRemove(deviceId: deviceID);
  }
}
