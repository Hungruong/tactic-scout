import 'package:flutter/material.dart';
import '../../../services/mlb_services.dart';

class TopPlayersSection extends StatefulWidget {
  const TopPlayersSection({super.key});

  @override
  State<TopPlayersSection> createState() => _TopPlayersSectionState();
}

class _TopPlayersSectionState extends State<TopPlayersSection> {
  final MLBService _mlbService = MLBService();
  List<Map<String, dynamic>>? _hitters;
  List<Map<String, dynamic>>? _pitchers;
  bool _isLoading = true;
  bool _isError = false;

  @override
  void initState() {
    super.initState();
    _fetchTopPlayers();
  }

  Future<void> _fetchTopPlayers() async {
    try {
      setState(() {
        _isLoading = true;
        _isError = false;
      });
      
      final hitters = await _mlbService.getTopHitters(limit: 5);
      final pitchers = await _mlbService.getTopPitchers(limit: 5);
      
      if (mounted) {
        setState(() {
          _hitters = hitters;
          _pitchers = pitchers;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error fetching top players: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isError = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_isError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Failed to load player stats'),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _fetchTopPlayers,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            title: 'Batting Leaders',
            icon: Icons.sports_baseball_outlined,
          ),
          const SizedBox(height: 12),
          ..._buildHitterCards(),
          
          const SizedBox(height: 24),
          
          _buildSectionHeader(
            title: 'Pitching Leaders',
            icon: Icons.sports_baseball,
          ),
          const SizedBox(height: 12),
          ..._buildPitcherCards(),
        ],
      ),
    );
  }

