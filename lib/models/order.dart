import 'cart_item.dart';

class Order {
  final String id;
  final String code;
  final String status;
  final String queueNumber;
  final List<CartItem> items;
  final int totalPrice;

  const Order({
    required this.id,
    required this.code,
    required this.status,
    required this.queueNumber,
    required this.items,
    required this.totalPrice,
  });
}
