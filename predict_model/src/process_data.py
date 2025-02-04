import pandas as pd
import numpy as np
from typing import Dict, List, Optional
from .constants import (
    TACTICAL_CATEGORIES,
    ACTION_TO_TACTIC,
    CONTEXT_WEIGHTS,
    HIGH_LEVERAGE_THRESHOLDS,
    VALID_EVENTS
)
from .stats_fetcher import PlayerStatsFetcher


def process_game_state(game_data: Dict, stats_fetcher: PlayerStatsFetcher = None) -> pd.DataFrame:
    """Process game state into a structured DataFrame with flattened information."""
    plays = game_data.get("liveData", {}).get("plays", {}).get("allPlays", [])
    processed = []

    for play in plays:
        # Extract basic info
        play_data = {
            "inning": int(play["about"]["inning"]),
            "half_inning": play["about"]["halfInning"],
            "result": play["result"]["event"],
            "outs": int(play["count"]["outs"]),
            "balls": int(play["count"].get("balls", 0)),
            "strikes": int(play["count"].get("strikes", 0)),
            "score_home": int(play["about"].get("home", 0)),
            "score_away": int(play["about"].get("away", 0)),
            "batting_team": play.get("about", {}).get("team", ""),
            "pitcher_id": play.get("matchup", {}).get("pitcher", {}).get("id", ""),
            "batter_id": play.get("matchup", {}).get("batter", {}).get("id", "")
        }

        # Add player stats if stats_fetcher is provided
        if stats_fetcher and play_data["batter_id"] and play_data["pitcher_id"]:
            batter_stats = stats_fetcher.get_batter_stats(play_data["batter_id"])
            pitcher_stats = stats_fetcher.get_pitcher_stats(play_data["pitcher_id"])
            matchup_stats = stats_fetcher.get_matchup_history(
                play_data["batter_id"], 
                play_data["pitcher_id"]
            )
            
            # Add batter stats
            if batter_stats:
                play_data.update({
                    'batter_avg': batter_stats['avg'],
                    'batter_obp': batter_stats['obp'],
                    'batter_slg': batter_stats['slg'],
                    'batter_ops': batter_stats['ops'],
                    'batter_hr': batter_stats['home_runs'],
                    'batter_so': batter_stats['strikeouts'],
                    'batter_bb': batter_stats['walks'],
                    'batter_risp_avg': batter_stats['risp_avg'],
                    'batter_clutch_ops': batter_stats['clutch_ops']
                })
            
            # Add pitcher stats
            if pitcher_stats:
                play_data.update({
                    'pitcher_era': pitcher_stats['era'],
                    'pitcher_whip': pitcher_stats['whip'],
                    'pitcher_k_per_9': pitcher_stats['k_per_9'],
                    'pitcher_bb_per_9': pitcher_stats['bb_per_9'],
                    'pitcher_h_per_9': pitcher_stats['hits_per_9'],
                    'pitcher_gb_rate': pitcher_stats['ground_ball_rate'],
                    'pitcher_k_rate': pitcher_stats['strikeout_rate'],
                    'pitcher_bb_rate': pitcher_stats['walk_rate']
                })
            
            # Add matchup history
            if matchup_stats:
                play_data.update({
                    'matchup_avg': matchup_stats['avg'],
                    'matchup_ops': matchup_stats['ops'],
                    'matchup_abs': matchup_stats['at_bats'],
                    'matchup_hr': matchup_stats['home_runs'],
                    'matchup_so': matchup_stats['strikeouts'],
                    'matchup_bb': matchup_stats['walks']
                })
        
        # Calculate score situation
        play_data["score_diff"] = play_data["score_away"] - play_data["score_home"]
        play_data["is_close_game"] = int(abs(play_data["score_diff"]) <= HIGH_LEVERAGE_THRESHOLDS["close_score"])
        
        # Process runners
        runners = play.get("runners", [])
        play_data.update(process_runners_flat(runners))
        
        # Calculate all metrics
        play_data.update(calculate_advanced_metrics(play_data))
        
        # Calculate tactical probabilities
        if play_data["result"] in VALID_EVENTS["hitting"] + VALID_EVENTS["baserunning"] + VALID_EVENTS["fielding"]:
            tactical_probs = calculate_tactical_probabilities(play_data)
            play_data["primary_tactic"] = tactical_probs["primary_tactic"]
            # Add tactical probabilities as separate columns
            for tactic, prob in tactical_probs["probabilities"].items():
                play_data[f"prob_{tactic}"] = prob
        else:
            continue  # Skip plays with invalid results
        
        processed.append(play_data)

    # Create DataFrame
    df = pd.DataFrame(processed)
    
    # Convert all columns to appropriate types
    df = convert_column_types(df)
    
    return df

