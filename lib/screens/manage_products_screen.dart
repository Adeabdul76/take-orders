import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import '../models/product.dart';
import '../providers/product_provider.dart';
import '../providers/settings_provider.dart';
import '../utils/money.dart';
import '../widgets/product_card.dart';

class ManageProductsScreen extends StatefulWidget {
  const ManageProductsScreen({super.key});

  @override
  State<ManageProductsScreen> createState() => _ManageProductsScreenState();
}

class _ManageProductsScreenState extends State<ManageProductsScreen> {
  String _search = '';

  void _openForm([Product? product]) => Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => ProductFormScreen(product: product)),
  );

  Future<void> _confirmDelete(Product product) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete "${product.name}"?'),
        content: const Text('Old orders will still show this item.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      await context.read<ProductProvider>().delete(product);
    }
  }

  @override
  Widget build(BuildContext context) {
    final products = context.watch<ProductProvider>();
    final currency = context.watch<SettingsProvider>().currency;
    final q = _search.toLowerCase();
    final list = products.products
        .where(
          (p) =>
              q.isEmpty ||
              p.name.toLowerCase().contains(q) ||
              p.category.toLowerCase().contains(q),
        )
        .toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Manage products')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        icon: const Icon(Icons.add),
        label: const Text('Add product', style: TextStyle(fontSize: 18)),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              style: const TextStyle(fontSize: 18),
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Search products',
              ),
              onChanged: (v) => setState(() => _search = v),
            ),
          ),
          Expanded(
            child: products.products.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'No products yet.\nTap "Add product" to add your first item.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 18),
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.only(bottom: 96),
                    itemCount: list.length,
                    itemBuilder: (_, i) {
                      final prod = list[i];
                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        child: ListTile(
                          minVerticalPadding: 12,
                          leading: ProductImage(product: prod, size: 52),
                          title: Text(
                            prod.name,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: prod.available ? null : Colors.grey,
                            ),
                          ),
                          subtitle: Text(
                            '${formatMoney(prod.priceCents, currency)}'
                            '${prod.category.isEmpty ? '' : ' · ${prod.category}'}'
                            '${prod.available ? '' : ' · Not available'}',
                            style: const TextStyle(fontSize: 15),
                          ),
                          onTap: () => _openForm(prod),
                          trailing: PopupMenuButton<String>(
                            onSelected: (v) {
                              switch (v) {
                                case 'edit':
                                  _openForm(prod);
                                case 'toggle':
                                  products.setAvailable(prod, !prod.available);
                                case 'duplicate':
                                  products.duplicate(prod);
                                case 'delete':
                                  _confirmDelete(prod);
                              }
                            },
                            itemBuilder: (_) => [
                              const PopupMenuItem(
                                value: 'edit',
                                child: Text('Edit / change price'),
                              ),
                              PopupMenuItem(
                                value: 'toggle',
                                child: Text(
                                  prod.available
                                      ? 'Mark not available'
                                      : 'Mark available',
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'duplicate',
                                child: Text('Duplicate'),
                              ),
                              const PopupMenuItem(
                                value: 'delete',
                                child: Text(
                                  'Delete',
                                  style: TextStyle(color: Colors.red),
                                ),
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

const _cafeEmojis = [
  '☕',
  '🍵',
  '🧋',
  '🥤',
  '🧃',
  '🥛',
  '🍹',
  '🧊',
  '🍚',
  '🍛',
  '🍜',
  '🍝',
  '🍳',
  '🥚',
  '🍗',
  '🍖',
  '🥪',
  '🍞',
  '🥐',
  '🧇',
  '🥞',
  '🍰',
  '🍩',
  '🍪',
  '🍌',
  '🥭',
  '🍉',
  '🌶️',
  '🥟',
  '🍢',
  '🥗',
  '🍲',
];

/// Add or edit a product.
class ProductFormScreen extends StatefulWidget {
  final Product? product;
  const ProductFormScreen({super.key, this.product});

  @override
  State<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends State<ProductFormScreen> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _price;
  late final TextEditingController _category;
  String? _imagePath;
  String? _emoji;
  late bool _available;
  bool _saving = false;

  bool get _isEdit => widget.product != null;

  @override
  void initState() {
    super.initState();
    final p0 = widget.product;
    _name = TextEditingController(text: p0?.name ?? '');
    _price = TextEditingController(
      text: p0 == null ? '' : (p0.priceCents / 100).toStringAsFixed(2),
    );
    _category = TextEditingController(text: p0?.category ?? '');
    _imagePath = p0?.imagePath;
    _emoji = p0?.emoji;
    _available = p0?.available ?? true;
  }

  @override
  void dispose() {
    _name.dispose();
    _price.dispose();
    _category.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 600,
        imageQuality: 80,
      );
      if (picked == null) return;
      final dir = await getApplicationDocumentsDirectory();
      final dest = p.join(
        dir.path,
        'product_${DateTime.now().millisecondsSinceEpoch}${p.extension(picked.path)}',
      );
      await File(picked.path).copy(dest);
      setState(() {
        _imagePath = dest;
        _emoji = null;
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not open the photo. Please allow photo access.'),
        ),
      );
    }
  }

  Future<void> _save() async {
    if (_saving || !_form.currentState!.validate()) return;
    setState(() => _saving = true);
    final provider = context.read<ProductProvider>();
    final product = Product(
      id: widget.product?.id,
      name: _name.text.trim(),
      priceCents: parseMoneyToCents(_price.text)!,
      category: _category.text.trim(),
      imagePath: _imagePath,
      emoji: _imagePath == null ? _emoji : null,
      available: _available,
    );
    if (_isEdit) {
      await provider.update(product);
    } else {
      await provider.add(product);
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final currency = context.watch<SettingsProvider>().currency;
    final categories = context.watch<ProductProvider>().categories;
    final preview = Product(
      name: _name.text.isEmpty ? '?' : _name.text,
      priceCents: 0,
      imagePath: _imagePath,
      emoji: _emoji,
    );
    const gap = SizedBox(height: 16);

    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? 'Edit product' : 'Add product')),
      body: SafeArea(
        child: Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TextFormField(
                controller: _name,
                textCapitalization: TextCapitalization.words,
                style: const TextStyle(fontSize: 18),
                decoration: const InputDecoration(labelText: 'Name *'),
                onChanged: (_) => setState(() {}),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Please type a name'
                    : null,
              ),
              gap,
              TextFormField(
                controller: _price,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                style: const TextStyle(fontSize: 18),
                decoration: InputDecoration(
                  labelText: 'Price ($currency) *',
                  hintText: 'e.g. 8.50',
                ),
                validator: (v) {
                  final cents = parseMoneyToCents(v ?? '');
                  if (cents == null) return 'Please type a price, e.g. 8.50';
                  if (cents <= 0) return 'Price must be more than 0';
                  return null;
                },
              ),
              if (_isEdit)
                const Padding(
                  padding: EdgeInsets.only(top: 6),
                  child: Text(
                    'Changing the price does not change old orders.',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              gap,
              TextFormField(
                controller: _category,
                textCapitalization: TextCapitalization.words,
                style: const TextStyle(fontSize: 18),
                decoration: const InputDecoration(
                  labelText: 'Category (optional)',
                  hintText: 'Type a new one, e.g. Drinks',
                ),
                onChanged: (_) => setState(() {}),
              ),
              if (categories.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    for (final c in categories)
                      ChoiceChip(
                        label: Text(c),
                        selected: _category.text.trim() == c,
                        onSelected: (_) => setState(() => _category.text = c),
                      ),
                  ],
                ),
              ],
              gap,
              const Text(
                'Picture',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  ProductImage(product: preview, size: 72),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickImage,
                      icon: const Icon(Icons.photo_library),
                      label: const Text('From gallery'),
                    ),
                  ),
                  if (_imagePath != null || _emoji != null)
                    IconButton(
                      tooltip: 'Remove picture',
                      onPressed: () => setState(() {
                        _imagePath = null;
                        _emoji = null;
                      }),
                      icon: const Icon(Icons.close),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              const Text('Or choose an emoji:'),
              const SizedBox(height: 4),
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: [
                  for (final e in _cafeEmojis)
                    InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () => setState(() {
                        _emoji = e;
                        _imagePath = null;
                      }),
                      child: Container(
                        width: 48,
                        height: 48,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: _emoji == e
                                ? Theme.of(context).colorScheme.primary
                                : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        child: Text(e, style: const TextStyle(fontSize: 26)),
                      ),
                    ),
                ],
              ),
              gap,
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Available', style: TextStyle(fontSize: 18)),
                subtitle: const Text('Turn off to hide it when sold out'),
                value: _available,
                onChanged: (v) => setState(() => _available = v),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: const Icon(Icons.check),
                label: Text(_isEdit ? 'Save changes' : 'Add product'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
