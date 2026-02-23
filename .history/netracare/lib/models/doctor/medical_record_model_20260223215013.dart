/// Medical Record Model for Doctor Dashboard
/// Represents medical records including Scan Reports, Prescriptions, and Lab Reports

enum MedicalRecordType {
  scanReport,
  prescription,
  labReport;

  static MedicalRecordType fromString(String type) {
    switch (type.toLowerCase()) {
      case 'scan_report':
      case 'scanreport':
        return MedicalRecordType.scanReport;
      case 'prescription':
        return MedicalRecordType.prescription;
      case 'lab_report':
      case 'labreport':
        return MedicalRecordType.labReport;
      default:
        return MedicalRecordType.scanReport;
    }
  }

  @override
  String toString() {
    switch (this) {
      case MedicalRecordType.scanReport:
        return 'Scan Report';
      case MedicalRecordType.prescription:
        return 'Prescription';
      case MedicalRecordType.labReport:
        return 'Lab Report';
    }
  }

  String get key {
    switch (this) {
      case MedicalRecordType.scanReport:
        return 'scan_report';
      case MedicalRecordType.prescription:
        return 'prescription';
      case MedicalRecordType.labReport:
        return 'lab_report';
    }
  }
}

class MedicalRecord {
  final String id;
  final String patientId;
  final MedicalRecordType type;
  final String title;
  final String description;
  final DateTime date;
  final String? doctorName;
  final String? fileUrl;
  final String? fileName;
  final Map<String, dynamic>? metadata;

  MedicalRecord({
    required this.id,
    required this.patientId,
    required this.type,
    required this.title,
    required this.description,
    required this.date,
    this.doctorName,
    this.fileUrl,
    this.fileName,
    this.metadata,
  });

  factory MedicalRecord.fromJson(Map<String, dynamic> json) {
    return MedicalRecord(
      id: json['id'] as String,
      patientId: json['patientId'] as String,
      type: MedicalRecordType.fromString(json['type'] as String),
      title: json['title'] as String,
      description: json['description'] as String,
      date: DateTime.parse(json['date'] as String),
      doctorName: json['doctorName'] as String?,
      fileUrl: json['fileUrl'] as String?,
      fileName: json['fileName'] as String?,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'patientId': patientId,
      'type': type.key,
      'title': title,
      'description': description,
      'date': date.toIso8601String(),
      'doctorName': doctorName,
      'fileUrl': fileUrl,
      'fileName': fileName,
      'metadata': metadata,
    };
  }

  String get formattedDate {
    return '${date.day}/${date.month}/${date.year}';
  }

  // Mock medical records
  static List<MedicalRecord> getMockRecords(String patientId) {
    return [
      MedicalRecord(
        id: '1',
        patientId: patientId,
        type: MedicalRecordType.scanReport,
        title: 'OCT Scan - Retina',
        description:
            'Optical coherence tomography scan of retina. Normal findings with no signs of macular degeneration.',
        date: DateTime.now().subtract(const Duration(days: 30)),
        doctorName: 'Dr. Rajesh Kumar Shrestha',
        fileName: 'oct_scan_retina.pdf',
      ),
      MedicalRecord(
        id: '2',
        patientId: patientId,
        type: MedicalRecordType.prescription,
        title: 'Eye Drops Prescription',
        description:
            'Lubricating eye drops for dry eyes. Use 3 times daily for 2 weeks.',
        date: DateTime.now().subtract(const Duration(days: 15)),
        doctorName: 'Dr. Rajesh Kumar Shrestha',
        metadata: {
          'medications': [
            {
              'name': 'Refresh Tears',
              'dosage': '3 times daily',
              'duration': '2 weeks',
            },
          ],
        },
      ),
      MedicalRecord(
        id: '3',
        patientId: patientId,
        type: MedicalRecordType.labReport,
        title: 'Blood Sugar Test',
        description:
            'Fasting blood sugar test for diabetic retinopathy screening. Results within normal range.',
        date: DateTime.now().subtract(const Duration(days: 45)),
        doctorName: 'Dr. Anita Gurung',
        fileName: 'blood_sugar_report.pdf',
        metadata: {
          'values': {'fasting': '95 mg/dL', 'postprandial': '120 mg/dL'},
        },
      ),
      MedicalRecord(
        id: '4',
        patientId: patientId,
        type: MedicalRecordType.scanReport,
        title: 'Visual Field Test',
        description:
            'Automated perimetry test. Mild peripheral vision defects noted in left eye.',
        date: DateTime.now().subtract(const Duration(days: 60)),
        doctorName: 'Dr. Srijana Poudel',
        fileName: 'visual_field_test.pdf',
      ),
    ];
  }
}

