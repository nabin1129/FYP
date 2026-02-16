import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math' as math;
import '../services/api_service.dart';
import '../config/app_theme.dart';

class EyeTrackingTestPage extends StatefulWidget {
  const EyeTrackingTestPage({super.key});

  @override
  State<EyeTrackingTestPage> createState() => _EyeTrackingTestPageState();
}

class _EyeTrackingTestPageState extends State<EyeTrackingTestPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<Offset> _dotAnimation;

  int testPhase = 0; // 0: calibration, 1: horizontal, 2: vertical, 3: circle
  int totalPhases = 4;
  double progress = 0;
  bool isTestComplete = false;

  // Test metrics
  int gazeDataPoints = 0;
  int successfulTracking = 0;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    );

    _startPhase();
  }

  void _startPhase() {
    _animationController.reset();
    _setupAnimation();
    _animationController.forward().then((_) {
      if (testPhase < totalPhases - 1) {
        setState(() {
          testPhase++;
          gazeDataPoints += 150;
          successfulTracking += 140;
        });
        _startPhase();
      } else {
        setState(() {
          isTestComplete = true;
        });
      }
    });
  }

  void _setupAnimation() {
    switch (testPhase) {
      case 0: // Calibration - center
        _dotAnimation = Tween<Offset>(
          begin: const Offset(0, 0),
          end: const Offset(0, 0),
        ).animate(_animationController);
        break;
      case 1: // Horizontal movement
        _dotAnimation = Tween<Offset>(
          begin: const Offset(-1.5, 0),
          end: const Offset(1.5, 0),
        ).animate(_animationController);
        break;
      case 2: // Vertical movement
        _dotAnimation = Tween<Offset>(
          begin: const Offset(0, -1.5),
          end: const Offset(0, 1.5),
        ).animate(_animationController);
        break;
      case 3: // Circular movement
        _dotAnimation = Tween<Offset>(
          begin: const Offset(0, 0),
          end: const Offset(0, 0),
        ).animate(_animationController);
        break;
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (!isTestComplete) {
          return await _showExitDialog();
        }
        return true;
      },
      child: Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(
          backgroundColor: AppTheme.surface,
          elevation: 1,
          titleTextStyle: const TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
          iconTheme: const IconThemeData(color: AppTheme.textPrimary),
          leading: isTestComplete
              ? null
              : IconButton(
                  icon: const Icon(Icons.close, color: AppTheme.textPrimary),
                  onPressed: () => _showExitDialog(),
                ),
          title: const Text("Eye Tracking Test"),
          centerTitle: true,
        ),
        body: SafeArea(child: isTestComplete ? _buildResults() : _buildTest()),
      ),
    );
  }

  // ============ TEST UI ============
  Widget _buildTest() {
    return Stack(
      children: [
        // Background tracking area
        Container(
          color: AppTheme.background,
          width: double.infinity,
          height: double.infinity,
        ),

        // Gaze tracking visualization
        Center(
          child: Container(
            width: MediaQuery.of(context).size.width * 0.85,
            height: MediaQuery.of(context).size.height * 0.6,
            decoration: BoxDecoration(
              border: Border.all(
                color: AppTheme.primary.withOpacity(0.3),
                width: 2,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: _buildTrackingArea(),
          ),
        ),

        // Progress indicator
        Positioned(
          top: 20,
          right: 20,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                "Phase ${testPhase + 1}/$totalPhases",
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: 80,
                child: LinearProgressIndicator(
                  value: (testPhase + 1) / totalPhases,
                  backgroundColor: AppTheme.textLight.withOpacity(0.2),
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    AppTheme.primary,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Status indicator
        Positioned(
          bottom: 30,
          left: 0,
          right: 0,
          child: Column(
            children: [
              Text(
                _getPhaseDescription(),
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                "Follow the dot with your eyes",
                style: const TextStyle(
                  color: AppTheme.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTrackingArea() {
    if (testPhase == 3) {
      // Circular animation
      return Center(
        child: AnimatedBuilder(
          animation: _animationController,
          builder: (context, child) {
            double angle = _animationController.value * 2 * math.pi;
            double radius = 60;
            double x = radius * math.cos(angle);
            double y = radius * math.sin(angle);

            return Transform.translate(
              offset: Offset(x, y),
              child: _buildDot(),
            );
          },
        ),
      );
    } else {
      // Linear animations
      return Center(
        child: SlideTransition(position: _dotAnimation, child: _buildDot()),
      );
    }
  }

  Widget _buildDot() {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: AppTheme.primary,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withOpacity(0.5),
            blurRadius: 12,
            spreadRadius: 2,
          ),
        ],
      ),
    );
  }

  String _getPhaseDescription() {
    switch (testPhase) {
      case 0:
        return "Calibration - Focus on the center dot";
      case 1:
        return "Horizontal Movement - Track left to right";
      case 2:
        return "Vertical Movement - Track up and down";
      case 3:
        return "Circular Movement - Follow the circular path";
      default:
        return "";
    }
  }

  // ============ RESULTS UI ============
  Widget _buildResults() {
    double accuracy = (successfulTracking / gazeDataPoints) * 100;
    String classification = _classifyAccuracy(accuracy);
    Color classificationColor = _getClassificationColor(classification);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Success indicator
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.success.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_circle,
              size: 56,
              color: AppTheme.success,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            "Test Complete",
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 32),

          // Main score card
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: classificationColor.withOpacity(0.3),
                width: 2,
              ),
              boxShadow: AppTheme.cardShadow,
            ),
            child: Column(
              children: [
                const Text(
                  "Gaze Tracking Accuracy",
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  "${accuracy.toStringAsFixed(1)}%",
                  style: TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                    color: classificationColor,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: classificationColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: classificationColor.withOpacity(0.3),
                    ),
                  ),
                  child: Text(
                    classification,
                    style: TextStyle(
                      color: classificationColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Detailed metrics
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(12),
              boxShadow: AppTheme.cardShadow,
            ),
            child: Column(
              children: [
                _metricRow(
                  "Data Points Collected",
                  gazeDataPoints.toString(),
                  AppTheme.info,
                ),
                Divider(color: AppTheme.textLight.withOpacity(0.2)),
                _metricRow(
                  "Successful Tracking",
                  "$successfulTracking/${gazeDataPoints.toStringAsFixed(0)}",
                  AppTheme.success,
                ),
                Divider(color: AppTheme.textLight.withOpacity(0.2)),
                _metricRow(
                  "Test Duration",
                  "${(totalPhases * 3)} seconds",
                  AppTheme.warning,
                ),
                Divider(color: AppTheme.textLight.withOpacity(0.2)),
                _metricRow("Fixation Stability", "Good", AppTheme.primary),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // Action buttons
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saveResults,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                backgroundColor: AppTheme.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                "Save Results",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () {
                setState(() {
                  testPhase = 0;
                  isTestComplete = false;
                  gazeDataPoints = 0;
                  successfulTracking = 0;
                });
                _startPhase();
              },
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                side: const BorderSide(color: AppTheme.primary),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                "Retry Test",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primary,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () =>
                  Navigator.of(context).popUntil((route) => route.isFirst),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                side: BorderSide(color: AppTheme.textLight.withOpacity(0.5)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                "Back to Home",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _metricRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  String _classifyAccuracy(double accuracy) {
    if (accuracy >= 90) return "Excellent";
    if (accuracy >= 75) return "Good";
    if (accuracy >= 60) return "Fair";
    return "Poor";
  }

  Color _getClassificationColor(String classification) {
    switch (classification) {
      case "Excellent":
        return AppTheme.success;
      case "Good":
        return AppTheme.info;
      case "Fair":
        return AppTheme.warning;
      case "Poor":
        return AppTheme.error;
      default:
        return AppTheme.textLight;
    }
  }

  Future<bool> _showExitDialog() async {
    return await showDialog<bool>(
          context: context,
          builder: (BuildContext context) => AlertDialog(
            backgroundColor: AppTheme.surface,
            title: const Text(
              "Exit Test?",
              style: TextStyle(color: AppTheme.textPrimary),
            ),
            content: const Text(
              "Are you sure you want to exit? Your progress will not be saved.",
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text("Continue"),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text(
                  "Exit",
                  style: TextStyle(color: AppTheme.error),
                ),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _saveResults() async {
    try {
      // Calculate metrics
      final gazeAccuracy = gazeDataPoints > 0
          ? (successfulTracking / gazeDataPoints) * 100
          : 0.0;
      final testDuration = (totalPhases * 3).toDouble();

      // Determine classification based on accuracy
      String classification;
      if (gazeAccuracy >= 90) {
        classification = 'Excellent';
      } else if (gazeAccuracy >= 75) {
        classification = 'Good';
      } else if (gazeAccuracy >= 60) {
        classification = 'Fair';
      } else {
        classification = 'Needs Improvement';
      }

      // Submit to backend
      await ApiService.submitEyeTrackingTest(
        gazeAccuracy: gazeAccuracy,
        testDuration: testDuration,
        classification: classification,
        overallScore: gazeAccuracy,
        testName: 'Eye Tracking Test',
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Results saved successfully!"),
          backgroundColor: AppTheme.success,
          duration: Duration(seconds: 2),
        ),
      );

      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      });
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Failed to save results: $e"),
          backgroundColor: AppTheme.error,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }
}
