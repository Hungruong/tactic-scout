from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from typing import Dict, Optional
import uvicorn
from pydantic import BaseModel
import logging
import sys
from pathlib import Path
from datetime import datetime
import os
from dotenv import load_dotenv

# Add project root to path
project_root = str(Path(__file__).parent.absolute())
if project_root not in sys.path:
    sys.path.append(project_root)

from src.predictor import MLBTacticalAnalyzer
from src.stats_fetcher import PlayerStatsFetcher
from src.fetch_data import MLBDataFetcher
from src.utils import format_prediction_output

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('logs/api.log'),
        logging.StreamHandler()
    ]
)

def validate_environment():
    """Validate required environment variables"""
    load_dotenv()  # Load .env file if exists
    
    gemini_key = os.getenv('GEMINI_API_KEY')
    if not gemini_key:
        logging.error("GEMINI_API_KEY environment variable is required")
        sys.exit(1)  # Exit immediately if no API key

# Validate environment before starting
validate_environment()

app = FastAPI(
    title="MLB Prediction API",
    description="API for MLB game tactical predictions",
    version="1.0.0"
)

# Configure CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Initialize components
stats_fetcher = PlayerStatsFetcher()
data_fetcher = MLBDataFetcher()
model_path = "models/tactical_predictor.joblib"

# Pydantic models for request/response validation
class GameStatus(BaseModel):
    id: int
    status: str
    inning: Optional[int]
    inningHalf: Optional[str]
    homeTeam: Dict
    awayTeam: Dict

class PredictionResponse(BaseModel):
    tactical_probabilities: Dict
    top_tactics: Dict  
    recommendations: list
    context_analysis: Dict
    momentum_analysis: Optional[Dict] = None 
    historical_patterns: Optional[Dict] = None
    player_analysis: Optional[Dict] = None
    gemini_analysis: Optional[str] = None

@app.get("/")
async def root():
    """Check if API is running"""
    return {"status": "ok", "message": "MLB Prediction API is running"}

@app.get("/health")
async def health_check():
    """Health check endpoint"""
    return {
        "status": "healthy",
        "components": {
            "data_fetcher": "ok",
            "stats_fetcher": "ok",
            "model": "ok" if Path(model_path).exists() else "error",
            "gemini": "ok" if os.getenv('GEMINI_API_KEY') else "error"
        }
    }

@app.get("/predict/{game_id}", response_model=PredictionResponse)
async def predict_game(game_id: int):
    """Get tactical predictions for a specific game"""
    try:
        # Fetch game data
        game_data = data_fetcher.fetch_live_game(game_id)
        if not game_data:
            raise HTTPException(
                status_code=404, 
                detail=f"Game {game_id} not found or no data available"
            )

        # Validate game data structure
        if 'gameData' not in game_data or 'liveData' not in game_data:
            raise HTTPException(
                status_code=422,
                detail="Invalid game data structure"
            )

        # Check for required game data
        plays = game_data.get('liveData', {}).get('plays', {}).get('allPlays', [])
        if not plays:
            raise HTTPException(
                status_code=422,
                detail="No play data available for this game"
            )

        # Get game context and set season
        game_date = game_data.get('gameData', {}).get('datetime', {}).get('originalDate', '')
        if game_date:
            game_season = int(game_date.split('-')[0])
            stats_fetcher.set_season(game_season)
            logging.info(f"Set season to {game_season} based on game date")

        # Add detailed logging
        logging.info(f"Processing game {game_id} with {len(plays)} plays")

        # Initialize analyzer and get predictions
        analyzer = MLBTacticalAnalyzer(model_path)
        analysis = analyzer.analyze_live_game(game_data, stats_fetcher)

        if not analysis:
            raise HTTPException(
                status_code=500, 
                detail="Failed to generate analysis"
            )

        return analysis

    except HTTPException:
        raise
    except Exception as e:
        logging.error(f"Error in predict_game: {str(e)}", exc_info=True)
        raise HTTPException(
            status_code=500,
            detail=f"Error processing prediction: {str(e)}"
        )

@app.get("/game/{game_id}/status", response_model=GameStatus)
async def get_game_status(game_id: int):
    """
    Get current status of a specific game
    
    Parameters:
    - game_id: MLB game ID
    
    Returns:
    - Current game status and score
    """
    try:
        game_data = data_fetcher.fetch_live_game(game_id)
        if not game_data:
            raise HTTPException(
                status_code=404, 
                detail=f"Game {game_id} not found"
            )

        game_status = {
            "id": game_id,
            "status": game_data.get('gameData', {}).get('status', {}).get('detailedState', ''),
            "inning": game_data.get('liveData', {}).get('linescore', {}).get('currentInning'),
            "inningHalf": game_data.get('liveData', {}).get('linescore', {}).get('inningHalf'),
            "homeTeam": {
                "name": game_data.get('gameData', {}).get('teams', {}).get('home', {}).get('name'),
                "score": game_data.get('liveData', {}).get('linescore', {}).get('teams', {}).get('home', {}).get('runs')
            },
            "awayTeam": {
                "name": game_data.get('gameData', {}).get('teams', {}).get('away', {}).get('name'),
                "score": game_data.get('liveData', {}).get('linescore', {}).get('teams', {}).get('away', {}).get('runs')
            }
        }
        return game_status

    except Exception as e:
        logging.error(f"Error in get_game_status: {str(e)}", exc_info=True)
        raise HTTPException(
            status_code=500,
            detail=f"Error fetching game status: {str(e)}"
        )

@app.get("/games/today")
async def get_today_games():
    """Get list of today's games"""
    try:
        today = datetime.now().strftime("%Y-%m-%d")
        games = data_fetcher.fetch_games_by_date(date=today)
        return {"games": games}
    except Exception as e:
        logging.error(f"Error fetching today's games: {str(e)}", exc_info=True)
        raise HTTPException(
            status_code=500,
            detail=f"Error fetching games: {str(e)}"
        )

if __name__ == "__main__":
    # Create required directories
    Path("logs").mkdir(exist_ok=True)
    
    # Run the API server
    uvicorn.run(
        "api:app", 
        host="0.0.0.0", 
        port=8000, 
        reload=True,
        log_level="info"
    )