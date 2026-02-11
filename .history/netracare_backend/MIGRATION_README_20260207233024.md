# Database Migration Guide

## Quick Start

### Running the Migration

**Stop your Flask server first**, then run:

```bash
python database_migration.py
```

### Skip Confirmation Prompt

If you want to run without confirmation:

```bash
python database_migration.py --yes
# or
python database_migration.py -y
```

## What This Does

Adds new profile fields to the `user` table:
- `phone` - User phone number
- `address` - User address
- `emergency_contact` - Emergency contact number
- `medical_history` - Medical history notes
- `profile_image_url` - Profile picture URL

## Safety Features

✅ **Idempotent** - Can be run multiple times safely  
✅ **Non-destructive** - Never deletes existing data  
✅ **Smart checks** - Only adds columns that don't exist  
✅ **Database lock detection** - Warns if Flask is running  
✅ **Detailed logging** - Shows exactly what it's doing  
✅ **Backup reminder** - Prompts you to backup first  

## Workflow

1. **Stop Flask server** (`CTRL+C` in terminal)
2. **Backup database** (optional but recommended):
   ```bash
   copy db.sqlite3 db.sqlite3.backup
   ```
3. **Run migration**:
   ```bash
   python database_migration.py
   ```
4. **Restart Flask server**:
   ```bash
   python app.py
   ```

## Troubleshooting

### "Database is locked" Error
- **Cause**: Flask server is still running
- **Solution**: Stop Flask server and try again

### "Database not found" Error
- **Cause**: Script run from wrong directory
- **Solution**: Run from `netracare_backend` folder

### Migration Already Run
- **What happens**: Script detects existing columns and skips them
- **Result**: No changes made, safe to continue

## Migration Results

After running, you'll see:
- ✓ Green: Successfully added columns
- ⊘ Yellow: Skipped (already exists)
- ✗ Red: Errors

## Verification

To verify the migration worked:

```bash
python check_db_direct.py
```

Or manually check:
```bash
sqlite3 db.sqlite3
sqlite> PRAGMA table_info(user);
sqlite> .quit
```

You should see the 5 new columns listed.

## Notes

- **Safe to re-run**: Won't duplicate columns or break data
- **No app dependencies**: Works directly with SQLite
- **Production ready**: Use in production with confidence
- **Old migration files**: Can be safely ignored (`add_profile_fields_migration.py`, `migrate_user_table.py`)
