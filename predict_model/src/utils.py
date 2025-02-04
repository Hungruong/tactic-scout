import json
import pandas as pd
from typing import Dict, Any, List, Union
from pathlib import Path
import logging

def setup_logging():
    """Setup logging configuration."""
    logging.basicConfig(
        level=logging.INFO,
        format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
    )

def save_to_json(data: Dict, filename: str):
    """Save data to a JSON file."""
    try:
        with open(filename, 'w') as f:
            json.dump(data, f, indent=4)
        # Log only if save was successful
        logging.info(f"Data saved to {filename}")
        return True
    except Exception as e:
        logging.error(f"Error saving to JSON: {str(e)}")
        return False

def load_from_json(filename: str) -> Union[Dict, List]:
    """Load data from a JSON file."""
    try:
        with open(filename, "r") as f:
            return json.load(f)
    except Exception as e:
        logging.error(f"Error loading data from {filename}: {e}")
        return None

def ensure_directories():
    """Ensure all required directories exist."""
    directories = [
        "data/raw",
        "data/processed",
        "models",
        "logs"
    ]
    for directory in directories:
        Path(directory).mkdir(parents=True, exist_ok=True)

def format_prediction_output(predictions: Dict) -> str:
    """Format prediction output for display including Gemini analysis."""
    output = ["Tactical Analysis Report", "=" * 50, ""]
    
    # If Gemini analysis is available, show it first
    if 'gemini_analysis' in predictions:
        output.append("Natural Language Analysis:")
        output.append("-" * 30)
        output.append(predictions['gemini_analysis'])
        output.append("\n" + "=" * 50 + "\n")
    
    # Display probabilities by category
    output.append("Tactical Probabilities by Category:")
    output.append("-" * 30)
    for category, tactics in predictions['tactical_probabilities'].items():
        if tactics:  # Only show categories with predictions
            output.append(f"\n{category}:")
            for tactic, prob in tactics.items():
                output.append(f"  {tactic:<25} {prob:>5.1f}%")
    
    # Display top recommendations
    output.append("\nTop Recommendations:")
    output.append("-" * 30)
    for rec in predictions['recommendations']:
        output.append(f"\n{rec['tactic']} ({rec['probability']}%):")
        output.append(f"Reasoning: {rec['reasoning']}")
        output.append("Specific Actions:")
        for action in rec['specific_actions']:
            output.append(f"  - {action}")
    
    # Display context analysis
    output.append("\nSituation Analysis:")
    output.append("-" * 30)
    context = predictions['context_analysis']
    output.append(f"Inning: {context['game_situation']['inning']}")
    output.append(f"Outs: {context['game_situation']['outs']}")
    output.append(f"Pressure Index: {context['game_situation']['pressure_index']:.2f}")
    output.append(f"Runners: {context['runner_situation']['runners']}")
    output.append(f"Scoring Position: {'Yes' if context['runner_situation']['scoring_position'] else 'No'}")
    
    return "\n".join(output)

def export_analysis_to_csv(predictions: List[Dict], filename: str):
    """Export predictions analysis to CSV."""
    try:
        df = pd.DataFrame(predictions)
        df.to_csv(filename, index=False)
        logging.info(f"Analysis exported to {filename}")
    except Exception as e:
        logging.error(f"Error exporting analysis to CSV: {e}")

def validate_game_data(game_data: Dict) -> bool:
    """Validate game data structure."""
    required_fields = ['gameData', 'liveData']
    for field in required_fields:
        if field not in game_data:
            logging.error(f"Missing required field: {field}")
            return False
    return True

def calculate_success_rate(predictions: List[Dict], actual_results: List[Dict]) -> Dict[str, float]:
    """Calculate success rate of predictions."""
    success_rates = {}
    for prediction, actual in zip(predictions, actual_results):
        for tactic, prob in prediction['tactical_probabilities'].items():
            if tactic not in success_rates:
                success_rates[tactic] = {'correct': 0, 'total': 0}
            success_rates[tactic]['total'] += 1
            if actual['result'] in TACTICAL_CATEGORIES[tactic]:
                success_rates[tactic]['correct'] += 1
    
    return {
        tactic: (stats['correct'] / stats['total'] * 100)
        for tactic, stats in success_rates.items()
    }