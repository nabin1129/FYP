import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import '../../services/camera_service.dart';
import '../../config/app_theme.dart';

/// Camera Preview Widget
///
/// Displays camera feed for capturing eye images during tests.
class CameraPreviewWidget extends StatefulWidget {
  final CameraService cameraService;
  final VoidCallback onCapture;
  final String? instructions;
  final bool showSwitchCamera;

  const CameraPreviewWidget({
    super.key,
    required this.cameraService,
    required this.onCapture,
    this.instructions,
    this.showSwitchCamera = true,
  });

  @override
  State<CameraPreviewWidget> createState() => _CameraPreviewWidgetState();
}

class _CameraPreviewWidgetState extends State<CameraPreviewWidget> {
  @override
  Widget build(BuildContext context) {
    if (!widget.cameraService.isInitialized) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Initializing camera...'),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Camera Preview Container
        Expanded(
          child: Stack(
            children: [
              // Camera Feed
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppTheme.radiusLG),
                  border: Border.all(
                    color: AppTheme.primary,
                    width: 3,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppTheme.radiusLG),
                  child: CameraPreview(widget.cameraService.controller!),
                ),
              ),

              // Switch Camera Button (top right)
              if (widget.showSwitchCamera &&
                  widget.cameraService.hasMultipleCameras())
                Positioned(
                  top: 12,
                  right: 12,
                  child: Material(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(20),
                    child: InkWell(
                      onTap: _switchCamera,
                      borderRadius: BorderRadius.circular(20),
                      child: const Padding(
                        padding: EdgeInsets.all(8.0),
                        child: Icon(
                          Icons.flip_camera_ios,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    ),
                  ),
                ),

              // Alignment Guide Overlay
              Center(
                child: Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: Colors.white.withOpacity(0.5),
                      width: 2,
                    ),
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: const Center(
                    child: Text(
                      'Position your eye\nin the circle',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        shadows: [
                          Shadow(
                            color: Colors.black,
                            blurRadius: 4,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: AppTheme.spacingMD),

        // Instructions Banner
        if (widget.instructions != null)
          Container(
            padding: const EdgeInsets.all(AppTheme.spacingMD),
            decoration: BoxDecoration(
              color: AppTheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(AppTheme.radiusMD),
              border: Border.all(
                color: AppTheme.primary.withOpacity(0.3),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.info_outline,
                  color: AppTheme.primary,
                  size: 24,
                ),
                const SizedBox(width: AppTheme.spacingSM),
                Expanded(
                  child: Text(
                    widget.instructions!,
                    style: const TextStyle(
                      color: AppTheme.textDark,
                      fontSize: 14,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),

        const SizedBox(height: AppTheme.spacingMD),

        // Capture Button
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: widget.onCapture,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusMD),
              ),
              elevation: 2,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.camera_alt, size: 24),
                const SizedBox(width: AppTheme.spacingSM),
                const Text(
                  'Capture Image',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _switchCamera() async {
    try {
      await widget.cameraService.switchCamera();
      setState(() {}); // Refresh preview
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to switch camera: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }
}
