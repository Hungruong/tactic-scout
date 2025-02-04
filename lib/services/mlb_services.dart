import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../models/game.dart';

class MLBService {
  static const baseUrl = 'statsapi.mlb.com';
  static const predictApiUrl = 'http://10.0.2.2:8000';

  // Schedule Related Methods
  Future<Map<String, dynamic>> getSchedule() async {
    final initialData = await _fetchScheduleForRange(
      startDate: DateTime.now(),
      daysForward: 7,
    );

    if (_isEmptySchedule(initialData)) {
      print('No games found in initial range, searching for next available games...');
      return _findNextAvailableGames();
    }

    return initialData;
  }

  Future<Map<String, dynamic>> getScheduleGames(int limit) async {
    try {
      final startDate = DateTime.now();
      final endDate = startDate.add(const Duration(days: 30));
      
      final queryParams = {
        'hydrate': 'team,venue,game(content(summary))',
        'sportId': '1',
        'startDate': _formatDate(startDate),
        'endDate': _formatDate(endDate),
        'gameTypes': ['R', 'S', 'E'].join(','),
        'language': 'en',
        'sortBy': 'gameDate',
      };

      final uri = Uri.https(baseUrl, '/api/v1/schedule', queryParams);
      print('Requesting schedule games URL: $uri');
      
      final response = await http.get(uri);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return _processScheduleGames(data, limit);
      }
      throw Exception('Failed to load schedule games: ${response.statusCode}');
    } catch (e) {
      print('Error fetching schedule games: $e');
      rethrow;
    }
  }

  // Live Games and Game Status Methods
  Future<List<Game>> getLiveGames() async {
    return [
      Game(
          gameId: 717446,
          team1: "Chicago Cubs",
          team2: "Los Angeles Dodgers", 
          team1Id: 112,
          team2Id: 119,
          team1Logo: 'https://www.mlbstatic.com/team-logos/112.svg',
          team2Logo: 'https://www.mlbstatic.com/team-logos/119.svg',
          score1: "3",
          score2: "2",
          gameDate: DateTime.now(),
          venue: "Dodger Stadium",
          status: "In Progress"
      ),
      Game(
          gameId: 717447,
          team1: "New York Yankees",
          team2: "Boston Red Sox",
          team1Id: 147,
          team2Id: 111,
          team1Logo: 'https://www.mlbstatic.com/team-logos/147.svg',
          team2Logo: 'https://www.mlbstatic.com/team-logos/111.svg',
          score1: "5",
          score2: "4",
          gameDate: DateTime.now(),
          venue: "Fenway Park",
          status: "In Progress"
      ),
      Game(
          gameId: 717448,
          team1: "San Francisco Giants",
          team2: "Los Angeles Angels",
          team1Id: 137,
          team2Id: 108,
          team1Logo: 'https://www.mlbstatic.com/team-logos/137.svg',
          team2Logo: 'https://www.mlbstatic.com/team-logos/108.svg',
          score1: "2",
          score2: "1",
          gameDate: DateTime.now(),
          venue: "Angel Stadium",
          status: "In Progress"
      ),
    ];
  }

  Future<Map<String, dynamic>> getPredictedTactics(int gameId) async {
    try {
      final response = await http.get(
        Uri.parse('$predictApiUrl/predict/$gameId'),
      );

      print('Predict API Response: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        // Return the entire data object
        if (data is Map<String, dynamic>) {
          return data;
        }

        print('Invalid data format received');
        return {
          'tactical_probabilities': {},
          'gemini_analysis': 'Invalid data format received'
        };
      }

      print('Failed to get tactics: ${response.statusCode}');
      return {
        'tactical_probabilities': {},
        'gemini_analysis': 'Failed to fetch analysis. Status code: ${response.statusCode}'
      };
    } catch (e) {
      print('Error getting predicted tactics: $e');
      return {
        'tactical_probabilities': {},
        'gemini_analysis': 'Error: $e'
      };
    }
  }

  Future<Map<String, dynamic>> getGameStatus(int gameId) async {
    try {
      final response = await http.get(
        Uri.parse('$predictApiUrl/game/$gameId/status'),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      }

      print('Failed to get game status: ${response.statusCode}');
      return {};
    } catch (e) {
      print('Error getting game status: $e');
      return {};
    }
  }

  // Player Stats Methods
  Future<List<Map<String, dynamic>>> getTopHitters({int limit = 5}) async {
    try {
      final leadersParams = {
        'sportId': '1',
        'leaderCategories': 'battingAverage',  
        'season': '2024',
        'limit': limit.toString(),
        'leaderGameTypes': 'R',
        'statGroup': 'hitting'
      };

      final leadersUri = Uri.https(baseUrl, '/api/v1/stats/leaders', leadersParams);
      print('Requesting Leaders URL: $leadersUri');
      
      final leadersResponse = await http.get(leadersUri);
      if (leadersResponse.statusCode == 200) {
        final leadersData = json.decode(leadersResponse.body);
        final results = <Map<String, dynamic>>[];

        final leagueLeaders = leadersData['leagueLeaders'] as List? ?? [];
        for (var category in leagueLeaders) {
          final leaders = category['leaders'] as List? ?? [];
          
          for (var leader in leaders) {
            final person = leader['person'];
            final team = leader['team'];
            final playerId = person['id'];

            // Get player details
            final playerResponse = await http.get(
              Uri.https(baseUrl, '/api/v1/people/$playerId')
            );
            
            // Get player stats
            final statsResponse = await http.get(
              Uri.https(baseUrl, '/api/v1/people/$playerId/stats', {
                'stats': 'season',
                'group': 'hitting',
                'season': '2024',
                'gameType': 'R'
              })
            );

            if (playerResponse.statusCode == 200 && statsResponse.statusCode == 200) {
              final playerData = json.decode(playerResponse.body);
              final statsData = json.decode(statsResponse.body);
              final player = playerData['people']?[0];
              
              Map<String, dynamic> stats = {};
              if (statsData['stats'] != null && statsData['stats'].isNotEmpty) {
                stats = statsData['stats'][0]['splits']?[0]?['stat'] ?? {};
              }

              results.add({
                'id': playerId,
                'name': person['fullName'],
                'position': player?['primaryPosition']?['name'] ?? 'Batter',
                'teamName': team['name'],
                'teamColor': _getTeamColor(int.parse(team['id'].toString())),
                'isPitcher': false,
                'birthDate': player?['birthDate'],
                'birthPlace': '${player?['birthCity'] ?? ''}, ${player?['birthStateProvince'] ?? ''}, ${player?['birthCountry'] ?? ''}',
                'height': player?['height'],
                'weight': player?['weight'],
                'draftYear': player?['draftYear'],
                'mlbDebutDate': player?['mlbDebutDate'],
                'stats': stats
              });
            }
          }
        }
        return results;
      }
      return [];
    } catch (e) {
      print('Error fetching hitting stats: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getTopPitchers({int limit = 5}) async {
    try {
      final leadersParams = {
        'sportId': '1',
        'leaderCategories': 'earnedRunAverage',
        'season': '2024',
        'limit': limit.toString(),
        'leaderGameTypes': 'R',
        'statGroup': 'pitching'
      };

      final leadersUri = Uri.https(baseUrl, '/api/v1/stats/leaders', leadersParams);
      print('Requesting Leaders URL: $leadersUri');
      
      final leadersResponse = await http.get(leadersUri);
      if (leadersResponse.statusCode == 200) {
        final leadersData = json.decode(leadersResponse.body);
        final results = <Map<String, dynamic>>[];

        final leagueLeaders = leadersData['leagueLeaders'] as List? ?? [];
        for (var category in leagueLeaders) {
          final leaders = category['leaders'] as List? ?? [];
          
          for (var leader in leaders) {
            final person = leader['person'];
            final team = leader['team'];
            final playerId = person['id'];

            // Get player details
            final playerResponse = await http.get(
              Uri.https(baseUrl, '/api/v1/people/$playerId')
            );
            
            // Get player stats
            final statsResponse = await http.get(
              Uri.https(baseUrl, '/api/v1/people/$playerId/stats', {
                'stats': 'season',
                'group': 'pitching',
                'season': '2024',
                'gameType': 'R'
              })
            );

            if (playerResponse.statusCode == 200 && statsResponse.statusCode == 200) {
              final playerData = json.decode(playerResponse.body);
              final statsData = json.decode(statsResponse.body);
              final player = playerData['people']?[0];
              
              Map<String, dynamic> stats = {};
              if (statsData['stats'] != null && statsData['stats'].isNotEmpty) {
                stats = statsData['stats'][0]['splits']?[0]?['stat'] ?? {};
              }

              results.add({
                'id': playerId,
                'name': person['fullName'],
                'position': 'Pitcher',
                'teamName': team['name'],
                'teamColor': _getTeamColor(int.parse(team['id'].toString())),
                'isPitcher': true,
                'birthDate': player?['birthDate'],
                'birthPlace': '${player?['birthCity'] ?? ''}, ${player?['birthStateProvince'] ?? ''}, ${player?['birthCountry'] ?? ''}',
                'height': player?['height'],
                'weight': player?['weight'],
                'draftYear': player?['draftYear'],
                'mlbDebutDate': player?['mlbDebutDate'],
                'stats': stats
              });
            }
          }
        }
        return results;
      }
      return [];
    } catch (e) {
      print('Error fetching pitching stats: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getAllPlayers({
  int page = 1,
  int limit = 10,
  String? search,
  }) async {
  try {
    final List<Map<String, dynamic>> allResults = [];

    // 1. Get batters
    final batterParams = {
      'sportId': '1',
      'season': '2024',
      'leaderCategories': 'battingAverage',
      'limit': '50', // Get more data for pagination
      'leaderGameTypes': 'R',
      'statGroup': 'hitting',
    };

    // 2. Get pitchers 
    final pitcherParams = {
      'sportId': '1', 
      'season': '2024',
      'leaderCategories': 'earnedRunAverage',
      'limit': '50', // Get more data for pagination
      'leaderGameTypes': 'R',
      'statGroup': 'pitching',
    };

    // Call APIs concurrently for better performance
    final battersFuture = http.get(Uri.https(baseUrl, '/api/v1/stats/leaders', batterParams));
    final pitchersFuture = http.get(Uri.https(baseUrl, '/api/v1/stats/leaders', pitcherParams));

    final responses = await Future.wait([battersFuture, pitchersFuture]);
    final battersData = json.decode(responses[0].body);
    final pitchersData = json.decode(responses[1].body);

    // Process batters
    for (var category in (battersData['leagueLeaders'] as List? ?? [])) {
      for (var leader in (category['leaders'] as List? ?? [])) {
        final person = leader['person'];
        final team = leader['team'];
        final playerId = person['id'];

        // Get player details and stats concurrently
        final playerFuture = http.get(Uri.https(baseUrl, '/api/v1/people/$playerId'));
        final statsFuture = http.get(
          Uri.https(baseUrl, '/api/v1/people/$playerId/stats', {
            'stats': 'season',
            'group': 'hitting',
            'season': '2024',
            'gameType': 'R'
          })
        );

        final playerResponses = await Future.wait([playerFuture, statsFuture]);
        final playerResponse = playerResponses[0];
        final statsResponse = playerResponses[1];

        if (playerResponse.statusCode == 200 && statsResponse.statusCode == 200) {
          final playerData = json.decode(playerResponse.body);
          final statsData = json.decode(statsResponse.body);
          final player = playerData['people']?[0];

          Map<String, dynamic> stats = {};
          if (statsData['stats'] != null && statsData['stats'].isNotEmpty) {
            stats = statsData['stats'][0]['splits']?[0]?['stat'] ?? {};
          }

          allResults.add({
            'id': playerId,
            'name': person['fullName'],
            'position': player?['primaryPosition']?['name'] ?? 'Batter',
            'teamName': team['name'],
            'teamColor': _getTeamColor(int.parse(team['id'].toString())),
            'isPitcher': false,
            'birthDate': player?['birthDate'],
            'birthPlace': _formatBirthPlace(
              city: player?['birthCity'],
              state: player?['birthStateProvince'],
              country: player?['birthCountry']
            ),
            'height': player?['height'],
            'weight': player?['weight'],
            'draftYear': player?['draftYear'],
            'mlbDebutDate': player?['mlbDebutDate'],
            'stats': stats
          });
        }
      }
    }

    // Process pitchers
    for (var category in (pitchersData['leagueLeaders'] as List? ?? [])) {
      for (var leader in (category['leaders'] as List? ?? [])) {
        final person = leader['person'];
        final team = leader['team'];
        final playerId = person['id'];

        // Get player details and stats concurrently
        final playerFuture = http.get(Uri.https(baseUrl, '/api/v1/people/$playerId'));
        final statsFuture = http.get(
          Uri.https(baseUrl, '/api/v1/people/$playerId/stats', {
            'stats': 'season',
            'group': 'pitching',
            'season': '2024',
            'gameType': 'R'
          })
        );

        final playerResponses = await Future.wait([playerFuture, statsFuture]);
        final playerResponse = playerResponses[0];
        final statsResponse = playerResponses[1];

        if (playerResponse.statusCode == 200 && statsResponse.statusCode == 200) {
          final playerData = json.decode(playerResponse.body);
          final statsData = json.decode(statsResponse.body);
          final player = playerData['people']?[0];

          Map<String, dynamic> stats = {};
          if (statsData['stats'] != null && statsData['stats'].isNotEmpty) {
            stats = statsData['stats'][0]['splits']?[0]?['stat'] ?? {};
          }

          allResults.add({
            'id': playerId,
            'name': person['fullName'],
            'position': 'Pitcher',
            'teamName': team['name'],
            'teamColor': _getTeamColor(int.parse(team['id'].toString())),
            'isPitcher': true,
            'birthDate': player?['birthDate'],
            'birthPlace': _formatBirthPlace(
              city: player?['birthCity'],
              state: player?['birthStateProvince'],
              country: player?['birthCountry']
            ),
            'height': player?['height'],
            'weight': player?['weight'],
            'draftYear': player?['draftYear'],
            'mlbDebutDate': player?['mlbDebutDate'],
            'stats': stats
          });
        }
      }
    }

    // Filter by search query if provided
    var filteredResults = allResults;
    if (search != null && search.isNotEmpty) {
      final searchLower = search.toLowerCase();
      filteredResults = allResults.where((player) {
        final name = player['name'].toString().toLowerCase();
        final team = player['teamName'].toString().toLowerCase();
        final position = player['position'].toString().toLowerCase();
        
        return name.contains(searchLower) || 
                team.contains(searchLower) ||
                position.contains(searchLower);
      }).toList();
    }

    // Sort results by name
    filteredResults.sort((a, b) => 
      (a['name'] ?? '').toString().compareTo((b['name'] ?? '').toString())
    );

    // Handle pagination
    final startIndex = (page - 1) * limit;
    if (startIndex >= filteredResults.length) {
      return [];
    }

    final endIndex = startIndex + limit;
    return filteredResults.sublist(
      startIndex,
      endIndex.clamp(0, filteredResults.length)
    );

  } catch (e) {
    print('Error fetching players: $e');
    return [];
  }
  }

// Helper method to format birth place consistently
String _formatBirthPlace({String? city, String? state, String? country}) {
 final parts = <String>[];
 if (city?.isNotEmpty ?? false) parts.add(city!);
 if (state?.isNotEmpty ?? false) parts.add(state!);
 if (country?.isNotEmpty ?? false) parts.add(country!);
 
 return parts.join(', ');
}

  // Helper Methods
  Map<String, dynamic> _processScheduleGames(Map<String, dynamic> data, int limit) {
    final List<dynamic> dates = data['dates'] ?? [];
    final List<Map<String, dynamic>> processedDates = [];
    int totalProcessedGames = 0;

    for (var date in dates) {
      if (totalProcessedGames >= limit) break;

      final List<dynamic> dateGames = date['games'] ?? [];
      final int remainingGames = limit - totalProcessedGames;
      final List<dynamic> limitedGames = dateGames.take(remainingGames).toList();

      if (limitedGames.isNotEmpty) {
        processedDates.add({
          'date': date['date'],
          'games': limitedGames,
        });
        totalProcessedGames += limitedGames.length;
      }
    }

    return {
      'copyright': data['copyright'],
      'totalGames': totalProcessedGames,
      'dates': processedDates,
    };
  }

  Future<Map<String, dynamic>> _findNextAvailableGames() async {
    DateTime startDate = DateTime.now();
    const maxAttempts = 12;
    
    for (int attempt = 0; attempt < maxAttempts; attempt++) {
      startDate = startDate.add(const Duration(days: 5));
      
      final data = await _fetchScheduleForRange(
        startDate: startDate,
        daysForward: 5,
      );
      
      if (!_isEmptySchedule(data)) {
        print('Found games starting from: ${_formatDate(startDate)}');
        return data;
      }
    }

    throw Exception('No games found in the next 60 days');
  }

  Future<Map<String, dynamic>> _fetchScheduleForRange({
    required DateTime startDate,
    required int daysForward,
  }) async {
    final endDate = startDate.add(Duration(days: daysForward));
    
    final queryParams = {
      'hydrate': 'team,venue,game(content(summary))',
      'sportId': '1',
      'startDate': _formatDate(startDate),
      'endDate': _formatDate(endDate),
      'gameTypes': ['R', 'S', 'E'].join(','),
      'language': 'en',
      'sortBy': 'gameDate',
    };

    try {
      final uri = Uri.https(baseUrl, '/api/v1/schedule', queryParams);
      print('Requesting URL: $uri');
      
      final response = await http.get(uri);
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      throw Exception('Failed to load schedule: ${response.statusCode}');
    } catch (e) {
      print('Error fetching schedule: $e');
      rethrow;
    }
  }

  List<Map<String, dynamic>> _processHittingStats(Map<String, dynamic> data) {
    try {
      final List<Map<String, dynamic>> results = [];
      final leagueLeaders = data['leagueLeaders'] as List? ?? [];
      
      for (var category in leagueLeaders) {
        final leaders = category['leaders'] as List? ?? [];
        for (var leader in leaders) {
          final person = leader['person'];
          final team = leader['team'];
          final seasonStats = leader['stats']?[0] ?? {};

          // In toàn bộ thông tin để debug
          print('Hitter Stats Raw Data:');
          print(json.encode(seasonStats));
          
          results.add({
            'id': person['id'],
            'name': person['fullName'],
            'position': person['primaryPosition']?['abbreviation'] ?? 'N/A',
            'teamName': team['name'],
            'teamColor': _getTeamColor(team['id']),
            'stats': {
              'avg': leader['value'],  // Batting average từ leader value
              'obp': seasonStats['obp']?.toString() ?? '---', // On-base percentage
              'slg': seasonStats['slg']?.toString() ?? '---', // Slugging
              'ops': seasonStats['ops']?.toString() ?? '---', // OPS
              'hr': seasonStats['homeRuns']?.toString() ?? '0', // Home runs
              'rbi': seasonStats['rbi']?.toString() ?? '0', // RBIs
              'hits': seasonStats['hits']?.toString() ?? '0', // Hits
              'runs': seasonStats['runs']?.toString() ?? '0', // Runs
              'sb': seasonStats['stolenBases']?.toString() ?? '0', // Stolen bases
              'bb': seasonStats['baseOnBalls']?.toString() ?? '0', // Walks
              'games': seasonStats['gamesPlayed']?.toString() ?? '0', // Games played
            }
          });
        }
      }
      return results;
    } catch (e) {
      print('Error processing hitting stats: $e');
      return [];
    }
  }

  List<Map<String, dynamic>> _processPitchingStats(Map<String, dynamic> data) {
    try {
      final List<Map<String, dynamic>> results = [];
      final leagueLeaders = data['leagueLeaders'] as List? ?? [];
      
      for (var category in leagueLeaders) {
        final leaders = category['leaders'] as List? ?? [];
        for (var leader in leaders) {
          final person = leader['person'];
          final team = leader['team'];
          final seasonStats = leader['stats']?[0] ?? {};

          // In toàn bộ thông tin để debug
          print('Pitcher Stats Raw Data:');
          print(json.encode(seasonStats));
          
          results.add({
            'id': person['id'],
            'name': person['fullName'],
            'position': 'P',
            'teamName': team['name'],
            'teamColor': _getTeamColor(team['id']),
            'stats': {
              'era': leader['value'], // ERA từ leader value
              'w': seasonStats['wins']?.toString() ?? '0', // Wins
              'l': seasonStats['losses']?.toString() ?? '0', // Losses
              'so': seasonStats['strikeOuts']?.toString() ?? '0', // Strikeouts
              'whip': seasonStats['whip']?.toString() ?? '---', // WHIP
              'ip': seasonStats['inningsPitched']?.toString() ?? '0.0', // Innings pitched
              'games': seasonStats['gamesPlayed']?.toString() ?? '0', // Games played
              'saves': seasonStats['saves']?.toString() ?? '0', // Saves
              'holds': seasonStats['holds']?.toString() ?? '0', // Holds
              'qs': seasonStats['qualityStarts']?.toString() ?? '0', // Quality starts
            }
          });
        }
      }
      return results;
    } catch (e) {
      print('Error processing pitching stats: $e');
      return [];
    }
  }

  List<Map<String, dynamic>> _processPlayers(Map<String, dynamic> data) {
    try {
      final List people = data['people'] ?? [];
      return people.map<Map<String, dynamic>>((person) {
        final team = person['currentTeam'] ?? {};
        final stats = person['stats'] ?? [];
        final isPitcher = person['primaryPosition']?['abbreviation'] == 'P';
        
        // Get season stats
        final seasonStats = stats.firstWhere(
          (stat) => 
            stat['group']?['displayName'] == (isPitcher ? 'pitching' : 'hitting') &&
            stat['type']?['displayName'] == 'Regular Season',
          orElse: () => {'splits': [{'stat': {}}]},
        );

        final statData = seasonStats['splits']?[0]?['stat'] ?? {};

        return {
          'id': person['id'],
          'name': person['fullName'] ?? 'Unknown Player',
          'position': person['primaryPosition']?['abbreviation'] ?? 'N/A',
          'teamName': team['name'] ?? 'Free Agent',
          'teamColor': _getTeamColor(team['id'] ?? 0),
          'isPitcher': isPitcher,
          'stats': isPitcher 
              ? _extractPitchingStats(statData)
              : _extractHittingStats(statData),
        };
      }).toList();
    } catch (e) {
      print('Error processing players: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getPlayers({
  int page = 1,
  int limit = 5,
  String? search,
  String position = 'hitting',
  String sortStat = 'battingAverage',
  String sortOrder = 'desc',
}) async {
  try {
    final queryParams = {
      'sportId': '1',
      'leaderCategories': sortStat,
      'season': DateTime.now().year.toString(),
      'limit': limit.toString(),
      'leaderGameTypes': 'R',
      'statGroup': position,  // 'pitching' or 'hitting'
      'hydrate': 'team,person',
    };

    final uri = Uri.https(baseUrl, '/api/v1/stats/leaders', queryParams);
      print('Requesting Players URL: $uri');
      
      final response = await http.get(uri);
      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final results = <Map<String, dynamic>>[];

        // Process data similarly to Python code
        final leagueLeaders = data['leagueLeaders'] as List? ?? [];
        for (var category in leagueLeaders) {
          final leaders = category['leaders'] as List? ?? [];
          for (var leader in leaders) {
            final person = leader['person'];
            final team = leader['team'];
            
            // Apply search filter if provided
            if (search != null && search.isNotEmpty) {
              final name = person['fullName']?.toString().toLowerCase() ?? '';
              if (!name.contains(search.toLowerCase())) continue;
            }

            results.add({
              'id': person['id'],
              'name': person['fullName'],
              'position': person['primaryPosition']?['abbreviation'] ?? 'N/A',
              'teamName': team['name'],
              'teamColor': _getTeamColor(team['id']),
              'isPitcher': position == 'pitching',
              'stats': position == 'pitching' 
                  ? {
                      'era': leader['value'],
                      'wins': leader['wins']?.toString() ?? '0',
                      'so': leader['strikeouts']?.toString() ?? '0',
                    }
                  : {
                      'avg': leader['value'],
                      'hr': leader['homeRuns']?.toString() ?? '0',
                      'rbi': leader['rbi']?.toString() ?? '0',
                    },
            });
          }
        }

        return results;
      }
      
      print('Failed to load players: ${response.statusCode}');
      return [];
    } catch (e) {
      print('Error fetching players: $e');
      return [];
    }
  }

  Map<String, String> _extractHittingStats(Map<String, dynamic> statData) {
    return {
      'avg': '.${((statData['avg'] ?? 0.0) * 1000).round().toString().padLeft(3, '0')}',
      'hr': statData['homeRuns']?.toString() ?? '0',
      'rbi': statData['rbi']?.toString() ?? '0',
      'hits': statData['hits']?.toString() ?? '0',
      'ops': (statData['ops'] ?? 0.0).toStringAsFixed(3),
    };
  }

  Map<String, String> _extractPitchingStats(Map<String, dynamic> statData) {
    return {
      'era': (statData['era'] ?? 0.0).toStringAsFixed(2),
      'wins': statData['wins']?.toString() ?? '0',
      'so': statData['strikeouts']?.toString() ?? '0',
      'whip': (statData['whip'] ?? 0.0).toStringAsFixed(2),
      'innings': statData['inningsPitched']?.toString() ?? '0.0',
    };
  }

  bool _isEmptySchedule(Map<String, dynamic> data) {
    final dates = data['dates'] as List?;
    return dates == null || dates.isEmpty || data['totalGames'] == 0;
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  Color _getTeamColor(int teamId) {
    final teamColors = {
      108: const Color(0xFFBA0021), // Angels
      109: const Color(0xFFA71930), // D-backs
      110: const Color(0xFF000000), // Orioles
      111: const Color(0xFFBD3039), // Red Sox
      112: const Color(0xFF0E3386), // Cubs
      113: const Color(0xFFC6011F), // Reds
      114: const Color(0xFF002B5C), // Guardians
      115: const Color(0xFF333366), // Rockies
      116: const Color(0xFF0C2340), // Tigers
      117: const Color(0xFF002D62), // Astros
      118: const Color(0xFF004687), // Royals
      119: const Color(0xFFBA0021), // Dodgers
      120: const Color(0xFF00A3E0), // Nationals
      121: const Color(0xFF002D72), // Mets
      133: const Color(0xFF003831), // Athletics
      134: const Color(0xFFE81828), // Pirates
      135: const Color(0xFF003149), // Padres
      136: const Color(0xFFFDB827), // Mariners
      137: const Color(0xFFFD5A1E), // Giants
      138: const Color(0xFF0C2340), // Cardinals
      139: const Color(0xFF092C5C), // Rays
      140: const Color(0xFFC0111F), // Rangers
      141: const Color(0xFF134A8E), // Blue Jays
      142: const Color(0xFF13274F), // Twins
      143: const Color(0xFF002B5C), // Phillies
      144: const Color(0xFF00594C), // Braves
      145: const Color(0xFF00A3E0), // White Sox
      146: const Color(0xFFBA0C2F), // Marlins
      147: const Color(0xFF12284B), // Yankees
      158: const Color(0xFF13294B), // Brewers
    };
    
    return teamColors[teamId] ?? Colors.grey;
  }
}