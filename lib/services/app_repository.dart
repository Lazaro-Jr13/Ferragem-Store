import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/product.dart';
import '../models/sale.dart';

class AppRepository {
  static const _productsKey = 'products';
  static const _salesKey = 'sales';

  Future<List<Product>> loadProducts() async {
    final prefs = await SharedPreferences.getInstance();
    final rawItems = prefs.getStringList(_productsKey) ?? <String>[];

    return rawItems
        .map((item) => Product.fromJson(jsonDecode(item) as Map<String, dynamic>))
        .toList();
  }

  Future<List<Sale>> loadSales() async {
    final prefs = await SharedPreferences.getInstance();
    final rawItems = prefs.getStringList(_salesKey) ?? <String>[];

    return rawItems
        .map((item) => Sale.fromJson(jsonDecode(item) as Map<String, dynamic>))
        .toList();
  }

  Future<void> saveProducts(List<Product> products) async {
    final prefs = await SharedPreferences.getInstance();
    final rawItems = products.map((product) => jsonEncode(product.toJson())).toList();
    await prefs.setStringList(_productsKey, rawItems);
  }

  Future<void> saveSales(List<Sale> sales) async {
    final prefs = await SharedPreferences.getInstance();
    final rawItems = sales.map((sale) => jsonEncode(sale.toJson())).toList();
    await prefs.setStringList(_salesKey, rawItems);
  }
}

