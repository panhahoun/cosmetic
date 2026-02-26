class Product {
  final int id;
  final String name;
  final String description;
  final double price;
  final String image;
  final String categoryName;

  Product({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.image,
    required this.categoryName,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: int.parse(json['id'].toString()),
      name: json['name'],
      description: json['description'] ?? "",
      price: double.parse(json['price'].toString()),
      image: json['image'] ?? "",
      categoryName: json['category_name'] ?? "",
    );
  }
}