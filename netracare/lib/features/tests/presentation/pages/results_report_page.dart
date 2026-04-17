import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:netracare/config/api_config.dart';
import 'package:netracare/config/app_theme.dart';
import 'package:netracare/services/api_service.dart';
import 'package:netracare/services/blink_fatigue_service.dart';
import 'package:netracare/services/pupil_reflex_service.dart';

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
  List<Map<String, dynamic>> _pupilReflexTests = [];
  // ignore: unused_field
  Map<String, dynamic>? _blinkFatigueStats;

  DateTime? _lastUpdated;

  // AI Report state
  bool _isGeneratingAIReport = false;
  bool _isDownloadingAIPDF = false;
  bool _isSendingToDoctor = false;
  Map<String, dynamic>? _aiReport;
  String? _aiReportError;

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
        debugPrint('Blink fatigue data not available: $e');
      }

      // Load pupil reflex data
      Map<String, dynamic>? pupilReflexData;
      try {
        pupilReflexData = await PupilReflexService.getTests();
      } catch (e) {
        // Pupil reflex might not have data yet
        debugPrint('Pupil reflex data not available: $e');
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
        _pupilReflexTests =
            (pupilReflexData?['tests'] as List?)
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

  Future<void> _generateAIReport() async {
    setState(() {
      _isGeneratingAIReport = true;
      _aiReportError = null;
    });
    try {
      final token = await ApiService.getToken();
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}${ApiConfig.aiReportGenerateEndpoint}'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'time_range_days': 30}),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _aiReport = data['report'] as Map<String, dynamic>?;
          _isGeneratingAIReport = false;
        });
      } else {
        final err = jsonDecode(response.body);
        setState(() {
          _aiReportError = err['message'] ?? 'Failed to generate report';
          _isGeneratingAIReport = false;
        });
      }
    } catch (e) {
      setState(() {
        _aiReportError = e.toString();
        _isGeneratingAIReport = false;
      });
    }
  }

  Future<void> _downloadAIPDF() async {
    setState(() => _isDownloadingAIPDF = true);
    try {
      final token = await ApiService.getToken();
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}${ApiConfig.aiReportPdfEndpoint}'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'time_range_days': 30}),
      );
      if (response.statusCode == 200) {
        final Uint8List bytes = response.bodyBytes;
        final dir = await getTemporaryDirectory();
        final file = File(
          '${dir.path}/netracare_ai_report_${DateTime.now().millisecondsSinceEpoch}.pdf',
        );
        await file.writeAsBytes(bytes);
        setState(() => _isDownloadingAIPDF = false);
        if (mounted) {
          await Share.shareXFiles([
            XFile(file.path),
          ], text: 'NetraCare AI Eye Health Report');
        }
      } else {
        final err = jsonDecode(response.body);
        setState(() => _isDownloadingAIPDF = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(err['message'] ?? 'Failed to download PDF'),
              backgroundColor: AppTheme.error,
            ),
          );
        }
      }
    } catch (e) {
      setState(() => _isDownloadingAIPDF = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error downloading PDF: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  Future<void> _handleSendToDoctor() async {
    if (_aiReport == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please generate the AI Report first.')),
      );
      return;
    }

    setState(() => _isSendingToDoctor = true);
    try {
      // 1. Fetch linked doctors
      final token = await ApiService.getToken();
      final doctorsRes = await http.get(
        Uri.parse('${ApiConfig.baseUrl}${ApiConfig.aiReportMyDoctorsEndpoint}'),
        headers: {'Authorization': 'Bearer $token'},
      );
      setState(() => _isSendingToDoctor = false);

      if (!mounted) return;

      final doctorsData = jsonDecode(doctorsRes.body) as Map<String, dynamic>;
      final doctors = (doctorsData['doctors'] as List<dynamic>? ?? [])
          .cast<Map<String, dynamic>>();

      if (doctors.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No linked doctors found. Book a consultation first to link a doctor.',
            ),
          ),
        );
        return;
      }

      // 2. Show doctor picker
      final selected = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (ctx) => _DoctorPickerDialog(doctors: doctors),
      );

      if (selected == null || !mounted) return;

      final doctorName = selected['name'] as String? ?? 'Doctor';

      // 3. Optional personal message
      final messageCtrl = TextEditingController();
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('Send to Dr. $doctorName'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Your AI report will be sent to the doctor's notifications.",
              ),
              const SizedBox(height: 12),
              TextField(
                controller: messageCtrl,
                decoration: const InputDecoration(
                  labelText: 'Optional message (e.g. concerns)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.categoryBlue,
                foregroundColor: Colors.white,
              ),
              child: const Text('Send'),
            ),
          ],
        ),
      );

      if (confirmed != true || !mounted) return;

      // 4. Send to backend
      setState(() => _isSendingToDoctor = true);
      final sendRes = await http.post(
        Uri.parse(
          '${ApiConfig.baseUrl}${ApiConfig.aiReportSendToDoctorEndpoint}',
        ),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'doctor_id': selected['id'],
          'time_range_days': 30,
          if (messageCtrl.text.trim().isNotEmpty)
            'message': messageCtrl.text.trim(),
        }),
      );
      setState(() => _isSendingToDoctor = false);

      if (!mounted) return;
      final body = jsonDecode(sendRes.body) as Map<String, dynamic>;
      if (sendRes.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              body['message'] as String? ?? 'Report sent to Dr. $doctorName',
            ),
            backgroundColor: AppTheme.success,
            duration: const Duration(seconds: 3),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              body['message'] as String? ?? 'Failed to send report',
            ),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    } catch (e) {
      setState(() => _isSendingToDoctor = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
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
      final correct = test['correct_answers'] ?? test['correct'] ?? 0;
      final total = test['total_questions'] ?? test['total'] ?? 0;
      final score =
          test['score'] ?? (total > 0 ? ((correct / total) * 100).round() : 0);
      return '$correct/$total ($score%)';
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
      final alertness = _resolveAlertnessPercent(test);
      return '${test['classification']} (${(alertness ?? 0).round()}% alert)';
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
                  fontSize: AppTheme.fontHeading,
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
                  fontSize: AppTheme.fontXL,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 10),
              pw.Text('Ã¢â‚¬Â¢ Visual Acuity: ${getLatestVisualAcuity()}'),
              pw.Text('Ã¢â‚¬Â¢ Eye Tracking: ${getLatestEyeTracking()}'),
              pw.Text('Ã¢â‚¬Â¢ Colour Vision: ${getLatestColourVision()}'),
              pw.Text('Ã¢â‚¬Â¢ Fatigue Level: ${getLatestFatigue()}'),
              pw.SizedBox(height: 20),
              pw.Text(
                'Note: This report is based on self-assessment tests. Please consult with a qualified eye care professional for comprehensive evaluation.',
                style: const pw.TextStyle(fontSize: AppTheme.fontXS),
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
            backgroundColor: AppTheme.success,
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
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 1,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: AppTheme.textPrimary),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Text(
            'Your Eye Health Report',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 1,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: AppTheme.textPrimary),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Text(
            'Your Eye Health Report',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: AppTheme.error),
              const SizedBox(height: 16),
              Text(
                'Error loading results',
                style: TextStyle(
                  fontSize: AppTheme.fontXL,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppTheme.textSecondary),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _loadTestResults,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.info,
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
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Your Eye Health Report',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppTheme.textPrimary),
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
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: AppTheme.fontBody,
                ),
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
          colors: [AppTheme.categoryBlue, AppTheme.categoryPurple],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withValues(alpha: 0.3),
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
                        fontSize: AppTheme.fontTitle,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Comprehensive assessment',
                      style: TextStyle(
                        color: AppTheme.overlayBlueLight,
                        fontSize: AppTheme.fontBody,
                      ),
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
                        backgroundColor: Colors.white.withValues(alpha: 0.3),
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
                          fontSize: AppTheme.fontHeading,
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
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'Tests Completed',
                        style: TextStyle(
                          color: AppTheme.overlayBlueLight,
                          fontSize: AppTheme.fontSM,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$totalTests',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: AppTheme.fontXXL,
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
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Improvement',
                        style: TextStyle(
                          color: AppTheme.overlayBlueLight,
                          fontSize: AppTheme.fontSM,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        '+5%',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: AppTheme.fontXXL,
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
            color: Colors.grey.withValues(alpha: 0.1),
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
            unselectedLabelColor: AppTheme.textSecondary,
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
    // Calculate overall statistics
    final totalTests =
        _visualAcuityTests.length +
        _colourVisionTests.length +
        _eyeTrackingTests.length +
        _blinkFatigueTests.length +
        _pupilReflexTests.length;

    final hasAnyTest = totalTests > 0;
    final double overallScore = hasAnyTest
        ? (() {
            double sum = 0;
            int count = 0;

            if (_visualAcuityTests.isNotEmpty) {
              sum += (_visualAcuityTests.first['score'] ?? 0).toDouble();
              count++;
            }

            if (_eyeTrackingTests.isNotEmpty) {
              sum += (_eyeTrackingTests.first['gaze_accuracy'] ?? 0).toDouble();
              count++;
            }

            if (_colourVisionTests.isNotEmpty) {
              sum += (_colourVisionTests.first['score'] ?? 0).toDouble();
              count++;
            }

            if (_blinkFatigueTests.isNotEmpty) {
              final alertness = _resolveAlertnessPercent(
                _blinkFatigueTests.first,
              );
              if (alertness != null) {
                sum += alertness;
                count++;
              }
            }

            return count > 0 ? (sum / count) : 0.0;
          })()
        : 0.0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Overall Health Score Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.categoryBlue.withValues(alpha: 0.1),
                  AppTheme.categoryPurple.withValues(alpha: 0.1),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppTheme.categoryBlue.withValues(alpha: 0.3),
                width: 2,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.textPrimary.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Text(
                        overallScore.toStringAsFixed(0),
                        style: TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          foreground: Paint()
                            ..shader = const LinearGradient(
                              colors: [
                                AppTheme.categoryBlue,
                                AppTheme.categoryPurple,
                              ],
                            ).createShader(const Rect.fromLTWH(0, 0, 200, 70)),
                        ),
                      ),
                      const Text(
                        'Overall',
                        style: TextStyle(
                          fontSize: AppTheme.fontSM,
                          color: AppTheme.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Eye Health Score',
                        style: TextStyle(
                          fontSize: AppTheme.fontXL,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        totalTests > 0
                            ? '$totalTests test${totalTests != 1 ? 's' : ''} completed'
                            : 'No tests completed yet',
                        style: const TextStyle(
                          fontSize: AppTheme.fontSM,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      if (_lastUpdated != null) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(
                              Icons.update,
                              size: 14,
                              color: AppTheme.textLight,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Updated ${_formatDate(_lastUpdated.toString())}',
                              style: const TextStyle(
                                fontSize: AppTheme.fontXS,
                                color: AppTheme.textLight,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          const Text(
            'Performance Overview',
            style: TextStyle(
              fontSize: AppTheme.fontXL,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 16),

          // Enhanced Radar Chart
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.textPrimary.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: SizedBox(
              height: 280,
              child: RadarChart(
                RadarChartData(
                  radarBackgroundColor: Colors.transparent,
                  borderData: FlBorderData(show: false),
                  radarBorderData: const BorderSide(color: Colors.transparent),
                  titlePositionPercentageOffset: 0.15,
                  radarShape: RadarShape.polygon,
                  getTitle: (index, angle) {
                    final titles = [
                      'Visual\nAcuity',
                      'Eye\nTracking',
                      'Colour\nVision',
                      'Blink &\nFatigue',
                      'Pupil\nReflex',
                    ];
                    return RadarChartTitle(
                      text: titles[index],
                      angle: angle,
                      positionPercentageOffset: 0.15,
                    );
                  },
                  titleTextStyle: const TextStyle(
                    fontSize: AppTheme.fontXS,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                  dataSets: [
                    RadarDataSet(
                      fillColor: AppTheme.categoryBlue.withValues(alpha: 0.2),
                      borderColor: AppTheme.categoryBlue,
                      borderWidth: 3,
                      entryRadius: 4,
                      dataEntries: [
                        RadarEntry(
                          value: _visualAcuityTests.isNotEmpty
                              ? (() {
                                  final test = _visualAcuityTests.first;
                                  final score = test['score'];
                                  if (score != null) return score.toDouble();
                                  final correct =
                                      test['correct_answers'] ??
                                      test['correct'] ??
                                      0;
                                  final total =
                                      test['total_questions'] ??
                                      test['total'] ??
                                      1;
                                  return ((correct / total) * 100).toDouble();
                                })()
                              : 0,
                        ),
                        RadarEntry(
                          value: _eyeTrackingTests.isNotEmpty
                              ? (_eyeTrackingTests.first['gaze_accuracy'] ?? 0)
                                    .toDouble()
                              : 0,
                        ),
                        RadarEntry(
                          value: _colourVisionTests.isNotEmpty
                              ? ((_colourVisionTests.first['score'] ?? 0)
                                    .toDouble())
                              : 0,
                        ),
                        RadarEntry(
                          value: _blinkFatigueTests.isNotEmpty
                              ? (_resolveAlertnessPercent(
                                      _blinkFatigueTests.first,
                                    ) ??
                                    0)
                              : 0,
                        ),
                        RadarEntry(value: 0),
                      ],
                    ),
                  ],
                  tickCount: 5,
                  ticksTextStyle: const TextStyle(
                    fontSize: AppTheme.fontXS,
                    color: AppTheme.textLight,
                    fontWeight: FontWeight.w500,
                  ),
                  tickBorderData: BorderSide(color: AppTheme.border, width: 1),
                  gridBorderData: BorderSide(
                    color: AppTheme.border,
                    width: 1.5,
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Quick Insights
          if (hasAnyTest) ...[
            const Text(
              'Quick Insights',
              style: TextStyle(
                fontSize: AppTheme.fontLG,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            _buildInsightCard(
              overallScore >= 80
                  ? Icons.check_circle
                  : overallScore >= 60
                  ? Icons.info
                  : Icons.warning,
              overallScore >= 80
                  ? 'Excellent eye health!'
                  : overallScore >= 60
                  ? 'Good progress'
                  : 'Needs attention',
              overallScore >= 80
                  ? 'Your eye health metrics are looking great. Keep up the good work!'
                  : overallScore >= 60
                  ? 'Your eye health is on track. Consider regular testing to maintain it.'
                  : 'Some metrics need improvement. Consult with an eye care professional.',
              overallScore >= 80
                  ? AppTheme.success
                  : overallScore >= 60
                  ? AppTheme.categoryBlue
                  : AppTheme.categoryOrange,
            ),
            const SizedBox(height: 16),
          ],

          const Text(
            'Latest Test Results',
            style: TextStyle(
              fontSize: AppTheme.fontLG,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 12),

          // Test Result Cards - Compact grid
          _buildTestCard(
            'Visual Acuity',
            _visualAcuityTests.isNotEmpty
                ? '${_visualAcuityTests.first['correct_answers'] ?? 0}/${_visualAcuityTests.first['total_questions'] ?? 0}'
                : 'No data',
            _visualAcuityTests.isNotEmpty
                ? '${_visualAcuityTests.first['snellen_value'] ?? 'N/A'}'
                : 'Not tested',
            Icons.remove_red_eye,
            AppTheme.categoryBlue,
            AppTheme.categoryBlueBg,
          ),
          const SizedBox(height: 10),
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
            AppTheme.success,
            AppTheme.categoryGreenBg,
          ),
          const SizedBox(height: 10),
          _buildTestCard(
            'Colour Vision',
            _colourVisionTests.isNotEmpty
                ? '${_colourVisionTests.first['correct_count'] ?? 0}/${_colourVisionTests.first['total_plates'] ?? 0}'
                : 'No data',
            _colourVisionTests.isNotEmpty
                ? (_colourVisionTests.first['severity'] ?? 'Normal')
                : 'Not tested',
            Icons.palette,
            AppTheme.categoryPurple,
            AppTheme.categoryPurpleBg,
          ),
          const SizedBox(height: 10),
          _buildTestCard(
            'Blink & Fatigue',
            _blinkFatigueTests.isNotEmpty
                ? _resolveBlinkClassification(_blinkFatigueTests.first)
                : 'No data',
            _blinkFatigueTests.isNotEmpty
                ? (() {
                    final alertness = _resolveAlertnessPercent(
                      _blinkFatigueTests.first,
                    );
                    return alertness != null
                        ? '${alertness.toStringAsFixed(0)}% alert'
                        : 'N/A';
                  })()
                : 'Not tested',
            Icons.visibility_off,
            AppTheme.categoryOrange,
            AppTheme.categoryOrangeBg,
          ),
          const SizedBox(height: 10),
          _buildTestCard(
            'Pupil Reflex',
            _pupilReflexTests.isNotEmpty
                ? '${(_pupilReflexTests.first['reaction_time'] ?? 0).toStringAsFixed(3)}s'
                : 'No data',
            _pupilReflexTests.isNotEmpty
                ? '${_pupilReflexTests.first['constriction_amplitude'] ?? 'Normal'} amplitude'
                : 'Not tested',
            Icons.flash_on,
            AppTheme.categoryIndigo,
            AppTheme.categoryIndigoBg,
          ),

          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildInsightCard(
    IconData icon,
    String title,
    String description,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1.5),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: AppTheme.fontBody,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: AppTheme.fontSM,
                    color: AppTheme.textPrimary.withValues(alpha: 0.7),
                    height: 1.4,
                  ),
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [bgColor, bgColor.withValues(alpha: 0.5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2), width: 1.5),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: color,
                    fontSize: AppTheme.fontBody,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: AppTheme.fontXS,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: AppTheme.fontXXL,
              fontWeight: FontWeight.bold,
              color: color,
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
              fontSize: AppTheme.fontXL,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 16),

          // Visual Acuity Tests
          _buildExpandableTestSection(
            'Visual Acuity Tests',
            _visualAcuityTests.length,
            Icons.remove_red_eye,
            AppTheme.categoryBlue,
            _visualAcuityTests
                .map((test) => _buildVisualAcuityTestCard(test))
                .toList(),
          ),
          const SizedBox(height: 12),

          // Eye Tracking Tests
          _buildExpandableTestSection(
            'Eye Tracking Tests',
            _eyeTrackingTests.length,
            Icons.my_location,
            AppTheme.success,
            _eyeTrackingTests
                .map((test) => _buildEyeTrackingTestCard(test))
                .toList(),
          ),
          const SizedBox(height: 12),

          // Colour Vision Tests
          _buildExpandableTestSection(
            'Colour Vision Tests',
            _colourVisionTests.length,
            Icons.palette,
            AppTheme.categoryPurple,
            _colourVisionTests
                .map((test) => _buildColourVisionTestCard(test))
                .toList(),
          ),
          const SizedBox(height: 12),

          // Blink & Fatigue Tests
          _buildExpandableTestSection(
            'Blink & Fatigue Tests',
            _blinkFatigueTests.length,
            Icons.visibility_off,
            AppTheme.categoryOrange,
            _blinkFatigueTests
                .map((test) => _buildBlinkFatigueTestCard(test))
                .toList(),
          ),
          const SizedBox(height: 12),

          // Pupil Reflex Tests
          _buildExpandableTestSection(
            'Pupil Reflex Tests',
            _pupilReflexTests.length,
            Icons.flash_on,
            AppTheme.categoryIndigo,
            _pupilReflexTests.isEmpty
                ? [_buildPupilReflexPlaceholder()]
                : _pupilReflexTests
                      .map((test) => _buildPupilReflexTestCard(test))
                      .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildPupilReflexPlaceholder() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.surfaceLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        children: [
          Icon(
            Icons.flash_on,
            size: 48,
            color: AppTheme.categoryIndigo.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 12),
          const Text(
            'No Tests Yet',
            style: TextStyle(
              fontSize: AppTheme.fontLG,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Complete a pupil reflex test to see your results here',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: AppTheme.fontSM,
              color: AppTheme.textSubtle,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPupilReflexTestCard(Map<String, dynamic> test) {
    final date = _formatDate(test['date'] ?? test['created_at'] ?? '');
    final reactionTime =
        (test['reaction_time'] ?? test['pupil_reaction_time'] ?? 0.0)
            .toDouble();
    final amplitude =
        test['constriction_amplitude'] ?? test['amplitude'] ?? 'Normal';
    final symmetry = test['symmetry'] ?? 'Equal';

    Color getReactionColor() {
      if (reactionTime < 0.3) {
        return AppTheme.success;
      } else if (reactionTime < 0.4) {
        return Colors.blue[600]!;
      } else {
        return AppTheme.categoryOrange;
      }
    }

    String getReactionStatus() {
      if (reactionTime < 0.3) {
        return 'Excellent';
      } else if (reactionTime < 0.4) {
        return 'Normal';
      } else {
        return 'Slow';
      }
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  date,
                  style: const TextStyle(
                    fontSize: AppTheme.fontSM,
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: getReactionColor().withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  getReactionStatus(),
                  style: TextStyle(
                    fontSize: AppTheme.fontSM,
                    fontWeight: FontWeight.bold,
                    color: getReactionColor(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildDetailItem(
                  'Reaction Time',
                  '${reactionTime.toStringAsFixed(3)}s',
                ),
              ),
              Expanded(child: _buildDetailItem('Amplitude', amplitude)),
            ],
          ),
          const SizedBox(height: 8),
          _buildDetailItem('Symmetry', symmetry),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: (0.5 - reactionTime).clamp(0.0, 0.5) / 0.5,
            backgroundColor: AppTheme.border,
            valueColor: AlwaysStoppedAnimation<Color>(getReactionColor()),
            minHeight: 8,
            borderRadius: BorderRadius.circular(4),
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
              fontSize: AppTheme.fontLG,
            ),
          ),
          subtitle: Text(
            '$count test${count != 1 ? 's' : ''} available',
            style: TextStyle(
              fontSize: AppTheme.fontSM,
              color: AppTheme.textSubtle,
            ),
          ),
          children: [
            if (testCards.isEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'No tests recorded yet',
                  style: TextStyle(color: AppTheme.textSubtle),
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
    final correct = test['correct_answers'] ?? test['correct'] ?? 0;
    final total = test['total_questions'] ?? test['total'] ?? 0;
    final score =
        test['score'] ?? (total > 0 ? ((correct / total) * 100).round() : 0);
    final date = _formatDate(test['date'] ?? test['created_at'] ?? '');
    final snellen = test['snellen'] ?? test['snellen_value'] ?? 'N/A';
    final severity = test['severity'] ?? 'Normal';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  date,
                  style: const TextStyle(
                    fontSize: AppTheme.fontSM,
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.categoryBlue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$score%',
                  style: const TextStyle(
                    fontSize: AppTheme.fontSM,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.categoryBlue,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildDetailItem('Score', '$correct/$total')),
              Expanded(child: _buildDetailItem('Snellen', snellen)),
            ],
          ),
          const SizedBox(height: 8),
          _buildDetailItem('Severity', severity),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: score / 100,
            backgroundColor: AppTheme.border,
            valueColor: const AlwaysStoppedAnimation<Color>(
              AppTheme.categoryBlue,
            ),
            minHeight: 8,
            borderRadius: BorderRadius.circular(4),
          ),
        ],
      ),
    );
  }

  Widget _buildEyeTrackingTestCard(Map<String, dynamic> test) {
    final date = _formatDate(test['date'] ?? test['created_at'] ?? '');
    final accuracy = (test['gaze_accuracy'] ?? 0).toDouble();
    final classification = test['performance_classification'] ?? 'Fair';
    final duration = (test['test_duration'] ?? 0).toDouble();
    final fixationStability =
        (test['fixation_stability_score'] ?? test['fixation_stability'] ?? 0)
            .toDouble();
    final saccadeConsistency =
        (test['saccade_consistency_score'] ?? test['saccade_consistency'] ?? 0)
            .toDouble();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  date,
                  style: const TextStyle(
                    fontSize: AppTheme.fontSM,
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.success.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  classification,
                  style: const TextStyle(
                    fontSize: AppTheme.fontSM,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.success,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildDetailItem(
                  'Accuracy',
                  '${accuracy.toStringAsFixed(1)}%',
                ),
              ),
              Expanded(
                child: _buildDetailItem(
                  'Duration',
                  '${duration.toStringAsFixed(1)}s',
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildDetailItem(
                  'Fixation Stability',
                  '${fixationStability.toStringAsFixed(1)}',
                ),
              ),
              Expanded(
                child: _buildDetailItem(
                  'Saccade',
                  '${saccadeConsistency.toStringAsFixed(1)}',
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: accuracy / 100,
            backgroundColor: AppTheme.border,
            valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.success),
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
        color: AppTheme.surfaceLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  date,
                  style: const TextStyle(
                    fontSize: AppTheme.fontSM,
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.categoryPurple.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  severity,
                  style: const TextStyle(
                    fontSize: AppTheme.fontSM,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.categoryPurple,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildDetailItem(
                  'Correct',
                  '$correctCount/$totalPlates',
                ),
              ),
              Expanded(child: _buildDetailItem('Score', '$score%')),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: totalPlates > 0 ? correctCount / totalPlates : 0,
            backgroundColor: AppTheme.border,
            valueColor: const AlwaysStoppedAnimation<Color>(
              AppTheme.categoryPurple,
            ),
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
                fontSize: AppTheme.fontSM,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            ...List.generate(
              userAnswers.length < totalPlates
                  ? userAnswers.length
                  : totalPlates,
              (index) {
                final userAnswer =
                    userAnswers[index]?.toString().trim() ?? 'No answer';
                final correctAnswer = index < correctAnswers.length
                    ? correctAnswers[index]?.toString().trim() ?? 'Unknown'
                    : 'Unknown';
                final isCorrect =
                    userAnswer.toLowerCase() == correctAnswer.toLowerCase();

                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      Icon(
                        isCorrect ? Icons.check_circle : Icons.cancel,
                        size: 16,
                        color: isCorrect ? AppTheme.success : AppTheme.error,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Plate ${index + 1}: ${isCorrect ? 'Correct' : 'Incorrect'} (Your: $userAnswer${!isCorrect ? ', Correct: $correctAnswer' : ''})',
                          style: const TextStyle(fontSize: AppTheme.fontXS),
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

  double? _resolveAlertnessPercent(Map<String, dynamic> test) {
    final raw =
        test['alertness_percentage'] ??
        test['alertness'] ??
        test['alertness_percent'] ??
        test['alertness_score'];
    if (raw is num) {
      return raw.toDouble();
    }
    if (raw is String) {
      final parsed = double.tryParse(raw);
      if (parsed != null) {
        return parsed;
      }
    }

    final probabilities = test['probabilities'];
    if (probabilities is Map) {
      final drowsy = probabilities['drowsy'];
      final notDrowsy = probabilities['notdrowsy'];
      if (drowsy is num) {
        return (1 - drowsy.toDouble()) * 100;
      }
      if (notDrowsy is num) {
        return notDrowsy.toDouble() * 100;
      }
    }

    final drowsyProb = test['drowsy_probability'];
    if (drowsyProb is num) {
      return (1 - drowsyProb.toDouble()) * 100;
    }

    return null;
  }

  String _resolveBlinkClassification(Map<String, dynamic> test) {
    final classification = test['classification'] ?? test['fatigue_level'];
    if (classification is String && classification.trim().isNotEmpty) {
      return classification;
    }

    final prediction = test['prediction'];
    if (prediction == 'notdrowsy') {
      return 'Alert';
    }
    if (prediction == 'drowsy') {
      return 'Drowsy';
    }
    return 'Unknown';
  }

  double? _resolveBlinkAvgBpm(Map<String, dynamic> test) {
    final raw =
        test['avg_blinks_per_minute'] ??
        test['blink_rate_per_minute'] ??
        test['blink_rate'];
    if (raw is num) {
      return raw.toDouble();
    }
    if (raw is String) {
      return double.tryParse(raw);
    }
    return null;
  }

  int? _resolveBlinkTotalBlinks(Map<String, dynamic> test) {
    final raw = test['total_blinks'] ?? test['blink_count'];
    if (raw is num) {
      return raw.toInt();
    }
    if (raw is String) {
      return int.tryParse(raw);
    }
    return null;
  }

  double? _resolveBlinkDuration(Map<String, dynamic> test) {
    final raw =
        test['duration_seconds'] ?? test['test_duration'] ?? test['duration'];
    if (raw is num) {
      return raw.toDouble();
    }
    if (raw is String) {
      return double.tryParse(raw);
    }
    return null;
  }

  Widget _buildBlinkFatigueTestCard(Map<String, dynamic> test) {
    final date = _formatDate(test['date'] ?? test['created_at'] ?? '');
    final classification = _resolveBlinkClassification(test);
    final alertness = _resolveAlertnessPercent(test);
    final avgBpm = _resolveBlinkAvgBpm(test);
    final duration = _resolveBlinkDuration(test);
    final totalBlinks = _resolveBlinkTotalBlinks(test);

    Color getClassificationColor(String classification) {
      switch (classification.toLowerCase()) {
        case 'alert':
          return AppTheme.success;
        case 'drowsy':
          return AppTheme.categoryOrange;
        case 'fatigue':
          return AppTheme.error;
        default:
          return AppTheme.textSecondary;
      }
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  date,
                  style: const TextStyle(
                    fontSize: AppTheme.fontSM,
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: getClassificationColor(
                    classification,
                  ).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  classification,
                  style: TextStyle(
                    fontSize: AppTheme.fontSM,
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
                child: _buildDetailItem(
                  'Alertness',
                  alertness != null
                      ? '${alertness.toStringAsFixed(0)}%'
                      : 'N/A',
                ),
              ),
              Expanded(
                child: _buildDetailItem(
                  'Avg BPM',
                  avgBpm != null ? avgBpm.toStringAsFixed(1) : 'N/A',
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildDetailItem(
                  'Total Blinks',
                  totalBlinks != null ? totalBlinks.toString() : 'N/A',
                ),
              ),
              Expanded(
                child: _buildDetailItem(
                  'Duration',
                  duration != null && duration > 0
                      ? '${duration.toStringAsFixed(0)}s'
                      : 'N/A',
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: (alertness ?? 0) / 100,
            backgroundColor: AppTheme.border,
            valueColor: AlwaysStoppedAnimation<Color>(
              getClassificationColor(classification),
            ),
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
            fontSize: AppTheme.fontXS,
            color: AppTheme.textSecondary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontSize: AppTheme.fontBody,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildHistoryTab() {
    // Combine all tests from different categories
    List<Map<String, dynamic>> allTests = [];

    // Add visual acuity tests
    for (var test in _visualAcuityTests) {
      final date = test['date'] ?? test['created_at'] ?? 'Unknown date';
      allTests.add({
        'title': 'Visual Acuity Test',
        'date': date,
        'score': test['score'] ?? 0,
        'timestamp': date,
      });
    }

    // Add colour vision tests
    for (var test in _colourVisionTests) {
      final date = test['date'] ?? test['created_at'] ?? 'Unknown date';
      final score =
          test['correct_count'] != null && test['total_plates'] != null
          ? ((test['correct_count'] / test['total_plates']) * 100).round()
          : test['score'] ?? 0;
      allTests.add({
        'title': 'Colour Vision Test',
        'date': date,
        'score': score,
        'timestamp': date,
      });
    }

    // Add eye tracking tests
    for (var test in _eyeTrackingTests) {
      final date = test['date'] ?? test['created_at'] ?? 'Unknown date';
      final score = (test['gaze_accuracy'] ?? 0).round();
      allTests.add({
        'title': 'Eye Tracking Test',
        'date': date,
        'score': score,
        'timestamp': date,
      });
    }

    // Add blink fatigue tests
    for (var test in _blinkFatigueTests) {
      final date = test['date'] ?? test['created_at'] ?? 'Unknown date';
      final alertness = _resolveAlertnessPercent(test);
      allTests.add({
        'title': 'Blink & Fatigue Test',
        'date': date,
        'score': alertness?.round() ?? 0,
        'timestamp': date,
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
                  color: AppTheme.categoryIndigoBg,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.history,
                  size: 48,
                  color: AppTheme.primary,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'No Test History',
                style: TextStyle(
                  fontSize: AppTheme.fontXL,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Complete some tests to see your history here',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: AppTheme.fontBody,
                  color: AppTheme.textSecondary,
                ),
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
            fontSize: AppTheme.fontLG,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        ...allTests.map(
          (test) => _buildHistoryItem(
            test['title'],
            _formatDate(test['date']),
            test['score'],
          ),
        ),
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
        color: AppTheme.surfaceLight,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.calendar_today,
            color: AppTheme.categoryBlue,
            size: 18,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: AppTheme.fontBody,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  date,
                  style: const TextStyle(
                    fontSize: AppTheme.fontSM,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Text(
            'Score: $score',
            style: const TextStyle(
              fontSize: AppTheme.fontBody,
              fontWeight: FontWeight.w600,
              color: AppTheme.success,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAIReportTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppTheme.categoryPurpleBg, AppTheme.categoryBlueBg],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppTheme.categoryPurple.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.categoryPurple.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.psychology,
                    color: AppTheme.categoryPurple,
                    size: 36,
                  ),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'AI Eye Health Report',
                        style: TextStyle(
                          fontSize: AppTheme.fontXL,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Powered by Google Gemini AI',
                        style: TextStyle(
                          fontSize: AppTheme.fontSM,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Generate button
          if (_aiReport == null && !_isGeneratingAIReport)
            ElevatedButton.icon(
              onPressed: _generateAIReport,
              icon: const Icon(Icons.auto_awesome),
              label: const Text('Generate AI Report'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: AppTheme.categoryPurple,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          // Loading state
          if (_isGeneratingAIReport)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Column(
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text(
                      'Analyzing your eye health data...',
                      style: TextStyle(color: AppTheme.textSecondary),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'This may take a few seconds',
                      style: TextStyle(
                        fontSize: AppTheme.fontSM,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          // Error state
          if (_aiReportError != null)
            Card(
              color: AppTheme.error.withValues(alpha: 0.08),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: AppTheme.error,
                      size: 32,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _aiReportError!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppTheme.error),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: _generateAIReport,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.error,
                      ),
                      child: const Text(
                        'Retry',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          // AI Report content
          if (_aiReport != null) ...[
            // Overall score card
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Overall Health Score',
                      style: TextStyle(
                        fontSize: AppTheme.fontBody,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Text(
                          '${_aiReport!['overall_score'] ?? '--'}',
                          style: const TextStyle(
                            fontSize: 48,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.categoryPurple,
                          ),
                        ),
                        const Text(
                          '/100',
                          style: TextStyle(
                            fontSize: AppTheme.fontXL,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.success.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${_aiReport!['health_status'] ?? 'N/A'}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: AppTheme.success,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (_aiReport!['scores'] != null) ...[
                      const Divider(height: 24),
                      ...(_aiReport!['scores'] as Map<String, dynamic>).entries
                          .map(
                            (e) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    e.key.replaceAll('_', ' ').toUpperCase(),
                                    style: const TextStyle(
                                      fontSize: AppTheme.fontSM,
                                      color: AppTheme.textSecondary,
                                    ),
                                  ),
                                  Text(
                                    '${e.value}/100',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            // AI Report text
            if (_aiReport!['ai_report_text'] != null)
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.article_outlined,
                            color: AppTheme.categoryPurple,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'AI Analysis',
                            style: TextStyle(
                              fontSize: AppTheme.fontBody,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 20),
                      Text(
                        '${_aiReport!['ai_report_text']}',
                        style: const TextStyle(
                          fontSize: AppTheme.fontBody,
                          color: AppTheme.textPrimary,
                          height: 1.6,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 12),
            // Findings
            if (_aiReport!['findings'] != null &&
                (_aiReport!['findings'] as Map).isNotEmpty)
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Key Findings',
                        style: TextStyle(
                          fontSize: AppTheme.fontBody,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const Divider(height: 20),
                      ...(_aiReport!['findings'] as Map<String, dynamic>)
                          .entries
                          .map(
                            (e) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(
                                    Icons.circle,
                                    size: 8,
                                    color: AppTheme.categoryPurple,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          e.key
                                              .replaceAll('_', ' ')
                                              .toUpperCase(),
                                          style: const TextStyle(
                                            fontSize: AppTheme.fontSM,
                                            fontWeight: FontWeight.w600,
                                            color: AppTheme.textSecondary,
                                          ),
                                        ),
                                        Text(
                                          '${e.value}',
                                          style: const TextStyle(
                                            color: AppTheme.textPrimary,
                                          ),
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
                ),
              ),
            const SizedBox(height: 16),
            // View Full Report button
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => _AIReportViewPage(
                      report: _aiReport!,
                      onDownloadPDF: _downloadAIPDF,
                      isDownloadingPDF: _isDownloadingAIPDF,
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.visibility),
              label: const Text('View Full Report'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: AppTheme.categoryPurple,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 8),
            // Download AI PDF button
            ElevatedButton.icon(
              onPressed: _isDownloadingAIPDF ? null : _downloadAIPDF,
              icon: _isDownloadingAIPDF
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.picture_as_pdf),
              label: Text(
                _isDownloadingAIPDF
                    ? 'Generating PDF...'
                    : 'Download AI Report PDF',
              ),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: AppTheme.categoryBlue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 8),
            // Regenerate button
            OutlinedButton.icon(
              onPressed: _isGeneratingAIReport ? null : _generateAIReport,
              icon: const Icon(Icons.refresh),
              label: const Text('Regenerate Report'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                side: const BorderSide(color: AppTheme.categoryPurple),
                foregroundColor: AppTheme.categoryPurple,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'AI-generated reports are for informational purposes only. Consult a qualified eye care professional for medical advice.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: AppTheme.fontXS,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
          ],
        ],
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
                side: const BorderSide(color: AppTheme.textSecondary, width: 2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _isSendingToDoctor ? null : _handleSendToDoctor,
              icon: _isSendingToDoctor
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.send),
              label: Text(_isSendingToDoctor ? 'Sending...' : 'Send to Doctor'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: AppTheme.categoryBlue,
                foregroundColor: Colors.white,
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

class _AIReportViewPage extends StatelessWidget {
  final Map<String, dynamic> report;
  final VoidCallback onDownloadPDF;
  final bool isDownloadingPDF;

  const _AIReportViewPage({
    required this.report,
    required this.onDownloadPDF,
    required this.isDownloadingPDF,
  });

  @override
  Widget build(BuildContext context) {
    final String reportText = report['ai_report_text'] ?? '';
    final double overallScore =
        (report['overall_score'] as num?)?.toDouble() ?? 0;
    final String healthStatus = report['health_status'] ?? '';
    final Map<String, dynamic> scores =
        (report['scores'] as Map<String, dynamic>?) ?? {};
    final String generationDate = report['generation_date'] ?? '';

    // Parse sections: lines ending with ':' that are all-caps are headers
    final List<Map<String, String>> sections = [];
    String currentHeader = '';
    final StringBuffer currentBody = StringBuffer();
    for (final line in reportText.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.isNotEmpty &&
          trimmed.endsWith(':') &&
          trimmed == trimmed.toUpperCase()) {
        if (currentHeader.isNotEmpty || currentBody.isNotEmpty) {
          sections.add({
            'header': currentHeader,
            'body': currentBody.toString().trim(),
          });
          currentBody.clear();
        }
        currentHeader = trimmed.replaceAll(':', '');
      } else {
        if (trimmed.isNotEmpty) currentBody.writeln(line);
      }
    }
    if (currentHeader.isNotEmpty || currentBody.isNotEmpty) {
      sections.add({
        'header': currentHeader,
        'body': currentBody.toString().trim(),
      });
    }
    // If no sections parsed, treat entire text as one block
    if (sections.isEmpty && reportText.isNotEmpty) {
      sections.add({'header': '', 'body': reportText});
    }

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'AI Eye Health Report',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Download PDF',
            icon: isDownloadingPDF
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(
                    Icons.picture_as_pdf,
                    color: AppTheme.categoryBlue,
                  ),
            onPressed: isDownloadingPDF ? null : onDownloadPDF,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Report header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppTheme.categoryPurpleBg, AppTheme.categoryBlueBg],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppTheme.categoryPurple.withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.psychology,
                        color: AppTheme.categoryPurple,
                        size: 28,
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'NetraCare AI Report',
                          style: TextStyle(
                            fontSize: AppTheme.fontXL,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (generationDate.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Generated: ${generationDate.split('T').first}',
                      style: const TextStyle(
                        fontSize: AppTheme.fontSM,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Text(
                        overallScore.toStringAsFixed(0),
                        style: const TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.categoryPurple,
                        ),
                      ),
                      const Text(
                        '/100',
                        style: TextStyle(
                          fontSize: AppTheme.fontXL,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      const Spacer(),
                      if (healthStatus.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.success.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            healthStatus,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: AppTheme.success,
                            ),
                          ),
                        ),
                    ],
                  ),
                  if (scores.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    const Divider(height: 1),
                    const SizedBox(height: 12),
                    ...scores.entries.map(
                      (e) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                e.key.replaceAll('_', ' ').toUpperCase(),
                                style: const TextStyle(
                                  fontSize: AppTheme.fontSM,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                            ),
                            Text(
                              '${e.value}/100',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),
            // Report sections
            ...sections.map(
              (section) => Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Card(
                  elevation: 0,
                  color: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: Colors.grey.withValues(alpha: 0.15),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (section['header']!.isNotEmpty) ...[
                          Text(
                            section['header']!,
                            style: const TextStyle(
                              fontSize: AppTheme.fontBody,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.categoryPurple,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const Divider(height: 16),
                        ],
                        Text(
                          section['body']!,
                          style: const TextStyle(
                            fontSize: AppTheme.fontBody,
                            color: AppTheme.textPrimary,
                            height: 1.7,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            // Download button at bottom
            ElevatedButton.icon(
              onPressed: isDownloadingPDF ? null : onDownloadPDF,
              icon: isDownloadingPDF
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.picture_as_pdf),
              label: Text(
                isDownloadingPDF
                    ? 'Generating PDF...'
                    : 'Download AI Report PDF',
              ),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: AppTheme.categoryBlue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'AI-generated reports are for informational purposes only. Consult a qualified eye care professional for medical advice.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: AppTheme.fontXS,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Doctor picker dialog — shown when patient taps "Send to Doctor"
// ---------------------------------------------------------------------------
class _DoctorPickerDialog extends StatelessWidget {
  final List<Map<String, dynamic>> doctors;
  const _DoctorPickerDialog({required this.doctors});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Select Doctor'),
      contentPadding: const EdgeInsets.symmetric(vertical: 12),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView.separated(
          shrinkWrap: true,
          itemCount: doctors.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (ctx, i) {
            final doc = doctors[i];
            final name = doc['name'] as String? ?? 'Unknown';
            final spec = doc['specialization'] as String? ?? 'Ophthalmology';
            final place = doc['working_place'] as String? ?? '';
            final available = doc['is_available'] as bool? ?? true;
            return ListTile(
              leading: CircleAvatar(
                backgroundColor: AppTheme.categoryBlue.withValues(alpha: 0.15),
                child: const Icon(Icons.person, color: AppTheme.categoryBlue),
              ),
              title: Text(
                'Dr. $name',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                [spec, if (place.isNotEmpty) place].join(' · '),
                style: const TextStyle(
                  fontSize: AppTheme.fontSM,
                  color: AppTheme.textSecondary,
                ),
              ),
              trailing: available
                  ? null
                  : const Chip(
                      label: Text(
                        'Unavailable',
                        style: TextStyle(fontSize: 10),
                      ),
                    ),
              onTap: () => Navigator.of(ctx).pop(doc),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}
