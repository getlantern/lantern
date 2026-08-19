import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lantern/features/user_message/user_message_route_observer.dart';

void main() {
  test('is not ready before the shell has a page route', () {
    final observer = UserMessageRouteObserver();

    expect(observer.isReadyForMessages, isFalse);
  });

  test('blocks configured, popup, and fullscreen routes', () {
    final observer = UserMessageRouteObserver(
      blockedRouteNames: const {'checkout'},
    );
    final home = MaterialPageRoute<void>(
      settings: const RouteSettings(name: 'home'),
      builder: (_) => const SizedBox.shrink(),
    );
    observer.didPush(home, null);
    expect(observer.isReadyForMessages, isTrue);

    final checkout = MaterialPageRoute<void>(
      settings: const RouteSettings(name: 'checkout'),
      builder: (_) => const SizedBox.shrink(),
    );
    observer.didPush(checkout, home);
    expect(observer.isReadyForMessages, isFalse);
    observer.didPop(checkout, home);
    expect(observer.isReadyForMessages, isTrue);

    final dialog = _TestPopupRoute();
    observer.didPush(dialog, home);
    expect(observer.isReadyForMessages, isFalse);
    observer.didPop(dialog, home);

    final fullscreen = MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => const SizedBox.shrink(),
    );
    observer.didPush(fullscreen, home);
    expect(observer.isReadyForMessages, isFalse);
  });
}

class _TestPopupRoute extends PopupRoute<void> {
  @override
  Color? get barrierColor => null;

  @override
  bool get barrierDismissible => true;

  @override
  String? get barrierLabel => null;

  @override
  Duration get transitionDuration => Duration.zero;

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) => const SizedBox.shrink();
}
