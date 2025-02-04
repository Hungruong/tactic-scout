import 'dart:async';

import 'package:flutter/material.dart';
import '../../services/mlb_services.dart';

class PlayersScreen extends StatefulWidget {
  const PlayersScreen({super.key});

  @override
  State<PlayersScreen> createState() => _PlayersScreenState();
}

class _PlayersScreenState extends State<PlayersScreen> {
  Timer? _debounce;
  final MLBService _mlbService = MLBService();
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  
  List<Map<String, dynamic>> _players = [];
  bool _isLoading = false;
  bool _hasMore = true;
  int _currentPage = 1;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadInitialPlayers();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      setState(() {
        _searchQuery = query;
        _currentPage = 1;  // Reset về trang đầu khi search
        _players.clear();  // Clear danh sách cũ
        _loadInitialPlayers();  // Load lại với query mới
      });
    });
  }

  Future<void> _loadInitialPlayers() async {
    if (_isLoading) return;
    
    setState(() => _isLoading = true);
    try {
      final players = await _mlbService.getAllPlayers(
        page: 1,
        limit: 10,
        search: _searchQuery.trim(),  // Thêm trim() để loại bỏ khoảng trắng
      );
      
      if (mounted) {
        setState(() {
          _players = players;
          _currentPage = 1;
          _hasMore = players.length >= 10;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading players: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _players = [];
        });
      }
    }
  }

  Future<void> _loadMorePlayers() async {
    if (_isLoading || !_hasMore) return;
    
    setState(() => _isLoading = true);
    try {
      final morePlayers = await _mlbService.getAllPlayers(
        page: _currentPage + 1,
        limit: 10,
        search: _searchQuery.trim(),  // Thêm trim() để loại bỏ khoảng trắng
      );
      
      if (mounted) {
        setState(() {
          _players.addAll(morePlayers);
          _currentPage++;
          _hasMore = morePlayers.length >= 10;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading more players: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= 
        _scrollController.position.maxScrollExtent - 200) {
      _loadMorePlayers();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: SearchBar(
              controller: _searchController,
              hintText: 'Search players...',
              onChanged: _onSearchChanged,  // Sử dụng hàm mới
              leading: const Icon(Icons.search),
              padding: const MaterialStatePropertyAll<EdgeInsets>(
                EdgeInsets.symmetric(horizontal: 16.0),
              ),
            ),
          ),
          Expanded(
            child: _players.isEmpty && !_isLoading
                ? const Center(child: Text('No players found'))
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: _players.length + (_hasMore ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index >= _players.length) {
                        return _isLoading
                            ? const Center(
                                child: Padding(
                                  padding: EdgeInsets.symmetric(vertical: 16),
                                  child: CircularProgressIndicator(),
                                ),
                              )
                            : const SizedBox();
                      }

                      final player = _players[index];
                      return _buildPlayerCard(player);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayerCard(Map<String, dynamic> player) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () => _showPlayerDetails(player),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              _buildPlayerAvatar(player),
              const SizedBox(width: 12),
              Expanded(
                child: _buildPlayerInfo(player),
              ),
              _buildMainStat(player),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlayerAvatar(Map<String, dynamic> player) {
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
              player['isPitcher'] == true ? Icons.sports_baseball : Icons.person,
              color: player['teamColor'] as Color,
              size: 24,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPlayerInfo(Map<String, dynamic> player) {
    return Column(
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
    );
  }

  Widget _buildMainStat(Map<String, dynamic> player) {
    final stats = player['stats'] ?? {};
    final isPitcher = player['isPitcher'] == true;
    
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          isPitcher ? (stats['era']?.toString() ?? '---') : (stats['avg']?.toString() ?? '---'),
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        Text(
          isPitcher ? 'ERA' : 'AVG',
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  void _showPlayerDetails(Map<String, dynamic> player) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
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
                _buildDetailHeader(player),
                const Divider(height: 32),
                _buildDetailInfo(player),
                const Divider(height: 32),
                _buildDetailStats(player),
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
      ),
    );
  }

  Widget _buildDetailHeader(Map<String, dynamic> player) {
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
              player['isPitcher'] == true ? Icons.sports_baseball : Icons.person,
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

  Widget _buildDetailInfo(Map<String, dynamic> player) {
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

  Widget _buildDetailStats(Map<String, dynamic> player) {
    final stats = player['stats'] ?? {};
    final statsList = player['isPitcher'] == true 
        ? _getPitcherStats(stats) 
        : _getHitterStats(stats);
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
            Expanded(
              child: Column(
                children: statsList.take(midPoint).map((stat) => _buildStatRow(stat, player['teamColor'] as Color)).toList(),
              ),
            ),
            const SizedBox(width: 24),
            Expanded(
              child: Column(
                children: statsList.skip(midPoint).map((stat) => _buildStatRow(stat, player['teamColor'] as Color)).toList(),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatRow(_StatItem stat, Color teamColor) {
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
              color: stat.isHighlighted ? teamColor : null,
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