import 'dart:collection';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../models/product.dart';
import '../models/sale.dart';
import '../models/sale_item.dart';
import 'app_repository.dart';

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

  // --- Métodos de manipulação direta do Carrinho (Map) ---
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
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/product.dart';
import '../models/sale.dart';
import '../services/store_controller.dart';

final NumberFormat currencyFormat = NumberFormat.simpleCurrency(decimalDigits: 2);
final DateFormat dateTimeFormat = DateFormat('dd/MM/yyyy HH:mm');

const List<String> defaultCategories = ['Geral', 'Ferramentas', 'Construção', 'Elétrica', 'Pintura', 'Hidráulica'];

class StockTab extends StatelessWidget {
  const StockTab({super.key, required this.controller, required this.onRestock});
  final StoreController controller;
  final Function(Product) onRestock;

  @override
  Widget build(BuildContext context) {
    final products = controller.products;
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: products.length,
      itemBuilder: (context, index) {
        final product = products[index];
        return Card(
          child: ListTile(
            title: Text(product.nome),
            subtitle: Text('Estoque atual: ${product.stock}'),
            trailing: IconButton(
              icon: const Icon(Icons.add_box),
              onPressed: () => onRestock(product),
            ),
          ),
        );
      },
    );
  }
}

class ReportsTab extends StatelessWidget {
  const ReportsTab({super.key, required this.controller});
  final StoreController controller;

  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('Aba de Relatórios'));
  }
}

Future<Product?> showProductFormSheet(BuildContext context, {Product? product}) async {
  return null;
}

Future<int?> showRestockDialog(BuildContext context, String productName) async {
  return null;
}

