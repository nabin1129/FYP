import 'package:flutter/material.dart';
import '../../config/app_theme.dart';
import '../../services/doctor_service.dart';
import '../../services/notification_service.dart';
import '../../widgets/notification/notification_bell.dart';
import 'doctor_home_page.dart';
import 'doctor_patients_page.dart';
import 'doctor_consultations_page.dart';

/// Main Doctor Dashboard with Bottom Navigation
class DoctorDashboardPage extends StatefulWidget {
  const DoctorDashboardPage({super.key});

  @override
  State<DoctorDashboardPage> createState() => _DoctorDashboardPageState();
}

class _DoctorDashboardPageState extends State<DoctorDashboardPage> {
  int _selectedIndex = 0;
  final DoctorService _doctorService = DoctorService();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeAsync();
  }

  Future<void> _initializeAsync() async {
    setState(() => _isLoading = true);

    // Initialize doctor service with API data
    await _doctorService.initializeAsync();

    // Initialize notification polling for doctor role
    NotificationService().setRole(NotificationRole.doctor);
    NotificationService().initialize();

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  final List<Widget> _pages = const [
    DoctorHomePage(),
    DoctorPatientsPage(),
    DoctorConsultationsPage(),
  ];

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppTheme.background,
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: AppTheme.primary),
              SizedBox(height: AppTheme.spaceMD),
              Text(
                'Loading dashboard...',
                style: TextStyle(color: AppTheme.textSecondary),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: _buildAppBar(),
      body: IndexedStack(index: _selectedIndex, children: _pages),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    String title;
    List<Widget> actions = [];

    switch (_selectedIndex) {
      case 0:
        title = 'Doctor Dashboard';
        actions = [const NotificationBell()];
        break;
      case 1:
        title = 'Patients';
        actions = [
          IconButton(
            icon: const Icon(Icons.sort),
            onPressed: () => _showSortOptions(),
          ),
        ];
        break;
      case 2:
        title = 'Consultations';
        break;
      default:
        title = 'Netra Care';
    }

    return AppBar(
      backgroundColor: AppTheme.surface,
      elevation: 0,
      leading: Padding(
        padding: const EdgeInsets.all(10),
        child: Container(
          decoration: BoxDecoration(
            color: AppTheme.testIconBackground,
            borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
          ),
          child: const Icon(
            Icons.medical_services,
            color: AppTheme.primary,
            size: 20,
          ),
        ),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: AppTheme.fontXL,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Text(
            'Dr. Rajesh Kumar Shrestha',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: AppTheme.fontSM,
            ),
          ),
        ],
      ),
      actions: [
        ...actions,
        GestureDetector(
          onTap: () => _showProfileMenu(),
          child: Container(
            margin: const EdgeInsets.symmetric(
              horizontal: AppTheme.spaceSM,
              vertical: AppTheme.spaceSM,
            ),
            child: const CircleAvatar(
              radius: 18,
              backgroundColor: AppTheme.testIconBackground,
              child: Icon(Icons.person, color: AppTheme.primary, size: 20),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
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
              _buildNavItem(1, Icons.people_outline, Icons.people, 'Patients'),
              _buildNavItem(
                2,
                Icons.chat_bubble_outline,
                Icons.chat_bubble,
                'Consult',
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
      onTap: () => setState(() => _selectedIndex = index),
      borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spaceMD,
          vertical: AppTheme.spaceSM,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primary.withOpacity(0.1)
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

  void _showSortOptions() {
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Sort Patients By',
              style: TextStyle(
                fontSize: AppTheme.fontXL,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppTheme.spaceMD),
            ListTile(
              leading: const Icon(Icons.sort_by_alpha, color: AppTheme.primary),
              title: const Text('Name (A-Z)'),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: const Icon(Icons.trending_down, color: AppTheme.error),
              title: const Text('Health Score (Low to High)'),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: const Icon(Icons.trending_up, color: AppTheme.success),
              title: const Text('Health Score (High to Low)'),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: const Icon(Icons.access_time, color: AppTheme.warning),
              title: const Text('Last Test Date'),
              onTap: () => Navigator.pop(context),
            ),
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
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                color: AppTheme.testIconBackground,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.person,
                color: AppTheme.primary,
                size: 36,
              ),
            ),
            const SizedBox(height: AppTheme.spaceMD),
            const Text(
              'Dr. Rajesh Kumar Shrestha',
              style: TextStyle(
                fontSize: AppTheme.fontXL,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            const Text(
              'Ophthalmologist',
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
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushNamedAndRemoveUntil(
                context,
                '/login',
                (route) => false,
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }
}
