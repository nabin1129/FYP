import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:netracare/config/app_theme.dart';
import 'package:netracare/config/api_config.dart';
import 'package:netracare/services/doctor_service.dart';
import 'package:netracare/services/doctor_api_service.dart';
import 'package:netracare/models/doctor/patient_model.dart';
import 'package:netracare/models/doctor/medical_record_model.dart';
import 'add_clinical_note_page.dart';
import 'add_medical_record_page.dart';

/// Patient Detail Page - View patient info, test results, records, and notes
class PatientDetailPage extends StatefulWidget {
  final String patientId;

  const PatientDetailPage({super.key, required this.patientId});

  @override
  State<PatientDetailPage> createState() => _PatientDetailPageState();
}

class _PatientDetailPageState extends State<PatientDetailPage>
    with SingleTickerProviderStateMixin {
  final DoctorService _doctorService = DoctorService();
  late TabController _tabController;

  Patient? _patient;
  List<MedicalRecord> _medicalRecords = [];
  List<ClinicalNote> _clinicalNotes = [];
  Map<String, List<Map<String, dynamic>>> _testHistory = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final token = await DoctorApiService.getDoctorToken();
      if (token != null) {
        final patientId = int.tryParse(widget.patientId);
        if (patientId != null) {
          final response = await http.get(
            Uri.parse(
              '${ApiConfig.baseUrl}${ApiConfig.doctorPatientDetailEndpoint(patientId)}',
            ),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
          );

          if (response.statusCode == 200) {
            final data = jsonDecode(response.body) as Map<String, dynamic>;
            final patientJson = data['patient'] as Map<String, dynamic>?;
            final historyJson =
                data['test_history'] as Map<String, dynamic>? ?? {};

            if (mounted) {
              setState(() {
                if (patientJson != null) {
                  _patient = Patient.fromJson(patientJson);
                }
                _testHistory = historyJson.map(
                  (key, value) => MapEntry(
                    key,
                    List<Map<String, dynamic>>.from(value as List),
                  ),
                );
                _medicalRecords = _doctorService.getMedicalRecords(
                  widget.patientId,
                );
                _clinicalNotes = _doctorService.getClinicalNotes(
                  widget.patientId,
                );
                _isLoading = false;
              });
            }
            return;
          }
        }
      }
    } catch (_) {
      // Fall through to local data
    }

    // Fallback to local service data
    if (mounted) {
      setState(() {
        _patient = _doctorService.getPatientById(widget.patientId);
        _medicalRecords = _doctorService.getMedicalRecords(widget.patientId);
        _clinicalNotes = _doctorService.getClinicalNotes(widget.patientId);
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(
          backgroundColor: AppTheme.surface,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: AppTheme.textPrimary),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_patient == null) {
      return Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(
          backgroundColor: AppTheme.surface,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: AppTheme.textPrimary),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: const Center(child: Text('Patient not found')),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [_buildSliverAppBar()];
        },
        body: Column(
          children: [
            _buildTabBar(),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildTestResultsTab(),
                  _buildMedicalRecordsTab(),
                  _buildClinicalNotesTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Compute a display health score from the loaded test history.
  /// Falls back to the DB-stored value only when no test data is available.
  String _computeHealthScore() {
    if (_testHistory.isEmpty) {
      final stored = _patient?.healthScore ?? 0;
      return stored > 0 ? '$stored' : 'N/A';
    }

    final scores = <int>[];

    // Visual Acuity — use score (% correct)
    final va = _testHistory['visual_acuity'];
    if (va != null && va.isNotEmpty) {
      final s = va.first['score'];
      if (s != null) scores.add((s as num).round());
    }

    // Colour Vision — use score (0-100)
    final cv = _testHistory['colour_vision'];
    if (cv != null && cv.isNotEmpty) {
      final s = cv.first['score'];
      if (s != null) scores.add((s as num).round());
    }

    // Blink Fatigue — alertness_percentage
    final bf = _testHistory['blink_fatigue'];
    if (bf != null && bf.isNotEmpty) {
      final s = bf.first['alertness_percentage'];
      if (s != null) scores.add((s as num).round());
    }

    // Pupil Reflex — derive from nystagmus flag + reaction time
    final pr = _testHistory['pupil_reflex'];
    if (pr != null && pr.isNotEmpty) {
      final nystagmus = pr.first['nystagmus_detected'] == true;
      final rt = pr.first['reaction_time'];
      int prScore = 100;
      if (nystagmus) prScore -= 20;
      if (rt != null && (rt as num) > 0.4) prScore -= 15;
      scores.add(prScore.clamp(0, 100));
    }

    // Eye Tracking — overall_performance_score
    final et = _testHistory['eye_tracking'];
    if (et != null && et.isNotEmpty) {
      final s = et.first['overall_performance_score'];
      if (s != null) scores.add((s as num).round());
    }

    if (scores.isEmpty) return 'N/A';
    final avg = scores.reduce((a, b) => a + b) ~/ scores.length;
    return '$avg';
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 240,
      pinned: true,
      backgroundColor: AppTheme.surface,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: AppTheme.textPrimary),
        onPressed: () => Navigator.pop(context),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(gradient: AppTheme.primaryGradient),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 50, 20, 20),
              child: Column(
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 40,
                        backgroundColor: Colors.white.withValues(alpha: 0.2),
                        child: Text(
                          _patient!.initials,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: AppTheme.fontHeading,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppTheme.spaceMD),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _patient!.name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: AppTheme.fontTitle,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${_patient!.age ?? 'N/A'} years • ${_patient!.sex ?? 'N/A'}',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.9),
                                fontSize: AppTheme.fontBody,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _patient!.email,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.8),
                                fontSize: AppTheme.fontSM,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppTheme.spaceMD),
                  Row(
                    children: [
                      _buildPatientStat(
                        'Health Score',
                        _computeHealthScore(),
                        _patient!.trend == 'up'
                            ? Icons.trending_up
                            : _patient!.trend == 'down'
                            ? Icons.trending_down
                            : Icons.trending_flat,
                      ),
                      const SizedBox(width: AppTheme.spaceMD),
                      _buildPatientStat('Status', _patient!.status.label, null),
                      const SizedBox(width: AppTheme.spaceMD),
                      _buildPatientStat(
                        'Last Test',
                        _patient!.lastTestAgo,
                        null,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPatientStat(String label, String value, IconData? icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spaceSM,
          vertical: AppTheme.spaceSM,
        ),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: AppTheme.fontLG,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (icon != null) ...[
                  const SizedBox(width: 4),
                  Icon(icon, color: Colors.white, size: 16),
                ],
              ],
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.8),
                fontSize: AppTheme.fontXS,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      color: AppTheme.surface,
      child: TabBar(
        controller: _tabController,
        labelColor: AppTheme.primary,
        unselectedLabelColor: AppTheme.textSecondary,
        indicatorColor: AppTheme.primary,
        indicatorWeight: 2,
        labelStyle: const TextStyle(
          fontSize: AppTheme.fontSM,
          fontWeight: FontWeight.w600,
        ),
        tabs: const [
          Tab(text: 'Test Results'),
          Tab(text: 'Medical Records'),
          Tab(text: 'Clinical Notes'),
        ],
      ),
    );
  }

  // ============================================
  // TEST RESULTS TAB
  // ============================================
  Widget _buildTestResultsTab() {
    // Use real test history from API when available
    if (_testHistory.isNotEmpty) {
      return _buildRealTestHistory();
    }

    // Fallback to PatientTestSummary from local model
    final testSummary = _patient!.testSummary;
    if (testSummary == null) {
      return _buildEmptyState('No test results available', Icons.assignment);
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppTheme.spaceMD),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTestProgressCard(testSummary),
          const SizedBox(height: AppTheme.spaceMD),
          const Text(
            'Test Results',
            style: TextStyle(
              fontSize: AppTheme.fontLG,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: AppTheme.spaceSM),
          _buildTestResultCard(
            'Visual Acuity',
            testSummary.visualAcuityScore ?? 'Not taken',
            Icons.visibility,
            testSummary.visualAcuityScore != null,
          ),
          _buildTestResultCard(
            'Blink Rate',
            testSummary.blinkRate != null
                ? '${testSummary.blinkRate} bpm'
                : 'Not taken',
            Icons.remove_red_eye,
            testSummary.blinkRate != null,
          ),
          _buildTestResultCard(
            'Fatigue Level',
            testSummary.fatigueLevel ?? 'Not taken',
            Icons.bedtime,
            testSummary.fatigueLevel != null,
          ),
          _buildTestResultCard(
            'Colour Vision',
            testSummary.colourVisionStatus ?? 'Not taken',
            Icons.color_lens,
            testSummary.colourVisionStatus != null,
          ),
          _buildTestResultCard(
            'Pupil Reflex',
            testSummary.pupilReflexStatus ?? 'Not taken',
            Icons.flash_on,
            testSummary.pupilReflexStatus != null,
          ),
        ],
      ),
    );
  }

  Widget _buildTestProgressCard(PatientTestSummary summary) {
    final progress = summary.testsCompleted / summary.totalTests;

    return Container(
      padding: const EdgeInsets.all(AppTheme.spaceMD),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Test Progress',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              Text(
                '${summary.testsCompleted}/${summary.totalTests} completed',
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: AppTheme.fontSM,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spaceSM),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: AppTheme.testIconBackground,
              valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primary),
              minHeight: 8,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTestResultCard(
    String testName,
    String result,
    IconData icon,
    bool isCompleted,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.spaceSM),
      padding: const EdgeInsets.all(AppTheme.spaceMD),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: isCompleted
                  ? AppTheme.testIconBackground
                  : AppTheme.textLight.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
            ),
            child: Icon(
              icon,
              color: isCompleted ? AppTheme.testIconColor : AppTheme.textLight,
              size: 22,
            ),
          ),
          const SizedBox(width: AppTheme.spaceMD),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  testName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                Text(
                  result,
                  style: TextStyle(
                    fontSize: AppTheme.fontSM,
                    color: isCompleted
                        ? AppTheme.textSecondary
                        : AppTheme.textLight,
                  ),
                ),
              ],
            ),
          ),
          if (isCompleted)
            const Icon(Icons.check_circle, color: AppTheme.success, size: 20),
        ],
      ),
    );
  }

  // ============================================
  // REAL TEST HISTORY (from API)
  // ============================================
  Widget _buildRealTestHistory() {
    final testTypes = {
      'visual_acuity': (label: 'Visual Acuity', icon: Icons.visibility),
      'colour_vision': (label: 'Colour Vision', icon: Icons.color_lens),
      'blink_fatigue': (label: 'Blink Fatigue', icon: Icons.remove_red_eye),
      'pupil_reflex': (label: 'Pupil Reflex', icon: Icons.flash_on),
      'eye_tracking': (label: 'Eye Tracking', icon: Icons.track_changes),
    };

    final hasAny = testTypes.keys.any(
      (k) => (_testHistory[k]?.isNotEmpty ?? false),
    );

    if (!hasAny) {
      return _buildEmptyState('No test results available', Icons.assignment);
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppTheme.spaceMD),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final entry in testTypes.entries)
            if (_testHistory[entry.key]?.isNotEmpty ?? false) ...[
              _buildTestHistorySection(
                entry.value.label,
                entry.value.icon,
                _testHistory[entry.key]!,
              ),
              const SizedBox(height: AppTheme.spaceMD),
            ],
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  String _timeAgo(String? iso) {
    if (iso == null) return '';
    final dt = DateTime.tryParse(iso);
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt);
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    return 'Just now';
  }

  Widget _buildTestHistorySection(
    String label,
    IconData icon,
    List<Map<String, dynamic>> results,
  ) {
    final latest = results.first;
    final dateStr = _timeAgo(latest['created_at'] as String?);
    final resultText = _extractTestResultText(label, latest);

    // Build secondary detail rows specific to each test type
    final List<_DetailRow> details = _buildDetailRows(label, latest);

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
          // Header row
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppTheme.testIconBackground,
                  borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                ),
                child: Icon(icon, color: AppTheme.testIconColor, size: 20),
              ),
              const SizedBox(width: AppTheme.spaceSM),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: AppTheme.fontBody,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    Text(
                      resultText,
                      style: const TextStyle(
                        fontSize: AppTheme.fontSM,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (dateStr.isNotEmpty)
                    Text(
                      dateStr,
                      style: const TextStyle(
                        fontSize: AppTheme.fontXS,
                        color: AppTheme.textLight,
                      ),
                    ),
                  Row(
                    children: [
                      const Icon(
                        Icons.history,
                        size: 12,
                        color: AppTheme.textLight,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        '${results.length} test${results.length > 1 ? 's' : ''}',
                        style: const TextStyle(
                          fontSize: AppTheme.fontXS,
                          color: AppTheme.textLight,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          // Detail rows
          if (details.isNotEmpty) ...[
            const SizedBox(height: AppTheme.spaceSM),
            const Divider(height: 1, color: AppTheme.textLight),
            const SizedBox(height: AppTheme.spaceSM),
            Wrap(
              spacing: AppTheme.spaceMD,
              runSpacing: 6,
              children: details
                  .map((d) => _buildDetailChip(d.label, d.value, d.highlight))
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDetailChip(String label, String value, bool highlight) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: highlight
            ? AppTheme.primary.withValues(alpha: 0.08)
            : AppTheme.background,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: highlight
              ? AppTheme.primary.withValues(alpha: 0.3)
              : AppTheme.textLight.withValues(alpha: 0.3),
        ),
      ),
      child: RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(
                fontSize: AppTheme.fontXS,
                color: AppTheme.textSecondary,
              ),
            ),
            TextSpan(
              text: value,
              style: TextStyle(
                fontSize: AppTheme.fontXS,
                fontWeight: FontWeight.w600,
                color: highlight ? AppTheme.primary : AppTheme.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<_DetailRow> _buildDetailRows(String label, Map<String, dynamic> r) {
    switch (label) {
      case 'Visual Acuity':
        return [
          if (r['snellen_value'] != null)
            _DetailRow('Snellen', r['snellen_value'].toString(), true),
          if (r['severity'] != null)
            _DetailRow('Severity', r['severity'].toString(), false),
          if (r['score'] != null) _DetailRow('Score', '${r['score']}%', false),
          if (r['correct_answers'] != null && r['total_questions'] != null)
            _DetailRow(
              'Correct',
              '${r['correct_answers']}/${r['total_questions']}',
              false,
            ),
        ];

      case 'Colour Vision':
        return [
          if (r['severity'] != null)
            _DetailRow('Result', r['severity'].toString(), true),
          if (r['correct_count'] != null && r['total_plates'] != null)
            _DetailRow(
              'Plates',
              '${r['correct_count']}/${r['total_plates']}',
              false,
            ),
          if (r['score'] != null) _DetailRow('Score', '${r['score']}%', false),
        ];

      case 'Blink Fatigue':
        return [
          if (r['classification'] != null || r['fatigue_level'] != null)
            _DetailRow(
              'Status',
              (r['classification'] ?? r['fatigue_level']).toString(),
              r['prediction'] == 'drowsy',
            ),
          if (r['avg_blinks_per_minute'] != null &&
              (r['avg_blinks_per_minute'] as num) > 0)
            _DetailRow(
              'Blink Rate',
              '${(r['avg_blinks_per_minute'] as num).toStringAsFixed(1)}/min',
              false,
            ),
          if (r['alertness_percentage'] != null)
            _DetailRow('Alertness', '${r['alertness_percentage']}%', false),
          if (r['total_blinks'] != null && (r['total_blinks'] as num) > 0)
            _DetailRow('Total Blinks', '${r['total_blinks']}', false),
        ];

      case 'Pupil Reflex':
        return [
          if (r['constriction_amplitude'] != null)
            _DetailRow(
              'Constriction',
              r['constriction_amplitude'].toString(),
              false,
            ),
          if (r['reaction_time'] != null)
            _DetailRow(
              'Reaction',
              '${((r['reaction_time'] as num) * 1000).round()} ms',
              false,
            ),
          if (r['symmetry'] != null)
            _DetailRow('Symmetry', r['symmetry'].toString(), false),
          if (r['nystagmus_detected'] == true)
            _DetailRow(
              'Nystagmus',
              r['nystagmus_severity']?.toString() ?? 'Detected',
              true,
            ),
        ];

      case 'Eye Tracking':
        return [
          if (r['performance_classification'] != null)
            _DetailRow(
              'Performance',
              r['performance_classification'].toString(),
              true,
            ),
          if (r['gaze_accuracy'] != null)
            _DetailRow(
              'Gaze Accuracy',
              '${(r['gaze_accuracy'] as num).toStringAsFixed(1)}%',
              false,
            ),
          if (r['overall_performance_score'] != null)
            _DetailRow(
              'Overall',
              '${(r['overall_performance_score'] as num).toStringAsFixed(1)}/100',
              false,
            ),
          if (r['fixation_stability_score'] != null)
            _DetailRow(
              'Fixation',
              '${(r['fixation_stability_score'] as num).toStringAsFixed(1)}/100',
              false,
            ),
        ];

      default:
        return [];
    }
  }

  String _extractTestResultText(String testLabel, Map<String, dynamic> result) {
    switch (testLabel) {
      case 'Visual Acuity':
        final snellen = result['snellen_value'];
        final severity = result['severity'];
        final score = result['score'];
        if (snellen != null && severity != null) {
          return 'Snellen: $snellen · $severity';
        }
        if (score != null) return 'Score: $score%';
        return 'Completed';

      case 'Colour Vision':
        final severity = result['severity'];
        final correct = result['correct_count'];
        final total = result['total_plates'];
        if (severity != null && correct != null && total != null) {
          return '$severity ($correct/$total plates correct)';
        }
        if (severity != null) return severity.toString();
        return 'Completed';

      case 'Blink Fatigue':
        final classification =
            result['classification'] ?? result['fatigue_level'];
        final bpm = result['avg_blinks_per_minute'];
        final alertness = result['alertness_percentage'];
        final parts = <String>[];
        if (classification != null) parts.add(classification.toString());
        final bpmNum = bpm as num?;
        if (bpmNum != null && bpmNum > 0) {
          parts.add('${bpmNum.toStringAsFixed(1)} blinks/min');
        }
        if (alertness != null) parts.add('$alertness% alert');
        return parts.isNotEmpty ? parts.join(' · ') : 'Completed';

      case 'Pupil Reflex':
        final amplitude = result['constriction_amplitude'];
        final reactionMs = result['reaction_time'] != null
            ? ((result['reaction_time'] as num) * 1000).round()
            : null;
        final nystagmus = result['nystagmus_detected'] == true
            ? (result['nystagmus_severity'] != null
                  ? '${result['nystagmus_severity']} nystagmus'
                  : 'Nystagmus detected')
            : null;
        final parts = <String>[];
        if (amplitude != null) parts.add('Constriction: $amplitude');
        if (reactionMs != null) parts.add('${reactionMs}ms reaction');
        if (nystagmus != null) parts.add(nystagmus);
        return parts.isNotEmpty ? parts.join(' · ') : 'Completed';

      case 'Eye Tracking':
        final perf = result['performance_classification'];
        final gaze = result['gaze_accuracy'];
        final overall = result['overall_performance_score'];
        if (perf != null && gaze != null) {
          return '$perf · Gaze: ${(gaze as num).toStringAsFixed(1)}%';
        }
        if (overall != null) {
          return 'Score: ${(overall as num).toStringAsFixed(1)}/100';
        }
        return 'Completed';

      default:
        return 'Completed';
    }
  }

  // ============================================
  // MEDICAL RECORDS TAB
  // ============================================
  Widget _buildMedicalRecordsTab() {
    return Column(
      children: [
        _buildRecordTypeSelector(),
        Expanded(
          child: _medicalRecords.isEmpty
              ? _buildEmptyState('No medical records', Icons.folder_open)
              : _buildMedicalRecordsList(),
        ),
      ],
    );
  }

  Widget _buildRecordTypeSelector() {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spaceMD),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () =>
                  _navigateToAddRecord(MedicalRecordType.scanReport),
              icon: const Icon(Icons.document_scanner, size: 18),
              label: const Text('Scan Report'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.testIconBackground,
                foregroundColor: AppTheme.primary,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          const SizedBox(width: AppTheme.spaceSM),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () =>
                  _navigateToAddRecord(MedicalRecordType.prescription),
              icon: const Icon(Icons.medication, size: 18),
              label: const Text('Prescription'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.testIconBackground,
                foregroundColor: AppTheme.primary,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          const SizedBox(width: AppTheme.spaceSM),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () =>
                  _navigateToAddRecord(MedicalRecordType.labReport),
              icon: const Icon(Icons.science, size: 18),
              label: const Text('Lab Report'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.testIconBackground,
                foregroundColor: AppTheme.primary,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _navigateToAddRecord(MedicalRecordType type) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            AddMedicalRecordPage(patientId: widget.patientId, recordType: type),
      ),
    ).then((_) => _loadData());
  }

  Widget _buildMedicalRecordsList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.spaceMD),
      itemCount: _medicalRecords.length,
      itemBuilder: (context, index) {
        return _buildMedicalRecordCard(_medicalRecords[index]);
      },
    );
  }

  Widget _buildMedicalRecordCard(MedicalRecord record) {
    IconData icon;
    Color iconColor;

    switch (record.type) {
      case MedicalRecordType.scanReport:
        icon = Icons.document_scanner;
        iconColor = AppTheme.info;
        break;
      case MedicalRecordType.prescription:
        icon = Icons.medication;
        iconColor = AppTheme.success;
        break;
      case MedicalRecordType.labReport:
        icon = Icons.science;
        iconColor = AppTheme.warning;
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.spaceSM),
      padding: const EdgeInsets.all(AppTheme.spaceMD),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: AppTheme.spaceMD),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  record.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  record.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: AppTheme.fontSM,
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${record.formattedDate} • ${record.doctorName ?? 'Unknown'}',
                  style: const TextStyle(
                    fontSize: AppTheme.fontXS,
                    color: AppTheme.textLight,
                  ),
                ),
              ],
            ),
          ),
          if (record.fileName != null)
            IconButton(
              icon: const Icon(Icons.download, color: AppTheme.primary),
              onPressed: () {
                // Download file
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Downloading file...')),
                );
              },
            ),
        ],
      ),
    );
  }

  // ============================================
  // CLINICAL NOTES TAB
  // ============================================
  Widget _buildClinicalNotesTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(AppTheme.spaceMD),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        AddClinicalNotePage(patientId: widget.patientId),
                  ),
                ).then((_) => _loadData());
              },
              icon: const Icon(Icons.add),
              label: const Text('Add Clinical Note'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                ),
              ),
            ),
          ),
        ),
        Expanded(
          child: _clinicalNotes.isEmpty
              ? _buildEmptyState('No clinical notes', Icons.note_alt_outlined)
              : _buildClinicalNotesList(),
        ),
      ],
    );
  }

  Widget _buildClinicalNotesList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.spaceMD),
      itemCount: _clinicalNotes.length,
      itemBuilder: (context, index) {
        return _buildClinicalNoteCard(_clinicalNotes[index]);
      },
    );
  }

  Widget _buildClinicalNoteCard(ClinicalNote note) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.spaceSM),
      padding: const EdgeInsets.all(AppTheme.spaceMD),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spaceSM,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.testIconBackground,
                  borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                ),
                child: Text(
                  note.category.toString(),
                  style: const TextStyle(
                    fontSize: AppTheme.fontXS,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primary,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                note.formattedDate,
                style: const TextStyle(
                  fontSize: AppTheme.fontSM,
                  color: AppTheme.textLight,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spaceSM),
          Text(
            note.title,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: AppTheme.fontBody,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            note.content,
            style: const TextStyle(
              fontSize: AppTheme.fontSM,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: AppTheme.spaceSM),
          Text(
            'By ${note.doctorName}',
            style: const TextStyle(
              fontSize: AppTheme.fontXS,
              color: AppTheme.textLight,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String message, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 64,
            color: AppTheme.textLight.withValues(alpha: 0.5),
          ),
          const SizedBox(height: AppTheme.spaceMD),
          Text(
            message,
            style: const TextStyle(
              fontSize: AppTheme.fontLG,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

// Helper data class for test detail chips
class _DetailRow {
  final String label;
  final String value;
  final bool highlight;
  const _DetailRow(this.label, this.value, this.highlight);
}
