import 'package:flutter/material.dart';
import '../../config/app_theme.dart';
import '../../models/admin/admin_user_model.dart';
import '../../services/admin_service.dart';

/// Admin Users Page — Page 2: Monitor and manage users/patients
class AdminUsersPage extends StatefulWidget {
  const AdminUsersPage({super.key});

  @override
  State<AdminUsersPage> createState() => _AdminUsersPageState();
}

class _AdminUsersPageState extends State<AdminUsersPage> {
  final AdminService _service = AdminService();
  final _searchCtrl = TextEditingController();
  String _filter = 'all';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<AdminUser> get _filtered =>
      _service.searchUsers(_searchCtrl.text, filter: _filter);

  void _refresh() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          _buildStatsBar(),
          _buildSearchBar(),
          Expanded(
            child: filtered.isEmpty
                ? _buildEmpty()
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppTheme.spaceMD, vertical: AppTheme.spaceSM),
                    itemCount: filtered.length,
                    itemBuilder: (_, i) => _buildUserRow(filtered[i]),
                  ),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: AppTheme.surface,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new, size: 20, color: AppTheme.primary),
        onPressed: () => Navigator.pop(context),
      ),
      title: const Text(
        'User Management',
        style: TextStyle(
          color: AppTheme.textPrimary,
          fontSize: 17,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildStatsBar() {
    final users = _service.users;
    final active = users.where((u) => u.isActive).length;
    final avgScore = _service.avgHealthScore;
    final totalTests = users.fold(0, (s, u) => s + u.totalTests);

    return Container(
      margin: const EdgeInsets.all(AppTheme.spaceMD),
      padding: const EdgeInsets.all(AppTheme.spaceMD),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFEFF6FF), Color(0xFFF5F3FF)],
        ),
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        border: Border.all(color: const Color(0xFFDBEAFE)),
      ),
      child: Row(
        children: [
          _miniStat('Total', '${users.length}', const Color(0xFF3B82F6)),
          _divider(),
          _miniStat('Active', '$active', AppTheme.success),
          _divider(),
          _miniStat('Avg Score', '$avgScore%', AppTheme.primary),
          _divider(),
          _miniStat('Tests', '$totalTests', AppTheme.warning),
        ],
      ),
    );
  }

  Widget _miniStat(String label, String value, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(value,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
          Text(label,
              style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
        ],
      ),
    );
  }

  Widget _divider() {
    return Container(height: 32, width: 1, color: const Color(0xFFDBEAFE));
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppTheme.spaceMD, 0, AppTheme.spaceMD, AppTheme.spaceSM),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 42,
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                boxShadow: AppTheme.cardShadow,
              ),
              child: TextField(
                controller: _searchCtrl,
                onChanged: (_) => _refresh(),
                style: const TextStyle(fontSize: 13),
                decoration: const InputDecoration(
                  hintText: 'Search by name, email or location...',
                  hintStyle: TextStyle(fontSize: 12, color: AppTheme.textLight),
                  prefixIcon: Icon(Icons.search, size: 18, color: AppTheme.textLight),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ),
          const SizedBox(width: AppTheme.spaceSM),
          Container(
            height: 42,
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
              boxShadow: AppTheme.cardShadow,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _filter,
                style: const TextStyle(fontSize: 12, color: AppTheme.textPrimary),
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('All')),
                  DropdownMenuItem(value: 'active', child: Text('Active')),
                  DropdownMenuItem(value: 'inactive', child: Text('Inactive')),
                ],
                onChanged: (v) => setState(() => _filter = v!),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserRow(AdminUser user) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.spaceSM),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        children: [
          // Header row
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.spaceMD, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(AppTheme.radiusMedium)),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFDBEAFE), Color(0xFFEDE9FE)],
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Center(
                    child: Text(
                      user.initials,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF4F46E5),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppTheme.spaceSM),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(user.name,
                          style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimary)),
                      Text(user.email,
                          style: const TextStyle(
                              fontSize: 11, color: AppTheme.textSecondary),
                          overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    _service.toggleUserStatus(user.id);
                    _refresh();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: user.isActive
                          ? const Color(0xFFECFDF5)
                          : const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: user.isActive
                            ? AppTheme.success.withOpacity(0.4)
                            : AppTheme.textLight.withOpacity(0.4),
                      ),
                    ),
                    child: Text(
                      user.status,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: user.isActive ? AppTheme.success : AppTheme.textSecondary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Details grid
          Padding(
            padding: const EdgeInsets.all(AppTheme.spaceMD),
            child: Column(
              children: [
                Row(
                  children: [
                    _infoCell(Icons.phone_outlined, 'Phone', user.phone),
                    _infoCell(Icons.location_on_outlined, 'Location', user.location),
                    _infoCell(Icons.person_outline, 'Age / Gender',
                        '${user.age}y • ${user.gender}'),
                  ],
                ),
                const SizedBox(height: AppTheme.spaceSM),
                Row(
                  children: [
                    _infoCell(Icons.access_time_outlined, 'Last Test', user.lastTest),
                    _infoCell(Icons.assignment_outlined, 'Total Tests',
                        '${user.totalTests} tests'),
                    _infoCell(Icons.calendar_today_outlined, 'Joined', user.joinDate),
                  ],
                ),
                const SizedBox(height: AppTheme.spaceSM),

                // Health score bar
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.background,
                    borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.favorite_outline,
                          size: 14, color: AppTheme.textSecondary),
                      const SizedBox(width: 6),
                      const Text('Health Score',
                          style: TextStyle(
                              fontSize: 11, color: AppTheme.textSecondary)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: user.healthScore / 100,
                            backgroundColor: const Color(0xFFE5E7EB),
                            valueColor: AlwaysStoppedAnimation<Color>(
                              user.healthScore >= 80
                                  ? AppTheme.success
                                  : user.healthScore >= 60
                                      ? AppTheme.warning
                                      : AppTheme.error,
                            ),
                            minHeight: 8,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${user.healthScore}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: user.healthScore >= 80
                              ? AppTheme.success
                              : user.healthScore >= 60
                                  ? AppTheme.warning
                                  : AppTheme.error,
                        ),
                      ),
                    ],
                  ),
                ),

                // Actions row
                const SizedBox(height: AppTheme.spaceSM),
                Row(
                  children: [
                    Text(
                      'ID: ${user.id}',
                      style: const TextStyle(
                          fontSize: 10,
                          color: AppTheme.textLight,
                          fontFamily: 'monospace'),
                    ),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: () => _showUserDetail(user),
                      icon: const Icon(Icons.visibility_outlined, size: 14),
                      label: const Text('Details', style: TextStyle(fontSize: 12)),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF3B82F6),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                    const SizedBox(width: 4),
                    TextButton.icon(
                      onPressed: () => _confirmDeleteUser(user),
                      icon: const Icon(Icons.delete_outline, size: 14),
                      label: const Text('Remove', style: TextStyle(fontSize: 12)),
                      style: TextButton.styleFrom(
                        foregroundColor: AppTheme.error,
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoCell(IconData icon, String label, String value) {
    return Expanded(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 13, color: AppTheme.textLight),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(fontSize: 10, color: AppTheme.textLight)),
                Text(value,
                    style: const TextStyle(
                        fontSize: 11,
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w500),
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline, size: 64, color: AppTheme.textLight),
          const SizedBox(height: AppTheme.spaceSM),
          const Text('No users found',
              style: TextStyle(color: AppTheme.textSecondary)),
        ],
      ),
    );
  }

  void _showUserDetail(AdminUser user) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _UserDetailSheet(user: user),
    );
  }

  void _confirmDeleteUser(AdminUser user) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusLarge)),
        title: const Text('Remove User?'),
        content: Text('Remove ${user.name} from the system? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            onPressed: () {
              _service.deleteUser(user.id);
              Navigator.pop(context);
              _refresh();
              _showSnack('${user.name} removed');
            },
            child: const Text('Remove', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ));
  }
}

