from google.cloud import vision
import numpy as np
import cv2
from config import *
from datetime import datetime

class MLBDetectionService:
    def __init__(self):
        """Initialize Vision API client"""
        self.vision_client = vision.ImageAnnotatorClient()
        
    def process_frame(self, frame_bytes):
        try:
            # Convert bytes to OpenCV image
            nparr = np.frombuffer(frame_bytes, np.uint8)
            frame = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
            height, width = frame.shape[:2]

            # Create Vision API image
            image = vision.Image(content=frame_bytes)

            objects = self.vision_client.object_localization(image=image).localized_object_annotations
            detections = []
            detected_numbers = set()

            for obj in objects:
                if obj.name == "Person" and obj.score > 0.5:
                    number = self._extract_jersey_number(image, obj.bounding_poly)
                    if number and number not in detected_numbers:
                        detected_numbers.add(number)
                        detections.append({
                            'number': number,
                            'confidence': float(obj.score)
                        })

            return {
                'status': 'success',
                'detections': detections
            }

        except Exception as e:
            return {'status': 'error', 'message': str(e)}


    
    def _extract_jersey_number(self, image, box):
        """
        Extract jersey number from the detected person area
        Args:
            image: Vision API image
            box: Bounding box of person
        Returns:
            Jersey number string or None
        """
        try:
            # Perform OCR on the image
            text_response = self.vision_client.text_detection(image=image)
            
            if text_response.text_annotations:
                # Skip first annotation (full text)
                for text in text_response.text_annotations[1:]:
                    number = text.description.strip()
                    # Validate if it's a valid jersey number
                    if number.isdigit() and len(number) <= 2:
                        return number
                        
        except Exception as e:
            print(f"Error extracting number: {e}")
        
        return None