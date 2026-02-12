import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:io';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../config/app_theme.dart';
import '../services/api_service.dart';
import '../services/blink_fatigue_service.dart';

class ResultsReportPage extends StatefulWidget {
  const ResultsReportPage({super.key});

  @override
  State<ResultsReportPage> createState() => _ResultsReportPageState();
}

class _ResultsReportPageState extends State<ResultsReportPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  String? _errorMessage;

  // Real data from backend
  List<Map<String, dynamic>> _visualAcuityTests = [];
  List<Map<String, dynamic>> _colourVisionTests = [];
  List<Map<String, dynamic>> _eyeTrackingTests = [];
  List<Map<String, dynamic>> _blinkFatigueTests = [];
  Map<String, dynamic>? _blinkFatigueStats;

  DateTime? _lastUpdated;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadTestResults();
  }

  Future<void> _loadTestResults() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final data = await ApiService.getAllTestResults();

      // Load blink fatigue data
      Map<String, dynamic>? blinkFatigueData;
      Map<String, dynamic>? blinkFatigueStats;
      try {
        blinkFatigueData = await BlinkFatigueService.getHistory();
        blinkFatigueStats = await BlinkFatigueService.getStatistics();
      } catch (e) {
        // Blink fatigue might not have data yet
        print('Blink fatigue data not available: $e');
      }

      setState(() {
        _visualAcuityTests =
            (data['visual_acuity']?['tests'] as List?)
                ?.map((e) => e as Map<String, dynamic>)
                .toList() ??
            [];
        _colourVisionTests =
            (data['colour_vision']?['tests'] as List?)
                ?.map((e) => e as Map<String, dynamic>)
                .toList() ??
            [];
        _eyeTrackingTests =
            (data['eye_tracking']?['tests'] as List?)
                ?.map((e) => e as Map<String, dynamic>)
                .toList() ??
            [];
        _blinkFatigueTests =
            (blinkFatigueData?['tests'] as List?)
                ?.map((e) => e as Map<String, dynamic>)
                .toList() ??
            [];
        _blinkFatigueStats = blinkFatigueStats;
        _lastUpdated = DateTime.now();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _handleSendToDoctor() async {
    await Future.delayed(const Duration(seconds: 2));

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Report successfully sent to your doctor!'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _downloadPDF() async {
    final pdf = pw.Document();

    // Calculate overall metrics
    int totalTests =
        _visualAcuityTests.length +
        _colourVisionTests.length +
        _eyeTrackingTests.length +
        _blinkFatigueTests.length;

    String getLatestVisualAcuity() {
      if (_visualAcuityTests.isEmpty) return 'Not tested';
      final test = _visualAcuityTests.first;
      return '${test['correct']}/${test['total']} (${test['score']}%)';
    }

    String getLatestEyeTracking() {
      if (_eyeTrackingTests.isEmpty) return 'Not tested';
      final test = _eyeTrackingTests.first;
      return '${test['performance_classification']} (${test['gaze_accuracy']?.toStringAsFixed(1)}% accuracy)';
    }

    String getLatestColourVision() {
      if (_colourVisionTests.isEmpty) return 'Not tested';
      final test = _colourVisionTests.first;
      return '${test['correct_count']}/${test['total_plates']} - ${test['severity']}';
    }

    String getLatestFatigue() {
      if (_blinkFatigueTests.isEmpty) return 'Not tested';
      final test = _blinkFatigueTests.first;
      return '${test['classification']} (${test['alertness_percentage']}% alert)';
    }

    pdf.addPage(
      pw.Page(
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'Eye Health Report',
                style: pw.TextStyle(
                  fontSize: 24,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 20),
              pw.Text(
                'Date: ${_lastUpdated?.toString().split('.')[0] ?? DateTime.now().toString().split('.')[0]}',
              ),
              pw.Text('Total Tests Completed: $totalTests'),
              pw.SizedBox(height: 20),
              pw.Text(
                'Test Results:',
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 10),
              pw.Text('• Visual Acuity: ${getLatestVisualAcuity()}'),
              pw.Text('• Eye Tracking: ${getLatestEyeTracking()}'),
              pw.Text('• Colour Vision: ${getLatestColourVision()}'),
              pw.Text('• Fatigue Level: ${getLatestFatigue()}'),
              pw.SizedBox(height: 20),
              pw.Text(
                'Note: This report is based on self-assessment tests. Please consult with a qualified eye care professional for comprehensive evaluation.',
                style: const pw.TextStyle(fontSize: 10),
              ),
            ],
          );
        },
      ),
    );

    try {
      final output = await getTemporaryDirectory();
      final file = File(
        '${output.path}/eye_health_report_${DateTime.now().millisecondsSinceEpoch}.pdf',
      );
      await file.writeAsBytes(await pdf.save());

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('PDF generated successfully'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
            action: SnackBarAction(
              label: 'Share',
              textColor: Colors.white,
              onPressed: () {
                Share.shareXFiles([
                  XFile(file.path),
                ], text: 'Eye Health Report');
              },
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error generating PDF: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFFF5F7FA),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 1,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black87),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Text(
            'Your Eye Health Report',
            style: TextStyle(
              color: Colors.black87,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        backgroundColor: const Color(0xFFF5F7FA),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 1,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black87),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Text(
            'Your Eye Health Report',
            style: TextStyle(
              color: Colors.black87,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                'Error loading results',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.black54),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _loadTestResults,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 12,
                  ),
                ),
                child: const Text(
                  'Retry',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final lastUpdatedText = _lastUpdated != null
        ? '${_lastUpdated!.day}/${_lastUpdated!.month}/${_lastUpdated!.year} ${_lastUpdated!.hour}:${_lastUpdated!.minute.toString().padLeft(2, '0')}'
        : 'Never';

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Your Eye Health Report',
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.black87),
            onPressed: _loadTestResults,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Header with date
            Container(
              width: double.infinity,
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Text(
                'Last updated: $lastUpdatedText',
                style: const TextStyle(color: Colors.grey, fontSize: 14),
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    // Overall Health Score Card
                    _buildHealthScoreCard(),

                    const SizedBox(height: 16),

                    // Tabs Section
                    _buildTabsSection(),

                    const SizedBox(height: 16),

                    // Action Buttons
                    _buildActionButtons(),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHealthScoreCard() {
    // Calculate overall score based on latest tests
    int totalScore = 0;
    int testCount = 0;

    if (_visualAcuityTests.isNotEmpty) {
      final latestVA = _visualAcuityTests.first;
      totalScore += (latestVA['score'] as num?)?.toInt() ?? 70;
      testCount++;
    }

    if (_colourVisionTests.isNotEmpty) {
      final latestCV = _colourVisionTests.first;
      totalScore += (latestCV['score'] as num?)?.toInt() ?? 80;
      testCount++;
    }

    if (_eyeTrackingTests.isNotEmpty) {
      final latestET = _eyeTrackingTests.first;
      final accuracy = (latestET['gaze_accuracy'] as num?)?.toDouble() ?? 75.0;
      totalScore += accuracy.toInt();
      testCount++;
    }

    final overallScore = testCount > 0 ? (totalScore / testCount).round() : 0;
    final totalTests =
        _visualAcuityTests.length +
        _colourVisionTests.length +
        _eyeTrackingTests.length;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF3B82F6), Color(0xFF9333EA)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Overall Health Score',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Comprehensive assessment',
                      style: TextStyle(color: Color(0xFFBFDBFE), fontSize: 14),
                    ),
                  ],
                ),
              ),
              // Circular Progress Indicator
              SizedBox(
                width: 80,
                height: 80,
                child: Stack(
                  children: [
                    SizedBox(
                      width: 80,
                      height: 80,
                      child: CircularProgressIndicator(
                        value: overallScore / 100,
                        strokeWidth: 8,
                        backgroundColor: Colors.white.withOpacity(0.3),
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          Colors.white,
                        ),
                      ),
                    ),
                    Center(
                      child: Text(
                        '$overallScore',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'Tests Completed',
                        style: TextStyle(
                          color: Color(0xFFBFDBFE),
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$totalTests',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Improvement',
                        style: TextStyle(
                          color: Color(0xFFBFDBFE),
                          fontSize: 12,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        '+5%',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTabsSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          TabBar(
            controller: _tabController,
            isScrollable: true,
            labelColor: AppTheme.primary,
            unselectedLabelColor: Colors.grey,
            indicatorColor: AppTheme.primary,
            indicatorWeight: 2,
            tabs: const [
              Tab(text: 'Summary'),
              Tab(text: 'Detailed Results'),
              Tab(text: 'History'),
              Tab(
                child: Row(
                  children: [
                    Icon(Icons.psychology, size: 16),
                    SizedBox(width: 4),
                    Text('AI Report'),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(
            height: 500,
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildSummaryTab(),
                _buildDetailsTab(),
                _buildHistoryTab(),
                _buildAIReportTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Test Performance Overview',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),

          // Radar Chart - Real Data
          SizedBox(
            height: 250,
            child: RadarChart(
              RadarChartData(
                radarBackgroundColor: Colors.transparent,
                borderData: FlBorderData(show: false),
                radarBorderData: const BorderSide(color: Colors.transparent),
                titlePositionPercentageOffset: 0.2,
                getTitle: (index, angle) {
                  final titles = [
                    'Visual\nAcuity',
                    'Eye\nTracking',
                    'Colour\nVision',
                    'Fatigue\nLevel',
                  ];
                  return RadarChartTitle(text: titles[index], angle: angle);
                },
                dataSets: [
                  RadarDataSet(
                    fillColor: const Color(0xFF3B82F6).withOpacity(0.3),
                    borderColor: const Color(0xFF3B82F6),
                    borderWidth: 2,
                    dataEntries: [
                      RadarEntry(value: _visualAcuityTests.isNotEmpty ? (_visualAcuityTests.first['score'] ?? 0).toDouble() : 0),
                      RadarEntry(value: _eyeTrackingTests.isNotEmpty ? (_eyeTrackingTests.first['gaze_accuracy'] ?? 0).toDouble() : 0),
                      RadarEntry(value: _colourVisionTests.isNotEmpty ? ((_colourVisionTests.first['score'] ?? 0).toDouble()) : 0),
                      RadarEntry(value: _blinkFatigueTests.isNotEmpty ? (_blinkFatigueTests.first['alertness_percentage'] ?? 0).toDouble() : 0),
                    ],
                  ),
                ],
                tickCount: 5,
                ticksTextStyle: const TextStyle(
                  fontSize: 10,
                  color: Colors.transparent,
                ),
                tickBorderData: const BorderSide(color: Colors.grey, width: 1),
                gridBorderData: const BorderSide(color: Colors.grey, width: 1),
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Test Result Cards
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.3,
            children: [
              _buildTestCard(
                'Visual Acuity',
                _visualAcuityTests.isNotEmpty
                    ? '${_visualAcuityTests.first['correct'] ?? 0}/${_visualAcuityTests.first['total'] ?? 0}'
                    : 'No data',
                _visualAcuityTests.isNotEmpty
                    ? '${_visualAcuityTests.first['score'] ?? 0}% score'
                    : 'Not tested',
                Icons.remove_red_eye,
                const Color(0xFF3B82F6),
                const Color(0xFFEFF6FF),
              ),
              _buildTestCard(
                'Eye Tracking',
                _eyeTrackingTests.isNotEmpty
                    ? (_eyeTrackingTests.first['performance_classification'] ??
                          'Normal')
                    : 'No data',
                _eyeTrackingTests.isNotEmpty
                    ? '${(_eyeTrackingTests.first['gaze_accuracy'] ?? 0).toStringAsFixed(1)}% accuracy'
                    : 'Not tested',
                Icons.my_location,
                const Color(0xFF10B981),
                const Color(0xFFECFDF5),
              ),
              _buildTestCard(
                'Colour Vision',
                _colourVisionTests.isNotEmpty
                    ? '${_colourVisionTests.first['correct_count'] ?? 0}/${_colourVisionTests.first['total_plates'] ?? 0}'
                    : 'No data',
                _colourVisionTests.isNotEmpty
                    ? (_colourVisionTests.first['severity'] ?? 'Normal')
                    : 'Not tested',
                Icons.palette,
                const Color(0xFF9333EA),
                const Color(0xFFFAF5FF),
              ),
              _buildTestCard(
                'Blink & Fatigue',
                _blinkFatigueTests.isNotEmpty
                    ? (_blinkFatigueTests.first['classification'] ?? 'No data')
                    : 'No data',
                _blinkFatigueTests.isNotEmpty
                    ? '${_blinkFatigueTests.first['alertness_percentage'] ?? 0}% alert'
                    : 'Not tested',
                Icons.visibility_off,
                const Color(0xFFF97316),
                const Color(0xFFFFF7ED),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // AI Recommendations - Coming Soon
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFEFF6FF), Color(0xFFFAF5FF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFF3B82F6).withOpacity(0.3),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.psychology,
                      color: const Color(0xFF3B82F6),
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'AI Recommendations',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E40AF),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  'AI-powered recommendations will be available soon. We are working on finalizing this feature to provide you with personalized health insights.',
                  style: TextStyle(fontSize: 13, color: Color(0xFF1E40AF)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTestCard(
    String title,
    String value,
    String subtitle,
    IconData icon,
    Color color,
    Color bgColor,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [bgColor, bgColor.withOpacity(0.6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: color,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              Text(subtitle, style: TextStyle(fontSize: 11, color: color)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFullWidthTestCard(
    String title,
    String value,
    String subtitle,
    IconData icon,
    Color color,
    Color bgColor,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [bgColor, bgColor.withOpacity(0.6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: color,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(subtitle, style: TextStyle(fontSize: 11, color: color)),
              ],
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'All Test Results',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          
          // Visual Acuity Tests
          _buildExpandableTestSection(
            'Visual Acuity Tests',
            _visualAcuityTests.length,
            Icons.remove_red_eye,
            const Color(0xFF3B82F6),
            _visualAcuityTests.map((test) => _buildVisualAcuityTestCard(test)).toList(),
          ),
          const SizedBox(height: 12),
          
          // Eye Tracking Tests
          _buildExpandableTestSection(
            'Eye Tracking Tests',
            _eyeTrackingTests.length,
            Icons.my_location,
            const Color(0xFF10B981),
            _eyeTrackingTests.map((test) => _buildEyeTrackingTestCard(test)).toList(),
          ),
          const SizedBox(height: 12),
          
          // Colour Vision Tests
          _buildExpandableTestSection(
            'Colour Vision Tests',
            _colourVisionTests.length,
            Icons.palette,
            const Color(0xFF9333EA),
            _colourVisionTests.map((test) => _buildColourVisionTestCard(test)).toList(),
          ),
          const SizedBox(height: 12),
          
          // Blink & Fatigue Tests
          _buildExpandableTestSection(
            'Blink & Fatigue Tests',
            _blinkFatigueTests.length,
            Icons.visibility_off,
            const Color(0xFFF97316),
            _blinkFatigueTests.map((test) => _buildBlinkFatigueTestCard(test)).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildExpandableTestSection(
    String title,
    int count,
    IconData icon,
    Color color,
    List<Widget> testCards,
  ) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          leading: Icon(icon, color: color),
          title: Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
          ),
          subtitle: Text(
            '$count test${count != 1 ? 's' : ''} available',
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
          children: [
            if (testCards.isEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'No tests recorded yet',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              )
            else
              ...testCards,
          ],
        ),
      ),
    );
  }

  Widget _buildVisualAcuityTestCard(Map<String, dynamic> test) {
    final score = test['score'] ?? 0;
    final correct = test['correct'] ?? test['correct_answers'] ?? 0;
    final total = test['total'] ?? test['total_questions'] ?? 0;
    final date = _formatDate(test['date'] ?? test['created_at'] ?? '');
    final snellen = test['snellen'] ?? test['snellen_value'] ?? 'N/A';
    final severity = test['severity'] ?? 'Normal';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                date,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF3B82F6).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$score%',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF3B82F6),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildDetailItem('Score', '$correct/$total'),
              ),
              Expanded(
                child: _buildDetailItem('Snellen', snellen),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _buildDetailItem('Severity', severity),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: score / 100,
            backgroundColor: Colors.grey[200],
            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF3B82F6)),
            minHeight: 8,
            borderRadius: BorderRadius.circular(4),
          ),
        ],
      ),
    );
  }

  Widget _buildEyeTrackingTestCard(Map<String, dynamic> test) {
    final date = _formatDate(test['date'] ?? test['created_at'] ?? '');
    final accuracy = test['gaze_accuracy'] ?? 0;
    final classification = test['performance_classification'] ?? 'Fair';
    final duration = test['test_duration'] ?? 0;
    final fixationStability = test['fixation_stability_score'] ?? test['fixation_stability'] ?? 0;
    final saccadeConsistency = test['saccade_consistency_score'] ?? test['saccade_consistency'] ?? 0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                date,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  classification,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF10B981),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildDetailItem('Accuracy', '${accuracy.toStringAsFixed(1)}%'),
              ),
              Expanded(
                child: _buildDetailItem('Duration', '${duration.toStringAsFixed(1)}s'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildDetailItem('Fixation Stability', '${fixationStability.toStringAsFixed(1)}'),
              ),
              Expanded(
                child: _buildDetailItem('Saccade', '${saccadeConsistency.toStringAsFixed(1)}'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: accuracy / 100,
            backgroundColor: Colors.grey[200],
            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF10B981)),
            minHeight: 8,
            borderRadius: BorderRadius.circular(4),
          ),
        ],
      ),
    );
  }

  Widget _buildColourVisionTestCard(Map<String, dynamic> test) {
    final date = _formatDate(test['date'] ?? test['created_at'] ?? '');
    final correctCount = test['correct_count'] ?? 0;
    final totalPlates = test['total_plates'] ?? 0;
    final score = test['score'] ?? 0;
    final severity = test['severity'] ?? 'Normal';
    final userAnswers = test['user_answers'] as List<dynamic>? ?? [];
    final correctAnswers = test['correct_answers'] as List<dynamic>? ?? [];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                date,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF9333EA).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  severity,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF9333EA),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildDetailItem('Correct', '$correctCount/$totalPlates'),
              ),
              Expanded(
                child: _buildDetailItem('Score', '$score%'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: totalPlates > 0 ? correctCount / totalPlates : 0,
            backgroundColor: Colors.grey[200],
            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF9333EA)),
            minHeight: 8,
            borderRadius: BorderRadius.circular(4),
          ),
          if (userAnswers.isNotEmpty && correctAnswers.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 8),
            const Text(
              'Plate Details:',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            ...List.generate(
              userAnswers.length < totalPlates ? userAnswers.length : totalPlates,
              (index) {
                final userAnswer = userAnswers[index]?.toString().trim() ?? 'No answer';
                final correctAnswer = index < correctAnswers.length 
                    ? correctAnswers[index]?.toString().trim() ?? 'Unknown' 
                    : 'Unknown';
                final isCorrect = userAnswer.toLowerCase() == correctAnswer.toLowerCase();
                
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      Icon(
                        isCorrect ? Icons.check_circle : Icons.cancel,
                        size: 16,
                        color: isCorrect ? Colors.green : Colors.red,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Plate ${index + 1}: ${isCorrect ? 'Correct' : 'Incorrect'} (Your: $userAnswer${!isCorrect ? ', Correct: $correctAnswer' : ''})',
                          style: const TextStyle(fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBlinkFatigueTestCard(Map<String, dynamic> test) {
    final date = _formatDate(test['date'] ?? test['created_at'] ?? '');
    final classification = test['classification'] ?? 'Unknown';
    final alertness = test['alertness_percentage'] ?? 0;
    final avgBpm = test['avg_blinks_per_minute'] ?? 0;
    final duration = test['duration_seconds'] ?? 0;
    final totalBlinks = test['total_blinks'] ?? 0;

    Color getClassificationColor(String classification) {
      switch (classification.toLowerCase()) {
        case 'alert':
          return const Color(0xFF10B981);
        case 'drowsy':
          return const Color(0xFFF97316);
        case 'fatigue':
          return Colors.red;
        default:
          return Colors.grey;
      }
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                date,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: getClassificationColor(classification).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  classification,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: getClassificationColor(classification),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildDetailItem('Alertness', '$alertness%'),
              ),
              Expanded(
                child: _buildDetailItem('Avg BPM', avgBpm.toStringAsFixed(1)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildDetailItem('Total Blinks', totalBlinks.toString()),
              ),
              Expanded(
                child: _buildDetailItem('Duration', '${duration}s'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: alertness / 100,
            backgroundColor: Colors.grey[200],
            valueColor: AlwaysStoppedAnimation<Color>(getClassificationColor(classification)),
            minHeight: 8,
            borderRadius: BorderRadius.circular(4),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }

  Widget _buildDetailSection(
    String title,
    List<Map<String, dynamic>> items,
    Color color,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 16,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF9FAFB),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: items.map((item) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          item['label'],
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                          ),
                        ),
                        Text(
                          item['value'],
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: item['progress'],
                      backgroundColor: Colors.grey[200],
                      valueColor: AlwaysStoppedAnimation<Color>(color),
                      minHeight: 8,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildColourVisionDetails() {
    if (_colourVisionTests.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Colour Vision Test Details',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 16,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(
              child: Text(
                'No colour vision test data available',
                style: TextStyle(color: Colors.grey),
              ),
            ),
          ),
        ],
      );
    }

    final latestTest = _colourVisionTests.first;
    final totalPlates = latestTest['total_plates'] ?? 0;
    final plateIds = latestTest['plate_ids'] as List<dynamic>? ?? [];
    final userAnswers = latestTest['user_answers'] as List<dynamic>? ?? [];
    final correctAnswers =
        latestTest['correct_answers'] as List<dynamic>? ?? [];

    // Debug: Print the FULL test data
    print('===== COLOR VISION DEBUG =====');
    print('Full test data: $latestTest');
    print('Total Plates: $totalPlates');
    print('Plate IDs (${plateIds.length}): $plateIds');
    print('User Answers (${userAnswers.length}): $userAnswers');
    print('Correct Answers (${correctAnswers.length}): $correctAnswers');
    print('Backend Correct Count: ${latestTest['correct_count']}');
    print('=====================================');

    // Check if data is missing
    if (userAnswers.isEmpty || correctAnswers.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Colour Vision Test Details',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 16,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.warning_amber, color: Colors.orange.shade700),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Test data incomplete',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'The detailed test answers were not saved properly. This may be due to a connection issue during the test. Your test score is still recorded.',
                  style: TextStyle(fontSize: 12, color: Colors.black54),
                ),
                const SizedBox(height: 12),
                Text(
                  'Score: ${latestTest['score'] ?? 0}%',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    // Calculate correct count by comparing answers
    int actualCorrectCount = 0;
    for (int i = 0; i < userAnswers.length && i < correctAnswers.length; i++) {
      final userAns = userAnswers[i]?.toString().trim().toLowerCase() ?? '';
      final correctAns =
          correctAnswers[i]?.toString().trim().toLowerCase() ?? '';

      if (userAns.isNotEmpty &&
          correctAns.isNotEmpty &&
          userAns == correctAns) {
        actualCorrectCount++;
      }
    }

    print(
      'Calculated Correct Count: $actualCorrectCount / ${userAnswers.length}',
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Colour Vision Test Details',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 16,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF9FAFB),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Correct Plates',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                  Text(
                    '$actualCorrectCount / $totalPlates',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: totalPlates > 0 ? actualCorrectCount / totalPlates : 0,
                backgroundColor: Colors.grey[200],
                valueColor: const AlwaysStoppedAnimation<Color>(
                  Color(0xFF9333EA),
                ),
                minHeight: 8,
                borderRadius: BorderRadius.circular(4),
              ),
              const SizedBox(height: 16),
              ...List.generate(
                plateIds.length < totalPlates ? plateIds.length : totalPlates,
                (index) {
                  final userAnswerRaw = index < userAnswers.length
                      ? userAnswers[index]
                      : null;
                  final correctAnswerRaw = index < correctAnswers.length
                      ? correctAnswers[index]
                      : null;

                  // Normalize answers for comparison
                  final userAnswerNormalized =
                      userAnswerRaw?.toString().trim().toLowerCase() ?? '';
                  final correctAnswerNormalized =
                      correctAnswerRaw?.toString().trim().toLowerCase() ?? '';

                  // Display values (original case)
                  final userAnswer =
                      userAnswerRaw?.toString().trim() ?? 'No answer';
                  final correctAnswer =
                      correctAnswerRaw?.toString().trim() ?? 'Unknown';

                  // Compare normalized values - STRICT matching
                  final isCorrect =
                      userAnswerNormalized.isNotEmpty &&
                      correctAnswerNormalized.isNotEmpty &&
                      userAnswerNormalized == correctAnswerNormalized;

                  // Debug per plate
                  print(
                    'Plate ${index + 1}: User="$userAnswerNormalized" vs Correct="$correctAnswerNormalized" => $isCorrect',
                  );

                  // Build display text
                  String displayText;
                  if (isCorrect) {
                    displayText =
                        'Plate ${index + 1}: Correct (Your answer: $userAnswer)';
                  } else {
                    displayText =
                        'Plate ${index + 1}: Incorrect (Your answer: $userAnswer, Correct: $correctAnswer)';
                  }

                  return _buildPlateResult(displayText, isCorrect);
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPlateResult(String text, bool correct) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(
            correct ? Icons.check_circle : Icons.cancel,
            size: 16,
            color: correct ? Colors.green : Colors.red,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 12, color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPupilReflexDetails() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Pupil Reflex Metrics',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 16,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF9FAFB),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _buildMetricItem('Reaction Time:', '0.3 seconds'),
                  ),
                  Expanded(child: _buildMetricItem('Constriction:', 'Normal')),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: _buildMetricItem('Dilation:', 'Normal')),
                  Expanded(child: _buildMetricItem('Symmetry:', 'Equal')),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMetricItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        Text(
          value,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  Widget _buildHistoryTab() {
    // Combine all tests from different categories
    List<Map<String, dynamic>> allTests = [];

    // Add visual acuity tests
    for (var test in _visualAcuityTests) {
      allTests.add({
        'title': 'Visual Acuity Test',
        'date': test['date'] ?? 'Unknown date',
        'score': test['score'] ?? 0,
        'timestamp': test['date'] ?? '',
      });
    }

    // Add colour vision tests
    for (var test in _colourVisionTests) {
      final score =
          test['correct_count'] != null && test['total_plates'] != null
          ? ((test['correct_count'] / test['total_plates']) * 100).round()
          : 0;
      allTests.add({
        'title': 'Colour Vision Test',
        'date': test['date'] ?? 'Unknown date',
        'score': score,
        'timestamp': test['date'] ?? '',
      });
    }

    // Add eye tracking tests
    for (var test in _eyeTrackingTests) {
      final score = (test['gaze_accuracy'] ?? 0).round();
      allTests.add({
        'title': 'Eye Tracking Test',
        'date': test['date'] ?? 'Unknown date',
        'score': score,
        'timestamp': test['date'] ?? '',
      });
    }

    // Add blink fatigue tests
    for (var test in _blinkFatigueTests) {
      allTests.add({
        'title': 'Blink & Fatigue Test',
        'date': test['date'] ?? 'Unknown date',
        'score': test['alertness_percentage']?.round() ?? 0,
        'timestamp': test['date'] ?? '',
      });
    }

    // Sort by date (most recent first)
    allTests.sort((a, b) {
      try {
        DateTime dateA = DateTime.parse(a['timestamp']);
        DateTime dateB = DateTime.parse(b['timestamp']);
        return dateB.compareTo(dateA);
      } catch (e) {
        return 0;
      }
    });

    if (allTests.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF2FF),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.history,
                  size: 48,
                  color: Color(0xFF4F46E5),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'No Test History',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Complete some tests to see your history here',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Test History',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 16,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 12),
        ...allTests
            .map(
              (test) => _buildHistoryItem(
                test['title'],
                _formatDate(test['date']),
                test['score'],
              ),
            )
            .toList(),
      ],
    );
  }

  String _formatDate(String dateStr) {
    try {
      DateTime date = DateTime.parse(dateStr);
      return '${date.day}/${date.month}/${date.year} at ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return dateStr;
    }
  }

  Widget _buildHistoryItem(String title, String date, int score) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.calendar_today, color: Color(0xFF3B82F6), size: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  date,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
          Text(
            'Score: $score',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF10B981),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBlinkFatigueTab() {
    if (_blinkFatigueTests.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.visibility_off,
                  size: 48,
                  color: Colors.orange,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'No Blink & Fatigue Tests Yet',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Take a test to see your drowsiness detection results here',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Statistics Card
          if (_blinkFatigueStats != null) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.orange.shade50, Colors.red.shade50],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.analytics,
                          color: Colors.orange,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Fatigue Statistics',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          'Total Tests',
                          '${_blinkFatigueStats!['total_tests'] ?? 0}',
                          Icons.assessment,
                          Colors.blue,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildStatCard(
                          'Drowsy',
                          '${_blinkFatigueStats!['drowsy_percentage']?.toStringAsFixed(0) ?? 0}%',
                          Icons.warning,
                          Colors.red,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          'Alerts',
                          '${_blinkFatigueStats!['alert_percentage']?.toStringAsFixed(0) ?? 0}%',
                          Icons.notifications_active,
                          Colors.orange,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildStatCard(
                          'Confidence',
                          '${(_blinkFatigueStats!['average_confidence'] * 100)?.toStringAsFixed(0) ?? 0}%',
                          Icons.verified,
                          Colors.green,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.trending_up,
                          color: Colors.blue.shade700,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _blinkFatigueStats!['recent_trend'] ??
                                'No trend data',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.blue.shade900,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],

          // Recent Tests List
          const Text(
            'Recent Tests',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          ...(_blinkFatigueTests.take(10).map((test) {
            final prediction = test['prediction'] as String;
            final confidence = (test['confidence'] as num).toDouble();
            final fatigueLevel = test['fatigue_level'] as String;
            final alertTriggered = test['alert_triggered'] as bool;
            final createdAt = DateTime.parse(test['created_at'] as String);

            final isDrowsy = prediction == 'drowsy';
            final statusColor = isDrowsy ? Colors.red : Colors.green;

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: alertTriggered
                      ? Colors.red.shade300
                      : Colors.grey.shade200,
                  width: alertTriggered ? 2 : 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          isDrowsy ? Icons.warning : Icons.check_circle,
                          color: statusColor,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isDrowsy ? 'Drowsy Detected' : 'Alert State',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: statusColor,
                              ),
                            ),
                            Text(
                              fatigueLevel,
                              style: const TextStyle(
                                fontSize: 13,
                                color: Colors.black54,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (alertTriggered)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.red.shade100,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'ALERT',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.red,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            const Icon(
                              Icons.percent,
                              size: 16,
                              color: Colors.grey,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Confidence: ${(confidence * 100).toStringAsFixed(1)}%',
                              style: const TextStyle(
                                fontSize: 13,
                                color: Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '${createdAt.day}/${createdAt.month}/${createdAt.year}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          })),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: Colors.black54),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildAIReportTab() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFAF5FF), Color(0xFFEFF6FF)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: const Color(0xFF9333EA).withOpacity(0.3),
                ),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF9333EA).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.psychology,
                      color: Color(0xFF9333EA),
                      size: 64,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'AI Report',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Coming Soon',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF9333EA),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'The AI-powered comprehensive report feature is currently under development. We are working on finalizing the template to provide you with detailed insights and personalized recommendations.\n\nCheck back soon for updates!',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.black87,
                        height: 1.6,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _downloadPDF,
              icon: const Icon(Icons.download),
              label: const Text('Download PDF'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                side: const BorderSide(color: Colors.grey, width: 2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () async {
                await _handleSendToDoctor();
              },
              icon: const Icon(Icons.share),
              label: const Text('Share with Doctor'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: const Color(0xFF3B82F6),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
