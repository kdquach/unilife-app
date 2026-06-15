import 'food.dart';

class CartItem {
  final Food food;
  final int quantity;

  const CartItem({required this.food, required this.quantity});

  factory CartItem.fromJson(Map<String, dynamic> json) {
    Food food;
    final menuScheduleItemJson = json['menuScheduleItemId'];
    if (menuScheduleItemJson is Map<String, dynamic>) {
      food = Food.fromMenuScheduleItemJson(menuScheduleItemJson);
    } else {
      final foodJson = json['foodId'];
      if (foodJson is Map<String, dynamic>) {
        food = Food.fromJson(foodJson);
      } else {
        food = const Food(
          id: '',
          name: 'Unknown Food',
          category: '',
          description: '',
          price: 0,
          kind: FoodKind.alwaysAvailable,
          status: FoodStatus.available,
        );
      }
    }
    final quantity = (json['quantity'] as num? ?? 0).toInt();
    return CartItem(food: food, quantity: quantity);
  }

  int get subtotal => food.price * quantity;

  String get backendItemType => food.isMenuFood ? 'MENU_ITEM' : 'REGULAR_FOOD';

  Map<String, dynamic> toPayload() {
    return {
      'itemType': backendItemType,
      'menuScheduleItemId': food.isMenuFood ? food.menuScheduleItemId : null,
      'foodId': food.isAlwaysAvailable ? food.id : null,
      'quantity': quantity,
      'unitPrice': food.price,
    };
  }
}
