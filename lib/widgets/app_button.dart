import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';

class AppButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool secondary;
  final bool danger;

  const AppButton({
    super.key,
    required this.label,
    this.onPressed,
    this.secondary = false,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    final background = danger
        ? AppColors.error
        : secondary
            ? AppColors.primarySoft
            : AppColors.primary;
    final foreground = secondary ? AppColors.primary : Colors.white;
    return SizedBox(
      height: 52,
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: background,
          foregroundColor: foreground,
          disabledBackgroundColor: AppColors.border,
          disabledForegroundColor: AppColors.subText,
        ),
        child: Text(label),
      ),
    );
  }
}
