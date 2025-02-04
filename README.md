# mlb_app

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.



# predict model
## python -m venv venv
## venv\Scripts\activate
## pip install -r requirements.txt
## uvicorn api:app --reload --host 0.0.0.0 --port 8000


# detect_player model
## add content of mlb-detector-key.json
## ## python -m venv venv
## env\Scripts\activate
## pip install -r requirements.txt
## $env:GOOGLE_APPLICATION_CREDENTIALS="path\to\mlb-detector-key.json"
## uvicorn api:app --reload


