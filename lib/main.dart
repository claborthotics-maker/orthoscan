import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
import 'screens/onboarding_screen.dart';
import 'services/database_service.dart';
import 'services/clinician_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize database
  await DatabaseService().database;

  // Load clinicians
  await ClinicianService().load();

  runApp(const OrthoScanApp());
}

class OrthoScanApp extends StatelessWidget {
  const OrthoScanApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CL@B',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0F3460),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFF1A1A2E),
      ),
      home: ClinicianService().isEmpty
          ? const OnboardingScreen()
          : const HomeScreen(),
    );
  }
}
