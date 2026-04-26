import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:netracare/config/app_theme.dart';
import 'package:netracare/features/shared/widgets/shared_widgets.dart';
import 'package:netracare/services/doctor_service.dart';
import 'package:netracare/models/doctor/doctor_analytics_model.dart';
import 'package:netracare/models/doctor/patient_model.dart';

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
    _loadDataAsync();
  }

  Future<void> _loadDataAsync() async {
    setState(() => _isLoading = true);

    try {
      final analytics = await _doctorService.getAnalyticsAsync();
      final patients = await _doctorService.getPatientsAsync();

      if (mounted) {
        setState(() {
          _analytics = analytics;
          _recentPatients = patients.take(5).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _analytics = DoctorAnalytics.empty();
          _recentPatients = [];
          _isLoading = false;
        });
      }
    }
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
      onRefresh: _loadDataAsync,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppTheme.spaceMD),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildWelcomeHeader(),
            const SizedBox(height: AppTheme.spaceLG),
            _buildStatCards(),
            if (_analytics.healthTrend.isNotEmpty) ...[
              const SizedBox(height: AppTheme.spaceLG),
              _buildChartsSection(),
            ],
            if (_analytics.testStats.isNotEmpty) ...[
              const SizedBox(height: AppTheme.spaceLG),
              _buildTestStatistics(),
            ],
            const SizedBox(height: AppTheme.spaceLG),
            _buildRecentPatients(),
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeHeader() {
    final colors = context.appColors;

    return AppContainer(
      padding: const EdgeInsets.all(AppTheme.spaceMD),
      gradient: colors.primaryGradient,
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
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
                Text(
                  'Welcome Back, ${_doctorService.doctorName}!',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: AppTheme.fontXXL,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Manage your patients and view analytics',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: AppTheme.fontBody,
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
                iconBgColor: AppTheme.success.withValues(alpha: 0.1),
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
                iconBgColor: AppTheme.warning.withValues(alpha: 0.1),
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
                iconBgColor: AppTheme.error.withValues(alpha: 0.1),
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
          AppText(
            'Analytics Overview',
            role: AppTextRole.subtitle,
            fontWeight: FontWeight.bold,
          ),
        const SizedBox(height: AppTheme.spaceMD),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () => _showFullScreenChart(
                  'Health Score Trend',
                  _buildHealthTrendChartContent(isFullScreen: true),
                ),
                child: _buildHealthTrendChart(),
              ),
            ),
            const SizedBox(width: AppTheme.spaceMD),
            Expanded(
              child: GestureDetector(
                onTap: () => _showFullScreenChart(
                  'Patient Distribution',
                  _buildDistributionChartContent(isFullScreen: true),
                ),
                child: _buildDistributionChart(),
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _showFullScreenChart(String title, Widget chartContent) {
    final colors = context.appColors;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: colors.background,
          appBar: AppBar(
            backgroundColor: colors.surface,
            elevation: 0,
            leading: IconButton(
              icon: Icon(Icons.close, color: colors.textPrimary),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(
              title,
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: AppTheme.fontXL,
                fontWeight: FontWeight.bold,
              ),
            ),
            centerTitle: true,
          ),
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(AppTheme.spaceMD),
              child: Center(child: chartContent),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHealthTrendChartContent({bool isFullScreen = false}) {
    final chartHeight = isFullScreen ? 400.0 : 180.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isFullScreen) ...[
          const Text(
            'Monthly average health scores of your patients',
            style: TextStyle(
              fontSize: AppTheme.fontBody,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: AppTheme.spaceLG),
        ],
        SizedBox(
          height: chartHeight,
          child: LineChart(
            LineChartData(
              gridData: FlGridData(
                show: true,
                drawVerticalLine: isFullScreen,
                horizontalInterval: 10,
                getDrawingHorizontalLine: (value) {
                  return FlLine(
                    color: AppTheme.textLight.withValues(alpha: 0.2),
                    strokeWidth: 1,
                  );
                },
              ),
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: isFullScreen ? 40 : 30,
                    interval: 10,
                    getTitlesWidget: (value, meta) {
                      return Text(
                        value.toInt().toString(),
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: isFullScreen ? 12 : 10,
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
                            style: TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: isFullScreen ? 12 : 10,
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
                  barWidth: isFullScreen ? 4 : 3,
                  isStrokeCapRound: true,
                  dotData: FlDotData(
                    show: true,
                    getDotPainter: (spot, percent, barData, index) {
                      return FlDotCirclePainter(
                        radius: isFullScreen ? 6 : 4,
                        color: AppTheme.primary,
                        strokeWidth: 2,
                        strokeColor: Colors.white,
                      );
                    },
                  ),
                  belowBarData: BarAreaData(
                    show: true,
                    color: AppTheme.primary.withValues(alpha: 0.1),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (isFullScreen) ...[
          const SizedBox(height: AppTheme.spaceLG),
          _buildTrendLegend(),
        ],
      ],
    );
  }

  Widget _buildTrendLegend() {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spaceMD),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        border: Border.all(color: AppTheme.textLight.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Monthly Breakdown',
            style: TextStyle(
              fontSize: AppTheme.fontBody,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: AppTheme.spaceSM),
          ..._analytics.healthTrend.map(
            (item) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    item.month,
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: AppTheme.fontSM,
                    ),
                  ),
                  Text(
                    '${item.avgScore.toStringAsFixed(1)}%',
                    style: const TextStyle(
                      color: AppTheme.primary,
                      fontWeight: FontWeight.w600,
                      fontSize: AppTheme.fontSM,
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

  Widget _buildDistributionChartContent({bool isFullScreen = false}) {
    final distribution = _analytics.distribution;
    final chartSize = isFullScreen ? 250.0 : 140.0;
    final radius = isFullScreen ? 60.0 : 40.0;
    final centerRadius = isFullScreen ? 50.0 : 30.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isFullScreen) ...[
          const Text(
            'Distribution of patients by health status',
            style: TextStyle(
              fontSize: AppTheme.fontBody,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: AppTheme.spaceLG),
        ],
        SizedBox(
          height: chartSize,
          child: PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: centerRadius,
              sections: [
                PieChartSectionData(
                  value: distribution.good.toDouble(),
                  color: AppTheme.success,
                  title: '${distribution.good}',
                  radius: radius,
                  titleStyle: TextStyle(
                    fontSize: isFullScreen ? 16 : 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                PieChartSectionData(
                  value: distribution.attention.toDouble(),
                  color: AppTheme.warning,
                  title: '${distribution.attention}',
                  radius: radius,
                  titleStyle: TextStyle(
                    fontSize: isFullScreen ? 16 : 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                PieChartSectionData(
                  value: distribution.critical.toDouble(),
                  color: AppTheme.error,
                  title: '${distribution.critical}',
                  radius: radius,
                  titleStyle: TextStyle(
                    fontSize: isFullScreen ? 16 : 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppTheme.spaceMD),
        if (isFullScreen)
          _buildDistributionDetails(distribution)
        else
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildLegendItem('Good', AppTheme.success),
                const SizedBox(width: 8),
                _buildLegendItem('Attention', AppTheme.warning),
                const SizedBox(width: 8),
                _buildLegendItem('Critical', AppTheme.error),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildDistributionDetails(PatientDistribution distribution) {
    final total =
        distribution.good + distribution.attention + distribution.critical;

    return Container(
      padding: const EdgeInsets.all(AppTheme.spaceMD),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        border: Border.all(color: AppTheme.textLight.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          _buildDistributionRow(
            'Good Health',
            distribution.good,
            total,
            AppTheme.success,
          ),
          const Divider(height: AppTheme.spaceMD),
          _buildDistributionRow(
            'Needs Attention',
            distribution.attention,
            total,
            AppTheme.warning,
          ),
          const Divider(height: AppTheme.spaceMD),
          _buildDistributionRow(
            'Critical',
            distribution.critical,
            total,
            AppTheme.error,
          ),
        ],
      ),
    );
  }

  Widget _buildDistributionRow(
    String label,
    int count,
    int total,
    Color color,
  ) {
    final percentage = total > 0
        ? (count / total * 100).toStringAsFixed(1)
        : '0';

    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: AppTheme.spaceSM),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: AppTheme.fontBody,
              color: AppTheme.textPrimary,
            ),
          ),
        ),
        Text(
          '$count patients',
          style: const TextStyle(
            fontSize: AppTheme.fontBody,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(width: AppTheme.spaceSM),
        Text(
          '($percentage%)',
          style: const TextStyle(
            fontSize: AppTheme.fontSM,
            color: AppTheme.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildHealthTrendChart() {
    final colors = context.appColors;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              AppText(
                'Health Score Trend',
                fontWeight: FontWeight.w600,
              ),
              Icon(Icons.fullscreen, size: 18, color: colors.textSecondary),
            ],
          ),
          const SizedBox(height: AppTheme.spaceMD),
          _buildHealthTrendChartContent(),
        ],
      ),
    );
  }

  Widget _buildDistributionChart() {
    final colors = context.appColors;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              AppText(
                'Patient Distribution',
                fontWeight: FontWeight.w600,
              ),
              Icon(Icons.fullscreen, size: 18, color: colors.textSecondary),
            ],
          ),
          const SizedBox(height: AppTheme.spaceMD),
          _buildDistributionChartContent(),
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
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: AppTheme.fontXS,
            color: AppTheme.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildTestStatistics() {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AppText(
            'Test Statistics',
            role: AppTextRole.subtitle,
            fontWeight: FontWeight.bold,
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
                    fontSize: AppTheme.fontSM,
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
              color: _getScoreColor(stat.avgScore).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
            ),
            child: Text(
              'Avg: ${stat.avgScore.round()}',
              style: TextStyle(
                fontSize: AppTheme.fontSM,
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
    final colors = context.appColors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const AppText(
              'Recent Patients',
              role: AppTextRole.subtitle,
              fontWeight: FontWeight.bold,
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
        AppCard(
          padding: EdgeInsets.zero,
          border: Border.all(color: colors.border.withValues(alpha: 0.7)),
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
                  color: AppTheme.textLight.withValues(alpha: 0.2),
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
                    fontSize: AppTheme.fontSM,
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
                  fontSize: AppTheme.fontXL,
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
              color: _getStatusColor(patient.status).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
            ),
            child: Text(
              patient.status.label,
              style: TextStyle(
                fontSize: AppTheme.fontXS,
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
    final colors = context.appColors;

    return AppCard(
      border: Border.all(color: colors.border.withValues(alpha: 0.7)),
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
                style: TextStyle(
                  fontSize: AppTheme.fontHeading,
                  fontWeight: FontWeight.bold,
                  color: colors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spaceSM),
          Text(
            label,
            style: TextStyle(
              fontSize: AppTheme.fontSM,
              color: colors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: AppTheme.fontXS,
              color: subtitleColor,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
