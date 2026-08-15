import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../models/food.dart';
import '../services/api_client.dart';

String? resolveFoodImageUrl(Food food) {
  final imageUrl = food.imageUrl;
  if (imageUrl == null || imageUrl.isEmpty) return null;
  if (imageUrl.startsWith('http://') || imageUrl.startsWith('https://')) {
    return imageUrl;
  }
  final apiRoot = Uri.parse(ApiClient.baseUrl);
  final origin = '${apiRoot.scheme}://${apiRoot.authority}';
  final normalizedPath = imageUrl.startsWith('/') ? imageUrl : '/$imageUrl';
  return '$origin$normalizedPath';
}

class FoodImagePlaceholder extends StatelessWidget {
  final Food food;
  final double size;
  final double radius;

  const FoodImagePlaceholder({
    super.key,
    required this.food,
    this.size = 80,
    this.radius = 20,
  });

  @override
  Widget build(BuildContext context) {
    final imageUrl = resolveFoodImageUrl(food);

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(
        width: size,
        height: size,
        child: imageUrl != null
            ? Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _buildPlaceholder(),
              )
            : _buildPlaceholder(),
      ),
    );
  }

  Widget _buildPlaceholder() {
    final label = food.isMenuFood ? 'MEAL' : food.category.toUpperCase();
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: food.isMenuFood ? AppColors.primarySoft : AppColors.muted,
        borderRadius: BorderRadius.circular(radius),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: AppColors.primary,
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}
