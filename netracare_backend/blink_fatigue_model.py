"""
Blink and Eye Fatigue Detection Model
CNN-based drowsiness detection using eye images
"""

import os
import numpy as np
from pathlib import Path
from typing import Tuple, Dict
import cv2
from tensorflow import keras
from tensorflow.keras import layers
from tensorflow.keras.preprocessing.image import ImageDataGenerator
from tensorflow.keras.callbacks import EarlyStopping, ModelCheckpoint, ReduceLROnPlateau


class BlinkFatigueModel:
    """CNN model for detecting drowsiness/fatigue from eye images"""
    
    def __init__(self, model_path: str = None):
        """
        Initialize the blink fatigue model
        
        Args:
            model_path: Path to saved model file (.keras or .h5)
        """
        self.model = None
        self.img_height = 145
        self.img_width = 145
        self.class_names = ['drowsy', 'notdrowsy']
        
        if model_path and os.path.exists(model_path):
            self.load_model(model_path)
        else:
            self.model = self._build_model()
    
    def _build_model(self) -> keras.Model:
        """
        Build CNN architecture based on Kaggle implementation
        Enhanced architecture for better drowsiness detection
        """
        model = keras.Sequential([
            # First convolutional block
            layers.Conv2D(32, (3, 3), activation='relu', 
                         input_shape=(self.img_height, self.img_width, 3)),
            layers.MaxPooling2D((2, 2)),
            layers.BatchNormalization(),
            
            # Second convolutional block
            layers.Conv2D(64, (3, 3), activation='relu'),
            layers.MaxPooling2D((2, 2)),
            layers.BatchNormalization(),
            
            # Third convolutional block
            layers.Conv2D(128, (3, 3), activation='relu'),
            layers.MaxPooling2D((2, 2)),
            layers.BatchNormalization(),
            
            # Fourth convolutional block
            layers.Conv2D(256, (3, 3), activation='relu'),
            layers.MaxPooling2D((2, 2)),
            layers.BatchNormalization(),
            
            # Flatten and dense layers
            layers.Flatten(),
            layers.Dropout(0.5),
            layers.Dense(512, activation='relu'),
            layers.Dropout(0.3),
            layers.Dense(256, activation='relu'),
            layers.Dropout(0.2),
            
            # Output layer - binary classification
            layers.Dense(2, activation='softmax')
        ])
        
        model.compile(
            optimizer=keras.optimizers.Adam(learning_rate=0.001),
            loss='categorical_crossentropy',
            metrics=['accuracy']
        )
        
        return model
    
    def train(self, train_data_path: str, validation_split: float = 0.2, 
              epochs: int = 50, batch_size: int = 32) -> Dict:
        """
        Train the CNN model on drowsy/notdrowsy dataset
        
        Args:
            train_data_path: Path to train_data folder containing drowsy/ and notdrowsy/ subfolders
            validation_split: Fraction of data to use for validation
            epochs: Number of training epochs
            batch_size: Batch size for training
            
        Returns:
            Dictionary containing training history and metrics
        """
        if not os.path.exists(train_data_path):
            raise FileNotFoundError(f"Training data not found at {train_data_path}")
        
        # Data augmentation for better generalization
        train_datagen = ImageDataGenerator(
            rescale=1./255,
            validation_split=validation_split,
            rotation_range=15,
            width_shift_range=0.1,
            height_shift_range=0.1,
            horizontal_flip=True,
            zoom_range=0.1,
            brightness_range=[0.8, 1.2]
        )
        
        # Training data generator
        train_generator = train_datagen.flow_from_directory(
            train_data_path,
            target_size=(self.img_height, self.img_width),
            batch_size=batch_size,
            class_mode='categorical',
            subset='training',
            shuffle=True
        )
        
        # Validation data generator
        validation_generator = train_datagen.flow_from_directory(
            train_data_path,
            target_size=(self.img_height, self.img_width),
            batch_size=batch_size,
            class_mode='categorical',
            subset='validation',
            shuffle=True
        )
        
        # Callbacks for better training
        callbacks = [
            EarlyStopping(
                monitor='val_accuracy',
                patience=10,
                restore_best_weights=True,
                verbose=1
            ),
            ReduceLROnPlateau(
                monitor='val_loss',
                factor=0.5,
                patience=5,
                min_lr=1e-7,
                verbose=1
            )
        ]
        
        # Train the model
        history = self.model.fit(
            train_generator,
            validation_data=validation_generator,
            epochs=epochs,
            callbacks=callbacks,
            verbose=1
        )
        
        # Evaluate on validation set
        val_loss, val_accuracy = self.model.evaluate(validation_generator, verbose=0)
        
        return {
            'final_val_accuracy': float(val_accuracy),
            'final_val_loss': float(val_loss),
            'epochs_trained': len(history.history['accuracy']),
            'best_val_accuracy': float(max(history.history['val_accuracy'])),
            'history': {
                'accuracy': [float(x) for x in history.history['accuracy']],
                'val_accuracy': [float(x) for x in history.history['val_accuracy']],
                'loss': [float(x) for x in history.history['loss']],
                'val_loss': [float(x) for x in history.history['val_loss']]
            }
        }
    
    def save_model(self, save_path: str) -> None:
        """
        Save trained model to disk
        
        Args:
            save_path: Path to save model file (.keras format)
        """
        if self.model is None:
            raise ValueError("No model to save. Train or load a model first.")
        
        # Create directory if it doesn't exist
        os.makedirs(os.path.dirname(save_path), exist_ok=True)
        self.model.save(save_path)
        print(f"Model saved to {save_path}")
    
    def load_model(self, model_path: str) -> None:
        """
        Load a trained model from disk
        
        Args:
            model_path: Path to saved model file
        """
        if not os.path.exists(model_path):
            raise FileNotFoundError(f"Model file not found at {model_path}")
        
        self.model = keras.models.load_model(model_path)
        print(f"Model loaded from {model_path}")
    
    def preprocess_image(self, image_input) -> np.ndarray:
        """
        Preprocess image for prediction
        
        Args:
            image_input: Can be file path (str), numpy array, or bytes
            
        Returns:
            Preprocessed image array ready for prediction
        """
        # Handle different input types
        if isinstance(image_input, str):
            # File path
            img = cv2.imread(image_input)
        elif isinstance(image_input, bytes):
            # Bytes from uploaded file
            nparr = np.frombuffer(image_input, np.uint8)
            img = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
        elif isinstance(image_input, np.ndarray):
            # Already a numpy array
            img = image_input
        else:
            raise ValueError("Invalid image input type. Expected str, bytes, or numpy.ndarray")
        
        if img is None:
            raise ValueError("Failed to load image")
        
        # Convert BGR to RGB (OpenCV loads as BGR)
        img = cv2.cvtColor(img, cv2.COLOR_BGR2RGB)
        
        # Resize to model input size
        img = cv2.resize(img, (self.img_width, self.img_height))
        
        # Normalize pixel values
        img = img.astype('float32') / 255.0
        
        # Add batch dimension
        img = np.expand_dims(img, axis=0)
        
        return img
    
    def predict(self, image_input) -> Dict:
        """
        Predict drowsiness from eye image
        
        Args:
            image_input: Image to analyze (file path, bytes, or numpy array)
            
        Returns:
            Dictionary with prediction results
        """
        if self.model is None:
            raise ValueError("Model not loaded. Train or load a model first.")
        
        # Preprocess image
        processed_img = self.preprocess_image(image_input)
        
        # Make prediction
        predictions = self.model.predict(processed_img, verbose=0)
        
        # Get predicted class and confidence
        predicted_class_idx = np.argmax(predictions[0])
        predicted_class = self.class_names[predicted_class_idx]
        confidence = float(predictions[0][predicted_class_idx])
        
        # Calculate probabilities for both classes
        drowsy_probability = float(predictions[0][0])
        notdrowsy_probability = float(predictions[0][1])
        
        # Determine fatigue level
        fatigue_level = self._classify_fatigue_level(drowsy_probability)
        
        return {
            'prediction': predicted_class,
            'confidence': confidence,
            'probabilities': {
                'drowsy': drowsy_probability,
                'notdrowsy': notdrowsy_probability
            },
            'fatigue_level': fatigue_level,
            'alert': drowsy_probability > 0.7,  # Alert if high drowsiness probability
            'timestamp': str(np.datetime64('now'))
        }
    
    def _classify_fatigue_level(self, drowsy_prob: float) -> str:
        """
        Classify fatigue level based on drowsiness probability
        
        Args:
            drowsy_prob: Probability of drowsiness (0-1)
            
        Returns:
            Fatigue level classification
        """
        if drowsy_prob >= 0.8:
            return 'Critical - High Fatigue'
        elif drowsy_prob >= 0.6:
            return 'High Fatigue'
        elif drowsy_prob >= 0.4:
            return 'Moderate Fatigue'
        elif drowsy_prob >= 0.2:
            return 'Low Fatigue'
        else:
            return 'Alert'
    
    def predict_batch(self, image_list: list) -> list:
        """
        Predict drowsiness for multiple images
        
        Args:
            image_list: List of images (file paths, bytes, or numpy arrays)
            
        Returns:
            List of prediction dictionaries
        """
        return [self.predict(img) for img in image_list]
    
    def evaluate_model(self, test_data_path: str, batch_size: int = 32) -> Dict:
        """
        Evaluate model on test dataset
        
        Args:
            test_data_path: Path to test data folder
            batch_size: Batch size for evaluation
            
        Returns:
            Dictionary with evaluation metrics
        """
        if self.model is None:
            raise ValueError("Model not loaded. Train or load a model first.")
        
        if not os.path.exists(test_data_path):
            raise FileNotFoundError(f"Test data not found at {test_data_path}")
        
        # Create test data generator (no augmentation)
        test_datagen = ImageDataGenerator(rescale=1./255)
        
        test_generator = test_datagen.flow_from_directory(
            test_data_path,
            target_size=(self.img_height, self.img_width),
            batch_size=batch_size,
            class_mode='categorical',
            shuffle=False
        )
        
        # Evaluate
        test_loss, test_accuracy = self.model.evaluate(test_generator, verbose=1)
        
        return {
            'test_accuracy': float(test_accuracy),
            'test_loss': float(test_loss)
        }


def get_model_singleton(model_path: str = None) -> BlinkFatigueModel:
    """
    Get or create singleton instance of BlinkFatigueModel
    
    Args:
        model_path: Optional path to load existing model
        
    Returns:
        BlinkFatigueModel instance
    """
    if not hasattr(get_model_singleton, '_instance'):
        # Default model path in backend directory
        if model_path is None:
            model_path = os.path.join(
                os.path.dirname(__file__), 
                'models', 
                'blink_fatigue_model.keras'
            )
        
        get_model_singleton._instance = BlinkFatigueModel(model_path)
    
    return get_model_singleton._instance
