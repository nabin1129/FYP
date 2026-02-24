import 'package:flutter/material.dart';
import '../../config/app_theme.dart';
import '../../services/admin_service.dart';
import 'admin_users_page.dart';
import 'admin_doctors_page.dart';

/// Admin Dashboard — Page 1: Overview with stats & quick navigation
class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  final AdminService _service = AdminService();

  @override
  void initState() {
    super.initState();
    _service.initialize();
  }

  void _refresh() => setState(() {});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: _buildAppBar(),
      body: RefreshIndicator(
        color: AppTheme.primary,
        onRefresh: () async => _refresh(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(AppTheme.spaceMD),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildWelcomeBanner(),
              const SizedBox(height: AppTheme.spaceLG),
              _buildStatsGrid(),
              const SizedBox(height: AppTheme.spaceLG),
              _buildQuickNavCards(),
              const SizedBox(height: AppTheme.spaceLG),
              _buildRecentSection(),
              const SizedBox(height: AppTheme.spaceLG),
              _buildSystemStatus(),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: AppTheme.surface,
      elevation: 0,
      automaticallyImplyLeading: false,
      title: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              gradient: AppTheme.primaryGradient,
              borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
            ),
            child: const Icon(Icons.admin_panel_settings, color: Colors.white, size: 20),
          ),
          const SizedBox(width: AppTheme.spaceSM),
          const Text(
            'Admin Panel',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
      actions: [
        Container(
          margin: const EdgeInsets.only(right: AppTheme.spaceMD),
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => _showAdminInfo(context),
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Text(
                  'A',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWelcomeBanner() {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spaceMD),
      decoration: BoxDecoration(
        gradient: AppTheme.primaryGradient,
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        boxShadow: AppTheme.elevatedShadow,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Welcome, Admin 👋',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Manage users, doctors & platform health',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.85),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            ),
            child: const Icon(Icons.shield_outlined, color: Colors.white, size: 30),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid() {
    final stats = [
      _StatData(
        label: 'Total Users',
        value: '${_service.totalUsers}',
        sub: '${_service.activeUsers} active',
        icon: Icons.people_alt_outlined,
        color: const Color(0xFF3B82F6),
        bgColor: const Color(0xFFEFF6FF),
      ),
      _StatData(
        label: 'Total Doctors',
        value: '${_service.totalDoctors}',
        sub: '${_service.activeDoctors} active',
        icon: Icons.local_hospital_outlined,
        color: const Color(0xFF10B981),
        bgColor: const Color(0xFFECFDF5),
      ),
      _StatData(
        label: 'Tests / Month',
        value: '${_service.totalTestsThisMonth}',
        sub: '+15% growth',
        icon: Icons.assignment_outlined,
        color: const Color(0xFFF59E0B),
        bgColor: const Color(0xFFFFFBEB),
      ),
      _StatData(
        label: 'Avg Health',
        value: '${_service.avgHealthScore}%',
        sub: '+2% improve',
        icon: Icons.favorite_outline,
        color: AppTheme.primary,
        bgColor: const Color(0xFFEEF2FF),
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 1.55,
        crossAxisSpacing: AppTheme.spaceSM,
        mainAxisSpacing: AppTheme.spaceSM,
      ),
      itemCount: stats.length,
      itemBuilder: (_, i) => _buildStatCard(stats[i]),
    );
  }

  Widget _buildStatCard(_StatData s) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spaceMD),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: s.bgColor,
                  borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                ),
                child: Icon(s.icon, color: s.color, size: 18),
              ),
              Text(
                s.value,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                s.label,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                s.sub,
                style: TextStyle(fontSize: 11, color: s.color),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickNavCards() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick Access',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: AppTheme.spaceSM),
        Row(
          children: [
            Expanded(
              child: _buildNavCard(
                title: 'Manage Users',
                subtitle: '${_service.totalUsers} patients registered',
                icon: Icons.people_alt_outlined,
                color: const Color(0xFF3B82F6),
                bgColor: const Color(0xFFEFF6FF),
                onTap: () => _goToUsers(),
              ),
            ),
            const SizedBox(width: AppTheme.spaceSM),
            Expanded(
              child: _buildNavCard(
                title: 'Manage Doctors',
                subtitle: '${_service.totalDoctors} doctors on-board',
                icon: Icons.local_hospital_outlined,
                color: const Color(0xFF10B981),
                bgColor: const Color(0xFFECFDF5),
                onTap: () => _goToDoctors(),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildNavCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required Color bgColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppTheme.spaceMD),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(height: AppTheme.spaceSM),
            Text(
              title,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(fontSize: 11, color: color),
            ),
            const SizedBox(height: AppTheme.spaceSM),
            Row(
              children: [
                Text(
                  'View All',
                  style: TextStyle(
                    fontSize: 12,
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 2),
                Icon(Icons.arrow_forward_ios, size: 10, color: color),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Recent Activity',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: AppTheme.spaceSM),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _buildRecentDoctors()),
            const SizedBox(width: AppTheme.spaceSM),
            Expanded(child: _buildRecentUsers()),
          ],
        ),
      ],
    );
  }

  Widget _buildRecentDoctors() {
    final recent = _service.doctors.take(3).toList();
    return Container(
      padding: const EdgeInsets.all(AppTheme.spaceMD),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Doctors',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
              ),
              GestureDetector(
                onTap: _goToDoctors,
                child: const Text(
                  'See all',
                  style: TextStyle(fontSize: 11, color: AppTheme.primary),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spaceSM),
          ...recent.map(
            (d) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFD1FAE5), Color(0xFFDBEAFE)],
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Center(
                      child: Text(
                        d.initials,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF059669),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          d.name.replaceFirst('Dr. ', ''),
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          d.specialization,
                          style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      const Icon(Icons.star, size: 10, color: Color(0xFFFBBF24)),
                      Text(
                        d.rating.toString(),
                        style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentUsers() {
    final recent = _service.users.take(3).toList();
    return Container(
      padding: const EdgeInsets.all(AppTheme.spaceMD),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Users',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
              ),
              GestureDetector(
                onTap: _goToUsers,
                child: const Text(
                  'See all',
                  style: TextStyle(fontSize: 11, color: AppTheme.primary),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spaceSM),
          ...recent.map(
            (u) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFDBEAFE), Color(0xFFEDE9FE)],
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Center(
                      child: Text(
                        u.initials,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF4F46E5),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          u.name,
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          u.location,
                          style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  _buildHealthBadge(u.healthScore),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHealthBadge(int score) {
    Color color;
    Color bgColor;
    if (score >= 80) {
      color = AppTheme.success;
      bgColor = const Color(0xFFECFDF5);
    } else if (score >= 60) {
      color = AppTheme.warning;
      bgColor = const Color(0xFFFFFBEB);
    } else {
      color = AppTheme.error;
      bgColor = const Color(0xFFFEF2F2);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        score.toString(),
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color),
      ),
    );
  }

  Widget _buildSystemStatus() {
    final items = [
      _StatusItem(
        label: 'Verified Doctors',
        value: '${_service.doctors.where((d) => d.isVerified).length}/${_service.totalDoctors}',
        color: const Color(0xFF10B981),
      ),
      _StatusItem(
        label: 'Available Doctors',
        value: '${_service.doctors.where((d) => d.isAvailable).length}/${_service.totalDoctors}',
        color: const Color(0xFF3B82F6),
      ),
      _StatusItem(
        label: 'Active Users',
        value: '${_service.activeUsers}/${_service.totalUsers}',
        color: AppTheme.primary,
      ),
      _StatusItem(
        label: 'Avg Rating',
        value: '${_service.avgRating.toStringAsFixed(1)}/5',
        color: const Color(0xFFF59E0B),
      ),
    ];

    return Container(
      padding: const EdgeInsets.all(AppTheme.spaceMD),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'System Status',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
          ),
          const SizedBox(height: AppTheme.spaceSM),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 2.8,
              crossAxisSpacing: AppTheme.spaceSM,
              mainAxisSpacing: AppTheme.spaceSM,
            ),
            itemCount: items.length,
            itemBuilder: (_, i) {
              final item = items[i];
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: item.color.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(color: item.color, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(item.value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: item.color)),
                          Text(item.label, style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  void _goToUsers() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AdminUsersPage()),
    ).then((_) => _refresh());
  }

  void _goToDoctors() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AdminDoctorsPage()),
    ).then((_) => _refresh());
  }

  void _showAdminInfo(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusLarge)),
        title: const Text('Admin Account'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Text('A', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: AppTheme.spaceSM),
            const Text('Administrator', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 4),
            const Text('Netra Care Platform', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
            },
            child: const Text('Logout', style: TextStyle(color: AppTheme.error)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
            onPressed: () => Navigator.pop(context),
            child: const Text('Close', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

class _StatData {
  final String label;
  final String value;
  final String sub;
  final IconData icon;
  final Color color;
  final Color bgColor;
  const _StatData({
    required this.label,
    required this.value,
    required this.sub,
    required this.icon,
    required this.color,
    required this.bgColor,
  });
}

class _StatusItem {
  final String label;
  final String value;
  final Color color;
  const _StatusItem({required this.label, required this.value, required this.color});
}
