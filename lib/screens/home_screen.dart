import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/cart_provider.dart';
import '../providers/order_provider.dart';
import '../providers/product_provider.dart';
import '../providers/settings_provider.dart';
import '../utils/money.dart';
import '../widgets/printer_status_banner.dart';
import '../widgets/product_card.dart';
import 'cart_screen.dart';
import 'manage_products_screen.dart';
import 'orders_screen.dart';
import 'printer_settings_screen.dart';
import 'setup_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String? _category; // null = All

  void _open(Widget screen) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final products = context.watch<ProductProvider>();
    final cart = context.watch<CartProvider>();
    final orders = context.watch<OrderProvider>();
    final currency = settings.currency;

    final categories = products.categories;
    if (_category != null && !categories.contains(_category)) _category = null;
    final visible = products.availableProducts
        .where((p) => _category == null || p.category == _category)
        .toList();

    return PrinterDisconnectListener(
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            settings.shopName.isEmpty ? 'Take Orders' : settings.shopName,
          ),
          actions: [
            const PrinterIconButton(),
            PopupMenuButton<String>(
              iconSize: 28,
              onSelected: (v) {
                switch (v) {
                  case 'orders':
                    _open(const OrdersScreen());
                  case 'products':
                    _open(const ManageProductsScreen());
                  case 'printer':
                    _open(const PrinterSettingsScreen());
                  case 'shop':
                    _open(const SetupScreen());
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: 'orders',
                  child: ListTile(
                    leading: Icon(Icons.receipt_long),
                    title: Text('Orders'),
                  ),
                ),
                PopupMenuItem(
                  value: 'products',
                  child: ListTile(
                    leading: Icon(Icons.inventory_2),
                    title: Text('Manage products'),
                  ),
                ),
                PopupMenuItem(
                  value: 'printer',
                  child: ListTile(
                    leading: Icon(Icons.print),
                    title: Text('Printer settings'),
                  ),
                ),
                PopupMenuItem(
                  value: 'shop',
                  child: ListTile(
                    leading: Icon(Icons.store),
                    title: Text('Shop settings'),
                  ),
                ),
              ],
            ),
          ],
        ),
        body: Column(
          children: [
            const PrinterStatusBanner(),
            // Today's sales
            InkWell(
              onTap: () => _open(const OrdersScreen()),
              child: Container(
                width: double.infinity,
                color: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    const Icon(Icons.today),
                    const SizedBox(width: 8),
                    const Text("Today's sales", style: TextStyle(fontSize: 16)),
                    const Spacer(),
                    Text(
                      '${formatMoney(orders.todayTotalCents, currency)}  '
                      '(${orders.todayCount} order${orders.todayCount == 1 ? '' : 's'})',
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (categories.isNotEmpty)
              SizedBox(
                height: 60,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  children: [
                    _chip(
                      'All',
                      _category == null,
                      () => setState(() => _category = null),
                    ),
                    for (final c in categories)
                      _chip(
                        c,
                        _category == c,
                        () => setState(() => _category = c),
                      ),
                  ],
                ),
              ),
            Expanded(
              child: products.products.isEmpty
                  ? _EmptyState(
                      onAdd: () => _open(const ManageProductsScreen()),
                    )
                  : visible.isEmpty
                  ? const Center(
                      child: Text(
                        'No available products here.',
                        style: TextStyle(fontSize: 16),
                      ),
                    )
                  : GridView.builder(
                      padding: const EdgeInsets.fromLTRB(12, 4, 12, 100),
                      gridDelegate:
                          const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 180,
                            mainAxisSpacing: 8,
                            crossAxisSpacing: 8,
                            childAspectRatio: 0.85,
                          ),
                      itemCount: visible.length,
                      itemBuilder: (_, i) {
                        final p = visible[i];
                        return ProductCard(
                          product: p,
                          currency: currency,
                          qtyInCart: cart.qtyOf(p),
                          onTap: () => cart.add(p),
                        );
                      },
                    ),
            ),
          ],
        ),
        bottomNavigationBar: cart.isEmpty
            ? null
            : SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(64),
                    ),
                    onPressed: () => _open(const CartScreen()),
                    child: Row(
                      children: [
                        const Icon(Icons.shopping_cart),
                        const SizedBox(width: 12),
                        Text(
                          '${cart.itemCount} item${cart.itemCount == 1 ? '' : 's'} - '
                          '${formatMoney(cart.totalCents, currency)}',
                        ),
                        const Spacer(),
                        const Text('View cart'),
                        const Icon(Icons.chevron_right),
                      ],
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  Widget _chip(String label, bool selected, VoidCallback onTap) => Padding(
    padding: const EdgeInsets.only(right: 8),
    child: ChoiceChip(
      label: Text(label, style: const TextStyle(fontSize: 16)),
      selected: selected,
      onSelected: (_) => onTap(),
    ),
  );
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.local_cafe_outlined, size: 72, color: Colors.grey),
            const SizedBox(height: 12),
            const Text(
              'No products yet',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Add your menu items and prices to start taking orders.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: const Text('Add products'),
            ),
          ],
        ),
      ),
    );
  }
}
