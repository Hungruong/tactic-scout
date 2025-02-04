from fastapi import FastAPI, UploadFile, File, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from model_service import MLBDetectionService
from mlb_stats import get_mlb_player_by_number, get_player_stats
import os

app = FastAPI(title="MLB Player Detection API")

# Setup CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Update with your Flutter app's domain
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Initialize services
detection_service = MLBDetectionService()

# Define folder to save detected frames
SAVE_FOLDER = "detected_frames"
os.makedirs(SAVE_FOLDER, exist_ok=True)

@app.get("/")
async def root():
    """Health check endpoint"""
    return {"status": "running"}

@app.post("/detect")
async def detect_players(file: UploadFile = File(...)):
    """
    Process uploaded frame and return detections with player info.
    Args:
        file: Uploaded image file.
    Returns:
        JSON with detections and player information.
    """
    try:
        # Read and validate image
        contents = await file.read()
        if not contents:
            raise HTTPException(status_code=400, detail="Empty file")
        
        # Process frame
        result = detection_service.process_frame(contents)
        
        if result['status'] == 'success':
            detected_numbers = set()  # Track unique numbers
            for detection in result['detections']:
                detected_numbers.add(detection['number'])

            # Get player info for unique numbers
            player_data = {}
            for number in detected_numbers:
                players = get_mlb_player_by_number(number)  # Search Guardians first
                if players:
                    # Take first matching player
                    player = players[0]
                    # Get player stats
                    stats = get_player_stats(player['person']['id'])

                    # Store in dictionary
                    player_data[number] = {
                        'info': player,
                        'stats': stats
                    }

                    # Log player information
                    print(f"\n=== Player Found for #{number} ===")
                    print(f"Name: {player['person']['fullName']}")
                    print(f"Team: {player['team']}")
                    print(f"Position: {player['position']['name']}")
                    if stats:
                        print(f"Stats: {stats}")

            # Update response with player data
            result["players"] = player_data
        
        return result
        
    except Exception as e:
        print(f"API Error: {e}")
        raise HTTPException(status_code=500, detail=str(e))


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8001)
