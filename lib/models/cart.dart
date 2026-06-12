import 'food.dart';
import 'menu_schedule.dart';

class Cart {
  final String cartId;
  final String userId;
  final int totalPrice;
  final int totalItems;
  final List<CartItemDto> items;

  Cart({
    required this.cartId,
    required this.userId,
    required this.totalPrice,
    required this.totalItems,
    required this.items,
  });

  Cart copyWith({
    String? cartId,
    String? userId,
    int? totalPrice,
    int? totalItems,
    List<CartItemDto>? items,
  }) {
    return Cart(
      cartId: cartId ?? this.cartId,
      userId: userId ?? this.userId,
      totalPrice: totalPrice ?? this.totalPrice,
      totalItems: totalItems ?? this.totalItems,
      items: items ?? this.items,
    );
  }

  List<CartItemDto> get validItems => items.where((e) => e.isValid).toList();
  List<CartItemDto> get invalidItems => items.where((e) => !e.isValid).toList();

  factory Cart.fromJson(Map<String, dynamic> json) {
    return Cart(
      cartId: json['cartId'] as String? ?? '',
      userId: json['userId'] as String? ?? '',
      totalPrice: (json['totalPrice'] as num?)?.toInt() ?? 0,
      totalItems: (json['totalItems'] as num?)?.toInt() ?? 0,
      items: (json['items'] as List<dynamic>?)
              ?.map((e) => CartItemDto.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

class CartItemDto {
  final String cartItemId;
  final String? menuScheduleItemId;
  final int quantity;
  final Food? food;
  final MenuSchedule? menuSchedule;
  final int? maxServing;
  final int? remainingCount;
  final bool isValid;
  final String? reason;
  final int subtotal;

  CartItemDto({
    required this.cartItemId,
    this.menuScheduleItemId,
    required this.quantity,
    this.food,
    this.menuSchedule,
    this.maxServing,
    this.remainingCount,
    required this.isValid,
    this.reason,
    required this.subtotal,
  });

  factory CartItemDto.fromJson(Map<String, dynamic> json) {
    return CartItemDto(
      cartItemId: json['cartItemId'] as String? ?? '',
      menuScheduleItemId: json['menuScheduleItemId'] as String?,
      quantity: (json['quantity'] as num?)?.toInt() ?? 0,
      food: json['food'] != null ? Food.fromJson(json['food']) : null,
      menuSchedule: json['menuSchedule'] != null ? MenuSchedule.fromJson(json['menuSchedule']) : null,
      maxServing: (json['maxServing'] as num?)?.toInt(),
      remainingCount: (json['remainingCount'] as num?)?.toInt(),
      isValid: json['isValid'] as bool? ?? true,
      reason: json['reason'] as String?,
      subtotal: (json['subtotal'] as num?)?.toInt() ?? 0,
    );
  }
}
