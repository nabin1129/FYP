import 'package:flutter/material.dart';
import '../../config/app_theme.dart';
import '../../models/admin/admin_user_model.dart';
import '../../services/admin_service.dart';

/// Admin Users Page — Page 2: Monitor and manage users/patients
class AdminUsersPage extends StatefulWidget {
  const AdminUsersPage({super.key});

  @override
  State<AdminUsersPage> createState() => _AdminUsersPageState();
}

class _AdminUsersPageState extends State<AdminUsersPage> {
  final AdminService _service = AdminService();
  final _searchCtrl = TextEditingController();
  final String _filter = 'all';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (!_service.isLoaded) _loadData();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    await _service.loadAll();
    if (mounted) setState(() => _isLoading = false);
  }

  List<AdminUser> get _filtered =>
      _service.searchUsers(_searchCtrl.text, filter: _filter);

  void _refresh() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: _buildAppBar(),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primary),
            )
          : Column(
              children: [
                _buildStatsBar(),
                _buildSearchBar(),
                Expanded(
                  child: filtered.isEmpty
                      ? _buildEmpty()
                      : RefreshIndicator(
                          onRefresh: _loadData,
                          color: AppTheme.primary,
                          child: ListView.builder(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppTheme.spaceMD,
                              vertical: AppTheme.spaceSM,
                            ),
                            itemCount: filtered.length,
                            itemBuilder: (_, i) => _buildUserRow(filtered[i]),
                          ),
                        ),
                ),
              ],
            ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: AppTheme.surface,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(
          Icons.arrow_back_ios_new,
          size: 20,
          color: AppTheme.primary,
        ),
        onPressed: () => Navigator.pop(context),
      ),
      title: const Text(
        'User Management',
        style: TextStyle(
          color: AppTheme.textPrimary,
          fontSize: AppTheme.fontXL,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildStatsBar() {
    final users = _service.users;

    return Container(
      margin: const EdgeInsets.all(AppTheme.spaceMD),
      padding: const EdgeInsets.all(AppTheme.spaceMD),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.categoryBlueBg, AppTheme.indigoTint],
        ),
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        border: Border.all(color: AppTheme.infoTint),
      ),
      child: Row(
        children: [
          _miniStat('Total', '${users.length}', AppTheme.categoryBlue),
        ],
      ),
    );
  }

  Widget _miniStat(String label, String value, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: AppTheme.fontXL,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              fontSize: AppTheme.fontXS,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.spaceMD,
        0,
        AppTheme.spaceMD,
        AppTheme.spaceSM,
      ),
      child: Container(
        height: 42,
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          boxShadow: AppTheme.cardShadow,
        ),
        child: TextField(
          controller: _searchCtrl,
          onChanged: (_) => _refresh(),
          style: const TextStyle(fontSize: AppTheme.fontSM),
          decoration: const InputDecoration(
            hintText: 'Search by name or email...',
            hintStyle: TextStyle(
              fontSize: AppTheme.fontSM,
              color: AppTheme.textLight,
            ),
            prefixIcon: Icon(Icons.search, size: 18, color: AppTheme.textLight),
            border: InputBorder.none,
            contentPadding: EdgeInsets.symmetric(vertical: 12),
          ),
        ),
      ),
    );
  }

  Widget _buildUserRow(AdminUser user) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.spaceSM),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        children: [
          // Header row
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.spaceMD,
              vertical: 10,
            ),
            decoration: const BoxDecoration(
              color: AppTheme.categoryBlueBg,
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(AppTheme.radiusMedium),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppTheme.infoTint, AppTheme.indigoTint],
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Center(
                    child: Text(
                      user.initials,
                      style: const TextStyle(
                        fontSize: AppTheme.fontSM,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppTheme.spaceSM),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.name,
                        style: const TextStyle(
                          fontSize: AppTheme.fontBody,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      Text(
                        user.email,
                        style: const TextStyle(
                          fontSize: AppTheme.fontXS,
                          color: AppTheme.textSecondary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Details grid
          Padding(
            padding: const EdgeInsets.all(AppTheme.spaceMD),
            child: Column(
              children: [
                Row(
                  children: [
                    _infoCell(
                      Icons.phone_outlined,
                      'Phone',
                      user.phone.isNotEmpty ? user.phone : 'N/A',
                    ),
                    _infoCell(
                      Icons.person_outline,
                      'Age / Sex',
                      '${user.age ?? 'N/A'} • ${user.sex.isNotEmpty ? user.sex : 'N/A'}',
                    ),
                    _infoCell(
                      Icons.location_on_outlined,
                      'Address',
                      user.address.isNotEmpty ? user.address : 'N/A',
                    ),
                  ],
                ),
                const SizedBox(height: AppTheme.spaceSM),
                Row(
                  children: [
                    _infoCell(
                      Icons.calendar_today_outlined,
                      'Joined',
                      user.joinDate,
                    ),
                  ],
                ),

                // Actions row
                const SizedBox(height: AppTheme.spaceSM),
                Row(
                  children: [
                    Text(
                      'ID: ${user.id}',
                      style: const TextStyle(
                        fontSize: AppTheme.fontXS,
                        color: AppTheme.textLight,
                        fontFamily: 'monospace',
                      ),
                    ),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: () => _showUserDetail(user),
                      icon: const Icon(Icons.visibility_outlined, size: 14),
                      label: const Text(
                        'Details',
                        style: TextStyle(fontSize: AppTheme.fontSM),
                      ),
                      style: TextButton.styleFrom(
                        foregroundColor: AppTheme.categoryBlue,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                    const SizedBox(width: 4),
                    TextButton.icon(
                      onPressed: () => _showEditUser(user),
                      icon: const Icon(Icons.edit_outlined, size: 14),
                      label: const Text(
                        'Edit',
                        style: TextStyle(fontSize: AppTheme.fontSM),
                      ),
                      style: TextButton.styleFrom(
                        foregroundColor: AppTheme.success,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                    const SizedBox(width: 4),
                    TextButton.icon(
                      onPressed: () => _confirmDeleteUser(user),
                      icon: const Icon(Icons.delete_outline, size: 14),
                      label: const Text(
                        'Remove',
                        style: TextStyle(fontSize: AppTheme.fontSM),
                      ),
                      style: TextButton.styleFrom(
                        foregroundColor: AppTheme.error,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoCell(IconData icon, String label, String value) {
    return Expanded(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 13, color: AppTheme.textLight),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: AppTheme.fontXS,
                    color: AppTheme.textLight,
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: AppTheme.fontXS,
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline, size: 64, color: AppTheme.textLight),
          const SizedBox(height: AppTheme.spaceSM),
          const Text(
            'No users found',
            style: TextStyle(color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }

  Future<void> _showUserDetail(AdminUser user) async {
    try {
      final detailedUser = await _service.getUserDetail(user.backendId);
      if (!mounted) return;

      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => _UserDetailSheet(user: detailedUser),
      );
    } catch (e) {
      if (!mounted) return;
      _showSnack('Failed to load detailed results: $e');
    }
  }

  void _showEditUser(AdminUser user) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _UserEditSheet(
        user: user,
        service: _service,
        onSaved: () {
          _refresh();
          _showSnack('${user.name} updated');
        },
      ),
    );
  }

  void _confirmDeleteUser(AdminUser user) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        ),
        title: const Text('Remove User?'),
        content: Text(
          'Remove ${user.name} from the system? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            onPressed: () async {
              Navigator.pop(context);
              try {
                await _service.deleteUser(user.backendId);
                _refresh();
                _showSnack('${user.name} removed');
              } catch (e) {
                _showSnack('Failed: $e');
              }
            },
            child: const Text('Remove', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}

// ============================================================
// USER DETAIL SHEET
// ============================================================
class _UserDetailSheet extends StatelessWidget {
  final AdminUser user;
  const _UserDetailSheet({required this.user});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppTheme.radiusXL),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppTheme.textLight,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppTheme.spaceLG),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        'User Details',
                        style: TextStyle(
                          fontSize: AppTheme.fontXL,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.arrow_back, size: 16),
                        label: const Text('Back'),
                        style: TextButton.styleFrom(
                          foregroundColor: AppTheme.primary,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppTheme.spaceMD),
                  // Avatar + name
                  Row(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [AppTheme.infoTint, AppTheme.indigoTint],
                          ),
                          borderRadius: BorderRadius.circular(28),
                        ),
                        child: Center(
                          child: Text(
                            user.initials,
                            style: const TextStyle(
                              fontSize: AppTheme.fontXL,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primary,
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
                              user.name,
                              style: const TextStyle(
                                fontSize: AppTheme.fontXL,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            Text(
                              user.email,
                              style: const TextStyle(
                                fontSize: AppTheme.fontSM,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppTheme.spaceLG),
                  _detailGrid(context),
                  const SizedBox(height: AppTheme.spaceMD),
                  _testSummarySection(context),
                  const SizedBox(height: AppTheme.spaceMD),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _testSummarySection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Test Details',
          style: TextStyle(
            fontSize: AppTheme.fontLG,
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: AppTheme.spaceSM),
        Wrap(
          spacing: AppTheme.spaceSM,
          runSpacing: AppTheme.spaceSM,
          children: [
            _summaryChip(
              'Total Tests',
              '${user.totalTests}',
              Icons.analytics_outlined,
            ),
            _summaryChip(
              'Eye Tracking',
              '${user.eyeTrackingCount}',
              Icons.my_location_outlined,
            ),
            _summaryChip(
              'Visual Acuity',
              '${user.visualAcuityCount}',
              Icons.visibility_outlined,
            ),
            _summaryChip(
              'Colour Vision',
              '${user.colourVisionCount}',
              Icons.palette_outlined,
            ),
            _summaryChip(
              'Blink Fatigue',
              '${user.blinkFatigueCount}',
              Icons.remove_red_eye_outlined,
            ),
            _summaryChip(
              'Pupil Reflex',
              '${user.pupilReflexCount}',
              Icons.light_mode_outlined,
            ),
          ],
        ),
        const SizedBox(height: AppTheme.spaceSM),
        if (user.lastTestDate.isNotEmpty)
          Text(
            'Last test: ${user.lastTestDate}',
            style: const TextStyle(
              fontSize: AppTheme.fontSM,
              color: AppTheme.textSecondary,
            ),
          ),
        const SizedBox(height: AppTheme.spaceSM),
        _recentTestsCard(),
        const SizedBox(height: AppTheme.spaceMD),
        _allTestsSection(),
      ],
    );
  }

  Widget _summaryChip(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppTheme.textSecondary),
          const SizedBox(width: 6),
          Text(
            '$label: $value',
            style: const TextStyle(
              fontSize: AppTheme.fontXS,
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _allTestsSection() {
    final history = user.testHistory;
    final eye = history['eye_tracking'] ?? const [];
    final visual = history['visual_acuity'] ?? const [];
    final colour = history['colour_vision'] ?? const [];
    final blink = history['blink_fatigue'] ?? const [];
    final pupil = history['pupil_reflex'] ?? const [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'All Tests by Type',
          style: TextStyle(
            fontSize: AppTheme.fontLG,
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: AppTheme.spaceSM),
        _historyTypeSection('Eye Tracking', eye, Icons.my_location_outlined, (
          test,
        ) {
          return 'Date: ${_strText(test['created_at'])} | Accuracy: ${_numText(test['gaze_accuracy'], suffix: '%')} | Class: ${_strText(test['performance_classification'] ?? test['classification'])}';
        }),
        _historyTypeSection('Visual Acuity', visual, Icons.visibility_outlined, (
          test,
        ) {
          return 'Date: ${_strText(test['created_at'])} | Score: ${_strText(test['correct_answers'] ?? test['correct'])}/${_strText(test['total_questions'] ?? test['total'])} | Snellen: ${_strText(test['snellen_value'] ?? test['snellen'])}';
        }),
        _historyTypeSection('Colour Vision', colour, Icons.palette_outlined, (
          test,
        ) {
          return 'Date: ${_strText(test['created_at'])} | Correct: ${_strText(test['correct_count'])}/${_strText(test['total_plates'])} | Severity: ${_strText(test['severity'])}';
        }),
        _historyTypeSection(
          'Blink Fatigue',
          blink,
          Icons.remove_red_eye_outlined,
          (test) {
            return 'Date: ${_strText(test['created_at'])} | Level: ${_strText(test['fatigue_level'])} | Alertness: ${_numText(test['alertness_percentage'], suffix: '%')} | Blinks: ${_strText(test['total_blinks'])}';
          },
        ),
        _historyTypeSection('Pupil Reflex', pupil, Icons.light_mode_outlined, (
          test,
        ) {
          return 'Date: ${_strText(test['created_at'])} | Reaction: ${_numText(test['reaction_time'], suffix: 's')} | Symmetry: ${_strText(test['symmetry'])} | Nystagmus: ${_strText(test['nystagmus_severity'])}';
        }),
      ],
    );
  }

  Widget _historyTypeSection(
    String title,
    List<Map<String, dynamic>> tests,
    IconData icon,
    String Function(Map<String, dynamic>) mapper,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.spaceSM),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
        border: Border.all(color: AppTheme.border),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
        childrenPadding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
        leading: Icon(icon, size: 18, color: AppTheme.primary),
        title: Text(
          title,
          style: const TextStyle(
            fontSize: AppTheme.fontSM,
            fontWeight: FontWeight.w700,
          ),
        ),
        subtitle: Text(
          '${tests.length} test${tests.length == 1 ? '' : 's'}',
          style: const TextStyle(
            fontSize: AppTheme.fontXS,
            color: AppTheme.textSecondary,
          ),
        ),
        children: tests.isEmpty
            ? [
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: EdgeInsets.only(top: 2, bottom: 6),
                    child: Text(
                      'No records available',
                      style: TextStyle(
                        fontSize: AppTheme.fontXS,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ),
                ),
              ]
            : tests
                  .asMap()
                  .entries
                  .map(
                    (entry) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.background,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '#${entry.key + 1}  ${mapper(entry.value)}',
                          style: const TextStyle(
                            fontSize: AppTheme.fontXS,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      ),
                    ),
                  )
                  .toList(),
      ),
    );
  }

  Widget _recentTestsCard() {
    final eye =
        user.recentTests['eye_tracking'] as Map<String, dynamic>? ?? const {};
    final visual =
        user.recentTests['visual_acuity'] as Map<String, dynamic>? ?? const {};
    final colour =
        user.recentTests['colour_vision'] as Map<String, dynamic>? ?? const {};
    final blink =
        user.recentTests['blink_fatigue'] as Map<String, dynamic>? ?? const {};
    final pupil =
        user.recentTests['pupil_reflex'] as Map<String, dynamic>? ?? const {};

    final eyeScore = _toDouble(eye['gaze_accuracy']);
    final visualScore = _toDouble(visual['score']);
    final colourScore = _toDouble(colour['score']);
    final blinkScore = _toDouble(blink['alertness_percentage']);
    final pupilReaction = _toDouble(pupil['reaction_time']);
    final pupilScore = pupilReaction == null
        ? null
        : ((0.6 - pupilReaction).clamp(0.0, 0.6) / 0.6) * 100;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppTheme.spaceMD),
      decoration: BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _resultCard(
            title: 'Eye Tracking',
            lines: [
              'Accuracy: ${_numText(eye['gaze_accuracy'], suffix: '%')}',
              'Classification: ${_strText(eye['classification'])}',
              'Duration: ${_numText(eye['duration'], suffix: 's')}',
              'Fixation: ${_numText(eye['fixation_stability'])}',
              'Saccade: ${_numText(eye['saccade_consistency'])}',
            ],
            icon: Icons.my_location_outlined,
            accent: AppTheme.success,
            score: eyeScore,
            scoreLabel: 'Accuracy',
          ),
          const SizedBox(height: 8),
          _resultCard(
            title: 'Visual Acuity',
            lines: [
              'Score: ${_strText('${_strText(visual['correct'])}/${_strText(visual['total'])}')}',
              'Percent: ${_numText(visual['score'], suffix: '%')}',
              'Snellen: ${_strText(visual['snellen'])}',
              'Severity: ${_strText(visual['severity'])}',
            ],
            icon: Icons.visibility_outlined,
            accent: AppTheme.categoryBlue,
            score: visualScore,
            scoreLabel: 'Score',
          ),
          const SizedBox(height: 8),
          _resultCard(
            title: 'Colour Vision',
            lines: [
              'Correct: ${_strText(colour['correct_count'])}/${_strText(colour['total_plates'])}',
              'Score: ${_numText(colour['score'], suffix: '%')}',
              'Severity: ${_strText(colour['severity'])}',
            ],
            icon: Icons.palette_outlined,
            accent: AppTheme.categoryPurple,
            score: colourScore,
            scoreLabel: 'Score',
          ),
          const SizedBox(height: 8),
          _resultCard(
            title: 'Blink Fatigue',
            lines: [
              'Classification: ${_strText(blink['fatigue_level'])}',
              'Alertness: ${_numText(blink['alertness_percentage'], suffix: '%')}',
              'Avg BPM: ${_numText(blink['avg_blinks_per_minute'])}',
              'Total Blinks: ${_strText(blink['total_blinks'])}',
              'Duration: ${_numText(blink['duration'], suffix: 's')}',
            ],
            icon: Icons.remove_red_eye_outlined,
            accent: AppTheme.categoryOrange,
            score: blinkScore,
            scoreLabel: 'Alertness',
          ),
          const SizedBox(height: 8),
          _resultCard(
            title: 'Pupil Reflex',
            lines: [
              'Reaction Time: ${_numText(pupil['reaction_time'], suffix: 's')}',
              'Amplitude: ${_strText(pupil['constriction_amplitude'])}',
              'Symmetry: ${_strText(pupil['symmetry'])}',
              'Nystagmus: ${_strText(pupil['nystagmus_detected'])}',
              'Severity: ${_strText(pupil['nystagmus_severity'])}',
            ],
            icon: Icons.light_mode_outlined,
            accent: AppTheme.categoryIndigo,
            score: pupilScore,
            scoreLabel: 'Reflex Index',
          ),
        ],
      ),
    );
  }

  Widget _resultCard({
    required String title,
    required List<String> lines,
    required IconData icon,
    required Color accent,
    String scoreLabel = 'Score',
    double? score,
  }) {
    final normalized = score == null ? null : (score.clamp(0.0, 100.0) / 100);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 16, color: accent),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: AppTheme.fontSM,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
              if (score != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${score.round()}%',
                    style: TextStyle(
                      fontSize: AppTheme.fontXS,
                      fontWeight: FontWeight.bold,
                      color: accent,
                    ),
                  ),
                ),
            ],
          ),
          if (normalized != null) ...[
            const SizedBox(height: 8),
            Text(
              scoreLabel,
              style: const TextStyle(
                fontSize: AppTheme.fontXS,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                minHeight: 7,
                value: normalized,
                backgroundColor: accent.withValues(alpha: 0.14),
                valueColor: AlwaysStoppedAnimation<Color>(accent),
              ),
            ),
          ],
          const SizedBox(height: 6),
          ...lines.map(
            (line) => Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text(
                line,
                style: const TextStyle(
                  fontSize: AppTheme.fontXS,
                  color: AppTheme.textSecondary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _strText(dynamic value) {
    if (value == null) {
      return 'N/A';
    }
    final text = value.toString().trim();
    return text.isEmpty ? 'N/A' : text;
  }

  String _numText(dynamic value, {String suffix = ''}) {
    if (value is num) {
      final hasFraction = value != value.roundToDouble();
      return '${hasFraction ? value.toStringAsFixed(1) : value.toStringAsFixed(0)}$suffix';
    }
    return _strText(value);
  }

  double? _toDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }
    if (value is String) {
      return double.tryParse(value);
    }
    return null;
  }

  Widget _detailGrid(BuildContext context) {
    final items = [
      [Icons.badge_outlined, 'User ID', user.id],
      [
        Icons.phone_outlined,
        'Phone',
        user.phone.isNotEmpty ? user.phone : 'N/A',
      ],
      [
        Icons.person_outline,
        'Age',
        user.age != null ? '${user.age} years' : 'N/A',
      ],
      [Icons.wc_outlined, 'Sex', user.sex.isNotEmpty ? user.sex : 'N/A'],
      [
        Icons.location_on_outlined,
        'Address',
        user.address.isNotEmpty ? user.address : 'N/A',
      ],
      [Icons.calendar_today_outlined, 'Joined', user.joinDate],
    ];

    return Wrap(
      spacing: AppTheme.spaceSM,
      runSpacing: AppTheme.spaceSM,
      children: items.map((item) {
        return SizedBox(
          width:
              (MediaQuery.of(context).size.width -
                  AppTheme.spaceLG * 2 -
                  AppTheme.spaceSM) /
              2,
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.background,
              borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(item[0] as IconData, size: 14, color: AppTheme.textLight),
                const SizedBox(width: 6),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item[1] as String,
                        style: const TextStyle(
                          fontSize: AppTheme.fontXS,
                          color: AppTheme.textLight,
                        ),
                      ),
                      Text(
                        item[2] as String,
                        style: const TextStyle(
                          fontSize: AppTheme.fontSM,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 2,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ============================================================
// USER EDIT SHEET
// ============================================================
class _UserEditSheet extends StatefulWidget {
  final AdminUser user;
  final AdminService service;
  final VoidCallback onSaved;

  const _UserEditSheet({
    required this.user,
    required this.service,
    required this.onSaved,
  });

  @override
  State<_UserEditSheet> createState() => _UserEditSheetState();
}

class _UserEditSheetState extends State<_UserEditSheet> {
  final _formKey = GlobalKey<FormState>();
  bool _saving = false;

  late final TextEditingController _nameCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _ageCtrl;
  late final TextEditingController _addressCtrl;
  late String _sex;

  @override
  void initState() {
    super.initState();
    final u = widget.user;
    _nameCtrl = TextEditingController(text: u.name);
    _emailCtrl = TextEditingController(text: u.email);
    _phoneCtrl = TextEditingController(text: u.phone);
    _ageCtrl = TextEditingController(text: u.age?.toString() ?? '');
    _addressCtrl = TextEditingController(text: u.address);
    _sex = u.sex.isNotEmpty ? u.sex : 'Male';
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _ageCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final fields = <String, dynamic>{
        'name': _nameCtrl.text.trim(),
        'email': _emailCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
        'age': int.tryParse(_ageCtrl.text.trim()),
        'sex': _sex,
        'address': _addressCtrl.text.trim(),
      };
      await widget.service.updateUser(widget.user.backendId, fields);
      if (!mounted) return;
      Navigator.pop(context);
      widget.onSaved();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$e'),
          backgroundColor: AppTheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppTheme.radiusXL),
        ),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppTheme.textLight,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppTheme.spaceLG,
              AppTheme.spaceMD,
              AppTheme.spaceLG,
              0,
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.categoryBlueBg,
                    borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                  ),
                  child: const Icon(
                    Icons.edit_outlined,
                    color: AppTheme.categoryBlue,
                    size: 20,
                  ),
                ),
                const SizedBox(width: AppTheme.spaceSM),
                const Expanded(
                  child: Text(
                    'Edit User',
                    style: TextStyle(
                      fontSize: AppTheme.fontXL,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.close,
                    size: 22,
                    color: AppTheme.textSecondary,
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppTheme.spaceLG),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _field(
                      _nameCtrl,
                      'Full Name *',
                      Icons.person_outline,
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Name required'
                          : null,
                    ),
                    const SizedBox(height: AppTheme.spaceSM),
                    _field(
                      _emailCtrl,
                      'Email *',
                      Icons.email_outlined,
                      keyboardType: TextInputType.emailAddress,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty)
                          return 'Email required';
                        if (!v.contains('@')) return 'Invalid email';
                        return null;
                      },
                    ),
                    const SizedBox(height: AppTheme.spaceSM),
                    _field(
                      _phoneCtrl,
                      'Phone',
                      Icons.phone_outlined,
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: AppTheme.spaceSM),
                    _field(
                      _ageCtrl,
                      'Age',
                      Icons.cake_outlined,
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: AppTheme.spaceSM),
                    // Sex dropdown
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.background,
                        borderRadius: BorderRadius.circular(
                          AppTheme.radiusSmall,
                        ),
                        border: Border.all(color: AppTheme.border),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.wc_outlined,
                            size: 16,
                            color: AppTheme.textSecondary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: _sex,
                                isExpanded: true,
                                style: const TextStyle(
                                  fontSize: AppTheme.fontBody,
                                  color: AppTheme.textPrimary,
                                ),
                                items: ['Male', 'Female', 'Other']
                                    .map(
                                      (s) => DropdownMenuItem(
                                        value: s,
                                        child: Text(s),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (v) => setState(() => _sex = v!),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppTheme.spaceSM),
                    _field(_addressCtrl, 'Address', Icons.location_on_outlined),
                    const SizedBox(height: AppTheme.spaceLG),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              AppTheme.radiusMedium,
                            ),
                          ),
                        ),
                        onPressed: _saving ? null : _submit,
                        child: _saving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text(
                                'Save Changes',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: AppTheme.fontBody,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: AppTheme.spaceSM),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _field(
    TextEditingController ctrl,
    String label,
    IconData icon, {
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: ctrl,
      keyboardType: keyboardType,
      validator: validator,
      style: const TextStyle(fontSize: AppTheme.fontBody),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 18, color: AppTheme.textSecondary),
        filled: true,
        fillColor: AppTheme.background,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
          borderSide: const BorderSide(color: AppTheme.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
          borderSide: const BorderSide(color: AppTheme.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
          borderSide: const BorderSide(color: AppTheme.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
          borderSide: const BorderSide(color: AppTheme.error),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
        isDense: true,
      ),
    );
  }
}