def process_runners_flat(runners: List[Dict]) -> Dict:
    """Process runners information into flattened format."""
    scoring_position = any(
        r.get("movement", {}).get("start") in ["2B", "3B"] 
        for r in runners
    )
    runs_scored = sum(
        1 for r in runners 
        if r.get("movement", {}).get("end") == "score"
    )
    
    return {
        "num_runners": len(runners),
        "scoring_position": int(scoring_position),
        "runs_scored": runs_scored,
        "runner_on_first": int(any(r.get("movement", {}).get("start") == "1B" for r in runners)),
        "runner_on_second": int(any(r.get("movement", {}).get("start") == "2B" for r in runners)),
        "runner_on_third": int(any(r.get("movement", {}).get("start") == "3B" for r in runners))
    }

def calculate_advanced_metrics(play_data: Dict) -> Dict:
    """Calculate advanced metrics for the play."""
    metrics = {}
    
    # Calculate pressure index
    pressure = 1.0
    if play_data["inning"] >= HIGH_LEVERAGE_THRESHOLDS["late_innings"]:
        pressure *= 1.5
    pressure *= (1 + play_data["outs"] * 0.2)
    if play_data["scoring_position"]:
        pressure *= 1.3
    metrics["pressure_index"] = min(pressure, 2.0)
    
    # Calculate game stage (0-1 scale)
    effective_inning = min(play_data["inning"], 9)  # Cap inning at 9 for extra innings
    metrics["game_stage"] = (effective_inning - 1 + play_data["outs"]/3) / 9
    
    # Calculate run expectancy
    run_exp = (
        play_data["num_runners"] * 
        (0.5 if play_data["scoring_position"] else 0.3) * 
        ((3 - play_data["outs"]) / 3)
    )
    metrics["run_expectancy"] = run_exp
    
    # Calculate leverage index
    leverage = (
        metrics["pressure_index"] * 
        (2.0 if play_data["is_close_game"] else 1.0) * 
        (1.5 if metrics["game_stage"] > 0.7 else 1.0)
    )
    metrics["leverage_index"] = min(leverage, 3.0)
    
    # Calculate win probability added
    if play_data["inning"] >= 10:
        metrics["win_probability_added"] = 0.5 + (play_data["score_diff"] / 2) * 0.1
    else:
        remaining_innings = max(10 - play_data["inning"], 1)
        metrics["win_probability_added"] = 0.5 + (play_data["score_diff"] / remaining_innings) * 0.1
    
    # Offensive metrics
    metrics["offensive_opportunity"] = (
        play_data["num_runners"] * 
        (1.5 if play_data["scoring_position"] else 1.0) * 
        ((3 - play_data["outs"]) / 3)
    )
    
    # Defensive metrics
    metrics["defensive_pressure"] = (
        play_data["num_runners"] * 
        metrics["pressure_index"] * 
        ((play_data["outs"] + 1) / 3)
    )
    
    # Count metrics
    metrics["count_leverage"] = (
        (play_data["balls"] / 4) * 
        (1 - play_data["strikes"] / 3)
    )
    
    # Scoring threat
    metrics["scoring_threat"] = (
        metrics["offensive_opportunity"] * 
        metrics["pressure_index"] * 
        (2.0 if play_data["is_close_game"] else 1.0)
    )
    
    return metrics

