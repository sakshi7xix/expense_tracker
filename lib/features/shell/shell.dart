import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/tokens.dart';
import '../../ui/kit/glass.dart';
import '../../ui/kit/motion.dart';
import '../add/add_spend_sheet.dart';
import '../bills/bills_screen.dart';
import '../friends/friends_screen.dart';
import '../home/home_screen.dart';
import '../stats/stats_screen.dart';

/// The tab bar, plus the + button on Home only.
class Shell extends StatefulWidget {
  const Shell({super.key});

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int _tab = 0;

  static const _tabs = [
    (icon: Icons.home_rounded, label: 'Home'),
    (icon: Icons.bar_chart_rounded, label: 'Statistics'),
    (icon: Icons.receipt_long_rounded, label: 'Bills'),
    (icon: Icons.group_rounded, label: 'Friends'),
  ];

  void _go(int index) {
    if (index == _tab) return;
    HapticFeedback.selectionClick();
    setState(() => _tab = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedSwitcher(
        duration: Duration(milliseconds: 300),
        reverseDuration: Duration(milliseconds: 120),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeIn,
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: animation,
          child: ScaleTransition(scale: Tween(begin: 0.97, end: 1.0).animate(animation), child: child),
        ),
        child: KeyedSubtree(
          key: ValueKey(_tab),
          child: switch (_tab) {
            0 => HomeScreen(onOpenBills: () => _go(2)),
            1 => StatsScreen(),
            2 => BillsScreen(),
            _ => FriendsScreen(),
          },
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: AnimatedScale(
        scale: _tab == 0 ? 1 : 0,
        duration: Duration(milliseconds: 380),
        curve: _tab == 0 ? Curves.easeOutBack : Curves.easeInCubic,
        child: _tab != 0
            ? SizedBox(width: 56, height: 56)
            : FloatingActionButton(
                key: Key('fab-add'),
                tooltip: 'Add a spend',
                backgroundColor: StubColors.pop,
                foregroundColor: Colors.white,
                shape: CircleBorder(),
                onPressed: () {
                  HapticFeedback.lightImpact();
                  showGlassSheet<void>(context, (_) => AddSpendSheet());
                },
                child: Icon(Icons.add_rounded, size: 30),
              ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(16, 4, 16, 10),
          child: Row(
            children: [
              for (var i = 0; i < _tabs.length; i++)
                Expanded(
                  flex: i == _tab ? 5 : 3,
                  child: _TabItem(
                    key: Key('nav-${_tabs[i].label.toLowerCase()}'),
                    icon: _tabs[i].icon,
                    label: _tabs[i].label,
                    selected: i == _tab,
                    onTap: () => _go(i),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A tab that grows into a dark pill with its name when selected.
class _TabItem extends StatelessWidget {
  const _TabItem({super.key, required this.icon, required this.label, required this.selected, required this.onTap});

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      label: label,
      child: Pressable(
        scale: 0.9,
        haptic: false,
        onTap: onTap,
        child: AnimatedContainer(
          duration: Duration(milliseconds: 360),
          curve: Curves.easeOutCubic,
          height: 48,
          margin: EdgeInsets.symmetric(horizontal: 3),
          decoration: BoxDecoration(
            color: selected ? StubColors.ink : Colors.transparent,
            borderRadius: BorderRadius.circular(24),
          ),
          child: ClipRect(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedScale(
                  scale: selected ? 1.08 : 1,
                  duration: Duration(milliseconds: 360),
                  curve: Curves.easeOutBack,
                  child: Icon(icon, size: 22, color: selected ? Colors.white : Color(0xFFB4B3B8)),
                ),
                Flexible(
                  child: AnimatedSize(
                    duration: Duration(milliseconds: 360),
                    curve: Curves.easeOutCubic,
                    child: selected
                        ? Padding(
                            padding: EdgeInsets.only(left: 7),
                            child: Text(
                              label,
                              maxLines: 1,
                              overflow: TextOverflow.fade,
                              softWrap: false,
                              style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800),
                            ),
                          )
                        : SizedBox.shrink(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
