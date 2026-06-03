import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../data/sample_data.dart';
import '../../models/food.dart';
import '../../services/app_state.dart';
import '../../widgets/app_card.dart';
import '../../widgets/food_cards.dart';
import '../food/food_detail_screen.dart';

class TodayMenuScreen extends StatelessWidget {
  static const String routeName = '/today-menu';

  const TodayMenuScreen({super.key});

  void _open(BuildContext context, Food food) => Navigator.pushNamed(context, FoodDetailScreen.routeName, arguments: food);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Today Menu')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Text('Food sold by menu schedule', style: TextStyle(color: AppColors.subText)),
          const SizedBox(height: 16),
          const Row(
            children: [
              _MealChip('Breakfast'),
              SizedBox(width: 10),
              _MealChip('Lunch', selected: true),
              SizedBox(width: 10),
              _MealChip('Dinner'),
            ],
          ),
          const SizedBox(height: 20),
          const AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Menu Food', style: TextStyle(color: AppColors.primary, fontSize: 16, fontWeight: FontWeight.w900)),
                SizedBox(height: 8),
                Text('Uses menuScheduleItemId, has remaining servings, can be sold out by meal session.', style: TextStyle(color: AppColors.subText)),
              ],
            ),
          ),
          const SizedBox(height: 20),
          ...SampleData.menuFoods.map(
            (food) => Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: MenuFoodCard(
                food: food,
                onTap: () => _open(context, food),
                onAdd: food.canAddToCart ? () => AppState.instance.addToCart(food) : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MealChip extends StatelessWidget {
  final String label;
  final bool selected;
  const _MealChip(this.label, {this.selected = false});

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(label),
      backgroundColor: selected ? AppColors.primary : Colors.white,
      labelStyle: TextStyle(color: selected ? Colors.white : AppColors.text, fontWeight: FontWeight.w800),
      side: BorderSide(color: selected ? AppColors.primary : AppColors.border),
    );
  }
}