def calculate_tactical_probabilities(play_data: Dict) -> Dict:
    """Calculate tactical probabilities with context consideration."""
    probabilities = {}
    action = play_data["result"]
    
    if action not in ACTION_TO_TACTIC:
        return {"probabilities": {'contact_hitting': 100.0}, "primary_tactic": 'contact_hitting'}
    
    possible_tactics = ACTION_TO_TACTIC[action]
    
    for tactic_info in possible_tactics:
        tactic = tactic_info['tactic']
        contexts = tactic_info['contexts']
        
        # Base probability from action match
        prob = 0.4
        
        # Context checks
        context_match_count = 0
        total_contexts = len(contexts)
        
        for context_key, threshold in contexts.items():
            if context_key == 'min_runners' and play_data['num_runners'] >= threshold:
                context_match_count += 1
            elif context_key == 'max_outs' and play_data['outs'] <= threshold:
                context_match_count += 1
            elif context_key == 'scoring_position' and play_data['scoring_position'] == threshold:
                context_match_count += 1
            elif context_key == 'min_pressure' and play_data['pressure_index'] >= threshold:
                context_match_count += 1
            elif context_key == 'max_pressure' and play_data['pressure_index'] <= threshold:
                context_match_count += 1
            elif context_key == 'score_diff_range' and threshold[0] <= play_data['score_diff'] <= threshold[1]:
                context_match_count += 1
            elif context_key == 'min_balls' and play_data['balls'] >= threshold:
                context_match_count += 1
            elif context_key == 'max_strikes' and play_data['strikes'] <= threshold:
                context_match_count += 1
            elif context_key == 'min_offensive_opportunity' and play_data['offensive_opportunity'] >= threshold:
                context_match_count += 1
            elif context_key == 'min_defensive_pressure' and play_data['defensive_pressure'] >= threshold:
                context_match_count += 1
        
        # Adjust probability based on context matches
        if total_contexts > 0:
            context_score = context_match_count / total_contexts
            prob += context_score * 0.6
            
            # Additional adjustments for high leverage situations
            if play_data['pressure_index'] >= HIGH_LEVERAGE_THRESHOLDS['high_pressure']:
                if tactic in ['power_hitting', 'patient_hitting']:
                    prob *= 1.2
                elif tactic in ['contact_hitting', 'defensive_outs']:
                    prob *= 1.1
        
        if prob >= 0.05:  # Only include probabilities >= 5%
            # Adjust based on batter stats
            if 'batter_ops' in play_data:
                if tactic == 'power_hitting' and play_data['batter_ops'] > .800:
                    prob *= 1.2
                elif tactic == 'contact_hitting' and play_data['batter_avg'] > .300:
                    prob *= 1.1
                    
            # Adjust based on pitcher stats  
            if 'pitcher_k_rate' in play_data:
                if tactic == 'strikeout_pitching' and play_data['pitcher_k_rate'] > 9.0:
                    prob *= 1.2
                elif tactic == 'defensive_outs' and play_data['pitcher_gb_rate'] > 1.5:
                    prob *= 1.1
                    
            # Adjust based on matchup history
            if 'matchup_ops' in play_data and play_data['matchup_abs'] > 10:
                if play_data['matchup_ops'] > .800:
                    if tactic in ['power_hitting', 'contact_hitting']:
                        prob *= 1.15
                elif play_data['matchup_ops'] < .600:
                    if tactic in ['defensive_outs', 'strikeout_pitching']:
                        prob *= 1.15
        
        probabilities[tactic] = prob
    
    if not probabilities:
        probabilities['contact_hitting'] = 100.0
    
    return {
        "probabilities": probabilities,
        "primary_tactic": max(probabilities.items(), key=lambda x: x[1])[0]
    }

def convert_column_types(df: pd.DataFrame) -> pd.DataFrame:
    """Convert DataFrame columns to appropriate types."""
    # Integer columns
    int_columns = [
        "inning", "outs", "balls", "strikes",
        "score_home", "score_away", "score_diff",
        "num_runners", "runs_scored",
        "runner_on_first", "runner_on_second", "runner_on_third"
    ]
    
    # Float columns
    float_columns = [
        "pressure_index", "leverage_index", "run_expectancy",
        "win_probability_added", "offensive_opportunity",
        "defensive_pressure", "count_leverage", "scoring_threat",
        "game_stage",
        # Player stat columns
        "batter_avg", "batter_obp", "batter_slg", "batter_ops",
        "batter_risp_avg", "batter_clutch_ops",
        "pitcher_era", "pitcher_whip", "pitcher_k_per_9", 
        "pitcher_bb_per_9", "pitcher_h_per_9", "pitcher_gb_rate",
        "pitcher_k_rate", "pitcher_bb_rate",
        "matchup_avg", "matchup_ops"
    ]
    
    # Boolean columns
    bool_columns = ["is_close_game", "scoring_position"]
    
    # Convert columns
    for col in int_columns:
        if col in df.columns:
            df[col] = pd.to_numeric(df[col], errors='coerce').fillna(0).astype(int)
    
    for col in float_columns:
        if col in df.columns:
            df[col] = pd.to_numeric(df[col], errors='coerce').fillna(0.0)
    
    for col in bool_columns:
        if col in df.columns:
            df[col] = df[col].astype(int)
    
    return df