  Widget _buildSectionHeader({required String title, required IconData icon}) {
    return Row(
      children: [
        Icon(icon, size: 24),
        const SizedBox(width: 12),
        Text(
          title,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  List<Widget> _buildHitterCards() {
    if (_hitters == null || _hitters!.isEmpty) {
      return [const _EmptyStateCard(message: 'No batting stats available')];
    }

    return _hitters!.take(5).map((player) {
      return _PlayerStatsCard(
        player: player,
        rank: _hitters!.indexOf(player) + 1,
        isHitter: true,
      );
    }).toList();
  }

  List<Widget> _buildPitcherCards() {
    if (_pitchers == null || _pitchers!.isEmpty) {
      return [const _EmptyStateCard(message: 'No pitching stats available')];
    }

    return _pitchers!.take(5).map((player) {
      return _PlayerStatsCard(
        player: player,
        rank: _pitchers!.indexOf(player) + 1,
        isHitter: false,
      );
    }).toList();
  }
}

class _PlayerStatsCard extends StatelessWidget {
  final Map<String, dynamic> player;
  final int rank;
  final bool isHitter;

  const _PlayerStatsCard({
    required this.player,
    required this.rank,
    required this.isHitter,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () {
          showDialog(
            context: context,
            builder: (context) => _PlayerDetailCard(
              player: player,
              isHitter: isHitter,
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              _buildPlayerAvatar(),
              const SizedBox(width: 12),
              Expanded(
                child: _buildPlayerInfo(),
              ),
              _buildMainStat(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlayerAvatar() {
    return Stack(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: (player['teamColor'] as Color).withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Icon(
              isHitter ? Icons.person : Icons.sports_baseball,
              color: player['teamColor'] as Color,
              size: 24,
            ),
          ),
        ),
        Positioned(
          right: -2,
          bottom: -2,
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: player['teamColor'] as Color,
              shape: BoxShape.circle,
            ),
            child: Text(
              rank.toString(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPlayerInfo() {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            player['name'] ?? 'Unknown Player',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            '${player['teamName'] ?? 'No Team'} · ${player['position'] ?? ''}',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 12,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildMainStat() {
    final stats = player['stats'] ?? {};
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          isHitter ? (stats['avg']?.toString() ?? '---') : (stats['era']?.toString() ?? '---'),
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        Text(
          isHitter ? 'AVG' : 'ERA',
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

class _PlayerDetailCard extends StatelessWidget {
  final Map<String, dynamic> player;
  final bool isHitter;

  const _PlayerDetailCard({
    required this.player,
    required this.isHitter,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const Divider(height: 32),
              _buildPersonalInfo(),
              const Divider(height: 32),
              _buildStats(),
              const SizedBox(height: 16),
              Center(
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: (player['teamColor'] as Color).withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Icon(
              isHitter ? Icons.person : Icons.sports_baseball,
              color: player['teamColor'] as Color,
              size: 30,
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                player['name'] ?? 'Unknown Player',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${player['teamName']} · ${player['position']}',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPersonalInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Personal Information',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        _buildInfoRow('Position', player['position'] ?? 'N/A'),
        _buildInfoRow('Team', player['teamName'] ?? 'N/A'),
        if (player['birthDate'] != null)
          _buildInfoRow('Birth Date', player['birthDate']),
        if (player['birthPlace'] != null)
          _buildInfoRow('Birth Place', player['birthPlace']),
        if (player['height'] != null) 
          _buildInfoRow('Height', player['height']),
        if (player['weight'] != null)
          _buildInfoRow('Weight', '${player['weight']} lbs'),
        if (player['draftYear'] != null)
          _buildInfoRow('Draft Year', player['draftYear'].toString()),
        if (player['mlbDebutDate'] != null)
          _buildInfoRow('MLB Debut', player['mlbDebutDate']),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStats() {
    final stats = player['stats'] ?? {};
    final statsList = isHitter ? _getHitterStats(stats) : _getPitcherStats(stats);
    final midPoint = (statsList.length / 2).ceil();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Season Statistics',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left column
            Expanded(
              child: Column(
                children: statsList.take(midPoint).map((stat) => _buildStatRow(stat)).toList(),
              ),
            ),
            const SizedBox(width: 24),
            // Right column
            Expanded(
              child: Column(
                children: statsList.skip(midPoint).map((stat) => _buildStatRow(stat)).toList(),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatRow(_StatItem stat) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            stat.label,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 14,
            ),
          ),
          Text(
            stat.value?.toString() ?? '---',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: stat.isHighlighted ? 16 : 14,
              color: stat.isHighlighted ? player['teamColor'] as Color : null,
            ),
          ),
        ],
      ),
    );
  }

  List<_StatItem> _getHitterStats(Map<String, dynamic> stats) {
   return [
     _StatItem(stats['avg'], 'AVG', true),
     _StatItem(stats['gamesPlayed'], 'Games'),
     _StatItem(stats['atBats'], 'AB'),
     _StatItem(stats['hits'], 'Hits'),
     _StatItem(stats['doubles'], '2B'),
     _StatItem(stats['triples'], '3B'), 
     _StatItem(stats['homeRuns'], 'HR'),
     _StatItem(stats['rbi'], 'RBI'),
     _StatItem(stats['runs'], 'Runs'),
     _StatItem(stats['stolenBases'], 'SB'),
     _StatItem(stats['baseOnBalls'], 'BB'),
     _StatItem(stats['strikeOuts'], 'SO'),
     _StatItem(stats['obp'], 'OBP'),
     _StatItem(stats['slg'], 'SLG'),
     _StatItem(stats['ops'], 'OPS'),
   ];
 }

 List<_StatItem> _getPitcherStats(Map<String, dynamic> stats) {
   return [
     _StatItem(stats['era'], 'ERA', true),
     _StatItem(stats['gamesPlayed'], 'Games'),
     _StatItem(stats['gamesStarted'], 'GS'),
     _StatItem('${stats['wins'] ?? '0'}-${stats['losses'] ?? '0'}', 'W-L'),
     _StatItem(stats['inningsPitched'], 'IP'),
     _StatItem(stats['hits'], 'Hits'),
     _StatItem(stats['runs'], 'Runs'),
     _StatItem(stats['earnedRuns'], 'ER'),
     _StatItem(stats['homeRuns'], 'HR'),
     _StatItem(stats['baseOnBalls'], 'BB'),
     _StatItem(stats['strikeOuts'], 'SO'),
     _StatItem(stats['whip'], 'WHIP'),
     _StatItem(stats['saves'], 'SV'),
     _StatItem(stats['holds'], 'HLD'),
     _StatItem(stats['blownSaves'], 'BS'),
   ];
 }
}

class _StatItem {
 final dynamic value;
 final String label;
 final bool isHighlighted;

 const _StatItem(this.value, this.label, [this.isHighlighted = false]);
}

class _EmptyStateCard extends StatelessWidget {
 final String message;

 const _EmptyStateCard({required this.message});

 @override
 Widget build(BuildContext context) {
   return Card(
     margin: EdgeInsets.zero,
     child: Padding(
       padding: const EdgeInsets.all(16),
       child: Center(
         child: Text(
           message,
           style: TextStyle(
             color: Colors.grey[600],
             fontSize: 14,
           ),
         ),
       ),
     ),
   );
 }
}