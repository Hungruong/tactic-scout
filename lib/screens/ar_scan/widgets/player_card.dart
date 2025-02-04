import 'package:flutter/material.dart';

class PlayerCard extends StatelessWidget {
  final Map<String, dynamic> playerInfo;
  final VoidCallback onClose;

  const PlayerCard({
    super.key,
    required this.playerInfo,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHeader(),
          const Divider(height: 1),
          _buildStats(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: Colors.blue[100],
        child: Text(
          playerInfo['number'] ?? '#',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.blue,
          ),
        ),
      ),
      title: Text(
        playerInfo['name'] ?? 'Unknown Player',
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      subtitle: Text(
        '${playerInfo['team']} • ${playerInfo['position']}',
      ),
      trailing: IconButton(
        icon: const Icon(Icons.close),
        onPressed: onClose,
      ),
    );
  }

  Widget _buildStats() {
    final stats = playerInfo['stats'] as Map<String, dynamic>?;
    if (stats == null) return const SizedBox();

    final position = playerInfo['position']?.toLowerCase();
    if (position == 'pitcher') {
      return _buildPitchingStats(stats['pitching']);
    } else {
      return _buildHittingStats(stats['hitting']);
    }
  }

  Widget _buildPitchingStats(Map<String, dynamic> pitching) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem('ERA', pitching['era']?.toString() ?? '---'),
          _buildStatItem('SO', pitching['strikeOuts']?.toString() ?? '0'),
          _buildStatItem('IP', pitching['inningsPitched']?.toString() ?? '0.0'),
          _buildStatItem('Games', pitching['games']?.toString() ?? '0'),
        ],
      ),
    );
  }

  Widget _buildHittingStats(Map<String, dynamic> hitting) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem('AVG', hitting['avg']?.toString() ?? '---'),
          _buildStatItem('HR', hitting['hr']?.toString() ?? '0'),
          _buildStatItem('RBI', hitting['rbi']?.toString() ?? '0'),
          _buildStatItem('Hits', hitting['hits']?.toString() ?? '0'),
          _buildStatItem('Games', hitting['games']?.toString() ?? '0'),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 14,
          ),
        ),
      ],
    );
  }
}
