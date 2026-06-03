import 'package:flutter/material.dart';

import '../../widgets/app_button.dart';

class RegisterScreen extends StatelessWidget {
  static const String routeName = '/register';

  const RegisterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create account')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const TextField(decoration: InputDecoration(labelText: 'Full name', hintText: 'Nguyen Khanh Duy')),
            const SizedBox(height: 14),
            const TextField(decoration: InputDecoration(labelText: 'Email', hintText: 'student@unilife.edu')),
            const SizedBox(height: 14),
            const TextField(decoration: InputDecoration(labelText: 'Phone', hintText: '0901234567')),
            const SizedBox(height: 14),
            const TextField(obscureText: true, decoration: InputDecoration(labelText: 'Password')),
            const SizedBox(height: 14),
            const TextField(obscureText: true, decoration: InputDecoration(labelText: 'Confirm password')),
            const SizedBox(height: 36),
            AppButton(label: 'Create Account', onPressed: () => Navigator.pop(context)),
          ],
        ),
      ),
    );
  }
}
