"""
Colour Vision Test Model
Contains plate metadata, validation logic, and scoring functions for Ishihara tests.
"""

# Ishihara plate metadata with correct answers and multiple-choice options
# NOTE: These should match what your actual Ishihara images show
# Update these based on your specific dataset images
ISHIHARA_PLATE_METADATA = {
    0: {
        "correct_answer": "0",
        "options": ["0", "6", "8", "Nothing"],
        "description": "Control plate - visible to all",
        "difficulty": "easy",
        "plate_type": "control"  # Must be seen by everyone
    },
    1: {
        "correct_answer": "1",
        "options": ["1", "7", "11", "Nothing"],
        "description": "Tests red-green deficiency",
        "difficulty": "easy",
        "plate_type": "red_green"  # Red-green deficiency test
    },
    2: {
        "correct_answer": "2",
        "options": ["2", "5", "12", "Nothing"],
        "description": "Tests red-green deficiency",
        "difficulty": "easy",
        "plate_type": "red_green"
    },
    3: {
        "correct_answer": "3",
        "options": ["3", "5", "8", "Nothing"],
        "description": "Tests red-green deficiency",
        "difficulty": "medium",
        "plate_type": "red_green"
    },
    4: {
        "correct_answer": "4",
        "options": ["4", "9", "14", "Nothing"],
        "description": "Tests red-green deficiency",
        "difficulty": "medium",
        "plate_type": "red_green"
    },
    5: {
        "correct_answer": "5",
        "options": ["5", "3", "6", "Nothing"],
        "description": "Tests red-green deficiency",
        "difficulty": "medium",
        "plate_type": "red_green"
    },
    6: {
        "correct_answer": "6",
        "options": ["6", "8", "9", "Nothing"],
        "description": "Tests red-green deficiency",
        "difficulty": "medium",
        "plate_type": "red_green"
    },
    7: {
        "correct_answer": "7",
        "options": ["7", "1", "17", "Nothing"],
        "description": "Tests blue-yellow deficiency",
        "difficulty": "hard",
        "plate_type": "blue_yellow"  # Blue-yellow deficiency test
    },
    8: {
        "correct_answer": "8",
        "options": ["8", "3", "6", "Nothing"],
        "description": "Tests blue-yellow deficiency",
        "difficulty": "hard",
        "plate_type": "blue_yellow"
    },
    9: {
        "correct_answer": "9",
        "options": ["9", "6", "8", "Nothing"],
        "description": "Tests total color blindness",
        "difficulty": "hard",
        "plate_type": "total"  # Total color blindness test
    }
}


def get_plate_metadata(plate_number: int) -> dict:
    """
    Get metadata for a specific Ishihara plate
    
    Args:
        plate_number: Plate number (0-9)
        
    Returns:
        Dictionary containing plate metadata
        
    Raises:
        ValueError: If plate number is invalid
    """
    if plate_number not in ISHIHARA_PLATE_METADATA:
        raise ValueError(f"Invalid plate number: {plate_number}. Must be between 0 and 9.")
    
    return ISHIHARA_PLATE_METADATA[plate_number]


