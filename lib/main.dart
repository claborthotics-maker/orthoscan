import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/home_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/tutorial_screen.dart';
import 'services/database_service.dart';
import 'services/clinician_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await DatabaseService().database;
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
      home: const _StartupRouter(),
    );
  }
}

class _StartupRouter extends StatefulWidget {
  const _StartupRouter();
  @override
  State<_StartupRouter> createState() => _StartupRouterState();
}

class _StartupRouterState extends State<_StartupRouter> {
  Widget? _home;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  Future<void> _resolve() async {
    if (ClinicianService().isEmpty) {
      setState(() => _home = const OnboardingScreen());
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    final tutorialDone = prefs.getBool('tutorial_done') ?? false;
    setState(() => _home = tutorialDone
        ? const HomeScreen()
        : const TutorialScreen());
  }

  @override
  Widget build(BuildContext context) {
    return _home ?? const Scaffold(
      backgroundColor: Color(0xFF1A1A2E),
      body: Center(child: CircularProgressIndicator(color: Color(0xFF4FC3F7))),
    );
  }
}
