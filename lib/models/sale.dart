import 'sale_item.dart';

class Sale {
  const Sale({
    required this.id,
    required this.data,
    required this.itens,
    required this.total,
  });

  final String id;
  final DateTime data;
  final List<SaleItem> itens;
  final double total;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'data': data.toIso8601String(),
      'itens': itens.map((item) => item.toJson()).toList(),
      'total': total,
    };
  }

  factory Sale.fromJson(Map<String, dynamic> json) {
    final items = (json['itens'] as List<dynamic>)
        .map((item) => SaleItem.fromJson(item as Map<String, dynamic>))
        .toList();

    return Sale(
      id: json['id'] as String,
      data: DateTime.parse(json['data'] as String),
      itens: items,
      total: (json['total'] as num).toDouble(),
    );
  }
}

