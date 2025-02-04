import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../services/mlb_services.dart';
import '../../models/game.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';


class LiveScreen extends StatefulWidget {
  const LiveScreen({super.key});

  @override
  State<LiveScreen> createState() => _LiveScreenState();
}

class _LiveScreenState extends State<LiveScreen> {
  final MLBService _mlbService = MLBService();
  final ScrollController _scrollController = ScrollController();
  List<Game>? _liveGames;
  Game? _selectedGame;
  Map<String, dynamic>? _tactics;
  bool _isLoading = true;
  bool _isLoadingTactics = false;
  bool _showPredictions = false;

  @override
  void initState() {
    super.initState();
    _fetchLiveGames();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchLiveGames() async {
    try {
      final games = await _mlbService.getLiveGames();
      setState(() {
        _liveGames = games;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error fetching live games: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchTactics(int gameId) async {
    setState(() {
      _isLoadingTactics = true;
      _tactics = null; // Reset tactics when loading new ones
    });
    
    try {
      final tactics = await _mlbService.getPredictedTactics(gameId);
      setState(() {
        _tactics = tactics;
        _isLoadingTactics = false;
      });
    } catch (e) {
      debugPrint('Error fetching tactics: $e');
      setState(() => _isLoadingTactics = false);
    }
  }

  String _formatAnalysisText(String text) {
    return text
        .replaceAll('**', '')
        .replaceAll('*', '')
        .replaceAll('\n\n****', '\n')
        .replaceAll('\n****', '\n');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Live Games',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        elevation: 0,
      ),
      body: Stack(
        children: [
          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else
            _buildBody(),
          if (_selectedGame != null && _showPredictions)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _buildTacticsPanel(),
            ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_liveGames == null || _liveGames!.isEmpty) {
      return const Center(
        child: Text('No live games at the moment'),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _liveGames!.length,
      itemBuilder: (context, index) {
        final game = _liveGames![index];
        return _buildGameCard(game);
      },
    );
  }

  Widget _buildGameCard(Game game) {
    final isSelected = _selectedGame?.gameId == game.gameId;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: isSelected ? 4 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isSelected ? Theme.of(context).primaryColor : Colors.transparent,
          width: 2,
        ),
      ),
      child: InkWell(
        onTap: () {
          setState(() {
            if (_selectedGame?.gameId == game.gameId) {
              _showPredictions = !_showPredictions;
            } else {
              _selectedGame = game;
              _showPredictions = true;
              _fetchTactics(game.gameId);
            }
          });
        },
        onLongPress: null,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: _buildTeamInfo(game.team1Logo, game.team1, game.score1, true),
                  ),
                  Column(
                    children: [
                      const Text(
                        'VS',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.fiber_manual_record,
                              color: Colors.red,
                              size: 12,
                            ),
                            SizedBox(width: 4),
                            Text(
                              'LIVE',
                              style: TextStyle(
                                color: Colors.red,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  Expanded(
                    child: _buildTeamInfo(game.team2Logo, game.team2, game.score2, false),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.location_on_outlined, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    game.venue,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTeamInfo(String logo, String name, String? score, bool isLeftTeam) {
    return Column(
      crossAxisAlignment: isLeftTeam ? CrossAxisAlignment.start : CrossAxisAlignment.end,
      children: [
        Container(
          width: 60,
          height: 60,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: SvgPicture.network(
            logo,
            fit: BoxFit.contain,
            placeholderBuilder: (context) => const Center(
              child: CircularProgressIndicator(),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          name,
          textAlign: isLeftTeam ? TextAlign.left : TextAlign.right,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        if (score != null)
          Text(
            score,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
      ],
    );
  }

  Widget _buildTacticsPanel() {
  // Color list for pie chart sections
  final List<Color> chartColors = [
    const Color(0xFF0D47A1), // Darkest Blue
    const Color(0xFFE65100), // Darkest Orange
    const Color(0xFF1B5E20), // Darkest Green
    const Color(0xFFB71C1C), // Darkest Red
    const Color(0xFF4A148C), // Darkest Purple
    const Color(0xFF01579B), // Darkest Light Blue
    const Color(0xFFF57F17), // Darkest Yellow
    const Color(0xFF4E342E), // Darkest Brown
    const Color(0xFF263238), // Darkest Grey
  ];



  // Helper function to process tactics data
  List<Map<String, dynamic>> processTactics(Map<String, dynamic>? tactics) {
    final List<Map<String, dynamic>> allTactics = [];
    
    if (tactics == null || !tactics.containsKey('tactical_probabilities')) {
      return allTactics;
    }

    final tacticalProbs = tactics['tactical_probabilities'];
    if (tacticalProbs is! Map) {
      return allTactics;
    }

    tacticalProbs.forEach((category, values) {
      if (values is Map) {
        values.forEach((name, value) {
          if (value is num) {
            String displayName = name.toString()
                .split('_')
                .map((word) => word[0].toUpperCase() + word.substring(1).toLowerCase())
                .join(' ');
            
            allTactics.add({
              'name': displayName,
              'value': value.toDouble(),
            });
          }
        });
      }
    });

    // Sort by value descending
    allTactics.sort((a, b) => (b['value'] as double).compareTo(a['value'] as double));

    // Calculate total and add others if needed
    final total = allTactics.fold<double>(
      0, (sum, item) => sum + (item['value'] as double));

    if (total < 100) {
      allTactics.add({
        'name': 'Others',
        'value': double.parse((100 - total).toStringAsFixed(1)),
      });
    }

    return allTactics;
  }

  return Container(
    width: double.infinity,
    constraints: BoxConstraints(
      maxHeight: MediaQuery.of(context).size.height * 0.5,
    ),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.1),
          blurRadius: 8,
          offset: const Offset(0, -2),
        ),
      ],
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          child: Column(
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Tactics Prediction',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => setState(() => _showPredictions = false),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Content area with pie chart
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_isLoadingTactics)
                  const Center(child: CircularProgressIndicator())
                else if (_tactics != null && _tactics!.containsKey('tactical_probabilities'))
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Pie Chart
                      SizedBox(
                        height: 300,
                        child: Stack(
                          children: [
                            PieChart(
                              PieChartData(
                                sectionsSpace: 2,
                                centerSpaceRadius: 40,
                                sections: processTactics(_tactics!).asMap().entries.map((entry) {
                                  final index = entry.key;
                                  final item = entry.value;
                                  return PieChartSectionData(
                                    color: chartColors[index % chartColors.length].withOpacity(0.85),
                                    value: item['value'],
                                    title: '${item['value'].toStringAsFixed(1)}%',
                                    radius: 100,
                                    titleStyle: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                    showTitle: item['value'] >= 5 || item['name'] == 'Others',
                                  );
                                }).toList(),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Legend
                      const SizedBox(height: 24),
                      Wrap(
                        spacing: 16,
                        runSpacing: 12,
                        children: processTactics(_tactics!).asMap().entries.map((entry) {
                          final index = entry.key;
                          final item = entry.value;
                          return Container(
                            constraints: const BoxConstraints(minWidth: 120),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 12,
                                  height: 12,
                                  decoration: BoxDecoration(
                                    color: chartColors[index % chartColors.length],
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    '${item['name']} (${item['value'].toStringAsFixed(1)}%)',
                                    style: const TextStyle(
                                      fontSize: 12,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // Analysis text
                      if (_tactics!.containsKey('gemini_analysis') && 
                          _tactics!['gemini_analysis'] != null)
                        Text(
                          _tactics!['gemini_analysis']
                              .toString()
                              .split('Analysis:')
                              .last
                              .replaceAll('**', '')
                              .replaceAll('****', '')
                              .trim(),
                          style: const TextStyle(
                            fontSize: 14,
                            height: 1.5,
                            color: Colors.grey,
                          ),
                        ),
                    ],
                  )
                else
                  const Center(
                    child: Text(
                      'No tactical data available',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
  }
}