import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../services/api_client.dart';
import '../../services/auth_service.dart';
import '../../widgets/app_button.dart';
import 'login_screen.dart';

class VerifyRegisterOtpArgs {
  const VerifyRegisterOtpArgs({required this.email});

  final String email;
}

class VerifyRegisterOtpScreen extends StatefulWidget {
  static const String routeName = '/verify-register-otp';

  const VerifyRegisterOtpScreen({super.key, required this.email});

  final String email;

  @override
  State<VerifyRegisterOtpScreen> createState() =>
      _VerifyRegisterOtpScreenState();
}

class _VerifyRegisterOtpScreenState extends State<VerifyRegisterOtpScreen> {
  final TextEditingController _otpController = TextEditingController();
  final AuthService _authService = AuthService(ApiClient());

  bool _isVerifying = false;
  bool _isResending = false;
  String? _errorMessage;
  String? _successMessage;

  @override
  void dispose() {
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _handleVerifyOtp() async {
    FocusScope.of(context).unfocus();
    final otp = _otpController.text.trim();
    if (otp.isEmpty) {
      setState(() => _errorMessage = 'Please enter the OTP code.');
      return;
    }

    setState(() {
      _isVerifying = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      final response = await _authService.verifyRegisterOtp(
        email: widget.email,
        otp: otp,
      );
      await AuthService.saveAuthTokens(response);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Account verified. Please login.')),
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
      setState(() => _errorMessage = 'Verification failed. Please try again.');
    } finally {
      if (mounted) {
        setState(() => _isVerifying = false);
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
      await _authService.resendRegisterOtp(widget.email);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Verify email')),
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
                  Icons.mark_email_read_outlined,
                  color: AppColors.primary,
                  size: 54,
                ),
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'Enter the OTP sent to ${widget.email}',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.subText),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _otpController,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _handleVerifyOtp(),
              decoration: const InputDecoration(
                labelText: 'OTP code',
                hintText: '123456',
              ),
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
              label: _isVerifying ? 'Verifying...' : 'Verify Account',
              onPressed: _isVerifying ? null : _handleVerifyOtp,
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
