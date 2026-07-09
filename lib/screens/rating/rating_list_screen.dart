import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import 'create_rating_screen.dart';

class RatingListScreen extends StatelessWidget {
  static const String routeName = '/ratings';

  const RatingListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Ratings')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          AppButton(label: 'Create New Rating', secondary: true, onPressed: () => Navigator.pushNamed(context, CreateRatingScreen.routeName)),
          const SizedBox(height: 20),
          const _RatingCard(foodName: 'Chicken Rice', stars: '★★★★☆'),
          SizedBox(height: 14),
          const _RatingCard(foodName: 'Beef Noodle', stars: '★★★★★'),
        ],
      ),
    );
  }
}

class _RatingCard extends StatelessWidget {
  final String foodName;
  final String stars;

  const _RatingCard({required this.foodName, required this.stars});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(foodName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          Text(stars, style: const TextStyle(color: AppColors.primary, fontSize: 20, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          const Text('Food was tasty and served quickly.', style: TextStyle(color: AppColors.subText)),
        ],
      ),
    );
  }
}
