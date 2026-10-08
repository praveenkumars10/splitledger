import 'package:flutter/material.dart';
import 'localization/app_strings.dart';
import 'localization/language_controller.dart';

class AppCategory {
  final String id;
  final String emoji;
  final IconData icon;
  final Color color;

  const AppCategory({
    required this.id,
    required this.emoji,
    required this.icon,
    required this.color,
  });

  String getLocalizedName(AppLanguage language) {
    return AppStrings.tr(language, id);
  }
}

const List<AppCategory> appCategories = [
  AppCategory(id: 'food', emoji: '🍔', icon: Icons.restaurant, color: Color(0xFFF97316)),
  AppCategory(id: 'tea', emoji: '☕', icon: Icons.coffee, color: Color(0xFF8B5CF6)),
  AppCategory(id: 'fuel', emoji: '🚗', icon: Icons.local_gas_station, color: Color(0xFFEF4444)),
  AppCategory(id: 'grocery', emoji: '🛒', icon: Icons.shopping_cart, color: Color(0xFF10B981)),
  AppCategory(id: 'bills', emoji: '💡', icon: Icons.receipt_long, color: Color(0xFF06B6D4)),
  AppCategory(id: 'rent', emoji: '🏠', icon: Icons.home, color: Color(0xFF3B82F6)),
  AppCategory(id: 'shopping', emoji: '🛍️', icon: Icons.shopping_bag, color: Color(0xFFA855F7)),
  AppCategory(id: 'medical', emoji: '💊', icon: Icons.medical_services, color: Color(0xFFE11D48)),
  AppCategory(id: 'entertainment', emoji: '🎬', icon: Icons.movie, color: Color(0xFFEC4899)),
  AppCategory(id: 'settle', emoji: '💵', icon: Icons.handshake, color: Color(0xFF0D9488)),
  AppCategory(id: 'other', emoji: '📦', icon: Icons.category, color: Color(0xFF64748B)),
];

AppCategory getCategoryById(String? id) {
  if (id == null) return appCategories.first;
  final lower = id.toLowerCase().trim();
  return appCategories.firstWhere(
    (c) => c.id == lower,
    orElse: () => appCategories.last,
  );
}
