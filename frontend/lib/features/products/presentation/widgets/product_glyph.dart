import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/product.dart';

/// Product photo, or a tinted stand-in.
class ProductGlyph extends StatelessWidget {
  const ProductGlyph({
    super.key,
    required this.product,
    required this.height,
    this.glyphSize = 34,
  });

  final Product product;
  final double height;
  final double glyphSize;

  // Tint follows the type, like session rows.
  static const _byType = {
    'CLEANSER': (Icons.water_drop_outlined, AppColors.sage, AppColors.bgSage),
    'MOISTURIZER': (Icons.spa_outlined, AppColors.sage, AppColors.bgSage),
    'SERUM': (Icons.science_outlined, AppColors.rose, AppColors.bgRose),
    'SUNSCREEN': (Icons.wb_sunny_outlined, AppColors.gold, AppColors.goldPale),
    'TONER': (Icons.opacity_outlined, AppColors.lav, AppColors.bgLavender),
    'EXFOLIANT': (Icons.grain_outlined, AppColors.gold, AppColors.goldPale),
    'MASK': (
      Icons.face_retouching_natural,
      AppColors.lav,
      AppColors.bgLavender,
    ),
    'RETINOID': (
      Icons.nightlight_outlined,
      AppColors.lav,
      AppColors.bgLavender,
    ),
  };

  @override
  Widget build(BuildContext context) {
    final tint =
        _byType[product.productType] ??
        (Icons.spa_outlined, AppColors.rose, AppColors.bgRose);
    final url = product.imageUrl?.trim();

    if (url != null && url.isNotEmpty) {
      return Container(
        height: height,
        width: double.infinity,
        color: tint.$3,
        alignment: Alignment.center,
        child: Image.network(
          url,
          height: height,
          width: double.infinity,
          fit: BoxFit.cover,
          filterQuality: FilterQuality.high,
          isAntiAlias: true,
          errorBuilder: (_, _, _) =>
              Icon(tint.$1, size: glyphSize, color: tint.$2),
        ),
      );
    }
    return _placeholder(tint);
  }

  Widget _placeholder((IconData, Color, Color) tint) {
    return Container(
      height: height,
      width: double.infinity,
      color: tint.$3,
      alignment: Alignment.center,
      child: Icon(tint.$1, size: glyphSize, color: tint.$2),
    );
  }
}
