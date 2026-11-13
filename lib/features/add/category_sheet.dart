import 'package:material_ui/material_ui.dart';

import '../../core/categories.dart';
import '../../core/tokens.dart';
import '../../data/models.dart';
import '../../ui/kit/kit.dart';

/// A grid of every category. Returns the chosen category id.
Future<int?> showCategorySheet(BuildContext context, List<Category> categories, int selectedId) {
  return showModalBottomSheet<int>(
    context: context,
    isScrollControlled: true,
    backgroundColor: StubColors.page,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    builder: (context) => SafeArea(
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
                child: Wrap(
              alignment: WrapAlignment.center,
              runSpacing: 12,
              children: [
                for (final c in categories)
                  SizedBox(
                    width: 78,
                    child: GestureDetector(
                    key: Key('cat-${c.name}'),
                    behavior: HitTestBehavior.opaque,
                    onTap: () => Navigator.of(context).pop(c.id),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              width: 2,
                              color: c.id == selectedId ? categoryStyle(c.name).color : Colors.transparent,
                            ),
                          ),
                          child: CategoryIcon(category: c.name, radius: 23),
                        ),
                        SizedBox(height: 5),
                        Text(
                          c.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: c.id == selectedId ? FontWeight.w800 : FontWeight.w700,
                            color: c.id == selectedId ? StubColors.ink : StubColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ),
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
