import 'package:flutter/material.dart';

import '../../core/constants/app_assets.dart';
import '../../core/theme/app_colors.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';

class UiStatesScreen extends StatelessWidget {
  static const String routeName = '/ui-states';

  const UiStatesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('UI States')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text('Loading menu', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                SizedBox(height: 8),
                Text('Please wait while we fetch latest meals.', style: TextStyle(color: AppColors.subText)),
                SizedBox(height: 18),
                LinearProgressIndicator(color: AppColors.primary),
              ],
            ),
          ),
          const SizedBox(height: 18),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Something went wrong', style: TextStyle(color: AppColors.error, fontSize: 18, fontWeight: FontWeight.w900)),
                const SizedBox(height: 8),
                const Text('Could not connect to server. Try again.', style: TextStyle(color: AppColors.subText)),
                const SizedBox(height: 18),
                SizedBox(width: 120, child: AppButton(label: 'Retry', secondary: true, onPressed: () {})),
              ],
            ),
          ),
          const SizedBox(height: 18),
          AppCard(
            child: Column(
              children: [
                Image.asset(AppAssets.emptyState, height: 130),
                const SizedBox(height: 12),
                const Text('No data found', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                const SizedBox(height: 8),
                const Text('Use empty state for cart, order, notification and rating list.', textAlign: TextAlign.center, style: TextStyle(color: AppColors.subText)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
