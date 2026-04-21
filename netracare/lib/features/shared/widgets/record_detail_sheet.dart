import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../config/api_config.dart';
import '../../../config/app_theme.dart';

/// A reusable bottom sheet that displays the full details of a medical record.
///
/// Accepts a raw `Map<String, dynamic>` so it can be used from the patient
/// page (API response), the doctor patient-detail tab (MedicalRecord model
/// converted to map), and the admin list (API response).
///
/// Usage:
/// ```dart
/// RecordDetailSheet.show(context, record);
/// ```
class RecordDetailSheet extends StatelessWidget {
  final Map<String, dynamic> record;

  const RecordDetailSheet._({required this.record});

  // ──────────────────────────────────────────────
  // Public entry point
  // ──────────────────────────────────────────────

  static void show(BuildContext context, Map<String, dynamic> record) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => RecordDetailSheet._(record: record),
    );
  }

  // ──────────────────────────────────────────────
  // Helpers
  // ──────────────────────────────────────────────

  String get _title => record['title']?.toString() ?? 'Medical Record';

  String get _description =>
      record['description']?.toString() ?? record['content']?.toString() ?? '';

  String get _doctor =>
      record['doctorName']?.toString() ?? record['doctor']?.toString() ?? '';

  String get _date {
    final raw =
        record['date']?.toString() ?? record['created_at']?.toString() ?? '';
    final dt = DateTime.tryParse(raw);
    return dt != null ? DateFormat('MMMM dd, yyyy').format(dt) : '';
  }

  String get _recordType =>
      (record['record_type']?.toString() ??
      record['type']?.toString() ??
      'scan_report');

  String? get _fileUrl => record['file_url']?.toString();
  String? get _fileName =>
      record['file_name']?.toString() ?? record['fileName']?.toString();
  String? get _mimeType => record['mime_type']?.toString();

  bool get _hasFile => _fileUrl != null && _fileUrl!.isNotEmpty;

  bool get _isImage {
    final mime = _mimeType ?? '';
    final url = _fileUrl ?? '';
    return mime.startsWith('image/') ||
        url.endsWith('.jpg') ||
        url.endsWith('.jpeg') ||
        url.endsWith('.png') ||
        url.endsWith('.gif') ||
        url.endsWith('.webp') ||
        url.endsWith('.bmp');
  }

  String get _fullFileUrl {
    final url = _fileUrl ?? '';
    if (url.startsWith('http')) return url;
    return '${ApiConfig.baseUrl}$url';
  }

  _RecordTypeMeta get _meta => _RecordTypeMeta.fromType(_recordType);

  String get _detailLabel {
    final source = (record['source'] ?? '').toString().toLowerCase();
    final category = (record['category'] ?? '').toString().toLowerCase();
    if (source == 'doctor_consultation') {
      if (category == 'diagnosis') return 'Diagnosis';
      if (_recordType == 'prescription') return 'Prescription';
      return 'Consultation Note';
    }
    return _meta.label;
  }

  // ──────────────────────────────────────────────
  // Build
  // ──────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              _buildHandle(),
              _buildHeader(context),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                  children: [
                    if (_date.isNotEmpty) ...[
                      _buildMetaRow(Icons.calendar_today_outlined, _date),
                      const SizedBox(height: 8),
                    ],
                    if (_doctor.isNotEmpty) ...[
                      _buildMetaRow(Icons.person_outlined, 'Dr. $_doctor'),
                      const SizedBox(height: 8),
                    ],
                    const SizedBox(height: 16),
                    if (_description.isNotEmpty) _buildDescriptionSection(),
                    if (_hasFile) ...[
                      const SizedBox(height: 20),
                      _buildFileSection(context),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHandle() {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 4),
      child: Center(
        child: Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: Colors.grey.shade300,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 16, 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _meta.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(_meta.icon, color: _meta.color, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: _meta.color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Text(
                    _detailLabel,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: _meta.color,
                    ),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close, size: 20),
            color: AppTheme.textSecondary,
          ),
        ],
      ),
    );
  }

  Widget _buildMetaRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppTheme.textSecondary),
        const SizedBox(width: 8),
        Text(
          text,
          style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
        ),
      ],
    );
  }

  Widget _buildDescriptionSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Details',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.background,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.border),
          ),
          child: Text(
            _description,
            style: const TextStyle(
              fontSize: 14,
              color: AppTheme.textPrimary,
              height: 1.6,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFileSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Attachment',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 10),
        if (_isImage)
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(
              _fullFileUrl,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _buildOpenFileButton(context),
            ),
          )
        else
          _buildOpenFileButton(context),
      ],
    );
  }

  Widget _buildOpenFileButton(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _openFile(context),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(color: AppTheme.primary.withValues(alpha: 0.4)),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(_fileIcon, color: AppTheme.primary, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _fileName ?? 'Attached file',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Tap to open',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.open_in_new, color: AppTheme.primary, size: 18),
            ],
          ),
        ),
      ),
    );
  }

  IconData get _fileIcon {
    final mime = _mimeType ?? '';
    final url = _fileUrl ?? '';
    if (mime == 'application/pdf' || url.endsWith('.pdf')) {
      return Icons.picture_as_pdf;
    }
    if (mime.startsWith('image/')) return Icons.image_outlined;
    return Icons.insert_drive_file_outlined;
  }

  Future<void> _openFile(BuildContext context) async {
    final uri = Uri.tryParse(_fullFileUrl);
    if (uri == null) return;
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Unable to open file')));
      }
    }
  }
}

// ──────────────────────────────────────────────
// Internal helper: icon + color + label per record type
// ──────────────────────────────────────────────

class _RecordTypeMeta {
  final IconData icon;
  final Color color;
  final String label;

  const _RecordTypeMeta({
    required this.icon,
    required this.color,
    required this.label,
  });

  factory _RecordTypeMeta.fromType(String type) {
    switch (type.toLowerCase()) {
      case 'prescription':
        return const _RecordTypeMeta(
          icon: Icons.receipt_long,
          color: Color(0xFF10B981),
          label: 'Prescription',
        );
      case 'lab_report':
        return const _RecordTypeMeta(
          icon: Icons.biotech,
          color: Color(0xFF06B6D4),
          label: 'Lab Report',
        );
      case 'clinical_note':
        return const _RecordTypeMeta(
          icon: Icons.assignment,
          color: Color(0xFF8B5CF6),
          label: 'Clinical Note',
        );
      case 'test_result':
        return const _RecordTypeMeta(
          icon: Icons.science_outlined,
          color: Color(0xFF10B981),
          label: 'Test Result',
        );
      default:
        return const _RecordTypeMeta(
          icon: Icons.document_scanner,
          color: Color(0xFF3B82F6),
          label: 'Scan Report',
        );
    }
  }
}