def validate_answers(plate_ids: list, user_answers: list) -> dict:
    """
    Validate user answers against correct answers
    
    Args:
        plate_ids: List of plate numbers shown in test
        user_answers: List of user's selected answers
        
    Returns:
        Dictionary with validation results:
        {
            'is_valid': bool,
            'correct_answers': list,
            'correct_count': int,
            'total_plates': int,
            'score': int (percentage),
            'control_plate_failed': bool,
            'warning': str (optional),
            'missed_plate_types': dict (counts of missed plates by type)
        }
    """
    if len(plate_ids) != len(user_answers):
        return {
            'is_valid': False,
            'error': 'Mismatch between plate_ids and user_answers length'
        }
    
    correct_answers = []
    correct_count = 0
    control_plate_failed = False
    missed_plate_types = {
        'red_green': 0,
        'blue_yellow': 0,
        'total': 0
    }
    
    for plate_id, user_answer in zip(plate_ids, user_answers):
        try:
            plate_meta = get_plate_metadata(plate_id)
            correct_answer = plate_meta['correct_answer']
            correct_answers.append(correct_answer)
            
            if user_answer == correct_answer:
                correct_count += 1
            else:
                # Check if this is the control plate (plate 0)
                if plate_id == 0:
                    control_plate_failed = True
                else:
                    # Track which type of plate was missed
                    plate_type = plate_meta.get('plate_type', 'unknown')
                    if plate_type in missed_plate_types:
                        missed_plate_types[plate_type] += 1
        except ValueError as e:
            return {
                'is_valid': False,
                'error': str(e)
            }
    
    total_plates = len(plate_ids)
    # Use round() for consistent rounding instead of int() truncation
    score = round((correct_count / total_plates) * 100) if total_plates > 0 else 0
    
    result = {
        'is_valid': True,
        'correct_answers': correct_answers,
        'correct_count': correct_count,
        'total_plates': total_plates,
        'score': score,
        'control_plate_failed': control_plate_failed,
        'missed_plate_types': missed_plate_types
    }
    
    # Add warning if control plate failed
    if control_plate_failed:
        result['warning'] = 'Control plate (Plate 0) was incorrect. Test results may be unreliable.'
    
    return result


def calculate_score(correct_count: int, total_plates: int) -> int:
    """
    Calculate percentage score
    
    Args:
        correct_count: Number of correct answers
        total_plates: Total number of plates shown
        
    Returns:
        Score as integer percentage (0-100)
    """
    if total_plates <= 0:
        return 0
    return int((correct_count / total_plates) * 100)


def classify_result(score: int, control_plate_failed: bool = False, missed_plate_types: dict = None) -> str:
    """
    Classify color vision test result and diagnose specific deficiency type
    
    Args:
        score: Test score as percentage (0-100)
        control_plate_failed: Whether the control plate (plate 0) was incorrect
        missed_plate_types: Dictionary of missed plates by type
        
    Returns:
        Specific deficiency diagnosis string
    """
    # If control plate failed, results are unreliable
    if control_plate_failed:
        return "Test Unreliable - Please Retake"
    
    # If score is perfect or near-perfect, normal vision
    if score >= 90:
        return "Normal Color Vision"
    
    # Analyze missed plate types to determine specific deficiency
    if missed_plate_types:
        red_green_missed = missed_plate_types.get('red_green', 0)
        blue_yellow_missed = missed_plate_types.get('blue_yellow', 0)
        total_missed = missed_plate_types.get('total', 0)
        
        # Total color blindness (monochromacy)
        if total_missed > 0 or score < 30:
            return "Total Color Blindness (Monochromacy)"
        
        # Both red-green and blue-yellow missed
        if red_green_missed > 0 and blue_yellow_missed > 0:
            if red_green_missed > blue_yellow_missed:
                return "Red-Green Color Deficiency (Deuteranomaly/Protanomaly)"
            else:
                return "Blue-Yellow Color Deficiency (Tritanomaly)"
        
        # Primarily red-green deficiency
        if red_green_missed > 0:
            if score < 50:
                return "Severe Red-Green Deficiency (Protanopia/Deuteranopia)"
            elif score < 70:
                return "Moderate Red-Green Deficiency"
            else:
                return "Mild Red-Green Deficiency"
        
        # Primarily blue-yellow deficiency
        if blue_yellow_missed > 0:
            if score < 50:
                return "Severe Blue-Yellow Deficiency (Tritanopia)"
            elif score < 70:
                return "Moderate Blue-Yellow Deficiency"
            else:
                return "Mild Blue-Yellow Deficiency"
    
    # Fallback classification based on score only
    if score >= 80:
        return "Borderline - Possible Mild Deficiency"
    elif score >= 60:
        return "Mild Color Vision Deficiency"
    elif score >= 40:
        return "Moderate Color Vision Deficiency"
    else:
        return "Severe Color Vision Deficiency"


def get_all_plate_numbers() -> list:
    """
    Get list of all available plate numbers
    
    Returns:
        List of plate numbers (0-9)
    """
    return list(ISHIHARA_PLATE_METADATA.keys())
