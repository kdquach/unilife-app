import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../data/sample_data.dart';
import '../../models/food.dart';
import '../../services/app_state.dart';
import '../../widgets/food_cards.dart';
import '../../widgets/section_title.dart';
import '../food/food_detail_screen.dart';
import '../menu/always_available_screen.dart';
import '../menu/today_menu_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  void _openDetail(BuildContext context, Food food) {
    Navigator.pushNamed(context, FoodDetailScreen.routeName, arguments: food);
  }

  void _add(BuildContext context, Food food) {
    AppState.instance.addToCart(food);
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('${food.name} added to cart')));
  }

  @override
  Widget build(BuildContext context) {
    final menuFood = SampleData.menuFoods.first;
    final regularFoods = SampleData.regularFoods.take(2).toList();
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 18, 24, 24),
        children: [
          const Text('Good morning, Duy',
              style: TextStyle(fontSize: 25, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          const Text('Choose today meal or daily snacks',
              style: TextStyle(color: AppColors.subText)),
          const SizedBox(height: 22),
          const TextField(
              decoration: InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Search food, drinks, snacks...')),
          const SizedBox(height: 22),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(28)),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Today menu is ready',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w900)),
                SizedBox(height: 8),
                Text('Order main meals and add drinks or snacks.',
                    style: TextStyle(color: Colors.white)),
              ],
            ),
          ),
          const SizedBox(height: 26),
          SectionTitle(
              title: 'Today Menu',
              action: 'See all',
              onActionTap: () =>
                  Navigator.pushNamed(context, TodayMenuScreen.routeName)),
          MenuFoodCard(
              food: menuFood,
              onTap: () => _openDetail(context, menuFood),
              onAdd: () => _add(context, menuFood)),
          const SizedBox(height: 24),
          SectionTitle(
              title: 'Always Available',
              action: 'See all',
              onActionTap: () => Navigator.pushNamed(
                  context, AlwaysAvailableScreen.routeName)),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: regularFoods.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 0.72,
            ),
            itemBuilder: (_, index) {
              final food = regularFoods[index];
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
