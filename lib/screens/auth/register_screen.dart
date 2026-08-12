import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../services/api_client.dart';
import '../../services/auth_service.dart';
import '../../widgets/app_button.dart';
import 'verify_register_otp_screen.dart';

class RegisterScreen extends StatefulWidget {
  static const String routeName = '/register';

  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  final AuthService _authService = AuthService(ApiClient());

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  String? _errorMessage;
  Map<String, String?> _fieldErrors = {
    'fullName': null,
    'email': null,
    'phone': null,
    'password': null,
  };

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    FocusScope.of(context).unfocus();
    final fullName = _fullNameController.text.trim();
    final email = _emailController.text.trim();
    final phone = _phoneController.text.trim();
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;


setState(() {
    _errorMessage = null;
    _fieldErrors = {
      'fullName': null,
      'email': null,
      'phone': null,
      'password': null,
    };
  });


    final validationMessage = _validateInput(
      fullName: fullName,
      email: email,
      phone: phone,
      password: password,
      confirmPassword: confirmPassword,
    );
    if (validationMessage != null) {
      setState(() => _errorMessage = validationMessage);
      return;
    }

    setState(() {
    _isLoading = true;
  });

    try {
      await _authService.register(
        fullName: fullName,
        email: email,
        phone: phone,
        password: password,
      );
      if (!mounted) return;
      Navigator.pushNamed(
        context,
        VerifyRegisterOtpScreen.routeName,
        arguments: VerifyRegisterOtpArgs(email: email),
      );
    } on ApiException catch (error) {
      if (!mounted) return;
      // Parse field errors from backend response
      if (error.errors != null && error.errors is Map<String, dynamic>) {
        setState(() {
          _fieldErrors = {
            'fullName': _formatError(error.errors!['fullName']),
            'email': _formatError(error.errors!['email']),
            'phone': _formatError(error.errors!['phone']),
            'password': _formatError(error.errors!['password']),
          };
        });
      } else {
        setState(() => _errorMessage = error.message);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _errorMessage = 'Register failed. Please try again.');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String? _validateInput({
    required String fullName,
    required String email,
    required String phone,
    required String password,
    required String confirmPassword,
  }) {
    if (fullName.isEmpty ||
        email.isEmpty ||
        phone.isEmpty ||
        password.isEmpty ||
        confirmPassword.isEmpty) {
      return 'Please fill in all fields.';
    }
    // if (!email.contains('@') || !email.contains('.')) {
    //   return 'Please enter a valid email address.';
    // }
    if (password.length < 8) {
      return 'Password must be at least 8 characters.';
    }
    if (password != confirmPassword) {
      return 'Confirm password does not match.';
    }
    return null;
  }

  String? _formatError(dynamic error) {
    if (error == null) return null;
    return error.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create account')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 112,
                height: 112,
                decoration: const BoxDecoration(
                  color: AppColors.primarySoft,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.person_add_alt_1_rounded,
                  color: AppColors.primary,
                  size: 48,
                ),
              ),
            ),
            const SizedBox(height: 28),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _fullNameController,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: 'Full name',
                    hintText: 'Nguyen Khanh Duy',
                    prefixIcon: const Icon(Icons.person_outline_rounded),
                  ),
                ),
                if (_fieldErrors['fullName'] != null)
                  Padding(
                    padding: const EdgeInsets.only(left: 12, top: 4),
                    child: Text(
                      _fieldErrors['fullName']!,
                      style: const TextStyle(
                        color: AppColors.error,
                        fontSize: 12,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.visible,
                    ),
                  ),
                SizedBox(height: _fieldErrors['fullName'] != null ? 20 : 14),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: 'Email',
                    hintText: 'student@unilife.edu',
                    prefixIcon: const Icon(Icons.email_outlined),
                  ),
                ),
                if (_fieldErrors['email'] != null)
                  Padding(
                    padding: const EdgeInsets.only(left: 12, top: 4),
                    child: Text(
                      _fieldErrors['email']!,
                      style: const TextStyle(
                        color: AppColors.error,
                        fontSize: 12,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.visible,
                    ),
                  ),
                SizedBox(height: _fieldErrors['email'] != null ? 20 : 14),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: 'Phone',
                    hintText: '0901234567',
                    prefixIcon: const Icon(Icons.phone_outlined),
                  ),
                ),
                if (_fieldErrors['phone'] != null)
                  Padding(
                    padding: const EdgeInsets.only(left: 12, top: 4),
                    child: Text(
                      _fieldErrors['phone']!,
                      style: const TextStyle(
                        color: AppColors.error,
                        fontSize: 12,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.visible,
                    ),
                  ),
                SizedBox(height: _fieldErrors['phone'] != null ? 20 : 14),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: const Icon(Icons.lock_outline_rounded),
                    suffixIcon: IconButton(
                      onPressed: () => setState(
                        () => _obscurePassword = !_obscurePassword,
                      ),
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                      ),
                    ),
                  ),
                ),
                if (_fieldErrors['password'] != null)
                  Padding(
                    padding: const EdgeInsets.only(left: 12, top: 4),
                    child: Text(
                      _fieldErrors['password']!,
                      style: const TextStyle(
                        color: AppColors.error,
                        fontSize: 12,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.visible,
                    ),
                  ),
                SizedBox(height: _fieldErrors['password'] != null ? 20 : 14),
              ],
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _confirmPasswordController,
              obscureText: _obscureConfirmPassword,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _handleRegister(),
              decoration: InputDecoration(
                labelText: 'Confirm password',
                prefixIcon: const Icon(Icons.lock_reset_rounded),
                suffixIcon: IconButton(
                  onPressed: () => setState(
                    () => _obscureConfirmPassword = !_obscureConfirmPassword,
                  ),
                  icon: Icon(
                    _obscureConfirmPassword
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                  ),
                ),
              ),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                style: const TextStyle(color: AppColors.error),
              ),
            ],
            const SizedBox(height: 30),
            AppButton(
              label: _isLoading ? 'Creating account...' : 'Create Account',
              onPressed: _isLoading ? null : _handleRegister,
            ),
            const SizedBox(height: 16),
            const Text(
              'We will send a 6-digit OTP to verify your email.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.subText),
            ),
          ],
        ),
      ),
    );
  }
}