void showSalesHistorySheet(BuildContext context, List<Sale> sales) {
  showModalBottomSheet<void>(
    context: context,
    builder: (context) {
      return SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Histórico de Vendas',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            Expanded(
              child: sales.isEmpty
                  ? const Center(child: Text('Nenhuma venda registrada.'))
                  : ListView.builder(
                      itemCount: sales.length,
                      itemBuilder: (context, index) {
                        final sale = sales[index];
                        return ListTile(
                          title: Text('Venda #${sale.id}'),
                          subtitle: Text('Itens: ${sale.items.length}'),
                        );
                      },
                    ),
            ),
          ],
        ),
      );
    },
  );
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.controller,
  });

  final StoreController controller;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  StoreController get controller => widget.controller;

  String get _title {
    switch (_currentIndex) {
      case 0:
        return 'Produtos';
      case 1:
        return 'Caixa';
      case 2:
        return 'Stock';
      case 3:
        return 'Relatorios';
      default:
        return 'Ferragem Store';
    }
  }

  Future<void> _openProductForm([Product? product]) async {
    final result = await showProductFormSheet(context, product: product);
    if (!mounted || result == null) {
      return;
    }

    if (product == null) {
      await controller.addProduct(result);
      if (!mounted) {
        return;
      }
      _showMessage('Produto cadastrado com sucesso.');
      return;
    }

    await controller.updateProduct(result);
    if (!mounted) {
      return;
    }
    _showMessage('Produto updated com sucesso.');
  }

  Future<void> _confirmDelete(Product product) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Excluir produto'),
          content: Text('Deseja excluir ${product.nome}?'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Excluir'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    await controller.deleteProduct(product.id);
    if (!mounted) {
      return;
    }
    _showMessage('Produto removido.');
  }

  Future<void> _openRestockDialog(Product product) async {
    final amount = await showRestockDialog(context, product.nome);
    if (!mounted || amount == null) {
      return;
    }

    await controller.restockProduct(product.id, amount);
    if (!mounted) {
      return;
    }
    _showMessage('Stock updated.');
  }

  Future<void> _finalizeSale() async {
    final error = await controller.finalizeSale();
    if (!mounted) {
      return;
    }

    if (error != null) {
      _showMessage(error);
      return;
    }

    _showMessage('Venda registada com sucesso.');
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(
            title: Text(_title),
            actions: <Widget>[
              IconButton(
                tooltip: 'Historico',
                onPressed: () => showSalesHistorySheet(
                  context,
                  controller.sales,
                ),
                icon: const Icon(Icons.receipt_long_outlined),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: IconButton(
                  tooltip: 'Carrinho',
                  onPressed: () => setState(() => _currentIndex = 1),
                  icon: _CartBadge(count: controller.cartItemsCount),
                ),
              ),
            ],
          ),
          drawer: Drawer(
            child: SafeArea(
              child: ListView(
                padding: const EdgeInsets.all(12),
                children: <Widget>[
                  const ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Color(0xFFFF7A00),
                      child: Icon(Icons.storefront, color: Colors.white),
                    ),
                    title: Text(
                      'Ferragem Store',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text('Gestao offline de loja'),
                  ),
                  const SizedBox(height: 8),
                  _DrawerItem(
                    label: 'Produtos',
                    icon: Icons.inventory_2_outlined,
                    selected: _currentIndex == 0,
                    onTap: () {
                      Navigator.of(context).pop();
                      setState(() => _currentIndex = 0);
                    },
                  ),
                  _DrawerItem(
                    label: 'Caixa',
                    icon: Icons.point_of_sale_outlined,
                    selected: _currentIndex == 1,
                    onTap: () {
                      Navigator.of(context).pop();
                      setState(() => _currentIndex = 1);
                    },
                  ),
                  _DrawerItem(
                    label: 'Stock',
                    icon: Icons.warehouse_outlined,
                    selected: _currentIndex == 2,
                    onTap: () {
                      Navigator.of(context).pop();
                      setState(() => _currentIndex = 2);
                    },
                  ),
                  _DrawerItem(
                    label: 'Relatorios',
                    icon: Icons.bar_chart_outlined,
                    selected: _currentIndex == 3,
                    onTap: () {
                      Navigator.of(context).pop();
                      setState(() => _currentIndex = 3);
                    },
                  ),
                  const Divider(height: 28),
                  _DrawerItem(
                    label: 'Historico de vendas',
                    icon: Icons.history,
                    selected: false,
                    onTap: () {
                      Navigator.of(context).pop();
                      showSalesHistorySheet(context, controller.sales);
                    },
                  ),
                ],
              ),
            ),
          ),
          floatingActionButton: _currentIndex == 0
              ? FloatingActionButton.extended(
                  onPressed: _openProductForm,
                  backgroundColor: const Color(0xFFFF7A00),
                  foregroundColor: Colors.white,
                  icon: const Icon(Icons.add),
                  label: const Text('Novo Produto'),
                )
              : null,
          bottomNavigationBar: NavigationBar(
            selectedIndex: _currentIndex,
            onDestinationSelected: (index) => setState(() => _currentIndex = index),
            destinations: const <NavigationDestination>[
              NavigationDestination(
                icon: Icon(Icons.inventory_2_outlined),
                selectedIcon: Icon(Icons.inventory_2),
                label: 'Produtos',
              ),
              NavigationDestination(
                icon: Icon(Icons.point_of_sale_outlined),
                selectedIcon: Icon(Icons.point_of_sale),
                label: 'Caixa',
              ),
              NavigationDestination(
                icon: Icon(Icons.warehouse_outlined),
                selectedIcon: Icon(Icons.warehouse),
                label: 'Stock',
              ),
              NavigationDestination(
                icon: Icon(Icons.bar_chart_outlined),
                selectedIcon: Icon(Icons.bar_chart),
                label: 'Relatorios',
              ),
            ],
          ),
          body: controller.isLoading
              ? const Center(child: CircularProgressIndicator())
              : IndexedStack(
                  index: _currentIndex,
                  children: <Widget>[
                    ProductsTab(
                      controller: controller,
                      onEdit: _openProductForm,
                      onDelete: _confirmDelete,
                    ),
                    CheckoutTab(
                      controller: controller,
                      onFinalizeSale: _finalizeSale,
                      onShowHistory: () => showSalesHistorySheet(
                        context,
                        controller.sales,
                      ),
                      onShowMessage: _showMessage,
                    ),
                    StockTab(
                      controller: controller,
                      onRestock: _openRestockDialog,
                    ),
                    ReportsTab(controller: controller),
                  ],
                ),
        );
      },
    );
  }
}

