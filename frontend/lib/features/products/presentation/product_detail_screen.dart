import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/skeleton.dart';
import '../data/product.dart';

typedef ProductLoader = Future<Product> Function(String id);

class ProductDetailScreen extends StatefulWidget {
  const ProductDetailScreen({
    super.key,
    required this.productId,
    required this.loadProduct,
    this.onBack,
  });

  final String productId;
  final ProductLoader loadProduct;
  final VoidCallback? onBack;

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  late Future<Product> _product;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _product = widget.loadProduct(widget.productId);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Product>(
      future: _product,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const SkeletonDetail(lineCount: 3);
        }
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 40),
                const SizedBox(height: 12),
                const Text('Unable to load product.'),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () => setState(_load),
                  child: const Text('Try again'),
                ),
              ],
            ),
          );
        }
        return _details(snapshot.requireData);
      },
    );
  }

  Widget _details(Product product) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.onBack != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: TextButton.icon(
                onPressed: widget.onBack,
                icon: const Icon(Icons.arrow_back, size: 16),
                label: const Text('Back to Products'),
              ),
            ),
          SizedBox(
            width: double.infinity,
            child: Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.spa_outlined,
                      color: AppColors.rose,
                      size: 36,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '${product.brandLabel} ${product.typeLabel}',
                      style: AppTypography.displayTitle(),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${product.category} • ${product.stockQuantity} in stock',
                      style: AppTypography.bodyMedium(
                        color: AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text('Ingredients', style: AppTypography.labelLarge()),
                    const SizedBox(height: 12),
                    if (product.ingredients.isEmpty)
                      const Text('No ingredients listed.')
                    else
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: product.ingredients
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
        ],
      ),
    );
  }
}
