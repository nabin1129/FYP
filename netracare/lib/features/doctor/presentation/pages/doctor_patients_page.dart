import 'package:flutter/material.dart';
import 'package:netracare/config/app_theme.dart';
import 'package:netracare/features/shared/widgets/shared_widgets.dart';
import 'package:netracare/services/doctor_service.dart';
import 'package:netracare/models/doctor/patient_model.dart';
import 'patient_detail_page.dart';
import 'doctor_all_users_page.dart';

/// Doctor Patients Page - Patient List with Search and Filter
class DoctorPatientsPage extends StatefulWidget {
  const DoctorPatientsPage({super.key});

  @override
  State<DoctorPatientsPage> createState() => _DoctorPatientsPageState();
}

class _DoctorPatientsPageState extends State<DoctorPatientsPage> {
  final DoctorService _doctorService = DoctorService();
  final TextEditingController _searchController = TextEditingController();

  List<Patient> _allPatients = [];
  List<Patient> _patients = [];
  String _searchQuery = '';
  HealthStatus? _selectedStatus;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPatientsAsync();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadPatientsAsync() async {
    setState(() => _isLoading = true);

    try {
      final patients = await _doctorService.getPatientsAsync();
      if (mounted) {
        setState(() {
          _allPatients = patients;
          _applyFilters();
          _isLoading = false;
        });
      }
    } catch (e) {
      // Fallback to synchronous data
      if (mounted) {
        setState(() {
          _allPatients = _doctorService.getAllPatients();
          _applyFilters();
          _isLoading = false;
        });
      }
    }
  }

