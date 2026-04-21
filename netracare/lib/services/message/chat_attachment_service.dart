import 'package:netracare/models/consultation/attachment_model.dart';
import 'package:flutter/foundation.dart';
import 'package:netracare/services/doctor_api_service.dart';
import 'package:netracare/services/api_service.dart';

/// Service for managing chat attachments and sharing test results, medical records, and clinical notes
class ChatAttachmentService {
  static final ChatAttachmentService _instance =
      ChatAttachmentService._internal();

  factory ChatAttachmentService() {
    return _instance;
  }

  ChatAttachmentService._internal();

  /// Get test results that can be shared in chat
  Future<List<Attachment>> getShareableTestResults(String patientId) async {
    try {
      final testResults = await DoctorApiService.getPatientTestResults(
        patientId,
      );

      return testResults.map((test) {
        final testType = test['test_type'] as String? ?? 'Unknown Test';
        final testDate =
            DateTime.tryParse(test['created_at'] as String? ?? '') ??
            DateTime.now();
        final description = _buildTestDescription(test);

        return Attachment.testResult(
          id: '${test['id']}',
          testTitle: testType,
          testDate: testDate,
          testDescription: description,
          fileName:
              '${testType.replaceAll(' ', '_')}_${testDate.year}${testDate.month.toString().padLeft(2, '0')}.pdf',
          fileSizeBytes: 102400, // Placeholder
        );
      }).toList();
    } catch (e) {
      debugPrint('Error fetching test results: $e');
      return [];
    }
  }

  /// Get medical records that can be shared in chat
  Future<List<Attachment>> getShareableMedicalRecords(String patientId) async {
    try {
      final recordsMap = await ApiService.getMedicalRecords();
      final attachments = <Attachment>[];

      // Process scan reports
      final scanReports = recordsMap['scanReports'] as List<dynamic>? ?? [];
      for (final record in scanReports) {
        final recordMap = record as Map<String, dynamic>? ?? {};
        attachments.add(
          Attachment.medicalRecord(
            id: '${recordMap['id']}',
            recordTitle: recordMap['title'] as String? ?? 'Scan Report',
            recordDate:
                DateTime.tryParse(recordMap['date'] as String? ?? '') ??
                DateTime.now(),
            recordDescription: recordMap['description'] as String? ?? '',
            fileName: recordMap['fileName'] as String? ?? 'scan_report.pdf',
            fileSizeBytes: recordMap['fileSizeBytes'] as int?,
          ),
        );
      }

      // Process prescriptions
      final prescriptions = recordsMap['prescriptions'] as List<dynamic>? ?? [];
      for (final record in prescriptions) {
        final recordMap = record as Map<String, dynamic>? ?? {};
        attachments.add(
          Attachment.medicalRecord(
            id: '${recordMap['id']}',
            recordTitle: recordMap['title'] as String? ?? 'Prescription',
            recordDate:
                DateTime.tryParse(recordMap['date'] as String? ?? '') ??
                DateTime.now(),
            recordDescription: recordMap['description'] as String? ?? '',
            fileName: recordMap['fileName'] as String? ?? 'prescription.pdf',
            fileSizeBytes: recordMap['fileSizeBytes'] as int?,
          ),
        );
      }

      // Process lab reports
      final labReports = recordsMap['labReports'] as List<dynamic>? ?? [];
      for (final record in labReports) {
        final recordMap = record as Map<String, dynamic>? ?? {};
        attachments.add(
          Attachment.medicalRecord(
            id: '${recordMap['id']}',
            recordTitle: recordMap['title'] as String? ?? 'Lab Report',
            recordDate:
                DateTime.tryParse(recordMap['date'] as String? ?? '') ??
                DateTime.now(),
            recordDescription: recordMap['description'] as String? ?? '',
            fileName: recordMap['fileName'] as String? ?? 'lab_report.pdf',
            fileSizeBytes: recordMap['fileSizeBytes'] as int?,
          ),
        );
      }

      return attachments;
    } catch (e) {
      debugPrint('Error fetching medical records: $e');
      return [];
    }
  }