/// Bottom sheet showing full user details
class _UserDetailSheet extends StatelessWidget {
  final AdminUser user;
  const _UserDetailSheet({required this.user});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppTheme.radiusXL)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
                color: AppTheme.textLight,
                borderRadius: BorderRadius.circular(2)),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppTheme.spaceLG),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Avatar + name
                  Row(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFDBEAFE), Color(0xFFEDE9FE)],
                          ),
                          borderRadius: BorderRadius.circular(28),
                        ),
                        child: Center(
                          child: Text(user.initials,
                              style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF4F46E5))),
                        ),
                      ),
                      const SizedBox(width: AppTheme.spaceMD),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(user.name,
                                style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.textPrimary)),
                            Text(user.email,
                                style: const TextStyle(
                                    fontSize: 13, color: AppTheme.textSecondary)),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: user.isActive
                                    ? const Color(0xFFECFDF5)
                                    : const Color(0xFFF3F4F6),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                user.status,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: user.isActive
                                      ? AppTheme.success
                                      : AppTheme.textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppTheme.spaceLG),

                  // Health score
                  Container(
                    padding: const EdgeInsets.all(AppTheme.spaceMD),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Health Score',
                                style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.textPrimary)),
                            Text(
                              '${user.healthScore}/100 — ${user.healthLabel}',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: user.healthScore >= 80
                                      ? AppTheme.success
                                      : user.healthScore >= 60
                                          ? AppTheme.warning
                                          : AppTheme.error),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: user.healthScore / 100,
                            backgroundColor: Colors.white,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              user.healthScore >= 80
                                  ? AppTheme.success
                                  : user.healthScore >= 60
                                      ? AppTheme.warning
                                      : AppTheme.error,
                            ),
                            minHeight: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppTheme.spaceMD),

                  // Details grid
                  _detailGrid(context),
                  const SizedBox(height: AppTheme.spaceMD),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailGrid(BuildContext context) {
    final items = [
      [Icons.badge_outlined, 'User ID', user.id],
      [Icons.phone_outlined, 'Phone', user.phone],
      [Icons.location_on_outlined, 'Location', user.location],
      [Icons.person_outline, 'Age', '${user.age} years'],
      [Icons.wc_outlined, 'Gender', user.gender],
      [Icons.calendar_today_outlined, 'Joined', user.joinDate],
      [Icons.access_time_outlined, 'Last Test', user.lastTest],
      [Icons.assignment_outlined, 'Total Tests', '${user.totalTests}'],
      [Icons.event_available_outlined, 'Next Appointment', user.nextAppointment],
    ];

    return Wrap(
      spacing: AppTheme.spaceSM,
      runSpacing: AppTheme.spaceSM,
      children: items.map((item) {
        return SizedBox(
          width: (MediaQuery.of(context).size.width - AppTheme.spaceLG * 2 - AppTheme.spaceSM) / 2,
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.background,
              borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(item[0] as IconData, size: 14, color: AppTheme.textLight),
                const SizedBox(width: 6),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item[1] as String,
                          style: const TextStyle(
                              fontSize: 10, color: AppTheme.textLight)),
                      Text(item[2] as String,
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textPrimary),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 2),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
