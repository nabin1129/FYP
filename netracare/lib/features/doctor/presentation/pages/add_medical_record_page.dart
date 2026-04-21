import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:netracare/config/app_theme.dart';
import 'package:netracare/services/doctor_api_service.dart';
import 'package:netracare/services/doctor_service.dart';
import 'package:netracare/models/doctor/medical_record_model.dart';

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
  bool _isUploading = false;

  // Populated after a successful file upload
  String? _selectedFileName;
  String? _uploadedFileUrl;
  int? _uploadedFileSize;
  String? _uploadedMimeType;

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
      case MedicalRecordType.testResult:
        return Icons.science_outlined;
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
      case MedicalRecordType.testResult:
        return const Color(0xFF10B981);
    }
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: [
        'pdf',
        'jpg',
        'jpeg',
        'png',
        'gif',
        'bmp',
        'tiff',
        'webp',
        'doc',
        'docx',
      ],
      withData: true,
    );

    if (result == null || result.files.isEmpty) return;
    final picked = result.files.first;
    final bytes = picked.bytes;
    if (bytes == null) return;

    setState(() => _isUploading = true);
    try {
      final meta = await DoctorApiService.uploadRecordFile(
        bytes: bytes,
        fileName: picked.name,
        mimeType: _mimeTypeFromExtension(picked.extension ?? ''),
      );
      if (!mounted) return;
      setState(() {
        _selectedFileName = meta['file_name'] as String? ?? picked.name;
        _uploadedFileUrl = meta['file_url'] as String?;
        _uploadedFileSize = meta['file_size'] as int?;
        _uploadedMimeType = meta['mime_type'] as String?;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Uploaded: $_selectedFileName'),
          backgroundColor: AppTheme.success,
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Upload failed: $e'),
          backgroundColor: AppTheme.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  String _mimeTypeFromExtension(String ext) {
    switch (ext.toLowerCase()) {
      case 'pdf':
        return 'application/pdf';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'bmp':
        return 'image/bmp';
      case 'webp':
        return 'image/webp';
      case 'tiff':
        return 'image/tiff';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      default:
        return 'application/octet-stream';
    }
  }

  Future<void> _saveRecord() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      await _doctorService.addMedicalRecordAsync(
        patientId: widget.patientId,
        recordType: widget.recordType,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        fileName: _selectedFileName,
        fileUrl: _uploadedFileUrl,
        fileSize: _uploadedFileSize,
        mimeType: _uploadedMimeType,
        category: 'general',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${widget.recordType.toString()} saved to database'),
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
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: AppTheme.fontBody,
                    ),
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
                  color: _recordColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: _recordColor.withValues(alpha: 0.2),
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
                      color: AppTheme.textLight.withValues(alpha: 0.3),
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
                      color: AppTheme.textLight.withValues(alpha: 0.3),
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
                onTap: _isUploading ? null : _pickFile,
                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppTheme.spaceLG),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                    border: Border.all(
                      color: _selectedFileName != null
                          ? AppTheme.success.withValues(alpha: 0.5)
                          : AppTheme.textLight.withValues(alpha: 0.3),
                    ),
                  ),
                  child: _isUploading
                      ? const Column(
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: AppTheme.spaceSM),
                            Text(
                              'Uploading...',
                              style: TextStyle(color: AppTheme.textSecondary),
                            ),
                          ],
                        )
                      : Column(
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
                              textAlign: TextAlign.center,
                            ),
                            if (_selectedFileName == null)
                              const Text(
                                'PDF, JPG, PNG, DOC (Max 10 MB)',
                                style: TextStyle(
                                  fontSize: AppTheme.fontSM,
                                  color: AppTheme.textLight,
                                ),
                              ),
                            if (_selectedFileName != null)
                              TextButton.icon(
                                onPressed: () => setState(() {
                                  _selectedFileName = null;
                                  _uploadedFileUrl = null;
                                  _uploadedFileSize = null;
                                  _uploadedMimeType = null;
                                }),
                                icon: const Icon(Icons.close, size: 16),
                                label: const Text('Remove'),
                                style: TextButton.styleFrom(
                                  foregroundColor: AppTheme.error,
                                  padding: EdgeInsets.zero,
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
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
      case MedicalRecordType.testResult:
        return 'Visual acuity, colour vision, blink fatigue, and related test outputs';
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
      case MedicalRecordType.testResult:
        return 'e.g., Visual Acuity Test Result';
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
      case MedicalRecordType.testResult:
        return 'Enter test metrics, interpretation, and recommendations...';
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
      labelStyle: const TextStyle(
        fontSize: AppTheme.fontSM,
        color: AppTheme.textSecondary,
      ),
    );
  }
}
