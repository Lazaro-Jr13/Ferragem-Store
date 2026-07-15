class SaleItem {
  const SaleItem({
    required this.productId,
    required this.productName,
    required this.category,
    required this.unitPrice,
    required this.quantity,
  });

  final String productId;
  final String productName;
  final String category;
  final double unitPrice;
  final int quantity;

  double get total => unitPrice * quantity;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'productId': productId,
      'productName': productName,
      'category': category,
      'unitPrice': unitPrice,
      'quantity': quantity,
    };
  }

  factory SaleItem.fromJson(Map<String, dynamic> json) {
    return SaleItem(
      productId: json['productId'] as String,
      productName: json['productName'] as String,
      category: json['category'] as String,
      unitPrice: (json['unitPrice'] as num).toDouble(),
      quantity: json['quantity'] as int,
    );
  }
}

