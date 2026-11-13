import 'package:material_ui/material_ui.dart';

import '../../core/tokens.dart';

/// White rounded surface used for rows, tiles and form cards.
class SoftCard extends StatelessWidget {
  const SoftCard({super.key, required this.child, this.padding = const EdgeInsets.all(14)});

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: StubColors.surface,
        borderRadius: BorderRadius.circular(StubRadius.row),
        boxShadow: [BoxShadow(color: Color(0x0D1E1E28), blurRadius: 12, offset: Offset(0, 4))],
      ),
      child: child,
    );
  }
}

/// The one primary action on a screen.
class PillButton extends StatelessWidget {
  const PillButton({super.key, required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 54,
      width: double.infinity,
      child: FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: StubColors.pop,
          foregroundColor: Colors.white,
          shape: StadiumBorder(),
          textStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
        onPressed: onPressed,
        child: Text(label),
      ),
    );
  }
}

/// A selectable pill: categories, who paid, split method.
class ChoicePill extends StatelessWidget {
  const ChoicePill({super.key, required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: Duration(milliseconds: 150),
          padding: EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: selected ? StubColors.ink : StubColors.soft,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: selected ? Colors.white : StubColors.muted,
            ),
          ),
        ),
      ),
    );
  }
}

/// Round initial for a friend.
class Avatar extends StatelessWidget {
  const Avatar({super.key, required this.name, this.filled = false, this.radius = 20});

  final String name;
  final bool filled;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: filled ? StubColors.ink : StubColors.soft,
      child: Text(
        name.isEmpty ? '?' : name[0].toUpperCase(),
        style: TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: radius * 0.75,
          color: filled ? Colors.white : StubColors.ink,
        ),
      ),
    );
  }
}

class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key, this.trailing});

  final String text;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(text, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: StubColors.muted)),
        if (trailing != null)
          Text(trailing!, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: StubColors.ink)),
      ],
    );
  }
}

const _categoryIcons = {
  'Food': Icons.restaurant_rounded,
  'Café': Icons.local_cafe_rounded,
  'Travel': Icons.directions_bus_rounded,
  'Fun': Icons.star_rounded,
  'Home': Icons.home_rounded,
  'Study': Icons.menu_book_rounded,
};

/// Soft round icon for a spending category.
class CategoryIcon extends StatelessWidget {
  const CategoryIcon({super.key, required this.category, this.radius = 20});

  final String category;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: StubColors.soft,
      child: Icon(_categoryIcons[category] ?? Icons.receipt_rounded, size: radius, color: StubColors.ink),
    );
  }
}
