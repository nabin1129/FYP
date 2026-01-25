import 'package:flutter/material.dart';
import 'dart:async';
import '../services/api_service.dart';

class IshiharaPlate {
  final int id;
  final int plateNumber;
  final String imagePath;
  final String correctAnswer;
  final List<String> options;
  final String description;

  IshiharaPlate({
    required this.id,
    required this.plateNumber,
    required this.imagePath,
    required this.correctAnswer,
    required this.options,
    required this.description,
  });

  factory IshiharaPlate.fromJson(Map<String, dynamic> json) {
    return IshiharaPlate(
      id: json['id'],
      plateNumber: json['plate_number'],
      imagePath: json['image_path'],
      correctAnswer: json['correct_answer'],
      options: List<String>.from(json['options']),
      description: json['description'] ?? '',
    );
  }
}

class ColourVisionTestPage extends StatefulWidget {
  const ColourVisionTestPage({super.key});

  @override
  State<ColourVisionTestPage> createState() => _ColourVisionTestPageState();
}

class _ColourVisionTestPageState extends State<ColourVisionTestPage> {
  List<IshiharaPlate> ishiharaPlates = [];
  bool isLoading = true;
  String? errorMessage;
  DateTime? testStartTime;

  int currentPlate = 0;
  List<String> answers = [];
  double progress = 0;
  bool isTestComplete = false;
  String? backendDiagnosis; // Stores the specific diagnosis from backend
  bool resultsSaved = false;

  @override
  void initState() {
    super.initState();
    testStartTime = DateTime.now();
    _loadPlates();
  }

  Future<void> _loadPlates() async {
    try {
      setState(() {
        isLoading = true;
        errorMessage = null;
      });

      // Request 10 plates for standard Ishihara screening test
      final platesData = await ApiService.getColorVisionPlates(count: 10);
      final plates = platesData
          .map((data) => IshiharaPlate.fromJson(data))
          .toList();

      setState(() {
        ishiharaPlates = plates;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        errorMessage = e.toString();
        isLoading = false;
      });
    }
  }

