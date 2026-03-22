import 'package:flutter/material.dart';

import 'app_logger.dart';
import 'app_route_observer.dart';

mixin LoggedStateMixin<T extends StatefulWidget> on State<T>
    implements RouteAware {
  String get screenName;

  ModalRoute<dynamic>? _route;

  @override
  void initState() {
    super.initState();
    AppLogger.screen(screenName, message: 'initState');
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final route = ModalRoute.of(context);
    if (route != null && route != _route) {
      if (_route != null) {
        appRouteObserver.unsubscribe(this);
      }
      _route = route;
      appRouteObserver.subscribe(this, route);
    }
  }

  @override
  void dispose() {
    appRouteObserver.unsubscribe(this);
    AppLogger.screen(screenName, message: 'dispose');
    super.dispose();
  }

  @override
  void didPush() {
    AppLogger.navPush(screenName);
  }

  @override
  void didPop() {
    AppLogger.navPop(screenName);
  }

  @override
  void didPopNext() {
    AppLogger.info('RETURN TO | $screenName');
  }

  @override
  void didPushNext() {
    AppLogger.info('LEAVE FROM | $screenName');
  }
}