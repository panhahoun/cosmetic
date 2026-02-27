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
      'login': 'Login',
      'register': 'Register',
      'logout': 'Logout',
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
      'add_to_cart': 'Add to Cart',
      'my_cart': 'My Cart',
      'cart_empty': 'Your cart is empty',
      'total': 'Total',
      'checkout': 'Checkout',
      'cart_detail': 'Cart Detail',
      'purchase': 'Purchase',
      'quantity': 'Quantity',
      'price': 'Price',
      'subtotal': 'Subtotal',
      'order_summary': 'Order Summary',
      'delivery': 'Delivery',
      'payment': 'Payment',
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
      'rating': 'Rating',
    };

    final km = <String, String>{
      'shop': 'ហាងគ្រឿងសំអាង',
      'home': 'ទំព័រដើម',
      'cart': 'កន្រ្តក',
      'login': 'ចូលគណនី',
      'register': 'ចុះឈ្មោះ',
      'logout': 'ចេញ',
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
      'add_to_cart': 'បន្ថែមទៅកន្រ្តក',
      'my_cart': 'កន្រ្តករបស់ខ្ញុំ',
      'cart_empty': 'កន្រ្តកទទេ',
      'total': 'សរុប',
      'checkout': 'បង់ប្រាក់',
      'cart_detail': 'លម្អិតកន្រ្តក',
      'purchase': 'ទិញ',
      'quantity': 'ចំនួន',
      'price': 'តម្លៃ',
      'subtotal': 'តម្លៃរង',
      'order_summary': 'សង្ខេបការបញ្ជាទិញ',
      'delivery': 'ការដឹកជញ្ជូន',
      'payment': 'ការទូទាត់',
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
      'rating': 'ការវាយតម្លៃ',
    };

    final dictionary = isKhmer ? km : en;
    return dictionary[key] ?? key;
  }
}
