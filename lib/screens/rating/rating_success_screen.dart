import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../widgets/app_button.dart';

class RatingSuccessScreen extends StatelessWidget {
  static const String routeName = '/rating-success';

  const RatingSuccessScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            children: [
              const Spacer(),
              Container(width: 174, height: 174, decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle), child: const Icon(Icons.star_rounded, color: Colors.white, size: 92)),
              const SizedBox(height: 34),
              const Text('Rating submitted', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
              const SizedBox(height: 12),
              const Text('Your feedback helps UniLife improve meal quality.', textAlign: TextAlign.center, style: TextStyle(color: AppColors.subText)),
              const Spacer(),
              AppButton(label: 'Back', onPressed: () => Navigator.pop(context)),
            ],
          ),
        ),
      ),
    );
  }
}
