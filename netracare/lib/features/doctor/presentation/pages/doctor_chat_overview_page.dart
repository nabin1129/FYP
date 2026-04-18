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
      _activeConsultations = allRequests
          .where((r) => r.status == RequestStatus.accepted)
          .toList();
      _completedConsultations = allRequests
          .where((r) => r.status == RequestStatus.completed)
          .toList();
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
          'Chat',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: AppTheme.fontXXL,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppTheme.primary),
            onPressed: _isLoading ? null : _loadDataAsync,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primary),
            )
          : RefreshIndicator(
              onRefresh: _loadDataAsync,
              child: _buildChatList(),
            ),
    );
  }

  Widget _buildChatList() {
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
                    decoration: const BoxDecoration(
                      color: AppTheme.testIconBackground,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.chat_bubble_outline,
                      size: 48,
                      color: AppTheme.primary,
                    ),
                  ),
                  const SizedBox(height: AppTheme.spaceMD),
                  const Text(
                    'No chats available',
                    style: TextStyle(
                      fontSize: AppTheme.fontLG,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
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
          const Text(
            'Active Chats',
            style: TextStyle(
              fontSize: AppTheme.fontLG,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: AppTheme.spaceSM),
          ..._activeConsultations.map(_buildConsultationCard),
        ],
        if (_completedConsultations.isNotEmpty) ...[
          if (_activeConsultations.isNotEmpty)
            const SizedBox(height: AppTheme.spaceSM),
          const Text(
            'Completed Patients',
            style: TextStyle(
              fontSize: AppTheme.fontLG,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: AppTheme.spaceSM),
          ..._completedConsultations.map(_buildConsultationCard),
        ],
      ],
    );
  }

  Widget _buildConsultationCard(ConsultationRequest consultation) {
    final isCompleted = consultation.status == RequestStatus.completed;

    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.spaceMD),
      padding: const EdgeInsets.all(AppTheme.spaceMD),
      decoration: BoxDecoration(
        color: isCompleted ? AppTheme.surfaceLight : AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        boxShadow: AppTheme.cardShadow,
        border: isCompleted ? Border.all(color: AppTheme.border) : null,
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
                            ? AppTheme.textSecondary
                            : AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: AppTheme.spaceXS),
                    Text(
                      consultation.requestedAgo,
                      style: const TextStyle(
                        fontSize: AppTheme.fontSM,
                        color: AppTheme.textSecondary,
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
                color: AppTheme.textLight,
              ),
              const SizedBox(width: 4),
              Text(
                consultation.requestType == 'physical' ? 'Physical' : 'Chat',
                style: const TextStyle(
                  fontSize: AppTheme.fontSM,
                  color: AppTheme.textSecondary,
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
                backgroundColor: AppTheme.primary,
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
    final color = switch (status) {
      RequestStatus.pending => AppTheme.warning,
      RequestStatus.accepted => AppTheme.success,
      RequestStatus.rejected => AppTheme.error,
      RequestStatus.completed => AppTheme.textSecondary,
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
