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
  int _selectedIndex = 0;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      await _service.loadAll();
    } catch (e) {
      _error = e.toString();
    }
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: _buildAppBar(),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primary),
            )
          : _error != null
          ? _buildErrorView()
          : RefreshIndicator(
              color: AppTheme.primary,
              onRefresh: () async {
                await _service.refresh();
                if (mounted) setState(() {});
              },
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
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.cloud_off, size: 56, color: AppTheme.textLight),
          const SizedBox(height: AppTheme.spaceSM),
          const Text(
            'Failed to load data',
            style: TextStyle(color: AppTheme.textSecondary),
          ),
          const SizedBox(height: AppTheme.spaceMD),
          ElevatedButton.icon(
            onPressed: _loadData,
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Retry'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    const titles = ['Admin Dashboard', 'Users', 'Doctors'];
    return AppBar(
      backgroundColor: AppTheme.surface,
      elevation: 0,
      automaticallyImplyLeading: false,
      leading: Padding(
        padding: const EdgeInsets.all(10),
        child: Container(
          decoration: BoxDecoration(
            gradient: AppTheme.primaryGradient,
            borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
          ),
          child: const Icon(
            Icons.admin_panel_settings,
            color: Colors.white,
            size: 20,
          ),
        ),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            titles[_selectedIndex],
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: AppTheme.fontXL,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Text(
            'Administrator',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: AppTheme.fontSM,
            ),
          ),
        ],
      ),
      actions: [
        GestureDetector(
          onTap: _showProfileMenu,
          child: Container(
            margin: const EdgeInsets.symmetric(
              horizontal: AppTheme.spaceSM,
              vertical: AppTheme.spaceSM,
            ),
            child: Container(
              width: 36,
              height: 36,
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
                    fontSize: AppTheme.fontLG,
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
                  'Welcome, Admin',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: AppTheme.fontXXL,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Manage users, doctors & platform health',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: AppTheme.fontSM,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            ),
            child: const Icon(
              Icons.shield_outlined,
              color: Colors.white,
              size: 30,
            ),
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
        color: AppTheme.categoryBlue,
        bgColor: AppTheme.categoryBlueBg,
      ),
      _StatData(
        label: 'Total Doctors',
        value: '${_service.totalDoctors}',
        sub: '${_service.activeDoctors} active',
        icon: Icons.local_hospital_outlined,
        color: AppTheme.success,
        bgColor: AppTheme.categoryGreenBg,
      ),
      _StatData(
        label: 'Active Doctors',
        value: '${_service.activeDoctors}',
        sub: 'On duty',
        icon: Icons.assignment_outlined,
        color: AppTheme.warning,
        bgColor: AppTheme.warningBg,
      ),
      _StatData(
        label: 'Avg Rating',
        value: _service.avgRating.toStringAsFixed(1),
        sub: 'Doctor rating',
        icon: Icons.star_outline,
        color: AppTheme.primary,
        bgColor: AppTheme.categoryIndigoBg,
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
                  fontSize: AppTheme.fontTitle,
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
                  fontSize: AppTheme.fontSM,
                  color: AppTheme.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                s.sub,
                style: TextStyle(fontSize: AppTheme.fontXS, color: s.color),
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
            fontSize: AppTheme.fontLG,
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
                color: AppTheme.categoryBlue,
                bgColor: AppTheme.categoryBlueBg,
                onTap: () => _goToUsers(),
              ),
            ),
            const SizedBox(width: AppTheme.spaceSM),
            Expanded(
              child: _buildNavCard(
                title: 'Manage Doctors',
                subtitle: '${_service.totalDoctors} doctors on-board',
                icon: Icons.local_hospital_outlined,
                color: AppTheme.success,
                bgColor: AppTheme.categoryGreenBg,
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
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(height: AppTheme.spaceSM),
            Text(
              title,
              style: const TextStyle(
                fontSize: AppTheme.fontSM,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(fontSize: AppTheme.fontXS, color: color),
            ),
            const SizedBox(height: AppTheme.spaceSM),
            Row(
              children: [
                Text(
                  'View All',
                  style: TextStyle(
                    fontSize: AppTheme.fontSM,
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
            fontSize: AppTheme.fontLG,
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
                style: TextStyle(
                  fontSize: AppTheme.fontSM,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              GestureDetector(
                onTap: _goToDoctors,
                child: const Text(
                  'See all',
                  style: TextStyle(
                    fontSize: AppTheme.fontXS,
                    color: AppTheme.primary,
                  ),
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
                        colors: [AppTheme.successTint, AppTheme.infoTint],
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Center(
                      child: Text(
                        d.initials,
                        style: const TextStyle(
                          fontSize: AppTheme.fontXS,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.successDark,
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
                          style: const TextStyle(
                            fontSize: AppTheme.fontXS,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          d.specialization,
                          style: const TextStyle(
                            fontSize: AppTheme.fontXS,
                            color: AppTheme.textSecondary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      const Icon(
                        Icons.star,
                        size: 10,
                        color: AppTheme.warningLight,
                      ),
                      Text(
                        d.rating.toString(),
                        style: const TextStyle(
                          fontSize: AppTheme.fontXS,
                          color: AppTheme.textSecondary,
                        ),
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
                style: TextStyle(
                  fontSize: AppTheme.fontSM,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              GestureDetector(
                onTap: _goToUsers,
                child: const Text(
                  'See all',
                  style: TextStyle(
                    fontSize: AppTheme.fontXS,
                    color: AppTheme.primary,
                  ),
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
                        colors: [AppTheme.infoTint, AppTheme.indigoTint],
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Center(
                      child: Text(
                        u.initials,
                        style: const TextStyle(
                          fontSize: AppTheme.fontXS,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primary,
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
                          style: const TextStyle(
                            fontSize: AppTheme.fontXS,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          u.email,
                          style: const TextStyle(
                            fontSize: AppTheme.fontXS,
                            color: AppTheme.textSecondary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSystemStatus() {
    final items = [
      _StatusItem(
        label: 'Verified Doctors',
        value:
            '${_service.doctors.where((d) => d.isVerified).length}/${_service.totalDoctors}',
        color: AppTheme.success,
      ),
      _StatusItem(
        label: 'Available Doctors',
        value:
            '${_service.doctors.where((d) => d.isAvailable).length}/${_service.totalDoctors}',
        color: AppTheme.categoryBlue,
      ),
      _StatusItem(
        label: 'Active Users',
        value: '${_service.activeUsers}/${_service.totalUsers}',
        color: AppTheme.primary,
      ),
      _StatusItem(
        label: 'Avg Rating',
        value: '${_service.avgRating.toStringAsFixed(1)}/5',
        color: AppTheme.warning,
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
            style: TextStyle(
              fontSize: AppTheme.fontBody,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: item.color.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: item.color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            item.value,
                            style: TextStyle(
                              fontSize: AppTheme.fontSM,
                              fontWeight: FontWeight.bold,
                              color: item.color,
                            ),
                          ),
                          Text(
                            item.label,
                            style: const TextStyle(
                              fontSize: AppTheme.fontXS,
                              color: AppTheme.textSecondary,
                            ),
                          ),
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
    setState(() => _selectedIndex = 1);
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AdminUsersPage()),
    ).then((_) {
      if (mounted) setState(() => _selectedIndex = 0);
      _loadData();
    });
  }

  void _goToDoctors() {
    setState(() => _selectedIndex = 2);
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AdminDoctorsPage()),
    ).then((result) {
      if (mounted) setState(() => _selectedIndex = 0);
      _loadData();
      if (result == 'added' && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white, size: 18),
                SizedBox(width: 8),
                Text('Doctor added successfully'),
              ],
            ),
            backgroundColor: AppTheme.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      }
    });
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.spaceMD,
            vertical: AppTheme.spaceSM,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(
                0,
                Icons.dashboard_outlined,
                Icons.dashboard,
                'Home',
              ),
              _buildNavItem(1, Icons.people_outline, Icons.people, 'Users'),
              _buildNavItem(
                2,
                Icons.local_hospital_outlined,
                Icons.local_hospital,
                'Doctors',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(
    int index,
    IconData icon,
    IconData activeIcon,
    String label,
  ) {
    final isSelected = _selectedIndex == index;
    return InkWell(
      onTap: () {
        if (index == 0) setState(() => _selectedIndex = 0);
        if (index == 1) _goToUsers();
        if (index == 2) _goToDoctors();
      },
      borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spaceMD,
          vertical: AppTheme.spaceSM,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primary.withValues(alpha: 0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? activeIcon : icon,
              color: isSelected ? AppTheme.primary : AppTheme.textSecondary,
              size: 22,
            ),
            if (isSelected) ...[
              const SizedBox(width: AppTheme.spaceSM),
              Text(
                label,
                style: const TextStyle(
                  color: AppTheme.primary,
                  fontWeight: FontWeight.w600,
                  fontSize: AppTheme.fontSM,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showProfileMenu() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppTheme.radiusLarge),
        ),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(AppTheme.spaceMD),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.textLight.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: AppTheme.spaceMD),
            Container(
              width: 70,
              height: 70,
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
                    fontSize: AppTheme.fontHeading,
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppTheme.spaceSM),
            const Text(
              'Administrator',
              style: TextStyle(
                fontSize: AppTheme.fontXL,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            const Text(
              'Netra Care Platform',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
            const SizedBox(height: AppTheme.spaceLG),
            ListTile(
              leading: const Icon(
                Icons.settings,
                color: AppTheme.textSecondary,
              ),
              title: const Text('Settings'),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: const Icon(
                Icons.help_outline,
                color: AppTheme.textSecondary,
              ),
              title: const Text('Help & Support'),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: const Icon(Icons.logout, color: AppTheme.error),
              title: const Text(
                'Logout',
                style: TextStyle(color: AppTheme.error),
              ),
              onTap: () {
                Navigator.pop(context);
                _showLogoutDialog();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        ),
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushNamedAndRemoveUntil(
                context,
                '/login',
                (route) => false,
              );
            },
            child: const Text('Logout', style: TextStyle(color: Colors.white)),
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
  const _StatusItem({
    required this.label,
    required this.value,
    required this.color,
  });
}
