import 'package:flutter/material.dart';

import '../../core/constants/app_assets.dart';
import '../../services/auth_storage.dart';
import '../admin/admin_main_shell.dart';
import '../auth/login_screen.dart';
import '../home/main_shell.dart';

class SplashScreen extends StatefulWidget {
  static const String routeName = '/';

  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkLogin();
  }

  Future<void> _checkLogin() async {
    await Future.delayed(const Duration(seconds: 2));

    final token = await AuthStorage.getToken();
    final role = await AuthStorage.getRole();

    if (!mounted) return;

    if (token == null) {
      Navigator.pushReplacementNamed(
        context,
        LoginScreen.routeName,
      );
    } else if (role == 'ADMIN') {
      Navigator.pushReplacementNamed(
        context,
        AdminMainShell.routeName,
      );
    } else {
      Navigator.pushReplacementNamed(
        context,
        MainShell.routeName,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Image.asset(
          AppAssets.logoLg,
          height: 120,
        ),
      ),
    );
  }
}