import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../widgets/app_button.dart';
import 'reset_password_screen.dart';

class ForgotPasswordScreen extends StatelessWidget {
  static const String routeName = '/forgot-password';

  const ForgotPasswordScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Forgot password')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Container(
              width: 132,
              height: 132,
              decoration: const BoxDecoration(color: AppColors.primarySoft, shape: BoxShape.circle),
              child: const Icon(Icons.mail_outline_rounded, color: AppColors.primary, size: 54),
            ),
            const SizedBox(height: 32),
            const TextField(decoration: InputDecoration(labelText: 'Email', hintText: 'student@unilife.edu')),
            const SizedBox(height: 24),
            AppButton(label: 'Send OTP', onPressed: () => Navigator.pushNamed(context, ResetPasswordScreen.routeName)),
            const SizedBox(height: 16),
            const Text('We will send a 6-digit OTP to your email.', style: TextStyle(color: AppColors.subText)),
          ],
        ),
      ),
    );
  }
}
