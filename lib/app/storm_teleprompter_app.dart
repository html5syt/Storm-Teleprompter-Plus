import 'package:flutter/material.dart';

import '../features/home/home_page.dart';

class StormTeleprompterApp extends StatelessWidget {
  const StormTeleprompterApp({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFFF7C948),
      brightness: Brightness.dark,
      surface: const Color(0xFF141414),
    );

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Storm Teleprompter Plus',
      themeMode: ThemeMode.dark,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: colorScheme,
        scaffoldBackgroundColor: const Color(0xFF0C0D10),
      ),
      home: const HomePage(),
    );
  }
}
