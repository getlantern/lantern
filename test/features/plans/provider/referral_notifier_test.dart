import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:i18n_extension/i18n_extension.dart' show Translations;
import 'package:lantern/core/localization/i18n.dart';
import 'package:lantern/core/models/referral_attach_response.dart';
import 'package:lantern/core/utils/failure.dart';
import 'package:lantern/features/plans/provider/referral_notifier.dart';
import 'package:lantern/lantern/lantern_service.dart';
import 'package:lantern/lantern/lantern_service_notifier.dart';

class _FakeLanternService implements LanternService {
  final submittedCodes = <String>[];
  Failure? failure;

  @override
  Future<Either<Failure, ReferralAttachV2Response>> attachReferralCodeV2(
    String code,
  ) async {
    submittedCodes.add(code);
    if (failure != null) return left(failure!);
    return right(
      ReferralAttachV2Response(
        plansData: null,
        code: code,
        discountPct: 0,
        type: ReferralType.referral,
      ),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const invalidCodeMessage =
      'The referral/promo code you entered is invalid. '
      'Please check the code and try again.';
  const invalidCodeMessageUrdu =
      'آپ کا درج کردہ ریفرل/پرومو کوڈ غلط ہے۔ براہ کرم کوڈ چیک کر کے دوبارہ کوشش کریں۔';
  late _FakeLanternService service;
  late ProviderContainer container;
  late ReferralNotifier notifier;

  setUpAll(() async {
    final previousTranslations = Localization.translations;
    addTearDown(() {
      Localization.translations = previousTranslations;
    });
    Localization.translations = Translations.byLocale('en-US');
    await Localization.loadTranslations();
  });

  setUp(() {
    final previousLocale = Localization.defaultLocale;
    Localization.defaultLocale = 'en_US';
    addTearDown(() => Localization.defaultLocale = previousLocale);
    service = _FakeLanternService();
    container = ProviderContainer(
      overrides: [lanternServiceProvider.overrideWithValue(service)],
    );
    notifier = container.read(referralProvider.notifier);
    addTearDown(container.dispose);
  });

  test('malformed codes never reach the referral service', () async {
    for (final code in [
      '',
      'A' * 501,
      'ſAVE15',
      'ßAVE15',
      'SAVE\\15',
      'SAVE%31%35',
      'SAVE\u000015',
      'SAVE\n15',
      'SAVE15&code=OTHER',
      'LSG_PROBE_1512_HTTPS_AFF_20260918T0608Z:JAVASCRIPT:ALERT(1)',
    ]) {
      final result = await notifier.applyReferralCodeV2(code);
      final failure = result.getLeft().toNullable();
      expect(failure?.error, 'invalid-referral-code');
      expect(failure?.localizedErrorMessage, invalidCodeMessage);
    }
    expect(service.submittedCodes, isEmpty);
    expect(container.read(referralProvider), isNull);
  });

  for (final entry in const {
    'en_US': invalidCodeMessage,
    'fr_CA':
        'Le code de parrainage/promo saisi est invalide. '
        'Veuillez vérifier le code et réessayer.',
    'ur': invalidCodeMessageUrdu,
    'ur_IN': invalidCodeMessageUrdu,
    'ur_PK': invalidCodeMessageUrdu,
  }.entries) {
    test('invalid referral message resolves for ${entry.key}', () async {
      Localization.defaultLocale = entry.key;

      final result = await notifier.applyReferralCodeV2('invalid code');

      final failure = result.getLeft().toNullable();
      expect(failure?.error, 'invalid-referral-code');
      expect(failure?.localizedErrorMessage, entry.value);
      expect(service.submittedCodes, isEmpty);
      expect(container.read(referralProvider), isNull);
    });
  }

  test('normalizes valid manual input before submission', () async {
    for (final code in [' half ', 'save15', 'summer-20', 'pygfj4']) {
      final result = await notifier.applyReferralCodeV2(code);
      expect(result.isRight(), isTrue);
      expect(container.read(referralProvider)?.code, code.trim().toUpperCase());
    }
    expect(service.submittedCodes, ['HALF', 'SAVE15', 'SUMMER-20', 'PYGFJ4']);
  });

  test('submits a code at the length limit without truncating it', () async {
    final code = 'a' * 500;

    final result = await notifier.applyReferralCodeV2(code);

    expect(result.isRight(), isTrue);
    expect(service.submittedCodes, ['A' * 500]);
    expect(container.read(referralProvider)?.code, 'A' * 500);
  });

  test('invalid input leaves the previously applied code intact', () async {
    await notifier.applyReferralCodeV2('HALF');
    final previous = container.read(referralProvider);

    final result = await notifier.applyReferralCodeV2('javascript:alert(1)');

    expect(result.isLeft(), isTrue);
    expect(container.read(referralProvider), same(previous));
    expect(service.submittedCodes, ['HALF']);
  });

  test('keeps backend validation for well-formed but unknown codes', () async {
    final failure = Failure(
      error: 'invalid-referral-code',
      localizedErrorMessage: 'Unknown code',
    );
    service.failure = failure;

    final result = await notifier.applyReferralCodeV2('UNKNOWN');

    expect(result.getLeft().toNullable(), same(failure));
    expect(service.submittedCodes, ['UNKNOWN']);
    expect(container.read(referralProvider), isNull);
  });
}
