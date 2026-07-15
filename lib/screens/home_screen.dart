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
    _showMessage('Produto atualizado com sucesso.');
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
                    separatorBuilder: (context, index) => const SizedBox(height: 12),
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
      return product.nome.toLowerCase().contains(
            _searchController.text.trim().toLowerCase(),
          );
    }).toList()
      ..sort((a, b) => a.nome.compareTo(b.nome));

    final cartEntries = widget.controller.cartEntries;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        'Adicionar ao carrinho',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: widget.onShowHistory,
                      icon: const Icon(Icons.history),
                      label: const Text('Historico'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _searchController,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    hintText: 'Pesquisar para venda',
                    prefixIcon: Icon(Icons.search),
                  ),
                ),
                const SizedBox(height: 16),
                if (filteredProducts.isEmpty)
                  const _EmptyState(
                    icon: Icons.search_off,
                    title: 'Nenhum produto encontrado',
                    message: 'Tente outro termo para iniciar a venda.',
                  )
                else
                  ...filteredProducts.map(
                    (product) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Card(
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 4,
                          ),
                          title: Text(product.nome),
                          subtitle: Text(
                            '${product.categoria}  |  Stock: ${product.stock}',
                          ),
                          trailing: SizedBox(
                            width: 110,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Text('${currencyFormat.format(product.preco)}   '),
                                IconButton(
                                  icon: const Icon(Icons.add_shopping_cart, color: Color(0xFFFF7A00)),
                                  onPressed: () {
                                    widget.controller.addToCart(product);
                                    widget.onShowMessage('${product.nome} adicionado ao carrinho.');
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (cartEntries.isNotEmpty) ...[
          Card(
            color: const Color(0xFFF9F9F9),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Itens no Carrinho',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  ...cartEntries.map((entry) {
                    final product = entry.product;
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(product.nome),
                      subtitle: Text('${entry.quantity}x ${currencyFormat.format(product.preco)}'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline),
                            onPressed: () => widget.controller.decrementCartQuantity(product),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.red),
                            onPressed: () => widget.controller.removeFromCart(product),
                          ),
                        ],
                      ),
                    );
                  }),
                  const Divider(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.between,
                    children: [
                      const Text('Total:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      Text(
                        currencyFormat.format(widget.controller.cartTotal),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFFFF7A00)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      style: FilledButton.styleFrom(backgroundColor: const Color(0xFFFF7A00)),
                      onPressed: widget.onFinalizeSale,
                      child: const Text('Finalizar Venda'),
                    ),
                  )
                ],
              ),
            ),
          )
        ]
      ],
    );
  }
}

class _TagChip extends StatelessWidget {
  const _TagChip({
    required this.label,
    this.color,
  });

  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color ?? const Color(0xFFECECEC),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              textAlign: TextAlign.center,
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DrawerItem extends StatelessWidget {
  const _DrawerItem({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: selected ? const Color(0xFFFF7A00) : null),
      title: Text(
        label,
        style: TextStyle(
          color: selected ? const Color(0xFFFF7A00) : null,
          fontWeight: selected ? FontWeight.bold : null,
        ),
      ),
      selected: selected,
      selectedTileColor: const Color(0xFFFFE1D6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      onTap: onTap,
    );
  }
}

class _CartBadge extends StatelessWidget {
  const _CartBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    if (count == 0) {
      return const Icon(Icons.shopping_cart_outlined);
    }

    return Badge(
      label: Text('$count'),
      backgroundColor: const Color(0xFFFF7A00),
      child: const Icon(Icons.shopping_cart_outlined),
    );
  }
}
