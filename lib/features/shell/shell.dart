import 'package:material_ui/material_ui.dart';

import '../../core/tokens.dart';
import '../add/add_spend_screen.dart';
import '../friends/friends_screen.dart';
import '../home/home_screen.dart';
import '../stats/stats_screen.dart';
import '../stubs/stubs_screen.dart';

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
    (icon: Icons.receipt_long_rounded, label: 'Stubs'),
    (icon: Icons.bar_chart_rounded, label: 'Statistics'),
    (icon: Icons.group_rounded, label: 'Friends'),
  ];

  Widget _tabButton(int index) {
    final tab = _tabs[index];
    return IconButton(
      key: Key('nav-${tab.label.toLowerCase()}'),
      tooltip: tab.label,
      icon: Icon(tab.icon),
      color: _tab == index ? StubColors.ink : Color(0xFFB4B3B8),
      onPressed: () => setState(() => _tab = index),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedSwitcher(
        duration: Duration(milliseconds: 240),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween(begin: Offset(0, 0.015), end: Offset.zero).animate(animation),
            child: child,
          ),
        ),
        child: KeyedSubtree(
          key: ValueKey(_tab),
          child: switch (_tab) {
            0 => HomeScreen(),
            1 => StubsScreen(),
            2 => StatsScreen(),
            _ => FriendsScreen(),
          },
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: _tab != 0
          ? null
          : FloatingActionButton(
        key: Key('fab-add'),
        tooltip: 'Add a spend',
        backgroundColor: StubColors.pop,
        foregroundColor: Colors.white,
        shape: CircleBorder(),
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute<void>(fullscreenDialog: true, builder: (_) => AddSpendScreen()),
        ),
        child: Icon(Icons.add_rounded, size: 30),
      ),
      bottomNavigationBar: BottomAppBar(
        color: StubColors.page,
        elevation: 0,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [_tabButton(0), _tabButton(1), _tabButton(2), _tabButton(3)],
        ),
      ),
    );
  }
}
