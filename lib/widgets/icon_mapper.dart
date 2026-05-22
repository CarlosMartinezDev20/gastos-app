import 'package:flutter/material.dart';

IconData iconFromApi(String name) {
  return switch (name) {
    'lunch_dining' => Icons.lunch_dining_outlined,
    'directions_bus' => Icons.directions_bus_outlined,
    'print' => Icons.print_outlined,
    'celebration' => Icons.celebration_outlined,
    'home' => Icons.home_outlined,
    'medical_services' => Icons.medical_services_outlined,
    'checkroom' => Icons.checkroom_outlined,
    'savings' => Icons.savings_outlined,
    'work' => Icons.work_outline,
    'account_balance_wallet' => Icons.account_balance_wallet_outlined,
    'laptop_mac' => Icons.laptop_mac_outlined,
    'flight' => Icons.flight_takeoff_outlined,
    'school' => Icons.school_outlined,
    'sports_esports' => Icons.sports_esports_outlined,
    'directions_car' => Icons.directions_car_outlined,
    'volunteer_activism' => Icons.volunteer_activism_outlined,
    'auto_awesome' => Icons.auto_awesome_outlined,
    _ => Icons.category_outlined,
  };
}
