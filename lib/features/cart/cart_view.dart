import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../config/app_colors.dart';
import '../../config/app_settings.dart';
import '../../data/address_service_dio.dart';
import '../../models/address_model.dart';
import '../../widgets/cart_item_tile.dart';
import 'cart_controller.dart';

class CartView extends GetView<CartController> {
  const CartView({super.key});

  void _openCheckout(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CheckoutSheet(controller: controller),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = AppSettings.instance;
    String tr(String key) => settings.t(key);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: Text(tr('my_cart'))),
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
          );
        }
        if (controller.cartItems.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.shopping_bag_outlined,
                  size: 72,
                  color: AppColors.textMuted.withAlpha(180),
                ),
                const SizedBox(height: 16),
                Text(
                  tr('cart_empty'),
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          );
        }
        return Column(
          children: [
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.all(20),
                itemCount: controller.cartItems.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final item = controller.cartItems[index];
                  return CartItemTile(
                    item: item,
                    onIncrement: () {
                      final qty = (item['quantity'] as int? ?? 0) + 1;
                      controller.updateQuantity(item['product_id'], qty);
                    },
                    onDecrement: () {
                      final qty = (item['quantity'] as int? ?? 0) - 1;
                      if (qty <= 0) {
                        controller.removeItem(item['product_id']);
                      } else {
                        controller.updateQuantity(item['product_id'], qty);
                      }
                    },
                    onRemove: () {
                      controller.removeItem(item['product_id']);
                    },
                  );
                },
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
                boxShadow: [
                  BoxShadow(
                    color: isDark
                        ? Colors.black.withAlpha(60)
                        : Colors.black.withAlpha(15),
                    blurRadius: 20,
                    offset: const Offset(0, -8),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        tr('total'),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : AppColors.textPrimary,
                        ),
                      ),
                      Obx(
                        () => Text(
                          '\$${controller.total.value.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: Obx(
                      () => ElevatedButton(
                        onPressed: controller.isLoading.value
                            ? null
                            : () => _openCheckout(context),
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
                                tr('checkout'),
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
          ],
        );
      }),
    );
  }
}

class _CheckoutSheet extends StatefulWidget {
  const _CheckoutSheet({required this.controller});

  final CartController controller;

  @override
  State<_CheckoutSheet> createState() => _CheckoutSheetState();
}

class _CheckoutSheetState extends State<_CheckoutSheet> {
  final AddressServiceDio _addressService = AddressServiceDio();
  final TextEditingController _manualAddress = TextEditingController();

  List<Address> _addresses = <Address>[];
  int? _selectedId;
  bool _loadingAddresses = false;
  String _paymentMethod = 'cash_on_delivery';

  AppSettings get _settings => AppSettings.instance;
  String tr(String key) => _settings.t(key);

  bool get _loggedIn => widget.controller.userId.value > 0;

  @override
  void initState() {
    super.initState();
    if (_loggedIn) _loadAddresses();
  }

  @override
  void dispose() {
    _manualAddress.dispose();
    super.dispose();
  }

  Future<void> _loadAddresses() async {
    setState(() => _loadingAddresses = true);
    try {
      final list = await _addressService.getAddresses();
      if (!mounted) return;
      setState(() {
        _addresses = list;
        if (list.isNotEmpty) {
          final def = list.firstWhere(
            (a) => a.isDefault,
            orElse: () => list.first,
          );
          _selectedId = def.id;
        }
      });
    } catch (_) {
      // The manual address field stays available if the address book fails.
    } finally {
      if (mounted) setState(() => _loadingAddresses = false);
    }
  }

  String? _resolveAddress() {
    if (_addresses.isNotEmpty && _selectedId != null) {
      final a = _addresses.firstWhere(
        (x) => x.id == _selectedId,
        orElse: () => _addresses.first,
      );
      return [
        a.fullName,
        a.phone,
        a.addressLine,
        a.summary,
      ].where((s) => s.trim().isNotEmpty).join(', ');
    }
    final manual = _manualAddress.text.trim();
    return manual.isEmpty ? null : manual;
  }

  Future<void> _confirm() async {
    final address = _resolveAddress();
    if (address == null) {
      Get.snackbar(
        tr('checkout'),
        tr('please_enter_shipping_address'),
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }
    Navigator.of(context).pop();
    await widget.controller.checkout(
      paymentMethod: _paymentMethod,
      shippingAddress: address,
    );
  }

  Widget _sectionLabel(String text) => Text(
    text,
    style: const TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w800,
      color: AppColors.textMuted,
      letterSpacing: 0.6,
    ),
  );

  Widget _choiceTile({
    required String title,
    required String subtitle,
    required bool selected,
    required VoidCallback onTap,
    bool disabled = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: selected
            ? AppColors.primary.withAlpha(20)
            : Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected
                    ? AppColors.primary
                    : AppColors.textMuted.withAlpha(30),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  selected ? Icons.check_circle : Icons.radio_button_unchecked,
                  color: disabled
                      ? AppColors.textMuted
                      : (selected ? AppColors.primary : AppColors.textMuted),
                  size: 22,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: disabled
                              ? AppColors.textMuted
                              : (isDark ? Colors.white : AppColors.textPrimary),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.textMuted.withAlpha(80),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                tr('confirm_checkout'),
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 20),
              _sectionLabel(tr('deliver_to')),
              const SizedBox(height: 8),
              if (_loadingAddresses)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: LinearProgressIndicator(
                    minHeight: 2,
                    color: AppColors.primary,
                  ),
                )
              else if (_addresses.isNotEmpty)
                for (final a in _addresses)
                  _choiceTile(
                    title: a.fullName,
                    subtitle: [
                      a.phone,
                      a.addressLine,
                      if (a.summary.isNotEmpty) a.summary,
                    ].where((s) => s.isNotEmpty).join(' · '),
                    selected: _selectedId == a.id,
                    onTap: () => setState(() => _selectedId = a.id),
                  )
              else
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: TextField(
                    controller: _manualAddress,
                    maxLines: 2,
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      hintText: tr('enter_full_delivery_address'),
                      hintStyle: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 20),
              _sectionLabel(tr('payment')),
              const SizedBox(height: 8),
              _choiceTile(
                title: tr('payment_cash_on_delivery'),
                subtitle: tr('payment_cod_subtitle'),
                selected: _paymentMethod == 'cash_on_delivery',
                onTap: () =>
                    setState(() => _paymentMethod = 'cash_on_delivery'),
              ),
              _choiceTile(
                title: tr('payment_khqr'),
                subtitle: tr('payment_khqr_subtitle'),
                selected: false,
                disabled: true,
                onTap: () => Get.snackbar(
                  tr('payment'),
                  tr('qr_payment_disabled'),
                  snackPosition: SnackPosition.BOTTOM,
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _confirm,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    tr('confirm_checkout'),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
