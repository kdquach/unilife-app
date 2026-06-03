import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../widgets/app_button.dart';

class ChangePasswordScreen extends StatelessWidget {
  static const String routeName = '/change-password';

  const ChangePasswordScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Change password')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Text('Keep your account secure', style: TextStyle(color: AppColors.subText)),
          const SizedBox(height: 24),
          const TextField(obscureText: true, decoration: InputDecoration(labelText: 'Current password')),
          const SizedBox(height: 14),
          const TextField(obscureText: true, decoration: InputDecoration(labelText: 'New password')),
          const SizedBox(height: 14),
          const TextField(obscureText: true, decoration: InputDecoration(labelText: 'Confirm new password')),
          const SizedBox(height: 26),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(20)),
            child: const Text('Password must contain at least 8 characters, including uppercase, lowercase and number.', style: TextStyle(color: AppColors.primaryDark, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(height: 40),
          AppButton(label: 'Change Password', onPressed: () => Navigator.pop(context)),
        ],
      ),
    );
  }
}
