import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../services/api_client.dart';
import '../../services/auth_service.dart';
import '../../widgets/app_button.dart';
import 'login_screen.dart';

class ResetPasswordArgs {
  const ResetPasswordArgs({required this.email});

  final String email;
}

class ResetPasswordScreen extends StatefulWidget {
  static const String routeName = '/reset-password';

  const ResetPasswordScreen({super.key, required this.email});

  final String email;

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final TextEditingController _otpController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  final AuthService _authService = AuthService(ApiClient());

  bool _isResetting = false;
  bool _isResending = false;
  String? _errorMessage;
  String? _successMessage;

  @override
  void dispose() {
    _otpController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleResetPassword() async {
    FocusScope.of(context).unfocus();
    final otp = _otpController.text.trim();
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;
    final validationMessage = _validateInput(
      otp: otp,
      password: password,
      confirmPassword: confirmPassword,
    );

    if (validationMessage != null) {
      setState(() => _errorMessage = validationMessage);
      return;
    }

    setState(() {
      _isResetting = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      await _authService.resetPassword(
        email: widget.email,
        otp: otp,
        newPassword: password,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password reset successfully.')),
      );
      Navigator.pushNamedAndRemoveUntil(
        context,
        LoginScreen.routeName,
        (route) => false,
      );
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _errorMessage = error.message);
    } catch (_) {
      if (!mounted) return;
      setState(
          () => _errorMessage = 'Reset password failed. Please try again.');
    } finally {
      if (mounted) {
        setState(() => _isResetting = false);
      }
    }
  }

  Future<void> _handleResendOtp() async {
    setState(() {
      _isResending = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      await _authService.resendForgotPasswordOtp(widget.email);
      if (!mounted) return;
      setState(() {
        _successMessage = 'A new OTP has been sent to your email.';
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _errorMessage = error.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _errorMessage = 'Could not resend OTP. Please try again.');
    } finally {
      if (mounted) {
        setState(() => _isResending = false);
      }
    }
  }

  String? _validateInput({
    required String otp,
    required String password,
    required String confirmPassword,
  }) {
    if (otp.isEmpty || password.isEmpty || confirmPassword.isEmpty) {
      return 'Please fill in all fields.';
    }
    if (password.length < 6) {
      return 'Password must be at least 6 characters.';
    }
    if (password != confirmPassword) {
      return 'Confirm password does not match.';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reset password')),
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
                  Icons.lock_reset_rounded,
                  color: AppColors.primary,
                  size: 54,
                ),
              ),
            ),
            const SizedBox(height: 28),
            Text(
              'Enter the OTP sent to ${widget.email}',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.subText),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _otpController,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'OTP code',
                hintText: '123456',
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _passwordController,
              obscureText: true,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(labelText: 'New password'),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _confirmPasswordController,
              obscureText: true,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _handleResetPassword(),
              decoration: const InputDecoration(labelText: 'Confirm password'),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                style: const TextStyle(color: AppColors.error),
              ),
            ],
            if (_successMessage != null) ...[
              const SizedBox(height: 16),
              Text(
                _successMessage!,
                style: const TextStyle(color: AppColors.success),
              ),
            ],
            const SizedBox(height: 30),
            AppButton(
              label: _isResetting ? 'Resetting...' : 'Reset Password',
              onPressed: _isResetting ? null : _handleResetPassword,
            ),
            const SizedBox(height: 12),
            AppButton(
              label: _isResending ? 'Sending OTP...' : 'Resend OTP',
              secondary: true,
              onPressed: _isResending ? null : _handleResendOtp,
            ),
          ],
        ),
      ),
    );
  }
}
