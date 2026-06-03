import 'package:flutter/material.dart';

import '../../core/constants/app_assets.dart';
import '../../core/theme/app_colors.dart';
import '../../services/api_client.dart';
import '../../services/auth_service.dart';
import '../../services/auth_storage.dart';
import '../../widgets/app_button.dart';
import '../home/main_shell.dart';
import 'forgot_password_screen.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  static const String routeName = '/login';

  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final AuthService _authService = AuthService(ApiClient());
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    FocusScope.of(context).unfocus();
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (email.isEmpty || password.isEmpty) {
      setState(() => _errorMessage = 'Please enter email and password.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response =
          await _authService.login(email: email, password: password);
      final token = _extractToken(response);
      if (token == null) {
        if (!mounted) return;
        setState(() => _errorMessage = 'Login succeeded but missing token.');
        return;
      }
      await AuthStorage.saveToken(token);
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, MainShell.routeName);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _errorMessage = error.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _errorMessage = 'Login failed. Please try again.');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String? _extractToken(Map<String, dynamic> response) {
    return _stringOrNull(response['accessToken']) ??
        _stringOrNull(response['token']) ??
        _stringOrNull(response['jwt']) ??
        _extractTokenFromData(response['data']);
  }

  String? _extractTokenFromData(dynamic data) {
    if (data is Map<String, dynamic>) {
      return _stringOrNull(data['accessToken']) ??
          _stringOrNull(data['token']) ??
          _stringOrNull(data['jwt']) ??
          _stringOrNull(data['access_token']);
    }
    return null;
  }

  String? _stringOrNull(dynamic value) {
    if (value is String && value.trim().isNotEmpty) {
      return value;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Column(
            children: [
              const SizedBox(height: 36),
              Image.asset(AppAssets.logoMd, height: 76),
              const SizedBox(height: 28),
              const Text('Welcome back',
                  style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              const Text('Login to order meals and track your queue.',
                  style: TextStyle(color: AppColors.subText)),
              const SizedBox(height: 48),
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                    labelText: 'Email', hintText: 'customer1@unilife.local'),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                obscureText: true,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _handleLogin(),
                decoration: const InputDecoration(
                    labelText: 'Password', hintText: '********'),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.pushNamed(
                      context, ForgotPasswordScreen.routeName),
                  child: const Text('Forgot password?'),
                ),
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 8),
                Text(_errorMessage!,
                    style: const TextStyle(color: AppColors.error)),
              ],
              const SizedBox(height: 16),
              AppButton(
                label: _isLoading ? 'Logging in...' : 'Login',
                onPressed: _isLoading ? null : _handleLogin,
              ),
              const SizedBox(height: 12),
              AppButton(
                  label: 'Continue as Guest',
                  secondary: true,
                  onPressed: () => Navigator.pushReplacementNamed(
                      context, MainShell.routeName)),
              const SizedBox(height: 42),
              TextButton(
                onPressed: () =>
                    Navigator.pushNamed(context, RegisterScreen.routeName),
                child: const Text('New to UniLife? Register'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
