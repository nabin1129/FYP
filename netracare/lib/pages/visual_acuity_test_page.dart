import 'dart:math';
import 'package:flutter/material.dart';
import 'package:netracare/services/api_service.dart';

class VisualAcuityTestPage extends StatefulWidget {
  const VisualAcuityTestPage({super.key});

  @override
  State<VisualAcuityTestPage> createState() => _VisualAcuityTestPageState();
}

class _VisualAcuityTestPageState extends State<VisualAcuityTestPage> {
  bool cameraReady = false;
  bool isSubmitting = false;

  final List<String> letters = ['E', 'F', 'P', 'T', 'O', 'Z', 'L', 'D'];
  String currentLetter = 'E';
  double fontSize = 80;

  int total = 0;
  int correct = 0;

  @override
  void initState() {
    super.initState();
    _initTest();
  }

  Future<void> _initTest() async {
    try {
      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) {
        setState(() => cameraReady = true);
        _nextLetter();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Test initialization failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _nextLetter() {
    if (mounted) {
      setState(() {
        currentLetter = letters[Random().nextInt(letters.length)];
        fontSize = max(30, fontSize - 6);
      });
    }
  }

  void _submitAnswer(String answer) {
    if (isSubmitting) return;

    total++;
    if (answer == currentLetter) correct++;

    if (total >= 10) {
      _showResult();
    } else {
      _nextLetter();
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
                  color: _getSeverityColor(result.severity).withOpacity(0.1),
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
                _nextLetter();
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
                _nextLetter();
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
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color ?? Colors.black87,
          ),
        ),
      ],
    );
  }

  Color _getSeverityColor(String severity) {
    switch (severity) {
      case "Normal":
        return Colors.green;
      case "Mild Vision Loss":
        return Colors.orange;
      case "Moderate Vision Loss":
        return Colors.deepOrange;
      case "Severe Vision Loss":
        return Colors.red;
      default:
        return Colors.grey;
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

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text("Visual Acuity Test"),
        backgroundColor: Colors.white,
        elevation: 1,
        titleTextStyle: const TextStyle(
          color: Colors.black87,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
        iconTheme: const IconThemeData(color: Colors.black87),
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
                            color: Colors.black.withOpacity(0.05),
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
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black54,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.blue.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  "$total/10",
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue,
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
                              backgroundColor: Colors.grey.shade200,
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                Colors.blue,
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
                            color: Colors.black.withOpacity(0.08),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          currentLetter,
                          style: TextStyle(
                            fontSize: fontSize,
                            color: const Color(0xFF1F2937),
                            fontWeight: FontWeight.w700,
                            fontFamily: 'Courier New',
                            letterSpacing: 2,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Instructions
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.blue.withOpacity(0.2),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info,
                            color: Colors.blue.shade600,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Select the letter displayed above',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.blue.shade700,
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
                            Colors.blue,
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
                            color: Colors.black.withOpacity(0.05),
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
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.black54,
                            ),
                          ),
                          const SizedBox(height: 16),
                          GridView.count(
                            crossAxisCount: isMobile ? 4 : 4,
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            mainAxisSpacing: 12,
                            crossAxisSpacing: 12,
                            children: letters.map((l) {
                              return Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: isSubmitting
                                      ? null
                                      : () => _submitAnswer(l),
                                  borderRadius: BorderRadius.circular(12),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.blue.withOpacity(0.08),
                                      border: Border.all(
                                        color: Colors.blue.withOpacity(0.3),
                                        width: 2,
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Center(
                                      child: Text(
                                        l,
                                        style: const TextStyle(
                                          fontSize: 22,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.blue,
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
                valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
              ),
            ),
    );
  }
}
