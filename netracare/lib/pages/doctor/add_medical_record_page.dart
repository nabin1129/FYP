import 'package:flutter/material.dart';
import '../../config/app_theme.dart';
import '../../services/doctor_service.dart';
import '../../models/doctor/medical_record_model.dart';

/// Add Medical Record Page
class AddMedicalRecordPage extends StatefulWidget {
  final String patientId;
  final MedicalRecordType recordType;

  const AddMedicalRecordPage({
    super.key,
    required this.patientId,
    required this.recordType,
  });

  @override
  State<AddMedicalRecordPage> createState() => _AddMedicalRecordPageState();
}

class _AddMedicalRecordPageState extends State<AddMedicalRecordPage> {
  final DoctorService _doctorService = DoctorService();
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();

  bool _isSaving = false;
  String? _selectedFileName;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  IconData get _recordIcon {
    switch (widget.recordType) {
      case MedicalRecordType.scanReport:
        return Icons.document_scanner;
      case MedicalRecordType.prescription:
        return Icons.medication;
      case MedicalRecordType.labReport:
        return Icons.science;
    }
  }

  Color get _recordColor {
    switch (widget.recordType) {
      case MedicalRecordType.scanReport:
        return AppTheme.info;
      case MedicalRecordType.prescription:
        return AppTheme.success;
      case MedicalRecordType.labReport:
        return AppTheme.warning;
    }
  }

  Future<void> _pickFile() async {
    // Simulate file picking
    setState(() {
      _selectedFileName =
          'document_${DateTime.now().millisecondsSinceEpoch}.pdf';
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('File selected successfully'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  Future<void> _saveRecord() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final record = MedicalRecord(
        id: 'record_${DateTime.now().millisecondsSinceEpoch}',
        patientId: widget.patientId,
        type: widget.recordType,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        date: DateTime.now(),
        doctorName: 'Dr. Rajesh Kumar Shrestha',
        fileName: _selectedFileName,
      );

      _doctorService.addMedicalRecord(record);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${widget.recordType.toString()} added successfully'),
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
        title: Text(
          'Add ${widget.recordType.toString()}',
          style: const TextStyle(
            color: AppTheme.textPrimary,
            fontSize: AppTheme.fontXL,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _saveRecord,
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
              // Record Type Header
              Container(
                padding: const EdgeInsets.all(AppTheme.spaceMD),
                decoration: BoxDecoration(
                  color: _recordColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: _recordColor.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(
                          AppTheme.radiusMedium,
                        ),
                      ),
                      child: Icon(_recordIcon, color: _recordColor, size: 26),
                    ),
                    const SizedBox(width: AppTheme.spaceMD),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.recordType.toString(),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: AppTheme.fontLG,
                              color: _recordColor,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _getRecordTypeDescription(),
                            style: const TextStyle(
                              fontSize: AppTheme.fontSM,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
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
                  hintText: _getTitleHint(),
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

              // Description
              const Text(
                'Description / Notes',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: AppTheme.spaceSM),
              TextFormField(
                controller: _descriptionController,
                maxLines: 5,
                decoration: InputDecoration(
                  hintText: _getDescriptionHint(),
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
                    return 'Please enter a description';
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppTheme.spaceLG),

              // File Upload
              const Text(
                'Attach File (Optional)',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: AppTheme.spaceSM),
              InkWell(
                onTap: _pickFile,
                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppTheme.spaceLG),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                    border: Border.all(
                      color: AppTheme.textLight.withOpacity(0.3),
                      style: BorderStyle.solid,
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        _selectedFileName != null
                            ? Icons.check_circle
                            : Icons.cloud_upload_outlined,
                        size: 40,
                        color: _selectedFileName != null
                            ? AppTheme.success
                            : AppTheme.textLight,
                      ),
                      const SizedBox(height: AppTheme.spaceSM),
                      Text(
                        _selectedFileName ?? 'Tap to upload file',
                        style: TextStyle(
                          color: _selectedFileName != null
                              ? AppTheme.textPrimary
                              : AppTheme.textSecondary,
                          fontWeight: _selectedFileName != null
                              ? FontWeight.w500
                              : FontWeight.normal,
                        ),
                      ),
                      if (_selectedFileName == null)
                        const Text(
                          'PDF, JPG, PNG (Max 10MB)',
                          style: TextStyle(
                            fontSize: AppTheme.fontSM,
                            color: AppTheme.textLight,
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              // Prescription-specific fields
              if (widget.recordType == MedicalRecordType.prescription)
                _buildPrescriptionFields(),

              const SizedBox(height: AppTheme.spaceLG),
            ],
          ),
        ),
      ),
    );
  }

  String _getRecordTypeDescription() {
    switch (widget.recordType) {
      case MedicalRecordType.scanReport:
        return 'OCT, Visual Field, Fundus Photography, etc.';
      case MedicalRecordType.prescription:
        return 'Eye drops, medications, corrective lenses';
      case MedicalRecordType.labReport:
        return 'Blood tests, diabetic screening, etc.';
    }
  }

  String _getTitleHint() {
    switch (widget.recordType) {
      case MedicalRecordType.scanReport:
        return 'e.g., OCT Scan - Retina';
      case MedicalRecordType.prescription:
        return 'e.g., Eye Drops Prescription';
      case MedicalRecordType.labReport:
        return 'e.g., Blood Sugar Test';
    }
  }

  String _getDescriptionHint() {
    switch (widget.recordType) {
      case MedicalRecordType.scanReport:
        return 'Enter scan findings and observations...';
      case MedicalRecordType.prescription:
        return 'Enter medication details, dosage, and duration...';
      case MedicalRecordType.labReport:
        return 'Enter test results and values...';
    }
  }

  Widget _buildPrescriptionFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: AppTheme.spaceLG),
        const Text(
          'Quick Add Medication',
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
            _buildMedicationChip('Refresh Tears'),
            _buildMedicationChip('Systane Ultra'),
            _buildMedicationChip('Timolol 0.5%'),
            _buildMedicationChip('Moxifloxacin'),
          ],
        ),
      ],
    );
  }

  Widget _buildMedicationChip(String name) {
    return ActionChip(
      avatar: const Icon(Icons.add, size: 16),
      label: Text(name),
      onPressed: () {
        final currentDesc = _descriptionController.text;
        _descriptionController.text = currentDesc.isEmpty
            ? '$name - '
            : '$currentDesc\n$name - ';
      },
      backgroundColor: AppTheme.surfaceLight,
      labelStyle: const TextStyle(fontSize: AppTheme.fontSM, color: AppTheme.textSecondary),
    );
  }
}
