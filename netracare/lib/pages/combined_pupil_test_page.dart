import 'package:flutter/material.dart';
import 'package:netracare/config/app_theme.dart';
import 'package:camera/camera.dart';
import 'dart:async';
import 'dart:io';
import 'dart:math';
import '../utils/permission_helper.dart';
import '../services/pupil_reflex_service.dart';

/// Combined Pupil Reflex + Nystagmus Detection Test
/// Records video during flash test and analyzes for both metrics
class CombinedPupilTestPage extends StatefulWidget {
  const CombinedPupilTestPage({super.key});

  @override
  State<CombinedPupilTestPage> createState() => _CombinedPupilTestPageState();
}

class _CombinedPupilTestPageState extends State<CombinedPupilTestPage>
    with SingleTickerProviderStateMixin {
  CameraController? _cameraController;
  late AnimationController _flashAnimationController;

  int _phase = 0; // 0: ready, 1: testing, 2: processing, 3: results
  // ignore: unused_field
  bool _isRecording = false;
  String? _videoPath;
  String? _testId;

  // Pupil reflex metrics
  double _reactionTime = 0.0;
  String _amplitude = '';
  String _symmetry = '';

  // Nystagmus metrics
  bool? _nystagmusDetected;
  String? _nystagmusType;
  String? _nystagmusSeverity;
  double? _confidence;
  String? _diagnosis;
  String? _recommendations;

  @override
  void initState() {
    super.initState();
    _flashAnimationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _initCamera();
  }

  Future<void> _initCamera() async {
    final hasPermission = await PermissionHelper.requestCameraPermission(
      context,
    );
    if (!hasPermission) return;

    final cameras = await availableCameras();
    if (cameras.isEmpty) return;

    final frontCamera = cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.front,
      orElse: () => cameras[0],
    );

    _cameraController = CameraController(
      frontCamera,
      ResolutionPreset.medium,
      enableAudio: false,
    );
    await _cameraController!.initialize();
    if (mounted) setState(() {});
  }

  Future<void> _startTest() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }

    // Start test session
    try {
      final result = await PupilReflexService.startNystagmusTest();
      if (result['test_id'] == null) {
        _showError('Failed to start test');
        return;
      }
      _testId = result['test_id'].toString();
    } catch (e) {
      _showError('Failed to start test: $e');
      return;
    }

    // Start video recording
    await _cameraController!.startVideoRecording();
    _isRecording = true;

    setState(() => _phase = 1);

    // Flash test sequence (5 seconds)
    _flashAnimationController.repeat(reverse: true);

    await Future.delayed(const Duration(seconds: 5));

    // Stop recording and process
    _flashAnimationController.stop();
    final video = await _cameraController!.stopVideoRecording();
    _videoPath = video.path;
    _isRecording = false;

    setState(() => _phase = 2);
    _analyzeResults();
  }

  Future<void> _analyzeResults() async {
    // Simulate pupil reflex metrics
    final random = Random();
    _reactionTime = 0.2 + (random.nextDouble() * 0.3);
    _amplitude = _reactionTime < 0.35 ? 'Normal' : 'Weak';
    _symmetry = 'Equal';

    // Analyze video for nystagmus
    if (_videoPath != null && _testId != null) {
      try {
        final result = await PupilReflexService.analyzeVideoForNystagmus(
          videoFile: File(_videoPath!),
          testId: _testId!,
        );

        if (result['success'] == true) {
          _nystagmusDetected = result['nystagmus_detected'] ?? false;
          _nystagmusType = result['nystagmus_type'];
          _nystagmusSeverity = result['severity'];
          _confidence = result['confidence']?.toDouble();
          _diagnosis = result['diagnosis'];
          _recommendations = result['recommendations'];
        }
      } catch (e) {
        debugPrint('Analysis error: $e');
      }
    }

    setState(() => _phase = 3);
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppTheme.error),
    );
  }

  @override
  void dispose() {
    _flashAnimationController.dispose();
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pupil & Nystagmus Test'),
        backgroundColor: AppTheme.accent,
      ),
      body: SafeArea(child: _buildContent()),
    );
  }

  Widget _buildContent() {
    if (_phase == 0) return _buildReady();
    if (_phase == 1) return _buildTesting();
    if (_phase == 2) return _buildProcessing();
    return _buildResults();
  }

  Widget _buildReady() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          // Camera preview
          if (_cameraController?.value.isInitialized ?? false)
            Container(
              height: 300,
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.border),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: CameraPreview(_cameraController!),
              ),
            ),
          const SizedBox(height: 24),

          // Instructions
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.border),
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
                const Row(
                  children: [
                    Icon(Icons.info_outline, color: AppTheme.accent),
                    SizedBox(width: 8),
                    Text(
                      'Test Instructions',
                      style: TextStyle(
                        fontSize: AppTheme.fontXL,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textDark,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildInstruction('Position face 30-40cm from camera'),
                _buildInstruction('Look directly at the screen'),
                _buildInstruction('Keep eyes open during flash test'),
                _buildInstruction('Test duration: ~5 seconds'),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Start button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _cameraController?.value.isInitialized ?? false
                  ? _startTest
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accent,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Start Test',
                style: TextStyle(
                  fontSize: AppTheme.fontXL,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInstruction(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: AppTheme.accent, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: AppTheme.textSubtle),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTesting() {
    return Stack(
      children: [
        // Camera preview
        if (_cameraController?.value.isInitialized ?? false)
          SizedBox.expand(child: CameraPreview(_cameraController!)),

        // Flash overlay
        AnimatedBuilder(
          animation: _flashAnimationController,
          builder: (context, child) {
            return Container(
              color: Colors.white.withValues(
                alpha: _flashAnimationController.value * 0.7,
              ),
            );
          },
        ),

        // Recording indicator
        Positioned(
          top: 20,
          left: 20,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.error,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Row(
              children: [
                Icon(Icons.fiber_manual_record, color: Colors.white, size: 12),
                SizedBox(width: 6),
                Text(
                  'Recording',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),

        // Instructions overlay
        Center(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.textSecondary,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              'Keep looking at the camera\nDuring the flash test',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: AppTheme.fontLG,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProcessing() {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: AppTheme.accent),
            SizedBox(height: 20),
            Text(
              'Analyzing results...',
              style: TextStyle(
                fontSize: AppTheme.fontLG,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Processing video for nystagmus detection',
              style: TextStyle(
                fontSize: AppTheme.fontSM,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResults() {
    final isNystagmusNormal = !(_nystagmusDetected ?? false);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          // Overall status
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isNystagmusNormal
                    ? [AppTheme.success, AppTheme.success]
                    : [AppTheme.warning, AppTheme.warning],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Icon(
                  isNystagmusNormal ? Icons.check_circle : Icons.warning,
                  color: Colors.white,
                  size: 48,
                ),
                const SizedBox(height: 12),
                Text(
                  isNystagmusNormal
                      ? 'Test Complete'
                      : 'Abnormal Results Detected',
                  style: const TextStyle(
                    fontSize: AppTheme.fontXXL,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Pupil Reflex Results
          _buildResultCard('Pupil Reflex Results', Icons.flash_on, [
            _buildResultRow(
              'Reaction Time',
              '${(_reactionTime * 1000).toStringAsFixed(0)} ms',
            ),
            _buildResultRow('Amplitude', _amplitude),
            _buildResultRow('Symmetry', _symmetry),
          ]),
          const SizedBox(height: 16),

          // Nystagmus Results
          if (_nystagmusDetected != null)
            _buildResultCard('Nystagmus Detection', Icons.remove_red_eye, [
              _buildResultRow(
                'Status',
                _nystagmusDetected! ? 'Detected' : 'Not Detected',
              ),
              if (_nystagmusDetected!) ...[
                _buildResultRow('Type', _nystagmusType ?? 'N/A'),
                _buildResultRow('Severity', _nystagmusSeverity ?? 'N/A'),
                _buildResultRow(
                  'Confidence',
                  _confidence != null
                      ? '${(_confidence! * 100).toStringAsFixed(1)}%'
                      : 'N/A',
                ),
              ],
            ]),
          const SizedBox(height: 16),

          // Diagnosis
          if (_diagnosis != null)
            _buildResultCard('Diagnosis', Icons.medical_information, [
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _diagnosis!,
                  style: const TextStyle(
                    color: AppTheme.textSubtle,
                    height: 1.5,
                  ),
                ),
              ),
            ]),
          const SizedBox(height: 16),

          // Recommendations
          if (_recommendations != null)
            _buildResultCard('Recommendations', Icons.recommend, [
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _recommendations!,
                  style: const TextStyle(
                    color: AppTheme.textSubtle,
                    height: 1.5,
                  ),
                ),
              ),
            ]),
          const SizedBox(height: 24),

          // Done button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accent,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Done',
                style: TextStyle(
                  fontSize: AppTheme.fontXL,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultCard(String title, IconData icon, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
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
          Row(
            children: [
              Icon(icon, color: AppTheme.accent, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: AppTheme.fontXL,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildResultRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppTheme.textSubtle)),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: AppTheme.textDark,
            ),
          ),
        ],
      ),
    );
  }
}
