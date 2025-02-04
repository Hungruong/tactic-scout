import requests
from config import MLB_API_BASE_URL

GUARDIANS_ID = 114
YANKEES_ID = 147

def get_mlb_player_by_number(number, teams=[GUARDIANS_ID, YANKEES_ID]):  
    """
    Get MLB player information by jersey number for specific teams.
    Args:
        number: Jersey number to search for.
        teams: List of team IDs to search in (Guardians first, then Yankees).
    Returns:
        List of players with matching jersey number.
    """
    players = []
    
    try:
        for team_id in teams:
            url = f"{MLB_API_BASE_URL}/teams/{team_id}/roster"
            params = {"rosterType": "active"}
            
            response = requests.get(url, params=params)
            response.raise_for_status()
            data = response.json()
            
            roster = data.get("roster", [])
            for player in roster:
                if player.get("jerseyNumber") == str(number):
                    team_name = "Guardians" if team_id == GUARDIANS_ID else "Yankees"
                    player["team"] = team_name
                    players.append(player)
            
            # Nếu tìm thấy cầu thủ trong Guardians, dừng tìm kiếm
            if players:
                break 
        
        return players
        
    except requests.exceptions.RequestException as e:
        print(f"Error fetching MLB data: {e}")
        return None

def get_player_stats(player_id):
    """
    Get player statistics for the current season
    Args:
        player_id: MLB player ID
    Returns:
        Dictionary containing player's hitting/pitching stats
    """
    url = f"{MLB_API_BASE_URL}/people/{player_id}/stats"
    params = {
        "stats": "season",
        "group": "hitting,pitching",
        "season": "2024"
    }
    
    try:
        response = requests.get(url, params=params)
        response.raise_for_status()
        data = response.json()
        
        stats = {
            'hitting': {
                'avg': '---',
                'hr': 0,
                'rbi': 0,
                'hits': 0,
                'games': 0
            },
            'pitching': {
                'era': '---',
                'wins': 0,
                'losses': 0,
                'strikeOuts': 0,
                'inningsPitched': 0,
                'games': 0
            }
        }
        
        if 'stats' in data:
            for stat_group in data['stats']:
                if stat_group['group']['displayName'] == 'hitting' and stat_group.get('splits'):
                    hitting_stats = stat_group['splits'][0]['stat']
                    stats['hitting'] = {
                        'avg': hitting_stats.get('avg', '---'),
                        'hr': hitting_stats.get('homeRuns', 0),
                        'rbi': hitting_stats.get('rbi', 0),
                        'hits': hitting_stats.get('hits', 0),
                        'games': hitting_stats.get('gamesPlayed', 0)
                    }
                elif stat_group['group']['displayName'] == 'pitching' and stat_group.get('splits'):
                    pitching_stats = stat_group['splits'][0]['stat']
                    stats['pitching'] = {
                        'era': pitching_stats.get('era', '---'),
                        'wins': pitching_stats.get('wins', 0),
                        'losses': pitching_stats.get('losses', 0),
                        'strikeOuts': pitching_stats.get('strikeOuts', 0),
                        'inningsPitched': pitching_stats.get('inningsPitched', 0),
                        'games': pitching_stats.get('gamesPlayed', 0)
                    }
        
        return stats
        
    except requests.exceptions.RequestException as e:
        print(f"Error fetching player stats: {e}")
        return None

def display_player_info(player, stats=None):
    """
    Display formatted player information and statistics
    Args:
        player: Player information dictionary
        stats: Optional player statistics dictionary
    """
    print(f"\nPlayer Information:")
    print(f"Name: {player.get('person', {}).get('fullName')}")
    print(f"Jersey Number: {player.get('jerseyNumber')}")
    print(f"Team: {player.get('team', 'Unknown')}")
    print(f"Position: {player.get('position', {}).get('name')}")
    
    if stats:
        print("\n2024 Season Stats:")
        if player.get('position', {}).get('name') == 'Pitcher':
            pitching = stats['pitching']
            print(f"ERA: {pitching.get('era', '---')}")
            print(f"Win-Loss: {pitching.get('wins', 0)}-{pitching.get('losses', 0)}")
            print(f"Strikeouts: {pitching.get('strikeOuts', 0)}")
            print(f"Innings: {pitching.get('inningsPitched', 0)}")
            print(f"Games Played: {pitching.get('games', 0)}")
        else:
            hitting = stats['hitting']
            print(f"AVG: {hitting.get('avg', '---')}")
            print(f"Home Runs: {hitting.get('hr', 0)}")
            print(f"RBI: {hitting.get('rbi', 0)}")
            print(f"Hits: {hitting.get('hits', 0)}")
            print(f"Games Played: {hitting.get('games', 0)}")