/// Clinical Note Model
class ClinicalNote {
  final String id;
  final String patientId;
  final String doctorId;
  final String doctorName;
  final String title;
  final String content;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final NoteCategory category;
  final List<String>? tags;

  ClinicalNote({
    required this.id,
    required this.patientId,
    required this.doctorId,
    required this.doctorName,
    required this.title,
    required this.content,
    required this.createdAt,
    this.updatedAt,
    required this.category,
    this.tags,
  });

  factory ClinicalNote.fromJson(Map<String, dynamic> json) {
    return ClinicalNote(
      id: json['id'] as String,
      patientId: json['patientId'] as String,
      doctorId: json['doctorId'] as String,
      doctorName: json['doctorName'] as String,
      title: json['title'] as String,
      content: json['content'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : null,
      category: NoteCategory.fromString(json['category'] as String),
      tags: (json['tags'] as List<dynamic>?)?.cast<String>(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'patientId': patientId,
      'doctorId': doctorId,
      'doctorName': doctorName,
      'title': title,
      'content': content,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'category': category.key,
      'tags': tags,
    };
  }

  String get formattedDate {
    return '${createdAt.day}/${createdAt.month}/${createdAt.year}';
  }

  // Mock clinical notes
  static List<ClinicalNote> getMockNotes(String patientId) {
    return [
      ClinicalNote(
        id: '1',
        patientId: patientId,
        doctorId: 'doc_1',
        doctorName: 'Dr. Rajesh Kumar Shrestha',
        title: 'Follow-up Examination',
        content:
            'Patient reports improvement in eye fatigue after following the 20-20-20 rule. Visual acuity stable at 6/6 for both eyes. Continue current management.',
        createdAt: DateTime.now().subtract(const Duration(days: 7)),
        category: NoteCategory.followUp,
        tags: ['fatigue', 'visual-acuity', 'improvement'],
      ),
      ClinicalNote(
        id: '2',
        patientId: patientId,
        doctorId: 'doc_1',
        doctorName: 'Dr. Rajesh Kumar Shrestha',
        title: 'Initial Assessment',
        content:
            'New patient presenting with complaints of eye strain and occasional blurred vision. Screen time: 8+ hours daily. Recommended comprehensive eye examination.',
        createdAt: DateTime.now().subtract(const Duration(days: 30)),
        category: NoteCategory.assessment,
        tags: ['new-patient', 'eye-strain', 'screen-time'],
      ),
      ClinicalNote(
        id: '3',
        patientId: patientId,
        doctorId: 'doc_2',
        doctorName: 'Dr. Anita Gurung',
        title: 'Treatment Plan Update',
        content:
            'Based on recent test results, prescribing lubricating eye drops for dry eye syndrome. Review in 2 weeks. Patient advised to reduce screen brightness and take regular breaks.',
        createdAt: DateTime.now().subtract(const Duration(days: 14)),
        category: NoteCategory.treatment,
        tags: ['dry-eye', 'prescription', 'lifestyle'],
      ),
    ];
  }
}

/// Note category enum
enum NoteCategory {
  assessment,
  diagnosis,
  treatment,
  followUp,
  observation,
  general;

  static NoteCategory fromString(String category) {
    switch (category.toLowerCase()) {
      case 'assessment':
        return NoteCategory.assessment;
      case 'diagnosis':
        return NoteCategory.diagnosis;
      case 'treatment':
        return NoteCategory.treatment;
      case 'follow_up':
      case 'followup':
        return NoteCategory.followUp;
      case 'observation':
        return NoteCategory.observation;
      case 'general':
        return NoteCategory.general;
      default:
        return NoteCategory.general;
    }
  }

  @override
  String toString() {
    switch (this) {
      case NoteCategory.assessment:
        return 'Assessment';
      case NoteCategory.diagnosis:
        return 'Diagnosis';
      case NoteCategory.treatment:
        return 'Treatment';
      case NoteCategory.followUp:
        return 'Follow-up';
      case NoteCategory.observation:
        return 'Observation';
      case NoteCategory.general:
        return 'General';
    }
  }

  String get key {
    switch (this) {
      case NoteCategory.assessment:
        return 'assessment';
      case NoteCategory.diagnosis:
        return 'diagnosis';
      case NoteCategory.treatment:
        return 'treatment';
      case NoteCategory.followUp:
        return 'follow_up';
      case NoteCategory.observation:
        return 'observation';
      case NoteCategory.general:
        return 'general';
    }
  }
}
