import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'dart:async';
import 'dart:io';
import '../utils/permission_helper.dart';
import '../services/pupil_reflex_service.dart';

/// Nystagmus Detection Test Page
/// Records eye movement video and analyzes for involuntary rhythmic movements
class NystagmusTestPage extends StatefulWidget {
  const NystagmusTestPage({super.key});

  @override
  State<NystagmusTestPage> createState() => _NystagmusTestPageState();
}

class _NystagmusTestPageState extends State<NystagmusTestPage> {
  CameraController? _cameraController;
  List<CameraDescription>? cameras;

  // Test state
  TestPhase _currentPhase = TestPhase.instructions;
  bool isRecording = false;
  int recordingDuration = 0;
  Timer? _recordingTimer;
  String? videoPath;
  String? testId;
  
  // Results
  bool? nystagmusDetected;
  String? nystagmusType;
  String? nystagmusSeverity;
  double? confidence;
  String? diagnosis;
  String? recommendations;
  bool isAnalyzing = false;

  @override
  void initState() {
    super.initState();
    _initializeCameras();
  }

  Future<void> _initializeCameras() async {
    try {
      final hasPermission = await PermissionHelper.requestCameraPermission(context);
      if (!hasPermission) {
        if (mounted) {
          _showErrorDialog('Camera permission is required for this test');
        }
        return;
      }

      cameras = await availableCameras();
      if (cameras == null || cameras!.isEmpty) {
        if (mounted) {
          _showErrorDialog('No camera detected on this device');
        }
        return;
      }

      if (mounted) {
        _initializeCamera();
      }
    } catch (e) {
      debugPrint('Error initializing cameras: $e');
      if (mounted) {
        _showErrorDialog('Camera initialization failed: $e');
      }
    }
  }

  Future<void> _initializeCamera() async {
    if (cameras == null || cameras!.isEmpty) return;

    // Prefer front camera for eye tests
    CameraDescription selectedCamera;
    try {
      selectedCamera = cameras!.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
      );
    } catch (e) {
      selectedCamera = cameras![0];
    }

    _cameraController = CameraController(
      selectedCamera,
      ResolutionPreset.high,
      enableAudio: false,
    );

