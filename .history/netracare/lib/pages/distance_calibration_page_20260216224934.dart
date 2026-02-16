/// Distance Calibration Page
/// User-guided calibration flow for arm-length distance measurement
/// Author: NetraCare Team
/// Date: January 26, 2026

import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import '../models/distance_calibration_model.dart';
import '../services/distance_detection_service.dart';
import '../services/camera_manager_service.dart';
import '../services/api_service.dart';

/// Calibration page for distance enforcement
class DistanceCalibrationPage extends StatefulWidget {
  /// User ID for saving calibration
  final String userId;

  /// Callback when calibration completes
  final Function(DistanceCalibrationData)? onCalibrationComplete;

  const DistanceCalibrationPage({
    super.key,
    required this.userId,
    this.onCalibrationComplete,
  });

  @override
  State<DistanceCalibrationPage> createState() =>
      _DistanceCalibrationPageState();
}

class _DistanceCalibrationPageState extends State<DistanceCalibrationPage> {
  final DistanceDetectionService _distanceService = DistanceDetectionService();
  final CameraManagerService _cameraManager = CameraManagerService();

  CalibrationStep _currentStep = CalibrationStep.introduction;
  bool _isProcessing = false;
  String? _errorMessage;
  DistanceCalibrationData? _calibrationData;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      await _cameraManager.initialize(
        useFrontCamera: true,
        resolution:
            ResolutionPreset.medium, // Lower resolution for better performance
      );
      await _distanceService.initialize();
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage =
              'Camera initialization failed:\n'
              'Please ensure camera permissions are granted.\n\n'
              'Error: ${e.toString().replaceAll('Exception: ', '')}';
        });
      }
    }
  }

  @override
  void dispose() {
    _cameraManager.dispose();
    _distanceService.dispose();
    super.dispose();
  }

  Future<void> _performCalibration() async {
    if (!_cameraManager.isReady) {
      setState(() {
        _errorMessage = 'Camera not ready. Please restart the calibration.';
        _currentStep = CalibrationStep.error;
      });
      return;
    }

    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    try {
      // Perform calibration at standard arm length (45 cm)
      final calibration = await _distanceService.performCalibration(
        userId: widget.userId,
        referenceDistanceCm: 45.0,
      );

      if (calibration == null) {
        throw Exception('Calibration failed - no data returned');
      }

      // Save to backend
      await ApiService.saveDistanceCalibration(calibration);

      if (mounted) {
        setState(() {
          _calibrationData = calibration;
          _currentStep = CalibrationStep.success;
          _isProcessing = false;
        });

        // Notify parent
        widget.onCalibrationComplete?.call(calibration);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          // Clean up the error message
          String cleanError = e.toString();
          cleanError = cleanError.replaceAll('Exception: ', '');
          _errorMessage = cleanError;
          _isProcessing = false;
          _currentStep = CalibrationStep.error;
        });
      }
    }
  }

  void _nextStep() {
    setState(() {
      switch (_currentStep) {
        case CalibrationStep.introduction:
          _currentStep = CalibrationStep.positioning;
          break;
        case CalibrationStep.positioning:
          _currentStep = CalibrationStep.capture;
          break;
        case CalibrationStep.capture:
          _performCalibration();
          break;
        case CalibrationStep.success:
        case CalibrationStep.error:
          Navigator.of(context).pop(_calibrationData);
          break;
      }
    });
  }

  void _previousStep() {
    setState(() {
      switch (_currentStep) {
        case CalibrationStep.positioning:
          _currentStep = CalibrationStep.introduction;
          break;
        case CalibrationStep.capture:
          _currentStep = CalibrationStep.positioning;
          break;
        case CalibrationStep.error:
          _currentStep = CalibrationStep.capture;
          _errorMessage = null;
          break;
        default:
          Navigator.of(context).pop();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Distance Calibration'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: Stack(
          children: [
            // Camera preview
            if (_cameraManager.isReady &&
                _currentStep != CalibrationStep.introduction &&
                _currentStep != CalibrationStep.success)
              Positioned.fill(child: CameraPreview(_cameraManager.controller!)),

            // Content overlay
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(0.7),
                      Colors.transparent,
                      Colors.black.withOpacity(0.7),
                    ],
                  ),
                ),
                child: _buildStepContent(),
              ),
            ),

            // Processing overlay
            if (_isProcessing)
              Container(
                color: Colors.black.withOpacity(0.8),
                child: const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: Colors.white),
                      SizedBox(height: 20),
                      Text(
                        'Calibrating...',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 8),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 40.0),
                        child: Text(
                          'Detecting face and measuring eye distance',
                          style: TextStyle(color: Colors.white70, fontSize: 14),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepContent() {
    switch (_currentStep) {
      case CalibrationStep.introduction:
        return _buildIntroduction();
      case CalibrationStep.positioning:
        return _buildPositioning();
      case CalibrationStep.capture:
        return _buildCapture();
      case CalibrationStep.success:
        return _buildSuccess();
      case CalibrationStep.error:
        return _buildError();
    }
  }

  Widget _buildIntroduction() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.straighten, size: 100, color: Colors.blue),
          const SizedBox(height: 30),
          const Text(
            'Calibrate Arm-Length Distance',
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          const Text(
            'For accurate visual acuity testing, we need to measure your arm-length distance.',
            style: TextStyle(color: Colors.white70, fontSize: 16),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.withOpacity(0.3)),
            ),
            child: const Row(
              children: [
                Icon(Icons.straighten, color: Colors.blue, size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Typically 40-50 cm (about 16-20 inches)',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 40),
          _buildInstructionCard(
            icon: Icons.pan_tool,
            title: 'Extend Your Arm',
            description: 'Hold the phone at full arm\'s length',
          ),
          const SizedBox(height: 15),
          _buildInstructionCard(
            icon: Icons.face,
            title: 'Face the Camera',
            description: 'Keep your face centered and clearly visible',
          ),
          const SizedBox(height: 15),
          _buildInstructionCard(
            icon: Icons.camera,
            title: 'Capture',
            description: 'Hold steady while we measure',
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _nextStep,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Start Calibration',
                style: TextStyle(fontSize: 18, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPositioning() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        children: [
          const SizedBox(height: 50),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.2),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.blue, width: 2),
            ),
            child: Column(
              children: [
                const Icon(Icons.pan_tool, color: Colors.blue, size: 50),
                const SizedBox(height: 15),
                const Text(
                  'Extend Your Arm Fully',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                const Text(
                  'Hold the phone at arm\'s length (about 40-50 cm)',
                  style: TextStyle(color: Colors.white70, fontSize: 16),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Your arm should be fully extended, not bent',
                  style: TextStyle(
                    color: Colors.blue.shade200,
                    fontSize: 14,
                    fontStyle: FontStyle.italic,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const Spacer(),
          // Face guide overlay
          Container(
            width: 250,
            height: 320,
            decoration: BoxDecoration(
              border: Border.all(
                color: Colors.white.withOpacity(0.5),
                width: 2,
              ),
              borderRadius: BorderRadius.circular(150),
            ),
            child: const Center(
              child: Icon(Icons.face, size: 150, color: Colors.white30),
            ),
          ),
          const Spacer(),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _previousStep,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text('Back'),
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: _nextStep,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text(
                    'I\'m Ready',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCapture() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        children: [
          const SizedBox(height: 50),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.2),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.green, width: 2),
            ),
            child: const Column(
              children: [
                Icon(Icons.center_focus_strong, color: Colors.green, size: 50),
                SizedBox(height: 15),
                Text(
                  'Hold Steady',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 10),
                Text(
                  'Keep your arm extended and face centered',
                  style: TextStyle(color: Colors.white70, fontSize: 16),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _isProcessing ? null : _nextStep,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Capture Calibration',
                style: TextStyle(fontSize: 18, color: Colors.white),
              ),
            ),
          ),
          const SizedBox(height: 10),
          TextButton(
            onPressed: _previousStep,
            child: const Text('Back', style: TextStyle(color: Colors.white70)),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccess() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.check_circle, size: 100, color: Colors.green),
          const SizedBox(height: 30),
          const Text(
            'Calibration Successful!',
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          if (_calibrationData != null) ...[
            _buildCalibrationDetail(
              'Reference Distance',
              '${_calibrationData!.referenceDistance.toStringAsFixed(1)} cm',
            ),
            _buildCalibrationDetail(
              'Focal Length',
              _calibrationData!.focalLength.toStringAsFixed(2),
            ),
            _buildCalibrationDetail(
              'IPD (Baseline)',
              '${_calibrationData!.baselineIpdPixels.toStringAsFixed(1)} px',
            ),
            _buildCalibrationDetail(
              'Tolerance',
              '±${_calibrationData!.toleranceCm.toStringAsFixed(1)} cm',
            ),
          ],
          const SizedBox(height: 40),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _nextStep,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Continue',
                style: TextStyle(fontSize: 18, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 100, color: Colors.red),
          const SizedBox(height: 30),
          const Text(
            'Calibration Failed',
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              _errorMessage ?? 'Unknown error occurred',
              style: const TextStyle(color: Colors.white, fontSize: 15),
              textAlign: TextAlign.left,
            ),
          ),
          const SizedBox(height: 30),
          // Troubleshooting tips
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.withOpacity(0.5)),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.lightbulb_outline, color: Colors.blue, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Troubleshooting Tips',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12),
                Text(
                  '• Ensure good lighting on your face\n'
                  '• Hold device at true arm\'s length\n'
                  '• Look directly at the camera\n'
                  '• Keep eyes open and visible\n'
                  '• Remove glasses if detection fails',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 30),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _previousStep,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Try Again',
                style: TextStyle(fontSize: 18, color: Colors.white),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'Skip Calibration',
              style: TextStyle(color: Colors.white70),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInstructionCard({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.blue, size: 32),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalibrationDetail(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 16),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

/// Calibration flow steps
enum CalibrationStep { introduction, positioning, capture, success, error }