  void _applyFilters() {
    List<Patient> result = List.from(_allPatients);

    if (_searchQuery.isNotEmpty) {
      final lowerQuery = _searchQuery.toLowerCase();
      result = result
          .where((p) => p.name.toLowerCase().contains(lowerQuery))
          .toList();
    }

    if (_selectedStatus != null) {
      result = result.where((p) => p.status == _selectedStatus).toList();
    }

    _patients = result;
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query;
      _applyFilters();
    });
  }

  void _onFilterChanged(HealthStatus? status) {
    setState(() {
      _selectedStatus = status;
      _applyFilters();
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(color: colors.primary),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadPatientsAsync,
      child: Column(
        children: [
          _buildSearchAndFilter(),
          Expanded(
            child: _patients.isEmpty ? _buildEmptyState() : _buildPatientList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilter() {
    final colors = context.appColors;

    return Container(
      padding: const EdgeInsets.all(AppTheme.spaceMD),
      color: colors.surface,
      child: Column(
        children: [
          // Header with Title and All Users Button
          Row(
            children: [
              Expanded(
                child: Text(
                  'My Patients',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const DoctorAllUsersPage(),
                    ),
                  );
                },
                icon: const Icon(Icons.people, size: 18),
                label: const Text('All Users'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.primary,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.spaceSM,
                    vertical: AppTheme.spaceSM,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spaceMD),
          // Search Bar
          TextField(
            controller: _searchController,
            onChanged: _onSearchChanged,
            decoration: AppTheme.inputDecoration(
              label: '',
              prefixIcon: Icons.search,
            ).copyWith(
              hintText: 'Search patients...',
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: Icon(Icons.clear, color: colors.textSecondary),
                      onPressed: () {
                        _searchController.clear();
                        _onSearchChanged('');
                      },
                    )
                  : null,
              fillColor: colors.background,
            ),
          ),
          const SizedBox(height: AppTheme.spaceSM),
          // Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip(null, 'All'),
                const SizedBox(width: AppTheme.spaceSM),
                _buildFilterChip(HealthStatus.good, 'Good'),
                const SizedBox(width: AppTheme.spaceSM),
                _buildFilterChip(HealthStatus.attention, 'Attention'),
                const SizedBox(width: AppTheme.spaceSM),
                _buildFilterChip(HealthStatus.critical, 'Critical'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(HealthStatus? status, String label) {
    final colors = context.appColors;
    final isSelected = _selectedStatus == status;
    Color chipColor;

    switch (status) {
      case HealthStatus.good:
        chipColor = AppTheme.success;
        break;
      case HealthStatus.attention:
        chipColor = AppTheme.warning;
        break;
      case HealthStatus.critical:
        chipColor = AppTheme.error;
        break;
      case null:
        chipColor = colors.primary;
        break;
    }

    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => _onFilterChanged(isSelected ? null : status),
      selectedColor: chipColor.withValues(alpha: 0.2),
      backgroundColor: colors.surfaceLight,
      labelStyle: TextStyle(
        color: isSelected ? chipColor : colors.textSecondary,
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
      ),
      checkmarkColor: chipColor,
      side: BorderSide(
        color: isSelected
            ? chipColor
            : colors.textLight.withValues(alpha: 0.3),
      ),
    );
  }

  Widget _buildEmptyState() {
    final colors = context.appColors;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off,
            size: 64,
            color: colors.textLight.withValues(alpha: 0.5),
          ),
          const SizedBox(height: AppTheme.spaceMD),
          Text(
            'No patients found',
            style: TextStyle(
              fontSize: AppTheme.fontXL,
              fontWeight: FontWeight.w500,
              color: colors.textSecondary,
            ),
          ),
          const SizedBox(height: AppTheme.spaceSM),
          Text(
            _searchQuery.isNotEmpty
                ? 'Try a different search term'
                : 'No patients match the selected filter',
            style: TextStyle(color: colors.textLight),
          ),
        ],
      ),
    );
  }

  Widget _buildPatientList() {
    return RefreshIndicator(
      onRefresh: _loadPatientsAsync,
      child: ListView.builder(
        padding: const EdgeInsets.all(AppTheme.spaceMD),
        itemCount: _patients.length,
        itemBuilder: (context, index) {
          return _buildPatientCard(_patients[index]);
        },
      ),
    );
  }

  Widget _buildPatientCard(Patient patient) {
    final colors = context.appColors;

    return AppCard(
      margin: const EdgeInsets.only(bottom: AppTheme.spaceSM),
      border: Border.all(color: colors.border.withValues(alpha: 0.7)),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => PatientDetailPage(patientId: patient.id),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.spaceMD),
            child: Row(
              children: [
                // Avatar
                CircleAvatar(
                  radius: 26,
                  backgroundColor: colors.testIconBackground,
                  child: Text(
                    patient.initials,
                    style: TextStyle(
                      color: colors.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: AppTheme.fontLG,
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
                        patient.name,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: AppTheme.fontLG,
                          color: colors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Last test: ${patient.lastTestAgo}',
                        style: TextStyle(
                          fontSize: AppTheme.fontSM,
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                // Score and Status
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(
                      children: [
                        Text(
                          patient.healthScore > 0
                              ? '${patient.healthScore}'
                              : '—',
                          style: TextStyle(
                            fontSize: AppTheme.fontXXL,
                            fontWeight: FontWeight.bold,
                            color: colors.textPrimary,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          patient.trend == 'up'
                              ? Icons.trending_up
                              : patient.trend == 'down'
                              ? Icons.trending_down
                              : Icons.trending_flat,
                          color: patient.trend == 'up'
                              ? AppTheme.success
                              : patient.trend == 'down'
                              ? AppTheme.error
                              : colors.textSecondary,
                          size: 20,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    _buildStatusBadge(patient.status),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(HealthStatus status) {
    Color badgeColor;
    switch (status) {
      case HealthStatus.good:
        badgeColor = AppTheme.success;
        break;
      case HealthStatus.attention:
        badgeColor = AppTheme.warning;
        break;
      case HealthStatus.critical:
        badgeColor = AppTheme.error;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spaceSM,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          fontSize: AppTheme.fontXS,
          fontWeight: FontWeight.w600,
          color: badgeColor,
        ),
      ),
    );
  }
}
