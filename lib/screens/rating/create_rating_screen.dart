import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import 'rating_success_screen.dart';

class CreateRatingScreen extends StatelessWidget {
  static const String routeName = '/create-rating';

  const CreateRatingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Rate your meal')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          AppCard(
            child: Row(
              children: [
                Container(width: 60, height: 60, decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(18)), alignment: Alignment.center, child: const Text('MEAL', style: TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.w900))),
                const SizedBox(width: 16),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Grilled Chicken Rice', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
                      SizedBox(height: 6),
                      Text('Order ORD-24001', style: TextStyle(color: AppColors.subText)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 46),
          const Text('How was your food?', textAlign: TextAlign.center, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
          const SizedBox(height: 16),
          const Text('★ ★ ★ ★ ☆', textAlign: TextAlign.center, style: TextStyle(color: AppColors.primary, fontSize: 34, fontWeight: FontWeight.w900)),
          const SizedBox(height: 34),
          const TextField(maxLines: 4, decoration: InputDecoration(labelText: 'Comment', hintText: 'Food was tasty and served quickly.')),
          const SizedBox(height: 26),
          AppButton(label: 'Submit Rating', onPressed: () => Navigator.pushReplacementNamed(context, RatingSuccessScreen.routeName)),
        ],
      ),
    );
  }
}
