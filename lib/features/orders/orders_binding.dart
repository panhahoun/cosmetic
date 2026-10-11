import 'package:get/get.dart';

import 'orders_controller.dart';

class OrdersBinding implements Bindings {
  @override
  void dependencies() {
    Get.lazyPut(() => OrdersController());
  }
}
