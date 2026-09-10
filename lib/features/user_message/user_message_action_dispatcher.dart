import 'package:lantern/core/common/common.dart' show appRouter;
import 'package:lantern/core/models/user_message.dart';
import 'package:lantern/core/router/router.gr.dart';
import 'package:url_launcher/url_launcher.dart';

typedef OpenUserMessageURL = Future<void> Function(Uri uri);
typedef OpenUserMessagePlans = Future<void> Function();

class UserMessageActionDispatcher {
  const UserMessageActionDispatcher({
    required OpenUserMessageURL openHttpsUrl,
    required OpenUserMessagePlans openPlans,
  }) : _openHttpsUrl = openHttpsUrl,
       _openPlans = openPlans;

  factory UserMessageActionDispatcher.application() {
    return UserMessageActionDispatcher(
      openHttpsUrl: (uri) async {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      },
      openPlans: () async {
        await appRouter.push(Plans());
      },
    );
  }

  final OpenUserMessageURL _openHttpsUrl;
  final OpenUserMessagePlans _openPlans;

  Future<void> dispatch(UserMessageAction action) async {
    switch (action.type) {
      case UserMessageActionType.openHttpsUrl:
        final uri = action.url;
        if (uri == null || !UserMessageAction.isAllowedHttpsUrl(uri)) return;
        await _openHttpsUrl(uri);
        return;
      case UserMessageActionType.openPlans:
        await _openPlans();
        return;
    }
  }
}
