import 'package:flutter_test/flutter_test.dart';
import 'package:lantern/core/models/radiance_settings_state.dart';
import 'package:lantern/features/home/provider/radiance_settings_providers.dart';

void main() {
  test('proxyless is on until the user turns it off', () {
    expect(const RadianceSettingsState().proxyless, isTrue);
    expect(proxylessFromSettings({}), isTrue);
    expect(proxylessFromSettings({proxylessSettingKey: 'yes'}), isTrue);
    expect(proxylessFromSettings({proxylessSettingKey: false}), isFalse);
    expect(proxylessFromSettings({proxylessSettingKey: true}), isTrue);
  });

  test('proxyless takes part in state equality', () {
    const on = RadianceSettingsState();
    expect(on.copyWith(proxyless: false) == on, isFalse);
    expect(on.copyWith(proxyless: false).hashCode == on.hashCode, isFalse);
  });
}
