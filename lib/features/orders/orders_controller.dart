import 'package:get/get.dart';

import '../../core/storage/session_store.dart';
import '../../data/orders_service_dio.dart';
import '../../models/order_model.dart';

class OrdersController extends GetxController {
  OrdersController({OrdersService? service})
    : _service = service ?? OrdersServiceDio();

  final OrdersService _service;

  final orders = <Order>[].obs;
  final isLoading = false.obs;
  final hasError = false.obs;

  @override
  void onInit() {
    super.onInit();
    reload();
  }

  Future<void> reload() async {
    final userId = await sessionStore.currentUserId() ?? 0;
    if (userId <= 0) {
      orders.clear();
      return;
    }
    isLoading.value = true;
    hasError.value = false;
    try {
      final list = await _service.getOrders();
      orders.assignAll(list);
    } on OrdersException catch (e) {
      if (e.isUnauthorized) {
        orders.clear();
      } else {
        hasError.value = true;
      }
    } catch (_) {
      hasError.value = true;
    } finally {
      isLoading.value = false;
    }
  }
}
