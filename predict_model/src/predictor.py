import logging
from typing import Dict, List, Optional
import pandas as pd
import numpy as np
from .model_training import TacticalPredictor
from .process_data import process_game_state
from .player_analysis import PlayerAnalyzer
from .stats_fetcher import PlayerStatsFetcher
from .utils import save_to_json
from .constants import TACTICAL_CATEGORIES
from .gemini_analysis import GeminiTacticalAnalyzer

class MLBTacticalAnalyzer:
    def __init__(self, model_path: str):
        self.model_path = model_path
        self._load_model()
        self.player_analyzer = PlayerAnalyzer()
        self.current_game_state = None
        self.historical_data = None
        
        # Try initialize Gemini
        try:
            from .gemini_analysis import GeminiTacticalAnalyzer
            self.gemini_analyzer = GeminiTacticalAnalyzer()
            logging.info("Gemini analyzer initialized successfully")
        except Exception as e:
            logging.error(f"Could not initialize Gemini analyzer: {str(e)}")
            self.gemini_analyzer = None

    def _load_model(self):
        """Load the tactical prediction model."""
        try:
            self.tactical_predictor = TacticalPredictor()
            self.tactical_predictor.load_model(self.model_path)
            print(f"\nModel loaded from {self.model_path}")
            if hasattr(self.tactical_predictor.model, 'classes_'):
                print("Available tactics:", self.tactical_predictor.model.classes_)
        except Exception as e:
            logging.error(f"Error loading model: {str(e)}")
            raise

    def _get_game_context(self, game_data: Dict) -> Dict:
        """Extract game context information."""
        game_date = game_data.get('gameData', {}).get('datetime', {}).get('originalDate', '')
        game_type = game_data.get('gameData', {}).get('game', {}).get('type')
        
        return {
            'season': int(game_date.split('-')[0]) if game_date else 2024,
            'type': game_type,
            'is_spring_training': game_type == 'S'
        }

    def analyze_live_game(self, game_data: Dict, stats_fetcher: PlayerStatsFetcher = None) -> Dict:
        """Analyze live game and predict tactics."""
        try:
            # Get game context and set season
            game_context = self._get_game_context(game_data)
            if stats_fetcher and game_context['season']:
                stats_fetcher.set_season(game_context['season'])
                logging.info(f"Set season to {game_context['season']} based on game date")

            # Process game state and get predictions
            game_df = process_game_state(game_data, stats_fetcher)
            self.current_game_state = game_df
            predictions = self.tactical_predictor.analyze_situation(game_df)

            # Get current matchup details for player analysis
            current_play = (game_data.get('liveData', {})
                        .get('plays', {})
                        .get('currentPlay', {}))
            
            matchup = current_play.get('matchup', {})
            batter_id = matchup.get('batter', {}).get('id')
            pitcher_id = matchup.get('pitcher', {}).get('id')

            # Add player analysis if we have stats_fetcher
            player_analysis = None
            if stats_fetcher and batter_id and pitcher_id:
                player_analysis = {
                    'batter': stats_fetcher.get_batter_stats(batter_id),
                    'pitcher': stats_fetcher.get_pitcher_stats(pitcher_id),
                    'matchup': stats_fetcher.get_matchup_history(batter_id, pitcher_id)
                }

            # Get Gemini analysis
            gemini_analysis = None
            if self.gemini_analyzer:
                try:
                    gemini_analysis = self.gemini_analyzer.generate_tactical_analysis(
                        predictions=predictions,
                        game_state=current_play,
                        context=predictions['context_analysis']
                    )
                    logging.info("Generated Gemini analysis successfully")
                except Exception as e:
                    logging.error(f"Error generating Gemini analysis: {str(e)}")

            # Build enhanced predictions
            enhanced_predictions = {
                'tactical_probabilities': predictions['tactical_probabilities'],
                'top_tactics': predictions['top_tactics'],
                'context_analysis': predictions['context_analysis'],
                'recommendations': predictions['recommendations'],
                'game_context': game_context,
                'momentum_analysis': predictions.get('momentum_analysis'),
                'historical_patterns': predictions.get('historical_patterns'),
                'player_analysis': player_analysis,
                'gemini_analysis': gemini_analysis
            }

            # Save results
            game_id = game_data['gameData']['game']['pk']
            if save_to_json(enhanced_predictions, f"data/processed/game_{game_id}_analysis.json"):
                return enhanced_predictions

            raise Exception("Failed to save analysis results")

        except Exception as e:
            logging.error(f"Error in analyze_live_game: {str(e)}", exc_info=True)
            raise

    def _build_predictions(self, predictions: Dict, game_data: Dict, game_df: pd.DataFrame, game_context: Dict) -> Dict:
        """Build enhanced predictions dictionary."""
        enhanced = {
            'tactical_probabilities': predictions['tactical_probabilities'],
            'top_tactics': predictions['top_tactics'],
            'context_analysis': predictions['context_analysis'],
            'recommendations': predictions['recommendations'],
            'game_context': {
                'season': game_context.get('season', 2024),
                'game_type': game_context.get('type'),
                'is_spring_training': game_context.get('type') == 'S'
            }
        }

        # Add Gemini analysis
        if self.gemini_analyzer:
            try:
                all_plays = game_data.get('liveData', {}).get('plays', {}).get('allPlays', [])
                current_play = all_plays[-1] if all_plays else {}
                enhanced['gemini_analysis'] = self.gemini_analyzer.generate_tactical_analysis(
                    predictions=enhanced,
                    game_state=current_play,
                    context=predictions['context_analysis']
                )
                logging.info("Generated Gemini analysis successfully")
            except Exception as e:
                logging.error(f"Error generating Gemini analysis: {str(e)}")
                enhanced['gemini_analysis'] = "Error generating detailed analysis"

        # Add historical and momentum analysis
        enhanced = self._enhance_predictions(enhanced, game_df)
        
        # Add player analysis if possible
        if 'matchup' in predictions['context_analysis']:
            enhanced['player_analysis'] = self._analyze_matchup(
                predictions['context_analysis']['matchup'],
                self.stats_fetcher
            )

        return enhanced

    def _enhance_predictions(self, predictions: Dict, game_state: pd.DataFrame) -> Dict:
        """Enhance predictions with additional analysis."""
        enhanced = predictions.copy()
        
        historical_patterns = self._analyze_historical_patterns(game_state)
        momentum_analysis = self._analyze_momentum(game_state)
        
        # Adjust probabilities based on patterns and momentum
        enhanced['tactical_probabilities'] = self._adjust_probabilities(
            enhanced['tactical_probabilities'],
            enhanced['context_analysis'],
            historical_patterns,
            momentum_analysis
        )
        
        enhanced['momentum_analysis'] = momentum_analysis
        enhanced['historical_patterns'] = historical_patterns
        
        return enhanced

    def _analyze_matchup(self, matchup: Dict, stats_fetcher: PlayerStatsFetcher) -> Dict:
        """Analyze specific matchup with player stats."""
        batter_id = matchup.get('batter_id')
        pitcher_id = matchup.get('pitcher_id')
        
        if not batter_id or not pitcher_id:
            return {}

        batter_stats = stats_fetcher.get_batter_stats(batter_id)
        pitcher_stats = stats_fetcher.get_pitcher_stats(pitcher_id)
        
        return {
            'batter': batter_stats,
            'pitcher': pitcher_stats,
            'advantage': self._determine_advantage(batter_stats, pitcher_stats),
            'key_factors': self._analyze_key_factors(batter_stats, pitcher_stats),
            'recommendations': self._get_matchup_recommendations(batter_stats, pitcher_stats)
        }

    def _analyze_historical_patterns(self, game_state: pd.DataFrame) -> Dict:
        """Analyze historical patterns for similar situations."""
        if self.historical_data is None or game_state.empty:
            return {'success_rates': {}, 'sample_size': 0}
            
        similar_situations = self._find_similar_situations(game_state)
        if similar_situations is None or similar_situations.empty:
            return {'success_rates': {}, 'sample_size': 0}
        
        success_rates = {}
        for category, tactics in TACTICAL_CATEGORIES.items():
            category_rates = {}
            for tactic_name, tactic_actions in tactics.items():
                success = np.sum(similar_situations['success'] & 
                               (similar_situations['tactic'] == tactic_name))
                total = np.sum(similar_situations['tactic'] == tactic_name)
                rate = (success / total * 100) if total > 0 else 0
                category_rates[tactic_name] = round(rate, 2)
            success_rates[category] = category_rates
        
        return {
            'success_rates': success_rates,
            'sample_size': len(similar_situations),
            'similar_situations': self._summarize_similar_situations(similar_situations)
        }

    def _analyze_momentum(self, game_state: pd.DataFrame) -> Dict:
        """Analyze game momentum factors."""
        if game_state.empty:
            return {}
            
        current_state = game_state.iloc[-1]
        recent_plays = game_state.tail(5)
        
        return {
            'batting_team': {
                'recent_success': self._calculate_recent_success(recent_plays, 'batting'),
                'pressure_handling': self._calculate_pressure_handling(recent_plays, 'batting')
            },
            'pitching_team': {
                'recent_success': self._calculate_recent_success(recent_plays, 'pitching'),
                'pressure_handling': self._calculate_pressure_handling(recent_plays, 'pitching')
            }
        }

    def _calculate_recent_success(self, recent_plays: pd.DataFrame, team_type: str) -> float:
        """Calculate recent success rate for a team."""
        if recent_plays.empty:
            return 0.0
            
        success_indicators = {
            'batting': ['hit', 'walk', 'run_scored'],
            'pitching': ['strikeout', 'out', 'double_play']
        }
        
        indicators = success_indicators[team_type]
        success_count = sum(
            recent_plays[indicator].sum() 
            for indicator in indicators 
            if indicator in recent_plays.columns
        )
        
        return min(success_count / len(recent_plays), 1.0)

    def _calculate_pressure_handling(self, recent_plays: pd.DataFrame, team_type: str) -> float:
        """Calculate how well a team handles pressure situations."""
        if recent_plays.empty:
            return 0.0
            
        pressure_plays = recent_plays[recent_plays['pressure_index'] > 1.5]
        if pressure_plays.empty:
            return 0.0
            
        success_count = sum(
            1 for _, play in pressure_plays.iterrows()
            if self._is_successful_pressure_play(play, team_type)
        )
        
        return success_count / len(pressure_plays)

    def _is_successful_pressure_play(self, play: pd.Series, team_type: str) -> bool:
        """Determine if a pressure play was successful."""
        if team_type == 'batting':
            return any([
                play.get('hit', False),
                play.get('walk', False),
                play.get('run_scored', False)
            ])
        else:  # pitching
            return any([
                play.get('strikeout', False),
                play.get('out', False),
                play.get('double_play', False)
            ])

    def _adjust_probabilities(self, base_probs: Dict, context: Dict, 
                            historical: Dict, momentum: Dict) -> Dict:
        """Adjust tactical probabilities based on analysis."""
        adjusted_probs = base_probs.copy()
        
        for category, tactics in adjusted_probs.items():
            for tactic in tactics:
                prob = tactics[tactic]
                
                # Historical adjustment
                hist_success = historical.get('success_rates', {}).get(category, {}).get(tactic, 0)
                if hist_success > 0:
                    prob = prob * (1 + (hist_success - 50) / 100)
                
                # Momentum adjustment
                if momentum:
                    momentum_factor = self._calculate_momentum_factor(momentum, tactic)
                    prob = prob * (1 + momentum_factor)
                
                adjusted_probs[category][tactic] = round(min(max(prob, 0), 100), 2)
        
        return adjusted_probs

    def _find_similar_situations(self, game_state: pd.DataFrame) -> Optional[pd.DataFrame]:
        """Find historically similar game situations."""
        if self.historical_data is None or game_state.empty:
            return None
            
        current_state = game_state.iloc[-1]
        
        similar = self.historical_data[
            (self.historical_data['inning'] == current_state['inning']) &
            (self.historical_data['outs'] == current_state['outs']) &
            (abs(self.historical_data['pressure_index'] - 
                 current_state['pressure_index']) < 0.2)
        ]
        
        return similar if not similar.empty else None

    def _calculate_momentum_factor(self, momentum: Dict, tactic: str) -> float:
        """Calculate momentum adjustment factor for a tactic."""
        batting_momentum = momentum['batting_team']['recent_success']
        pitching_momentum = momentum['pitching_team']['recent_success']
        
        momentum_weights = {
            'aggressive_hitting': 0.2,
            'patient_hitting': -0.1,
            'power_hitting': 0.15,
            'small_ball': 0.1,
            'defensive_pressure': 0.2,
            'strikeout_hunting': 0.15
        }
        
        weight = momentum_weights.get(tactic, 0.1)
        momentum_diff = batting_momentum - pitching_momentum
        
        return momentum_diff * weight

    def _summarize_similar_situations(self, situations: pd.DataFrame) -> Dict:
        """Create a summary of similar historical situations."""
        return {
            'total_count': len(situations),
            'success_count': situations['success'].sum(),
            'avg_pressure': situations['pressure_index'].mean(),
            'most_common_tactic': situations['tactic'].mode().iloc[0]
            if not situations['tactic'].empty else None
        }

    def _determine_advantage(self, batter_stats: Dict, pitcher_stats: Dict) -> str:
        """Determine matchup advantage."""
        if not batter_stats or not pitcher_stats:
            return 'neutral'
        
        batter_ops = batter_stats.get('ops', 0)
        pitcher_era = pitcher_stats.get('era', 0)
        
        if batter_ops > 0.900 and pitcher_era > 4.50:
            return 'batter'
        elif batter_ops < 0.700 and pitcher_era < 3.50:
            return 'pitcher'
        return 'neutral'

    def _analyze_key_factors(self, batter_stats: Dict, pitcher_stats: Dict) -> List[Dict]:
        """Analyze key matchup factors."""
        factors = []
        
        if batter_stats and pitcher_stats:
            if batter_stats.get('slg', 0) > .500:
                factors.append({
                    'factor': 'power_threat',
                    'description': 'Batter shows significant power potential'
                })
                
            if pitcher_stats.get('k_per_9', 0) > 9.0:
                factors.append({
                    'factor': 'strikeout_pitcher',
                    'description': 'Pitcher has high strikeout rate'
                })
                
        return factors

    def _get_matchup_recommendations(self, batter_stats: Dict, pitcher_stats: Dict) -> List[Dict]:
        """Get tactical recommendations based on matchup."""
        recommendations = []
        
        if batter_stats and pitcher_stats:
            if batter_stats.get('ops', 0) > .800:
                recommendations.append({
                    'tactic': 'aggressive_hitting',
                    'reason': 'Batter showing strong offensive performance'
                })
                
            if pitcher_stats.get('bb_per_9', 0) > 4.0:
                recommendations.append({
                    'tactic': 'patient_hitting',
                    'reason': 'Pitcher has control issues'
                })
                
        return recommendations