import 'dart:math' as math;

import 'package:flutter/material.dart';

enum VisualAcuityVariant { snellen, tumblingE, landoltC }

extension VisualAcuityVariantX on VisualAcuityVariant {
  String get apiValue {
    switch (this) {
      case VisualAcuityVariant.snellen:
        return 'snellen';
      case VisualAcuityVariant.tumblingE:
        return 'tumbling_e';
      case VisualAcuityVariant.landoltC:
        return 'landolt_c';
    }
  }

  String get title {
    switch (this) {
      case VisualAcuityVariant.snellen:
        return 'Snellen';
      case VisualAcuityVariant.tumblingE:
        return 'Tumbling E';
      case VisualAcuityVariant.landoltC:
        return 'Landolt C';
    }
  }

  String get description {
    switch (this) {
      case VisualAcuityVariant.snellen:
        return 'Identify the letter shown on screen.';
      case VisualAcuityVariant.tumblingE:
        return 'Tap the direction the E is facing.';
      case VisualAcuityVariant.landoltC:
        return 'Tap the direction of the gap in the ring.';
    }
  }

  String get answerPrompt {
    switch (this) {
      case VisualAcuityVariant.snellen:
        return 'Select the letter displayed above';
      case VisualAcuityVariant.tumblingE:
        return 'Select the E direction';
      case VisualAcuityVariant.landoltC:
        return 'Select the gap direction';
    }
  }

  List<String> get answerOptions {
    switch (this) {
      case VisualAcuityVariant.snellen:
        return const ['E', 'F', 'P', 'T', 'O', 'Z', 'L', 'D'];
      case VisualAcuityVariant.tumblingE:
      case VisualAcuityVariant.landoltC:
        return const ['up', 'right', 'down', 'left'];
    }
  }
}

class VisualAcuityQuestion {
  final VisualAcuityVariant variant;
  final String prompt;
  final String expectedAnswer;
  final String? direction;

  const VisualAcuityQuestion({
    required this.variant,
    required this.prompt,
    required this.expectedAnswer,
    this.direction,
  });

  static VisualAcuityQuestion generate(
    VisualAcuityVariant variant,
    math.Random random,
  ) {
    switch (variant) {
      case VisualAcuityVariant.snellen:
        const letters = ['E', 'F', 'P', 'T', 'O', 'Z', 'L', 'D'];
        final letter = letters[random.nextInt(letters.length)];
        return VisualAcuityQuestion(
          variant: variant,
          prompt: letter,
          expectedAnswer: letter,
        );
      case VisualAcuityVariant.tumblingE:
        const directions = ['up', 'right', 'down', 'left'];
        final direction = directions[random.nextInt(directions.length)];
        return VisualAcuityQuestion(
          variant: variant,
          prompt: 'E',
          expectedAnswer: direction,
          direction: direction,
        );
      case VisualAcuityVariant.landoltC:
        const directions = ['up', 'right', 'down', 'left'];
        final direction = directions[random.nextInt(directions.length)];
        return VisualAcuityQuestion(
          variant: variant,
          prompt: 'C',
          expectedAnswer: direction,
          direction: direction,
        );
    }
  }
}

class VisualAcuityStimulus extends StatelessWidget {
  final VisualAcuityQuestion question;
  final double fontSize;

  const VisualAcuityStimulus({
    super.key,
    required this.question,
    required this.fontSize,
  });

  @override
  Widget build(BuildContext context) {
    switch (question.variant) {
      case VisualAcuityVariant.snellen:
        return Text(
          question.prompt,
          style: TextStyle(
            fontSize: fontSize,
            color: Colors.black87,
            fontWeight: FontWeight.w700,
            fontFamily: 'Courier New',
            letterSpacing: 2,
          ),
        );
      case VisualAcuityVariant.tumblingE:
        return RotatedBox(
          quarterTurns: _quarterTurns(question.direction),
          child: Text(
            question.prompt,
            style: TextStyle(
              fontSize: fontSize,
              color: Colors.black87,
              fontWeight: FontWeight.w700,
              fontFamily: 'Courier New',
            ),
          ),
        );
      case VisualAcuityVariant.landoltC:
        return CustomPaint(
          size: Size.square(fontSize * 1.25),
          painter: _LandoltCPainter(
            direction: question.direction ?? 'right',
            color: Colors.black87,
            strokeWidth: math.max(6, fontSize * 0.12),
          ),
        );
    }
  }

  int _quarterTurns(String? direction) {
    switch (direction) {
      case 'up':
        return 3;
      case 'right':
        return 0;
      case 'down':
        return 1;
      case 'left':
        return 2;
      default:
        return 0;
    }
  }
}

class _LandoltCPainter extends CustomPainter {
  final String direction;
  final Color color;
  final double strokeWidth;

  _LandoltCPainter({
    required this.direction,
    required this.color,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) * 0.32;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = strokeWidth;

    const gapRadians = math.pi / 3;
    final gapCenter = switch (direction) {
      'right' => 0.0,
      'down' => math.pi / 2,
      'left' => math.pi,
      'up' => -math.pi / 2,
      _ => 0.0,
    };

    final startAngle = gapCenter + gapRadians / 2;
    final sweepAngle = (2 * math.pi) - gapRadians;
    final rect = Rect.fromCircle(center: center, radius: radius);
    canvas.drawArc(rect, startAngle, sweepAngle, false, paint);
  }

  @override
  bool shouldRepaint(covariant _LandoltCPainter oldDelegate) {
    return oldDelegate.direction != direction ||
        oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}
