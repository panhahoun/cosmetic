class Product {
  final int id;
  final String name;
  final String description;
  final double price;
  final String image;
  final String categoryName;
  final String brand;
  final double rating;
  final int reviewCount;
  final int stock;
  final String size;

  Product({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.image,
    required this.categoryName,
    required this.brand,
    required this.rating,
    required this.reviewCount,
    required this.stock,
    required this.size,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: int.tryParse(json['id']?.toString() ?? '') ?? 0,
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      price: double.tryParse(json['price']?.toString() ?? '') ?? 0,
      image: json['image']?.toString() ?? '',
      categoryName: (json['category_name'] ?? json['category'] ?? '')
          .toString(),
      // No fabricated fallbacks: missing brand/rating stay empty and 0.
      brand: (json['brand'] ?? '').toString(),
      rating: double.tryParse(json['rating']?.toString() ?? '') ?? 0,
      reviewCount: int.tryParse(json['review_count']?.toString() ?? '') ?? 0,
      stock: int.tryParse(json['stock']?.toString() ?? '') ?? 0,
      size: (json['size'] ?? '').toString(),
    );
  }
}
