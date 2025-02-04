from typing import Dict, List, Optional
import numpy as np
import pandas as pd
from .constants import TACTICAL_CATEGORIES

class PlayerAnalyzer:
    def __init__(self):
        self.player_stats = {}
        self.player_tendencies = {}
        self.historical_matchups = {}

    def analyze_player_stats(self, player_data: Dict) -> Dict:
        """Analyze player's historical stats to determine strengths and tendencies."""
        stats = {}
        
        # Batting analysis
        batting_stats = player_data.get('stats', {}).get('batting', {})
        if batting_stats:
            stats['batting'] = {
                'power_index': self._calculate_power_index(batting_stats),
                'contact_index': self._calculate_contact_index(batting_stats),
                'speed_index': self._calculate_speed_index(batting_stats),
                'discipline_index': self._calculate_discipline_index(batting_stats),
                'clutch_index': self._calculate_clutch_index(batting_stats),
                'tendencies': self._analyze_batting_tendencies(batting_stats)
            }
        
        # Pitching analysis
        pitching_stats = player_data.get('stats', {}).get('pitching', {})
        if pitching_stats:
            stats['pitching'] = {
                'power_index': self._calculate_pitching_power(pitching_stats),
                'control_index': self._calculate_control_index(pitching_stats),
                'groundball_rate': self._calculate_groundball_rate(pitching_stats),
                'pressure_index': self._calculate_pressure_performance(pitching_stats),
                'tendencies': self._analyze_pitching_tendencies(pitching_stats)
            }
        
        return stats

    def analyze_matchup(self, batter_id: str, pitcher_id: str) -> Dict:
        """Analyze batter vs pitcher matchup."""
        batter_stats = self.player_stats.get(batter_id, {})
        pitcher_stats = self.player_stats.get(pitcher_id, {})
        h2h_stats = self._get_head_to_head_stats(batter_id, pitcher_id)
        
        matchup_analysis = {
            'advantage': self._calculate_matchup_advantage(batter_stats, pitcher_stats),
            'recommended_tactics': self._get_recommended_tactics(batter_stats, pitcher_stats),
            'head_to_head': h2h_stats,
            'key_factors': self._analyze_key_matchup_factors(batter_stats, pitcher_stats)
        }
        
        # Add probability adjustments based on matchup
        matchup_analysis['probability_adjustments'] = self._calculate_probability_adjustments(
            batter_stats, pitcher_stats, h2h_stats
        )
        
        return matchup_analysis

    def _calculate_power_index(self, stats: Dict) -> float:
        """Calculate batter's power hitting ability."""
        if not stats:
            return 0.0
        
        hr_rate = stats.get('homeRuns', 0) / max(stats.get('atBats', 1), 1)
        slugging = stats.get('sluggingPercentage', 0)
        extra_base_rate = (
            stats.get('doubles', 0) + stats.get('triples', 0) + stats.get('homeRuns', 0)
        ) / max(stats.get('atBats', 1), 1)
        
        return round((hr_rate * 0.4 + slugging * 0.4 + extra_base_rate * 0.2), 3)

    def _calculate_contact_index(self, stats: Dict) -> float:
        """Calculate batter's contact hitting ability."""
        if not stats:
            return 0.0
        
        batting_avg = stats.get('avg', 0)
        strikeout_rate = stats.get('strikeOuts', 0) / max(stats.get('plateAppearances', 1), 1)
        contact_rate = 1 - strikeout_rate
        babip = stats.get('babip', 0)
        
        return round((batting_avg * 0.4 + contact_rate * 0.4 + babip * 0.2), 3)

    def _calculate_speed_index(self, stats: Dict) -> float:
        """Calculate player's speed and baserunning ability."""
        if not stats:
            return 0.0
        
        stolen_base_success = (
            stats.get('stolenBases', 0) / 
            max(stats.get('stolenBases', 0) + stats.get('caughtStealing', 0), 1)
        )
        stolen_base_attempt_rate = (
            (stats.get('stolenBases', 0) + stats.get('caughtStealing', 0)) /
            max(stats.get('plateAppearances', 1), 1)
        )
        triples_rate = stats.get('triples', 0) / max(stats.get('hits', 1), 1)
        
        return round((stolen_base_success * 0.4 + stolen_base_attempt_rate * 0.3 + triples_rate * 0.3), 3)

    def _calculate_discipline_index(self, stats: Dict) -> float:
        """Calculate batter's plate discipline."""
        if not stats:
            return 0.0
        
        walk_rate = stats.get('walks', 0) / max(stats.get('plateAppearances', 1), 1)
        strikeout_to_walk = (
            stats.get('strikeOuts', 0) / max(stats.get('walks', 1), 1)
        )
        pitches_per_pa = stats.get('pitchesPerPlateAppearance', 3.8)
        
        discipline_score = (
            walk_rate * 0.4 +
            (1 / max(strikeout_to_walk, 1)) * 0.3 +
            (pitches_per_pa / 5) * 0.3
        )
        
        return round(discipline_score, 3)

    def _calculate_clutch_index(self, stats: Dict) -> float:
        """Calculate player's performance in clutch situations."""
        if not stats:
            return 0.0
        
        risp_avg = stats.get('avgWithRunnersInScoringPosition', 0)
        late_close_avg = stats.get('avgInLateInningPressure', 0)
        high_leverage_avg = stats.get('avgInHighLeverage', 0)
        
        clutch_score = (
            risp_avg * 0.4 +
            late_close_avg * 0.3 +
            high_leverage_avg * 0.3
        )
        
        return round(clutch_score, 3)

    def _analyze_batting_tendencies(self, stats: Dict) -> Dict:
        """Analyze batter's tendencies and patterns."""
        if not stats:
            return {}
        
        return {
            'early_count_aggression': self._calculate_early_count_tendency(stats),
            'groundball_tendency': self._calculate_groundball_tendency(stats),
            'pull_tendency': self._calculate_pull_tendency(stats),
            'platoon_splits': self._calculate_platoon_splits(stats)
        }

    def _calculate_pitching_power(self, stats: Dict) -> float:
        """Calculate pitcher's power/strikeout ability."""
        if not stats:
            return 0.0
        
        k_per_9 = (stats.get('strikeOuts', 0) * 9) / max(stats.get('inningsPitched', 1), 1)
        avg_velocity = stats.get('averageVelocity', 90)
        swinging_strike_rate = stats.get('swingingStrikeRate', 0.1)
        
        power_score = (
            (k_per_9 / 12) * 0.4 +
            ((avg_velocity - 85) / 15) * 0.3 +
            (swinging_strike_rate / 0.15) * 0.3
        )
        
        return round(min(power_score, 1.0), 3)

    def _calculate_control_index(self, stats: Dict) -> float:
        """Calculate pitcher's control/command."""
        if not stats:
            return 0.0
        
        walks_per_9 = (stats.get('walks', 0) * 9) / max(stats.get('inningsPitched', 1), 1)
        strike_percentage = stats.get('strikePercentage', 0.6)
        first_pitch_strike_rate = stats.get('firstPitchStrikeRate', 0.6)
        
        control_score = (
            (1 - (walks_per_9 / 6)) * 0.4 +
            strike_percentage * 0.3 +
            first_pitch_strike_rate * 0.3
        )
        
        return round(min(control_score, 1.0), 3)

    def _calculate_groundball_rate(self, stats: Dict) -> float:
        """Calculate pitcher's groundball tendency."""
        if not stats:
            return 0.0
        
        return round(stats.get('groundBallRate', 0.45), 3)

    def _calculate_pressure_performance(self, stats: Dict) -> float:
        """Calculate pitcher's performance under pressure."""
        if not stats:
            return 0.0
        
        high_leverage_era = stats.get('eraInHighLeverage', 4.50)
        risp_ops = stats.get('opsAgainstWithRISP', 0.750)
        late_close_era = stats.get('eraInLateInningPressure', 4.50)
        
        pressure_score = (
            (1 - (high_leverage_era / 9)) * 0.4 +
            (1 - (risp_ops / 1.000)) * 0.3 +
            (1 - (late_close_era / 9)) * 0.3
        )
        
        return round(max(min(pressure_score, 1.0), 0.0), 3)

    def _analyze_pitching_tendencies(self, stats: Dict) -> Dict:
        """Analyze pitcher's tendencies and patterns."""
        if not stats:
            return {}
        
        return {
            'first_pitch_strike': stats.get('firstPitchStrikeRate', 0.6),
            'pitch_mix': self._analyze_pitch_mix(stats),
            'platoon_splits': self._calculate_platoon_splits(stats),
            'situational_patterns': self._analyze_situational_patterns(stats)
        }

    def _calculate_matchup_advantage(self, batter: Dict, pitcher: Dict) -> str:
        """Determine which player has the advantage in the matchup."""
        if not batter or not pitcher:
            return 'neutral'
        
        batter_strength = batter.get('batting', {}).get('power_index', 0)
        pitcher_strength = pitcher.get('pitching', {}).get('power_index', 0)
        
        if batter_strength > pitcher_strength * 1.2:
            return 'batter'
        elif pitcher_strength > batter_strength * 1.2:
            return 'pitcher'
        return 'neutral'

    def _get_recommended_tactics(self, batter: Dict, pitcher: Dict) -> List[Dict]:
        """Get recommended tactics based on player matchup."""
        recommendations = []
        
        if not batter or not pitcher:
            return recommendations
        
        # Example tactical recommendation
        if batter.get('batting', {}).get('power_index', 0) > 0.7:
            recommendations.append({
                'tactic': 'power_hitting',
                'confidence': 0.8,
                'reasoning': 'Batter has high power index'
            })
        
        # Add more tactical recommendations based on other factors
        return recommendations

    def _calculate_probability_adjustments(self, batter: Dict, pitcher: Dict, 
                                        h2h_stats: Dict) -> Dict:
        """Calculate probability adjustments for different tactics based on matchup."""
        adjustments = {}
        
        for category, tactics in TACTICAL_CATEGORIES.items():
            adjustments[category] = {}
            for tactic in tactics:
                adjustment = self._calculate_single_tactic_adjustment(
                    tactic, batter, pitcher, h2h_stats
                )
                adjustments[category][tactic] = round(adjustment, 2)
        
        return adjustments

    def _analyze_key_matchup_factors(self, batter: Dict, pitcher: Dict) -> List[Dict]:
        """Analyze key factors that could influence the matchup."""
        factors = []
        
        if batter and pitcher:
            batting_stats = batter.get('batting', {})
            pitching_stats = pitcher.get('pitching', {})
            
            # Power vs Control
            if batting_stats.get('power_index', 0) > 0.7 and pitching_stats.get('control_index', 0) < 0.3:
                factors.append({
                    'factor': 'power_advantage',
                    'description': 'Batter power advantage vs pitcher control',
                    'significance': 'high'
                })
            
            # Add more factors
        
        return factors

    def _calculate_single_tactic_adjustment(self, tactic: str, batter: Dict, 
                                         pitcher: Dict, h2h_stats: Dict) -> float:
        """Calculate probability adjustment for a single tactic."""
        adjustment = 0.0
        
        # Basic adjustment based on player strengths
        if batter and pitcher:
            batting_stats = batter.get('batting', {})
            pitching_stats = pitcher.get('pitching', {})
            
            if tactic == 'power_hitting':
                adjustment += (batting_stats.get('power_index', 0) - 0.5) * 0.2
            elif tactic == 'contact_hitting':
                adjustment += (batting_stats.get('contact_index', 0) - 0.5) * 0.2
            
            # Add more tactic-specific adjustments
        
        # Historical matchup adjustment
        if h2h_stats:
            adjustment += self._calculate_h2h_adjustment(tactic, h2h_stats)
        
        return min(max(adjustment, -0.5), 0.5)  # Cap adjustment at ±50%

    def _get_head_to_head_stats(self, batter_id: str, pitcher_id: str) -> Optional[Dict]:
        """Get head-to-head statistics between batter and pitcher."""
        key = f"{batter_id}-{pitcher_id}"
        return self.historical_matchups.get(key)