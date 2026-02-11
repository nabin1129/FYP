"""
Comprehensive Database Migration Script
========================================

This script safely migrates the NetraCare database schema by adding new profile fields
to the User table. It can be run multiple times safely (idempotent).

Features:
- Direct SQLite access (no Flask app dependencies)
- Checks existing schema before making changes
- Won't break existing code or data
- Can be run while app is stopped
- Provides detailed logging

Usage:
    python database_migration.py

New fields added:
- phone (VARCHAR 20)
- address (TEXT)
- emergency_contact (VARCHAR 20)
- medical_history (TEXT)
- profile_image_url (VARCHAR 500)

Author: NetraCare Development Team
Date: February 2026
"""

import sqlite3
import os
import sys
from datetime import datetime


class DatabaseMigration:
    """Handles database schema migrations safely"""
    
    def __init__(self, db_path='db.sqlite3'):
        self.db_path = os.path.join(os.path.dirname(__file__), db_path)
        self.migration_log = []
        
    def log(self, message, level='INFO'):
        """Log migration messages"""
        timestamp = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
        log_entry = f"[{timestamp}] [{level}] {message}"
        self.migration_log.append(log_entry)
        
        # Color coding for terminal
        colors = {
            'INFO': '\033[94m',    # Blue
            'SUCCESS': '\033[92m', # Green
            'WARNING': '\033[93m', # Yellow
            'ERROR': '\033[91m',   # Red
        }
        reset = '\033[0m'
        
        print(f"{colors.get(level, '')}{log_entry}{reset}")
    
    def check_database_exists(self):
        """Verify database file exists"""
        if not os.path.exists(self.db_path):
            self.log(f"Database not found at: {self.db_path}", 'ERROR')
            return False
        self.log(f"Database found: {self.db_path}", 'SUCCESS')
        return True
    
    def get_table_columns(self, cursor, table_name):
        """Get list of existing columns in a table"""
        cursor.execute(f"PRAGMA table_info({table_name})")
        columns = {row[1]: row[2] for row in cursor.fetchall()}
        return columns
    
    def backup_recommendation(self):
        """Provide backup recommendation"""
        backup_path = self.db_path + f'.backup_{datetime.now().strftime("%Y%m%d_%H%M%S")}'
        self.log("=" * 70, 'INFO')
        self.log("RECOMMENDATION: Create a backup before migration", 'WARNING')
        self.log(f"Suggested command:", 'INFO')
        self.log(f"  copy {self.db_path} {backup_path}", 'INFO')
        self.log("=" * 70, 'INFO')
        
        response = input("\nDo you want to continue with migration? (yes/no): ").strip().lower()
        if response not in ['yes', 'y']:
            self.log("Migration cancelled by user", 'INFO')
            return False
        return True
    
    def migrate_user_table(self):
        """Add new profile fields to User table"""
        
        # Define new columns to add
        new_columns = {
            'phone': 'VARCHAR(20)',
            'address': 'TEXT',
            'emergency_contact': 'VARCHAR(20)',
            'medical_history': 'TEXT',
            'profile_image_url': 'VARCHAR(500)'
        }
        
        try:
            # Connect to database
            self.log("Connecting to database...", 'INFO')
            conn = sqlite3.connect(self.db_path)
            cursor = conn.cursor()
            
            # Get existing columns
            existing_columns = self.get_table_columns(cursor, 'user')
            self.log(f"Existing columns in 'user' table: {len(existing_columns)}", 'INFO')
            
            # Track changes
            added = []
            skipped = []
            
            # Add new columns
            for column_name, column_type in new_columns.items():
                if column_name in existing_columns:
                    skipped.append(column_name)
                    self.log(f"Column '{column_name}' already exists - skipping", 'WARNING')
                else:
                    try:
                        sql = f"ALTER TABLE user ADD COLUMN {column_name} {column_type}"
                        cursor.execute(sql)
                        conn.commit()
                        added.append(column_name)
                        self.log(f"✓ Added column: {column_name} ({column_type})", 'SUCCESS')
                    except sqlite3.OperationalError as e:
                        self.log(f"Failed to add column '{column_name}': {e}", 'ERROR')
                        conn.rollback()
            
            # Verify changes
            updated_columns = self.get_table_columns(cursor, 'user')
            
            # Close connection
            conn.close()
            self.log("Database connection closed", 'INFO')
            
            # Summary
            self.print_summary(added, skipped, updated_columns)
            
            return len(added) > 0 or len(skipped) > 0
            
        except sqlite3.OperationalError as e:
            if "database is locked" in str(e):
                self.log("Database is locked - Flask app may be running", 'ERROR')
                self.log("Please stop the Flask server and try again", 'ERROR')
            else:
                self.log(f"Database error: {e}", 'ERROR')
            return False
        except Exception as e:
            self.log(f"Unexpected error: {e}", 'ERROR')
            return False
    
    def print_summary(self, added, skipped, final_columns):
        """Print migration summary"""
        print("\n" + "=" * 70)
        self.log("MIGRATION SUMMARY", 'INFO')
        print("=" * 70)
        
        if added:
            self.log(f"✓ Successfully added {len(added)} new column(s):", 'SUCCESS')
            for col in added:
                print(f"  • {col}")
        
        if skipped:
            self.log(f"⊘ Skipped {len(skipped)} existing column(s):", 'WARNING')
            for col in skipped:
                print(f"  • {col}")
        
        if not added and not skipped:
            self.log("No changes were needed", 'INFO')
        
        print("\n" + "-" * 70)
        self.log(f"Final user table structure: {len(final_columns)} columns", 'INFO')
        for col_name, col_type in final_columns.items():
            print(f"  • {col_name:<25} {col_type}")
        
        print("=" * 70)
        
        if added:
            self.log("✓ Migration completed successfully!", 'SUCCESS')
            self.log("You can now restart your Flask server.", 'INFO')
        else:
            self.log("No migration was needed. Schema is up to date.", 'INFO')
        
        print("=" * 70 + "\n")
    
    def run(self, skip_confirmation=False):
        """Execute the migration"""
        print("\n" + "=" * 70)
        print("NetraCare Database Migration Tool".center(70))
        print("=" * 70 + "\n")
        
        # Check database exists
        if not self.check_database_exists():
            return False
        
        # Backup recommendation
        if not skip_confirmation:
            if not self.backup_recommendation():
                return False
        
        print()
        self.log("Starting migration process...", 'INFO')
        print()
        
        # Run migration
        result = self.migrate_user_table()
        
        return result


def main():
    """Main entry point"""
    # Parse command line arguments
    skip_confirmation = '--yes' in sys.argv or '-y' in sys.argv
    
    # Create migration instance
    migration = DatabaseMigration()
    
    # Run migration
    success = migration.run(skip_confirmation=skip_confirmation)
    
    # Exit with appropriate code
    sys.exit(0 if success else 1)


if __name__ == "__main__":
    main()
