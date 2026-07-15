import 'dart:collection';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../models/product.dart';
import '../models/sale.dart';
import '../models/sale_item.dart';
import 'app_repository.dart';

// Categorias oficiais do sistema (definidas apenas aqui para evitar conflitos)
const List<String> defaultCategories = <String>[
  'Ferramentas',
  'Fixacao',
  'Tintas',
  'Eletrica',
  'Hidraulica',
  'Seguranca',
  'Outros',
];

class CartEntry {
  const CartEntry({
    required this.product,
    required this.quantity,
  });

  final Product product;
  final int quantity;

  double get total => product.preco * quantity;
}

class ProductSalesSummary {
  const ProductSalesSummary({
    required this.productName,
    required this.quantitySold,
    required this.revenue,
  });

  final String productName;
  final int quantitySold;
  final double revenue;
}

class StoreController extends ChangeNotifier {
  StoreController({required this.repository});

  final AppRepository repository;
  final Random _random = Random();

  final Map<String, int> _cart = <String, int>{};
  List<Product> _products = <Product>[];
  List<Sale> _sales = <Sale>[];
  bool _isLoading = false;

  List<Product> get products => UnmodifiableListView<Product>(_products);
  List<Sale> get sales => UnmodifiableListView<Sale>(_sales);
  bool get isLoading => _isLoading;
  int get cartItemsCount =>
      _cart.values.fold<int>(0, (sum, quantity) => sum + quantity);

  List<CartEntry> get cartEntries {
    return _cart.entries.map((entry) {
      final product = _products.firstWhere((item) => item.id == entry.key);
      return CartEntry(product: product, quantity: entry.value);
    }).toList();
  }

  double get cartTotal => cartEntries.fold<double>(
        0,
        (sum, entry) => sum + entry.total,
      );

  double get totalStockValue => _products.fold<double>(
        0,
        (sum, product) => sum + (product.preco * product.stock),
      );

  List<Product> get lowStockProducts =>
      _products.where((product) => product.stock <= 5).toList()
        ..sort((a, b) => a.stock.compareTo(b.stock));

