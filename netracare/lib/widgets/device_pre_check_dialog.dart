import 'package:flutter/material.dart';
import 'package:netracare/config/app_theme.dart';
import 'package:netracare/services/device_pre_check_service.dart';

/// Shows a blocking pre-test checklist.
///
/// Returns `true` if the user confirms they meet requirements and the camera
/// check passes. Returns `false` if requirements cannot be met (hard fail).
Future<bool> showDevicePreCheckDialog(BuildContext context) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const _DevicePreCheckDialog(),
  );
  return result ?? false;
}

class _DevicePreCheckDialog extends StatefulWidget {
  const _DevicePreCheckDialog();

  @override
  State<_DevicePreCheckDialog> createState() => _DevicePreCheckDialogState();
}

class _DevicePreCheckDialogState extends State<_DevicePreCheckDialog> {
  PreCheckResult? _result;
  bool _luxConfirmed = false;
  bool _distanceConfirmed = false;
  bool _checking = true;

  @override
  void initState() {
    super.initState();
    _runCheck();
  }

  Future<void> _runCheck() async {
    final result = await DevicePreCheckService.run();
    if (mounted) {
      setState(() {
        _result = result;
        _checking = false;
      });
    }
  }

  bool get _canProceed =>
      !_checking &&
      (_result?.canProceed ?? false) &&
      _luxConfirmed &&
      _distanceConfirmed;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Pre-Test Requirements'),
      content: _checking
          ? const SizedBox(
              height: 80,
              child: Center(child: CircularProgressIndicator()),
            )
          : _buildChecklist(),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _canProceed ? () => Navigator.pop(context, true) : null,
          style: AppTheme.primaryButton,
          child: const Text('Start Test'),
        ),
      ],
    );
  }

  Widget _buildChecklist() {
    final r = _result!;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _CheckRow(
            label: 'Camera resolution',
            status: r.cameraResolution,
            detail: r.cameraResolutionDetail,
          ),
          const SizedBox(height: 8),
          _ManualCheckRow(
            label: 'Ambient lighting ≥ 50 lux',
            hint: 'Ensure you are in a well-lit room (daylight or desk lamp).',
            checked: _luxConfirmed,
            onChanged: (v) => setState(() => _luxConfirmed = v),
          ),
          const SizedBox(height: 8),
          _ManualCheckRow(
            label: 'Face distance 28–38 cm',
            hint:
                'Hold your device so your face is ${DevicePreCheckService.minDistanceCm.toInt()}–'
                '${DevicePreCheckService.maxDistanceCm.toInt()} cm from the camera.',
            checked: _distanceConfirmed,
            onChanged: (v) => setState(() => _distanceConfirmed = v),
          ),
          if (r.cameraResolution == PreCheckStatus.warning) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                border: Border.all(color: Colors.orange),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.warning, color: Colors.orange, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Camera resolution is below recommended (1920×1080). '
                      'Test results may vary due to lower image quality.',
                      style: TextStyle(
                        color: Colors.orange.shade900,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CheckRow extends StatelessWidget {
  final String label;
  final PreCheckStatus status;
  final String? detail;

  const _CheckRow({required this.label, required this.status, this.detail});

  @override
  Widget build(BuildContext context) {
    final icon = switch (status) {
      PreCheckStatus.pass => const Icon(
        Icons.check_circle,
        color: Colors.green,
      ),
      PreCheckStatus.warning => const Icon(Icons.warning, color: Colors.orange),
      PreCheckStatus.fail => const Icon(Icons.cancel, color: Colors.red),
      PreCheckStatus.unavailable => const Icon(
        Icons.help_outline,
        color: Colors.orange,
      ),
    };

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        icon,
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
              if (detail != null)
                Text(
                  detail!,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ManualCheckRow extends StatelessWidget {
  final String label;
  final String hint;
  final bool checked;
  final ValueChanged<bool> onChanged;

  const _ManualCheckRow({
    required this.label,
    required this.hint,
    required this.checked,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Checkbox(
          value: checked,
          activeColor: AppTheme.primary,
          onChanged: (v) => onChanged(v ?? false),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  hint,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
