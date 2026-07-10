import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/home_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/tutorial_screen.dart';
import 'services/database_service.dart';
import 'services/clinician_service.dart';
import 'services/theme_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await DatabaseService().database;
  await ClinicianService().load();
  await ThemeService().load();
  runApp(const OrthoScanApp());
}

class OrthoScanApp extends StatefulWidget {
  const OrthoScanApp({super.key});
  @override
  State<OrthoScanApp> createState() => _OrthoScanAppState();
}

class _OrthoScanAppState extends State<OrthoScanApp> {
  final _themeService = ThemeService();

  @override
  void initState() {
    super.initState();
    _themeService.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _themeService.removeListener(() => setState(() {}));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CL@B',
      debugShowCheckedModeBanner: false,
      theme: _themeService.lightTheme,
      darkTheme: _themeService.darkTheme,
      themeMode: _themeService.isDark ? ThemeMode.dark : ThemeMode.light,
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


