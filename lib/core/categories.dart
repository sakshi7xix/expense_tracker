import 'package:material_ui/material_ui.dart';

/// How a spending category looks: its icon, its colour and a soft tint of it.
class CategoryStyle {
  const CategoryStyle(this.icon, this.color, this.tint);

  final IconData icon;
  final Color color;
  final Color tint;
}

const _other = CategoryStyle(Icons.more_horiz_rounded, Color(0xFF6B7280), Color(0xFFEEEFF1));

const _styles = {
  'Food': CategoryStyle(Icons.restaurant_rounded, Color(0xFFE8703A), Color(0xFFFFF0E8)),
  'Groceries': CategoryStyle(Icons.shopping_basket_rounded, Color(0xFF2F9E6B), Color(0xFFE6F6EE)),
  'Café': CategoryStyle(Icons.local_cafe_rounded, Color(0xFF8D5A3B), Color(0xFFF3EAE3)),
  'Travel': CategoryStyle(Icons.directions_bus_rounded, Color(0xFF2F6BFF), Color(0xFFE8EFFF)),
  'Shopping': CategoryStyle(Icons.shopping_bag_rounded, Color(0xFFD6409F), Color(0xFFFCE9F5)),
  'Fun': CategoryStyle(Icons.movie_rounded, Color(0xFF7C4DFF), Color(0xFFEFE9FF)),
  'Home': CategoryStyle(Icons.home_rounded, Color(0xFF0E9AA7), Color(0xFFE2F5F6)),
  'Rent': CategoryStyle(Icons.apartment_rounded, Color(0xFF5562EA), Color(0xFFE9EBFD)),
  'Utilities': CategoryStyle(Icons.water_drop_rounded, Color(0xFF1C8FD6), Color(0xFFE3F2FB)),
  'Electricity': CategoryStyle(Icons.bolt_rounded, Color(0xFFD69E00), Color(0xFFFFF6D6)),
  'Subscriptions': CategoryStyle(Icons.subscriptions_rounded, Color(0xFFE5484D), Color(0xFFFDEBEC)),
  'Health': CategoryStyle(Icons.favorite_rounded, Color(0xFFE03177), Color(0xFFFDE8F0)),
  'Study': CategoryStyle(Icons.menu_book_rounded, Color(0xFF4263EB), Color(0xFFE8ECFD)),
  'Other': _other,
};

CategoryStyle categoryStyle(String name) => _styles[name] ?? _other;

/// Colours handed to friends, picked by name so each friend keeps theirs.
const _friendColors = [
  (Color(0xFF2F6BFF), Color(0xFFE8EFFF)),
  (Color(0xFFD6409F), Color(0xFFFCE9F5)),
  (Color(0xFF0E9AA7), Color(0xFFE2F5F6)),
  (Color(0xFF7C4DFF), Color(0xFFEFE9FF)),
  (Color(0xFFE8703A), Color(0xFFFFF0E8)),
  (Color(0xFF2F9E6B), Color(0xFFE6F6EE)),
];

(Color, Color) friendColors(String name) {
  if (name.isEmpty) return _friendColors[0];
  final sum = name.codeUnits.fold<int>(0, (a, b) => a + b);
  return _friendColors[sum % _friendColors.length];
}
