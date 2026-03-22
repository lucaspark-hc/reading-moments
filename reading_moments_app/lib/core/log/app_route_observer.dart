import 'package:flutter/material.dart';
import 'app_logger.dart';

final RouteObserver<ModalRoute<dynamic>> appRouteObserver =
    RouteObserver<ModalRoute<dynamic>>();

class AppRouteAware extends RouteAware {
  final String screenName;

  AppRouteAware(this.screenName);

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