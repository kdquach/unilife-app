import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../models/food.dart';
import '../../services/app_state.dart';
import '../../widgets/app_button.dart';
import '../../widgets/status_badge.dart';
import '../cart/cart_screen.dart';

class FoodDetailScreen extends StatefulWidget {
  static const String routeName = '/food-detail';

  final Food food;

  const FoodDetailScreen({super.key, required this.food});

  @override
  State<FoodDetailScreen> createState() => _FoodDetailScreenState();
}

class _FoodDetailScreenState extends State<FoodDetailScreen> {
  int quantity = 1;

  void _addToCart({bool openCart = false}) {
    if (!widget.food.canAddToCart) return;
    AppState.instance.addToCart(widget.food, quantity: quantity);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${widget.food.name} added to cart')));
    if (openCart) Navigator.pushNamed(context, CartScreen.routeName);
  }

  @override
  Widget build(BuildContext context) {
    final food = widget.food;
    return Scaffold(
      body: Stack(
        children: [
          Container(
            height: 310,
            color: food.isMenuFood ? AppColors.primarySoft : AppColors.muted,
            alignment: Alignment.center,
            child: Text(
              food.isMenuFood ? 'MEAL' : food.category.toUpperCase(),
              style: const TextStyle(color: AppColors.primary, fontSize: 44, fontWeight: FontWeight.w900),
            ),
          ),
          SafeArea(
            child: IconButton(
              style: IconButton.styleFrom(backgroundColor: Colors.white),
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back_ios_new_rounded),
            ),
          ),
          DraggableScrollableSheet(
            initialChildSize: 0.66,
            minChildSize: 0.66,
            maxChildSize: 0.9,
            builder: (context, scrollController) {
              return Container(
                padding: const EdgeInsets.fromLTRB(28, 28, 28, 24),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
                ),
                child: ListView(
                  controller: scrollController,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(food.name, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
                        ),
                        StatusBadge(label: food.typeLabel),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      CurrencyFormatter.vnd(food.price),
                      style: const TextStyle(color: AppColors.primary, fontSize: 22, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 26),
                    _InfoRow(label: food.isMenuFood ? 'Menu session' : 'Category', value: food.isMenuFood ? '${food.menuDateLabel} ${food.mealType}' : food.category),
                    _InfoRow(
                      label: food.isMenuFood ? 'Remaining' : 'Stock status',
                      value: food.isMenuFood ? '${food.remainingServings ?? 0} servings' : food.statusLabel,
                      valueColor: food.canAddToCart ? AppColors.success : AppColors.error,
                    ),
                    _InfoRow(label: 'Rating', value: '⭐ ${food.rating.toStringAsFixed(1)}'),
                    const SizedBox(height: 22),
                    Text(food.description, style: const TextStyle(color: AppColors.subText, height: 1.5)),
                    const SizedBox(height: 32),
                    Row(
                      children: [
                        const Expanded(child: Text('Quantity', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900))),
                        Container(
                          decoration: BoxDecoration(color: AppColors.muted, borderRadius: BorderRadius.circular(16)),
                          child: Row(
                            children: [
                              IconButton(onPressed: quantity > 1 ? () => setState(() => quantity--) : null, icon: const Icon(Icons.remove)),
                              Text('$quantity', style: const TextStyle(fontWeight: FontWeight.w900)),
                              IconButton(onPressed: () => setState(() => quantity++), icon: const Icon(Icons.add)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 34),
                    if (food.isMenuFood)
                      Row(
                        children: [
                          Expanded(child: AppButton(label: 'Add Cart', secondary: true, onPressed: food.canAddToCart ? () => _addToCart() : null)),
                          const SizedBox(width: 12),
                          Expanded(child: AppButton(label: 'Order Now', onPressed: food.canAddToCart ? () => _addToCart(openCart: true) : null)),
                        ],
                      )
                    else
                      AppButton(label: 'Add to Cart', onPressed: food.canAddToCart ? () => _addToCart() : null),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _InfoRow({required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(color: AppColors.subText))),
          Text(value, style: TextStyle(color: valueColor ?? AppColors.text, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}
