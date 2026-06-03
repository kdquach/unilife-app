import 'package:flutter/foundation.dart';

import '../data/sample_data.dart';
import '../models/cart_item.dart';
import '../models/food.dart';

class AppState {
  AppState._();

  static final AppState instance = AppState._();

  final ValueNotifier<List<CartItem>> cart = ValueNotifier<List<CartItem>>(
    List<CartItem>.from(SampleData.initialCart),
  );

  void addToCart(Food food, {int quantity = 1}) {
    final items = List<CartItem>.from(cart.value);
    final index = items.indexWhere((item) => item.food.id == food.id);
    if (index >= 0) {
      final current = items[index];
      items[index] = CartItem(food: current.food, quantity: current.quantity + quantity);
    } else {
      items.add(CartItem(food: food, quantity: quantity));
    }
    cart.value = items;
  }

  void clearCart() {
    cart.value = [];
  }
}
