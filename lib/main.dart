import 'package:flutter/material.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(const OrthoScanApp());
}

class OrthoScanApp extends StatelessWidget {
  const OrthoScanApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OrthoScan',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0F3460),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFF1A1A2E),
      ),
      home: const HomeScreen(),
    );
  }
}