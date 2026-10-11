import 'package:cosmetic/data/address_service_dio.dart';
import 'package:cosmetic/data/orders_service_dio.dart';
import 'package:cosmetic/features/addresses/address_controller.dart';
import 'package:cosmetic/features/orders/orders_controller.dart';
import 'package:cosmetic/models/address_model.dart';
import 'package:cosmetic/models/order_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeOrdersService implements OrdersService {
  FakeOrdersService(this.orders);

  final List<Order> orders;
  int calls = 0;

  @override
  Future<List<Order>> getOrders({int limit = 50, int offset = 0}) async {
    calls++;
    return orders;
  }
}

class FakeAddressService implements AddressService {
  final List<Address> store = [];
  int _nextId = 1;
  int? lastDeletedId;
  int? lastDefaultId;

  @override
  Future<List<Address>> getAddresses() async => List.of(store);

  @override
  Future<Address> addAddress({
    required String fullName,
    required String phone,
    required String addressLine,
    String? city,
    String? postalCode,
    bool isDefault = false,
  }) async {
    final a = Address(
      id: _nextId++,
      fullName: fullName,
      phone: phone,
      addressLine: addressLine,
      city: city ?? '',
      postalCode: postalCode ?? '',
      isDefault: isDefault,
    );
    store.add(a);
    return a;
  }

  @override
  Future<Address> setDefault(int addressId) async {
    lastDefaultId = addressId;
    final idx = store.indexWhere((a) => a.id == addressId);
    return store[idx];
  }

  @override
  Future<void> deleteAddress(int addressId) async {
    lastDeletedId = addressId;
    store.removeWhere((a) => a.id == addressId);
  }
}

Order _order({int id = 1}) => Order(
  id: id,
  orderNumber: 'ORD-000$id',
  totalAmount: 52.0,
  status: 'pending_payment',
  paymentMethod: 'cash_on_delivery',
  shippingAddress: '12 Norodom Blvd, Phnom Penh',
  notes: '',
  createdAt: DateTime.utc(2026, 1, 5, 9, 30),
  items: [
    OrderItem(
      id: 1,
      productId: 3,
      productName: 'Ceramide Cloud Cream',
      productImage: '',
      price: 26.0,
      quantity: 2,
      subtotal: 52.0,
    ),
  ],
);

void main() {
  tearDown(() => Get.reset());

  Future<void> settleSnackbars(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  }

  group('models', () {
    test('Order.fromJson parses items and total', () {
      final order = Order.fromJson({
        'id': 7,
        'order_number': 'ORD-0007',
        'total_amount': '52.5',
        'status': 'paid',
        'payment_method': 'cash_on_delivery',
        'shipping_address': 'Somewhere',
        'created_at': '2026-01-05T09:30:00+00:00',
        'items': [
          {
            'id': 1,
            'product_id': 3,
            'product_name': 'Cream',
            'price': '26.25',
            'quantity': 2,
            'subtotal': '52.5',
          },
        ],
      });
      expect(order.status, 'paid');
      expect(order.totalAmount, 52.5);
      expect(order.items, hasLength(1));
      expect(order.items.first.quantity, 2);
      expect(order.itemCount, 2);
    });

    test('Address.fromJson reads the default flag and summary', () {
      final a = Address.fromJson({
        'id': 4,
        'full_name': 'Sok Dara',
        'phone': '012345678',
        'address_line': '12 Norodom Blvd',
        'city': 'Phnom Penh',
        'postal_code': '12000',
        'is_default': true,
      });
      expect(a.isDefault, isTrue);
      expect(a.summary, 'Phnom Penh, 12000');
    });
  });

  group('OrdersController', () {
    testWidgets('loads orders for a logged-in user', (tester) async {
      SharedPreferences.setMockInitialValues({'id': 7});
      final controller = OrdersController(
        service: FakeOrdersService([_order()]),
      );
      addTearDown(controller.dispose);

      await tester.pumpWidget(GetMaterialApp(home: const Scaffold()));
      await controller.reload();
      await tester.pump();

      expect(controller.orders, hasLength(1));
      expect(controller.orders.first.orderNumber, 'ORD-0001');
    });

    testWidgets('shows nothing when logged out', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final service = FakeOrdersService([_order()]);
      final controller = OrdersController(service: service);
      addTearDown(controller.dispose);

      await tester.pumpWidget(GetMaterialApp(home: const Scaffold()));
      await controller.reload();
      await tester.pump();

      expect(controller.orders, isEmpty);
      expect(service.calls, 0);
    });
  });

  group('AddressController', () {
    testWidgets('adds, defaults and deletes an address', (tester) async {
      SharedPreferences.setMockInitialValues({'id': 7});
      final service = FakeAddressService();
      final controller = AddressController(service: service);
      addTearDown(controller.dispose);

      await tester.pumpWidget(GetMaterialApp(home: const Scaffold()));
      await controller.reload();

      final ok = await controller.addAddress(
        fullName: 'Sok Dara',
        phone: '012345678',
        addressLine: '12 Norodom Blvd',
        city: 'Phnom Penh',
        isDefault: true,
      );
      await tester.pump();
      expect(ok, isTrue);
      expect(controller.addresses, hasLength(1));
      expect(controller.addresses.first.isDefault, isTrue);
      await settleSnackbars(tester);

      await controller.setDefault(controller.addresses.first.id);
      await tester.pump();
      expect(service.lastDefaultId, controller.addresses.first.id);

      await controller.remove(controller.addresses.first.id);
      await tester.pump();
      expect(controller.addresses, isEmpty);
      expect(service.lastDeletedId, isNotNull);
      await settleSnackbars(tester);
    });
  });
}
