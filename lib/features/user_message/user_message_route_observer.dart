import 'package:flutter/material.dart';

/// Tracks routes where a global message would get in the user's way: startup,
/// dialogs, full-screen modals, and blocked flows such as checkout.
class UserMessageRouteObserver extends NavigatorObserver {
  UserMessageRouteObserver({Set<String> blockedRouteNames = const {}})
    : _blockedRouteNames = Set.unmodifiable(blockedRouteNames);

  final Set<String> _blockedRouteNames;
  final List<Route<dynamic>> _routes = [];
  final ValueNotifier<int> _changes = ValueNotifier(0);

  Listenable get changes => _changes;

  bool get isReadyForMessages {
    if (_routes.isEmpty) return false;
    final top = _routes.last;
    if (top is! PageRoute<dynamic>) return false;
    if (top.fullscreenDialog) return false;
    return !_blockedRouteNames.contains(top.settings.name);
  }

  void _notify() {
    _changes.value++;
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (!_routes.contains(route)) _routes.add(route);
    _notify();
    super.didPush(route, previousRoute);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _routes.remove(route);
    _notify();
    super.didPop(route, previousRoute);
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _routes.remove(route);
    _notify();
    super.didRemove(route, previousRoute);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    final index = oldRoute == null ? -1 : _routes.indexOf(oldRoute);
    if (index >= 0) {
      if (newRoute == null) {
        _routes.removeAt(index);
      } else {
        _routes[index] = newRoute;
      }
    } else if (newRoute != null && !_routes.contains(newRoute)) {
      _routes.add(newRoute);
    }
    _notify();
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
  }
}
