import 'package:flutter/material.dart';

import '../../widgets/app_button.dart';

class ResetPasswordScreen extends StatelessWidget {
  static const String routeName = '/reset-password';

  const ResetPasswordScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reset password')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const TextField(decoration: InputDecoration(labelText: 'OTP code', hintText: '123456')),
            const SizedBox(height: 14),
            const TextField(obscureText: true, decoration: InputDecoration(labelText: 'New password')),
            const SizedBox(height: 14),
            const TextField(obscureText: true, decoration: InputDecoration(labelText: 'Confirm password')),
            const SizedBox(height: 30),
            AppButton(label: 'Reset Password', onPressed: () => Navigator.popUntil(context, (route) => route.isFirst)),
          ],
        ),
      ),
    );
  }
}
