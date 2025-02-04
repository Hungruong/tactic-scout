import 'package:flutter/material.dart';
import '../../ar_scan/ar_scan_screen.dart';
import 'schedule_games.dart';
import 'top_players.dart';
import 'header.dart';
import '../../../widgets/search_bar.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      controller: _scrollController,
      physics: const BouncingScrollPhysics(),
      slivers: [
        const MLBHeader(),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              const SizedBox(height: 16),
              const CustomSearchBar(),
              const SizedBox(height: 24),
              _buildSectionTitle(context, 'Quick Actions'),
              const SizedBox(height: 16),
              const QuickActionsRow(),
              const SizedBox(height: 24),
              _buildSectionTitle(context, 'Schedule'),
              const SizedBox(height: 16),
              const ScheduleGamesSection(),
              const SizedBox(height: 24),
              _buildSectionTitle(context, 'Top Players'),
              const SizedBox(height: 16),
              const TopPlayersSection(),
              const SizedBox(height: 24),
            ]),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
    );
  }
}

// Extracted QuickActions row for better organization
class QuickActionsRow extends StatelessWidget {
  const QuickActionsRow({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _ActionItem(
          icon: Icons.camera_alt,
          label: 'Scan Player',
          color: Colors.blue[700]!,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const ARScanScreen(),
              ),
            );
          },
        ),
        _ActionItem(
          icon: Icons.analytics,
          label: 'Analysis',
          color: Colors.green[700]!,
          onTap: () {},
        ),
        _ActionItem(
          icon: Icons.compare_arrows,
          label: 'Compare',
          color: Colors.orange[700]!,
          onTap: () {},
        ),
        _ActionItem(
          icon: Icons.history,
          label: 'History',
          color: Colors.purple[700]!,
          onTap: () {},
        ),
      ],
    );
  }
}

class _ActionItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionItem({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, size: 24, color: color),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}