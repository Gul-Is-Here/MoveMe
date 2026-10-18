import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

/// Tracks the navigator stack so a screen that is already open further
/// back can be returned to instead of stacking a second copy.
class RouteStack extends NavigatorObserver {
  RouteStack._();

  static final instance = RouteStack._();

  final _routes = <Route<dynamic>>[];

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) => _routes.add(route);

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) => _routes.remove(route);

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) => _routes.remove(route);

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    final index = oldRoute == null ? -1 : _routes.indexOf(oldRoute);
    if (index == -1) {
      if (newRoute != null) _routes.add(newRoute);
    } else if (newRoute != null) {
      _routes[index] = newRoute;
    } else {
      _routes.removeAt(index);
    }
  }

  bool _matches(Route<dynamic> route, String name, bool Function(Object? arguments) sameTarget) =>
      route.isActive && route.settings.name == name && sameTarget(route.settings.arguments);

  /// Opens [name], or pops back to it when an equivalent screen (by
  /// [sameTarget]) is already on the stack.
  void openOrReturn(String name, {Object? arguments, required bool Function(Object? arguments) sameTarget}) {
    if (_routes.any((r) => _matches(r, name, sameTarget))) {
      Get.until((r) => _matches(r, name, sameTarget));
    } else {
      // A different target on the same screen type (another user's
      // account) is a new screen, which GetX would otherwise drop.
      Get.toNamed(name, arguments: arguments, preventDuplicates: false);
    }
  }
}
