import 'package:flutter/material.dart';
import 'package:reading_moments_app/core/log/app_route_observer.dart';
import 'package:reading_moments_app/screens/auth/login_screen.dart';

class ReadingMomentsApp extends StatelessWidget {
  const ReadingMomentsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Reading Moments',
      debugShowCheckedModeBanner: false,
      navigatorObservers: [appRouteObserver],
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const LoginScreen(),
    );
  }
}