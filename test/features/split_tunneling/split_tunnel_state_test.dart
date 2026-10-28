import 'package:flutter_test/flutter_test.dart';
import 'package:lantern/core/common/app_eum.dart';
import 'package:lantern/core/models/app_data.dart';
import 'package:lantern/core/models/split_tunnel_state.dart';
import 'package:lantern/features/split_tunneling/utils/split_tunnel_app_utils.dart';

void main() {
  test(
    'requires a valid state envelope while tolerating bad selector entries',
    () {
      for (final json in <Map<String, dynamic>>[
        {},
        {'enabled': false, 'policy': 'include'},
        {'enabled': 'false', 'policy': 'exclude', 'filters': {}},
        {'enabled': true, 'policy': 'unknown', 'filters': {}},
      ]) {
        expect(() => SplitTunnelState.fromJson(json), throwsFormatException);
      }
      final state = SplitTunnelState.fromJson({
        'enabled': true,
        'policy': 'include',
        'filters': {
          'PackageName': ['missing.app', 2, '', 'missing.app'],
          'domainSuffix': ['.example.com'],
        },
      });
      expect(state.policy, SplitTunnelPolicy.includeOnly);
      expect(state.supported, isFalse);
      expect(state.statusLabelKey, 'split_tunnel_include_only');
      expect(state.appCount, 1);
      expect(state.websiteCount, 1);
    },
  );

  test(
    'stored rows retain missing selectors and enrich discovered metadata',
    () {
      const state = SplitTunnelState(
        enabled: true,
        policy: SplitTunnelPolicy.bypass,
        supported: true,
        filters: {
          SplitTunnelFilterType.packageName: ['found.app', 'missing.app'],
          SplitTunnelFilterType.processName: ['invisible.exe'],
          SplitTunnelFilterType.processPath: [r'C:\Removed\lost.exe'],
          SplitTunnelFilterType.processPathRegex: ['/hidden/.*'],
        },
      );
      final rows = storedSplitTunnelApps(state, [
        AppData(name: 'Found', bundleId: 'found.app', appPath: '/found'),
      ]).cast<StoredSplitTunnelApp>();
      expect(rows, hasLength(5));
      expect(
        rows.singleWhere((row) => row.selector == 'found.app').name,
        'Found',
      );
      expect(
        rows.map((row) => row.selector),
        containsAll([
          'missing.app',
          'invisible.exe',
          r'C:\Removed\lost.exe',
          '/hidden/.*',
        ]),
      );
      expect(rows.map(splitTunnelAppRowId).toSet(), hasLength(5));
    },
  );

  test(
    'managed Windows aliases count once while orphan and custom regex stay visible',
    () {
      const alias =
          r'(?i)^(?P<lantern_windows_executable>)C:\\(?:Program Files|PROGRA~1)\\Sample\\sample\.exe$';
      const orphan =
          r'(?i)^(?P<lantern_windows_executable>)C:\\Gone\\gone\.exe$';
      const state = SplitTunnelState(
        enabled: true,
        policy: SplitTunnelPolicy.bypass,
        supported: true,
        filters: {
          SplitTunnelFilterType.processPath: [
            r'C:\Program Files\Sample\sample.exe',
          ],
          SplitTunnelFilterType.processPathRegex: [alias, orphan, 'custom/.*'],
        },
      );
      expect(state.appCount, 3);
      final rows = storedSplitTunnelApps(
        state,
        [],
      ).cast<StoredSplitTunnelApp>();
      expect(
        rows.map((row) => row.selector),
        containsAll([orphan, 'custom/.*']),
      );
      expect(rows.map((row) => row.selector), isNot(contains(alias)));
      expect(
        state.selectors(SplitTunnelFilterType.processPathRegex),
        hasLength(3),
      );
    },
  );
}
