import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lantern/core/common/app_theme.dart';
import 'package:lantern/core/models/user.dart';
import 'package:lantern/core/services/injection_container.dart';
import 'package:lantern/core/services/local_storage_service.dart';
import 'package:lantern/features/setting/referral_reward_dialog.dart';

class _RecordingStorage implements LocalStorageService {
  List<String> seen = const <String>[];
  int saves = 0;

  @override
  List<String> getSeenConvertedReferrals() => seen;

  @override
  Future<void> saveSeenConvertedReferrals(List<String> userIds) async {
    saves++;
    seen = userIds;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late _RecordingStorage storage;

  setUp(() {
    storage = _RecordingStorage();
    sl.registerSingleton<LocalStorageService>(storage);
  });

  tearDown(() => sl.reset());

  final user = UserResponseModel.fromJson({
    'legacyID': 1,
    'legacyToken': 'token',
    'emailConfirmed': true,
    'success': true,
    'legacyUserData': {
      'referral': 'abc123',
      'referrals': [
        {'userId': 'friend', 'converted': true, 'bonusDaysEarned': 30},
      ],
    },
  });

  testWidgets('marks referrals seen only once the dialog is dismissed', (
    tester,
  ) async {
    final navigatorKey = GlobalKey<NavigatorState>();
    late BuildContext context;

    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(390, 844),
        child: MaterialApp(
          navigatorKey: navigatorKey,
          theme: AppTheme.appTheme(),
          home: Builder(
            builder: (ctx) {
              context = ctx;
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final pending = checkAndShowReferralReward(context, user);
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.redeem), findsOneWidget);
    expect(
      storage.saves,
      0,
      reason:
          'persisting before dismissal loses the notification if the '
          'dialog never reaches the user',
    );

    navigatorKey.currentState!.pop();
    await tester.pumpAndSettle();
    await pending;

    expect(storage.saves, 1);
    expect(storage.seen, <String>['friend']);
  });
}