  /// Get clinical notes that can be shared in chat
  Future<List<Attachment>> getShareableClinicalNotes(String patientId) async {
    try {
      final notes = await DoctorApiService.getPatientClinicalNotes(patientId);

      return notes.map((note) {
        final noteTitle = note['title'] as String? ?? 'Clinical Note';
        final noteDate =
            DateTime.tryParse(note['created_at'] as String? ?? '') ??
            DateTime.now();
        final description = note['content'] as String? ?? '';

        return Attachment.clinicalNote(
          id: '${note['id']}',
          noteTitle: noteTitle,
          noteDate: noteDate,
          noteDescription: description,
          fileName:
              '${noteTitle.replaceAll(' ', '_')}_${noteDate.year}${noteDate.month.toString().padLeft(2, '0')}.pdf',
          fileSizeBytes: (description.length * 2), // Rough estimate
        );
      }).toList();
    } catch (e) {
      debugPrint('Error fetching clinical notes: $e');
      return [];
    }
  }

  /// Build description from test data
  String _buildTestDescription(Map<String, dynamic> test) {
    final testType = test['test_type'] as String? ?? '';
    final status = test['status'] as String? ?? 'Completed';

    switch (testType.toLowerCase()) {
      case 'visual acuity':
        final leftEye = test['left_eye_score'] as String? ?? 'N/A';
        final rightEye = test['right_eye_score'] as String? ?? 'N/A';
        return 'Visual Acuity Test - Left: $leftEye, Right: $rightEye - Status: $status';

      case 'blink fatigue':
        final fatigueLevel = test['fatigue_level'] as String? ?? 'N/A';
        return 'Blink Fatigue Test - Fatigue Level: $fatigueLevel - Status: $status';

      case 'colour vision':
        final accuracy = test['accuracy'] as String? ?? 'N/A';
        return 'Colour Vision Test - Accuracy: $accuracy - Status: $status';

      case 'pupil reflex':
        final reflex = test['reflex_status'] as String? ?? 'Normal';
        return 'Pupil Reflex Test - Status: $reflex - Completed: $status';

      default:
        return '$testType - Status: $status';
    }
  }

  /// Create an attachment from test result for sharing
  Attachment createTestResultAttachment({
    required String testId,
    required String testType,
    required DateTime testDate,
    required Map<String, dynamic> testData,
  }) {
    final description = _buildTestDescription({
      'test_type': testType,
      ...testData,
    });

    return Attachment.testResult(
      id: testId,
      testTitle: testType,
      testDate: testDate,
      testDescription: description,
      fileName:
          '${testType.replaceAll(' ', '_')}_${testDate.year}${testDate.month.toString().padLeft(2, '0')}.pdf',
      fileSizeBytes: 102400,
    );
  }

  /// Create an attachment from medical record for sharing
  Attachment createMedicalRecordAttachment({
    required String recordId,
    required String recordTitle,
    required DateTime recordDate,
    required String description,
    String? fileName,
  }) {
    return Attachment.medicalRecord(
      id: recordId,
      recordTitle: recordTitle,
      recordDate: recordDate,
      recordDescription: description,
      fileName: fileName ?? '$recordTitle.pdf',
    );
  }

  /// Create an attachment from clinical note for sharing
  Attachment createClinicalNoteAttachment({
    required String noteId,
    required String noteTitle,
    required DateTime noteDate,
    required String noteDescription,
  }) {
    return Attachment.clinicalNote(
      id: noteId,
      noteTitle: noteTitle,
      noteDate: noteDate,
      noteDescription: noteDescription,
      fileName:
          '${noteTitle.replaceAll(' ', '_')}_${noteDate.year}${noteDate.month.toString().padLeft(2, '0')}.txt',
    );
  }
}
