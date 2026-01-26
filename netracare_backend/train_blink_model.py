"""
Script to train the Blink Fatigue Detection CNN Model
Run this script to train the model on the drowsy/notdrowsy dataset
"""

import os
import sys
from pathlib import Path
from blink_fatigue_model import BlinkFatigueModel

def main():
    """Train the blink fatigue detection model"""
    
    # Dataset path - adjust if needed
    DATASET_PATH = r"D:\3rd_Year\Dataset\train_data"
    
    # Model save path
    MODEL_SAVE_PATH = os.path.join(
        os.path.dirname(__file__), 
        'models', 
        'blink_fatigue_model.keras'
    )
    
    print("=" * 60)
    print("Blink Fatigue Detection - Model Training")
    print("=" * 60)
    
    # Verify dataset exists
    if not os.path.exists(DATASET_PATH):
        print(f"❌ ERROR: Dataset not found at {DATASET_PATH}")
        print("Please ensure the train_data folder exists with drowsy/ and notdrowsy/ subfolders")
        sys.exit(1)
    
    # Check for drowsy and notdrowsy folders
    drowsy_path = os.path.join(DATASET_PATH, 'drowsy')
    notdrowsy_path = os.path.join(DATASET_PATH, 'notdrowsy')
    
    if not os.path.exists(drowsy_path) or not os.path.exists(notdrowsy_path):
        print(f"❌ ERROR: Required folders not found")
        print(f"Expected: {drowsy_path}")
        print(f"Expected: {notdrowsy_path}")
        sys.exit(1)
    
    # Count images
    drowsy_count = len([f for f in os.listdir(drowsy_path) if f.endswith('.jpg')])
    notdrowsy_count = len([f for f in os.listdir(notdrowsy_path) if f.endswith('.jpg')])
    
    print(f"\n📊 Dataset Statistics:")
    print(f"  - Drowsy images: {drowsy_count}")
    print(f"  - Not drowsy images: {notdrowsy_count}")
    print(f"  - Total images: {drowsy_count + notdrowsy_count}")
    
    # Initialize model
    print(f"\n🔧 Initializing CNN model...")
    model = BlinkFatigueModel()
    
    print(f"\n📝 Model Architecture:")
    model.model.summary()
    
    # Training configuration
    EPOCHS = 50
    BATCH_SIZE = 32
    VALIDATION_SPLIT = 0.2
    
    print(f"\n🎯 Training Configuration:")
    print(f"  - Epochs: {EPOCHS}")
    print(f"  - Batch Size: {BATCH_SIZE}")
    print(f"  - Validation Split: {VALIDATION_SPLIT * 100}%")
    print(f"  - Image Size: {model.img_height}x{model.img_width}")
    
    # Start training
    print(f"\n🚀 Starting training...")
    print("-" * 60)
    
    try:
        history = model.train(
            train_data_path=DATASET_PATH,
            validation_split=VALIDATION_SPLIT,
            epochs=EPOCHS,
            batch_size=BATCH_SIZE
        )
        
        print("\n" + "=" * 60)
        print("✅ Training Completed Successfully!")
        print("=" * 60)
        print(f"\n📊 Final Results:")
        print(f"  - Final Validation Accuracy: {history['final_val_accuracy']:.4f}")
        print(f"  - Final Validation Loss: {history['final_val_loss']:.4f}")
        print(f"  - Best Validation Accuracy: {history['best_val_accuracy']:.4f}")
        print(f"  - Epochs Trained: {history['epochs_trained']}")
        
        # Save model
        print(f"\n💾 Saving model to {MODEL_SAVE_PATH}...")
        model.save_model(MODEL_SAVE_PATH)
        
        print(f"\n✅ Model saved successfully!")
        print(f"\n🎉 Training complete! Model is ready for predictions.")
        
    except Exception as e:
        print(f"\n❌ Training failed: {str(e)}")
        sys.exit(1)


if __name__ == "__main__":
    main()
