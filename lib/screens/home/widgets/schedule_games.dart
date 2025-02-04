import 'package:flutter/material.dart';
import '../../../models/game.dart';
import '../../../services/mlb_services.dart';
import 'package:intl/intl.dart';
import 'package:flutter_svg/flutter_svg.dart';

class ScheduleGamesSection extends StatefulWidget {
  const ScheduleGamesSection({super.key});

  @override
  State<ScheduleGamesSection> createState() => _ScheduleGamesSectionState();
}

class _ScheduleGamesSectionState extends State<ScheduleGamesSection> {
  final MLBService _mlbService = MLBService();
  Map<DateTime, List<Game>> _gamesByDate = {};
  DateTime? _selectedDate;
  bool _isLoading = true;
  static const int _gamesLimit = 3; // Show 9 games total

  @override
  void initState() {
    super.initState();
    _fetchGames();
  }

  Future<void> _fetchGames() async {
    setState(() => _isLoading = true);
    try {
      final response = await _mlbService.getScheduleGames(_gamesLimit);
      final dates = response['dates'] as List;
      
      final Map<DateTime, List<Game>> newGamesByDate = {};
      
      for (var dateData in dates) {
        final games = (dateData['games'] as List)
            .map((game) => Game.fromJson(game))
            .toList();
            
        if (games.isNotEmpty) {
          final gameDate = DateTime(
            games[0].gameDate.year,
            games[0].gameDate.month,
            games[0].gameDate.day,
          );
          newGamesByDate[gameDate] = games;
        }
      }

      setState(() {
        _gamesByDate = newGamesByDate;
        _selectedDate = _gamesByDate.keys.first;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error fetching scheduled games: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_gamesByDate.isEmpty) {
      return const Center(child: Text('No scheduled games available'));
    }

    final dates = _gamesByDate.keys.toList()..sort();

    return Column(
      children: [
        _buildDateSelector(dates),
        const SizedBox(height: 16),
        if (_selectedDate != null && _gamesByDate[_selectedDate]?.isNotEmpty == true)
          ..._gamesByDate[_selectedDate]!.map((game) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildGameCard(game),
              )),
      ],
    );
  }

  Widget _buildDateSelector(List<DateTime> dates) {
    return SizedBox(
      height: 36,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: dates.length,
        itemBuilder: (context, index) {
          final date = dates[index];
          final isSelected = _selectedDate?.day == date.day &&
              _selectedDate?.month == date.month &&
              _selectedDate?.year == date.year;
          
          return Container(
            margin: const EdgeInsets.only(right: 8),
            child: Material(
              color: isSelected ? const Color(0xFF0E3174) : Colors.grey[200],
              borderRadius: BorderRadius.circular(20),
              child: InkWell(
                onTap: () {
                  setState(() => _selectedDate = date);
                },
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text(
                    '${DateFormat('EEE').format(date)}, ${DateFormat('MMM d').format(date)}',
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.black87,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildGameCard(Game game) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTeamRow(game.team1, game.team1Logo),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Divider(
                height: 1,
                color: Colors.grey[300],
              ),
            ),
            _buildTeamRow(game.team2, game.team2Logo),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  Icons.access_time,
                  size: 16,
                  color: Colors.blue[600],
                ),
                const SizedBox(width: 4),
                Text(
                  DateFormat('h:mm a').format(game.gameDate),
                  style: TextStyle(
                    color: Colors.blue[600],
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 16),
                Icon(
                  Icons.location_on_outlined,
                  size: 16,
                  color: Colors.grey[600],
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    game.venue,
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTeamRow(String team, String logo) {
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
          child: SvgPicture.network(
            logo,
            fit: BoxFit.contain,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            team,
            style: const TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 16,
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ),
      ],
    );
  }
}