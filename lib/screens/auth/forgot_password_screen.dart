import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../services/api_client.dart';
import '../../services/auth_service.dart';
import '../../widgets/app_button.dart';
import 'reset_password_screen.dart';

class ForgotPasswordScreen extends StatefulWidget {
  static const String routeName = '/forgot-password';

  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final TextEditingController _emailController = TextEditingController();
  final AuthService _authService = AuthService(ApiClient());

  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _handleSendOtp() async {
    FocusScope.of(context).unfocus();
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      setState(() => _errorMessage = 'Please enter your email.');
      return;
    }
    if (!email.contains('@') || !email.contains('.')) {
      setState(() => _errorMessage = 'Please enter a valid email address.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await _authService.forgotPassword(email);
      if (!mounted) return;
      Navigator.pushNamed(
        context,
        ResetPasswordScreen.routeName,
        arguments: ResetPasswordArgs(email: email),
      );
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _errorMessage = error.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _errorMessage = 'Could not send OTP. Please try again.');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Forgot password')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 132,
                height: 132,
                decoration: const BoxDecoration(
                  color: AppColors.primarySoft,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.mail_outline_rounded,
                  color: AppColors.primary,
                  size: 54,
                ),
              ),
            ),
            const SizedBox(height: 32),
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _handleSendOtp(),
              decoration: const InputDecoration(
                labelText: 'Email',
                hintText: 'student@unilife.edu',
              ),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                style: const TextStyle(color: AppColors.error),
              ),
            ],
            const SizedBox(height: 24),
            AppButton(
              label: _isLoading ? 'Sending OTP...' : 'Send OTP',
              onPressed: _isLoading ? null : _handleSendOtp,
            ),
            const SizedBox(height: 16),
            const Text(
              'We will send a 6-digit OTP to your email.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.subText),
            ),
          ],
        ),
      ),
    );
  }
}
