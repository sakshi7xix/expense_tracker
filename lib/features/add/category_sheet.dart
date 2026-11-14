import 'package:material_ui/material_ui.dart';

import '../../core/categories.dart';
import '../../core/tokens.dart';
import '../../data/models.dart';
import '../../ui/kit/glass.dart';
import '../../ui/kit/kit.dart';
import '../../ui/kit/motion.dart';

/// A grid of every category. Returns the chosen category id.
Future<int?> showCategorySheet(BuildContext context, List<Category> categories, int selectedId) {
  final byName = {for (final c in categories) c.name: c};
  final listed = {for (final (_, names) in categoryGroups) ...names};
  final extra = [for (final c in categories) if (!listed.contains(c.name)) c];
  return showGlassSheet<int>(
    context,
    (context) => SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SheetGrab(),
            Text('Category', style: Theme.of(context).textTheme.titleMedium),
            SizedBox(height: 16),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final (title, names) in categoryGroups)
                      if (names.any(byName.containsKey)) ...[
                        if (title.isNotEmpty)
                          Padding(
                            padding: EdgeInsets.fromLTRB(4, 6, 4, 8),
                            child: Text(
                              title,
                              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: StubColors.muted),
                            ),
                          ),
                        Wrap(
                          runSpacing: 10,
                          children: [
                            for (final name in names)
                              if (byName[name] case final c?) _cell(context, c, selectedId),
                          ],
                        ),
                        SizedBox(height: 10),
                      ],
                    if (extra.isNotEmpty)
                      Wrap(runSpacing: 10, children: [for (final c in extra) _cell(context, c, selectedId)]),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

Widget _cell(BuildContext context, Category c, int selectedId) {
  final selected = c.id == selectedId;
  return SizedBox(
    width: 80,
    child: Pressable(
      key: Key('cat-${c.name}'),
      scale: 0.88,
      onTap: () => Navigator.of(context).pop(c.id),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: Duration(milliseconds: 150),
            padding: EdgeInsets.all(3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(width: 2, color: selected ? categoryStyle(c.name).color : Colors.transparent),
            ),
            child: CategoryIcon(category: c.name, radius: 23),
          ),
          SizedBox(height: 5),
          Text(
            c.name,
            maxLines: 2,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              height: 1.15,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w700,
              color: selected ? StubColors.ink : StubColors.muted,
            ),
          ),
        ],
      ),
    ),
  );
}
