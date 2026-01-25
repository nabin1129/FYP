"""
API Routes for Colour Vision Tests (Ishihara)
"""

from flask import request, send_from_directory
from flask_restx import Namespace, Resource, fields
from db_model import db, ColourVisionTest, User
from auth_utils import token_required
from colour_vision_model import (
    validate_answers, 
    calculate_score, 
    classify_result, 
    get_plate_metadata,
    get_all_plate_numbers
)
import random
from pathlib import Path
import os

# Create namespace
colour_vision_ns = Namespace('colour-vision', description='Colour vision test operations (Ishihara)')

# Dataset path - adjust based on your setup
DATASET_PATH = Path(__file__).parent.parent / 'FYP' / 'ishihara_data_set'
if not DATASET_PATH.exists():
    # Try alternative path
    DATASET_PATH = Path(__file__).parent.parent / 'ishihara_data_set'

# API Models for documentation
plate_model = colour_vision_ns.model('IshiharaPlate', {
    'id': fields.Integer(required=True, description='Plate index in test sequence'),
    'plate_number': fields.Integer(required=True, description='Ishihara plate number (0-9)'),
    'image_path': fields.String(required=True, description='URL path to plate image'),
    'image_filename': fields.String(required=True, description='Image filename'),
    'correct_answer': fields.String(required=True, description='Correct answer for the plate'),
    'options': fields.List(fields.String, required=True, description='Multiple choice options'),
    'description': fields.String(description='Plate description')
})

plates_response_model = colour_vision_ns.model('PlatesResponse', {
    'plates': fields.List(fields.Nested(plate_model)),
    'total_plates': fields.Integer(description='Number of plates in test')
})

test_submission_model = colour_vision_ns.model('ColourVisionTestSubmission', {
    'plate_ids': fields.List(fields.Integer, required=True, description='List of plate numbers shown'),
    'plate_images': fields.List(fields.String, required=True, description='List of image filenames used'),
    'user_answers': fields.List(fields.String, required=True, description='User\'s selected answers'),
    'test_duration': fields.Float(description='Test duration in seconds')
})

test_response_model = colour_vision_ns.model('ColourVisionTestResponse', {
    'id': fields.Integer(description='Test ID'),
    'user_id': fields.Integer(description='User ID'),
    'total_plates': fields.Integer(description='Total plates shown'),
    'plate_ids': fields.List(fields.Integer, description='Plate numbers shown'),
    'correct_count': fields.Integer(description='Number of correct answers'),
    'score': fields.Integer(description='Score percentage (0-100)'),
    'severity': fields.String(description='Classification: Normal, Mild Deficiency, Deficiency Detected'),
    'test_duration': fields.Float(description='Test duration in seconds'),
    'created_at': fields.String(description='Test timestamp')
})


def get_random_plates(count=10):
    """
    Select random Ishihara plates from the dataset
    
    Args:
        count: Number of plates to select (default: 10 for standard test)
        
    Returns:
        List of plate dictionaries with metadata and image paths
    """
    if not DATASET_PATH.exists():
        raise FileNotFoundError(f"Dataset not found at {DATASET_PATH}")
    
    # Get all available plate numbers
    available_plates = get_all_plate_numbers()
    
    # CRITICAL: Enforce unique plate numbers per test session
    # This prevents duplicate plates with different fonts
    selected_plate_numbers = random.sample(available_plates, min(count, len(available_plates)))
    
    plates = []
    for idx, plate_number in enumerate(selected_plate_numbers):
        # Get all images for this plate number
        pattern = f"{plate_number}_*.png"
        matching_images = list(DATASET_PATH.glob(pattern))
        
        if not matching_images:
            continue
        
        # Randomly select one image for this plate number
        selected_image = random.choice(matching_images)
        
        # Get plate metadata
        metadata = get_plate_metadata(plate_number)
        
        # Randomize the order of options to prevent pattern memorization
        randomized_options = metadata['options'].copy()
        random.shuffle(randomized_options)
        
        plates.append({
            'id': idx,
            'plate_number': plate_number,
            'image_path': f'/static/ishihara/{selected_image.name}',
            'image_filename': selected_image.name,
            'correct_answer': metadata['correct_answer'],
            'options': randomized_options,  # Randomized options
            'description': metadata.get('description', '')
        })
    
    return plates


