class Game {
  final int gameId;
  final String team1;
  final String team2;
  final String team1Logo;
  final String team2Logo;
  final String? score1;
  final String? score2;
  final DateTime gameDate;
  final String venue;
  final int team1Id;
  final int team2Id;
  final String status;

  Game({
    required this.gameId,
    required this.team1,
    required this.team2,
    required this.team1Logo,
    required this.team2Logo,
    this.score1,
    this.score2,
    required this.gameDate,
    required this.venue,
    required this.team1Id,
    required this.team2Id,
    this.status = 'Scheduled',
  });

  factory Game.fromJson(Map<String, dynamic> json) {
    final awayTeam = json['teams']['away']['team'];
    final homeTeam = json['teams']['home']['team'];
    final venue = json['teams']['home']['team']['venue'] ?? {};

    String getTeamLogoUrl(int teamId) {
      return 'https://www.mlbstatic.com/team-logos/$teamId.svg';
    }

    return Game(
      gameId: json['gamePk'] ?? 0,
      team1: awayTeam['name'] ?? 'Away Team',
      team2: homeTeam['name'] ?? 'Home Team',
      team1Id: awayTeam['id'] ?? 0,
      team2Id: homeTeam['id'] ?? 0,
      team1Logo: getTeamLogoUrl(awayTeam['id']),
      team2Logo: getTeamLogoUrl(homeTeam['id']),
      score1: json['teams']?['away']?['score']?.toString(),
      score2: json['teams']?['home']?['score']?.toString(),
      gameDate: DateTime.parse(json['gameDate']),
      venue: venue['name'] ?? 'TBD',
      status: json['status']?['detailedState'] ?? 'Scheduled',
    );
  }
}