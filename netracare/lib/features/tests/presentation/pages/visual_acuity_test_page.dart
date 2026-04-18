import 'dart:math';
import 'package:flutter/material.dart';
import 'package:netracare/config/app_theme.dart';
import 'package:netracare/services/api_service.dart';
import 'package:netracare/models/distance_calibration_model.dart';
import 'package:netracare/widgets/distance_monitor_widget.dart';
import 'package:netracare/widgets/distance_feedback_overlay.dart';
import 'package:netracare/features/tests/presentation/pages/visual_acuity_variant.dart';

class VisualAcuityTestPage extends StatefulWidget {
  final VisualAcuityVariant variant;

  const VisualAcuityTestPage({super.key, required this.variant});

  @override
  State<VisualAcuityTestPage> createState() => _VisualAcuityTestPageState();
}

class _VisualAcuityTestPageState extends State<VisualAcuityTestPage> {
  bool cameraReady = false;
  bool isSubmitting = false;
  bool isTestPaused = false;
  DistanceCalibrationData? calibration;
  bool isLoadingCalibration = true;

  late VisualAcuityQuestion currentQuestion;
  double fontSize = 80;

  int total = 0;
  int correct = 0;

  @override
  void initState() {
    super.initState();
    _loadCalibration();
  }

  Future<void> _loadCalibration() async {
    try {
      final cal = await ApiService.getActiveCalibration();

      if (cal == null && mounted) {
        // No calibration exists - proceed without distance monitoring
        debugPrint(
          'No calibration found - proceeding without distance monitoring',
        );
        setState(() {
          calibration = null;
          isLoadingCalibration = false;
        });
        _initTest();
      } else {
        debugPrint('Calibration loaded successfully');
        setState(() {
          calibration = cal;
          isLoadingCalibration = false;
        });
        _initTest();
      }
    } catch (e) {
      // Error loading - proceed without distance enforcement
      debugPrint('Error loading calibration: $e');
      if (mounted) {
        setState(() {
          calibration = null;
          isLoadingCalibration = false;
        });
        // Show brief notice to user
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Distance monitoring unavailable. Test will proceed without distance validation.',
            ),
            duration: Duration(seconds: 3),
            backgroundColor: AppTheme.warning,
          ),
        );
        _initTest();
      }
    }
  }

  Future<void> _initTest() async {
    try {
      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) {
        setState(() => cameraReady = true);
        _nextQuestion();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Test initialization failed: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  void _handleTestPaused() {
    setState(() {
      isTestPaused = true;
    });
  }

  void _handleTestResumed() {
    setState(() {
      isTestPaused = false;
    });
  }

  void _nextQuestion() {
    if (mounted) {
      setState(() {
        currentQuestion = VisualAcuityQuestion.generate(
          widget.variant,
          Random(),
        );
        fontSize = max(30, fontSize - 6);
      });
    }
  }

  void _submitAnswer(String answer) {
    if (isSubmitting || isTestPaused) return; // Block if test is paused

    total++;
    if (answer == currentQuestion.expectedAnswer) correct++;

    if (total >= 10) {
      _showResult();
    } else {
      _nextQuestion();
    }
  }

  Future<void> _showResult() async {
    setState(() {
      isSubmitting = true;
    });

    try {
      // Call backend API with DA model integration
      final result = await ApiService.submitVisualAcuityTest(
        correct: correct,
        total: total,
        testVariant: widget.variant.apiValue,
      );

      if (!mounted) return;

      // Show results dialog with backend analysis
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          title: const Text(
            "Visual Acuity Test Results",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _resultRow("Correct Answers", "$correct / $total"),
              const SizedBox(height: 12),
              _resultRow("Test Type", widget.variant.title),
              const SizedBox(height: 12),
              _resultRow("logMAR Score", result.logMAR.toStringAsFixed(2)),
              const SizedBox(height: 12),
              _resultRow("Snellen Equivalent", result.snellen),
              const SizedBox(height: 12),
              _resultRow(
                "Severity",
                result.severity,
                color: _getSeverityColor(result.severity),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _getSeverityColor(
                    result.severity,
                  ).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      _getSeverityIcon(result.severity),
                      color: _getSeverityColor(result.severity),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _getSeverityMessage(result.severity),
                        style: TextStyle(
                          color: _getSeverityColor(result.severity),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context); // Close dialog
                Navigator.popUntil(
                  context,
                  (route) => route.isFirst,
                ); // Go to home page
              },
              child: const Text("Save Results"),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context); // Close dialog
                setState(() {
                  total = 0;
                  correct = 0;
                  isSubmitting = false;
                });
                _nextQuestion();
              },
              child: const Text("Retry Test"),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context); // Close dialog
                Navigator.popUntil(context, (route) => route.isFirst);
              },
              child: const Text("Back to Home"),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;

      // Show error dialog
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text("Error"),
          content: Text(e.toString().replaceAll('Exception:', '').trim()),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context); // Close error dialog
                setState(() {
                  total = 0;
                  correct = 0;
                  isSubmitting = false;
                });
                _nextQuestion();
              },
              child: const Text("Retry Test"),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context); // Close error dialog
                Navigator.popUntil(context, (route) => route.isFirst);
              },
              child: const Text("Back to Home"),
            ),
          ],
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          isSubmitting = false;
        });
      }
    }
  }

  Widget _resultRow(String label, String value, {Color? color}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: AppTheme.fontLG,
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: AppTheme.fontLG,
            fontWeight: FontWeight.bold,
            color: color ?? AppTheme.textPrimary,
          ),
        ),
      ],
    );
  }

  Color _getSeverityColor(String severity) {
    switch (severity) {
      case "Normal":
        return AppTheme.success;
      case "Mild Vision Loss":
        return AppTheme.warning;
      case "Moderate Vision Loss":
        return AppTheme.warning;
      case "Severe Vision Loss":
        return AppTheme.error;
      default:
        return AppTheme.textSecondary;
    }
  }

  IconData _getSeverityIcon(String severity) {
    switch (severity) {
      case "Normal":
        return Icons.check_circle;
      case "Mild Vision Loss":
        return Icons.warning;
      case "Moderate Vision Loss":
        return Icons.warning_amber;
      case "Severe Vision Loss":
        return Icons.error;
      default:
        return Icons.info;
    }
  }

  String _getSeverityMessage(String severity) {
    switch (severity) {
      case "Normal":
        return "Your vision appears to be within normal range.";
      case "Mild Vision Loss":
        return "You may have mild vision impairment. Consider consulting an eye care professional.";
      case "Moderate Vision Loss":
        return "Moderate vision loss detected. Please consult an eye care professional soon.";
      case "Severe Vision Loss":
        return "Severe vision loss detected. Please consult an eye care professional immediately.";
      default:
        return "Please consult an eye care professional for detailed analysis.";
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    if (isLoadingCalibration) {
      return Scaffold(
        backgroundColor: AppTheme.background,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 20),
              const Text(
                'Preparing Visual Acuity Test...',
                style: TextStyle(
                  fontSize: AppTheme.fontLG,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Loading distance calibration',
                style: TextStyle(
                  fontSize: AppTheme.fontBody,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      );
    }

    Widget testContent = Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text("Visual Acuity Test"),
        backgroundColor: Colors.white,
        elevation: 1,
        titleTextStyle: const TextStyle(
          color: AppTheme.textPrimary,
          fontSize: AppTheme.fontXXL,
          fontWeight: FontWeight.w600,
        ),
        iconTheme: const IconThemeData(color: AppTheme.textPrimary),
      ),
      body: cameraReady
          ? SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 20,
                ),
                child: Column(
                  children: [
                    // Progress Section
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                "Progress",
                                style: TextStyle(
                                  fontSize: AppTheme.fontBody,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: AppTheme.primary.withValues(
                                    alpha: 0.1,
                                  ),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  "$total/10",
                                  style: const TextStyle(
                                    fontSize: AppTheme.fontBody,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.primary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: LinearProgressIndicator(
                              value: total / 10,
                              minHeight: 8,
                              backgroundColor: AppTheme.border,
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                AppTheme.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Distance Monitoring Status
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: calibration != null
                            ? AppTheme.success.withValues(alpha: 0.1)
                            : AppTheme.warning.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: calibration != null
                              ? AppTheme.success.withValues(alpha: 0.3)
                              : AppTheme.warning.withValues(alpha: 0.3),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            calibration != null
                                ? Icons.verified_user
                                : Icons.info_outline,
                            size: 16,
                            color: calibration != null
                                ? AppTheme.success
                                : AppTheme.warning,
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              calibration != null
                                  ? 'Distance monitoring active'
                                  : 'Testing without distance monitoring',
                              style: TextStyle(
                                fontSize: AppTheme.fontSM,
                                fontWeight: FontWeight.w500,
                                color: calibration != null
                                    ? AppTheme.success
                                    : AppTheme.warning,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Letter Display Area
                    Container(
                      width: double.infinity,
                      height: MediaQuery.of(context).size.height * 0.35,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Center(
                        child: VisualAcuityStimulus(
                          question: currentQuestion,
                          fontSize: fontSize,
                        ),
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Instructions
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: AppTheme.primary.withValues(alpha: 0.2),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info, color: AppTheme.primary, size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              widget.variant.answerPrompt,
                              style: TextStyle(
                                fontSize: AppTheme.fontSM,
                                color: AppTheme.primary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 28),

                    // Answer Buttons
                    if (isSubmitting)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 16),
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(
                            AppTheme.primary,
                          ),
                        ),
                      ),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Text(
                            "Select your answer",
                            style: TextStyle(
                              fontSize: AppTheme.fontBody,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 16),
                          GridView.count(
                            crossAxisCount: isMobile ? 4 : 4,
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            mainAxisSpacing: 12,
                            crossAxisSpacing: 12,
                            children: widget.variant.answerOptions.map((
                              option,
                            ) {
                              return Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: isSubmitting
                                      ? null
                                      : () => _submitAnswer(option),
                                  borderRadius: BorderRadius.circular(12),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: AppTheme.primary.withValues(
                                        alpha: 0.08,
                                      ),
                                      border: Border.all(
                                        color: AppTheme.primary.withValues(
                                          alpha: 0.3,
                                        ),
                                        width: 2,
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Center(
                                      child: Text(
                                        _optionLabel(option),
                                        style: const TextStyle(
                                          fontSize: AppTheme.fontTitle,
                                          fontWeight: FontWeight.bold,
                                          color: AppTheme.primary,
                                          fontFamily: 'Courier New',
                                          letterSpacing: 1,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            )
          : const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primary),
              ),
            ),
    );

    // Wrap with distance monitoring if calibration exists
    if (calibration != null) {
      return DistanceMonitorWidget(
        calibrationData: calibration!,
        continuousMonitoring: true,
        showFaceGuide: false, // Don't show face guide during test
        showFeedbackOverlay: true,
        overlayPosition: OverlayPosition.top,
        onTestPaused: _handleTestPaused,
        onTestResumed: _handleTestResumed,
        child: testContent,
      );
    }

    // Return test without distance monitoring if no calibration
    return testContent;
  }

  String _optionLabel(String option) {
    switch (option) {
      case 'up':
        return '↑';
      case 'right':
        return '→';
      case 'down':
        return '↓';
      case 'left':
        return '←';
      default:
        return option;
    }
  }
}