  void handleAnswer(String answer) {
    setState(() {
      answers.add(answer);
      progress = ((currentPlate + 1) / ishiharaPlates.length) * 100;
    });

    if (currentPlate < ishiharaPlates.length - 1) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          setState(() {
            currentPlate++;
          });
        }
      });
    } else {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          setState(() {
            isTestComplete = true;
          });
        }
      });
    }
  }

  int calculateScore() {
    int correct = 0;
    // Use minimum length to prevent index out of bounds
    final minLength = answers.length < ishiharaPlates.length
        ? answers.length
        : ishiharaPlates.length;

    for (int i = 0; i < minLength; i++) {
      if (answers[i] == ishiharaPlates[i].correctAnswer) {
        correct++;
      }
    }
    return ((correct / ishiharaPlates.length) * 100).round();
  }

  Map<String, dynamic> getResultMessage() {
    // If backend diagnosis is available, use it
    if (backendDiagnosis != null) {
      return getBackendResultMessage(backendDiagnosis!);
    }

    // Otherwise, use local score calculation
    final score = calculateScore();

    // Map specific deficiency types to appropriate UI
    if (score >= 90) {
      return {
        'status': 'Normal Color Vision',
        'message':
            'Your colour vision appears to be normal. No deficiency detected.',
        'color': Colors.green,
        'icon': Icons.check_circle,
      };
    } else if (score >= 80) {
      return {
        'status': 'Borderline - Possible Mild Deficiency',
        'message':
            'Your results are borderline. Consider retaking the test in better lighting or consulting an eye specialist.',
        'color': Colors.lightGreen,
        'icon': Icons.info,
      };
    } else if (score >= 60) {
      return {
        'status': 'Mild Color Vision Deficiency',
        'message':
            'You may have mild colour vision deficiency. Consider consulting an eye specialist for detailed evaluation.',
        'color': Colors.amber,
        'icon': Icons.warning,
      };
    } else if (score >= 40) {
      return {
        'status': 'Moderate Color Vision Deficiency',
        'message':
            'Moderate colour vision deficiency detected. We recommend consulting an eye specialist for proper diagnosis.',
        'color': Colors.orange,
        'icon': Icons.warning_amber,
      };
    } else if (score >= 30) {
      return {
        'status': 'Severe Color Vision Deficiency',
        'message':
            'Significant colour vision deficiency detected. Please consult an eye care professional for comprehensive evaluation.',
        'color': Colors.deepOrange,
        'icon': Icons.error,
      };
    } else {
      return {
        'status': 'Total Color Blindness',
        'message':
            'Possible total color blindness detected. Immediate consultation with an eye care specialist is strongly recommended.',
        'color': Colors.red,
        'icon': Icons.error_outline,
      };
    }
  }

  Map<String, dynamic> getBackendResultMessage(String diagnosis) {
    // Handle Test Unreliable status
    if (diagnosis.contains('Unreliable') || diagnosis.contains('Retake')) {
      return {
        'status': diagnosis,
        'message':
            'The control plate was answered incorrectly. This may indicate poor lighting, screen issues, or misunderstanding of instructions. Please retake the test in better conditions.',
        'color': Colors.orange,
        'icon': Icons.refresh,
      };
    }

    // Handle Normal Color Vision
    if (diagnosis.contains('Normal')) {
      return {
        'status': diagnosis,
        'message':
            'Your colour vision appears to be normal. No deficiency detected.',
        'color': Colors.green,
        'icon': Icons.check_circle,
      };
    }

    // Handle Red-Green Deficiency
    if (diagnosis.contains('Red-Green')) {
      if (diagnosis.contains('Severe')) {
        return {
          'status': diagnosis,
          'message':
              'Severe red-green color deficiency detected (Protanopia or Deuteranopia). You have difficulty distinguishing between red and green colors. Please consult an eye specialist.',
          'color': Colors.red,
          'icon': Icons.error,
        };
      } else if (diagnosis.contains('Moderate')) {
        return {
          'status': diagnosis,
          'message':
              'Moderate red-green color deficiency detected. You may have difficulty with red and green colors. Consider consulting an eye specialist.',
          'color': Colors.orange,
          'icon': Icons.warning_amber,
        };
      } else {
        return {
          'status': diagnosis,
          'message':
              'Mild red-green color deficiency detected. You may have slight difficulty distinguishing red and green colors. Consider consulting an eye specialist for confirmation.',
          'color': Colors.amber,
          'icon': Icons.warning,
        };
      }
    }

    // Handle Blue-Yellow Deficiency
    if (diagnosis.contains('Blue-Yellow')) {
      if (diagnosis.contains('Severe')) {
        return {
          'status': diagnosis,
          'message':
              'Severe blue-yellow color deficiency detected (Tritanopia). You have difficulty distinguishing between blue and yellow colors. Please consult an eye specialist.',
          'color': Colors.red,
          'icon': Icons.error,
        };
      } else if (diagnosis.contains('Moderate')) {
        return {
          'status': diagnosis,
          'message':
              'Moderate blue-yellow color deficiency detected. You may have difficulty with blue and yellow colors. Consider consulting an eye specialist.',
          'color': Colors.orange,
          'icon': Icons.warning_amber,
        };
      } else {
        return {
          'status': diagnosis,
          'message':
              'Mild blue-yellow color deficiency detected. You may have slight difficulty distinguishing blue and yellow colors. Consider consulting an eye specialist for confirmation.',
          'color': Colors.amber,
          'icon': Icons.warning,
        };
      }
    }

    // Handle Total Color Blindness
    if (diagnosis.contains('Total') || diagnosis.contains('Monochromacy')) {
      return {
        'status': diagnosis,
        'message':
            'Total color blindness (Monochromacy) detected. You may see only in shades of gray. Immediate consultation with an eye care specialist is strongly recommended.',
        'color': Colors.red,
        'icon': Icons.error_outline,
      };
    }

    // Handle Borderline
    if (diagnosis.contains('Borderline')) {
      return {
        'status': diagnosis,
        'message':
            'Your results are borderline. Consider retaking the test in better lighting or consulting an eye specialist.',
        'color': Colors.lightGreen,
        'icon': Icons.info,
      };
    }

    // Default fallback
    return {
      'status': diagnosis,
      'message':
          'Color vision deficiency detected. Please consult an eye specialist for proper diagnosis and evaluation.',
      'color': Colors.amber,
      'icon': Icons.warning,
    };
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<bool> _showExitDialog() async {
    return await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text("Exit Test?"),
            content: const Text(
              "Are you sure you want to exit? Your progress will be lost.",
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text("Cancel"),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text("Exit"),
              ),
            ],
          ),
        ) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    // Show loading state
    if (isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text("Colour Vision Test"),
          backgroundColor: Colors.teal[800],
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text("Loading test plates..."),
            ],
          ),
        ),
      );
    }

    // Show error state
    if (errorMessage != null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text("Colour Vision Test"),
          backgroundColor: Colors.teal[800],
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text("Error: $errorMessage"),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadPlates,
                child: const Text("Retry"),
              ),
            ],
          ),
        ),
      );
    }

    // Show test UI
    return WillPopScope(
      onWillPop: () async {
        if (!isTestComplete) {
          return await _showExitDialog();
        }
        return true;
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF1A1A2E),
        appBar: AppBar(
          backgroundColor: const Color(0xFF16213E),
          elevation: 0,
          leading: isTestComplete
              ? null
              : IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => _showExitDialog(),
                ),
          title: const Text("Colour Vision Test"),
          centerTitle: true,
        ),
        body: SafeArea(child: isTestComplete ? _buildResults() : _buildTest()),
      ),
    );
  }

  // ============ TEST UI ============
  Widget _buildTest() {
    final plate = ishiharaPlates[currentPlate];
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 16),
            // Plate info
            Text(
              "What number do you see?",
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Plate ${currentPlate + 1} of ${ishiharaPlates.length}",
              style: const TextStyle(fontSize: 14, color: Colors.white70),
            ),
            const SizedBox(height: 24),

            // Plate display
            Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white24, width: 2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.network(
                  '${ApiService.getBaseUrl()}${plate.imagePath}',
                  width: 280,
                  height: 280,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Center(
                      child: CircularProgressIndicator(
                        value: loadingProgress.expectedTotalBytes != null
                            ? loadingProgress.cumulativeBytesLoaded /
                                  loadingProgress.expectedTotalBytes!
                            : null,
                        color: Colors.white,
                      ),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: Colors.grey[800],
                      child: const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.error_outline,
                              size: 48,
                              color: Colors.white54,
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Image failed to load',
                              style: TextStyle(color: Colors.white54),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 32),

            // Answer options
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              children: plate.options.map((option) {
                return GestureDetector(
                  onTap: () => handleAnswer(option),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white10,
                      border: Border.all(color: Colors.white24),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => handleAnswer(option),
                        child: Center(
                          child: Text(
                            option,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 32),

            // Progress bar
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "Progress",
                      style: TextStyle(fontSize: 14, color: Colors.white70),
                    ),
                    Text(
                      "${progress.round()}%",
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress / 100,
                    minHeight: 8,
                    backgroundColor: Colors.white24,
                    valueColor: AlwaysStoppedAnimation(Colors.purple[400]),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ============ RESULTS UI ============
  Widget _buildResults() {
    final resultMsg = getResultMessage();
    final score = calculateScore();
    int correct = 0;
    // Use minimum length to prevent index out of bounds
    final minLength = answers.length < ishiharaPlates.length
        ? answers.length
        : ishiharaPlates.length;

    for (int i = 0; i < minLength; i++) {
      if (answers[i] == ishiharaPlates[i].correctAnswer) {
        correct++;
      }
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: (resultMsg['color'] as Color).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(resultMsg['icon'], size: 48, color: resultMsg['color']),
          ),
          const SizedBox(height: 24),
          const Text(
            "Test Completed!",
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            "Your colour vision test has been successfully completed.",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Colors.white70),
          ),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              border: Border.all(color: Colors.white24),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Results:",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),
                _resultRow(
                  "Correct Answers",
                  "$correct / ${ishiharaPlates.length}",
                  Colors.white70,
                ),
                const SizedBox(height: 12),
                Divider(color: Colors.white12),
                const SizedBox(height: 12),
                _resultRow("Score", "$score%", Colors.purple[400]!),
                const SizedBox(height: 12),
                Divider(color: Colors.white12),
                const SizedBox(height: 12),
                _resultRow(
                  "Status",
                  resultMsg['status'], // Always use resultMsg which now handles backend diagnosis
                  resultMsg['color'],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: (resultMsg['color'] as Color).withOpacity(0.1),
              border: Border.all(
                color: (resultMsg['color'] as Color).withOpacity(0.3),
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              resultMsg['message'],
              style: TextStyle(
                fontSize: 14,
                color: resultMsg['color'],
                height: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () async {
                try {
                  final testDuration = testStartTime != null
                      ? DateTime.now()
                            .difference(testStartTime!)
                            .inSeconds
                            .toDouble()
                      : null;

                  // Extract image filenames from image paths
                  final plateImages = ishiharaPlates.map((p) {
                    final path = p.imagePath;
                    return path.split('/').last; // Get filename from path
                  }).toList();

                  final response = await ApiService.submitColorVisionTest(
                    plateIds: ishiharaPlates.map((p) => p.plateNumber).toList(),
                    plateImages: plateImages,
                    userAnswers: answers,
                    score: calculateScore(),
                    testDuration: testDuration,
                  );

                  if (mounted) {
                    // Store the backend diagnosis
                    setState(() {
                      backendDiagnosis = response['severity'];
                      resultsSaved = true;
                    });

                    // Show warning if control plate failed
                    String message = "Results saved successfully!";
                    if (backendDiagnosis != null) {
                      message += "\nDiagnosis: $backendDiagnosis";
                    }
                    Color bgColor = Colors.green;

                    if (response['warning'] != null) {
                      message = response['warning'];
                      bgColor = Colors.orange;
                    }

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(message),
                        backgroundColor: bgColor,
                        duration: const Duration(seconds: 4),
                      ),
                    );

                    // Show medical disclaimer
                    if (response['medical_disclaimer'] != null) {
                      Future.delayed(const Duration(seconds: 4), () {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(response['medical_disclaimer']),
                              backgroundColor: Colors.blueGrey,
                              duration: const Duration(seconds: 6),
                            ),
                          );
                        }
                      });
                    }
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text("Failed to save results: $e"),
                        backgroundColor: Colors.red,
                        duration: const Duration(seconds: 3),
                      ),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue[600],
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                "Save Results",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ColourVisionTestPage(),
                  ),
                );
              },
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                side: const BorderSide(color: Colors.blue),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                "Retry Test",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.blue,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () =>
                  Navigator.popUntil(context, (route) => route.isFirst),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                side: BorderSide(color: Colors.grey.withOpacity(0.5)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                "Back to Home",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.withOpacity(0.7),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _resultRow(String label, String value, Color valueColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 14, color: Colors.white70),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: valueColor,
          ),
        ),
      ],
    );
  }
}
