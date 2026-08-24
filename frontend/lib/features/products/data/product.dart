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
  static const ingredientsByType = <String, List<String>>{
    'CLEANSER': ['CERAMIDES', 'SALICYLIC_ACID'],
    'MOISTURIZER': ['HYALURONIC_ACID', 'CERAMIDES'],
    'SERUM': ['VITAMIN_C', 'NIACINAMIDE'],
    'SUNSCREEN': ['ZINC_OXIDE'],
    'TONER': ['NIACINAMIDE', 'GLYCOLIC_ACID'],
    'EXFOLIANT': ['GLYCOLIC_ACID', 'SALICYLIC_ACID'],
    'MASK': ['HYALURONIC_ACID', 'NIACINAMIDE'],
    'RETINOID': ['RETINOL'],
  };

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

class PatientProductRecord {
  const PatientProductRecord({
    required this.id,
    required this.productId,
    required this.brand,
    required this.productType,
    required this.source,
    this.startedOn,
    this.discontinuedOn,
  });

  final String id;
  final String productId;
  final String brand;
  final String productType;
  final String source;
  final String? startedOn;
  final String? discontinuedOn;

  factory PatientProductRecord.fromJson(Map<String, dynamic> json) {
    return PatientProductRecord(
      id: json['id'].toString(),
      productId: json['productId'].toString(),
      brand: json['brand'].toString(),
      productType: json['productType'].toString(),
      source: json['source'].toString(),
      startedOn: json['startedOn']?.toString(),
      discontinuedOn: json['discontinuedOn']?.toString(),
    );
  }
}
