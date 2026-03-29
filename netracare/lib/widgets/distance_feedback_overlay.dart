// Distance Feedback Overlay Widget
// Provides real-time visual feedback for distance positioning
// Author: NetraCare Team
// Date: January 26, 2026

import 'package:flutter/material.dart';
import 'package:netracare/config/app_theme.dart';
import '../models/distance_calibration_model.dart';

/// Animated overlay showing distance validation status
class DistanceFeedbackOverlay extends StatefulWidget {
  /// Current distance validation result
  final DistanceValidationResult? validationResult;

  /// Show detailed distance information?
  final bool showDetails;

  /// Overlay position
  final OverlayPosition position;

  const DistanceFeedbackOverlay({
    super.key,
    required this.validationResult,
    this.showDetails = true,
    this.position = OverlayPosition.top,
  });

  @override
  State<DistanceFeedbackOverlay> createState() =>
      _DistanceFeedbackOverlayState();
}

class _DistanceFeedbackOverlayState extends State<DistanceFeedbackOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final result = widget.validationResult;

    if (result == null) {
      return const SizedBox.shrink();
    }

    final color = Color(result.status.colorValue);
    final shouldPulse = !result.isValid;

    return Positioned(
      top: widget.position == OverlayPosition.top ? 20 : null,
      bottom: widget.position == OverlayPosition.bottom ? 20 : null,
      left: 0,
      right: 0,
      child: Center(
        child: AnimatedBuilder(
          animation: shouldPulse ? _pulseAnimation : const AlwaysStoppedAnimation(1.0),
          builder: (context, child) {
            return Transform.scale(
              scale: shouldPulse ? _pulseAnimation.value : 1.0,
              child: child,
            );
          },
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.4),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Status icon
                _buildStatusIcon(result.status),
                const SizedBox(height: 8),

                // Main message
                Text(
                  result.feedbackMessage,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: AppTheme.fontXL,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),

                // Detailed information
                if (widget.showDetails) ...[
                  const SizedBox(height: 8),
                  Text(
                    '${result.currentDistance.toStringAsFixed(1)} cm',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: AppTheme.fontBody,
                    ),
                  ),
                  if (result.status == DistanceStatus.acceptable ||
                      result.status == DistanceStatus.perfect)
                    Text(
                      'Target: ${result.referenceDistance.toStringAsFixed(0)} cm',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: AppTheme.fontSM,
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusIcon(DistanceStatus status) {
    IconData icon;
    switch (status) {
      case DistanceStatus.perfect:
      case DistanceStatus.acceptable:
        icon = Icons.check_circle;
        break;
      case DistanceStatus.tooClose:
        icon = Icons.arrow_back;
        break;
      case DistanceStatus.tooFar:
        icon = Icons.arrow_forward;
        break;
      case DistanceStatus.noFaceDetected:
        icon = Icons.face_retouching_off;
        break;
      case DistanceStatus.multipleFaces:
        icon = Icons.people_alt;
        break;
      case DistanceStatus.error:
        icon = Icons.error_outline;
        break;
    }

    return Icon(
      icon,
      color: Colors.white,
      size: 32,
    );
  }
}

/// Distance indicator ring (circular progress indicator)
class DistanceIndicatorRing extends StatelessWidget {
  /// Current distance validation result
  final DistanceValidationResult? validationResult;

  /// Ring size
  final double size;

  const DistanceIndicatorRing({
    super.key,
    required this.validationResult,
    this.size = 200,
  });

  @override
  Widget build(BuildContext context) {
    final result = validationResult;

    if (result == null) {
      return SizedBox(
        width: size,
        height: size,
        child: const CircularProgressIndicator(
          strokeWidth: 8,
          valueColor: AlwaysStoppedAnimation<Color>(AppTheme.textSecondary),
        ),
      );
    }

    final color = Color(result.status.colorValue);
    final progress = _calculateProgress(result);

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Background ring
          CircularProgressIndicator(
            value: 1.0,
            strokeWidth: 12,
            valueColor: AlwaysStoppedAnimation<Color>(
              AppTheme.textSecondary.withValues(alpha: 0.2),
            ),
          ),

          // Progress ring
          CircularProgressIndicator(
            value: progress,
            strokeWidth: 12,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),

          // Center content
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                result.isValid ? Icons.check_circle : Icons.warning_amber,
                color: color,
                size: 48,
              ),
              const SizedBox(height: 8),
              Text(
                '${result.currentDistance.toStringAsFixed(0)} cm',
                style: TextStyle(
                  fontSize: AppTheme.fontXXL,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  double _calculateProgress(DistanceValidationResult result) {
    // Calculate progress based on how close to reference distance
    final maxDeviation = result.toleranceCm * 2; // Â±tolerance
    final deviation = (result.delta.abs() / maxDeviation).clamp(0.0, 1.0);
    return 1.0 - deviation;
  }
}

/// Simple distance status bar
class DistanceStatusBar extends StatelessWidget {
  /// Current distance validation result
  final DistanceValidationResult? validationResult;

  const DistanceStatusBar({
    super.key,
    required this.validationResult,
  });

  @override
  Widget build(BuildContext context) {
    final result = validationResult;

    if (result == null) {
      return Container(
        height: 4,
        color: AppTheme.textSecondary.withValues(alpha: 0.3),
      );
    }

    final color = Color(result.status.colorValue);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      height: 4,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withValues(alpha: 0.5),
            color,
            color.withValues(alpha: 0.5),
          ],
        ),
      ),
    );
  }
}

/// Overlay position enum
enum OverlayPosition {
  top,
  bottom,
  center,
}
