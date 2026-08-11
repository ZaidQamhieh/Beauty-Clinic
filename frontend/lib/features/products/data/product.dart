class Product {
  const Product({
    required this.id,
    required this.brand,
    required this.productType,
    required this.ingredients,
  });

  final String id;
  final String brand;
  final String productType;
  final List<String> ingredients;

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'] as String,
      brand: json['brand'] as String,
      productType: json['productType'] as String,
      ingredients: List<String>.from(json['ingredients'] as List),
    );
  }

  String get brandLabel => _label(brand);
  String get typeLabel => _label(productType);

  static String labelIngredient(String ingredient) => _label(ingredient);

  static String _label(String value) {
    return value
        .split('_')
        .map((word) => '${word[0]}${word.substring(1).toLowerCase()}')
        .join(' ');
  }
}
