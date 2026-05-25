#!/usr/bin/env python3
"""Cleanup script to remove unwanted files."""
import os

files_to_delete = [
    "d:\\3rd_Year\\FYP\\netracare_backend\\features\\blink\\fatigue_model.py",
    "d:\\3rd_Year\\FYP\\netracare_backend\\scripts\\send_test_frame.py",
    "d:\\3rd_Year\\FYP\\netracare_backend\\scripts\\test_predict.py",
    "d:\\3rd_Year\\FYP\\netracare_backend\\scripts\\verify_loader.py",
]

for fpath in files_to_delete:
    try:
        if os.path.exists(fpath):
            os.remove(fpath)
            print(f"Deleted: {fpath}")
        else:
            print(f"Not found: {fpath}")
    except Exception as e:
        print(f"Error deleting {fpath}: {e}")

print("Cleanup complete.")