  Future<void> load() async {
    _isLoading = true;
    notifyListeners();

    final products = await repository.loadProducts();
    final sales = await repository.loadSales();

    _products = products.isEmpty ? _seedProducts() : products;
    _sales = sales;

    if (products.isEmpty) {
      await repository.saveProducts(_products);
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> addProduct(Product product) async {
    _products = <Product>[product, ..._products];
    await repository.saveProducts(_products);
    notifyListeners();
  }

  Future<void> updateProduct(Product updatedProduct) async {
    _products = _products
        .map((product) => product.id == updatedProduct.id ? updatedProduct : product)
        .toList();
    await repository.saveProducts(_products);
    notifyListeners();
  }

  Future<void> deleteProduct(String productId) async {
    _products = _products.where((product) => product.id != productId).toList();
    _cart.remove(productId);
    await repository.saveProducts(_products);
    notifyListeners();
  }

  String? addToCart(Product product) {
    final currentQty = _cart[product.id] ?? 0;
    if (currentQty >= product.stock) {
      return 'Stock insuficiente para adicionar mais unidades.';
    }

    _cart[product.id] = currentQty + 1;
    notifyListeners();
    return null;
  }

  String? updateCartQuantity(String productId, int quantity) {
    final product = _products.firstWhere((item) => item.id == productId);

    if (quantity <= 0) {
      _cart.remove(productId);
      notifyListeners();
      return null;
    }

    if (quantity > product.stock) {
      return 'Nao pode vender mais do que o stock disponivel.';
    }

    _cart[productId] = quantity;
    notifyListeners();
    return null;
  }

  void clearCart() {
    _cart.clear();
    notifyListeners();
  }

  Future<String?> finalizeSale() async {
    if (_cart.isEmpty) {
      return 'O carrinho esta vazio.';
    }

    final updatedProducts = <Product>[];
    final saleItems = <SaleItem>[];

    for (final product in _products) {
      final quantity = _cart[product.id] ?? 0;
      if (quantity == 0) {
        updatedProducts.add(product);
        continue;
      }

      if (quantity > product.stock) {
        return 'Stock insuficiente para ${product.nome}.';
      }

      updatedProducts.add(
        product.copyWith(
          stock: product.stock - quantity,
          ultimaAtualizacao: DateTime.now(),
        ),
      );

      saleItems.add(
        SaleItem(
          productId: product.id,
          productName: product.nome,
          category: product.categoria,
          unitPrice: product.preco,
          quantity: quantity,
        ),
      );
    }

    final total = saleItems.fold<double>(0, (sum, item) => sum + item.total);
    final sale = Sale(
      id: _generateId(),
      data: DateTime.now(),
      itens: saleItems,
      total: total,
    );

    _products = updatedProducts;
    _sales = <Sale>[sale, ..._sales];
    _cart.clear();

    await repository.saveProducts(_products);
    await repository.saveSales(_sales);
    notifyListeners();

    return null;
  }

  Future<void> restockProduct(String productId, int amount) async {
    if (amount <= 0) {
      return;
    }

    _products = _products.map((product) {
      if (product.id != productId) {
        return product;
      }

      return product.copyWith(
        stock: product.stock + amount,
        ultimaAtualizacao: DateTime.now(),
      );
    }).toList();

    await repository.saveProducts(_products);
    notifyListeners();
  }

  double salesTotalForDay(DateTime date) {
    return _sales
        .where((sale) => _isSameDate(sale.data, date))
        .fold<double>(0, (sum, sale) => sum + sale.total);
  }

  double salesTotalForLastDays(int days) {
    final now = DateTime.now();
    final start =
        DateTime(now.year, now.month, now.day).subtract(Duration(days: days - 1));

    return _sales.where((sale) => !sale.data.isBefore(start)).fold<double>(
          0,
          (sum, sale) => sum + sale.total,
        );
  }

  List<ProductSalesSummary> bestSellingProducts({int limit = 5}) {
    final Map<String, ProductSalesSummary> totals =
        <String, ProductSalesSummary>{};

    for (final sale in _sales) {
      for (final item in sale.itens) {
        final existing = totals[item.productId];
        totals[item.productId] = ProductSalesSummary(
          productName: item.productName,
          quantitySold: (existing?.quantitySold ?? 0) + item.quantity,
          revenue: (existing?.revenue ?? 0) + item.total,
        );
      }
    }

    final summaries = totals.values.toList()
      ..sort((a, b) => b.quantitySold.compareTo(a.quantitySold));
    return summaries.take(limit).toList();
  }

  List<Product> _seedProducts() {
    final now = DateTime.now();
    return <Product>[
      Product(
        id: _generateId(),
        nome: 'Martelo 27mm',
        categoria: 'Ferramentas',
        preco: 3500,
        stock: 12,
        codigoBarras: '1000001',
        ultimaAtualizacao: now,
      ),
      Product(
        id: _generateId(),
        nome: 'Parafuso 8x60',
        categoria: 'Fixacao',
        preco: 120,
        stock: 150,
        codigoBarras: '1000002',
        ultimaAtualizacao: now,
      ),
      Product(
        id: _generateId(),
        nome: 'Tinta Acrilica 18L',
        categoria: 'Tintas',
        preco: 28500,
        stock: 4,
        codigoBarras: '1000003',
        ultimaAtualizacao: now,
      ),
      Product(
        id: _generateId(),
        nome: 'Tomada Dupla',
        categoria: 'Eletrica',
        preco: 1800,
        stock: 8,
        codigoBarras: '1000004',
        ultimaAtualizacao: now,
      ),
      Product(
        id: _generateId(),
        nome: 'Torneira 1/2',
        categoria: 'Hidraulica',
        preco: 4200,
        stock: 6,
        codigoBarras: '1000005',
        ultimaAtualizacao: now,
      ),
    ];
  }

  String _generateId() {
    final timestamp = DateTime.now().microsecondsSinceEpoch;
    final suffix = _random.nextInt(999999).toString().padLeft(6, '0');
    return '$timestamp$suffix';
  }

  bool _isSameDate(DateTime first, DateTime second) {
    return first.year == second.year &&
        first.month == second.month &&
        first.day == second.day;
  }

  void decrementCartQuantity(Product product) {
    final currentQty = _cart[product.id] ?? 0;
    
    if (currentQty <= 1) {
      _cart.remove(product.id);
    } else {
      _cart[product.id] = currentQty - 1;
    }
    notifyListeners();
  }

  void removeFromCart(Product product) {
    _cart.remove(product.id);
    notifyListeners();
  }
}
