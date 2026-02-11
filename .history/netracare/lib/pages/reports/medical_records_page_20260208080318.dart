import 'package:flutter/material.dart';
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
  String? errorMessage;

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
      setState(() {
        errorMessage = e.toString().replaceAll('Exception:', '').trim();
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1F2937)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Medical Records',
          style: TextStyle(
            color: Color(0xFF1F2937),
            fontWeight: FontWeight.w600,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF3B82F6),
          unselectedLabelColor: Colors.grey,
          indicatorColor: const Color(0xFF3B82F6),
          tabs: const [
            Tab(text: 'Scan Reports'),
            Tab(text: 'Prescriptions'),
            Tab(text: 'Lab Reports'),
          ],
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage != null
              ? _buildErrorView()
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

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
            const SizedBox(height: 16),
            Text(
              errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  errorMessage = null;
                  isLoading = true;
                });
                _loadMedicalRecords();
              },
              child: const Text("Retry"),
            ),
          ],
        ),
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
    String message;

    switch (type) {
      case 'scan':
        icon = Icons.medical_services_outlined;
        message = 'No scan reports yet';
        break;
      case 'prescription':
        icon = Icons.receipt_long;
        message = 'No prescriptions yet';
        break;
      case 'lab':
        icon = Icons.biotech;
        message = 'No lab reports yet';
        break;
      default:
        icon = Icons.folder_outlined;
        message = 'No records yet';
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 80, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              message,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade600,
              ),
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
        iconColor = const Color(0xFFEF4444);
        break;
      case 'prescription':
        icon = Icons.receipt_long;
        iconColor = const Color(0xFF8B5CF6);
        break;
      case 'lab':
        icon = Icons.biotech;
        iconColor = const Color(0xFF06B6D4);
        break;
      default:
        icon = Icons.folder;
        iconColor = Colors.grey;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
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
                  color: iconColor.withOpacity(0.1),
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
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1F2937),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Dr. $doctor • $date',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey.shade400),
            ],
          ),
        ),
      ),
    );
  }
}
