import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppLanguage { english, khmer }

class AppSettings extends ChangeNotifier {
  AppSettings._();
  static final AppSettings instance = AppSettings._();

  ThemeMode _themeMode = ThemeMode.light;
  AppLanguage _language = AppLanguage.english;

  ThemeMode get themeMode => _themeMode;
  AppLanguage get language => _language;
  bool get isKhmer => _language == AppLanguage.khmer;

  static const _themeKey = 'app_theme_mode';
  static const _languageKey = 'app_language';

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _themeMode = prefs.getString(_themeKey) == 'dark'
        ? ThemeMode.dark
        : ThemeMode.light;
    _language = prefs.getString(_languageKey) == 'km'
        ? AppLanguage.khmer
        : AppLanguage.english;
  }

  Future<void> toggleTheme() async {
    _themeMode = _themeMode == ThemeMode.dark
        ? ThemeMode.light
        : ThemeMode.dark;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _themeKey,
      _themeMode == ThemeMode.dark ? 'dark' : 'light',
    );
    notifyListeners();
  }

  Future<void> setLanguage(AppLanguage language) async {
    _language = language;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _languageKey,
      language == AppLanguage.khmer ? 'km' : 'en',
    );
    notifyListeners();
  }

  String t(String key) {
    final en = <String, String>{
      'shop': 'Cosmetic Shop',
      'home': 'Home',
      'cart': 'Cart',
      'wishlist': 'Wishlist',
      'profile': 'Profile',
      'login': 'Login',
      'register': 'Register',
      'logout': 'Logout',
      'account': 'Account',
      'order_history': 'Order History',
      'shipping_address': 'Shipping Address',
      'payment_methods': 'Payment Methods',
      'welcome_back': 'Welcome Back',
      'sign_in_subtitle': 'Sign in to continue your beauty shopping.',
      'create_account': 'Create Account',
      'create_account_subtitle': 'Join and personalize your skincare routine.',
      'email': 'Email',
      'password': 'Password',
      'full_name': 'Full Name',
      'phone': 'Phone',
      'search_hint': 'Search product or brand',
      'find_daily': 'Find your daily essentials',
      'added_to_cart': 'Added to cart',
      'added_to_wishlist': 'Added to wishlist',
      'removed_from_wishlist': 'Removed from wishlist',
      'add_to_cart': 'Add to Cart',
      'my_cart': 'My Cart',
      'cart_empty': 'Your cart is empty',
      'total': 'Total',
      'checkout': 'Checkout',
      'confirm_order': 'Confirm Order',
      'continue_shopping': 'Continue Shopping',
      'order_success': 'Order Successful',
      'order_success_desc':
          'Your order has been placed. You can continue shopping.',
      'cart_detail': 'Cart Detail',
      'purchase': 'Purchase',
      'quantity': 'Quantity',
      'total_items': 'Total Items',
      'price': 'Price',
      'subtotal': 'Subtotal',
      'order_summary': 'Order Summary',
      'delivery': 'Delivery',
      'payment': 'Payment',
      'items': 'Items',
      'shipping': 'Shipping',
      'free': 'Free',
      'payment_cash_on_delivery': 'Cash on Delivery',
      'payment_credit_card': 'Credit Card',
      'payment_credit_subtitle': 'Visa, MasterCard, etc.',
      'settings': 'Settings',
      'dark_mode': 'Dark mode',
      'language': 'Language',
      'english': 'English',
      'khmer': 'Khmer',
      'retry': 'Retry',
      'no_products': 'No products available',
      'failed_load': 'Failed to load products',
      'all': 'All',
      'featured_card_title': 'Skincare picks for today',
      'featured_card_subtitle': 'Tap a product card to see full details.',
      'view_cart': 'View Cart',
      'product_detail': 'Product Detail',
      'description': 'Description',
      'brand': 'Brand',
      'category': 'Category',
      'rating': 'Rating',
      'wishlist_empty': 'Your wishlist is empty',
      'please_login_wishlist': 'Please login to use wishlist',
      'please_login_again': 'Please login again',
      'please_login_add_to_cart': 'Please login to add to cart',
      'remove_server_not_supported':
          'Removing server cart items is not supported yet.',
      'cart_update_failed': 'Failed to update cart.',
      'checkout_failed': 'Checkout failed',
      'checkout_failed_try_again': 'Checkout failed. Please try again.',
      'order_placed_local': 'Order placed successfully (Local)',
      'enter_full_delivery_address': 'Enter your full delivery address',
      'please_enter_shipping_address': 'Please enter a shipping address',
      'login_failed': 'Login failed. Please check credentials.',
      'please_enter_name': 'Please enter your name',
      'please_enter_email': 'Please enter your email',
      'please_enter_valid_email': 'Please enter a valid email',
      'please_enter_phone_number': 'Please enter your phone number',
      'please_enter_password': 'Please enter your password',
      'password_min_6': 'Password must be at least 6 characters',
      'product_description_fallback':
          'Premium skincare product for daily routine.',
      'order_history_coming_soon': 'Order History coming soon',
      'shipping_address_coming_soon': 'Shipping Address coming soon',
      'payment_methods_coming_soon': 'Payment Methods coming soon',
      'guest_user': 'Guest User',
      'guest_email': 'guest@example.com',
    };

    final km = <String, String>{
      'shop': 'ហាងគ្រឿងសំអាង',
      'home': 'ទំព័រដើម',
      'cart': 'កន្រ្តក',
      'wishlist': 'ចំណូលចិត្ត',
      'profile': 'ប្រវត្តិរូប',
      'login': 'ចូលគណនី',
      'register': 'ចុះឈ្មោះ',
      'logout': 'ចេញ',
      'account': 'គណនី',
      'order_history': 'ប្រវត្តិបញ្ជាទិញ',
      'shipping_address': 'អាសយដ្ឋានដឹកជញ្ជូន',
      'payment_methods': 'វិធីបង់ប្រាក់',
      'welcome_back': 'សូមស្វាគមន៍',
      'sign_in_subtitle': 'ចូលគណនីដើម្បីបន្តទិញទំនិញសម្រស់។',
      'create_account': 'បង្កើតគណនី',
      'create_account_subtitle': 'ចូលរួម និងរៀបចំការថែរក្សាស្បែករបស់អ្នក។',
      'email': 'អ៊ីមែល',
      'password': 'ពាក្យសម្ងាត់',
      'full_name': 'ឈ្មោះពេញ',
      'phone': 'ទូរស័ព្ទ',
      'search_hint': 'ស្វែងរកផលិតផល ឬ ម៉ាក',
      'find_daily': 'រកឃើញអ្វីដែលអ្នកត្រូវការប្រចាំថ្ងៃ',
      'added_to_cart': 'បានបន្ថែមទៅកន្រ្តក',
      'added_to_wishlist': 'បានបន្ថែមទៅចំណូលចិត្ត',
      'removed_from_wishlist': 'បានដកចេញពីចំណូលចិត្ត',
      'add_to_cart': 'បន្ថែមទៅកន្រ្តក',
      'my_cart': 'កន្រ្តករបស់ខ្ញុំ',
      'cart_empty': 'កន្រ្តកទទេ',
      'total': 'សរុប',
      'checkout': 'បង់ប្រាក់',
      'confirm_order': 'បញ្ជាក់ការបញ្ជាទិញ',
      'continue_shopping': 'បន្តទិញទំនិញ',
      'order_success': 'បញ្ជាទិញជោគជ័យ',
      'order_success_desc': 'ការបញ្ជាទិញរបស់អ្នកបានបញ្ចប់។ អ្នកអាចបន្តទិញ។',
      'cart_detail': 'លម្អិតកន្រ្តក',
      'purchase': 'ទិញ',
      'quantity': 'ចំនួន',
      'total_items': 'ចំនួនទំនិញសរុប',
      'price': 'តម្លៃ',
      'subtotal': 'តម្លៃរង',
      'order_summary': 'សង្ខេបការបញ្ជាទិញ',
      'delivery': 'ការដឹកជញ្ជូន',
      'payment': 'ការទូទាត់',
      'items': 'ទំនិញ',
      'shipping': 'ដឹកជញ្ជូន',
      'free': 'ឥតគិតថ្លៃ',
      'payment_cash_on_delivery': 'បង់ប្រាក់ពេលដឹក',
      'payment_credit_card': 'កាតឥណទាន',
      'payment_credit_subtitle': 'Visa, MasterCard ជាដើម',
      'settings': 'ការកំណត់',
      'dark_mode': 'របៀបងងឹត',
      'language': 'ភាសា',
      'english': 'អង់គ្លេស',
      'khmer': 'ខ្មែរ',
      'retry': 'ព្យាយាមម្ដងទៀត',
      'no_products': 'មិនមានផលិតផល',
      'failed_load': 'ផ្ទុកផលិតផលបរាជ័យ',
      'all': 'ទាំងអស់',
      'featured_card_title': 'ផលិតផលថែស្បែកសម្រាប់ថ្ងៃនេះ',
      'featured_card_subtitle': 'ចុចលើកាតផលិតផលដើម្បីមើលលម្អិត។',
      'view_cart': 'មើលកន្រ្តក',
      'product_detail': 'លម្អិតផលិតផល',
      'description': 'ពិពណ៌នា',
      'brand': 'ម៉ាក',
      'category': 'ប្រភេទ',
      'rating': 'ការវាយតម្លៃ',
      'wishlist_empty': 'បញ្ជីចំណូលចិត្តរបស់អ្នកទទេ',
      'please_login_wishlist': 'សូមចូលគណនីដើម្បីប្រើចំណូលចិត្ត',
      'please_login_again': 'សូមចូលគណនីម្តងទៀត',
      'please_login_add_to_cart': 'សូមចូលគណនីដើម្បីបន្ថែមទៅកន្រ្តក',
      'remove_server_not_supported':
          'មិនទាន់គាំទ្រការលុបពីកន្រ្តកនៅម៉ាស៊ីនមេ',
      'cart_update_failed': 'មិនអាចកែប្រែកន្រ្តកបានទេ',
      'checkout_failed': 'បង់ប្រាក់បរាជ័យ',
      'checkout_failed_try_again': 'បង់ប្រាក់បរាជ័យ។ សូមព្យាយាមម្តងទៀត។',
      'order_placed_local': 'បានបញ្ជាទិញជោគជ័យ (Local)',
      'enter_full_delivery_address': 'បញ្ចូលអាសយដ្ឋានដឹកជញ្ជូនពេញលេញ',
      'please_enter_shipping_address': 'សូមបញ្ចូលអាសយដ្ឋានដឹកជញ្ជូន',
      'login_failed': 'ចូលគណនីបរាជ័យ។ សូមពិនិត្យព័ត៌មាន។',
      'please_enter_name': 'សូមបញ្ចូលឈ្មោះ',
      'please_enter_email': 'សូមបញ្ចូលអ៊ីមែល',
      'please_enter_valid_email': 'សូមបញ្ចូលអ៊ីមែលត្រឹមត្រូវ',
      'please_enter_phone_number': 'សូមបញ្ចូលលេខទូរស័ព្ទ',
      'please_enter_password': 'សូមបញ្ចូលពាក្យសម្ងាត់',
      'password_min_6': 'ពាក្យសម្ងាត់ត្រូវមានយ៉ាងហោចណាស់ ៦ តួអក្សរ',
      'product_description_fallback':
          'ផលិតផលថែរក្សាស្បែកគុណភាពសម្រាប់ប្រើប្រចាំថ្ងៃ។',
      'order_history_coming_soon': 'ប្រវត្តិបញ្ជាទិញនឹងមានឆាប់ៗ',
      'shipping_address_coming_soon': 'អាសយដ្ឋានដឹកជញ្ជូននឹងមានឆាប់ៗ',
      'payment_methods_coming_soon': 'វិធីបង់ប្រាក់នឹងមានឆាប់ៗ',
      'guest_user': 'ភ្ញៀវ',
      'guest_email': 'guest@example.com',
    };

    final dictionary = isKhmer ? km : en;
    return dictionary[key] ?? key;
  }
}