    try {
      await _cameraController!.initialize();
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      debugPrint('Camera initialization error: $e');
      if (mounted) {
        _showErrorDialog('Failed to initialize camera: $e');
      }
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Close page
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _startTest() async {
    setState(() {
      _currentPhase = TestPhase.starting;
    });

    try {
      // Start test session on backend
      final response = await PupilReflexService.startNystagmusTest(
        testType: 'nystagmus',
        eyeTested: 'both',
      );

      testId = response['test_id'].toString();

      if (mounted) {
        setState(() {
          _currentPhase = TestPhase.recording;
        });
        _startRecording();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to start test: $e'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() {
          _currentPhase = TestPhase.instructions;
        });
      }
    }
  }

  Future<void> _startRecording() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }

    try {
      await _cameraController!.startVideoRecording();
      
      setState(() {
        isRecording = true;
        recordingDuration = 0;
      });

      // Timer for recording duration (10-15 seconds recommended)
      _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        setState(() {
          recordingDuration++;
        });

        // Auto-stop after 15 seconds
        if (recordingDuration >= 15) {
          _stopRecording();
        }
      });
    } catch (e) {
      debugPrint('Error starting recording: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to start recording: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _stopRecording() async {
    _recordingTimer?.cancel();

    if (_cameraController == null || !_cameraController!.value.isRecordingVideo) {
      return;
    }

    try {
      final xFile = await _cameraController!.stopVideoRecording();
      videoPath = xFile.path;

      setState(() {
        isRecording = false;
        _currentPhase = TestPhase.processing;
      });

      // Analyze video
      _analyzeVideo();
    } catch (e) {
      debugPrint('Error stopping recording: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to stop recording: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _analyzeVideo() async {
    if (videoPath == null || testId == null) {
      setState(() {
        _currentPhase = TestPhase.error;
      });
      return;
    }

    setState(() {
      isAnalyzing = true;
    });

    try {
      final videoFile = File(videoPath!);
      
      // Upload and analyze video
      final results = await PupilReflexService.analyzeVideoForNystagmus(
        testId: testId!,
        videoFile: videoFile,
      );

      // Extract results
      final nystagmusData = results['results']?['nystagmus'];
      
      setState(() {
        nystagmusDetected = nystagmusData?['detected'] ?? false;
        nystagmusType = nystagmusData?['type'];
        nystagmusSeverity = nystagmusData?['severity'];
        confidence = nystagmusData?['confidence']?.toDouble();
        diagnosis = results['results']?['diagnosis'];
        recommendations = results['results']?['recommendations'];
        _currentPhase = TestPhase.results;
        isAnalyzing = false;
      });

      // Clean up video file
      try {
        await videoFile.delete();
      } catch (_) {}
    } catch (e) {
      debugPrint('Error analyzing video: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to analyze video: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
        setState(() {
          _currentPhase = TestPhase.error;
          isAnalyzing = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _recordingTimer?.cancel();
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nystagmus Detection'),
        backgroundColor: Colors.deepPurple,
      ),
      body: SafeArea(
        child: _buildPhaseContent(),
      ),
    );
  }

  Widget _buildPhaseContent() {
    switch (_currentPhase) {
      case TestPhase.instructions:
        return _buildInstructionsView();
      case TestPhase.starting:
        return const Center(child: CircularProgressIndicator());
      case TestPhase.recording:
        return _buildRecordingView();
      case TestPhase.processing:
        return _buildProcessingView();
      case TestPhase.results:
        return _buildResultsView();
      case TestPhase.error:
        return _buildErrorView();
    }
  }

  Widget _buildInstructionsView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF6366F1).withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Column(
              children: [
                Icon(Icons.remove_red_eye, color: Colors.white, size: 48),
                SizedBox(height: 12),
                Text(
                  'Nystagmus Detection',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Involuntary Eye Movement Analysis',
                  style: TextStyle(fontSize: 14, color: Colors.white70),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          
          // What is Nystagmus Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.info_outline, color: Color(0xFF6366F1)),
                    SizedBox(width: 8),
                    Text(
                      'What is Nystagmus?',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1f2937),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12),
                Text(
                  'Nystagmus is a condition where the eyes make repetitive, uncontrolled movements. This test detects and classifies these movements to help identify potential eye health concerns.',
                  style: TextStyle(fontSize: 14, color: Color(0xFF6b7280), height: 1.5),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          
          // Instructions Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
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
                    Icon(Icons.checklist, color: Color(0xFF6366F1)),
                    SizedBox(width: 8),
                    Text(
                      'Test Instructions',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1f2937),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildInstructionItem('1', 'Position your face 30-40cm from the camera'),
                _buildInstructionItem('2', 'Look directly at the camera'),
                _buildInstructionItem('3', 'Keep your eyes open and relaxed'),
                _buildInstructionItem('4', 'The test will record for 10-15 seconds'),
                _buildInstructionItem('5', 'Try to keep your head still during recording'),
              ],
            ),
          ),
          const SizedBox(height: 24),
          
          // Note Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF3C7),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFFDE047)),
            ),
            child: const Row(
              children: [
                Icon(Icons.tips_and_updates, color: Color(0xFFEAB308), size: 24),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'The test analyzes your eye movements to detect subtle patterns that may indicate nystagmus.',
                    style: TextStyle(fontSize: 14, color: Color(0xFF78350F)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          
          // Start Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _cameraController?.value.isInitialized ?? false ? _startTest : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6366F1),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 2,
              ),
              child: const Text(
                'Start Test',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInstructionItem(String number, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: const Color(0xFF6366F1).withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Center(
              child: Text(
                number,
                style: const TextStyle(
                  color: Color(0xFF6366F1),
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                text,
                style: const TextStyle(fontSize: 14, color: Color(0xFF6b7280), height: 1.5),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecordingView() {
    return Stack(
      children: [
        // Camera preview
        if (_cameraController?.value.isInitialized ?? false)
          Center(
            child: AspectRatio(
              aspectRatio: _cameraController!.value.aspectRatio,
              child: CameraPreview(_cameraController!),
            ),
          ),
        
        // Recording overlay
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withOpacity(0.5),
                Colors.transparent,
                Colors.black.withOpacity(0.5),
              ],
            ),
          ),
        ),

        // Recording indicator
        Positioned(
          top: 20,
          left: 0,
          right: 0,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(25),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.fiber_manual_record, color: Colors.white, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    'RECORDING ${recordingDuration}s',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // Instructions overlay
        Positioned(
          bottom: 40,
          left: 20,
          right: 20,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.7),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                const Text(
                  'Look Straight at the Camera',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Keep your eyes open and relaxed',
                  style: TextStyle(color: Colors.white70),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                if (recordingDuration >= 10)
                  ElevatedButton(
                    onPressed: _stopRecording,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.red,
                    ),
                    child: const Text('Stop Recording'),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProcessingView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6366F1)),
                strokeWidth: 3,
              ),
              SizedBox(height: 24),
              Text(
                'Analyzing Video...',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1f2937),
                ),
              ),
              SizedBox(height: 12),
              Text(
                'Analyzing your eye movements for signs of nystagmus',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF6b7280), fontSize: 14),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResultsView() {
    final isNormal = nystagmusDetected == false;
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status Banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isNormal 
                  ? [const Color(0xFF10B981), const Color(0xFF059669)]
                  : [const Color(0xFFF59E0B), const Color(0xFFD97706)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: (isNormal ? const Color(0xFF10B981) : const Color(0xFFF59E0B)).withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                Icon(
                  isNormal ? Icons.check_circle_outline : Icons.info_outline,
                  size: 64,
                  color: Colors.white,
                ),
                const SizedBox(height: 12),
                Text(
                  isNormal ? 'No Nystagmus Detected' : 'Nystagmus Detected',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  isNormal ? 'Your eye movements appear normal' : 'Involuntary eye movements detected',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.white70,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),

          if (!isNormal) ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
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
                  _buildResultRow('Type', nystagmusType?.toUpperCase() ?? 'N/A'),
                  const Divider(height: 24),
                  _buildResultRow('Severity', nystagmusSeverity?.toUpperCase() ?? 'N/A'),
                  const Divider(height: 24),
                  _buildResultRow(
                    'Confidence',
                    confidence != null ? '${(confidence! * 100).toStringAsFixed(1)}%' : 'N/A',
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
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
                    Icon(Icons.medical_information, color: Color(0xFF6366F1), size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Diagnosis',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1f2937),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  diagnosis ?? 'No diagnosis available',
                  style: const TextStyle(fontSize: 14, color: Color(0xFF6b7280), height: 1.5),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
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
                    Icon(Icons.recommend, color: Color(0xFF6366F1), size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Recommendations',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1f2937),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  recommendations ?? 'No recommendations available',
                  style: const TextStyle(fontSize: 14, color: Color(0xFF6b7280), height: 1.5),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6366F1),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 2,
              ),
              child: const Text(
                'Done',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            color: Color(0xFF6b7280),
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1f2937),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 80, color: Colors.red),
            const SizedBox(height: 24),
            const Text(
              'Test Failed',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const Text(
              'An error occurred during the test. Please try again.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _currentPhase = TestPhase.instructions;
                });
              },
              child: const Text('Try Again'),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }
}

enum TestPhase {
  instructions,
  starting,
  recording,
  processing,
  results,
  error,
}
