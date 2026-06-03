import 'package:flutter/material.dart';

import '../../core/constants/app_assets.dart';
import '../../core/theme/app_colors.dart';
import '../../widgets/app_button.dart';

class UploadAvatarScreen extends StatelessWidget {
  static const String routeName = '/upload-avatar';

  const UploadAvatarScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Upload avatar')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Text('Choose a profile photo', style: TextStyle(color: AppColors.subText)),
            const SizedBox(height: 34),
            CircleAvatar(
              radius: 84,
              backgroundColor: AppColors.primarySoft,
              child: Padding(padding: const EdgeInsets.all(28), child: Image.asset(AppAssets.logoMd)),
            ),
            const SizedBox(height: 38),
            AppButton(label: 'Choose from Gallery', secondary: true, onPressed: () {}),
            const SizedBox(height: 14),
            AppButton(label: 'Take Photo', secondary: true, onPressed: () {}),
            const Spacer(),
            AppButton(label: 'Upload Avatar', onPressed: () => Navigator.pop(context)),
          ],
        ),
      ),
    );
  }
}
