import requests
from typing import Dict, Optional, Any
import logging
import time

class PlayerStatsFetcher:
    def __init__(self):
        self.base_url = "https://statsapi.mlb.com/api/v1"
        self.stats_cache = {}
        self.season_year = 2024
        
        # Default values for batter stats
        self.DEFAULT_BATTER_STATS = {
            'avg': 0.0,
            'obp': 0.0, 
            'slg': 0.0,
            'ops': 0.0,
            'home_runs': 0,
            'hits': 0,
            'strikeouts': 0,
            'walks': 0,
            'at_bats': 0,
            'plate_appearances': 0,
            'babip': 0.0,
            'total_bases': 0,
            'risp_avg': 0.0,
            'clutch_ops': 0.0,
            'runs': 0,
            'doubles': 0,
            'triples': 0,
            'stolen_bases': 0,
            'caught_stealing': 0,
            'ground_outs': 0,
            'air_outs': 0,
            'rbi': 0
        }

        # Default values for pitcher stats
        self.DEFAULT_PITCHER_STATS = {
            'era': 0.0,
            'whip': 0.0,
            'k_per_9': 0.0,
            'bb_per_9': 0.0,
            'hits_per_9': 0.0,
            'strikeouts': 0,
            'walks': 0,
            'innings_pitched': 0.0,
            'ground_ball_rate': 0.0,
            'strikeout_rate': 0.0,
            'walk_rate': 0.0,
            'hits': 0,
            'earned_runs': 0,
            'games': 0,
            'games_started': 0,
            'saves': 0
        }

    def set_season(self, year: int):
        """Set the season year for stats fetching."""
        if year != self.season_year:
            logging.info(f"Set season to {year} based on game date")
            self.season_year = year
            self.stats_cache.clear()

    def _safe_convert_stat(self, stat_value: Any, default: float = 0.0) -> float:
        """Safely convert stat value to float."""
        if stat_value is None:
            return default
            
        # Handle special MLB API cases
        if isinstance(stat_value, str):
            # Special MLB API values for no stats
            if stat_value in ['0.---', '-0.--', '-.--', '-.---', '*.**']:
                return default
            try:
                # Remove leading '-' if present and handle dots
                cleaned = stat_value.lstrip('-').replace('.', '0.') if '.' in stat_value else stat_value
                return float(cleaned)
            except ValueError:
                logging.debug(f"Could not convert stat value: {stat_value}")
                return default
        
        try:
            return float(stat_value)
        except (TypeError, ValueError):
            return default

    def _safe_convert_int(self, value: Any, default: int = 0) -> int:
        """Safely convert value to integer."""
        try:
            if isinstance(value, str) and value.strip() in ['', '-']:
                return default
            return int(value)
        except (TypeError, ValueError):
            return default

    def _try_get_stats_with_retry(self, player_id: int, season: int, group: str = 'hitting', 
                                game_type: str = 'R', retries: int = 3) -> Optional[Dict]:
        """Get stats with retry logic."""
        for attempt in range(retries):
            try:
                stats = self._try_get_stats(player_id, season, group, game_type)
                if stats and not any(str(v) in ['0.---', '-0.--', '-.--', '-.---', '*.**'] 
                                   for v in stats.values()):
                    return stats
                time.sleep(1)  # Wait between retries
            except Exception as e:
                if attempt == retries - 1:
                    logging.error(f"Failed to get stats for player {player_id} after {retries} attempts: {e}")
                time.sleep(1)
        return None

    def _try_get_stats(self, player_id: int, season: int, group: str = 'hitting', 
                       game_type: str = 'R') -> Optional[Dict]:
        """Try to get stats for a specific season and game type."""
        cache_key = f"{player_id}_{season}_{group}_{game_type}"
        if cache_key in self.stats_cache:
            return self.stats_cache[cache_key]

        url = f"{self.base_url}/people/{player_id}"
        params = {
            "hydrate": f"stats(group={group},type=season,season={season},gameType={game_type})"
        }

        try:
            response = requests.get(url, params=params)
            response.raise_for_status()
            data = response.json()

            stats_data = (data.get('people', [{}])[0]
                         .get('stats', [{}])[0]
                         .get('splits', [{}])[0]
                         .get('stat', {}))

            if stats_data:
                self.stats_cache[cache_key] = stats_data
                return stats_data

        except Exception as e:
            logging.debug(f"Error fetching stats for player {player_id}, season {season}: {e}")
            return None

        return None

    def get_batter_stats(self, batter_id: int) -> Dict:
        """Get hitting stats of batter."""
        # Try current season
        stats_data = self._try_get_stats_with_retry(batter_id, self.season_year, 'hitting')
        
        # If no stats, try previous season
        if not stats_data:
            stats_data = self._try_get_stats_with_retry(batter_id, self.season_year - 1, 'hitting')
        
        # If still no stats, try previous season with all game types
        if not stats_data:
            stats_data = self._try_get_stats_with_retry(batter_id, self.season_year - 1, 'hitting', 'ANY')

        if not stats_data:
            return self.DEFAULT_BATTER_STATS

        try:
            # Convert stats to appropriate types
            stats = {
                'avg': self._safe_convert_stat(stats_data.get('avg')),
                'obp': self._safe_convert_stat(stats_data.get('obp')),
                'slg': self._safe_convert_stat(stats_data.get('slg')),
                'ops': self._safe_convert_stat(stats_data.get('ops')),
                'home_runs': self._safe_convert_int(stats_data.get('homeRuns')),
                'hits': self._safe_convert_int(stats_data.get('hits')),
                'strikeouts': self._safe_convert_int(stats_data.get('strikeOuts')),
                'walks': self._safe_convert_int(stats_data.get('baseOnBalls')),
                'at_bats': self._safe_convert_int(stats_data.get('atBats')),
                'plate_appearances': self._safe_convert_int(stats_data.get('plateAppearances')),
                'babip': self._safe_convert_stat(stats_data.get('babip')),
                'total_bases': self._safe_convert_int(stats_data.get('totalBases')),
                'runs': self._safe_convert_int(stats_data.get('runs')),
                'doubles': self._safe_convert_int(stats_data.get('doubles')),
                'triples': self._safe_convert_int(stats_data.get('triples')),
                'stolen_bases': self._safe_convert_int(stats_data.get('stolenBases')),
                'caught_stealing': self._safe_convert_int(stats_data.get('caughtStealing')),
                'ground_outs': self._safe_convert_int(stats_data.get('groundOuts')),
                'air_outs': self._safe_convert_int(stats_data.get('airOuts')),
                'rbi': self._safe_convert_int(stats_data.get('rbi'))
            }

            # Add calculated stats
            stats['risp_avg'] = stats['avg']  # Using regular avg as proxy
            stats['clutch_ops'] = stats['ops']  # Using regular ops as proxy

            return stats

        except Exception as e:
            logging.error(f"Error processing batter stats for {batter_id}: {e}")
            return self.DEFAULT_BATTER_STATS

    def get_pitcher_stats(self, pitcher_id: int) -> Dict:
        """Get pitching stats."""
        # Try current season
        stats_data = self._try_get_stats_with_retry(pitcher_id, self.season_year, 'pitching')
        
        # If no stats, try previous season
        if not stats_data:
            stats_data = self._try_get_stats_with_retry(pitcher_id, self.season_year - 1, 'pitching')
        
        # If still no stats, try previous season with all game types
        if not stats_data:
            stats_data = self._try_get_stats_with_retry(pitcher_id, self.season_year - 1, 'pitching', 'ANY')

        if not stats_data:
            return self.DEFAULT_PITCHER_STATS

        try:
            # Convert and calculate all stats
            innings_pitched = self._safe_convert_stat(stats_data.get('inningsPitched'))
            strikeouts = self._safe_convert_int(stats_data.get('strikeOuts'))
            walks = self._safe_convert_int(stats_data.get('baseOnBalls'))
            hits = self._safe_convert_int(stats_data.get('hits'))

            stats = {
                'era': self._safe_convert_stat(stats_data.get('era')),
                'whip': self._safe_convert_stat(stats_data.get('whip')),
                'strikeouts': strikeouts,
                'walks': walks,
                'innings_pitched': innings_pitched,
                'hits': hits,
                'earned_runs': self._safe_convert_int(stats_data.get('earnedRuns')),
                'games': self._safe_convert_int(stats_data.get('gamesPlayed')),
                'games_started': self._safe_convert_int(stats_data.get('gamesStarted')),
                'saves': self._safe_convert_int(stats_data.get('saves'))
            }

            # Calculate rate stats
            if innings_pitched > 0:
                stats['k_per_9'] = (strikeouts * 9) / innings_pitched
                stats['bb_per_9'] = (walks * 9) / innings_pitched
                stats['hits_per_9'] = (hits * 9) / innings_pitched
            else:
                stats['k_per_9'] = 0.0
                stats['bb_per_9'] = 0.0
                stats['hits_per_9'] = 0.0

            # Calculate additional rates
            total_batters = stats['hits'] + stats['walks'] + stats['strikeouts']
            if total_batters > 0:
                stats['strikeout_rate'] = stats['strikeouts'] / total_batters
                stats['walk_rate'] = stats['walks'] / total_batters
            else:
                stats['strikeout_rate'] = 0.0
                stats['walk_rate'] = 0.0
            
            # Calculate ground ball rate
            ground_outs = self._safe_convert_int(stats_data.get('groundOuts'))
            air_outs = self._safe_convert_int(stats_data.get('airOuts'))
            total_outs = ground_outs + air_outs
            stats['ground_ball_rate'] = ground_outs / total_outs if total_outs > 0 else 0.0

            return stats

        except Exception as e:
            logging.error(f"Error processing pitcher stats for {pitcher_id}: {e}")
            return self.DEFAULT_PITCHER_STATS

    def get_matchup_history(self, batter_id: int, pitcher_id: int) -> Dict:
        """Get matchup history between batter and pitcher."""
        return {
            'at_bats': 0,
            'hits': 0,
            'home_runs': 0,
            'strikeouts': 0,
            'walks': 0,
            'avg': 0.0,
            'ops': 0.0
        }