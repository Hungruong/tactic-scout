import sys
from pathlib import Path
import logging
from typing import Dict, List
import pandas as pd
import numpy as np

# Add project root to Python path
project_root = str(Path(__file__).parent.absolute())
if project_root not in sys.path:
    sys.path.append(project_root)

from src.fetch_data import MLBDataFetcher
from src.process_data import process_game_state
from src.model_training import TacticalPredictor
from src.predictor import MLBTacticalAnalyzer
from src.player_analysis import PlayerAnalyzer
from src.utils import (
    setup_logging,
    save_to_json,
    ensure_directories,
    format_prediction_output,
    export_analysis_to_csv
)

def initialize_system() -> Dict:
    """Initialize all system components."""
    print("Initializing MLB Tactical Analysis System...")
    
    # Setup logging and directories
    setup_logging()
    ensure_directories()
    
    # Initialize components
    components = {
        'data_fetcher': MLBDataFetcher(),
        'tactical_predictor': TacticalPredictor(),
        'player_analyzer': PlayerAnalyzer()
    }
    
    return components

def build_training_dataset(data_fetcher: MLBDataFetcher) -> pd.DataFrame:
    """Build training dataset from historical games."""
    print("\nFetching historical games for training...")
    
    # Fetch comprehensive historical dataset
    historical_data = data_fetcher.fetch_historical_dataset(
        start_year=2023,  # Starting from enhanced metrics era
        end_year=2024,    # Up to current season
        limit_per_year=None  # No limit - fetch all available games
    )
    
    if not historical_data['games']:
        raise ValueError("Failed to fetch historical games")
    
    # Process games into training data
    all_plays = []
    for i, game_data in enumerate(historical_data['games']):
        if i % 100 == 0:
            print(f"Processing game {i+1}/{len(historical_data['games'])}...")
        plays = process_game_state(game_data)
        all_plays.append(plays)
    
    training_df = pd.concat(all_plays, ignore_index=True)
    print(f"Built training dataset with {len(training_df)} plays")
    
    return training_df

def train_model(training_data: pd.DataFrame, save_path: str = "models/tactical_predictor.joblib"):
    """Train and save the tactical prediction model."""
    print("\nTraining tactical prediction model...")
    
    predictor = TacticalPredictor()
    predictor.train(training_data, optimize=True)
    predictor.save_model(save_path)
    
    print("Model training completed and saved")
    
    # Save training metadata
    save_to_json({
        'training_stats': {
            'num_plays': len(training_data),
            'feature_names': predictor.feature_names
        }
    }, "data/processed/model_metadata.json")

def analyze_live_game(game_id: int, components: Dict):
    """Analyze a live game."""
    print(f"\nAnalyzing game {game_id}...")
    
    # Fetch live game data
    game_data = components['data_fetcher'].fetch_live_game(game_id)
    if not game_data:
        print(f"Failed to fetch data for game {game_id}")
        return
    
    # Initialize analyzer with trained model
    analyzer = MLBTacticalAnalyzer("models/tactical_predictor.joblib")
    
    # Analyze game
    analysis = analyzer.analyze_live_game(game_data)
    
    # Format and display results
    print("\nTactical Analysis Results:")
    print("=" * 50)
    print(format_prediction_output(analysis))
    
    # Save analysis
    save_to_json(
        analysis,
        f"data/processed/game_{game_id}_analysis.json"
    )
    
    return analysis

def validate_training_data(training_data: pd.DataFrame) -> bool:
    """Validate training data before model training."""
    print("\nValidating training data...")
    
    # Check for required columns
    required_columns = [
        'inning', 'half_inning', 'result', 'outs',
        'num_runners', 'scoring_position', 'pressure_index',
        'primary_tactic'
    ]
    
    missing_columns = [col for col in required_columns if col not in training_data.columns]
    if missing_columns:
        print(f"Error: Missing required columns: {missing_columns}")
        return False
    
    # Check for null values
    null_counts = training_data[required_columns].isnull().sum()
    if null_counts.any():
        print("Warning: Found null values:")
        print(null_counts[null_counts > 0])
        # Fill nulls with appropriate values
        training_data = training_data.fillna(0)
    
    # Check data types
    incorrect_types = []
    for col in ['inning', 'outs', 'num_runners']:
        if not np.issubdtype(training_data[col].dtype, np.number):
            incorrect_types.append(col)
    
    if incorrect_types:
        print(f"Error: Non-numeric columns found: {incorrect_types}")
        return False
    
    # Check value ranges
    if not (0 <= training_data['outs'].max() <= 3):
        print("Error: Invalid outs values found")
        return False
    
    if not (1 <= training_data['inning'].max() <= 20):
        print("Error: Invalid inning values found")
        return False
    
    # Check categorical values
    valid_half_innings = ['top', 'bottom']
    invalid_half_innings = training_data[~training_data['half_inning'].isin(valid_half_innings)]
    if not invalid_half_innings.empty:
        print("Error: Invalid half_inning values found")
        return False
    
    print("Data validation successful!")
    return True

def main():
    """Main execution function."""
    try:
        # Initialize system
        components = initialize_system()
        
        # Build training dataset
        training_data = build_training_dataset(components['data_fetcher'])
        
        # Validate training data
        if not validate_training_data(training_data):
            print("Error: Training data validation failed")
            return 1
        
        # Train model
        train_model(training_data)
        
        # Analyze current game
        current_game_id = 566615  # Example game ID
        game_analysis = analyze_live_game(current_game_id, components)
        
        if game_analysis:
            # Export results
            export_analysis_to_csv(
                [game_analysis],
                "data/processed/latest_analysis.csv"
            )
            
            print("\nAnalysis completed successfully")
            return 0
        else:
            print("\nAnalysis failed")
            return 1
            
    except Exception as e:
        logging.error(f"Error in main execution: {str(e)}", exc_info=True)
        return 1

if __name__ == "__main__":
    sys.exit(main())