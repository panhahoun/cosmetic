import 'package:get/get.dart';

import '../../config/app_settings.dart';
import '../../core/storage/session_store.dart';
import '../../data/address_service_dio.dart';
import '../../models/address_model.dart';

class AddressController extends GetxController {
  AddressController({AddressService? service})
    : _service = service ?? AddressServiceDio();

  final AddressService _service;

  final addresses = <Address>[].obs;
  final isLoading = false.obs;
  final isSaving = false.obs;
  final sessionExpired = false.obs;

  AppSettings get settings => AppSettings.instance;
  String tr(String key) => settings.t(key);

  @override
  void onInit() {
    super.onInit();
    reload();
  }

  Future<void> reload() async {
    final userId = await sessionStore.currentUserId() ?? 0;
    if (userId <= 0) {
      addresses.clear();
      sessionExpired.value = true;
      return;
    }
    isLoading.value = true;
    sessionExpired.value = false;
    try {
      addresses.assignAll(await _service.getAddresses());
    } on AddressException catch (e) {
      if (e.isUnauthorized) {
        sessionExpired.value = true;
        addresses.clear();
      }
    } finally {
      isLoading.value = false;
    }
  }

  Future<bool> addAddress({
    required String fullName,
    required String phone,
    required String addressLine,
    String? city,
    String? postalCode,
    bool isDefault = false,
  }) async {
    isSaving.value = true;
    try {
      await _service.addAddress(
        fullName: fullName,
        phone: phone,
        addressLine: addressLine,
        city: city,
        postalCode: postalCode,
        isDefault: isDefault,
      );
      await reload();
      Get.snackbar(
        tr('shipping_address'),
        tr('address_saved'),
        snackPosition: SnackPosition.BOTTOM,
      );
      return true;
    } on AddressException catch (e) {
      Get.snackbar(
        tr('shipping_address'),
        e.isUnauthorized ? tr('please_login_again') : e.message,
        snackPosition: SnackPosition.BOTTOM,
      );
      return false;
    } finally {
      isSaving.value = false;
    }
  }

  Future<void> setDefault(int addressId) async {
    try {
      await _service.setDefault(addressId);
      await reload();
    } on AddressException catch (e) {
      Get.snackbar(
        tr('shipping_address'),
        e.isUnauthorized ? tr('please_login_again') : e.message,
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  Future<void> remove(int addressId) async {
    try {
      await _service.deleteAddress(addressId);
      await reload();
      Get.snackbar(
        tr('shipping_address'),
        tr('address_deleted'),
        snackPosition: SnackPosition.BOTTOM,
      );
    } on AddressException catch (e) {
      Get.snackbar(
        tr('shipping_address'),
        e.isUnauthorized ? tr('please_login_again') : e.message,
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }
}
