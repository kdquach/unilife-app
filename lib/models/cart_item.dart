import 'food.dart';

class CartItem {
  final Food food;
  final int quantity;

  const CartItem({required this.food, required this.quantity});

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
