import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../config/app_settings.dart';
import '../../core/routes/app_routes.dart';
import '../../data/auth_service.dart';

class AuthController extends GetxController {
  final AuthService _authService = AuthService();

  final GlobalKey<FormState> loginFormKey = GlobalKey<FormState>();
  final GlobalKey<FormState> registerFormKey = GlobalKey<FormState>();

  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final nameController = TextEditingController();
  final phoneController = TextEditingController();

  final isLoading = false.obs;

  /// Server-supplied failure reason, shown instead of a generic string.
  final errorMessage = RxnString();

  AppSettings get settings => AppSettings.instance;
  String tr(String key) => settings.t(key);

  @override
  void onClose() {
    emailController.dispose();
    passwordController.dispose();
    nameController.dispose();
    phoneController.dispose();
    super.onClose();
  }

  Future<void> login() async {
    final form = loginFormKey.currentState;
    if (form == null || !form.validate()) return;

    isLoading.value = true;
    errorMessage.value = null;
    try {
      await _authService.login(
        emailController.text.trim(),
        passwordController.text,
      );
      Get.offAllNamed(AppRoutes.main);
    } on AuthException catch (e) {
      errorMessage.value = e.message;
      Get.snackbar(tr('login'), e.message, snackPosition: SnackPosition.BOTTOM);
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> register() async {
    final form = registerFormKey.currentState;
    if (form == null || !form.validate()) return;

    isLoading.value = true;
    errorMessage.value = null;
    try {
      await _authService.register(
        nameController.text.trim(),
        emailController.text.trim(),
        passwordController.text,
        phoneController.text.trim(),
      );
      nameController.clear();
      phoneController.clear();
      Get.offAllNamed(AppRoutes.login);
      Get.snackbar(tr('register'), tr('create_account'),
          snackPosition: SnackPosition.BOTTOM);
    } on AuthException catch (e) {
      errorMessage.value = e.message;
      Get.snackbar(tr('register'), e.message, snackPosition: SnackPosition.BOTTOM);
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> logout() async {
    await _authService.logout();
    Get.offAllNamed(AppRoutes.login);
  }
}
