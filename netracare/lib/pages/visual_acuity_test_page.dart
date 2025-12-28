import 'dart:math';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

class VisualAcuityTestPage extends StatefulWidget {
  const VisualAcuityTestPage({super.key});

  @override
  State<VisualAcuityTestPage> createState() => _VisualAcuityTestPageState();
}

class _VisualAcuityTestPageState extends State<VisualAcuityTestPage> {
  CameraController? _controller;
  bool cameraReady = false;

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
    final cameras = await availableCameras();
    _controller = CameraController(
      cameras.first,
      ResolutionPreset.medium,
      enableAudio: false,
    );

    await _controller!.initialize();
    setState(() => cameraReady = true);
    _nextLetter();
  }

  void _nextLetter() {
    setState(() {
      currentLetter = letters[Random().nextInt(letters.length)];
      fontSize = max(30, fontSize - 6);
    });
  }

  void _submitAnswer(String answer) {
    total++;
    if (answer == currentLetter) correct++;

    if (total >= 10) {
      _showResult();
    } else {
      _nextLetter();
    }
  }

  void _showResult() {
    double logMAR = correct == 0 ? 1.0 : -log(correct / total) / ln10;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Visual Acuity Result"),
        content: Text(
          "Correct: $correct / $total\nlogMAR: ${logMAR.toStringAsFixed(2)}",
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text("Done"),
          ),
        ],
      ),
    );
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

                Center(
                  child: Text(
                    currentLetter,
                    style: TextStyle(
                      fontSize: fontSize,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),

                Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Wrap(
                      spacing: 8,
                      children: letters.map((l) {
                        return ElevatedButton(
                          onPressed: () => _submitAnswer(l),
                          child: Text(l),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ],
            )
          : const Center(child: CircularProgressIndicator(color: Colors.white)),
    );
  }
}
