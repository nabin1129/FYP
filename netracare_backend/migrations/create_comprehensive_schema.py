"""
Comprehensive Migration Script - Netra Care System
Implements all tables required as per project proposal
- Users with medical history
- Visual Acuity Tests
- Colour Vision Tests (Ishihara)
- Pupil Reflex Tests (Nystagmus Detection)
- AI Reports Generation
- Distance Calibration (ARCore/ARKit)
"""
import sqlite3
import os
from datetime import datetime

db_path = os.path.join(os.path.dirname(os.path.dirname(__file__)), 'db.sqlite3')

def migrate():
    """Create comprehensive database schema"""
    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()
    
    try:
        print("🚀 Starting Netra Care comprehensive migration...")
        print(f"📍 Database: {db_path}\n")
        
        # ===== 1. USERS TABLE (Enhanced with Medical History) =====
        cursor.execute("""
            CREATE TABLE IF NOT EXISTS users (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                username VARCHAR(80) UNIQUE NOT NULL,
                email VARCHAR(120) UNIQUE NOT NULL,
                password_hash VARCHAR(255) NOT NULL,
                
                -- Personal Information
                full_name VARCHAR(100),
                date_of_birth DATE,
                gender VARCHAR(10),
                phone VARCHAR(20),
                
                -- Medical History
                has_glasses BOOLEAN DEFAULT 0,
                has_eye_disease BOOLEAN DEFAULT 0,
                eye_disease_details TEXT,
                family_history TEXT,
                current_medications TEXT,
                allergies TEXT,
                
                -- Settings
                preferred_language VARCHAR(10) DEFAULT 'en',
                notification_enabled BOOLEAN DEFAULT 1,
                
                -- Timestamps
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                last_login TIMESTAMP
            )
        """)
        print("✓ Users table created/verified")
        
        # ===== 2. VISUAL ACUITY TESTS TABLE =====
        cursor.execute("""
            CREATE TABLE IF NOT EXISTS visual_acuity_tests (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                user_id INTEGER NOT NULL,
                
                -- Test Configuration
                test_type VARCHAR(20) NOT NULL,
                test_distance FLOAT DEFAULT 1.0,
                device_calibrated BOOLEAN DEFAULT 0,
                calibration_method VARCHAR(30),
                screen_size_inches FLOAT,
                device_model VARCHAR(100),
                
                -- Test Results per Eye
                left_eye_score VARCHAR(10),
                right_eye_score VARCHAR(10),
                both_eyes_score VARCHAR(10),
                
                -- Detailed Metrics
                correct_answers INTEGER,
                total_questions INTEGER,
                accuracy_percentage FLOAT,
                smallest_line_read INTEGER,
                
                -- AI Analysis
                condition_detected VARCHAR(50),
                severity VARCHAR(20),
                confidence_score FLOAT,
                recommended_action TEXT,
                
                -- Testing Environment
                ambient_light_level VARCHAR(20),
                user_distance_cm FLOAT,
                
                -- Metadata
                test_duration INTEGER,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                
                FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
            )
        """)
        print("✓ Visual Acuity Tests table created")
        
        # ===== 3. COLOUR VISION TESTS TABLE (Ishihara) =====
        cursor.execute("""
            CREATE TABLE IF NOT EXISTS colour_vision_tests (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                user_id INTEGER NOT NULL,
                
                -- Test Configuration
                total_plates INTEGER DEFAULT 24,
                test_duration INTEGER,
                
                -- Results
                correct_answers INTEGER,
                accuracy_percentage FLOAT,
                
                -- Deficiency Detection
                colorblind_type VARCHAR(30),
                severity VARCHAR(20),
                
                -- Specific Deficiencies
                protanopia BOOLEAN DEFAULT 0,
                deuteranopia BOOLEAN DEFAULT 0,
                tritanopia BOOLEAN DEFAULT 0,
                protanomaly BOOLEAN DEFAULT 0,
                deuteranomaly BOOLEAN DEFAULT 0,
                tritanomaly BOOLEAN DEFAULT 0,
                
                -- Detailed Answers (JSON format in TEXT)
                answers_log TEXT,
                
                -- AI Analysis
                confidence_score FLOAT,
                recommendations TEXT,
                
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                
                FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
            )
        """)
        print("✓ Colour Vision Tests table created")
        
        # ===== 4. PUPIL REFLEX TESTS TABLE (Nystagmus Detection) =====
        cursor.execute("""
            CREATE TABLE IF NOT EXISTS pupil_reflex_tests (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                user_id INTEGER NOT NULL,
                
                -- Left Eye Pupil Data
                left_pupil_initial_size FLOAT,
                left_pupil_constricted_size FLOAT,
                left_pupil_reaction_time FLOAT,
                left_constriction_percentage FLOAT,
                
                -- Right Eye Pupil Data
                right_pupil_initial_size FLOAT,
                right_pupil_constricted_size FLOAT,
                right_pupil_reaction_time FLOAT,
                right_constriction_percentage FLOAT,
                
                -- Reflex Analysis
                normal_reflex_left BOOLEAN DEFAULT 1,
                normal_reflex_right BOOLEAN DEFAULT 1,
                reflex_symmetry BOOLEAN DEFAULT 1,
                
                -- Nystagmus Detection (AI-based)
                nystagmus_detected BOOLEAN DEFAULT 0,
                nystagmus_type VARCHAR(50),
                nystagmus_severity VARCHAR(20),
                nystagmus_frequency FLOAT,
                nystagmus_confidence FLOAT,
                
                -- Abnormalities
                abnormal_reflex BOOLEAN DEFAULT 0,
                abnormality_details TEXT,
                requires_neurologist BOOLEAN DEFAULT 0,
                
                -- Video Analysis
                video_path VARCHAR(255),
                video_duration FLOAT,
                frames_analyzed INTEGER,
                fps INTEGER,
                
                -- Test Environment
                flash_intensity VARCHAR(20),
                ambient_light VARCHAR(20),
                
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                
                FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
            )
        """)
        print("✓ Pupil Reflex Tests table created")
        
        # ===== 5. DISTANCE CALIBRATION TABLE (ARCore/ARKit) =====
        cursor.execute("""
            CREATE TABLE IF NOT EXISTS distance_calibrations (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                user_id INTEGER,
                
                -- Calibration Method
                calibration_method VARCHAR(30) NOT NULL,
                platform VARCHAR(20),
                
                -- Distance Measurement
                measured_distance_cm FLOAT NOT NULL,
                target_distance_cm FLOAT DEFAULT 100,
                calibration_accuracy FLOAT,
                
                -- Device Information
                device_model VARCHAR(100),
                screen_size_inches FLOAT,
                camera_resolution VARCHAR(20),
                
                -- Reference Object (for manual calibration)
                reference_object VARCHAR(50),
                reference_object_size_cm FLOAT,
                
                -- AR Session Data (if using ARCore/ARKit)
                ar_session_data TEXT,
                tracking_quality VARCHAR(20),
                
                -- Validation
                is_validated BOOLEAN DEFAULT 0,
                validation_timestamp TIMESTAMP,
                
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                expires_at TIMESTAMP,
                
                FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
            )
        """)
        print("✓ Distance Calibration table created")
        
        # ===== 6. AI REPORTS TABLE (Comprehensive Reports) =====
        cursor.execute("""
            CREATE TABLE IF NOT EXISTS ai_reports (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                user_id INTEGER NOT NULL,
                
                -- Report Metadata
                report_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                report_type VARCHAR(50) DEFAULT 'comprehensive',
                report_number VARCHAR(50) UNIQUE,
                
                -- Test References (Foreign Keys)
                visual_acuity_test_id INTEGER,
                eye_tracking_session_id INTEGER,
                blink_fatigue_test_id INTEGER,
                colour_vision_test_id INTEGER,
                pupil_reflex_test_id INTEGER,
                
                -- Overall Assessment
                overall_health_score FLOAT,
                risk_level VARCHAR(20),
                
                -- Detected Conditions (JSON Array in TEXT)
                detected_conditions TEXT,
                
                -- AI-Generated Content
                ai_summary TEXT,
                detailed_analysis TEXT,
                recommendations TEXT,
                
                -- Visual Defects Detected
                has_refractive_error BOOLEAN DEFAULT 0,
                has_color_deficiency BOOLEAN DEFAULT 0,
                has_fatigue BOOLEAN DEFAULT 0,
                has_tracking_issues BOOLEAN DEFAULT 0,
                has_nystagmus BOOLEAN DEFAULT 0,
                
                -- Consultation Required
                requires_consultation BOOLEAN DEFAULT 0,
                urgency_level VARCHAR(20),
                specialist_type VARCHAR(50),
                
                -- Report Files & Data
                pdf_path VARCHAR(255),
                charts_data TEXT,
                
                -- Doctor Review Section (for future doctor dashboard)
                reviewed_by_doctor BOOLEAN DEFAULT 0,
                doctor_id INTEGER,
                doctor_notes TEXT,
                doctor_diagnosis TEXT,
                doctor_prescription TEXT,
                doctor_reviewed_at TIMESTAMP,
                followup_required BOOLEAN DEFAULT 0,
                followup_date DATE,
                
                -- Report Status
                status VARCHAR(20) DEFAULT 'pending',
                
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                
                FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
                FOREIGN KEY (visual_acuity_test_id) REFERENCES visual_acuity_tests(id),
                FOREIGN KEY (eye_tracking_session_id) REFERENCES camera_eye_tracking_sessions(id),
                FOREIGN KEY (blink_fatigue_test_id) REFERENCES blink_fatigue_tests(id),
                FOREIGN KEY (colour_vision_test_id) REFERENCES colour_vision_tests(id),
                FOREIGN KEY (pupil_reflex_test_id) REFERENCES pupil_reflex_tests(id)
            )
        """)
        print("✓ AI Reports table created")
        
        # ===== 7. UPDATE EXISTING TABLES =====
        
        # Add user_id to blink_fatigue_tests if not exists
        cursor.execute("PRAGMA table_info(blink_fatigue_tests)")
        blink_columns = [col[1] for col in cursor.fetchall()]
        
        if 'user_id' not in blink_columns:
            cursor.execute("ALTER TABLE blink_fatigue_tests ADD COLUMN user_id INTEGER")
            cursor.execute("CREATE INDEX IF NOT EXISTS idx_blink_user ON blink_fatigue_tests(user_id)")
            print("✓ Added user_id to blink_fatigue_tests")
        
        # Add user_id to camera_eye_tracking_sessions if not exists
        cursor.execute("PRAGMA table_info(camera_eye_tracking_sessions)")
        tracking_columns = [col[1] for col in cursor.fetchall()]
        
        if 'user_id' not in tracking_columns:
            cursor.execute("ALTER TABLE camera_eye_tracking_sessions ADD COLUMN user_id INTEGER")
            cursor.execute("CREATE INDEX IF NOT EXISTS idx_tracking_user ON camera_eye_tracking_sessions(user_id)")
            print("✓ Added user_id to camera_eye_tracking_sessions")
        
        # ===== 8. CREATE INDEXES FOR PERFORMANCE =====
        indexes = [
            "CREATE INDEX IF NOT EXISTS idx_users_email ON users(email)",
            "CREATE INDEX IF NOT EXISTS idx_users_username ON users(username)",
            "CREATE INDEX IF NOT EXISTS idx_visual_acuity_user ON visual_acuity_tests(user_id)",
            "CREATE INDEX IF NOT EXISTS idx_colour_vision_user ON colour_vision_tests(user_id)",
            "CREATE INDEX IF NOT EXISTS idx_pupil_reflex_user ON pupil_reflex_tests(user_id)",
            "CREATE INDEX IF NOT EXISTS idx_calibration_user ON distance_calibrations(user_id)",
            "CREATE INDEX IF NOT EXISTS idx_reports_user ON ai_reports(user_id)",
            "CREATE INDEX IF NOT EXISTS idx_reports_date ON ai_reports(report_date)",
        ]
        
        for index_sql in indexes:
            cursor.execute(index_sql)
        print("✓ Performance indexes created")
        
        conn.commit()
        
        # ===== 9. VERIFICATION =====
        cursor.execute("SELECT name FROM sqlite_master WHERE type='table' ORDER BY name")
        tables = cursor.fetchall()
        
        print("\n" + "="*60)
        print("✅ MIGRATION COMPLETED SUCCESSFULLY!")
        print("="*60)
        print(f"\n📊 Total Tables Created: {len(tables)}")
        print("\n📋 Database Schema:")
        for table in tables:
            cursor.execute(f"SELECT COUNT(*) FROM {table[0]}")
            count = cursor.fetchone()[0]
            print(f"   • {table[0]:<35} ({count} records)")
        
        print(f"\n📍 Database Location: {db_path}")
        print("🎯 Ready for Netra Care backend development!")
        
    except Exception as e:
        conn.rollback()
        print(f"\n❌ Migration failed: {e}")
        import traceback
        traceback.print_exc()
        raise
    finally:
        conn.close()

if __name__ == '__main__':
    migrate()
