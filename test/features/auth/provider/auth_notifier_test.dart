import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/models/user.dart';
import 'package:lantern/core/utils/failure.dart';
import 'package:lantern/features/auth/provider/auth_notifier.dart';
import 'package:lantern/lantern/lantern_service.dart';
import 'package:lantern/lantern/lantern_service_notifier.dart';

UserResponseModel _successUser() => const UserResponseModel(
  legacyID: 0,
  legacyToken: '',
  emailConfirmed: false,
  success: true,
);

class _FakeLanternService implements LanternService {
  String? loginEmail;
  String? loginPassword;
  Either<Failure, UserResponseModel> loginResult = right(_successUser());

  String? signUpEmail;
  String? signUpPassword;
  Either<Failure, Unit> signUpResult = right(unit);

  String? deleteEmail;
  String? deletePassword;
  bool? deleteIsSSO;
  Either<Failure, UserResponseModel> deleteResult = right(_successUser());

  @override
  Future<Either<Failure, UserResponseModel>> login({
    required String email,
    required String password,
  }) async {
    loginEmail = email;
    loginPassword = password;
    return loginResult;
  }

  @override
  Future<Either<Failure, Unit>> signUp({
    required String email,
    required String password,
  }) async {
    signUpEmail = email;
    signUpPassword = password;
    return signUpResult;
  }

  @override
  Future<Either<Failure, UserResponseModel>> deleteAccount({
    required String email,
    required String password,
    bool isSSO = false,
  }) async {
    deleteEmail = email;
    deletePassword = password;
    deleteIsSSO = isSSO;
    return deleteResult;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('AuthNotifier', () {
    test('signInWithEmail forwards credentials and returns success', () async {
      final fakeService = _FakeLanternService()..loginResult = right(_successUser());
      final container = ProviderContainer(
        overrides: [lanternServiceProvider.overrideWithValue(fakeService)],
      );
      addTearDown(container.dispose);

      final notifier = container.read(authProvider.notifier);
      final result = await notifier.signInWithEmail(
        'person@example.com',
        'pass-123',
      );

      expect(fakeService.loginEmail, equals('person@example.com'));
      expect(fakeService.loginPassword, equals('pass-123'));
      expect(result.isRight(), isTrue);
    });

    test('signInWithEmail returns service failure unchanged', () async {
      final failure = Failure(
        error: 'login failed',
        localizedErrorMessage: 'Invalid credentials',
      );
      final fakeService = _FakeLanternService()..loginResult = left(failure);
      final container = ProviderContainer(
        overrides: [lanternServiceProvider.overrideWithValue(fakeService)],
      );
      addTearDown(container.dispose);

      final notifier = container.read(authProvider.notifier);
      final result = await notifier.signInWithEmail(
        'person@example.com',
        'bad-pass',
      );

      result.match(
        (err) =>
            expect(err.localizedErrorMessage, equals('Invalid credentials')),
        (_) => fail('Expected Left(Failure), got Right(UserResponseModel)'),
      );
    });

    test('signUpWithEmail forwards args and returns service result', () async {
      final fakeService = _FakeLanternService()..signUpResult = right(unit);
      final container = ProviderContainer(
        overrides: [lanternServiceProvider.overrideWithValue(fakeService)],
      );
      addTearDown(container.dispose);

      final notifier = container.read(authProvider.notifier);
      final result = await notifier.signUpWithEmail(
        'new@example.com',
        'temp-pw',
      );

      expect(fakeService.signUpEmail, equals('new@example.com'));
      expect(fakeService.signUpPassword, equals('temp-pw'));
      expect(result.isRight(), isTrue);
    });

    test('deleteAccount forwards args and returns service result', () async {
      final fakeService = _FakeLanternService()
        ..deleteResult = right(_successUser());
      final container = ProviderContainer(
        overrides: [lanternServiceProvider.overrideWithValue(fakeService)],
      );
      addTearDown(container.dispose);

      final notifier = container.read(authProvider.notifier);
      final result = await notifier.deleteAccount(
        'person@example.com',
        'pw',
        false,
      );

      expect(fakeService.deleteEmail, equals('person@example.com'));
      expect(fakeService.deletePassword, equals('pw'));
      expect(fakeService.deleteIsSSO, isFalse);
      expect(result.isRight(), isTrue);
    });
  });
}
