import 'package:flutter/material.dart';
import '../../widgets/botton_nav.dart';
import 'widgets/main_screen.dart';
import '../live/live_screen.dart';
import '../ar_scan/ar_scan_screen.dart';
import '../news/news_screen.dart';
import '../players/players_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  final List<Widget> _screens = const [
    MainScreen(),
    LiveScreen(),
    ARScanScreen(),
    NewsScreen(),
    PlayersScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: IndexedStack(
          index: _selectedIndex,
          children: _screens,
        ),
      ),
      bottomNavigationBar: CustomBottomNav(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) => setState(() => _selectedIndex = index),
      ),
    );
  }
}