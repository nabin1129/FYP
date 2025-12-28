import 'dart:math';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:netracare/services/api_service.dart';
import 'package:netracare/models/user_model.dart';

class VisualAcuityTestPage extends StatefulWidget {
  const VisualAcuityTestPage({super.key});

  @override
  State<VisualAcuityTestPage> createState() => _VisualAcuityTestPageState();
}

class _VisualAcuityTestPageState extends State<VisualAcuityTestPage> {
  CameraController? _controller;
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
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      _controller = CameraController(
        cameras.first,
        ResolutionPreset.medium,
        enableAudio: false,
      );

      await _controller!.initialize();
      if (mounted) {
        setState(() => cameraReady = true);
        _nextLetter();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Camera initialization failed: $e'),
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
                Navigator.pop(context); // Go back to previous page
              },
              child: const Text("Done"),
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
          content: Text(
            e.toString().replaceAll('Exception:', '').trim(),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context); // Close error dialog
                Navigator.pop(context); // Go back to previous page
              },
              child: const Text("OK"),
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
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
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
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("Visual Acuity Test"),
        backgroundColor: Colors.black,
      ),
      body: cameraReady
          ? Stack(
              children: [
                CameraPreview(_controller!),

                // Progress indicator
                Positioned(
                  top: 16,
                  left: 16,
                  right: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.visibility, color: Colors.white, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: LinearProgressIndicator(
                            value: total / 10,
                            backgroundColor: Colors.grey.shade700,
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          "$total/10",
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Current letter display
                Center(
                  child: Text(
                    currentLetter,
                    style: TextStyle(
                      fontSize: fontSize,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      shadows: [
                        Shadow(
                          offset: const Offset(2, 2),
                          blurRadius: 4,
                          color: Colors.black.withOpacity(0.8),
                        ),
                      ],
                    ),
                  ),
                ),

                // Answer buttons
                Align(
                  alignment: Alignment.bottomCenter,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(0.8),
                        ],
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isSubmitting)
                          const Padding(
                            padding: EdgeInsets.only(bottom: 16),
                            child: CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          ),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: letters.map((l) {
                            return ElevatedButton(
                              onPressed: isSubmitting ? null : () => _submitAnswer(l),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white.withOpacity(0.9),
                                foregroundColor: Colors.black,
                                minimumSize: const Size(50, 50),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: Text(
                                l,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            )
          : const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
    );
  }
}
