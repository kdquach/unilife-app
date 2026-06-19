import 'cart_item.dart';

import 'cart_item.dart';

class PaymentInfo {
  final String? qrCodeUrl;
  final String? bankName;
  final String? accountNumber;

  const PaymentInfo({
    this.qrCodeUrl,
    this.bankName,
    this.accountNumber,
  });

  PaymentInfo copyWith({
    String? qrCodeUrl,
    String? bankName,
    String? accountNumber,
  }) {
    return PaymentInfo(
      qrCodeUrl: qrCodeUrl ?? this.qrCodeUrl,
      bankName: bankName ?? this.bankName,
      accountNumber: accountNumber ?? this.accountNumber,
    );
  }

  factory PaymentInfo.fromJson(Map<String, dynamic> json) {
    return PaymentInfo(
      qrCodeUrl: json['qrCodeUrl'] as String?,
      bankName: json['bankName'] as String?,
      accountNumber: json['accountNumber'] as String?,
    );
  }
}

class Order {
  final String id;
  final String code;
  final String status;
  final String queueNumber;
  final List<CartItem> items;
  final int totalPrice;
  final String paymentMethod;
  final String paymentStatus;
  final PaymentInfo? paymentInfo;
  final String? transferContent;
  final String? transactionRef;
  final String? note;
  final DateTime? createdAt;
  final DateTime? expiresAt;
  final DateTime? paidAt;

  const Order({
    required this.id,
    required this.code,
    required this.status,
    required this.queueNumber,
    required this.items,
    required this.totalPrice,
    required this.paymentMethod,
    required this.paymentStatus,
    this.paymentInfo,
    this.transferContent,
    this.transactionRef,
    this.note,
    this.createdAt,
    this.expiresAt,
    this.paidAt,
  });

  Order copyWith({
    String? id,
    String? code,
    String? status,
    String? queueNumber,
    List<CartItem>? items,
    int? totalPrice,
    String? paymentMethod,
    String? paymentStatus,
    PaymentInfo? paymentInfo,
    String? transferContent,
    String? transactionRef,
    String? note,
    DateTime? createdAt,
    DateTime? expiresAt,
    DateTime? paidAt,
  }) {
    return Order(
      id: id ?? this.id,
      code: code ?? this.code,
      status: status ?? this.status,
      queueNumber: queueNumber ?? this.queueNumber,
      items: items ?? this.items,
      totalPrice: totalPrice ?? this.totalPrice,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      paymentInfo: paymentInfo ?? this.paymentInfo,
      transferContent: transferContent ?? this.transferContent,
      transactionRef: transactionRef ?? this.transactionRef,
      note: note ?? this.note,
      createdAt: createdAt ?? this.createdAt,
      expiresAt: expiresAt ?? this.expiresAt,
      paidAt: paidAt ?? this.paidAt,
    );
  }

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

    final paymentMethod = json['paymentMethod'] as String? ?? 'SEPAY';
    final paymentStatus = json['paymentStatus'] as String? ?? 'PENDING';
    
    final paymentInfoRaw = json['paymentInfo'];
    final paymentInfo = paymentInfoRaw is Map<String, dynamic> 
        ? PaymentInfo.fromJson(paymentInfoRaw) 
        : null;

    DateTime? tryParseDate(String key) {
      final str = json[key] as String?;
      return str != null ? DateTime.tryParse(str) : null;
    }

    return Order(
      id: json['id']?.toString() ?? json['_id']?.toString() ?? '',
      code: json['orderCode'] as String? ?? 'UNKNOWN',
      status: json['status'] as String? ?? 'PENDING',
      queueNumber: queueNum,
      items: itemsList,
      totalPrice: ((json['totalPrice'] as num?) ?? 0).toInt(),
      paymentMethod: paymentMethod,
      paymentStatus: paymentStatus,
      paymentInfo: paymentInfo,
      transferContent: json['transferContent'] as String?,
      transactionRef: json['transactionRef'] as String?,
      note: json['note'] as String?,
      createdAt: tryParseDate('createdAt'),
      expiresAt: tryParseDate('expiresAt'),
      paidAt: tryParseDate('paidAt'),
    );
  }
}
