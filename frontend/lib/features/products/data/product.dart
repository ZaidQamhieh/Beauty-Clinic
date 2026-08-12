class Product {
  const Product({
    required this.id,
    required this.brand,
    required this.productType,
    required this.category,
    required this.stockQuantity,
    required this.ingredients,
  });

  static const brands = [
    'CERAVE',
    'LA_ROCHE_POSAY',
    'SKINCEUTICALS',
    'OBAGI',
    'ZO_SKIN_HEALTH',
    'BIODERMA',
    'AVENE',
  ];
  static const types = [
    'CLEANSER',
    'MOISTURIZER',
    'SERUM',
    'SUNSCREEN',
    'TONER',
    'EXFOLIANT',
    'MASK',
    'RETINOID',
  ];
  static const ingredientOptions = [
    'RETINOL',
    'NIACINAMIDE',
    'SALICYLIC_ACID',
    'HYALURONIC_ACID',
    'VITAMIN_C',
    'GLYCOLIC_ACID',
    'BENZOYL_PEROXIDE',
    'AZELAIC_ACID',
    'CERAMIDES',
    'ZINC_OXIDE',
  ];

  final String id;
  final String brand;
  final String productType;
  final String category;
  final int stockQuantity;
  final List<String> ingredients;

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'] as String,
      brand: json['brand'] as String,
      productType: json['productType'] as String,
      category: json['category'] as String,
      stockQuantity: json['stockQuantity'] as int,
      ingredients: List<String>.from(json['ingredients'] as List),
    );
  }

  String get brandLabel => label(brand);
  String get typeLabel => label(productType);

  static String label(String value) {
    return value
        .split('_')
        .map((word) => '${word[0]}${word.substring(1).toLowerCase()}')
        .join(' ');
  }
}

class ProductInput {
  const ProductInput({
    required this.brand,
    required this.productType,
    required this.category,
    required this.stockQuantity,
    required this.ingredients,
  });

  final String brand;
  final String productType;
  final String category;
  final int stockQuantity;
  final List<String> ingredients;

  Map<String, dynamic> toJson() => {
    'brand': brand,
    'productType': productType,
    'category': category,
    'stockQuantity': stockQuantity,
    'ingredients': ingredients,
  };
}
