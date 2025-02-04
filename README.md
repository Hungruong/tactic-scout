# Tactic Scout - Baseball Analysis App

## Overview
Tactic Scout is an advanced baseball analysis application that combines Flutter mobile development with machine learning capabilities for real-time player detection and game prediction. This application helps coaches, players, and analysts make data-driven decisions by providing comprehensive baseball tactical analysis tools.

## Table of Contents
- [Features](#features)
- [Project Structure](#project-structure)
- [Technologies Used](#technologies-used)
- [Installation & Setup](#installation--setup)
- [API Documentation](#api-documentation)
- [Contributing](#contributing)
- [Troubleshooting](#troubleshooting)
- [License](#license)
- [Contact](#contact)

## Features

### Player Search and Stats
- Comprehensive MLB player database
- Detailed player statistics and information
- Quick search functionality

### AR Player Recognition
- Real-time player detection using Google Cloud Vision AI
- Instant display of player statistics
- Jersey number recognition

### Live Game Analysis
- Real-time game updates and scores
- Tactical prediction with probability breakdown
- Detailed analysis of game situations

### Baseball News
- Latest MLB news and updates
- Trade rumors and draft information
- League developments

### Season Leaders
- Top batting leaders showcase
- Pitching performance rankings
- Updated statistics

## Project Structure
```
tactic-scout/
├── lib/                     # Flutter app source code
│   ├── models/              # Data models
│   ├── screens/             # UI screens
│   ├── services/            # API services
│   ├── widgets/             # Reusable widgets
│   └── utils/               # Utility functions
├── predict_model/           # Prediction model API
├── detect_players_model/    # Player detection model
├── assets/                  # App assets
├── test/                    # Test files
└── docs/                    # Documentation
```

## Technologies Used

### Mobile Development
- Flutter & Dart for cross-platform development
- Provider for state management
- Flutter ARCore/ARKit for AR capabilities

### Backend Services
- Google Cloud Vision AI for player detection
- Vertex AI for tactical analysis
- Gemini Models for natural language generation
- Cloud Storage for data management
- Cloud Functions for serverless operations

### APIs and Data
- MLB Stats API for official statistics
- ESPN API for sports news

## Installation & Setup

### Flutter App Setup

#### Prerequisites
- Flutter SDK (latest stable version)
- Android Studio or VS Code with Flutter plugins
- iOS/Android development environment

#### Installation Steps
1. Clone the repository:
```bash
git clone https://github.com/hungtruongOwolf/tactic-scout.git
```

2. Navigate to project directory:
```bash
cd tactic-scout
```

3. Install dependencies:
```bash
flutter pub get
```

4. Run the app:
```bash
flutter run
```

### Prediction Model Setup

#### Prerequisites
- Python 3.8+
- pip package manager

#### Installation Steps
1. Create and activate virtual environment:
```bash
python -m venv venv
venv\Scripts\activate  # Windows
source venv/bin/activate  # Linux/Mac
```

2. Install requirements:
```bash
pip install -r requirements.txt
```

3. Create .env file in the root directory and add:
```env
MLB_API_BASE_URL=https://statsapi.mlb.com/api
GEMINI_API_KEY=[your-key]
```

4. Start the server:
```bash
uvicorn api:app --reload --port 8000
```

### Player Detection Model Setup

#### Prerequisites
- Python 3.8+
- Google Cloud account and credentials

#### Installation Steps
1. Create and activate virtual environment:
```bash
python -m venv venv
env\Scripts\activate  # Windows
source env/bin/activate  # Linux/Mac
```

2. Install requirements:
```bash
pip install -r requirements.txt
```

3. Configure Google Cloud:
   - Add mlb-detector-key.json to project
   - Set credentials path:
```bash
# Windows PowerShell
$env:GOOGLE_APPLICATION_CREDENTIALS="path\to\mlb-detector-key.json"

# Linux/Mac
export GOOGLE_APPLICATION_CREDENTIALS="path/to/mlb-detector-key.json"
```

4. Start the server:
```bash
uvicorn api:app --reload --port 8001
```

## API Documentation

### Prediction API
```
GET /predict/{game_id}
- Description: Get game prediction
- Parameters: game_id
- Response: List of tactics and prediction analysis

```

### Detection API
```
POST /detect
- Description: Detect players in image/video
- Parameters: Image/video file
- Response: Player detection results

```

## Contributing
1. Fork the repository
2. Create feature branch (`git checkout -b feature/YourFeature`)
3. Commit changes (`git commit -m 'Add YourFeature'`)
4. Push to branch (`git push origin feature/YourFeature`)
5. Open a Pull Request

## Troubleshooting

### Flutter Issues
- Clear build files:
```bash
flutter clean
flutter pub get
```
- Update Flutter:
```bash
flutter upgrade
```

### Python Environment Issues
- Recreate environment:
```bash
deactivate
rm -rf venv
python -m venv venv
```
- Update pip:
```bash
python -m pip install --upgrade pip
```

### API Connection Issues
- Verify servers are running
- Check port availability
- Confirm API endpoints are correct
- Verify network connectivity

## License
MIT License

## Contact
- Project Owner: Tien Nguyen, Hung Truong
- Project Link: https://github.com/hungtruongOwolf/tactic-scout

---

Made with ❤️ by Tien Nguyen, Hung Truong
