import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class ResultsReportPage extends StatefulWidget {
  const ResultsReportPage({super.key});

  @override
  State<ResultsReportPage> createState() => _ResultsReportPageState();
}

class _ResultsReportPageState extends State<ResultsReportPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _sendingReport = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // Mock data
  final List<Map<String, dynamic>> _mockData = [
    {'date': 'Jan', 'score': 78.0},
    {'date': 'Feb', 'score': 82.0},
    {'date': 'Mar', 'score': 79.0},
    {'date': 'Apr', 'score': 84.0},
    {'date': 'May', 'score': 85.0},
  ];

  final String _aiReport = '''
**AI-Generated Comprehensive Eye Health Report**

Patient: Sarah Johnson
Date: 15th May 2023
Overall Health Score: 85/100

**Summary:**
The patient's eye health assessment indicates generally good vision with some areas requiring attention. The comprehensive analysis of multiple tests reveals stable eye health with minor recommendations for improvement.

**Detailed Analysis:**

1. **Visual Acuity (20/25):**
   - The patient demonstrates slightly reduced visual acuity compared to optimal 20/20 vision
   - This is within normal range but suggests potential for improvement
   - Recommendation: Consider a comprehensive optometric examination within the next 3 months

2. **Eye Tracking (Normal):**
   - Smooth pursuit movements are within normal parameters
   - Saccadic eye movements show good coordination
   - No concerns identified in this area

3. **Colour Vision (85%):**
   - Patient shows normal colour discrimination ability
   - Successfully identified 4 out of 5 Ishihara plates correctly
   - No significant colour vision deficiency detected
   - Minor variations may be due to screen calibration or lighting conditions

4. **Pupil Reflex (0.3s reaction time):**
   - Pupil response to light stimulus is within normal range
   - Constriction and dilation patterns are symmetrical
   - No neurological concerns identified

5. **Eye Fatigue (Mild):**
   - Blink rate of 12 blinks per minute indicates mild digital eye strain
   - This is below the optimal 15-20 blinks per minute
   - Likely related to extended screen time

**Recommendations:**

1. **Immediate Actions:**
   - Implement the 20-20-20 rule: Every 20 minutes, look at something 20 feet away for 20 seconds
   - Ensure proper screen positioning and lighting in work environment
   - Consider using artificial tears if experiencing dry eyes

2. **Short-term (1-3 months):**
   - Schedule a comprehensive eye examination with an optometrist
   - Monitor any changes in vision quality
   - Maintain regular eye test schedule through this application

3. **Long-term:**
   - Continue regular eye health monitoring every 3-6 months
   - Maintain healthy screen time habits
   - Ensure adequate lighting when reading or using digital devices

**Risk Assessment:**
- Low risk for immediate vision problems
- Moderate risk for digital eye strain if screen time habits are not modified
- No indicators of serious eye conditions detected

**Follow-up:**
Next recommended assessment: 15th August 2023

This report has been generated using advanced AI analysis of your test results. Please consult with a qualified eye care professional for any concerns or before making medical decisions.
''';

  Future<void> _handleSendToDoctor() async {
    setState(() => _sendingReport = true);
    await Future.delayed(const Duration(seconds: 2));
    setState(() => _sendingReport = false);

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
              pw.Text('Patient: Sarah Johnson'),
              pw.Text('Date: 15th May 2023'),
              pw.Text('Overall Health Score: 85/100'),
              pw.SizedBox(height: 20),
              pw.Text(
                'Test Results:',
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 10),
              pw.Text('• Visual Acuity: 20/25 (Slightly reduced)'),
              pw.Text('• Eye Tracking: Normal'),
              pw.Text('• Colour Vision: 85% (Normal range)'),
              pw.Text('• Pupil Reflex: Normal (0.3s reaction time)'),
              pw.Text('• Fatigue Level: Mild (12 blinks/min)'),
            ],
          );
        },
      ),
    );

    try {
      final output = await getTemporaryDirectory();
      final file = File('${output.path}/eye_health_report.pdf');
      await file.writeAsBytes(await pdf.save());

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('PDF saved to ${file.path}'),
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
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Your Eye Health Report',
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Header with date
            Container(
              width: double.infinity,
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: const Text(
                'Last updated: 15th May 2023',
                style: TextStyle(color: Colors.grey, fontSize: 14),
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
                        value: 0.85,
                        strokeWidth: 8,
                        backgroundColor: Colors.white.withOpacity(0.3),
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          Colors.white,
                        ),
                      ),
                    ),
                    const Center(
                      child: Text(
                        '85',
                        style: TextStyle(
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
                  child: const Column(
                    children: [
                      Text(
                        'Tests Completed',
                        style: TextStyle(
                          color: Color(0xFFBFDBFE),
                          fontSize: 12,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        '5/5',
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
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Column(
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
            labelColor: const Color(0xFF3B82F6),
            unselectedLabelColor: Colors.grey,
            indicatorColor: const Color(0xFF3B82F6),
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

          // Radar Chart
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
                    'Pupil\nReflex',
                    'Fatigue\nLevel',
                  ];
                  return RadarChartTitle(text: titles[index], angle: angle);
                },
                dataSets: [
                  RadarDataSet(
                    fillColor: const Color(0xFF3B82F6).withOpacity(0.3),
                    borderColor: const Color(0xFF3B82F6),
                    borderWidth: 2,
                    dataEntries: const [
                      RadarEntry(value: 80),
                      RadarEntry(value: 90),
                      RadarEntry(value: 85),
                      RadarEntry(value: 88),
                      RadarEntry(value: 75),
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
                '20/25',
                'Slightly reduced',
                Icons.remove_red_eye,
                const Color(0xFF3B82F6),
                const Color(0xFFEFF6FF),
              ),
              _buildTestCard(
                'Eye Tracking',
                'Normal',
                'Smooth pursuit',
                Icons.my_location,
                const Color(0xFF10B981),
                const Color(0xFFECFDF5),
              ),
              _buildTestCard(
                'Colour Vision',
                '85%',
                'Normal range',
                Icons.palette,
                const Color(0xFF9333EA),
                const Color(0xFFFAF5FF),
              ),
              _buildTestCard(
                'Fatigue Level',
                'Mild',
                '12 blinks/min',
                Icons.visibility,
                const Color(0xFFF97316),
                const Color(0xFFFFF7ED),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Pupil Reflex Card (full width)
          _buildFullWidthTestCard(
            'Pupil Reflex',
            'Normal',
            '0.3s reaction time',
            Icons.flash_on,
            const Color(0xFF6366F1),
            const Color(0xFFEEF2FF),
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

  Widget _buildRecommendationItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '• ',
            style: TextStyle(color: Color(0xFF1E40AF), fontSize: 14),
          ),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: Color(0xFF1E40AF), fontSize: 13),
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
          _buildDetailSection('Visual Acuity Test Details', [
            {'label': 'Right Eye', 'value': '20/25', 'progress': 0.8},
            {'label': 'Left Eye', 'value': '20/30', 'progress': 0.75},
          ], const Color(0xFF3B82F6)),
          const SizedBox(height: 16),
          _buildDetailSection('Eye Tracking Analysis', [
            {'label': 'Smooth Pursuit', 'value': 'Normal', 'progress': 0.9},
            {'label': 'Saccadic Movement', 'value': 'Normal', 'progress': 0.85},
          ], const Color(0xFF10B981)),
          const SizedBox(height: 16),
          _buildColourVisionDetails(),
          const SizedBox(height: 16),
          _buildPupilReflexDetails(),
        ],
      ),
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
              const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Correct Plates',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                  Text(
                    '4 / 5',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: 0.8,
                backgroundColor: Colors.grey[200],
                valueColor: const AlwaysStoppedAnimation<Color>(
                  Color(0xFF9333EA),
                ),
                minHeight: 8,
                borderRadius: BorderRadius.circular(4),
              ),
              const SizedBox(height: 16),
              _buildPlateResult('Plate 1: Correctly identified (12)', true),
              _buildPlateResult('Plate 2: Correctly identified (8)', true),
              _buildPlateResult('Plate 3: Incorrectly identified', false),
              _buildPlateResult('Plate 4: Correctly identified (5)', true),
              _buildPlateResult('Plate 5: Correctly identified (74)', true),
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
        _buildHistoryItem('Complete Eye Checkup', 'May 15, 2023', 85),
        _buildHistoryItem('Visual Acuity Test', 'April 10, 2023', 84),
        _buildHistoryItem('Complete Eye Checkup', 'March 5, 2023', 79),
        _buildHistoryItem('Pupil Reflex Test', 'February 20, 2023', 82),
      ],
    );
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
