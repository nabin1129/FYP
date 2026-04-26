import 'package:flutter/material.dart';
import 'package:netracare/config/app_theme.dart';
import 'dart:async';
import 'package:netracare/services/api_service.dart';

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
  bool _isSkippingFailedPlate = false;

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

      final validPlates = await _filterLoadablePlates(plates);

      if (validPlates.isEmpty) {
        throw Exception(
          'No valid colour vision plates available. Please retry.',
        );
      }

      setState(() {
        ishiharaPlates = validPlates;
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

  Future<List<IshiharaPlate>> _filterLoadablePlates(
    List<IshiharaPlate> plates,
  ) async {
    final valid = <IshiharaPlate>[];

    for (final plate in plates) {
      final imagePath = plate.imagePath.trim();
      if (imagePath.isEmpty) {
        continue;
      }

      final imageUrl = '${ApiService.getBaseUrl()}$imagePath';

      try {
        await precacheImage(NetworkImage(imageUrl), context);
        valid.add(plate);
      } catch (_) {
        // Skip broken or unreachable plate images.
      }
    }

    return valid;
  }

  void _skipCurrentFailedPlate() {
    if (!mounted || _isSkippingFailedPlate || ishiharaPlates.isEmpty) {
      return;
    }

    _isSkippingFailedPlate = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        _isSkippingFailedPlate = false;
        return;
      }

      setState(() {
        if (ishiharaPlates.isNotEmpty && currentPlate < ishiharaPlates.length) {
          ishiharaPlates.removeAt(currentPlate);
        }

        if (currentPlate >= ishiharaPlates.length && currentPlate > 0) {
          currentPlate = ishiharaPlates.length - 1;
        }

        if (ishiharaPlates.isEmpty) {
          errorMessage =
              'All test plate images failed to load. Please retry later.';
          isLoading = false;
        }
      });

      _isSkippingFailedPlate = false;
    });
  }

  int calculateScore() {
    if (ishiharaPlates.isEmpty) {
      return 0;
    }

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

  Map<String, dynamic> getResultMessage(BuildContext context) {
    final colors = context.appColors;
    // If backend diagnosis is available, use it
    if (backendDiagnosis != null) {
      return getBackendResultMessage(context, backendDiagnosis!);
    }

    // Otherwise, use local score calculation
    final score = calculateScore();

    // Map specific deficiency types to appropriate UI
    if (score >= 90) {
      return {
        'status': 'Normal Color Vision',
        'message':
            'Your colour vision appears to be normal. No deficiency detected.',
        'color': colors.success,
        'icon': Icons.check_circle,
      };
    } else if (score >= 80) {
      return {
        'status': 'Borderline - Possible Mild Deficiency',
        'message':
            'Your results are borderline. Consider retaking the test in better lighting or consulting an eye specialist.',
        'color': colors.success,
        'icon': Icons.info,
      };
    } else if (score >= 60) {
      return {
        'status': 'Mild Color Vision Deficiency',
        'message':
            'You may have mild colour vision deficiency. Consider consulting an eye specialist for detailed evaluation.',
        'color': colors.warning,
        'icon': Icons.warning,
      };
    } else if (score >= 40) {
      return {
        'status': 'Moderate Color Vision Deficiency',
        'message':
            'Moderate colour vision deficiency detected. We recommend consulting an eye specialist for proper diagnosis.',
        'color': colors.warning,
        'icon': Icons.warning_amber,
      };
    } else if (score >= 30) {
      return {
        'status': 'Severe Color Vision Deficiency',
        'message':
            'Significant colour vision deficiency detected. Please consult an eye care professional for comprehensive evaluation.',
        'color': colors.warning,
        'icon': Icons.error,
      };
    } else {
      return {
        'status': 'Total Color Blindness',
        'message':
            'Possible total color blindness detected. Immediate consultation with an eye care specialist is strongly recommended.',
        'color': colors.error,
        'icon': Icons.error_outline,
      };
    }
  }

  Map<String, dynamic> getBackendResultMessage(BuildContext context, String diagnosis) {
    final colors = context.appColors;
    // Handle Test Unreliable status
    if (diagnosis.contains('Unreliable') || diagnosis.contains('Retake')) {
      return {
        'status': diagnosis,
        'message':
            'The control plate was answered incorrectly. This may indicate poor lighting, screen issues, or misunderstanding of instructions. Please retake the test in better conditions.',
        'color': colors.warning,
        'icon': Icons.refresh,
      };
    }

    // Handle Normal Color Vision
    if (diagnosis.contains('Normal')) {
      return {
        'status': diagnosis,
        'message':
            'Your colour vision appears to be normal. No deficiency detected.',
        'color': colors.success,
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
          'color': colors.error,
          'icon': Icons.error,
        };
      } else if (diagnosis.contains('Moderate')) {
        return {
          'status': diagnosis,
          'message':
              'Moderate red-green color deficiency detected. You may have difficulty with red and green colors. Consider consulting an eye specialist.',
          'color': colors.warning,
          'icon': Icons.warning_amber,
        };
      } else {
        return {
          'status': diagnosis,
          'message':
              'Mild red-green color deficiency detected. You may have slight difficulty distinguishing red and green colors. Consider consulting an eye specialist for confirmation.',
          'color': colors.warning,
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
          'color': colors.error,
          'icon': Icons.error,
        };
      } else if (diagnosis.contains('Moderate')) {
        return {
          'status': diagnosis,
          'message':
              'Moderate blue-yellow color deficiency detected. You may have difficulty with blue and yellow colors. Consider consulting an eye specialist.',
          'color': colors.warning,
          'icon': Icons.warning_amber,
        };
      } else {
        return {
          'status': diagnosis,
          'message':
              'Mild blue-yellow color deficiency detected. You may have slight difficulty distinguishing blue and yellow colors. Consider consulting an eye specialist for confirmation.',
          'color': colors.warning,
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
        'color': colors.error,
        'icon': Icons.error_outline,
      };
    }

    // Handle Borderline
    if (diagnosis.contains('Borderline')) {
      return {
        'status': diagnosis,
        'message':
            'Your results are borderline. Consider retaking the test in better lighting or consulting an eye specialist.',
        'color': colors.success,
        'icon': Icons.info,
      };
    }

    // Default fallback
    return {
      'status': diagnosis,
      'message':
          'Color vision deficiency detected. Please consult an eye specialist for proper diagnosis and evaluation.',
      'color': colors.warning,
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

  AppBar _buildAppBar(BuildContext context) {
    final colors = context.appColors;
    return AppBar(
      title: const Text("Colour Vision Test"),
      backgroundColor: colors.surface,
      elevation: 1,
      titleTextStyle: TextStyle(
        color: colors.textPrimary,
        fontSize: AppTheme.fontXXL,
        fontWeight: FontWeight.w600,
      ),
      iconTheme: IconThemeData(color: colors.textPrimary),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    // Show loading state
    if (isLoading) {
      return Scaffold(
        appBar: _buildAppBar(context),
        backgroundColor: colors.background,
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
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
        appBar: _buildAppBar(context),
        backgroundColor: colors.background,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: colors.error),
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
    return PopScope(
      canPop: isTestComplete,
      onPopInvokedWithResult: (didPop, _) async {
        if (!didPop) {
          final nav = Navigator.of(context);
          final exit = await _showExitDialog();
          if (exit) nav.pop();
        }
      },
      child: Scaffold(
        backgroundColor: colors.background,
        appBar: AppBar(
          backgroundColor: colors.surface,
          elevation: 1,
          titleTextStyle: TextStyle(
            color: colors.textPrimary,
            fontSize: AppTheme.fontXXL,
            fontWeight: FontWeight.w600,
          ),
          iconTheme: IconThemeData(color: colors.textPrimary),
          leading: isTestComplete
              ? null
              : IconButton(
                  icon: Icon(Icons.close, color: colors.textPrimary),
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
    final colors = context.appColors;
    final plate = ishiharaPlates[currentPlate];
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: Column(
          children: [
            // Progress Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colors.surface,
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
                      Text(
                        "Progress",
                        style: TextStyle(
                          fontSize: AppTheme.fontBody,
                          fontWeight: FontWeight.w600,
                          color: colors.textSecondary,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: colors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          "${currentPlate + 1}/${ishiharaPlates.length}",
                          style: TextStyle(
                            fontSize: AppTheme.fontBody,
                            fontWeight: FontWeight.bold,
                            color: colors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: progress / 100,
                      minHeight: 8,
                      backgroundColor: colors.border,
                      valueColor: AlwaysStoppedAnimation<Color>(colors.primary),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // Question Text
            Text(
              "What number do you see?",
              style: TextStyle(
                fontSize: AppTheme.fontXXL,
                fontWeight: FontWeight.bold,
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: 24),

            // Plate display
            Container(
              width: double.infinity,
              height: 300,
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Image.network(
                    '${ApiService.getBaseUrl()}${plate.imagePath}',
                    fit: BoxFit.contain,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Center(
                        child: CircularProgressIndicator(
                          value: loadingProgress.expectedTotalBytes != null
                              ? loadingProgress.cumulativeBytesLoaded /
                                    loadingProgress.expectedTotalBytes!
                              : null,
                          valueColor: AlwaysStoppedAnimation<Color>(colors.primary),
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) {
                      _skipCurrentFailedPlate();

                      return Container(
                        color: colors.background,
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 28,
                                height: 28,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    colors.primary,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                'Skipping unavailable plate...',
                                style: TextStyle(color: colors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Answer options
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colors.surface,
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
                      color: colors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    children: plate.options.map((option) {
                      return Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => handleAnswer(option),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            decoration: BoxDecoration(
                              color: colors.primary.withValues(alpha: 0.08),
                              border: Border.all(
                                color: colors.primary.withValues(alpha: 0.3),
                                width: 2,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Center(
                              child: Text(
                                option,
                                style: TextStyle(
                                  fontSize: AppTheme.fontHeading,
                                  fontWeight: FontWeight.bold,
                                  color: colors.primary,
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
          ],
        ),
      ),
    );
  }

  // ============ RESULTS UI ============
  Widget _buildResults() {
    final colors = context.appColors;
    final resultMsg = getResultMessage(context);
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Column(
        children: [
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: (resultMsg['color'] as Color).withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(resultMsg['icon'], size: 64, color: resultMsg['color']),
          ),
          const SizedBox(height: 24),
          Text(
            "Test Completed!",
            style: TextStyle(
              fontSize: AppTheme.fontHeading,
              fontWeight: FontWeight.bold,
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Your colour vision test has been successfully completed.",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: AppTheme.fontBody,
              color: colors.textSecondary,
            ),
          ),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: colors.surface,
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Results:",
                  style: TextStyle(
                    fontSize: AppTheme.fontLG,
                    fontWeight: FontWeight.bold,
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 16),
                _resultRow(
                  "Correct Answers",
                  "$correct / ${ishiharaPlates.length}",
                  colors.textPrimary,
                ),
                const SizedBox(height: 12),
                Divider(color: colors.divider),
                const SizedBox(height: 12),
                _resultRow("Score", "$score%", colors.primary),
                const SizedBox(height: 12),
                Divider(color: colors.divider),
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
              color: (resultMsg['color'] as Color).withValues(alpha: 0.1),
              border: Border.all(
                color: (resultMsg['color'] as Color).withValues(alpha: 0.3),
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              resultMsg['message'],
              style: TextStyle(
                fontSize: AppTheme.fontBody,
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

                  // Debug: Print what we're sending
                  debugPrint('===== SUBMITTING COLOR VISION TEST =====');
                  debugPrint(
                    'Plate IDs: ${ishiharaPlates.map((p) => p.plateNumber).toList()}',
                  );
                  debugPrint('Plate Images: $plateImages');
                  debugPrint('User Answers: $answers');
                  debugPrint('Score: ${calculateScore()}');
                  debugPrint('==========================================');

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
                    Color bgColor = colors.success;

                    if (response['warning'] != null) {
                      message = response['warning'];
                      bgColor = colors.warning;
                    }

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(message),
                        backgroundColor: bgColor,
                        duration: const Duration(seconds: 3),
                      ),
                    );

                    // Navigate to home page after short delay
                    Future.delayed(const Duration(seconds: 3), () {
                      if (mounted) {
                        Navigator.popUntil(context, (route) => route.isFirst);
                      }
                    });

                    // Show medical disclaimer
                    if (response['medical_disclaimer'] != null) {
                      Future.delayed(const Duration(seconds: 4), () {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(response['medical_disclaimer']),
                              backgroundColor: colors.textSubtle,
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
                        backgroundColor: colors.error,
                        duration: const Duration(seconds: 3),
                      ),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.primary,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                "Save Results",
                style: TextStyle(
                  fontSize: AppTheme.fontLG,
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
                side: BorderSide(color: colors.primary),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                "Retry Test",
                style: TextStyle(
                  fontSize: AppTheme.fontLG,
                  fontWeight: FontWeight.w600,
                  color: colors.primary,
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
                side: BorderSide(color: colors.textSecondary),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                "Back to Home",
                style: TextStyle(
                  fontSize: AppTheme.fontLG,
                  fontWeight: FontWeight.w600,
                  color: colors.textSecondary,
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
    final colors = context.appColors;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: AppTheme.fontLG,
            fontWeight: FontWeight.w500,
            color: colors.textPrimary,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: AppTheme.fontLG,
            fontWeight: FontWeight.bold,
            color: valueColor,
          ),
        ),
      ],
    );
  }
}
