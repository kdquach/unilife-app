import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../data/sample_data.dart';
import '../../models/food.dart';
import '../../services/app_state.dart';
import '../../widgets/app_card.dart';
import '../../widgets/food_cards.dart';
import '../food/food_detail_screen.dart';

class AlwaysAvailableScreen extends StatelessWidget {
  static const String routeName = '/always-available';

  const AlwaysAvailableScreen({super.key});

  void _open(BuildContext context, Food food) =>
      Navigator.pushNamed(context, FoodDetailScreen.routeName, arguments: food);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Always Available')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Text('Drinks, cakes, ice cream, snacks',
              style: TextStyle(color: AppColors.subText)),
          const SizedBox(height: 16),
          const Row(
            children: [
              _CategoryChip('All', selected: true),
              SizedBox(width: 10),
              _CategoryChip('Drinks'),
              SizedBox(width: 10),
              _CategoryChip('Snacks'),
            ],
          ),
          const SizedBox(height: 20),
          const AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Regular Food',
                    style: TextStyle(
                        color: AppColors.primary,
                        fontSize: 16,
                        fontWeight: FontWeight.w900)),
                SizedBox(height: 8),
                Text(
                    'Uses foodId, available every day, controlled by stock or in-stock status.',
                    style: TextStyle(color: AppColors.subText)),
              ],
            ),
          ),
          const SizedBox(height: 20),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: SampleData.regularFoods.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 0.72,
            ),
            itemBuilder: (_, index) {
              final food = SampleData.regularFoods[index];
              return RegularFoodCard(
                food: food,
                onTap: () => _open(context, food),
                onAdd: food.canAddToCart
                    ? () => AppState.instance.addToCart(food)
                    : null,
              );
            },
          ),
        ],
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final String label;
  final bool selected;
  const _CategoryChip(this.label, {this.selected = false});

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(label),
      backgroundColor: selected ? AppColors.primary : Colors.white,
      labelStyle: TextStyle(
          color: selected ? Colors.white : AppColors.text,
          fontWeight: FontWeight.w800),
      side: BorderSide(color: selected ? AppColors.primary : AppColors.border),
    );
  }
}
