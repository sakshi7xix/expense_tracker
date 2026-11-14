import 'dart:ui' as ui;

import 'package:material_ui/material_ui.dart';

import '../../core/tokens.dart';

/// Frosted glass: white, a little see-through, with whatever is behind
/// blurred. Used for every pop-up so none of them pick up a colour tint.
class Glass extends StatelessWidget {
  const Glass({super.key, required this.child, this.radius = const BorderRadius.all(Radius.circular(28))});

  final Widget child;
  final BorderRadius radius;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 26, sigmaY: 26),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Color(0xC7FBFBFA),
            borderRadius: radius,
            border: Border.all(color: Color(0x99FFFFFF)),
          ),
          child: Material(type: MaterialType.transparency, child: child),
        ),
      ),
    );
  }
}

/// What is behind a pop-up: dimmed only lightly so the blur shows through.
const glassBarrier = Color(0x2E101014);

/// A bottom sheet made of [Glass].
Future<T?> showGlassSheet<T>(BuildContext context, WidgetBuilder builder) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    elevation: 0,
    barrierColor: glassBarrier,
    builder: (context) => Glass(
      radius: BorderRadius.vertical(top: Radius.circular(28)),
      child: builder(context),
    ),
  );
}

/// A centred dialog made of [Glass]: a title, content and actions.
class GlassDialog extends StatelessWidget {
  const GlassDialog({super.key, required this.title, required this.content, required this.actions});

  final String title;
  final Widget content;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      insetPadding: EdgeInsets.symmetric(horizontal: 28, vertical: 24),
      child: Glass(
        child: Padding(
          padding: EdgeInsets.fromLTRB(22, 22, 22, 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(title, style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: StubColors.ink)),
              SizedBox(height: 14),
              content,
              SizedBox(height: 18),
              Row(mainAxisAlignment: MainAxisAlignment.end, children: actions),
            ],
          ),
        ),
      ),
    );
  }
}
