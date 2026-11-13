import 'package:material_ui/material_ui.dart';

import '../../core/tokens.dart';
import '../add/add_spend_screen.dart';
import '../friends/friends_screen.dart';
import '../home/home_screen.dart';

/// The tab bar and the + button. Stubs and Statistics arrive in later phases.
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
      body: IndexedStack(
        index: _tab,
        children: [
          HomeScreen(),
          _ComingSoon(title: 'Stubs', note: 'One receipt per week. Coming in the next phase.'),
          _ComingSoon(title: 'Statistics', note: 'Trends and top spending. Coming in the next phase.'),
          FriendsScreen(),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: FloatingActionButton(
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
          children: [_tabButton(0), _tabButton(1), SizedBox(width: 56), _tabButton(2), _tabButton(3)],
        ),
      ),
    );
  }
}

class _ComingSoon extends StatelessWidget {
  const _ComingSoon({required this.title, required this.note});

  final String title;
  final String note;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: text.titleMedium),
            SizedBox(height: 6),
            Text(note, style: text.bodyMedium, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
