import 'package:flutter/material.dart';
import 'package:netracare/config/app_theme.dart';
import 'package:netracare/features/shared/widgets/shared_widgets.dart';
import 'package:netracare/models/consultation/doctor_model.dart';
import 'package:netracare/models/consultation/consultation_model.dart';
import 'package:netracare/services/consultation_service.dart';
import 'book_consultation_tab.dart';
import 'consultation_history_tab.dart';

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
    final colors = context.appColors;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: colors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Doctor Consultation',
          style: TextStyle(
            color: colors.textPrimary,
            fontSize: AppTheme.fontXXL,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: colors.primary),
            onPressed: _isLoading ? null : _refreshData,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            height: 1,
            color: colors.border.withValues(alpha: 0.5),
          ),
        ),
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: colors.primary),
                  SizedBox(height: AppTheme.spaceMD),
                  Text(
                    'Loading consultations...',
                    style: TextStyle(color: colors.textSecondary),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                // Page Header
                Container(
                  color: colors.surface,
                  padding: const EdgeInsets.fromLTRB(
                    AppTheme.spaceMD,
                    AppTheme.spaceSM,
                    AppTheme.spaceMD,
                    AppTheme.spaceMD,
                  ),
                  child: AppText(
                    'Connect with eye care specialists for personalized advice',
                    role: AppTextRole.bodySecondary,
                  ),
                ),
                // Tab Bar
                Container(
                  color: colors.surface,
                  child: TabBar(
                    controller: _tabController,
                    labelColor: colors.primary,
                    unselectedLabelColor: colors.textSecondary,
                    indicatorColor: colors.primary,
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
