/// Face Alignment Guide Widget
/// Provides visual guidance for proper face positioning
/// Author: NetraCare Team
/// Date: January 26, 2026

import 'package:flutter/material.dart';
import '../models/distance_calibration_model.dart';

/// Visual guide showing optimal face position
class FaceAlignmentGuide extends StatelessWidget {
  /// Current distance validation result
  final DistanceValidationResult? validationResult;

  /// Show guide overlay?
  final bool showGuide;

  /// Guide opacity
  final double opacity;

  const FaceAlignmentGuide({
    super.key,
    required this.validationResult,
    this.showGuide = true,
    this.opacity = 0.5,
  });

  @override
  Widget build(BuildContext context) {
    if (!showGuide) {
      return const SizedBox.shrink();
    }

    final result = validationResult;
    final color = result != null
        ? Color(result.status.colorValue)
        : Colors.white;

    return Center(
      child: CustomPaint(
        size: const Size(250, 320),
        painter: _FaceGuidePainter(
          color: color,
          opacity: opacity,
          isValid: result?.isValid ?? false,
        ),
      ),
    );
  }
}

/// Custom painter for face guide overlay
class _FaceGuidePainter extends CustomPainter {
  final Color color;
  final double opacity;
  final bool isValid;

  _FaceGuidePainter({
    required this.color,
    required this.opacity,
    required this.isValid,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withOpacity(opacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;

    final dashedPaint = Paint()
      ..color = color.withOpacity(opacity * 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    // Draw face oval
    final ovalRect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2.2),
      width: size.width * 0.7,
      height: size.height * 0.65,
    );
    canvas.drawOval(ovalRect, paint);

    // Draw eye guides
    final leftEyeCenter = Offset(size.width * 0.35, size.height * 0.38);
    final rightEyeCenter = Offset(size.width * 0.65, size.height * 0.38);
    final eyeRadius = 15.0;

    canvas.drawCircle(leftEyeCenter, eyeRadius, dashedPaint);
    canvas.drawCircle(rightEyeCenter, eyeRadius, dashedPaint);

    // Draw nose guide (small vertical line)
    final noseTop = Offset(size.width / 2, size.height * 0.48);
    final noseBottom = Offset(size.width / 2, size.height * 0.55);
    canvas.drawLine(noseTop, noseBottom, dashedPaint);

    // Draw corner indicators
    _drawCornerIndicators(canvas, size, paint);

    // Draw center crosshair if valid
    if (isValid) {
      _drawCenterCrosshair(canvas, size, paint);
    }
  }

  void _drawCornerIndicators(Canvas canvas, Size size, Paint paint) {
    const cornerLength = 20.0;
    final corners = [
      // Top-left
      [Offset(0, cornerLength), const Offset(0, 0), Offset(cornerLength, 0)],
      // Top-right
      [
        Offset(size.width - cornerLength, 0),
        Offset(size.width, 0),
        Offset(size.width, cornerLength),
      ],
      // Bottom-left
      [
        Offset(0, size.height - cornerLength),
        Offset(0, size.height),
        Offset(cornerLength, size.height),
      ],
      // Bottom-right
      [
        Offset(size.width - cornerLength, size.height),
        Offset(size.width, size.height),
        Offset(size.width, size.height - cornerLength),
      ],
    ];

    for (final corner in corners) {
      final path = Path()
        ..moveTo(corner[0].dx, corner[0].dy)
        ..lineTo(corner[1].dx, corner[1].dy)
        ..lineTo(corner[2].dx, corner[2].dy);
      canvas.drawPath(path, paint);
    }
  }

  void _drawCenterCrosshair(Canvas canvas, Size size, Paint paint) {
    final center = Offset(size.width / 2, size.height / 2);
    const lineLength = 15.0;

    canvas.drawLine(
      Offset(center.dx - lineLength, center.dy),
      Offset(center.dx + lineLength, center.dy),
      paint..strokeWidth = 2.0,
    );

    canvas.drawLine(
      Offset(center.dx, center.dy - lineLength),
      Offset(center.dx, center.dy + lineLength),
      paint,
    );
  }

  @override
  bool shouldRepaint(_FaceGuidePainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.opacity != opacity ||
        oldDelegate.isValid != isValid;
  }
}

/// Animated face silhouette guide
class FaceSilhouetteGuide extends StatefulWidget {
  /// Current distance validation result
  final DistanceValidationResult? validationResult;

  const FaceSilhouetteGuide({super.key, required this.validationResult});

  @override
  State<FaceSilhouetteGuide> createState() => _FaceSilhouetteGuideState();
}

class _FaceSilhouetteGuideState extends State<FaceSilhouetteGuide>
    with SingleTickerProviderStateMixin {
  late AnimationController _scaleController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _scaleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final result = widget.validationResult;
    final shouldAnimate = result != null && !result.isValid;

    return Center(
      child: AnimatedBuilder(
        animation: shouldAnimate
            ? _scaleAnimation
            : const AlwaysStoppedAnimation(1.0),
        builder: (context, child) {
          return Transform.scale(
            scale: shouldAnimate ? _scaleAnimation.value : 1.0,
            child: child,
          );
        },
        child: Icon(
          Icons.face,
          size: 200,
          color: result != null
              ? Color(result.status.colorValue).withOpacity(0.3)
              : Colors.white.withOpacity(0.3),
        ),
      ),
    );
  }
}
