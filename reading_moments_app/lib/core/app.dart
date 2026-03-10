import 'package:flutter/material.dart';

import '../screens/auth/auth_gate.dart';

class ReadingMomentsApp extends StatelessWidget {
  const ReadingMomentsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'ReadingMoments',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.indigo,
      ),
      home: const AuthGate(),
    );
  }
}