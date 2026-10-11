import 'package:flutter/material.dart';

import '../../config/app_colors.dart';
import '../../config/app_settings.dart';

class PaymentMethodsView extends StatelessWidget {
  const PaymentMethodsView({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = AppSettings.instance;
    String tr(String key) => settings.t(key);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: Text(tr('payment_methods'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _MethodCard(
            icon: Icons.payments_outlined,
            title: tr('payment_cash_on_delivery'),
            subtitle: tr('payment_cod_subtitle'),
            enabled: true,
            enabledLabel: tr('in_stock'),
            isDark: isDark,
          ),
          const SizedBox(height: 12),
          _MethodCard(
            icon: Icons.qr_code_2_outlined,
            title: tr('payment_khqr'),
            subtitle: tr('payment_khqr_subtitle'),
            enabled: false,
            enabledLabel: tr('qr_payment_disabled'),
            isDark: isDark,
          ),
        ],
      ),
    );
  }
}

class _MethodCard extends StatelessWidget {
  const _MethodCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.enabled,
    required this.enabledLabel,
    required this.isDark,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool enabled;
  final String enabledLabel;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: enabled
              ? AppColors.primary.withAlpha(90)
              : AppColors.textMuted.withAlpha(30),
          width: enabled ? 1.5 : 1,
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: (enabled ? AppColors.primary : AppColors.textMuted)
                  .withAlpha(30),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: enabled ? AppColors.primary : AppColors.textMuted,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : AppColors.textPrimary,
                        ),
                      ),
                    ),
                    if (enabled)
                      const Icon(
                        Icons.check_circle,
                        color: AppColors.primary,
                        size: 20,
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 13,
                  ),
                ),
                if (!enabled) ...[
                  const SizedBox(height: 8),
                  Text(
                    enabledLabel,
                    style: const TextStyle(
                      color: Colors.orange,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
