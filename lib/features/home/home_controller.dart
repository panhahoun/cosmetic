import 'package:get/get.dart';

import '../../models/product_model.dart';
import '../../data/product_service.dart';

class HomeController extends GetxController {
  final ProductService _productService = ProductService();

  final products = <Product>[].obs;
  final isLoading = false.obs;
  final selectedCategory = 'All'.obs;
  final searchQuery = ''.obs;

  @override
  void onInit() {
    super.onInit();
    loadProducts();
  }

  Future<void> loadProducts() async {
    isLoading.value = true;
    try {
      final list = await _productService.getProducts();
      products.assignAll(list);
    } finally {
      isLoading.value = false;
    }
  }

  List<Product> get filteredProducts {
    var list = products.toList();
    if (searchQuery.value.isNotEmpty) {
      list = list.where((p) {
        return p.name.toLowerCase().contains(searchQuery.value.toLowerCase()) ||
            p.brand.toLowerCase().contains(searchQuery.value.toLowerCase()) ||
            p.categoryName.toLowerCase().contains(searchQuery.value.toLowerCase());
      }).toList();
    }
    if (selectedCategory.value != 'All') {
      list = list.where((p) => p.categoryName == selectedCategory.value).toList();
    }
    return list;
  }

  List<String> get categories {
    final set = <String>{'All'};
    for (final p in products) {
      if (p.categoryName.isNotEmpty) set.add(p.categoryName);
    }
    return set.toList()..sort((a, b) => a.compareTo(b));
  }

  void setCategory(String c) => selectedCategory.value = c;
  void setSearch(String q) => searchQuery.value = q;
}
