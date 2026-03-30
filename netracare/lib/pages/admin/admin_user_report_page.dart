import 'package:flutter/material.dart';
import '../../config/app_theme.dart';
import '../../models/admin/admin_user_model.dart';
import '../../services/admin_service.dart';

class AdminUserReportPage extends StatefulWidget {
  final AdminUser user;
  const AdminUserReportPage({super.key, required this.user});

  @override
  State<AdminUserReportPage> createState() => _AdminUserReportPageState();
}

class _AdminUserReportPageState extends State<AdminUserReportPage> {
  final AdminService _service = AdminService();
  Map<String, dynamic>? _report;
  bool _loading = true;
  String? _error;
  int _days = 30;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await _service.fetchUserReport(
        userId: widget.user.backendId,
        days: _days,
      );
      if (!mounted) return;
      setState(() => _report = data);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _downloadPdf() async {
    try {
      final res = await _service.downloadUserReportPdf(
        userId: widget.user.backendId,
        days: _days,
      );
      if (res.statusCode == 200) {
        final bytes = res.bodyBytes;
        if (bytes.isNotEmpty) {
          // In-app viewing/sharing can be added later; for now just confirm download success
          _showSnack('PDF ready (${bytes.lengthInBytes} bytes)');
        } else {
          _showSnack('PDF generated but empty');
        }
      } else {
        final msg = res.body.isNotEmpty ? res.body : 'Failed to download PDF';
        _showSnack(msg);
      }
    } catch (e) {
      _showSnack('Download failed: $e');
    }
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    final report = _report;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        elevation: 0,
        title: Text(
          'AI Report — ${widget.user.name}',
          style: const TextStyle(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              value: _days,
              items: const [
                DropdownMenuItem(value: 7, child: Text('7d')),
                DropdownMenuItem(value: 30, child: Text('30d')),
                DropdownMenuItem(value: 90, child: Text('90d')),
              ],
              onChanged: (v) {
                if (v == null) return;
                setState(() => _days = v);
                _load();
              },
            ),
          ),
          IconButton(
            icon: const Icon(
              Icons.picture_as_pdf_outlined,
              color: AppTheme.primary,
            ),
            onPressed: _downloadPdf,
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: AppTheme.textSecondary),
            onPressed: _load,
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primary),
            )
          : _error != null
          ? _buildError()
          : report == null
          ? _buildEmpty()
          : RefreshIndicator(
              color: AppTheme.primary,
              onRefresh: _load,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(AppTheme.spaceMD),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildScoreHeader(report),
                    const SizedBox(height: AppTheme.spaceMD),
                    _buildScoreChips(report),
                    const SizedBox(height: AppTheme.spaceMD),
                    _buildFindings(report),
                    const SizedBox(height: AppTheme.spaceMD),
                    _buildAiText(report),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: AppTheme.error),
          const SizedBox(height: 12),
          Text(_error ?? 'Failed to load report'),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: _load,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(AppTheme.spaceLG),
        child: Text('No report available'),
      ),
    );
  }

  Widget _buildScoreHeader(Map<String, dynamic> report) {
    final overall = report['overall_score'] as num? ?? 0;
    final timeRange = report['time_range_days'] ?? _days;
    return Container(
      padding: const EdgeInsets.all(AppTheme.spaceMD),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              gradient: AppTheme.primaryGradient,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                overall.toStringAsFixed(1),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: AppTheme.fontHeading,
                ),
              ),
            ),
          ),
          const SizedBox(width: AppTheme.spaceMD),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.user.name,
                  style: const TextStyle(
                    fontSize: AppTheme.fontLG,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Data from last $timeRange days',
                  style: const TextStyle(color: AppTheme.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScoreChips(Map<String, dynamic> report) {
    final scores = report['scores'] as Map<String, dynamic>? ?? {};
    final entries = scores.entries.toList();
    return Wrap(
      spacing: AppTheme.spaceSM,
      runSpacing: AppTheme.spaceSM,
      children: entries
          .map(
            (e) => Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.spaceMD,
                vertical: AppTheme.spaceSM,
              ),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                border: Border.all(color: AppTheme.border),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.bubble_chart_outlined,
                    size: 14,
                    color: AppTheme.primary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    e.key.replaceAll('_', ' ').toUpperCase(),
                    style: const TextStyle(
                      fontSize: AppTheme.fontXS,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${(e.value as num).toStringAsFixed(1)} / 100',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _buildFindings(Map<String, dynamic> report) {
    final findings = report['findings'] as Map<String, dynamic>? ?? {};
    if (findings.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(AppTheme.spaceMD),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Key Findings',
            style: TextStyle(
              fontSize: AppTheme.fontLG,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: AppTheme.spaceSM),
          ...findings.entries.map(
            (e) => Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.brightness_1,
                    size: 8,
                    color: AppTheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${e.key.replaceAll('_', ' ').toUpperCase()}: ${e.value}',
                      style: const TextStyle(color: AppTheme.textPrimary),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAiText(Map<String, dynamic> report) {
    final text = report['ai_report_text'] as String? ?? '';
    if (text.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(AppTheme.spaceMD),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'AI Report',
            style: TextStyle(
              fontSize: AppTheme.fontLG,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: AppTheme.spaceSM),
          Text(
            text,
            style: const TextStyle(height: 1.4, color: AppTheme.textPrimary),
          ),
        ],
      ),
    );
  }
}
