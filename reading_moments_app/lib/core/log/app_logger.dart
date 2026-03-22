import 'package:flutter/foundation.dart';

class AppLogger {
  static void screen(String screenName, {String? message}) {
    debugPrint('📱 SCREEN | $screenName${message != null ? ' | $message' : ''}');
  }

  static void navPush(String routeName) {
    debugPrint('➡️ NAV PUSH | $routeName');
  }

  static void navPop(String routeName) {
    debugPrint('⬅️ NAV POP  | $routeName');
  }

  static void action(String actionName, {String? detail}) {
    debugPrint('🟦 ACTION | $actionName${detail != null ? ' | $detail' : ''}');
  }

  static void apiStart(String name, {String? detail}) {
    debugPrint('🌐 API START | $name${detail != null ? ' | $detail' : ''}');
  }

  static void apiSuccess(String name, {String? detail}) {
    debugPrint('✅ API OK    | $name${detail != null ? ' | $detail' : ''}');
  }

  static void apiError(String name, Object error, {StackTrace? stackTrace}) {
    debugPrint('❌ API FAIL  | $name | $error');
    if (stackTrace != null) {
      debugPrint(stackTrace.toString());
    }
  }

  static void info(String message) {
    debugPrint('ℹ️ INFO | $message');
  }

  static void warn(String message) {
    debugPrint('⚠️ WARN | $message');
  }

  static void error(String message, {Object? error, StackTrace? stackTrace}) {
    debugPrint('🛑 ERROR | $message${error != null ? ' | $error' : ''}');
    if (stackTrace != null) {
      debugPrint(stackTrace.toString());
    }
  }
}