import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../config/app_theme.dart';
import '../../services/doctor_service.dart';
import '../../models/doctor/doctor_analytics_model.dart';
import '../../models/doctor/patient_model.dart';

/// Doctor Home Page - Analytics and Statistics
class DoctorHomePage extends StatefulWidget {
  const DoctorHomePage({super.key});

  @override
  State<DoctorHomePage> createState() => _DoctorHomePageState();
}

class _DoctorHomePageState extends State<DoctorHomePage> {
  final DoctorService _doctorService = DoctorService();
  late DoctorAnalytics _analytics;
  late List<Patient> _recentPatients;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    setState(() {
      _analytics = _doctorService.getAnalytics();
      _recentPatients = _doctorService.getAllPatients().take(5).toList();
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: () async => _loadData(),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppTheme.spaceMD),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildWelcomeHeader(),
            const SizedBox(height: AppTheme.spaceLG),
            _buildStatCards(),
            const SizedBox(height: AppTheme.spaceLG),
            _buildChartsSection(),
            const SizedBox(height: AppTheme.spaceLG),
            _buildTestStatistics(),
            const SizedBox(height: AppTheme.spaceLG),
            _buildRecentPatients(),
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeHeader() {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spaceMD),
      decoration: BoxDecoration(
        gradient: AppTheme.primaryGradient,
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
      ),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            ),
            child: const Icon(
              Icons.medical_services,
              color: Colors.white,
              size: 32,
            ),
          ),
          const SizedBox(width: AppTheme.spaceMD),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Welcome Back, Doctor!',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Manage your patients and view analytics',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCards() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _StatCard(
                icon: Icons.people,
                iconColor: AppTheme.primary,
                iconBgColor: AppTheme.testIconBackground,
                value: '${_analytics.totalPatients}',
                label: 'Total Patients',
                subtitle: '+${_analytics.newPatientsThisMonth} this month',
                subtitleColor: AppTheme.success,
              ),
            ),
            const SizedBox(width: AppTheme.spaceMD),
            Expanded(
              child: _StatCard(
                icon: Icons.insights,
                iconColor: AppTheme.success,
                iconBgColor: AppTheme.success.withOpacity(0.1),
                value: '${_analytics.averageHealthScore.round()}',
                label: 'Avg Health Score',
                subtitle: '+${_analytics.healthScoreChange}% from last month',
                subtitleColor: AppTheme.success,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppTheme.spaceMD),
        Row(
          children: [
            Expanded(
              child: _StatCard(
                icon: Icons.calendar_today,
                iconColor: AppTheme.warning,
                iconBgColor: AppTheme.warning.withOpacity(0.1),
                value: '${_analytics.testsThisWeek}',
                label: 'Tests This Week',
                subtitle: '${_analytics.pendingReviews} pending reviews',
                subtitleColor: AppTheme.warning,
              ),
            ),
            const SizedBox(width: AppTheme.spaceMD),
            Expanded(
              child: _StatCard(
                icon: Icons.priority_high,
                iconColor: AppTheme.error,
                iconBgColor: AppTheme.error.withOpacity(0.1),
                value: '${_analytics.distribution.critical}',
                label: 'Critical Patients',
                subtitle: 'Need immediate attention',
                subtitleColor: AppTheme.error,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildChartsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Analytics Overview',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: AppTheme.spaceMD),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _buildHealthTrendChart()),
            const SizedBox(width: AppTheme.spaceMD),
            Expanded(child: _buildDistributionChart()),
          ],
        ),
      ],
    );
  }

  Widget _buildHealthTrendChart() {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spaceMD),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Health Score Trend',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: AppTheme.spaceMD),
          SizedBox(
            height: 180,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 10,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: AppTheme.textLight.withOpacity(0.2),
                      strokeWidth: 1,
                    );
                  },
                ),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      interval: 10,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          value.toInt().toString(),
                          style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 10,
                          ),
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final idx = value.toInt();
                        if (idx >= 0 && idx < _analytics.healthTrend.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              _analytics.healthTrend[idx].month,
                              style: const TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 10,
                              ),
                            ),
                          );
                        }
                        return const Text('');
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                borderData: FlBorderData(show: false),
                minY: 60,
                maxY: 100,
                lineBarsData: [
                  LineChartBarData(
                    spots: _analytics.healthTrend.asMap().entries.map((e) {
                      return FlSpot(e.key.toDouble(), e.value.avgScore);
                    }).toList(),
                    isCurved: true,
                    color: AppTheme.primary,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) {
                        return FlDotCirclePainter(
                          radius: 4,
                          color: AppTheme.primary,
                          strokeWidth: 2,
                          strokeColor: Colors.white,
                        );
                      },
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      color: AppTheme.primary.withOpacity(0.1),
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

  Widget _buildDistributionChart() {
    final distribution = _analytics.distribution;
    
    return Container(
      padding: const EdgeInsets.all(AppTheme.spaceMD),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Patient Distribution',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: AppTheme.spaceMD),
          SizedBox(
            height: 140,
            child: PieChart(
              PieChartData(
                sectionsSpace: 2,
                centerSpaceRadius: 30,
                sections: [
                  PieChartSectionData(
                    value: distribution.good.toDouble(),
                    color: AppTheme.success,
                    title: '${distribution.good}',
                    radius: 40,
                    titleStyle: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  PieChartSectionData(
                    value: distribution.attention.toDouble(),
                    color: AppTheme.warning,
                    title: '${distribution.attention}',
                    radius: 40,
                    titleStyle: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  PieChartSectionData(
                    value: distribution.critical.toDouble(),
                    color: AppTheme.error,
                    title: '${distribution.critical}',
                    radius: 40,
                    titleStyle: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppTheme.spaceSM),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildLegendItem('Good', AppTheme.success),
              _buildLegendItem('Attention', AppTheme.warning),
              _buildLegendItem('Critical', AppTheme.error),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            color: AppTheme.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildTestStatistics() {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spaceMD),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Test Statistics',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: AppTheme.spaceMD),
          ..._analytics.testStats.map((stat) => _buildTestStatRow(stat)),
        ],
      ),
    );
  }

  Widget _buildTestStatRow(TestTypeStats stat) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.spaceSM),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppTheme.testIconBackground,
              borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
            ),
            child: const Icon(
              Icons.visibility,
              color: AppTheme.testIconColor,
              size: 20,
            ),
          ),
          const SizedBox(width: AppTheme.spaceMD),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  stat.testType,
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textPrimary,
                  ),
                ),
                Text(
                  '${stat.count} tests completed',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.spaceSM,
              vertical: 4,
            ),
            decoration: BoxDecoration(
              color: _getScoreColor(stat.avgScore).withOpacity(0.1),
              borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
            ),
            child: Text(
              'Avg: ${stat.avgScore.round()}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: _getScoreColor(stat.avgScore),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getScoreColor(double score) {
    if (score >= 80) return AppTheme.success;
    if (score >= 60) return AppTheme.warning;
    return AppTheme.error;
  }

  Widget _buildRecentPatients() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Recent Patients',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            TextButton(
              onPressed: () {
                // Navigate to patients tab
              },
              child: const Text('View All'),
            ),
          ],
        ),
        const SizedBox(height: AppTheme.spaceSM),
        Container(
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
            boxShadow: AppTheme.cardShadow,
          ),
          child: Column(
            children: _recentPatients.map((patient) {
              final isLast = patient == _recentPatients.last;
              return _buildPatientRow(patient, isLast);
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildPatientRow(Patient patient, bool isLast) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spaceMD),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : Border(
                bottom: BorderSide(
                  color: AppTheme.textLight.withOpacity(0.2),
                ),
              ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: AppTheme.testIconBackground,
            child: Text(
              patient.initials,
              style: const TextStyle(
                color: AppTheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: AppTheme.spaceMD),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  patient.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                Text(
                  'Last test: ${patient.lastTestAgo}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Row(
            children: [
              Text(
                '${patient.healthScore}',
                style: const TextStyle(
                  fontSize: 18,
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
          const SizedBox(width: AppTheme.spaceSM),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.spaceSM,
              vertical: 4,
            ),
            decoration: BoxDecoration(
              color: _getStatusColor(patient.status).withOpacity(0.1),
              borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
            ),
            child: Text(
              patient.status.label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: _getStatusColor(patient.status),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(HealthStatus status) {
    switch (status) {
      case HealthStatus.good:
        return AppTheme.success;
      case HealthStatus.attention:
        return AppTheme.warning;
      case HealthStatus.critical:
        return AppTheme.error;
    }
  }
}

/// Reusable Stat Card Widget
class _StatCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBgColor;
  final String value;
  final String label;
  final String subtitle;
  final Color subtitleColor;

  const _StatCard({
    required this.icon,
    required this.iconColor,
    required this.iconBgColor,
    required this.value,
    required this.label,
    required this.subtitle,
    required this.subtitleColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spaceMD),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: iconBgColor,
                  borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spaceSM),
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 11,
              color: subtitleColor,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
