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
  final ConsultationService _consultationService = ConsultationService();

  List<Doctor> doctors = [];
  List<Consultation> consultationHistory = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _initializeData();
  }

  Future<void> _initializeData() async {
    setState(() => _isLoading = true);

    await Future.wait([_loadDoctors(), _loadConsultations()]);

    setState(() => _isLoading = false);
  }

  Future<void> _loadDoctors() async {
    try {
      final loadedDoctors = await _consultationService
          .getAvailableDoctorsAsync();
      if (mounted) {
        setState(() {
          doctors = loadedDoctors;
        });
      }
    } catch (e) {
      // Fallback to mock data
      if (mounted) {
        setState(() {
          doctors = Doctor.getMockDoctors();
        });
      }
    }
  }

  Future<void> _loadConsultations() async {
    try {
      final loadedConsultations = await _consultationService
          .getAllConsultationsAsync();
      if (mounted) {
        setState(() {
          consultationHistory = loadedConsultations;
        });
      }
    } catch (e) {
      // Fallback to local data
      if (mounted) {
        setState(() {
          consultationHistory = _consultationService.getAllConsultations();
        });
      }
    }
  }

  Future<void> _refreshData() async {
    setState(() => _isLoading = true);
    await Future.wait([_loadDoctors(), _loadConsultations()]);
    if (mounted) {
      setState(() => _isLoading = false);
    }
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
            fontSize: AppTheme.fontXXL,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppTheme.primary),
            onPressed: _isLoading ? null : _refreshData,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            height: 1,
            color: AppTheme.textLight.withValues(alpha: 0.1),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: AppTheme.primary),
                  SizedBox(height: AppTheme.spaceMD),
                  Text(
                    'Loading consultations...',
                    style: TextStyle(color: AppTheme.textSecondary),
                  ),
                ],
              ),
            )
          : Column(
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
                    style: TextStyle(
                      fontSize: AppTheme.fontBody,
                      color: AppTheme.textSecondary,
                    ),
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
                      fontSize: AppTheme.fontBody,
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
                      RefreshIndicator(
                        onRefresh: _loadDoctors,
                        child: BookConsultationTab(
                          doctors: doctors,
                          onConsultationRequested: () {
                            _loadConsultations();
                            // Switch to history tab to show the pending request
                            _tabController.animateTo(1);
                          },
                        ),
                      ),
                      RefreshIndicator(
                        onRefresh: _loadConsultations,
                        child: ConsultationHistoryTab(
                          consultations: consultationHistory,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
