import 'package:flutter/material.dart';
import '../../models/test_models.dart';
import '../../config/app_theme.dart';
import '../../config/test_config.dart';
import 'camera_test_page.dart';

/// Test Selection Page
///
/// Main entry point for all eye tests.
/// Routes to camera-based testing in test mode or existing pages in production.
class TestSelectionPage extends StatelessWidget {
  const TestSelectionPage({super.key});

  Future<void> _startTest(BuildContext context, TestType testType) async {
    if (TestConfig.isTestMode && TestConfig.enableWebcam) {
      // Use camera test page for laptop testing
      final result = await Navigator.push<TestResult>(
        context,
        MaterialPageRoute(
          builder: (context) => CameraTestPage(testType: testType),
        ),
      );

      if (result != null && context.mounted) {
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Test completed! Score: ${result.score?.toStringAsFixed(1) ?? "N/A"}%',
                  ),
                ),
              ],
            ),
            backgroundColor: AppTheme.success,
            duration: const Duration(seconds: 3),
            action: SnackBarAction(
              label: 'View',
              textColor: Colors.white,
              onPressed: () {
                _showResultDialog(context, result);
              },
            ),
          ),
        );
      }
    } else {
      // Production mode - navigate to existing test pages
      _navigateToProductionTest(context, testType);
    }
  }

  void _navigateToProductionTest(BuildContext context, TestType testType) {
    // TODO: Navigate to existing production test pages
    // This is where you'd route to your existing test pages
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Production mode: Use existing test pages'),
        backgroundColor: AppTheme.warning,
      ),
    );
  }

  void _showResultDialog(BuildContext context, TestResult result) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.assessment, color: AppTheme.primary),
            const SizedBox(width: 8),
            const Text('Test Results'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildResultRow('Test Type', result.testType.displayName),
              const SizedBox(height: 8),
              _buildResultRow(
                'Score',
                '${result.score?.toStringAsFixed(1) ?? "N/A"}%',
              ),
              const SizedBox(height: 8),
              _buildResultRow(
                'Diagnosis',
                result.diagnosis ?? 'No diagnosis available',
              ),
              if (result.recommendations != null &&
                  result.recommendations!.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text(
                  'Recommendations:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                ...result.recommendations!.map(
                  (rec) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('• ', style: TextStyle(fontSize: 16)),
                        Expanded(child: Text(rec)),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildResultRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 90,
          child: Text(
            '$label:',
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: AppTheme.textLight,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              color: AppTheme.textDark,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Eye Tests'),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppTheme.spacingMD),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Test Mode Banner
              if (TestConfig.isTestMode)
                Container(
                  padding: const EdgeInsets.all(AppTheme.spacingMD),
                  margin: const EdgeInsets.only(bottom: AppTheme.spacingLG),
                  decoration: BoxDecoration(
                    color: AppTheme.warning.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                    border: Border.all(
                      color: AppTheme.warning,
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.science,
                        color: AppTheme.warning,
                        size: 28,
                      ),
                      const SizedBox(width: AppTheme.spacingSM),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Test Mode Active',
                              style: TextStyle(
                                color: AppTheme.textDark,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Using laptop webcam for testing',
                              style: TextStyle(
                                color: AppTheme.textLight,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

              // Header
              const Text(
                'Available Eye Tests',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textDark,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Select a test to begin assessment',
                style: TextStyle(
                  fontSize: 14,
                  color: AppTheme.textLight,
                ),
              ),
              const SizedBox(height: AppTheme.spacingLG),

              // Test Cards
              _buildTestCard(
                context,
                TestType.visualAcuity,
                Icons.remove_red_eye,
                AppTheme.primary,
              ),
              _buildTestCard(
                context,
                TestType.colorBlindness,
                Icons.palette,
                const Color(0xFFE91E63),
              ),
              _buildTestCard(
                context,
                TestType.astigmatism,
                Icons.visibility,
                const Color(0xFF9C27B0),
              ),
              _buildTestCard(
                context,
                TestType.contrastSensitivity,
                Icons.contrast,
                const Color(0xFF3F51B5),
              ),
              _buildTestCard(
                context,
                TestType.eyeTracking,
                Icons.track_changes,
                const Color(0xFF00BCD4),
              ),
              _buildTestCard(
                context,
                TestType.pupilResponse,
                Icons.light_mode,
                const Color(0xFFFF9800),
              ),
              _buildTestCard(
                context,
                TestType.fatigue,
                Icons.timer,
                const Color(0xFFF44336),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTestCard(
    BuildContext context,
    TestType testType,
    IconData icon,
    Color color,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppTheme.spacingMD),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
      ),
      child: InkWell(
        onTap: () => _startTest(context, testType),
        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacingMD),
          child: Row(
            children: [
              // Icon Container
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 32,
                ),
              ),
              const SizedBox(width: AppTheme.spacingMD),
              
              // Text Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      testType.displayName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textDark,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      testType.description,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppTheme.textLight,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              
              // Arrow
              const Icon(
                Icons.arrow_forward_ios,
                size: 18,
                color: AppTheme.textLight,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
