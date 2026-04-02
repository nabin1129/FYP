"""
Blink and Eye Fatigue Detection Model
MobileNetV2 transfer-learning based drowsiness detection using eye images.

Two-phase training:
  Phase 1 — frozen MobileNetV2 base, train new head only (fast convergence).
  Phase 2 — unfreeze top layers of base for fine-tuning (higher accuracy).
"""

import os
import numpy as np
from typing import Dict
import cv2
from tensorflow import keras
from tensorflow.keras import layers
from tensorflow.keras.applications import MobileNetV2
from tensorflow.keras.preprocessing.image import ImageDataGenerator
from tensorflow.keras.callbacks import EarlyStopping, ModelCheckpoint, ReduceLROnPlateau
import tensorflow as tf


class BlinkFatigueModel:
    """MobileNetV2-based transfer learning model for drowsiness/fatigue detection."""
    DROWSY_LABEL_THRESHOLD = 0.6

    # MobileNetV2 native input size — better ImageNet feature reuse
    IMG_HEIGHT = 224
    IMG_WIDTH = 224

    # Number of top MobileNetV2 layers to unfreeze in phase 2
    UNFREEZE_LAYERS = 30

    def __init__(self, model_path: str = None):
        self.model = None
        # Keep legacy attributes for compatibility with prediction/preprocessing code
        self.img_height = self.IMG_HEIGHT
        self.img_width = self.IMG_WIDTH
        self.class_names = ['drowsy', 'notdrowsy']

        if model_path and os.path.exists(model_path):
            self.load_model(model_path)
        else:
            self.model = self._build_model()

    # ------------------------------------------------------------------
    # Model construction
    # ------------------------------------------------------------------

    def _build_model(self) -> keras.Model:
        """Build MobileNetV2 transfer-learning model."""
        base = MobileNetV2(
            input_shape=(self.IMG_HEIGHT, self.IMG_WIDTH, 3),
            include_top=False,
            weights='imagenet',
        )
        base.trainable = False  # freeze for phase-1 training

        inputs = keras.Input(shape=(self.IMG_HEIGHT, self.IMG_WIDTH, 3))
        # MobileNetV2 expects inputs pre-processed via its own preprocess_input
        x = tf.keras.applications.mobilenet_v2.preprocess_input(inputs)
        x = base(x, training=False)
        x = layers.GlobalAveragePooling2D()(x)
        x = layers.Dense(256, activation='relu')(x)
        x = layers.Dropout(0.4)(x)
        x = layers.Dense(128, activation='relu')(x)
        x = layers.Dropout(0.2)(x)
        outputs = layers.Dense(2, activation='softmax')(x)

        model = keras.Model(inputs, outputs)
        model.compile(
            optimizer=keras.optimizers.Adam(learning_rate=1e-3),
            loss='categorical_crossentropy',
            metrics=['accuracy'],
        )
        return model

    def _unfreeze_top_layers(self) -> None:
        """Unfreeze the top UNFREEZE_LAYERS of the MobileNetV2 base for fine-tuning."""
        base = self.model.layers[3]  # MobileNetV2 layer inside the functional model
        base.trainable = True
        for layer in base.layers[:-self.UNFREEZE_LAYERS]:
            layer.trainable = False

        # Use a much lower LR to avoid destroying pre-trained weights
        self.model.compile(
            optimizer=keras.optimizers.Adam(learning_rate=1e-5),
            loss='categorical_crossentropy',
            metrics=['accuracy'],
        )

    # ------------------------------------------------------------------
    # Training
    # ------------------------------------------------------------------

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

        # Compute class weights to handle the ~36K drowsy / ~30K notdrowsy imbalance
        class_counts = {
            cls: len(os.listdir(os.path.join(train_data_path, cls)))
            for cls in os.listdir(train_data_path)
            if os.path.isdir(os.path.join(train_data_path, cls))
        }
        total = sum(class_counts.values())
        n_classes = len(class_counts)
        # Map class index -> weight (flow_from_directory sorts alphabetically: drowsy=0, notdrowsy=1)
        sorted_classes = sorted(class_counts.keys())
        class_weight = {
            i: total / (n_classes * class_counts[cls])
            for i, cls in enumerate(sorted_classes)
        }
        print(f"Class weights: {class_weight}")

        # IMPORTANT: Both generators MUST share the same ImageDataGenerator instance
        # with validation_split set — using two separate instances causes the split
        # to be computed independently and train/val sets can overlap.
        #
        # MobileNetV2 preprocess_input is applied inside the model graph, so we
        # pass raw pixel values (no /255 rescaling) here.
        datagen = ImageDataGenerator(
            validation_split=validation_split,
            rotation_range=20,
            width_shift_range=0.15,
            height_shift_range=0.15,
            horizontal_flip=True,
            zoom_range=0.15,
            shear_range=0.1,
            brightness_range=[0.7, 1.3],
            channel_shift_range=20.0,
            fill_mode='nearest',
        )

        train_generator = datagen.flow_from_directory(
            train_data_path,
            target_size=(self.IMG_HEIGHT, self.IMG_WIDTH),
            batch_size=batch_size,
            class_mode='categorical',
            subset='training',
            shuffle=True,
            seed=42,
        )

        # Validation generator from the SAME datagen instance — no augmentation
        # applied to val images because subset='validation' bypasses transforms.
        validation_generator = datagen.flow_from_directory(
            train_data_path,
            target_size=(self.IMG_HEIGHT, self.IMG_WIDTH),
            batch_size=batch_size,
            class_mode='categorical',
            subset='validation',
            shuffle=False,
            seed=42,
        )

        model_dir = os.path.join(os.path.dirname(__file__), 'models')
        os.makedirs(model_dir, exist_ok=True)
        best_ckpt = os.path.join(model_dir, 'best_blink_fatigue.keras')

        base_callbacks = [
            EarlyStopping(
                monitor='val_accuracy',
                patience=8,
                restore_best_weights=True,
                verbose=1,
            ),
            ModelCheckpoint(
                filepath=best_ckpt,
                monitor='val_accuracy',
                save_best_only=True,
                verbose=1,
            ),
            ReduceLROnPlateau(
                monitor='val_loss',
                factor=0.5,
                patience=4,
                min_lr=1e-7,
                verbose=1,
            ),
        ]

        # ── Phase 1: train head only (frozen base) ──────────────────────
        phase1_epochs = min(epochs, 15)
        print(f"\n[Phase 1] Training new head ({phase1_epochs} epochs, frozen MobileNetV2 base)…")
        h1 = self.model.fit(
            train_generator,
            validation_data=validation_generator,
            epochs=phase1_epochs,
            callbacks=base_callbacks,
            class_weight=class_weight,
            verbose=1,
        )

        # ── Phase 2: fine-tune top layers of base ───────────────────────
        remaining = epochs - phase1_epochs
        all_acc = list(h1.history['accuracy'])
        all_val_acc = list(h1.history['val_accuracy'])
        all_loss = list(h1.history['loss'])
        all_val_loss = list(h1.history['val_loss'])

        if remaining > 0:
            print(f"\n[Phase 2] Fine-tuning top {self.UNFREEZE_LAYERS} MobileNetV2 layers ({remaining} epochs)…")
            self._unfreeze_top_layers()
            h2 = self.model.fit(
                train_generator,
                validation_data=validation_generator,
                epochs=remaining,
                callbacks=base_callbacks,
                class_weight=class_weight,
                verbose=1,
            )
            all_acc += list(h2.history['accuracy'])
            all_val_acc += list(h2.history['val_accuracy'])
            all_loss += list(h2.history['loss'])
            all_val_loss += list(h2.history['val_loss'])

        val_loss, val_accuracy = self.model.evaluate(validation_generator, verbose=0)

        return {
            'final_val_accuracy': float(val_accuracy),
            'final_val_loss': float(val_loss),
            'epochs_trained': len(all_acc),
            'best_val_accuracy': float(max(all_val_acc)),
            'history': {
                'accuracy': [float(x) for x in all_acc],
                'val_accuracy': [float(x) for x in all_val_acc],
                'loss': [float(x) for x in all_loss],
                'val_loss': [float(x) for x in all_val_loss],
            },
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

        # MobileNetV2 preprocess_input is applied inside the model graph,
        # so pass raw float32 pixel values in [0, 255] (no /255 rescaling).
        img = img.astype('float32')

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
        
        # Calculate probabilities for both classes
        drowsy_probability = float(predictions[0][0])
        notdrowsy_probability = float(predictions[0][1])

        # Use a thresholded decision so borderline values are treated as normal.
        is_drowsy = drowsy_probability >= self.DROWSY_LABEL_THRESHOLD
        predicted_class = 'drowsy' if is_drowsy else 'notdrowsy'
        confidence = drowsy_probability if is_drowsy else notdrowsy_probability
        
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
