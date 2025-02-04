import requests
import time
from typing import List, Dict, Any, Optional
from datetime import datetime, timedelta

class MLBDataFetcher:
    def __init__(self, base_url: str = "https://statsapi.mlb.com/api"):
        self.base_url = base_url
        self.version = "v1.1"
        self.session = requests.Session()
    
    def _fetch_with_retries(self, url: str, max_retries: int = 5) -> Optional[Dict[str, Any]]:
        """Fetch data with retries and exponential backoff."""
        for attempt in range(max_retries):
            try:
                response = self.session.get(url, timeout=30)
                response.raise_for_status()
                return response.json()
            except requests.exceptions.RequestException as e:
                wait_time = min(2 ** attempt, 60)
                print(f"Attempt {attempt + 1} failed: {e}. Retrying in {wait_time} seconds...")
                time.sleep(wait_time)
                if attempt == max_retries - 1:
                    print(f"Max retries reached. Request to {url} failed.")
                    return None
    
    def fetch_live_game(self, game_id: int) -> Optional[Dict]:
        """Fetch live game data."""
        url = f"{self.base_url}/{self.version}/game/{game_id}/feed/live"
        return self._fetch_with_retries(url)
    
    def fetch_player(self, player_id: str, season: int = 2024) -> Optional[Dict]:
        """Fetch player data and stats."""
        url = f"{self.base_url}/v1/people/{player_id}"
        params = {
            "hydrate": f"stats(group=[hitting,pitching],type=season,season={season})"
        }
        return self._fetch_with_retries(f"{url}?{self._build_params(params)}")
    
    def fetch_team(self, team_id: int, season: int = 2024) -> Optional[Dict]:
        """Fetch team data including roster and stats."""
        url = f"{self.base_url}/v1/teams/{team_id}"
        params = {
            "hydrate": f"roster(person(stats(group=[hitting,pitching],type=season,season={season})))"
        }
        return self._fetch_with_retries(f"{url}?{self._build_params(params)}")
    
    def fetch_games_by_date(self, date: str) -> List[Dict]:
        """Fetch all games for a specific date."""
        url = f"{self.base_url}/v1/schedule"
        params = {
            "sportId": 1,
            "date": date,
            "hydrate": "game(content(highlights,summary)),probablePitcher,stats,lineup"
        }
        response = self._fetch_with_retries(f"{url}?{self._build_params(params)}")
        return self._extract_games(response)
    
    def fetch_season_games(self, season: int = 2024, team_id: Optional[int] = None, 
                          limit: Optional[int] = None) -> List[Dict]:
        """Fetch games from a specific season."""
        url = f"{self.base_url}/v1/schedule"
        params = {
            "sportId": 1,
            "season": season,
            "gameType": "R"  # Regular season only
        }
        if team_id:
            params["teamId"] = team_id
        
        games = []
        response = self._fetch_with_retries(f"{url}?{self._build_params(params)}")
        if response and 'dates' in response:
            print(f"Found {len(response['dates'])} game dates for season {season}")
            for date in response['dates']:
                for game in date['games']:
                    games.append({
                        'game_pk': game['gamePk'],
                        'date': date['date'],
                        'teams': {
                            'home': game['teams']['home']['team']['name'],
                            'away': game['teams']['away']['team']['name']
                        },
                        'status': game.get('status', {}).get('detailedState', '')
                    })
                    if limit and len(games) >= limit:
                        return games
        return games
    
    def fetch_historical_dataset(self, start_year: int = 2015, end_year: int = 2024, 
                               limit_per_year: Optional[int] = None) -> Dict[str, List[Dict]]:
        """Build comprehensive historical dataset from multiple seasons."""
        dataset = {
            'games': [],
            'player_stats': {},
            'team_stats': {}
        }
        
        total_games = 0
        total_plays = 0
        
        for year in range(start_year, end_year + 1):
            print(f"\nFetching season {year}...")
            year_games = self.fetch_season_games(season=year, limit=limit_per_year)
            processed_games = 0
            
            for game in year_games:
                game_data = self.fetch_live_game(game['game_pk'])
                if game_data:
                    # Count plays in this game
                    plays = len(game_data.get('liveData', {}).get('plays', {}).get('allPlays', []))
                    total_plays += plays
                    dataset['games'].append(game_data)
                    processed_games += 1
                    total_games += 1
                    
                    # Progress update every 50 games
                    if processed_games % 50 == 0:
                        print(f"Season {year}: Processed {processed_games}/{len(year_games)} games")
                        print(f"Total plays so far: {total_plays}")
                    
                    # Rate limiting sleep between game requests
                    time.sleep(0.5)
            
            print(f"Completed season {year}: {processed_games} games, {total_plays} total plays")
        
        # Print final statistics
        print(f"\nFinal stats:")
        print(f"Total seasons: {end_year - start_year + 1}")
        print(f"Total games: {total_games}")
        print(f"Total plays: {total_plays}")
        print(f"Average plays per game: {total_plays/max(total_games, 1):.1f}")
        
        return dataset
    
    def _build_params(self, params: Dict) -> str:
        """Build URL parameters string."""
        return "&".join(f"{k}={v}" for k, v in params.items())
    
    def _extract_games(self, response: Optional[Dict], limit: Optional[int] = None) -> List[Dict]:
        """Extract games from schedule response."""
        games = []
        if response and 'dates' in response:
            for date in response['dates']:
                for game in date['games']:
                    games.append({
                        'game_pk': game['gamePk'],
                        'date': date['date'],
                        'teams': {
                            'home': game['teams']['home']['team']['name'],
                            'away': game['teams']['away']['team']['name']
                        },
                        'status': game.get('status', {}).get('detailedState', '')
                    })
                    if limit and len(games) >= limit:
                        break
                if limit and len(games) >= limit:
                    break
        return games

    def _extract_player_ids(self, game_data: Dict) -> Dict[str, List[int]]:
        """Extract batter and pitcher IDs from all plays."""
        try:
            plays = game_data.get("liveData", {}).get("plays", {}).get("allPlays", [])
            batter_ids = []
            pitcher_ids = []
            
            for play in plays:
                matchup = play.get("matchup", {})
                batter_id = matchup.get("batter", {}).get("id")
                pitcher_id = matchup.get("pitcher", {}).get("id")
                
                if batter_id: batter_ids.append(batter_id)
                if pitcher_id: pitcher_ids.append(pitcher_id)
                
            return {
                'batters': list(set(batter_ids)),
                'pitchers': list(set(pitcher_ids))
            }
        except Exception as e:
            print(f"Error extracting player IDs: {e}")
            return {'batters': [], 'pitchers': []}

    def fetch_game_timecodes(self, game_id: int) -> List[str]:
        """Fetch list of available timecodes for a game."""
        url = f"{self.base_url}/{self.version}/game/{game_id}/feed/live/timestamps"
        response = self._fetch_with_retries(url)
        return response if response else []
    
    def fetch_game_at_timestamp(self, game_id: int, timestamp: str) -> Optional[Dict]:
        """Fetch game state at a specific timestamp."""
        url = f"{self.base_url}/{self.version}/game/{game_id}/feed/live"
        params = {"timecode": timestamp}
        return self._fetch_with_retries(f"{url}?{self._build_params(params)}")