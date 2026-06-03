import 'package:flutter/material.dart';

import '../../core/constants/app_assets.dart';
import '../../core/theme/app_colors.dart';
import '../../widgets/app_button.dart';
import '../auth/login_screen.dart';

class SplashScreen extends StatelessWidget {
  static const String routeName = '/';

  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            children: [
              const Spacer(),
              Image.asset(AppAssets.logoLg, height: 150, fit: BoxFit.contain),
              const SizedBox(height: 32),
              const Text(
                'UniLife',
                style: TextStyle(color: Colors.white, fontSize: 44, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 12),
              const Text(
                'Campus meals, faster queue, smarter canteen.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              AppButton(
                label: 'Get Started',
                secondary: true,
                onPressed: () => Navigator.pushReplacementNamed(context, LoginScreen.routeName),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
