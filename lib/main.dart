import 'package:flutter/material.dart';
import 'pages/home_page.dart';

void main() {
  runApp(const PalmGuardApp());
}

class PalmGuardApp extends StatelessWidget {
  const PalmGuardApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PalmGuard AI',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: const Color(0xFF10B981),
        scaffoldBackgroundColor: const Color(0xFF0C1910),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF10B981),
          secondary: Color(0xFF34D399),
          surface: Color(0xFF152A1C),
        ),
        fontFamily: 'Roboto',
      ),
      home: const HomePage(),
    );
  }
}