@colour_vision_ns.route('/plates')
class ColourVisionPlates(Resource):
    @token_required
    @colour_vision_ns.doc('get_random_plates')
    @colour_vision_ns.param('count', 'Number of plates to retrieve (default: 5)', type=int)
    @colour_vision_ns.marshal_with(plates_response_model)
    def get(self, current_user):
        """Get a random selection of Ishihara plates for testing"""
        try:
            count = int(request.args.get('count', 5))
            if count < 1 or count > 10:
                colour_vision_ns.abort(400, 'Count must be between 1 and 10')
            
            plates = get_random_plates(count)
            
            return {
                'plates': plates,
                'total_plates': len(plates)
            }, 200
            
        except FileNotFoundError as e:
            colour_vision_ns.abort(500, f'Dataset error: {str(e)}')
        except Exception as e:
            colour_vision_ns.abort(500, f'Error generating plates: {str(e)}')


@colour_vision_ns.route('/tests')
class ColourVisionTests(Resource):
    @token_required
    @colour_vision_ns.doc('submit_colour_vision_test')
    @colour_vision_ns.expect(test_submission_model)
    @colour_vision_ns.marshal_with(test_response_model, code=201)
    def post(self, current_user):
        """Submit a new colour vision test result"""
        try:
            data = request.get_json()
            plate_ids = data['plate_ids']
            plate_images = data['plate_images']
            user_answers = data['user_answers']
            test_duration = data.get('test_duration', None)
            
            # Validate answers
            validation = validate_answers(plate_ids, user_answers)
            
            if not validation['is_valid']:
                colour_vision_ns.abort(400, validation.get('error', 'Invalid test data'))
            
            correct_answers = validation['correct_answers']
            correct_count = validation['correct_count']
            score = validation['score']
            control_plate_failed = validation.get('control_plate_failed', False)
            missed_plate_types = validation.get('missed_plate_types', {})
            
            # Classify result with specific deficiency type diagnosis
            severity = classify_result(score, control_plate_failed, missed_plate_types)
            
            # Create test record
            test = ColourVisionTest(
                user_id=current_user.id,
                total_plates=len(plate_ids),
                correct_count=correct_count,
                score=score,
                severity=severity,
                test_duration=test_duration
            )
            
            # Set JSON data
            test.set_plate_data(plate_ids, plate_images)
            test.set_answers(user_answers, correct_answers)
            
            # Save to database
            db.session.add(test)
            db.session.commit()
            
            # Return result with optional warning
            result = test.to_dict()
            if validation.get('warning'):
                result['warning'] = validation['warning']
            result['medical_disclaimer'] = (
                "NOTE: This is a screening test using synthetic images, not medical-grade Ishihara plates. "
                "Results are for educational purposes only. Consult an eye care professional for proper diagnosis."
            )
            
            return result, 201
            
        except KeyError as e:
            colour_vision_ns.abort(400, f'Missing required field: {str(e)}')
        except Exception as e:
            db.session.rollback()
            colour_vision_ns.abort(500, f'Error saving test: {str(e)}')
    
    @token_required
    @colour_vision_ns.doc('get_colour_vision_tests')
    @colour_vision_ns.marshal_list_with(test_response_model)
    def get(self, current_user):
        """Get all colour vision tests for the current user"""
        try:
            tests = ColourVisionTest.query.filter_by(user_id=current_user.id)\
                .order_by(ColourVisionTest.created_at.desc())\
                .all()
            
            return [test.to_dict() for test in tests], 200
            
        except Exception as e:
            colour_vision_ns.abort(500, f'Error retrieving tests: {str(e)}')


@colour_vision_ns.route('/tests/<int:test_id>')
class ColourVisionTestDetail(Resource):
    @token_required
    @colour_vision_ns.doc('get_colour_vision_test')
    @colour_vision_ns.marshal_with(test_response_model)
    def get(self, current_user, test_id):
        """Get a specific colour vision test result"""
        try:
            test = ColourVisionTest.query.filter_by(
                id=test_id,
                user_id=current_user.id
            ).first()
            
            if not test:
                colour_vision_ns.abort(404, 'Test not found')
            
            return test.to_dict(), 200
            
        except Exception as e:
            colour_vision_ns.abort(500, f'Error retrieving test: {str(e)}')
