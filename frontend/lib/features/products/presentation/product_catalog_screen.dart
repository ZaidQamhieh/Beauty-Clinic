import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../data/product.dart';
import '../data/product_api.dart';
import 'product_detail_screen.dart';

class ProductCatalogScreen extends StatefulWidget {
  const ProductCatalogScreen({
    super.key,
    required this.api,
    required this.canManage,
  });

  final ProductApi api;
  final bool canManage;

  @override
  State<ProductCatalogScreen> createState() => _ProductCatalogScreenState();
}

class _ProductCatalogScreenState extends State<ProductCatalogScreen> {
  late Future<List<Product>> _products = widget.api.list();

  void _reload() {
    setState(() {
      _products = widget.api.list();
    });
  }

  Future<void> _edit([Product? product]) async {
    final input = await showDialog<ProductInput>(
      context: context,
      builder: (_) => _ProductForm(product: product),
    );
    if (input == null) return;

    try {
      product == null
          ? await widget.api.create(input)
          : await widget.api.update(product.id, input);
      if (mounted) _reload();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to save product.')),
        );
      }
    }
  }

  Future<void> _delete(Product product) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete product?'),
        content: Text('Delete ${product.brandLabel} ${product.typeLabel}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await widget.api.delete(product.id);
      if (mounted) _reload();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to delete product.')),
        );
      }
    }
  }

  void _open(Product product) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          body: ProductDetailScreen(
            productId: product.id,
            loadProduct: widget.api.getById,
            onBack: () => Navigator.pop(context),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Products', style: AppTypography.displayTitle()),
              ),
              if (widget.canManage)
                ElevatedButton.icon(
                  onPressed: _edit,
                  icon: const Icon(Icons.add),
                  label: const Text('Add Product'),
                ),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: FutureBuilder<List<Product>>(
              future: _products,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: OutlinedButton(
                      onPressed: _reload,
                      child: const Text('Unable to load products. Try again'),
                    ),
                  );
                }
                final products = snapshot.requireData;
                if (products.isEmpty) {
                  return const Center(child: Text('No products yet.'));
                }
                return ListView.builder(
                  itemCount: products.length,
                  itemBuilder: (_, index) {
                    final product = products[index];
                    return Card(
                      child: ListTile(
                        leading: const Icon(
                          Icons.spa_outlined,
                          color: AppColors.rose,
                        ),
                        title: Text(
                          '${product.brandLabel} ${product.typeLabel}',
                        ),
                        subtitle: Text(
                          [
                            '${product.category} • ${product.stockQuantity} in stock',
                            if (product.ingredients.isNotEmpty)
                              'Ingredients: ${product.ingredients.map(Product.label).join(', ')}',
                          ].join('\n'),
                        ),
                        trailing: widget.canManage
                            ? Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    tooltip: 'Edit product',
                                    onPressed: () => _edit(product),
                                    icon: const Icon(Icons.edit_outlined),
                                  ),
                                  IconButton(
                                    tooltip: 'Delete product',
                                    onPressed: () => _delete(product),
                                    icon: const Icon(Icons.delete_outline),
                                  ),
                                ],
                              )
                            : const Icon(Icons.chevron_right),
                        onTap: () => _open(product),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductForm extends StatefulWidget {
  const _ProductForm({this.product});

  final Product? product;

  @override
  State<_ProductForm> createState() => _ProductFormState();
}

class _ProductFormState extends State<_ProductForm> {
  final _formKey = GlobalKey<FormState>();
  late final _category = TextEditingController(text: widget.product?.category);
  late final _stock = TextEditingController(
    text: '${widget.product?.stockQuantity ?? 0}',
  );
  late String _brand = widget.product?.brand ?? Product.brands.first;
  late String _type = widget.product?.productType ?? Product.types.first;
  List<String> get _ingredients => Product.ingredientsByType[_type] ?? const [];

  @override
  void dispose() {
    _category.dispose();
    _stock.dispose();
    super.dispose();
  }

  Widget _dropdown(
    String label,
    List<String> values,
    String value,
    ValueChanged<String> onChanged,
  ) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      decoration: InputDecoration(labelText: label),
      items: values
          .map(
            (item) =>
                DropdownMenuItem(value: item, child: Text(Product.label(item))),
          )
          .toList(),
      onChanged: (item) => onChanged(item!),
    );
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(
      context,
      ProductInput(
        brand: _brand,
        productType: _type,
        category: _category.text.trim(),
        stockQuantity: int.parse(_stock.text),
        ingredients: _ingredients,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.product == null ? 'Add Product' : 'Edit Product'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _dropdown(
                  'Brand',
                  Product.brands,
                  _brand,
                  (value) => _brand = value,
                ),
                const SizedBox(height: 12),
                _dropdown(
                  'Product type',
                  Product.types,
                  _type,
                  (value) => setState(() => _type = value),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _category,
                  decoration: const InputDecoration(labelText: 'Category'),
                  maxLength: 60,
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Enter a category'
                      : null,
                ),
                TextFormField(
                  controller: _stock,
                  decoration: const InputDecoration(
                    labelText: 'Stock quantity',
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    final stock = int.tryParse(value ?? '');
                    return stock == null || stock < 0
                        ? 'Enter a non-negative number'
                        : null;
                  },
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 6,
                  children: _ingredients
                      .map(
                        (ingredient) =>
                            Chip(label: Text(Product.label(ingredient))),
                      )
                      .toList(),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(onPressed: _submit, child: const Text('Save')),
      ],
    );
  }
}
