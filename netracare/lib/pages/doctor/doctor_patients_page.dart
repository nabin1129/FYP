import 'package:flutter/material.dart';
import '../../config/app_theme.dart';
import '../../services/doctor_service.dart';
import '../../models/doctor/patient_model.dart';
import 'patient_detail_page.dart';

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
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.primary),
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
    return Container(
      padding: const EdgeInsets.all(AppTheme.spaceMD),
      color: AppTheme.surface,
      child: Column(
        children: [
          // Search Bar
          TextField(
            controller: _searchController,
            onChanged: _onSearchChanged,
            decoration: InputDecoration(
              hintText: 'Search patients...',
              hintStyle: const TextStyle(color: AppTheme.textLight),
              prefixIcon: const Icon(
                Icons.search,
                color: AppTheme.textSecondary,
              ),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(
                        Icons.clear,
                        color: AppTheme.textSecondary,
                      ),
                      onPressed: () {
                        _searchController.clear();
                        _onSearchChanged('');
                      },
                    )
                  : null,
              filled: true,
              fillColor: AppTheme.background,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppTheme.spaceMD,
                vertical: AppTheme.spaceSM,
              ),
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
        chipColor = AppTheme.primary;
        break;
    }

    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => _onFilterChanged(isSelected ? null : status),
      selectedColor: chipColor.withOpacity(0.2),
      backgroundColor: AppTheme.surfaceLight,
      labelStyle: TextStyle(
        color: isSelected ? chipColor : AppTheme.textSecondary,
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
      ),
      checkmarkColor: chipColor,
      side: BorderSide(
        color: isSelected ? chipColor : AppTheme.textLight.withOpacity(0.3),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off,
            size: 64,
            color: AppTheme.textLight.withOpacity(0.5),
          ),
          const SizedBox(height: AppTheme.spaceMD),
          const Text(
            'No patients found',
            style: TextStyle(
              fontSize: AppTheme.fontXL,
              fontWeight: FontWeight.w500,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: AppTheme.spaceSM),
          Text(
            _searchQuery.isNotEmpty
                ? 'Try a different search term'
                : 'No patients match the selected filter',
            style: const TextStyle(color: AppTheme.textLight),
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
    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.spaceSM),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        boxShadow: AppTheme.cardShadow,
      ),
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
                  backgroundColor: AppTheme.testIconBackground,
                  child: Text(
                    patient.initials,
                    style: const TextStyle(
                      color: AppTheme.primary,
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
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: AppTheme.fontLG,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Last test: ${patient.lastTestAgo}',
                        style: const TextStyle(
                          fontSize: AppTheme.fontSM,
                          color: AppTheme.textSecondary,
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
                          '${patient.healthScore}',
                          style: const TextStyle(
                            fontSize: AppTheme.fontXXL,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary,
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
                              : AppTheme.textSecondary,
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
        color: badgeColor.withOpacity(0.1),
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
