import 'package:flutter/material.dart';
import 'package:netracare/config/app_theme.dart';
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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
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
          tabs: const [
            Tab(text: 'Scan Reports'),
            Tab(text: 'Prescriptions'),
            Tab(text: 'Lab Reports'),
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
              style: TextStyle(fontSize: AppTheme.fontBody, color: Colors.grey.shade500),
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
    final doctor = record['doctor'] ?? 'N/A';

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
        onTap: () {
          // Navigate to record details
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: AppTheme.fontLG,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textDark,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Dr. $doctor â€¢ $date',
                      style: TextStyle(
                        fontSize: AppTheme.fontSM,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: AppTheme.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
