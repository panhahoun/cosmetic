import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../config/app_settings.dart';
import '../../core/routes/app_routes.dart';

class ProfileController extends GetxController {
  final name = 'Guest User'.obs;
  final email = 'guest@example.com'.obs;
  final userId = 0.obs;

  AppSettings get settings => AppSettings.instance;
  String tr(String key) => settings.t(key);

  @override
  void onInit() {
    super.onInit();
    loadUser();
  }

  Future<void> loadUser() async {
    final prefs = await SharedPreferences.getInstance();
    userId.value = prefs.getInt('id') ?? 0;
    if (userId.value > 0) {
      name.value = prefs.getString('name') ?? tr('guest_user');
      email.value = prefs.getString('email') ?? tr('guest_email');
    }
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    Get.offAllNamed(AppRoutes.login);
  }
}
