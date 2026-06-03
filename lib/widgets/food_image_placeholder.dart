import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../models/food.dart';

class FoodImagePlaceholder extends StatelessWidget {
  final Food food;
  final double size;
  final double radius;

  const FoodImagePlaceholder({super.key, required this.food, this.size = 80, this.radius = 20});

  @override
  Widget build(BuildContext context) {
    final label = food.isMenuFood ? 'MEAL' : food.category.toUpperCase();
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: food.isMenuFood ? AppColors.primarySoft : AppColors.muted,
        borderRadius: BorderRadius.circular(radius),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: AppColors.primary,
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}
