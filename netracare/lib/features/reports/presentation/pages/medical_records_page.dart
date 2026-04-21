import 'package:flutter/material.dart';
import 'package:netracare/config/app_theme.dart';
import 'package:netracare/features/shared/widgets/record_detail_sheet.dart';
import 'package:netracare/services/api_service.dart';
import 'package:intl/intl.dart';

class MedicalRecordsPage extends StatefulWidget {
  const MedicalRecordsPage({super.key});

  @override
  State<MedicalRecordsPage> createState() => _MedicalRecordsPageState();
}

class _MedicalRecordsPageState extends State<MedicalRecordsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool isLoading = true;
  List<dynamic> scanReports = [];
  List<dynamic> prescriptions = [];
  List<dynamic> labReports = [];
  List<dynamic> clinicalNotes = [];
  List<dynamic> testResults = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _loadMedicalRecords();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadMedicalRecords() async {
    try {
      final records = await ApiService.getMedicalRecords();
      if (!mounted) return;

      setState(() {
        scanReports = records['scanReports'] ?? [];
        prescriptions = records['prescriptions'] ?? [];
        labReports = records['labReports'] ?? [];
        clinicalNotes = records['clinicalNotes'] ?? [];
        testResults = records['testResults'] ?? [];
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      // Instead of showing error, just show empty state
      // The backend endpoint might not exist yet
      setState(() {
        scanReports = [];
        prescriptions = [];
        labReports = [];
        clinicalNotes = [];
        testResults = [];
        isLoading = false;
        // Don't set errorMessage - just show empty states
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.textDark),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Medical Records',
          style: TextStyle(
            color: AppTheme.textDark,
            fontWeight: FontWeight.w600,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppTheme.categoryBlue,
          unselectedLabelColor: AppTheme.textSecondary,
          indicatorColor: AppTheme.categoryBlue,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Scan Reports'),
            Tab(text: 'Prescriptions'),
            Tab(text: 'Lab Reports'),
            Tab(text: 'Clinical Notes'),
            Tab(text: 'Test Results'),
          ],
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _RecordsList(records: scanReports, type: 'scan'),
                _RecordsList(records: prescriptions, type: 'prescription'),
                _RecordsList(records: labReports, type: 'lab'),
                _RecordsList(records: clinicalNotes, type: 'clinical'),
                _RecordsList(records: testResults, type: 'test'),
              ],
            ),
    );
  }
}

class _RecordsList extends StatelessWidget {
  final List<dynamic> records;
  final String type;

  const _RecordsList({required this.records, required this.type});

  @override
  Widget build(BuildContext context) {
    if (records.isEmpty) {
      return _buildEmptyView();
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: records.length,
      itemBuilder: (context, index) {
        final record = records[index];
        return _MedicalRecordCard(record: record, type: type);
      },
    );
  }

  Widget _buildEmptyView() {
    IconData icon;
    String title;
    String subtitle;

    switch (type) {
      case 'scan':
        icon = Icons.medical_services_outlined;
        title = 'No Scan Reports';
        subtitle = 'Your scan reports will appear here';
        break;
      case 'prescription':
        icon = Icons.receipt_long;
        title = 'No Prescriptions';
        subtitle = 'Your prescriptions will appear here';
        break;
      case 'lab':
        icon = Icons.biotech;
        title = 'No Lab Reports';
        subtitle = 'Your lab reports will appear here';
        break;
      case 'clinical':
        icon = Icons.assignment;
        title = 'No Clinical Notes';
        subtitle = 'Clinical notes from your doctors will appear here';
        break;
      case 'test':
        icon = Icons.science;
        title = 'No Test Results';
        subtitle = 'Test results assigned by your doctors will appear here';
        break;
      default:
        icon = Icons.folder_outlined;
        title = 'No Records';
        subtitle = 'Your medical records will appear here';
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 80, color: AppTheme.border),
            const SizedBox(height: 16),
            Text(
              title,
              style: TextStyle(
                fontSize: AppTheme.fontXL,
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: AppTheme.fontBody,
                color: Colors.grey.shade500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _MedicalRecordCard extends StatelessWidget {
  final dynamic record;
  final String type;

  const _MedicalRecordCard({required this.record, required this.type});

  @override
  Widget build(BuildContext context) {
    final date = record['date'] != null
        ? DateFormat('MMM dd, yyyy').format(DateTime.parse(record['date']))
        : 'Unknown';

    final title = record['title'] ?? 'Medical Record';
    final doctor = record['doctorName'] ?? record['doctor'] ?? 'N/A';
    final source = (record['source'] ?? 'personal').toString();
    final category = (record['category'] ?? '').toString();
    final recordType = (record['record_type'] ?? '').toString();
    final isFromDoctor = source.startsWith('doctor') || doctor != 'N/A';
    final detailLabel = _resolveDetailLabel(
      category: category,
      recordType: recordType,
      source: source,
    );

    IconData icon;
    Color iconColor;

    switch (type) {
      case 'scan':
        icon = Icons.medical_services;
        iconColor = AppTheme.error;
        break;
      case 'prescription':
        icon = Icons.receipt_long;
        iconColor = AppTheme.categoryPurple;
        break;
      case 'lab':
        icon = Icons.biotech;
        iconColor = const Color(0xFF06B6D4);
        break;
      case 'clinical':
        icon = Icons.assignment;
        iconColor = const Color(0xFF8B5CF6);
        break;
      case 'test':
        icon = Icons.science;
        iconColor = const Color(0xFF10B981);
        break;
      default:
        icon = Icons.folder;
        iconColor = AppTheme.textSecondary;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppTheme.border),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => RecordDetailSheet.show(
          context,
          Map<String, dynamic>.from(record as Map),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: iconColor, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textDark,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isFromDoctor)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(
                                0xFF06B6D4,
                              ).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'Dr.',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF06B6D4),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    if (detailLabel != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: iconColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(100),
                          ),
                          child: Text(
                            detailLabel,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: iconColor,
                            ),
                          ),
                        ),
                      ),
                    Row(
                      children: [
                        Icon(
                          Icons.calendar_today,
                          size: 14,
                          color: AppTheme.textSecondary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          date,
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        if (isFromDoctor) ...[
                          Icon(
                            Icons.person,
                            size: 14,
                            color: AppTheme.textSecondary,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              'From $doctor',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppTheme.textSecondary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Icon(Icons.chevron_right, color: AppTheme.border),
            ],
          ),
        ),
      ),
    );
  }

  String? _resolveDetailLabel({
    required String category,
    required String recordType,
    required String source,
  }) {
    final normalizedCategory = category.toLowerCase();
    final normalizedType = recordType.toLowerCase();

    if (source == 'doctor_consultation') {
      if (normalizedCategory == 'diagnosis') return 'Diagnosis';
      if (normalizedType == 'prescription') return 'Prescription';
      return 'Consultation Note';
    }

    if (normalizedType == 'clinical_note') return 'Clinical Note';
    if (normalizedType == 'test_result') return 'Test Result';
    return null;
  }
}
