import 'package:flutter/material.dart';
import 'package:netracare/config/app_theme.dart';
import 'package:netracare/services/doctor_service.dart';
import 'package:netracare/services/doctor_api_service.dart';
import 'package:netracare/models/doctor/doctor_analytics_model.dart';
import 'doctor_chat_page.dart';
import 'doctor_slot_management_page.dart';

/// Doctor Consultation Page - Manage consultation requests and chat
class DoctorConsultationsPage extends StatefulWidget {
  const DoctorConsultationsPage({super.key, this.initialTabIndex = 0});

  final int initialTabIndex;

  @override
  State<DoctorConsultationsPage> createState() =>
      _DoctorConsultationsPageState();
}

class _DoctorConsultationsPageState extends State<DoctorConsultationsPage>
    with SingleTickerProviderStateMixin {
  final DoctorService _doctorService = DoctorService();
  late TabController _tabController;

  List<ConsultationRequest> _activeConsultations = [];
  List<ConsultationRequest> _completedConsultations = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    final safeInitialIndex = widget.initialTabIndex.clamp(0, 1);
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: safeInitialIndex,
    );
    _loadDataAsync();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadDataAsync() async {
    setState(() => _isLoading = true);

    try {
      final allRequests = await _doctorService.getConsultationRequestsAsync();
      if (!mounted) return;
      _categorizeRequests(allRequests);
    } catch (_) {
      if (!mounted) return;
      _categorizeRequests(_doctorService.getConsultationRequests());
    }
  }

  void _categorizeRequests(List<ConsultationRequest> allRequests) {
    setState(() {
      // Deduplicate by patientId - keep only the latest consultation per patient
      final activeByPatient = <String, ConsultationRequest>{};
      final completedByPatient = <String, ConsultationRequest>{};

      for (final req in allRequests) {
        if (req.status == RequestStatus.accepted) {
          // Keep the latest (most recent) active consultation for each patient
          if (!activeByPatient.containsKey(req.patientId) ||
              req.requestedAt.isAfter(
                activeByPatient[req.patientId]!.requestedAt,
              )) {
            activeByPatient[req.patientId] = req;
          }
        } else if (req.status == RequestStatus.completed) {
          // Keep the latest completed consultation for each patient
          if (!completedByPatient.containsKey(req.patientId) ||
              req.requestedAt.isAfter(
                completedByPatient[req.patientId]!.requestedAt,
              )) {
            completedByPatient[req.patientId] = req;
          }
        }
      }

      _activeConsultations = activeByPatient.values.toList();
      _completedConsultations = completedByPatient.values.toList();
      _isLoading = false;
    });
  }

  Future<void> _completeConsultation(ConsultationRequest request) async {
    final messenger = ScaffoldMessenger.of(context);

    final colors = context.appColors;
    final shouldComplete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        ),
        title: const Text('Complete Consultation'),
        content: Text(
          'Mark consultation with ${request.patientName} as completed?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(backgroundColor: colors.success),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );

    if (shouldComplete != true) {
      return;
    }

    try {
      await DoctorApiService.completeConsultation(consultationId: request.id);

      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: const Text('Consultation marked as completed'),
          backgroundColor: colors.success,
        ),
      );
      _loadDataAsync();
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: colors.error),
      );
    }
  }

  void _openChat(ConsultationRequest request) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DoctorChatPage(
          patientId: request.patientId,
          patientName: request.patientName,
          consultationId: int.tryParse(request.id),
        ),
      ),
    );
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
          'Consultations',
          style: TextStyle(
            color: colors.textPrimary,
            fontSize: AppTheme.fontXXL,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: colors.primary),
            onPressed: _isLoading ? null : _loadDataAsync,
          ),
          IconButton(
            icon: Icon(Icons.calendar_month, color: colors.primary),
            tooltip: 'Manage assigned slots',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const DoctorSlotManagementPage(),
                ),
              );
            },
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            height: 1,
            color: colors.textLight.withValues(alpha: 0.1),
          ),
        ),
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: colors.primary),
                  const SizedBox(height: AppTheme.spaceMD),
                  Text(
                    'Loading consultations...',
                    style: TextStyle(color: colors.textSecondary),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                Container(
                  color: colors.surface,
                  padding: const EdgeInsets.fromLTRB(
                    AppTheme.spaceMD,
                    AppTheme.spaceSM,
                    AppTheme.spaceMD,
                    AppTheme.spaceMD,
                  ),
                  child: Text(
                    'Manage active patient chats and review completed consultations.',
                    style: TextStyle(
                      fontSize: AppTheme.fontBody,
                      color: colors.textSecondary,
                    ),
                  ),
                ),
                Material(
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
                      Tab(text: 'Chat'),
                      Tab(text: 'History'),
                    ],
                  ),
                ),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      RefreshIndicator(
                        onRefresh: _loadDataAsync,
                        child: _buildConsultationList(
                          consultations: _activeConsultations,
                          emptyTitle: 'No active chat consultations',
                          emptySubtitle:
                              'Active patient chats will appear here when they are ready.',
                          emptyIcon: Icons.chat_bubble_outline,
                          showActions: true,
                        ),
                      ),
                      RefreshIndicator(
                        onRefresh: _loadDataAsync,
                        child: _buildConsultationList(
                          consultations: _completedConsultations,
                          emptyTitle: 'No consultation history',
                          emptySubtitle:
                              'Completed consultations will appear here.',
                          emptyIcon: Icons.history,
                          showActions: true,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildConsultationList({
    required List<ConsultationRequest> consultations,
    required String emptyTitle,
    required String emptySubtitle,
    required IconData emptyIcon,
    required bool showActions,
  }) {
    final colors = context.appColors;
    if (consultations.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppTheme.spaceMD),
        children: [
          SizedBox(
            height: 360,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppTheme.spaceLG),
                    decoration: BoxDecoration(
                      color: colors.testIconBackground,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(emptyIcon, size: 48, color: colors.primary),
                  ),
                  const SizedBox(height: AppTheme.spaceMD),
                  Text(
                    emptyTitle,
                    style: TextStyle(
                      fontSize: AppTheme.fontLG,
                      fontWeight: FontWeight.w600,
                      color: colors.textPrimary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppTheme.spaceXS),
                  Text(
                    emptySubtitle,
                    style: TextStyle(
                      fontSize: AppTheme.fontBody,
                      color: colors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(AppTheme.spaceMD),
      itemCount: consultations.length,
      itemBuilder: (context, index) {
        return _buildConsultationCard(
          consultation: consultations[index],
          showActions: showActions,
        );
      },
    );
  }

  Widget _buildConsultationCard({
    required ConsultationRequest consultation,
    required bool showActions,
  }) {
    final colors = context.appColors;
    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.spaceMD),
      padding: const EdgeInsets.all(AppTheme.spaceMD),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        boxShadow: AppTheme.adaptiveCardShadow(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      consultation.patientName,
                      style: TextStyle(
                        fontSize: AppTheme.fontLG,
                        fontWeight: FontWeight.bold,
                        color: colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: AppTheme.spaceXS),
                    Text(
                      consultation.requestedAgo,
                      style: TextStyle(
                        fontSize: AppTheme.fontSM,
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              _buildStatusBadge(consultation.status),
            ],
          ),
          const SizedBox(height: AppTheme.spaceSM),
          Row(
            children: [
              Icon(
                consultation.requestType == 'physical'
                    ? Icons.local_hospital_outlined
                    : Icons.chat_bubble_outline,
                size: 16,
                color: colors.textLight,
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  consultation.requestType == 'physical' ? 'Physical' : 'Chat',
                  style: TextStyle(
                    fontSize: AppTheme.fontSM,
                    color: colors.textSecondary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          if (consultation.message != null &&
              consultation.message!.isNotEmpty) ...[
            const SizedBox(height: AppTheme.spaceSM),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppTheme.spaceSM),
              decoration: BoxDecoration(
                color: colors.surfaceLight,
                borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
              ),
              child: Text(
                consultation.message!,
                style: TextStyle(
                  fontSize: AppTheme.fontSM,
                  color: colors.textSecondary,
                ),
              ),
            ),
          ],
          if (showActions) ...[
            const SizedBox(height: AppTheme.spaceMD),
            Row(
              children: [
                // Show Mark Completed button only for active (accepted) consultations
                if (consultation.status == RequestStatus.accepted) ...[
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _completeConsultation(consultation),
                      icon: const Icon(Icons.check_circle_outline, size: 18),
                      label: const Text('Mark Completed'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: colors.success,
                        side: BorderSide(color: colors.success),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppTheme.spaceMD),
                ],
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _openChat(consultation),
                    icon: const Icon(Icons.chat, size: 18),
                    label: const Text('Chat'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusBadge(RequestStatus status) {
    final color = _statusColor(status);
    final label = _statusLabel(status);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spaceSM,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: AppTheme.fontXS,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  Color _statusColor(RequestStatus status) {
    final colors = context.appColors;
    switch (status) {
      case RequestStatus.pending:
        return colors.warning;
      case RequestStatus.accepted:
        return colors.success;
      case RequestStatus.rejected:
        return colors.error;
      case RequestStatus.completed:
        return colors.textSecondary;
    }
  }

  String _statusLabel(RequestStatus status) {
    switch (status) {
      case RequestStatus.pending:
        return 'Pending';
      case RequestStatus.accepted:
        return 'Active';
      case RequestStatus.rejected:
        return 'Rejected';
      case RequestStatus.completed:
        return 'Completed';
    }
  }
}
