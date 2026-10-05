import 'package:flutter/material.dart';

import '../../config/app_colors.dart';
import '../../config/app_settings.dart';

class WishlistView extends StatelessWidget {
  const WishlistView({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = AppSettings.instance;
    String tr(String key) => settings.t(key);

    return Scaffold(
      appBar: AppBar(
        title: Text(tr('wishlist')),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.favorite_border_rounded,
              size: 72,
              color: AppColors.textMuted.withAlpha(180),
            ),
            const SizedBox(height: 16),
            Text(
              tr('wishlist_empty'),
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
