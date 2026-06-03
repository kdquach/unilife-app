import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/utils/currency_formatter.dart';
import '../models/food.dart';
import 'app_button.dart';
import 'app_card.dart';
import 'food_image_placeholder.dart';
import 'status_badge.dart';

class MenuFoodCard extends StatelessWidget {
  final Food food;
  final VoidCallback? onTap;
  final VoidCallback? onAdd;

  const MenuFoodCard({super.key, required this.food, this.onTap, this.onAdd});

  @override
  Widget build(BuildContext context) {
    final isSoldOut = !food.canAddToCart;
    return AppCard(
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FoodImagePlaceholder(food: food, size: 78),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(food.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(
                  CurrencyFormatter.vnd(food.price),
                  style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    StatusBadge(label: '${food.mealType ?? 'Menu'} menu'),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        food.statusLabel,
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          color: isSoldOut ? AppColors.error : AppColors.success,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerRight,
                  child: SizedBox(
                    width: 120,
                    height: 42,
                    child: AppButton(
                      label: isSoldOut ? 'Sold out' : 'Add',
                      onPressed: food.canAddToCart ? onAdd : null,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class RegularFoodCard extends StatelessWidget {
  final Food food;
  final VoidCallback? onTap;
  final VoidCallback? onAdd;

  const RegularFoodCard({super.key, required this.food, this.onTap, this.onAdd});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 86,
            width: double.infinity,
            decoration: BoxDecoration(
              color: AppColors.muted,
              borderRadius: BorderRadius.circular(20),
            ),
            alignment: Alignment.center,
            child: Text(
              food.category.toUpperCase(),
              style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w900),
            ),
          ),
          const SizedBox(height: 12),
          Text(food.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Text(
                  CurrencyFormatter.vnd(food.price),
                  style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w900),
                ),
              ),
              Text(
                food.statusLabel,
                style: TextStyle(
                  color: food.canAddToCart ? AppColors.success : AppColors.error,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 42,
            child: AppButton(
              label: food.canAddToCart ? 'Add' : 'Out',
              secondary: true,
              onPressed: food.canAddToCart ? onAdd : null,
            ),
          ),
        ],
      ),
    );
  }
}
