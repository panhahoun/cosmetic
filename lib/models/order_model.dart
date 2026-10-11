class OrderItem {
  final int id;
  final int productId;
  final String productName;
  final String productImage;
  final double price;
  final int quantity;
  final double subtotal;

  OrderItem({
    required this.id,
    required this.productId,
    required this.productName,
    required this.productImage,
    required this.price,
    required this.quantity,
    required this.subtotal,
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    double d(dynamic v) => double.tryParse(v?.toString() ?? '') ?? 0;
    int i(dynamic v) => int.tryParse(v?.toString() ?? '') ?? 0;
    return OrderItem(
      id: i(json['id']),
      productId: i(json['product_id']),
      productName: json['product_name']?.toString() ?? '',
      productImage: (json['product_image'] ?? '').toString(),
      price: d(json['price']),
      quantity: i(json['quantity']),
      subtotal: d(json['subtotal']),
    );
  }
}

class Order {
  final int id;
  final String orderNumber;
  final double totalAmount;
  final String status;
  final String paymentMethod;
  final String shippingAddress;
  final String notes;
  final DateTime? createdAt;
  final List<OrderItem> items;

  Order({
    required this.id,
    required this.orderNumber,
    required this.totalAmount,
    required this.status,
    required this.paymentMethod,
    required this.shippingAddress,
    required this.notes,
    required this.createdAt,
    required this.items,
  });

  factory Order.fromJson(Map<String, dynamic> json) {
    double d(dynamic v) => double.tryParse(v?.toString() ?? '') ?? 0;
    int i(dynamic v) => int.tryParse(v?.toString() ?? '') ?? 0;
    final raw = json['items'];
    final items = raw is List
        ? raw.whereType<Map<String, dynamic>>().map(OrderItem.fromJson).toList()
        : <OrderItem>[];
    return Order(
      id: i(json['id']),
      orderNumber: json['order_number']?.toString() ?? '',
      totalAmount: d(json['total_amount']),
      status: json['status']?.toString() ?? '',
      paymentMethod: json['payment_method']?.toString() ?? '',
      shippingAddress: json['shipping_address']?.toString() ?? '',
      notes: json['notes']?.toString() ?? '',
      createdAt: DateTime.tryParse(
        json['created_at']?.toString() ?? '',
      )?.toLocal(),
      items: items,
    );
  }

  int get itemCount => items.fold(0, (sum, it) => sum + it.quantity);
}
