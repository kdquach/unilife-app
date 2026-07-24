import 'package:flutter/material.dart';

import '../../core/constants/app_assets.dart';
import '../../widgets/app_button.dart';
import '../auth/login_screen.dart';

class SplashScreen extends StatelessWidget {
  static const String routeName = '/';
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFFFF),
      body: SafeArea(
        child: Stack(
          children: [
            // ── Decorative arcs ──────────────────────────────────────────────
            _Arc(size: 340, strokeW: 60, top: -120, right: -120, opacity: .07),
            _Arc(size: 220, strokeW: 40, bottom: 60, left: -80, opacity: .05),
            // ── Decorative lines ─────────────────────────────────────────────
            _Stroke(height: 180, top: 80, left: 44, angle: 20, opacity: .15),
            _Stroke(height: 120, top: 120, right: 36, angle: -15, opacity: .10),
            // ── Main content ─────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                children: [
                  const Spacer(),
                  // Logo asset
                  Image.asset(
                    AppAssets.logoLg,
                    height: 110,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Campus meals, faster queue, smarter canteen.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0x99000000),
                      fontSize: 13,
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Orange divider accent
                  Container(
                    width: 40,
                    height: 2,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF6B00),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Feature rows
                  _FeatureList(),
                  const Spacer(),
                  // ── CTA button (using project AppButton) ───────────────────
                  AppButton(
                    label: 'Get Started',
                    secondary: true,
                    onPressed: () => Navigator.pushReplacementNamed(
                      context,
                      LoginScreen.routeName,
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Terms hint
                  RichText(
                    textAlign: TextAlign.center,
                    text: const TextSpan(
                      style: TextStyle(
                        fontSize: 11,
                        color: Color(0x66000000),
                      ),
                      children: [
                        TextSpan(text: 'Continuing means you agree '),
                        TextSpan(
                          text: 'Terms & Privacy Policy',
                          style: TextStyle(color: Color(0xB3FF6B00)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Feature list ──────────────────────────────────────────────────────────────
class _FeatureList extends StatelessWidget {
  static const _features = [
    (Icons.receipt_long_outlined, 'Order in advance.', 'New'),
    (Icons.access_time_outlined, 'Skip the queue', null),
    (Icons.location_on_outlined, 'Track actual orders', null),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: _features
          .map(
            (f) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _FeatureRow(icon: f.$1, label: f.$2, badge: f.$3),
            ),
          )
          .toList(),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? badge;
  const _FeatureRow({required this.icon, required this.label, this.badge});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0x08000000),
        border: Border.all(color: const Color(0x1A000000), width: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: const Color(0x26FF6B00),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, color: const Color(0xFFFF6B00), size: 16),
          ),
          const SizedBox(width: 10),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF1A1A1A),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (badge != null) ...[
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0x1EFF6B00),
                border: Border.all(
                  color: const Color(0x4DFF6B00),
                  width: 0.5,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                badge!,
                style: const TextStyle(
                  color: Color(0xFFFF6B00),
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Decorative helpers ────────────────────────────────────────────────────────
class _Arc extends StatelessWidget {
  final double size, strokeW, opacity;
  final double? top, right, bottom, left;
  const _Arc({
    required this.size,
    required this.strokeW,
    required this.opacity,
    this.top,
    this.right,
    this.bottom,
    this.left,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: top,
      right: right,
      bottom: bottom,
      left: left,
      child: Opacity(
        opacity: opacity,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: const Color(0xFFFF6B00),
              width: strokeW,
            ),
          ),
        ),
      ),
    );
  }
}

class _Stroke extends StatelessWidget {
  final double height, top, opacity, angle;
  final double? left, right;
  const _Stroke({
    required this.height,
    required this.top,
    required this.opacity,
    required this.angle,
    this.left,
    this.right,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: top,
      left: left,
      right: right,
      child: Transform.rotate(
        angle: angle * 3.1415926 / 180,
        child: Opacity(
          opacity: opacity,
          child: Container(
            width: 2,
            height: height,
            color: const Color(0xFFFF6B00),
          ),
        ),
      ),
    );
  }
}
