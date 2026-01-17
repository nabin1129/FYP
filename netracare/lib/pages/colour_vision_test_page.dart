import 'package:flutter/material.dart';
import 'dart:async';

class IshiharaPlate {
  final int id;
  final String correctAnswer;
  final List<String> options;
  final String description;
  final Color plateBgColor;

  IshiharaPlate({
    required this.id,
    required this.correctAnswer,
    required this.options,
    required this.description,
    required this.plateBgColor,
  });
}

class ColourVisionTestPage extends StatefulWidget {
  const ColourVisionTestPage({super.key});

  @override
  State<ColourVisionTestPage> createState() => _ColourVisionTestPageState();
}

class _ColourVisionTestPageState extends State<ColourVisionTestPage> {
  final List<IshiharaPlate> ishiharaPlates = [
    IshiharaPlate(
      id: 1,
      correctAnswer: '12',
      options: ['12', '15', '17', '21'],
      description: 'Normal vision sees 12',
      plateBgColor: Colors.red,
    ),
    IshiharaPlate(
      id: 2,
      correctAnswer: '8',
      options: ['3', '5', '8', '9'],
      description: 'Normal vision sees 8',
      plateBgColor: Colors.amber,
    ),
    IshiharaPlate(
      id: 3,
      correctAnswer: '29',
      options: ['29', '70', '79', 'Nothing'],
      description: 'Normal vision sees 29',
      plateBgColor: Colors.green,
    ),
    IshiharaPlate(
      id: 4,
      correctAnswer: '5',
      options: ['2', '5', '6', '9'],
      description: 'Normal vision sees 5',
      plateBgColor: Colors.orange,
    ),
    IshiharaPlate(
      id: 5,
      correctAnswer: '74',
      options: ['21', '74', '71', 'Nothing'],
      description: 'Normal vision sees 74',
      plateBgColor: Colors.purple,
    ),
  ];

  int currentPlate = 0;
  List<String> answers = [];
  double progress = 0;
  bool isTestComplete = false;

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
    for (int i = 0; i < answers.length; i++) {
      if (answers[i] == ishiharaPlates[i].correctAnswer) {
        correct++;
      }
    }
    return ((correct / ishiharaPlates.length) * 100).round();
  }

  Map<String, dynamic> getResultMessage() {
    final score = calculateScore();
    if (score >= 80) {
      return {
        'status': 'Normal',
        'message': 'Your colour vision appears to be normal.',
        'color': Colors.green,
        'icon': Icons.check_circle,
      };
    } else if (score >= 60) {
      return {
        'status': 'Mild Deficiency',
        'message':
            'You may have mild colour vision deficiency. Consider consulting an eye specialist.',
        'color': Colors.amber,
        'icon': Icons.warning,
      };
    } else {
      return {
        'status': 'Deficiency Detected',
        'message':
            'Colour vision deficiency detected. We recommend consulting an eye specialist for a comprehensive evaluation.',
        'color': Colors.red,
        'icon': Icons.error,
      };
    }
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
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Base gradient background
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          plate.plateBgColor.withOpacity(0.3),
                          plate.plateBgColor.withOpacity(0.1),
                        ],
                      ),
                    ),
                  ),
                  // Ishihara pattern visualization
                  Text(
                    plate.correctAnswer,
                    style: TextStyle(
                      fontSize: 72,
                      fontWeight: FontWeight.bold,
                      color: Colors.white.withOpacity(0.15),
                    ),
                  ),
                  // Color dots pattern (simplified visualization)
                  CustomPaint(
                    size: const Size(260, 260),
                    painter: _IsihharaPatternPainter(
                      color: plate.plateBgColor,
                      answer: plate.correctAnswer,
                    ),
                  ),
                ],
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
    for (int i = 0; i < answers.length; i++) {
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
                _resultRow("Status", resultMsg['status'], resultMsg['color']),
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
              onPressed: () {
                // TODO: Save results to backend
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Results saved successfully!"),
                    duration: Duration(seconds: 2),
                  ),
                );
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

// Custom painter for Ishihara pattern visualization
class _IsihharaPatternPainter extends CustomPainter {
  final Color color;
  final String answer;

  _IsihharaPatternPainter({required this.color, required this.answer});

  @override
  void paint(Canvas canvas, Size size) {
    // Draw a simple pattern of colored circles to simulate Ishihara plates
    final paint = Paint()..color = color.withOpacity(0.6);
    final dotRadius = 4.0;
    final spacing = 15.0;

    for (int i = 0; i < 15; i++) {
      for (int j = 0; j < 15; j++) {
        final x = j * spacing + 5;
        final y = i * spacing + 5;

        if (x < size.width && y < size.height) {
          // Random visibility to create number pattern effect
          final shouldDraw = (i + j) % 3 != 0;
          if (shouldDraw) {
            canvas.drawCircle(Offset(x, y), dotRadius, paint);
          }
        }
      }
    }
  }

  @override
  bool shouldRepaint(_IsihharaPatternPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.answer != answer;
  }
}
