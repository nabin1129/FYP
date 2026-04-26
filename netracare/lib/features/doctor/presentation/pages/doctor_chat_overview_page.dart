import 'package:flutter/material.dart';
import 'package:netracare/config/app_theme.dart';
import 'package:netracare/models/doctor/doctor_analytics_model.dart';
import 'package:netracare/services/doctor_service.dart';

import 'doctor_chat_page.dart';

/// Chat-only page launched from the app bar chat shortcut.
class DoctorChatOverviewPage extends StatefulWidget {
  const DoctorChatOverviewPage({super.key});

  @override
  State<DoctorChatOverviewPage> createState() => _DoctorChatOverviewPageState();
}

class _DoctorChatOverviewPageState extends State<DoctorChatOverviewPage> {
  final DoctorService _doctorService = DoctorService();

  List<ConsultationRequest> _activeConsultations = [];
  List<ConsultationRequest> _completedConsultations = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDataAsync();
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
          'Chat',
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
        ],
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(color: colors.primary),
            )
          : RefreshIndicator(
              onRefresh: _loadDataAsync,
              child: _buildChatList(),
            ),
    );
  }

  Widget _buildChatList() {
    final colors = context.appColors;
    if (_activeConsultations.isEmpty && _completedConsultations.isEmpty) {
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
                    child: Icon(
                      Icons.chat_bubble_outline,
                      size: 48,
                      color: colors.primary,
                    ),
                  ),
                  const SizedBox(height: AppTheme.spaceMD),
                  Text(
                    'No chats available',
                    style: TextStyle(
                      fontSize: AppTheme.fontLG,
                      fontWeight: FontWeight.w600,
                      color: colors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(AppTheme.spaceMD),
      children: [
        if (_activeConsultations.isNotEmpty) ...[
          Text(
            'Active Chats',
            style: TextStyle(
              fontSize: AppTheme.fontLG,
              fontWeight: FontWeight.bold,
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: AppTheme.spaceSM),
          ..._activeConsultations.map(_buildConsultationCard),
        ],
        if (_completedConsultations.isNotEmpty) ...[
          if (_activeConsultations.isNotEmpty)
            const SizedBox(height: AppTheme.spaceSM),
          Text(
            'Completed Patients',
            style: TextStyle(
              fontSize: AppTheme.fontLG,
              fontWeight: FontWeight.bold,
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: AppTheme.spaceSM),
          ..._completedConsultations.map(_buildConsultationCard),
        ],
      ],
    );
  }

  Widget _buildConsultationCard(ConsultationRequest consultation) {
    final colors = context.appColors;
    final isCompleted = consultation.status == RequestStatus.completed;

    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.spaceMD),
      padding: const EdgeInsets.all(AppTheme.spaceMD),
      decoration: BoxDecoration(
        color: isCompleted ? colors.surfaceLight : colors.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        boxShadow: AppTheme.adaptiveCardShadow(context),
        border: isCompleted ? Border.all(color: colors.border) : null,
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
                        color: isCompleted
                            ? colors.textSecondary
                            : colors.textPrimary,
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
              Text(
                consultation.requestType == 'physical' ? 'Physical' : 'Chat',
                style: TextStyle(
                  fontSize: AppTheme.fontSM,
                  color: colors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spaceMD),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _openChat(consultation),
              icon: const Icon(Icons.chat, size: 18),
              label: const Text('Open Chat'),
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(RequestStatus status) {
    final colors = context.appColors;
    final color = switch (status) {
      RequestStatus.pending => colors.warning,
      RequestStatus.accepted => colors.success,
      RequestStatus.rejected => colors.error,
      RequestStatus.completed => colors.textSecondary,
    };

    final label = switch (status) {
      RequestStatus.pending => 'Pending',
      RequestStatus.accepted => 'Active',
      RequestStatus.rejected => 'Rejected',
      RequestStatus.completed => 'Completed',
    };

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
}
