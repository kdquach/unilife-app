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

  factory Order.fromJson(Map<String, dynamic> json) {
    final queueObj = json['queue'];
    String queueNum = 'N/A';
    if (queueObj is Map<String, dynamic>) {
      final qNumRaw = queueObj['queueNumber'];
      if (qNumRaw != null) {
        final qNumStr = qNumRaw.toString();
        final parsedNum = int.tryParse(qNumStr);
        if (parsedNum != null) {
          queueNum = 'A${parsedNum.toString().padLeft(2, '0')}';
        } else {
          queueNum = qNumStr;
        }
      }
    }

    final itemsRaw = json['items'] as List?;
    final itemsList = itemsRaw != null
        ? itemsRaw.map((item) => CartItem.fromJson(item as Map<String, dynamic>)).toList()
        : <CartItem>[];

    return Order(
      id: json['id']?.toString() ?? json['_id']?.toString() ?? '',
      code: json['orderCode'] as String? ?? 'UNKNOWN',
      status: json['status'] as String? ?? 'PENDING',
      queueNumber: queueNum,
      items: itemsList,
      totalPrice: ((json['totalPrice'] as num?) ?? 0).toInt(),
    );
  }
}
