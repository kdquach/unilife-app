import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../models/food.dart';
import '../../services/api_client.dart';
import '../../services/app_state.dart';
import '../../services/food_service.dart';
import '../../widgets/food_cards.dart';
import '../food/food_detail_screen.dart';

class AlwaysAvailableScreen extends StatefulWidget {
  static const String routeName = '/always-available';

  const AlwaysAvailableScreen({super.key});

  @override
  State<AlwaysAvailableScreen> createState() => _AlwaysAvailableScreenState();
}

class _AlwaysAvailableScreenState extends State<AlwaysAvailableScreen> {
  final FoodService _foodService = FoodService(ApiClient());

  List<Food> _foods = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadFoods();
  }

  Future<void> _loadFoods() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final foods = await _foodService.getAlwaysAvailableFoods();
      if (mounted) setState(() => _foods = foods);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _open(Food food) =>
      Navigator.pushNamed(context, FoodDetailScreen.routeName, arguments: food);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Always Available')),
      body: RefreshIndicator(
        onRefresh: _loadFoods,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.wifi_off_rounded, size: 56, color: AppColors.subText),
              const SizedBox(height: 16),
              const Text(
                'Could not load foods',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(_error!, textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.subText)),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _loadFoods,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_foods.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.fastfood_outlined, size: 56, color: AppColors.subText),
            SizedBox(height: 16),
            Text('No daily foods available',
                style: TextStyle(fontSize: 16, color: AppColors.subText)),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          '${_foods.length} item${_foods.length > 1 ? 's' : ''} available today',
          style: const TextStyle(color: AppColors.subText),
        ),
        const SizedBox(height: 20),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _foods.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: 0.72,
          ),
          itemBuilder: (_, index) {
            final food = _foods[index];
            return RegularFoodCard(
              food: food,
              onTap: () => _open(food),
              onAdd: food.canAddToCart
                  ? () => AppState.instance.addToCart(food)
                  : null,
            );
          },
        ),
      ],
    );
  }
}

