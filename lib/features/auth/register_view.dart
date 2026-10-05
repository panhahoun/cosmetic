import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../config/app_colors.dart';
import '../../config/app_settings.dart';
import 'auth_controller.dart';

class RegisterView extends GetView<AuthController> {
  const RegisterView({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final settings = AppSettings.instance;
    String tr(String key) => settings.t(key);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? const [Color(0xFF1B1720), Color(0xFF241F29)]
                : const [Color(0xFFFDFBFA), Color(0xFFF7EFEC)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 430),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tr('create_account'),
                      style: TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      tr('create_account_subtitle'),
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x15000000),
                            blurRadius: 30,
                            offset: Offset(0, 15),
                          ),
                        ],
                      ),
                      child: Form(
                        key: controller.registerFormKey,
                        child: Column(
                          children: [
                            TextFormField(
                              controller: controller.nameController,
                              decoration: InputDecoration(
                                labelText: tr('full_name'),
                                prefixIcon: const Icon(Icons.person_outline,
                                    color: AppColors.primary),
                              ),
                              validator: (v) => (v == null || v.isEmpty)
                                  ? tr('please_enter_name')
                                  : null,
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: controller.emailController,
                              decoration: InputDecoration(
                                labelText: tr('email'),
                                prefixIcon: const Icon(
                                    Icons.alternate_email,
                                    color: AppColors.primary),
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: controller.phoneController,
                              decoration: InputDecoration(
                                labelText: tr('phone'),
                                prefixIcon: const Icon(Icons.phone_outlined,
                                    color: AppColors.primary),
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: controller.passwordController,
                              obscureText: true,
                              decoration: InputDecoration(
                                labelText: tr('password'),
                                prefixIcon: const Icon(Icons.lock_outline,
                                    color: AppColors.primary),
                              ),
                            ),
                            const SizedBox(height: 24),
                            Obx(
                              () => SizedBox(
                                width: double.infinity,
                                height: 56,
                                child: ElevatedButton(
                                  onPressed: controller.isLoading.value
                                      ? null
                                      : controller.register,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primary,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                  child: controller.isLoading.value
                                      ? const CircularProgressIndicator(
                                          color: Colors.white,
                                        )
                                      : Text(
                                          tr('register'),
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w700,
                                            color: Colors.white,
                                          ),
                                        ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
