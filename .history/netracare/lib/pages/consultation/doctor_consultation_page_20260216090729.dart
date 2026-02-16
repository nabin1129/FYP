import 'package:flutter/material.dart';
import 'package:netracare/config/app_theme.dart';
import 'package:netracare/models/consultation/doctor_model.dart';
import 'package:netracare/models/consultation/consultation_model.dart';
import 'package:netracare/services/consultation_service.dart';
import 'package:netracare/pages/consultation/book_consultation_tab.dart';
import 'package:netracare/pages/consultation/consultation_history_tab.dart';

/// Main Doctor Consultation Page with Tabs
class DoctorConsultationPage extends StatefulWidget {
  const DoctorConsultationPage({super.key});

  @override
  State<DoctorConsultationPage> createState() => _DoctorConsultationPageState();
}

class _DoctorConsultationPageState extends State<DoctorConsultationPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Mock data - In production, these would come from API
  late List<Doctor> doctors;
  late List<Consultation> consultationHistory;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    // Initialize mock data
    doctors = Doctor.getMockDoctors();
    consultationHistory = Consultation.getMockHistory();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Doctor Consultation',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            height: 1,
            color: AppTheme.textLight.withOpacity(0.1),
          ),
        ),
      ),
      body: Column(
        children: [
          // Page Header
          Container(
            color: AppTheme.surface,
            padding: const EdgeInsets.fromLTRB(
              AppTheme.spaceMD,
              AppTheme.spaceSM,
              AppTheme.spaceMD,
              AppTheme.spaceMD,
            ),
            child: const Text(
              'Connect with eye care specialists for personalized advice',
              style: TextStyle(fontSize: 14, color: AppTheme.textSecondary),
            ),
          ),
          // Tab Bar
          Container(
            color: AppTheme.surface,
            child: TabBar(
              controller: _tabController,
              labelColor: AppTheme.primary,
              unselectedLabelColor: AppTheme.textSecondary,
              indicatorColor: AppTheme.primary,
              indicatorWeight: 2,
              labelStyle: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
              tabs: const [
                Tab(text: 'Book Consultation'),

                Tab(text: 'History'),
              ],
            ),
          ),
          // Tab Content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                BookConsultationTab(doctors: doctors),
                ConsultationHistoryTab(consultations: consultationHistory),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
