import 'package:flutter/material.dart';

/// Material Symbols names the API stores, mapped to their outlined icons.
/// The order is the order of the category icon picker.
const _icons = <String, IconData>{
  'lunch_dining': Icons.lunch_dining_outlined,
  'restaurant': Icons.restaurant_outlined,
  'local_cafe': Icons.local_cafe_outlined,
  'shopping_cart': Icons.shopping_cart_outlined,
  'shopping_bag': Icons.shopping_bag_outlined,
  'directions_bus': Icons.directions_bus_outlined,
  'directions_car': Icons.directions_car_outlined,
  'local_gas_station': Icons.local_gas_station_outlined,
  'flight': Icons.flight_takeoff_outlined,
  'home': Icons.home_outlined,
  'bolt': Icons.bolt_outlined,
  'wifi': Icons.wifi,
  'phone_iphone': Icons.phone_iphone_outlined,
  'medical_services': Icons.medical_services_outlined,
  'fitness_center': Icons.fitness_center_outlined,
  'spa': Icons.spa_outlined,
  'checkroom': Icons.checkroom_outlined,
  'school': Icons.school_outlined,
  'print': Icons.print_outlined,
  'menu_book': Icons.menu_book_outlined,
  'celebration': Icons.celebration_outlined,
  'movie': Icons.movie_outlined,
  'music_note': Icons.music_note_outlined,
  'sports_esports': Icons.sports_esports_outlined,
  'sports_soccer': Icons.sports_soccer_outlined,
  'pets': Icons.pets_outlined,
  'card_giftcard': Icons.card_giftcard_outlined,
  'volunteer_activism': Icons.volunteer_activism_outlined,
  'laptop_mac': Icons.laptop_mac_outlined,
  'work': Icons.work_outline,
  'savings': Icons.savings_outlined,
  'payments': Icons.payments_outlined,
  'trending_up': Icons.trending_up,
  'storefront': Icons.storefront_outlined,
  'account_balance_wallet': Icons.account_balance_wallet_outlined,
  'auto_awesome': Icons.auto_awesome_outlined,
};

/// Icon names offered when creating or editing a category.
final categoryIconNames = _icons.keys.toList(growable: false);

IconData iconFromApi(String name) => _icons[name] ?? Icons.category_outlined;
