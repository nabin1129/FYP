import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../config/app_theme.dart';
import '../../services/admin_service.dart';

class AdminAnalyticsPage extends StatefulWidget {
  const AdminAnalyticsPage({super.key});

  @override
  State<AdminAnalyticsPage> createState() => _AdminAnalyticsPageState();
}

class _AdminAnalyticsPageState extends State<AdminAnalyticsPage> {
  final AdminService _service = AdminService();
  Map<String, dynamic> _analytics = {};
  bool _loading = true;
  String? _error;
  int _days = 30;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await _service.loadAnalytics(days: _days);
      if (!mounted) return;
      setState(() => _analytics = data);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        elevation: 0,
        title: const Text(
          'Analytics Overview',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              value: _days,
              items: const [
                DropdownMenuItem(value: 7, child: Text('7d')),
                DropdownMenuItem(value: 30, child: Text('30d')),
                DropdownMenuItem(value: 90, child: Text('90d')),
              ],
              onChanged: (v) {
                if (v == null) return;
                setState(() => _days = v);
                _load();
              },
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: AppTheme.textSecondary),
            onPressed: _load,
          ),
        ],
      ),
      body: SafeArea(
        child: _loading
            ? const Center(
                child: CircularProgressIndicator(color: AppTheme.primary),
              )
            : _error != null
            ? _buildError()
            : RefreshIndicator(
                color: AppTheme.primary,
                onRefresh: _load,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(AppTheme.spaceMD),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeadlineCards(),
                      const SizedBox(height: AppTheme.spaceLG),
                      _buildSectionTitle('Test Counts (last $_days days)'),
                      const SizedBox(height: AppTheme.spaceSM),
                      _buildTestGrid(),
                      const SizedBox(height: AppTheme.spaceLG),
                      _buildSectionTitle('Test Mix'),
                      const SizedBox(height: AppTheme.spaceSM),
                      _buildTestMixPie(),
                      const SizedBox(height: AppTheme.spaceLG),
                      _buildSectionTitle('Age Distribution'),
                      const SizedBox(height: AppTheme.spaceSM),
                      _buildAgeChart(),
                      const SizedBox(height: AppTheme.spaceLG),
                      _buildSectionTitle('Usage (last $_days days)'),
                      const SizedBox(height: AppTheme.spaceSM),
                      _buildUsageChart(),
                      const SizedBox(height: AppTheme.spaceLG),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildAgeChart() {
    final demographics =
        _analytics['demographics'] as Map<String, dynamic>? ?? {};
    final ages = demographics['age_buckets'] as Map<String, dynamic>? ?? {};
    final buckets = <String, int>{
      '<18': ages['under_18'] as int? ?? 0,
      '18-29': ages['18_to_29'] as int? ?? 0,
      '30-44': ages['30_to_44'] as int? ?? 0,
      '45-59': ages['45_to_59'] as int? ?? 0,
      '60+': ages['60_plus'] as int? ?? 0,
      'Unknown': ages['unknown'] as int? ?? 0,
    };

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
            'Age Buckets',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: AppTheme.spaceSM),
          SizedBox(
            height: 200,
            child: BarChart(
              BarChartData(
                barGroups: [
                  for (final entry in buckets.entries)
                    BarChartGroupData(
                      x: buckets.keys.toList().indexOf(entry.key),
                      barRods: [
                        BarChartRodData(
                          toY: entry.value.toDouble(),
                          color: AppTheme.primary,
                          width: 18,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ],
                      showingTooltipIndicators: const [0],
                    ),
                ],
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final idx = value.toInt();
                        final label = buckets.keys.elementAt(idx);
                        return Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                            label,
                            style: const TextStyle(fontSize: AppTheme.fontXS),
                          ),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: true, reservedSize: 32),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                gridData: FlGridData(show: true, drawVerticalLine: false),
                borderData: FlBorderData(show: false),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: AppTheme.error),
          const SizedBox(height: 12),
          Text(_error ?? 'Failed to load analytics'),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: _load,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: AppTheme.fontLG,
        fontWeight: FontWeight.bold,
        color: AppTheme.textPrimary,
      ),
    );
  }

  Widget _buildHeadlineCards() {
    final totalUsers = _analytics['total_users'] as int? ?? 0;
    final usage = _analytics['usage'] as Map<String, dynamic>? ?? {};
    final totalTests =
        (usage['eye_tracking_tests'] as int? ?? 0) +
        (usage['visual_acuity_tests'] as int? ?? 0) +
        (usage['colour_vision_tests'] as int? ?? 0) +
        (usage['blink_fatigue_tests'] as int? ?? 0) +
        (usage['pupil_reflex_tests'] as int? ?? 0);

    return Row(
      children: [
        _metricCard(
          label: 'Total Users',
          value: '$totalUsers',
          icon: Icons.people_alt_outlined,
          color: AppTheme.categoryBlue,
        ),
        const SizedBox(width: AppTheme.spaceSM),
        _metricCard(
          label: 'Tests in $_days d',
          value: '$totalTests',
          icon: Icons.analytics_outlined,
          color: AppTheme.primary,
        ),
      ],
    );
  }

  Widget _metricCard({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(AppTheme.spaceMD),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          boxShadow: AppTheme.cardShadow,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: AppTheme.spaceSM),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: AppTheme.fontTitle,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                Text(
                  label,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: AppTheme.fontSM,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTestGrid() {
    final usage = _analytics['usage'] as Map<String, dynamic>? ?? {};
    final items = [
      _TestTile(
        'Eye Tracking',
        usage['eye_tracking_tests'] as int? ?? 0,
        AppTheme.primary,
      ),
      _TestTile(
        'Visual Acuity',
        usage['visual_acuity_tests'] as int? ?? 0,
        AppTheme.categoryBlue,
      ),
      _TestTile(
        'Colour Vision',
        usage['colour_vision_tests'] as int? ?? 0,
        AppTheme.success,
      ),
      _TestTile(
        'Blink & Fatigue',
        usage['blink_fatigue_tests'] as int? ?? 0,
        AppTheme.warning,
      ),
      _TestTile(
        'Pupil Reflex',
        usage['pupil_reflex_tests'] as int? ?? 0,
        AppTheme.categoryIndigo,
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 2.1,
        crossAxisSpacing: AppTheme.spaceSM,
        mainAxisSpacing: AppTheme.spaceSM,
      ),
      itemCount: items.length,
      itemBuilder: (_, i) => _buildTestCard(items[i]),
    );
  }

  Widget _buildTestCard(_TestTile t) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: t.color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
            ),
            child: Icon(Icons.visibility_outlined, color: t.color),
          ),
          const SizedBox(width: AppTheme.spaceSM),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${t.count}',
                style: TextStyle(
                  fontSize: AppTheme.fontTitle,
                  fontWeight: FontWeight.bold,
                  color: t.color,
                ),
              ),
              Text(
                t.label,
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: AppTheme.fontXS,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUsageChart() {
    final usage = _analytics['usage'] as Map<String, dynamic>? ?? {};
    final items = [
      _UsageBar(
        'Eye',
        usage['eye_tracking_tests'] as int? ?? 0,
        AppTheme.primary,
      ),
      _UsageBar(
        'Visual',
        usage['visual_acuity_tests'] as int? ?? 0,
        AppTheme.categoryBlue,
      ),
      _UsageBar(
        'Colour',
        usage['colour_vision_tests'] as int? ?? 0,
        AppTheme.success,
      ),
      _UsageBar(
        'Fatigue',
        usage['blink_fatigue_tests'] as int? ?? 0,
        AppTheme.warning,
      ),
      _UsageBar(
        'Pupil',
        usage['pupil_reflex_tests'] as int? ?? 0,
        AppTheme.categoryIndigo,
      ),
    ];

    return Container(
      padding: const EdgeInsets.all(AppTheme.spaceMD),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        boxShadow: AppTheme.cardShadow,
      ),
      child: SizedBox(
        height: 200,
        child: BarChart(
          BarChartData(
            barGroups: [
              for (int i = 0; i < items.length; i++)
                BarChartGroupData(
                  x: i,
                  barRods: [
                    BarChartRodData(
                      toY: items[i].value.toDouble(),
                      color: items[i].color,
                      width: 20,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ],
                  showingTooltipIndicators: const [0],
                ),
            ],
            titlesData: FlTitlesData(
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (value, meta) {
                    final idx = value.toInt();
                    return Padding(
                      padding: const EdgeInsets.only(top: 6.0),
                      child: Text(
                        items[idx].label,
                        style: const TextStyle(fontSize: AppTheme.fontXS),
                      ),
                    );
                  },
                ),
              ),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(showTitles: true, reservedSize: 30),
              ),
              rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
            ),
            gridData: FlGridData(show: true, drawVerticalLine: false),
            borderData: FlBorderData(show: false),
          ),
        ),
      ),
    );
  }

  Widget _buildTestMixPie() {
    final usage = _analytics['usage'] as Map<String, dynamic>? ?? {};
    final values = [
      _UsageBar(
        'Eye Tracking',
        usage['eye_tracking_tests'] as int? ?? 0,
        AppTheme.primary,
      ),
      _UsageBar(
        'Visual Acuity',
        usage['visual_acuity_tests'] as int? ?? 0,
        AppTheme.categoryBlue,
      ),
      _UsageBar(
        'Colour Vision',
        usage['colour_vision_tests'] as int? ?? 0,
        AppTheme.success,
      ),
      _UsageBar(
        'Blink & Fatigue',
        usage['blink_fatigue_tests'] as int? ?? 0,
        AppTheme.warning,
      ),
      _UsageBar(
        'Pupil Reflex',
        usage['pupil_reflex_tests'] as int? ?? 0,
        AppTheme.categoryIndigo,
      ),
    ];

    final total = values
        .fold<int>(0, (sum, v) => sum + v.value)
        .clamp(1, 1 << 30);

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
            'Share by Test Type',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: AppTheme.spaceSM),
          SizedBox(
            height: 220,
            child: PieChart(
              PieChartData(
                sectionsSpace: 2,
                centerSpaceRadius: 40,
                sections: [
                  for (final v in values)
                    PieChartSectionData(
                      color: v.color,
                      value: v.value.toDouble(),
                      title: '${((v.value / total) * 100).toStringAsFixed(1)}%',
                      radius: 55,
                      titleStyle: const TextStyle(
                        fontSize: AppTheme.fontSM,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppTheme.spaceSM),
          Wrap(
            spacing: 12,
            runSpacing: 6,
            children: [
              for (final v in values)
                _legendDot('${v.label} (${v.value})', v.color),
            ],
          ),
        ],
      ),
    );
  }
}

class _UsageBar {
  final String label;
  final int value;
  final Color color;
  _UsageBar(this.label, this.value, this.color);
}

class _TestTile {
  final String label;
  final int count;
  final Color color;

  _TestTile(this.label, this.count, this.color);
}

Widget _legendDot(String label, Color color) {
  return Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 6),
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
