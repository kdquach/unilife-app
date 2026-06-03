import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../data/sample_data.dart';
import '../../models/food.dart';
import '../../services/app_state.dart';
import '../../widgets/food_cards.dart';
import '../../widgets/section_title.dart';
import '../food/food_detail_screen.dart';
import 'always_available_screen.dart';
import 'today_menu_screen.dart';

class MenuScreen extends StatelessWidget {
  const MenuScreen({super.key});

  void _openDetail(BuildContext context, Food food) =>
      Navigator.pushNamed(context, FoodDetailScreen.routeName, arguments: food);

  void _add(BuildContext context, Food food) {
    AppState.instance.addToCart(food);
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('${food.name} added to cart')));
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 18, 24, 24),
        children: [
          const Text('Menu',
              style: TextStyle(fontSize: 25, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          const Text('Scheduled meals and daily items',
              style: TextStyle(color: AppColors.subText)),
          const SizedBox(height: 20),
          Row(
            children: [
              _Chip(
                  label: 'Today',
                  selected: true,
                  onTap: () =>
                      Navigator.pushNamed(context, TodayMenuScreen.routeName)),
              const SizedBox(width: 10),
              const _Chip(label: 'Weekly'),
              const SizedBox(width: 10),
              _Chip(
                  label: 'Always',
                  onTap: () => Navigator.pushNamed(
                      context, AlwaysAvailableScreen.routeName)),
            ],
          ),
          const SizedBox(height: 24),
          const SectionTitle(title: 'Scheduled Food'),
          ...SampleData.menuFoods.take(2).map(
                (food) => Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: MenuFoodCard(
                      food: food,
                      onTap: () => _openDetail(context, food),
                      onAdd: () => _add(context, food)),
                ),
              ),
          const SizedBox(height: 10),
          const SectionTitle(title: 'Always Available Food'),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: 2,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 0.72,
            ),
            itemBuilder: (_, index) {
              final food = SampleData.regularFoods[index + 1];
              return RegularFoodCard(
                  food: food,
                  onTap: () => _openDetail(context, food),
                  onAdd: () => _add(context, food));
            },
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  const _Chip({required this.label, this.selected = false, this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: selected ? AppColors.primary : AppColors.border),
        ),
        child: Text(
          label,
          style: TextStyle(
              color: selected ? Colors.white : AppColors.text,
              fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}