class ProductsTab extends StatefulWidget {
  const ProductsTab({
    super.key,
    required this.controller,
    required this.onEdit,
    required this.onDelete,
  });

  final StoreController controller;
  final Future<void> Function(Product product) onEdit;
  final Future<void> Function(Product product) onDelete;

  @override
  State<ProductsTab> createState() => _ProductsTabState();
}

class _ProductsTabState extends State<ProductsTab> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedCategory = 'Todas';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final products = widget.controller.products.where((product) {
      final matchesSearch = product.nome.toLowerCase().contains(
            _searchController.text.trim().toLowerCase(),
          );
      final matchesCategory =
          _selectedCategory == 'Todas' || product.categoria == _selectedCategory;
      return matchesSearch && matchesCategory;
    }).toList()
      ..sort((a, b) => a.nome.compareTo(b.nome));

    final categories = <String>{
      'Todas',
      ...defaultCategories,
      ...widget.controller.products.map((item) => item.categoria),
    }.toList();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: <Widget>[
          TextField(
            controller: _searchController,
            decoration: const InputDecoration(
              hintText: 'Pesquisar produto',
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _selectedCategory,
            decoration: const InputDecoration(
              labelText: 'Categoria',
            ),
            items: categories
                .map(
                  (category) => DropdownMenuItem<String>(
                    value: category,
                    child: Text(category),
                  ),
                )
                .toList(),
            onChanged: (value) {
              if (value == null) {
                return;
              }
              setState(() => _selectedCategory = value);
            },
          ),
          const SizedBox(height: 16),
          Expanded(
            child: products.isEmpty
                ? const _EmptyState(
                    icon: Icons.inventory_2_outlined,
                    title: 'Sem produtos encontrados',
                    message: 'Ajuste os filtros ou cadastre um novo produto.',
                  )
                : ListView.separated(
                    itemCount: products.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final product = products[index];
                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: <Widget>[
                                        Text(
                                          product.nome,
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleMedium
                                              ?.copyWith(fontWeight: FontWeight.w700),
                                        ),
                                        const SizedBox(height: 6),
                                        Wrap(
                                          spacing: 8,
                                          runSpacing: 8,
                                          children: <Widget>[
                                            _TagChip(label: product.categoria),
                                            _TagChip(
                                              label: 'Stock: ${product.stock}',
                                              color: product.stock <= 5
                                                  ? const Color(0xFFFFE1D6)
                                                  : const Color(0xFFECECEC),
                                            ),
                                            if ((product.codigoBarras ?? '').isNotEmpty)
                                              _TagChip(
                                                label: 'Cod: ${product.codigoBarras}',
                                              ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  PopupMenuButton<String>(
                                    onSelected: (value) {
                                      if (value == 'edit') {
                                        widget.onEdit(product);
                                      } else {
                                        widget.onDelete(product);
                                      }
                                    },
                                    itemBuilder: (context) => const <PopupMenuEntry<String>>[
                                      PopupMenuItem<String>(
                                        value: 'edit',
                                        child: Text('Editar'),
                                      ),
                                      PopupMenuItem<String>(
                                        value: 'delete',
                                        child: Text('Excluir'),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: <Widget>[
                                  Expanded(
                                    child: Text(
                                      'Preco: ${currencyFormat.format(product.preco)}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    product.ultimaAtualizacao == null
                                        ? 'Sem atualizacao'
                                        : 'Atualizado: ${dateTimeFormat.format(product.ultimaAtualizacao!)}',
                                    style: Theme.of(context).textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class CheckoutTab extends StatefulWidget {
  const CheckoutTab({
    super.key,
    required this.controller,
    required this.onFinalizeSale,
    required this.onShowHistory,
    required this.onShowMessage,
  });

  final StoreController controller;
  final Future<void> Function() onFinalizeSale;
  final VoidCallback onShowHistory;
  final void Function(String message) onShowMessage;

  @override
  State<CheckoutTab> createState() => _CheckoutTabState();
}

class _CheckoutTabState extends State<CheckoutTab> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filteredProducts = widget.controller.products.where((product) {
