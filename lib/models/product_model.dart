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
      id: int.parse(json['id'].toString()),
      name: json['name'],
      description: json['description'] ?? "",
      price: double.parse(json['price'].toString()),
      image: json['image'] ?? "",
      categoryName: (json['category_name'] ?? json['category'] ?? "General")
          .toString(),
      brand: (json['brand'] ?? "GlowLab").toString(),
      rating: double.tryParse((json['rating'] ?? "4.5").toString()) ?? 4.5,
      reviewCount: int.tryParse((json['review_count'] ?? "0").toString()) ?? 0,
      stock: int.tryParse((json['stock'] ?? "0").toString()) ?? 0,
      size: (json['size'] ?? "50ml").toString(),
    );
  }
}
