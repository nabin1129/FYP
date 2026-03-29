import 'package:flutter/material.dart';
import '../../config/app_theme.dart';
import '../../services/doctor_service.dart';
import '../../models/doctor/patient_model.dart';
import '../../models/doctor/medical_record_model.dart';
import 'add_clinical_note_page.dart';
import 'add_medical_record_page.dart';

/// Patient Detail Page - View patient info, test results, records, and notes
class PatientDetailPage extends StatefulWidget {
  final String patientId;

  const PatientDetailPage({super.key, required this.patientId});

  @override
  State<PatientDetailPage> createState() => _PatientDetailPageState();
}

class _PatientDetailPageState extends State<PatientDetailPage>
    with SingleTickerProviderStateMixin {
  final DoctorService _doctorService = DoctorService();
  late TabController _tabController;

  Patient? _patient;
  List<MedicalRecord> _medicalRecords = [];
  List<ClinicalNote> _clinicalNotes = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _loadData() {
    setState(() {
      _patient = _doctorService.getPatientById(widget.patientId);
      _medicalRecords = _doctorService.getMedicalRecords(widget.patientId);
      _clinicalNotes = _doctorService.getClinicalNotes(widget.patientId);
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(
          backgroundColor: AppTheme.surface,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: AppTheme.textPrimary),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_patient == null) {
      return Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(
          backgroundColor: AppTheme.surface,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: AppTheme.textPrimary),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: const Center(child: Text('Patient not found')),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [_buildSliverAppBar()];
        },
        body: Column(
          children: [
            _buildTabBar(),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildTestResultsTab(),
                  _buildMedicalRecordsTab(),
                  _buildClinicalNotesTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 220,
      pinned: true,
      backgroundColor: AppTheme.surface,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: AppTheme.textPrimary),
        onPressed: () => Navigator.pop(context),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(gradient: AppTheme.primaryGradient),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 50, 20, 20),
              child: Column(
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 40,
                        backgroundColor: Colors.white.withValues(alpha: 0.2),
                        child: Text(
                          _patient!.initials,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: AppTheme.fontHeading,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppTheme.spaceMD),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _patient!.name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: AppTheme.fontTitle,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${_patient!.age ?? 'N/A'} years â€¢ ${_patient!.sex ?? 'N/A'}',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.9),
                                fontSize: AppTheme.fontBody,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _patient!.email,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.8),
                                fontSize: AppTheme.fontSM,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppTheme.spaceMD),
                  Row(
                    children: [
                      _buildPatientStat(
                        'Health Score',
                        '${_patient!.healthScore}',
                        _patient!.trend == 'up'
                            ? Icons.trending_up
                            : _patient!.trend == 'down'
                            ? Icons.trending_down
                            : Icons.trending_flat,
                      ),
                      const SizedBox(width: AppTheme.spaceMD),
                      _buildPatientStat('Status', _patient!.status.label, null),
                      const SizedBox(width: AppTheme.spaceMD),
                      _buildPatientStat(
                        'Last Test',
                        _patient!.lastTestAgo,
                        null,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPatientStat(String label, String value, IconData? icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spaceSM,
          vertical: AppTheme.spaceSM,
        ),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: AppTheme.fontLG,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (icon != null) ...[
                  const SizedBox(width: 4),
                  Icon(icon, color: Colors.white, size: 16),
                ],
              ],
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.8),
                fontSize: AppTheme.fontXS,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      color: AppTheme.surface,
      child: TabBar(
        controller: _tabController,
        labelColor: AppTheme.primary,
        unselectedLabelColor: AppTheme.textSecondary,
        indicatorColor: AppTheme.primary,
        indicatorWeight: 2,
        labelStyle: const TextStyle(fontSize: AppTheme.fontSM, fontWeight: FontWeight.w600),
        tabs: const [
          Tab(text: 'Test Results'),
          Tab(text: 'Medical Records'),
          Tab(text: 'Clinical Notes'),
        ],
      ),
    );
  }

  // ============================================
  // TEST RESULTS TAB
  // ============================================
  Widget _buildTestResultsTab() {
    final testSummary = _patient!.testSummary;
    if (testSummary == null) {
      return _buildEmptyState('No test results available', Icons.assignment);
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppTheme.spaceMD),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTestProgressCard(testSummary),
          const SizedBox(height: AppTheme.spaceMD),
          const Text(
            'Test Results',
            style: TextStyle(
              fontSize: AppTheme.fontLG,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: AppTheme.spaceSM),
          _buildTestResultCard(
            'Visual Acuity',
            testSummary.visualAcuityScore ?? 'Not taken',
            Icons.visibility,
            testSummary.visualAcuityScore != null,
          ),
          _buildTestResultCard(
            'Blink Rate',
            testSummary.blinkRate != null
                ? '${testSummary.blinkRate} bpm'
                : 'Not taken',
            Icons.remove_red_eye,
            testSummary.blinkRate != null,
          ),
          _buildTestResultCard(
            'Fatigue Level',
            testSummary.fatigueLevel ?? 'Not taken',
            Icons.bedtime,
            testSummary.fatigueLevel != null,
          ),
          _buildTestResultCard(
            'Colour Vision',
            testSummary.colourVisionStatus ?? 'Not taken',
            Icons.color_lens,
            testSummary.colourVisionStatus != null,
          ),
          _buildTestResultCard(
            'Pupil Reflex',
            testSummary.pupilReflexStatus ?? 'Not taken',
            Icons.flash_on,
            testSummary.pupilReflexStatus != null,
          ),
        ],
      ),
    );
  }

  Widget _buildTestProgressCard(PatientTestSummary summary) {
    final progress = summary.testsCompleted / summary.totalTests;

    return Container(
      padding: const EdgeInsets.all(AppTheme.spaceMD),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Test Progress',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              Text(
                '${summary.testsCompleted}/${summary.totalTests} completed',
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: AppTheme.fontSM,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spaceSM),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: AppTheme.testIconBackground,
              valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primary),
              minHeight: 8,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTestResultCard(
    String testName,
    String result,
    IconData icon,
    bool isCompleted,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.spaceSM),
      padding: const EdgeInsets.all(AppTheme.spaceMD),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: isCompleted
                  ? AppTheme.testIconBackground
                  : AppTheme.textLight.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
            ),
            child: Icon(
              icon,
              color: isCompleted ? AppTheme.testIconColor : AppTheme.textLight,
              size: 22,
            ),
          ),
          const SizedBox(width: AppTheme.spaceMD),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  testName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                Text(
                  result,
                  style: TextStyle(
                    fontSize: AppTheme.fontSM,
                    color: isCompleted
                        ? AppTheme.textSecondary
                        : AppTheme.textLight,
                  ),
                ),
              ],
            ),
          ),
          if (isCompleted)
            const Icon(Icons.check_circle, color: AppTheme.success, size: 20),
        ],
      ),
    );
  }

  // ============================================
  // MEDICAL RECORDS TAB
  // ============================================
  Widget _buildMedicalRecordsTab() {
    return Column(
      children: [
        _buildRecordTypeSelector(),
        Expanded(
          child: _medicalRecords.isEmpty
              ? _buildEmptyState('No medical records', Icons.folder_open)
              : _buildMedicalRecordsList(),
        ),
      ],
    );
  }

  Widget _buildRecordTypeSelector() {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spaceMD),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () =>
                  _navigateToAddRecord(MedicalRecordType.scanReport),
              icon: const Icon(Icons.document_scanner, size: 18),
              label: const Text('Scan Report'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.testIconBackground,
                foregroundColor: AppTheme.primary,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          const SizedBox(width: AppTheme.spaceSM),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () =>
                  _navigateToAddRecord(MedicalRecordType.prescription),
              icon: const Icon(Icons.medication, size: 18),
              label: const Text('Prescription'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.testIconBackground,
                foregroundColor: AppTheme.primary,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          const SizedBox(width: AppTheme.spaceSM),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () =>
                  _navigateToAddRecord(MedicalRecordType.labReport),
              icon: const Icon(Icons.science, size: 18),
              label: const Text('Lab Report'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.testIconBackground,
                foregroundColor: AppTheme.primary,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _navigateToAddRecord(MedicalRecordType type) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            AddMedicalRecordPage(patientId: widget.patientId, recordType: type),
      ),
    ).then((_) => _loadData());
  }

  Widget _buildMedicalRecordsList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.spaceMD),
      itemCount: _medicalRecords.length,
      itemBuilder: (context, index) {
        return _buildMedicalRecordCard(_medicalRecords[index]);
      },
    );
  }

  Widget _buildMedicalRecordCard(MedicalRecord record) {
    IconData icon;
    Color iconColor;

    switch (record.type) {
      case MedicalRecordType.scanReport:
        icon = Icons.document_scanner;
        iconColor = AppTheme.info;
        break;
      case MedicalRecordType.prescription:
        icon = Icons.medication;
        iconColor = AppTheme.success;
        break;
      case MedicalRecordType.labReport:
        icon = Icons.science;
        iconColor = AppTheme.warning;
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.spaceSM),
      padding: const EdgeInsets.all(AppTheme.spaceMD),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: AppTheme.spaceMD),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  record.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  record.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: AppTheme.fontSM,
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${record.formattedDate} â€¢ ${record.doctorName ?? 'Unknown'}',
                  style: const TextStyle(
                    fontSize: AppTheme.fontXS,
                    color: AppTheme.textLight,
                  ),
                ),
              ],
            ),
          ),
          if (record.fileName != null)
            IconButton(
              icon: const Icon(Icons.download, color: AppTheme.primary),
              onPressed: () {
                // Download file
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Downloading file...')),
                );
              },
            ),
        ],
      ),
    );
  }

  // ============================================
  // CLINICAL NOTES TAB
  // ============================================
  Widget _buildClinicalNotesTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(AppTheme.spaceMD),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        AddClinicalNotePage(patientId: widget.patientId),
                  ),
                ).then((_) => _loadData());
              },
              icon: const Icon(Icons.add),
              label: const Text('Add Clinical Note'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                ),
              ),
            ),
          ),
        ),
        Expanded(
          child: _clinicalNotes.isEmpty
              ? _buildEmptyState('No clinical notes', Icons.note_alt_outlined)
              : _buildClinicalNotesList(),
        ),
      ],
    );
  }

  Widget _buildClinicalNotesList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.spaceMD),
      itemCount: _clinicalNotes.length,
      itemBuilder: (context, index) {
        return _buildClinicalNoteCard(_clinicalNotes[index]);
      },
    );
  }

  Widget _buildClinicalNoteCard(ClinicalNote note) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.spaceSM),
      padding: const EdgeInsets.all(AppTheme.spaceMD),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spaceSM,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.testIconBackground,
                  borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                ),
                child: Text(
                  note.category.toString(),
                  style: const TextStyle(
                    fontSize: AppTheme.fontXS,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primary,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                note.formattedDate,
                style: const TextStyle(fontSize: AppTheme.fontSM, color: AppTheme.textLight),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spaceSM),
          Text(
            note.title,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: AppTheme.fontBody,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            note.content,
            style: const TextStyle(fontSize: AppTheme.fontSM, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: AppTheme.spaceSM),
          Text(
            'By ${note.doctorName}',
            style: const TextStyle(
              fontSize: AppTheme.fontXS,
              color: AppTheme.textLight,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String message, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: AppTheme.textLight.withValues(alpha: 0.5)),
          const SizedBox(height: AppTheme.spaceMD),
          Text(
            message,
            style: const TextStyle(fontSize: AppTheme.fontLG, color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }
}
