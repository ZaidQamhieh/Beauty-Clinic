import '../../../core/widgets/app_search_field.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/validation/field_rules.dart';
import '../../../core/widgets/app_dropdown.dart';
import '../../../core/widgets/skeleton.dart';
import '../data/product.dart';
import '../data/product_api.dart';
import 'product_detail_screen.dart';
import 'widgets/facet_menu_button.dart';

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
  List<Product> _items = const [];
  bool _loading = true;
  bool _failed = false;

  final Set<String> _types = {};
  final Set<String> _brands = {};
  final Set<String> _ingredients = {};
  final Set<String> _stock = {};
  String _query = '';

  static const _stockLabels = {
    'IN': 'In stock',
    'LOW': 'Low stock',
    'OUT': 'Out of stock',
  };

  // Ten or fewer left reads as low.
  static String _stockBand(Product product) {
    if (product.stockQuantity <= 0) return 'OUT';
    if (product.stockQuantity <= 10) return 'LOW';
    return 'IN';
  }

  List<Product> get _visibleItems {
    final query = _query.toLowerCase();
    return _items.where((product) {
      if (_types.isNotEmpty && !_types.contains(product.productType)) {
        return false;
      }
      if (_brands.isNotEmpty && !_brands.contains(product.brand)) return false;
      if (_ingredients.isNotEmpty &&
          !product.ingredients.any(_ingredients.contains)) {
        return false;
      }
      if (_stock.isNotEmpty && !_stock.contains(_stockBand(product))) {
        return false;
      }
      if (query.isEmpty) return true;
      return product.name.toLowerCase().contains(query) ||
          product.brandLabel.toLowerCase().contains(query) ||
          product.typeLabel.toLowerCase().contains(query);
    }).toList();
  }

  Map<String, int> _countsBy(String Function(Product) valueOf) {
    final counts = <String, int>{};
    for (final product in _items) {
      counts.update(valueOf(product), (value) => value + 1, ifAbsent: () => 1);
    }
    final sorted = counts.keys.toList()..sort();
    return {for (final key in sorted) key: counts[key]!};
  }

  Map<String, int> get _ingredientCounts {
    final counts = <String, int>{};
    for (final product in _items) {
      for (final ingredient in product.ingredients) {
        counts.update(ingredient, (value) => value + 1, ifAbsent: () => 1);
      }
    }
    final sorted = counts.keys.toList()..sort();
    return {for (final key in sorted) key: counts[key]!};
  }

  void _toggle(Set<String> facet, String value) {
    setState(() {
      if (!facet.remove(value)) facet.add(value);
    });
  }

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final products = await widget.api.list();
      if (!mounted) return;
      setState(() {
        _items = products;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _failed = true;
      });
    }
  }

  Future<void> _edit([Product? product]) async {
    final input = await showDialog<ProductInput>(
      context: context,
      builder: (_) => _ProductForm(product: product),
    );
    if (input == null) return;

    final previous = _items;
    // Shows the edit now; server confirms after.
    final optimistic = Product(
      id: product?.id ?? 'pending-${DateTime.now().microsecondsSinceEpoch}',
      name: input.name,
      brand: input.brand,
      productType: input.productType,
      imageUrl: input.imageUrl,
      stockQuantity: input.stockQuantity,
      ingredients: input.ingredients,
    );
    setState(() {
      _items = product == null
          ? [..._items, optimistic]
          : [
              for (final current in _items)
                if (current.id == product.id) optimistic else current,
            ];
    });

    try {
      final saved = product == null
          ? await widget.api.create(input)
          : await widget.api.update(product.id, input);
      if (!mounted) return;
      setState(() {
        _items = [
          for (final current in _items)
            if (current.id == optimistic.id) saved else current,
        ];
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _items = previous);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Unable to save product.')));
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

    final previous = _items;
    setState(() {
      _items = [
        for (final current in _items)
          if (current.id != product.id) current,
      ];
    });

    try {
      await widget.api.delete(product.id);
    } catch (_) {
      if (!mounted) return;
      // Nothing was deleted; put it back.
      setState(() => _items = previous);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to delete product.')),
      );
    }
  }

  Widget _filterBar() {
    final stockCounts = _countsBy(_stockBand);
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: 250,
          child: AppSearchField(
            hintText: 'Search products',
            onChanged: (value) => setState(() => _query = value.trim()),
          ),
        ),
        FacetMenuButton(
          label: 'Type',
          counts: _countsBy((product) => product.productType),
          selected: _types,
          labelFor: Product.label,
          onToggle: (value) => _toggle(_types, value),
          onClear: () => setState(_types.clear),
        ),
        FacetMenuButton(
          label: 'Brand',
          counts: _countsBy((product) => product.brand),
          selected: _brands,
          labelFor: Product.label,
          onToggle: (value) => _toggle(_brands, value),
          onClear: () => setState(_brands.clear),
        ),
        FacetMenuButton(
          label: 'Ingredient',
          counts: _ingredientCounts,
          selected: _ingredients,
          labelFor: Product.label,
          onToggle: (value) => _toggle(_ingredients, value),
          onClear: () => setState(_ingredients.clear),
        ),
        FacetMenuButton(
          label: 'Stock',
          counts: stockCounts,
          selected: _stock,
          labelFor: (value) => _stockLabels[value] ?? value,
          onToggle: (value) => _toggle(_stock, value),
          onClear: () => setState(_stock.clear),
        ),
        if (_types.isNotEmpty ||
            _brands.isNotEmpty ||
            _ingredients.isNotEmpty ||
            _stock.isNotEmpty)
          TextButton.icon(
            onPressed: () => setState(() {
              _types.clear();
              _brands.clear();
              _ingredients.clear();
              _stock.clear();
            }),
            icon: const Icon(Icons.close, size: 14),
            label: const Text('Clear filters'),
          ),
        Text(
          '${_visibleItems.length} of ${_items.length}',
          style: AppTypography.bodySmall(),
        ),
      ],
    );
  }

  void _open(Product product) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        content: SizedBox(
          width: 600,
          child: ProductDetailScreen(
            productId: product.id,
            loadProduct: widget.api.getById,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
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
          const SizedBox(height: 16),
          _filterBar(),
          const SizedBox(height: 16),
          Expanded(
            child: Builder(
              builder: (context) {
                if (_loading) {
                  return const SkeletonGrid();
                }
                if (_failed) {
                  return Center(
                    child: OutlinedButton(
                      onPressed: _reload,
                      child: const Text('Unable to load products. Try again'),
                    ),
                  );
                }
                if (_items.isEmpty) {
                  return const Center(child: Text('No products yet.'));
                }
                final products = _visibleItems;
                if (products.isEmpty) {
                  return Center(
                    child: Text(
                      'No products match these filters.',
                      style: AppTypography.bodySmall(),
                    ),
                  );
                }
                return ListView.builder(
                  itemCount: products.length,
                  itemBuilder: (_, index) {
                    final product = products[index];
                    return Card(
                      child: ListTile(
                        leading: SizedBox(
                          width: 48,
                          height: 48,
                          child: product.imageUrl == null
                              ? const Icon(
                                  Icons.spa_outlined,
                                  color: AppColors.rose,
                                )
                              : ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.network(
                                    product.imageUrl!,
                                    fit: BoxFit.cover,
                                    filterQuality: FilterQuality.high,
                                    isAntiAlias: true,
                                    errorBuilder: (_, _, _) => const Icon(
                                      Icons.spa_outlined,
                                      color: AppColors.rose,
                                    ),
                                  ),
                                ),
                        ),
                        title: Text(product.name),
                        subtitle: Text(
                          [
                            '${product.brandLabel} ${product.typeLabel} • ${product.stockQuantity} in stock',
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
  late final _name = TextEditingController(text: widget.product?.name);
  late final _imageUrl = TextEditingController(text: widget.product?.imageUrl);
  late final _stock = TextEditingController(
    text: '${widget.product?.stockQuantity ?? 0}',
  );
  late String _brand = widget.product?.brand ?? Product.brands.first;
  late String _type = widget.product?.productType ?? Product.types.first;
  List<String> get _ingredients => Product.ingredientsByType[_type] ?? const [];

  late final List<Object?> _initialSnapshot = _snapshot();

  List<Object?> _snapshot() => [
    _name.text,
    _imageUrl.text,
    _stock.text,
    _brand,
    _type,
  ];

  bool get _isDirty => !listEquals(_snapshot(), _initialSnapshot);

  @override
  void dispose() {
    _name.dispose();
    _imageUrl.dispose();
    _stock.dispose();
    super.dispose();
  }

  Widget _dropdown(
    String label,
    List<String> values,
    String value,
    ValueChanged<String> onChanged,
  ) {
    return AppDropdownField<String>(
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
        name: _name.text.trim(),
        brand: _brand,
        productType: _type,
        stockQuantity: int.parse(_stock.text),
        ingredients: _ingredients,
        imageUrl: _imageUrl.text.trim().isEmpty ? null : _imageUrl.text.trim(),
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
                TextFormField(
                  controller: _name,
                  decoration: const InputDecoration(labelText: 'Name'),
                  maxLength: 60,
                  validator: (value) => FieldRules.requiredText(value, 'Name'),
                ),
                TextFormField(
                  controller: _imageUrl,
                  decoration: const InputDecoration(
                    labelText: 'Image URL (optional)',
                  ),
                  maxLength: 2048,
                  validator: (value) =>
                      FieldRules.httpUrl(value, label: 'Image URL'),
                ),
                const SizedBox(height: 12),
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
                  controller: _stock,
                  decoration: const InputDecoration(
                    labelText: 'Stock quantity',
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) => FieldRules.nonNegativeInt(
                    value,
                    'Stock quantity',
                    max: 100000,
                  ),
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
        ListenableBuilder(
          listenable: Listenable.merge([_name, _imageUrl, _stock]),
          builder: (context, _) => ElevatedButton(
            onPressed: _isDirty ? _submit : null,
            child: const Text('Save'),
          ),
        ),
      ],
    );
  }
}
