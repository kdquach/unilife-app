import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../widgets/app_button.dart';

class EditProfileScreen extends StatelessWidget {
  static const String routeName = '/edit-profile';

  const EditProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit profile')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Text('Update your account information', style: TextStyle(color: AppColors.subText)),
          const SizedBox(height: 24),
          const TextField(decoration: InputDecoration(labelText: 'Full name', hintText: 'Nguyen Khanh Duy')),
          const SizedBox(height: 14),
          const TextField(decoration: InputDecoration(labelText: 'Phone', hintText: '0901234567')),
          const SizedBox(height: 14),
          const TextField(decoration: InputDecoration(labelText: 'Email', hintText: 'customer1@unilife.local')),
          const SizedBox(height: 28),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(20)),
            child: const Text('Email is used for login and OTP verification.', style: TextStyle(color: AppColors.primaryDark, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(height: 40),
          AppButton(label: 'Save Changes', onPressed: () => Navigator.pop(context)),
        ],
      ),
    );
  }
}
