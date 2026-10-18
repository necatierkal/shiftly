import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/services/local_storage_service.dart';
import '../../widgets/shiftly_logo.dart';
import '../onboarding/onboarding_screen.dart';
import '../auth/auth_screen.dart';
import '../navigation/main_nav_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkNextScreen();
  }

  Future<void> _checkNextScreen() async {
    await Future.delayed(const Duration(milliseconds: 1200));
    if (!mounted) return;

    final storage = context.read<LocalStorageService>();
    final isOnboardingDone = storage.isOnboardingDone();
    final hasToken = storage.getAccessToken() != null;

    Widget nextScreen;
    if (!isOnboardingDone) {
      nextScreen = const OnboardingScreen();
    } else if (hasToken) {
      nextScreen = const MainNavScreen();
    } else {
      nextScreen = const AuthScreen();
    }

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => nextScreen,
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: ShiftlyLogo(
          size: 110,
          showText: true,
        ),
      ),
    );
  }
}
