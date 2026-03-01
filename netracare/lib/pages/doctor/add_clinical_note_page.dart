import 'package:flutter/material.dart';
import '../../config/app_theme.dart';
import '../../services/doctor_service.dart';
import '../../models/doctor/medical_record_model.dart';

/// Add Clinical Note Page
class AddClinicalNotePage extends StatefulWidget {
  final String patientId;

  const AddClinicalNotePage({super.key, required this.patientId});

  @override
  State<AddClinicalNotePage> createState() => _AddClinicalNotePageState();
}

class _AddClinicalNotePageState extends State<AddClinicalNotePage> {
  final DoctorService _doctorService = DoctorService();
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();

  NoteCategory _selectedCategory = NoteCategory.general;
  bool _isSaving = false;

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _saveNote() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final note = ClinicalNote(
        id: 'note_${DateTime.now().millisecondsSinceEpoch}',
        patientId: widget.patientId,
        doctorId: 'doc_1',
        doctorName: 'Dr. Rajesh Kumar Shrestha',
        title: _titleController.text.trim(),
        content: _contentController.text.trim(),
        createdAt: DateTime.now(),
        category: _selectedCategory,
      );

      _doctorService.addClinicalNote(note);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Clinical note added successfully'),
            backgroundColor: AppTheme.success,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: AppTheme.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Add Clinical Note',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: AppTheme.fontXL,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _saveNote,
            child: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text(
                    'Save',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: AppTheme.fontBody),
                  ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppTheme.spaceMD),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Category Selection
              const Text(
                'Category',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: AppTheme.spaceSM),
              Wrap(
                spacing: AppTheme.spaceSM,
                runSpacing: AppTheme.spaceSM,
                children: NoteCategory.values.map((category) {
                  final isSelected = _selectedCategory == category;
                  return ChoiceChip(
                    label: Text(category.toString()),
                    selected: isSelected,
                    onSelected: (_) {
                      setState(() => _selectedCategory = category);
                    },
                    selectedColor: AppTheme.primary.withOpacity(0.2),
                    labelStyle: TextStyle(
                      color: isSelected
                          ? AppTheme.primary
                          : AppTheme.textSecondary,
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: AppTheme.spaceLG),

              // Title
              const Text(
                'Title',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: AppTheme.spaceSM),
              TextFormField(
                controller: _titleController,
                decoration: InputDecoration(
                  hintText: 'Enter note title',
                  filled: true,
                  fillColor: AppTheme.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                    borderSide: BorderSide(
                      color: AppTheme.textLight.withOpacity(0.3),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                    borderSide: const BorderSide(color: AppTheme.primary),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a title';
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppTheme.spaceLG),

              // Content
              const Text(
                'Note Content',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: AppTheme.spaceSM),
              TextFormField(
                controller: _contentController,
                maxLines: 8,
                decoration: InputDecoration(
                  hintText:
                      'Enter clinical observations, recommendations, etc.',
                  filled: true,
                  fillColor: AppTheme.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                    borderSide: BorderSide(
                      color: AppTheme.textLight.withOpacity(0.3),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                    borderSide: const BorderSide(color: AppTheme.primary),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter note content';
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppTheme.spaceLG),

              // Quick Templates
              const Text(
                'Quick Templates',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: AppTheme.spaceSM),
              Wrap(
                spacing: AppTheme.spaceSM,
                runSpacing: AppTheme.spaceSM,
                children: [
                  _buildTemplateChip('Follow-up needed'),
                  _buildTemplateChip('Continue current treatment'),
                  _buildTemplateChip('Refer to specialist'),
                  _buildTemplateChip('Schedule tests'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTemplateChip(String text) {
    return ActionChip(
      label: Text(text),
      onPressed: () {
        final currentContent = _contentController.text;
        _contentController.text = currentContent.isEmpty
            ? text
            : '$currentContent\n$text';
      },
      backgroundColor: AppTheme.surfaceLight,
      labelStyle: const TextStyle(fontSize: AppTheme.fontSM, color: AppTheme.textSecondary),
    );
  }
}
