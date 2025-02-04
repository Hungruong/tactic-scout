import sys
from pathlib import Path
import logging
from typing import Dict
import argparse
import os

project_root = str(Path(__file__).parent.absolute())
if project_root not in sys.path:
    sys.path.append(project_root)

from src.stats_fetcher import PlayerStatsFetcher
from src.fetch_data import MLBDataFetcher
from src.predictor import MLBTacticalAnalyzer
from src.player_analysis import PlayerAnalyzer
from src.utils import (
    setup_logging,
    save_to_json,
    ensure_directories,
    format_prediction_output,
    export_analysis_to_csv
)

class DuplicateFilter(logging.Filter):
    def __init__(self):
        super().__init__()
        self.msgs = set()

    def filter(self, record):
        rv = record.msg not in self.msgs
        self.msgs.add(record.msg)
        return rv

def configure_logging():
    root_logger = logging.getLogger()
    root_logger.setLevel(logging.INFO)
    root_logger.addFilter(DuplicateFilter())
    formatter = logging.Formatter('%(asctime)s - %(name)s - %(levelname)s - %(message)s')
    console = logging.StreamHandler()
    console.setFormatter(formatter)
    root_logger.addHandler(console)

def initialize_prediction_system() -> Dict:
    print("Initializing MLB Prediction System...")
    configure_logging()
    ensure_directories()
    
    if not os.getenv('GEMINI_API_KEY'):
        print("Warning: GEMINI_API_KEY not found. Natural language analysis will not be available")
    
    return {
        'data_fetcher': MLBDataFetcher(),
        'player_analyzer': PlayerAnalyzer(),
        'stats_fetcher': PlayerStatsFetcher()
    }

def analyze_live_game(game_id: int, components: Dict):
    stats_fetcher = components['stats_fetcher']
    print(f"\nAnalyzing game {game_id}...")
    
    model_path = "models/tactical_predictor.joblib"
    if not Path(model_path).exists():
        print(f"Error: Model not found at {model_path}\nPlease run train.py first")
        return None

    game_data = components['data_fetcher'].fetch_live_game(game_id)
    if not game_data:
        print(f"Failed to fetch data for game {game_id}")
        return None

    try:
        game_info = game_data.get('gameData', {})
        game_date = game_info.get('datetime', {}).get('originalDate', '')
        game_type = game_info.get('game', {}).get('type')
        game_season = int(game_date.split('-')[0]) if game_date else 2024

        if game_date:
            stats_fetcher.set_season(game_season)
            print(f"Analyzing game from season {game_season}")
        
        if game_type == 'S':
            print("Spring Training game detected")

        analyzer = MLBTacticalAnalyzer(model_path)
        analysis = analyzer.analyze_live_game(game_data, stats_fetcher)
        
        if not analysis:
            return None

        print("\nTactical Analysis Results:")
        print("=" * 50)
        print(format_prediction_output(analysis))

        # Save to files only once
        if save_to_json(analysis, f"data/processed/game_{game_id}_analysis.json"):
            export_analysis_to_csv([analysis], "data/processed/latest_analysis.csv")
            
        return analysis

    except Exception as e:
        logging.error(f"Error analyzing game: {str(e)}", exc_info=True)
        return None

def main():
    try:
        parser = argparse.ArgumentParser(description='MLB Game Tactical Predictor')
        parser.add_argument('game_id', type=int, help='ID of the game to analyze')
        args = parser.parse_args()
        
        components = initialize_prediction_system()
        analysis = analyze_live_game(args.game_id, components)
        
        if analysis:
            print("\nAnalysis completed successfully")
            return 0
        
        print("\nAnalysis failed")
        return 1

    except Exception as e:
        logging.error(f"Error in prediction execution: {str(e)}", exc_info=True)
        return 1

if __name__ == "__main__":
    sys.exit(main())