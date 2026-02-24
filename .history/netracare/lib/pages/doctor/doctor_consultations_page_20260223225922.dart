import 'package:flutter/material.dart';
import '../../config/app_theme.dart';
import '../../services/doctor_service.dart';
import '../../models/doctor/doctor_analytics_model.dart';
import 'doctor_chat_page.dart';

/// Doctor Consultation Page - Manage consultation requests and chat
class DoctorConsultationsPage extends StatefulWidget {
  const DoctorConsultationsPage({super.key});

  @override
  State<DoctorConsultationsPage> createState() =>
      _DoctorConsultationsPageState();
}

class _DoctorConsultationsPageState extends State<DoctorConsultationsPage>
    with SingleTickerProviderStateMixin {
  final DoctorService _doctorService = DoctorService();
  late TabController _tabController;

  List<ConsultationRequest> _pendingRequests = [];
  List<ConsultationRequest> _acceptedRequests = [];
  List<ConsultationRequest> _completedRequests = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
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
      if (mounted) {
        _categorizeRequests(allRequests);
      }
    } catch (e) {
      // Fallback to synchronous data
      if (mounted) {
        _categorizeRequests(_doctorService.getConsultationRequests());
      }
    }
  }

  void _categorizeRequests(List<ConsultationRequest> allRequests) {
    setState(() {
      _pendingRequests = allRequests
          .where((r) => r.status == RequestStatus.pending)
          .toList();
      _acceptedRequests = allRequests
          .where((r) => r.status == RequestStatus.accepted)
          .toList();
      _completedRequests = allRequests
          .where(
            (r) =>
                r.status == RequestStatus.completed ||
                r.status == RequestStatus.rejected,
          )
          .toList();
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.primary),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadDataAsync,
      child: Column(
        children: [
          _buildHeader(),
          _buildTabBar(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildRequestsList(_pendingRequests, 'pending'),
                _buildRequestsList(_acceptedRequests, 'accepted'),
                _buildRequestsList(_completedRequests, 'history'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spaceMD),
      color: AppTheme.surface,
      child: Row(
        children: [
          Expanded(
            child: _buildStatBox(
              'Pending',
              '${_pendingRequests.length}',
              AppTheme.warning,
            ),
          ),
          const SizedBox(width: AppTheme.spaceSM),
          Expanded(
            child: _buildStatBox(
              'Active',
              '${_acceptedRequests.length}',
              AppTheme.success,
            ),
          ),
          const SizedBox(width: AppTheme.spaceSM),
          Expanded(
            child: _buildStatBox(
              'Completed',
              '${_completedRequests.length}',
              AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatBox(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spaceMD,
        vertical: AppTheme.spaceSM,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(label, style: TextStyle(fontSize: 12, color: color)),
        ],
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
        labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        tabs: [
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('Pending'),
                if (_pendingRequests.isNotEmpty) ...[
                  const SizedBox(width: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.warning,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${_pendingRequests.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const Tab(text: 'Active'),
          const Tab(text: 'History'),
        ],
      ),
    );
  }

  Widget _buildRequestsList(List<ConsultationRequest> requests, String type) {
    if (requests.isEmpty) {
      return _buildEmptyState(type);
    }

    return RefreshIndicator(
      onRefresh: _loadDataAsync,
      child: ListView.builder(
        padding: const EdgeInsets.all(AppTheme.spaceMD),
        itemCount: requests.length,
        itemBuilder: (context, index) {
          return _buildRequestCard(requests[index], type);
        },
      ),
    );
  }

  Widget _buildEmptyState(String type) {
    String message;
    IconData icon;

    switch (type) {
      case 'pending':
        message = 'No pending consultation requests';
        icon = Icons.inbox_outlined;
        break;
      case 'accepted':
        message = 'No active consultations';
        icon = Icons.chat_bubble_outline;
        break;
      default:
        message = 'No consultation history';
        icon = Icons.history;
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: AppTheme.textLight.withOpacity(0.5)),
          const SizedBox(height: AppTheme.spaceMD),
          Text(
            message,
            style: const TextStyle(fontSize: 16, color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildRequestCard(ConsultationRequest request, String type) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.spaceSM),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppTheme.spaceMD),
            child: Row(
              children: [
                // Avatar
                CircleAvatar(
                  radius: 26,
                  backgroundColor: AppTheme.testIconBackground,
                  child: Text(
                    request.initials,
                    style: const TextStyle(
                      color: AppTheme.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                const SizedBox(width: AppTheme.spaceMD),
                // Patient Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        request.patientName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            request.requestType == 'video_call'
                                ? Icons.videocam
                                : Icons.chat_bubble_outline,
                            size: 14,
                            color: AppTheme.textSecondary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            request.requestType == 'video_call'
                                ? 'Video Call'
                                : 'Chat',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                          const SizedBox(width: AppTheme.spaceSM),
                          const Icon(
                            Icons.access_time,
                            size: 14,
                            color: AppTheme.textLight,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            request.requestedAgo,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.textLight,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Status Badge
                _buildStatusBadge(request.status),
              ],
            ),
          ),
          // Message
          if (request.message != null && request.message!.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(
                AppTheme.spaceMD,
                0,
                AppTheme.spaceMD,
                AppTheme.spaceSM,
              ),
              child: Container(
                padding: const EdgeInsets.all(AppTheme.spaceSM),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceLight,
                  borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                ),
                child: Text(
                  request.message!,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppTheme.textSecondary,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ),
          // Actions
          if (type == 'pending')
            _buildPendingActions(request)
          else if (type == 'accepted')
            _buildAcceptedActions(request),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(RequestStatus status) {
    Color color;
    String label;

    switch (status) {
      case RequestStatus.pending:
        color = AppTheme.warning;
        label = 'Pending';
        break;
      case RequestStatus.accepted:
        color = AppTheme.success;
        label = 'Active';
        break;
      case RequestStatus.rejected:
        color = AppTheme.error;
        label = 'Rejected';
        break;
      case RequestStatus.completed:
        color = AppTheme.textSecondary;
        label = 'Completed';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spaceSM,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  Widget _buildPendingActions(ConsultationRequest request) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spaceMD),
      decoration: BoxDecoration(
        color: AppTheme.surfaceLight,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(AppTheme.radiusLarge),
          bottomRight: Radius.circular(AppTheme.radiusLarge),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => _showRejectDialog(request),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.error,
                side: const BorderSide(color: AppTheme.error),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: const Text('Decline'),
            ),
          ),
          const SizedBox(width: AppTheme.spaceMD),
          Expanded(
            child: ElevatedButton(
              onPressed: () => _showAcceptDialog(request),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.success,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: const Text('Accept'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAcceptedActions(ConsultationRequest request) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spaceMD),
      decoration: BoxDecoration(
        color: AppTheme.surfaceLight,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(AppTheme.radiusLarge),
          bottomRight: Radius.circular(AppTheme.radiusLarge),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () {
                // View patient details
              },
              icon: const Icon(Icons.person, size: 18),
              label: const Text('View Patient'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.primary,
                side: const BorderSide(color: AppTheme.primary),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          const SizedBox(width: AppTheme.spaceMD),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () {
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
              },
              icon: Icon(
                request.requestType == 'video_call'
                    ? Icons.videocam
                    : Icons.chat,
                size: 18,
              ),
              label: Text(
                request.requestType == 'video_call' ? 'Start Call' : 'Chat',
              ),
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

  void _showAcceptDialog(ConsultationRequest request) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        ),
        title: const Text('Accept Consultation'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Accept consultation request from ${request.patientName}?'),
            const SizedBox(height: AppTheme.spaceMD),
            const Text(
              'The patient will be notified and can start the consultation.',
              style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              _doctorService.acceptRequest(
                request.id,
                'Scheduled for consultation',
              );
              Navigator.pop(context);
              _loadDataAsync();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Consultation request accepted'),
                  backgroundColor: AppTheme.success,
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.success),
            child: const Text('Accept'),
          ),
        ],
      ),
    );
  }

  void _showRejectDialog(ConsultationRequest request) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        ),
        title: const Text('Decline Consultation'),
        content: Text(
          'Are you sure you want to decline the consultation request from ${request.patientName}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              _doctorService.rejectRequest(request.id);
              Navigator.pop(context);
              _loadDataAsync();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Consultation request declined')),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            child: const Text('Decline'),
          ),
        ],
      ),
    );
  }
}
