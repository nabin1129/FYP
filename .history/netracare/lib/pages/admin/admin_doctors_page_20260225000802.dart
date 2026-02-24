import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../config/app_theme.dart';
import '../../models/admin/admin_doctor_model.dart';
import '../../services/admin_service.dart';

/// Admin Doctors Page — Page 3: Full CRUD for doctors
/// Admin manually provides doctor ID and password
class AdminDoctorsPage extends StatefulWidget {
  const AdminDoctorsPage({super.key});

  @override
  State<AdminDoctorsPage> createState() => _AdminDoctorsPageState();
}

class _AdminDoctorsPageState extends State<AdminDoctorsPage> {
  final AdminService _service = AdminService();
  final _searchCtrl = TextEditingController();
  String _filter = 'all';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<AdminDoctor> get _filtered =>
      _service.searchDoctors(_searchCtrl.text, filter: _filter);

  void _refresh() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: _buildAppBar(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(context),
        backgroundColor: const Color(0xFF10B981),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Add Doctor',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
      ),
      body: Column(
        children: [
          _buildStatsBar(),
          _buildSearchBar(),
          Expanded(
            child: filtered.isEmpty
                ? _buildEmpty()
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(
                        AppTheme.spaceMD, AppTheme.spaceSM, AppTheme.spaceMD, 80),
                    itemCount: filtered.length,
                    itemBuilder: (_, i) => _buildDoctorRow(filtered[i]),
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
        icon: const Icon(Icons.arrow_back_ios_new, size: 20, color: AppTheme.primary),
        onPressed: () => Navigator.pop(context),
      ),
      title: const Text(
        'Doctor Management',
        style: TextStyle(
          color: AppTheme.textPrimary,
          fontSize: 17,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildStatsBar() {
    final docs = _service.doctors;
    final avg = _service.avgRating.toStringAsFixed(1);
    final totalTests = _service.totalTestsThisMonth;
    final totalPatients = _service.totalPatients;

    return Container(
      margin: const EdgeInsets.all(AppTheme.spaceMD),
      padding: const EdgeInsets.all(AppTheme.spaceMD),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFECFDF5), Color(0xFFEFF6FF)],
        ),
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        border: Border.all(color: const Color(0xFFD1FAE5)),
      ),
      child: Row(
        children: [
          _miniStat('Doctors', '${docs.length}', const Color(0xFF10B981)),
          _divider(),
          _miniStat('Patients', '$totalPatients', const Color(0xFF3B82F6)),
          _divider(),
          _miniStat('Tests/Mo', '$totalTests', AppTheme.primary),
          _divider(),
          _miniStat('Avg ★', avg, const Color(0xFFF59E0B)),
        ],
      ),
    );
  }

  Widget _miniStat(String label, String value, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(value,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
          Text(label,
              style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
        ],
      ),
    );
  }

  Widget _divider() {
    return Container(height: 32, width: 1, color: const Color(0xFFD1FAE5));
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppTheme.spaceMD, 0, AppTheme.spaceMD, AppTheme.spaceSM),
      child: Row(
        children: [
          Expanded(
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
                style: const TextStyle(fontSize: 13),
                decoration: const InputDecoration(
                  hintText: 'Search by name, email or ID...',
                  hintStyle: TextStyle(fontSize: 12, color: AppTheme.textLight),
                  prefixIcon: Icon(Icons.search, size: 18, color: AppTheme.textLight),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ),
          const SizedBox(width: AppTheme.spaceSM),
          Container(
            height: 42,
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
              boxShadow: AppTheme.cardShadow,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _filter,
                style: const TextStyle(fontSize: 12, color: AppTheme.textPrimary),
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('All')),
                  DropdownMenuItem(value: 'active', child: Text('Active')),
                  DropdownMenuItem(value: 'inactive', child: Text('Inactive')),
                ],
                onChanged: (v) => setState(() => _filter = v!),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDoctorRow(AdminDoctor doc) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.spaceSM),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.spaceMD, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFECFDF5),
              borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(AppTheme.radiusMedium)),
            ),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFD1FAE5), Color(0xFFDBEAFE)],
                    ),
                    borderRadius: BorderRadius.circular(21),
                  ),
                  child: Center(
                    child: Text(
                      doc.initials,
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF059669)),
                    ),
                  ),
                ),
                const SizedBox(width: AppTheme.spaceSM),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(doc.name,
                          style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimary)),
                      Text(doc.specialization,
                          style: const TextStyle(
                              fontSize: 11, color: Color(0xFF059669))),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    _service.toggleDoctorStatus(doc.id);
                    _refresh();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: doc.isActive
                          ? const Color(0xFFECFDF5)
                          : const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: doc.isActive
                            ? AppTheme.success.withOpacity(0.4)
                            : AppTheme.textLight.withOpacity(0.4),
                      ),
                    ),
                    child: Text(
                      doc.status,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color:
                            doc.isActive ? AppTheme.success : AppTheme.textSecondary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Details
          Padding(
            padding: const EdgeInsets.all(AppTheme.spaceMD),
            child: Column(
              children: [
                Row(
                  children: [
                    _infoCell(Icons.badge_outlined, 'ID', doc.id),
                    _infoCell(Icons.email_outlined, 'Email', doc.email),
                    _infoCell(Icons.phone_outlined, 'Phone', doc.phone),
                  ],
                ),
                const SizedBox(height: AppTheme.spaceSM),
                Row(
                  children: [
                    _infoCell(Icons.local_hospital_outlined, 'NHPC', doc.nhpcNumber),
                    _infoCell(Icons.work_history_outlined, 'Experience',
                        '${doc.experienceYears} yrs'),
                    _infoCell(Icons.star_outline, 'Rating',
                        '${doc.rating} / 5.0'),
                  ],
                ),
                const SizedBox(height: AppTheme.spaceSM),
                Row(
                  children: [
                    _infoCell(Icons.business_outlined, 'Working At', doc.workingPlace),
                    _infoCell(Icons.location_on_outlined, 'Address', doc.address),
                    _infoCell(Icons.groups_outlined, 'Patients', '${doc.patients}'),
                  ],
                ),
                // Credential chip
                const SizedBox(height: AppTheme.spaceSM),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                    border: Border.all(color: const Color(0xFFFDE68A)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.key_outlined, size: 14, color: Color(0xFFF59E0B)),
                      const SizedBox(width: 6),
                      const Text('Password: ',
                          style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                      Text(
                        doc.password,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                          fontFamily: 'monospace',
                        ),
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: () {
                          Clipboard.setData(ClipboardData(text: doc.password));
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                            content: Text('Password copied'),
                            behavior: SnackBarBehavior.floating,
                            duration: Duration(seconds: 1),
                          ));
                        },
                        child: const Icon(Icons.copy, size: 14, color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                ),

                // Actions
                const SizedBox(height: AppTheme.spaceSM),
                Row(
                  children: [
                    Text(
                      'Joined: ${doc.joinDate}',
                      style: const TextStyle(fontSize: 10, color: AppTheme.textLight),
                    ),
                    const Spacer(),
                    _actionBtn(
                      icon: Icons.visibility_outlined,
                      label: 'View',
                      color: const Color(0xFF3B82F6),
                      onTap: () => _showDoctorDetail(doc),
                    ),
                    const SizedBox(width: 4),
                    _actionBtn(
                      icon: Icons.edit_outlined,
                      label: 'Edit',
                      color: const Color(0xFF10B981),
                      onTap: () => _openForm(context, doctor: doc),
                    ),
                    const SizedBox(width: 4),
                    _actionBtn(
                      icon: Icons.delete_outline,
                      label: 'Delete',
                      color: AppTheme.error,
                      onTap: () => _confirmDelete(doc),
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
                Text(label,
                    style: const TextStyle(fontSize: 10, color: AppTheme.textLight)),
                Text(value,
                    style: const TextStyle(
                        fontSize: 11,
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w500),
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionBtn({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return TextButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 14),
      label: Text(label, style: const TextStyle(fontSize: 11)),
      style: TextButton.styleFrom(
        foregroundColor: color,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.local_hospital_outlined, size: 64, color: AppTheme.textLight),
          const SizedBox(height: AppTheme.spaceSM),
          const Text('No doctors found',
              style: TextStyle(color: AppTheme.textSecondary)),
          const SizedBox(height: AppTheme.spaceMD),
          ElevatedButton.icon(
            onPressed: () => _openForm(context),
            icon: const Icon(Icons.add),
            label: const Text('Add First Doctor'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  void _openForm(BuildContext context, {AdminDoctor? doctor}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _DoctorFormSheet(
        doctor: doctor,
        service: _service,
        onSaved: (saved) {
          _refresh();
          if (doctor == null) {
            // New doctor added — navigate back to dashboard
            Navigator.pop(context, 'added');
          }
        },
      ),
    );
  }

  void _showDoctorDetail(AdminDoctor doc) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _DoctorDetailSheet(
        doctor: doc,
        onShowCredentials: () {
          Navigator.pop(context);
          _showCredentials(doc);
        },
      ),
    );
  }

  void _showCredentials(AdminDoctor doc) {
    showDialog(
      context: context,
      builder: (_) => _CredentialsDialog(doctor: doc),
    );
  }

  void _confirmDelete(AdminDoctor doc) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusLarge)),
        title: const Text('Remove Doctor?'),
        content: Text(
            'Remove ${doc.name} from the system? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            onPressed: () {
              _service.deleteDoctor(doc.id);
              Navigator.pop(context);
              _refresh();
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text('${doc.name} removed'),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ));
            },
            child: const Text('Remove', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// DOCTOR FORM SHEET — Add / Edit
// ============================================================
class _DoctorFormSheet extends StatefulWidget {
  final AdminDoctor? doctor;
  final AdminService service;
  final void Function(AdminDoctor) onSaved;

  const _DoctorFormSheet({
    this.doctor,
    required this.service,
    required this.onSaved,
  });

  @override
  State<_DoctorFormSheet> createState() => _DoctorFormSheetState();
}

class _DoctorFormSheetState extends State<_DoctorFormSheet> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _showPassword = false;

  late final TextEditingController _idCtrl;
  late final TextEditingController _nameCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _passwordCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _nhpcCtrl;
  late final TextEditingController _qualCtrl;
  late final TextEditingController _expCtrl;
  late final TextEditingController _workCtrl;
  late final TextEditingController _addrCtrl;
  late String _specialization;
  late bool _isActive;
  late bool _isVerified;
  late bool _isAvailable;

  bool get _isEdit => widget.doctor != null;

  @override
  void initState() {
    super.initState();
    final d = widget.doctor;
    _idCtrl = TextEditingController(
      text: d?.id ?? widget.service.generateNextDoctorId(),
    );
    _nameCtrl = TextEditingController(text: d?.name ?? '');
    _emailCtrl = TextEditingController(text: d?.email ?? '');
    _passwordCtrl = TextEditingController(text: d?.password ?? '');
    _phoneCtrl = TextEditingController(text: d?.phone ?? '');
    _nhpcCtrl = TextEditingController(text: d?.nhpcNumber ?? '');
    _qualCtrl = TextEditingController(text: d?.qualification ?? '');
    _expCtrl = TextEditingController(text: d?.experienceYears.toString() ?? '0');
    _workCtrl = TextEditingController(text: d?.workingPlace ?? '');
    _addrCtrl = TextEditingController(text: d?.address ?? '');
    _specialization = d?.specialization ?? kSpecializations.first;
    _isActive = d?.isActive ?? true;
    _isVerified = d?.isVerified ?? true;
    _isAvailable = d?.isAvailable ?? true;
  }

  @override
  void dispose() {
    for (final c in [
      _idCtrl, _nameCtrl, _emailCtrl, _passwordCtrl, _phoneCtrl,
      _nhpcCtrl, _qualCtrl, _expCtrl, _workCtrl, _addrCtrl
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final doctorData = AdminDoctor(
      id: _isEdit ? widget.doctor!.id : '',
      name: _nameCtrl.text.trim(),
      email: _emailCtrl.text.trim(),
      password: _passwordCtrl.text.trim(),
      phone: _phoneCtrl.text.trim(),
      specialization: _specialization,
      nhpcNumber: _nhpcCtrl.text.trim(),
      qualification: _qualCtrl.text.trim(),
      experienceYears: int.tryParse(_expCtrl.text.trim()) ?? 0,
      workingPlace: _workCtrl.text.trim(),
      address: _addrCtrl.text.trim(),
      isActive: _isActive,
      isVerified: _isVerified,
      isAvailable: _isAvailable,
      joinDate: _isEdit
          ? widget.doctor!.joinDate
          : _formatDate(DateTime.now()),
      patients: _isEdit ? widget.doctor!.patients : 0,
      testsThisMonth: _isEdit ? widget.doctor!.testsThisMonth : 0,
      avgResponseTime: _isEdit ? widget.doctor!.avgResponseTime : 'N/A',
      rating: _isEdit ? widget.doctor!.rating : 4.5,
    );

    if (_isEdit) {
      final error = widget.service.updateDoctor(widget.doctor!.id, doctorData);
      setState(() => _isLoading = false);
      if (error != null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(error),
          backgroundColor: AppTheme.error,
          behavior: SnackBarBehavior.floating,
        ));
        return;
      }
      Navigator.pop(context);
      widget.onSaved(doctorData);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('${doctorData.name} updated'),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ));
    } else {
      try {
        final created = await widget.service.addDoctorViaApi(doctorData);
        if (!mounted) return;
        setState(() => _isLoading = false);
        Navigator.pop(context);
        widget.onSaved(created);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('${created.name} added'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ));
      } catch (e) {
        if (!mounted) return;
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.toString()),
          backgroundColor: AppTheme.error,
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

  String _formatDate(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppTheme.radiusXL)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
                color: AppTheme.textLight,
                borderRadius: BorderRadius.circular(2)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppTheme.spaceLG, AppTheme.spaceMD, AppTheme.spaceLG, 0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                  ),
                  child: Icon(
                    _isEdit ? Icons.edit_outlined : Icons.person_add_outlined,
                    color: const Color(0xFF10B981),
                    size: 20,
                  ),
                ),
                const SizedBox(width: AppTheme.spaceSM),
                Text(
                  _isEdit ? 'Edit Doctor' : 'Add New Doctor',
                  style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary),
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
                    _sectionLabel('Credentials'),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0FDF4),
                        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                        border: Border.all(
                          color: const Color(0xFF10B981).withValues(alpha: 0.35),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.badge_outlined, size: 18, color: Color(0xFF10B981)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _isEdit ? 'Doctor ID' : 'Doctor ID  (Auto-assigned)',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppTheme.textSecondary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Text(
                                  _idCtrl.text.isEmpty ? 'Assigned on save' : _idCtrl.text,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF10B981),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.lock_outline,
                            size: 14,
                            color: AppTheme.textSecondary.withValues(alpha: 0.5),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppTheme.spaceSM),
                    _buildTextField(
                      ctrl: _passwordCtrl,
                      label: 'Password *',
                      hint: 'Set login password for doctor',
                      icon: Icons.lock_outline,
                      obscureText: !_showPassword,
                      suffixIcon: IconButton(
                        icon: Icon(
                            _showPassword ? Icons.visibility_off : Icons.visibility,
                            size: 18,
                            color: AppTheme.textSecondary),
                        onPressed: () =>
                            setState(() => _showPassword = !_showPassword),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Password is required';
                        if (v.trim().length < 6) return 'Minimum 6 characters';
                        return null;
                      },
                    ),

                    const SizedBox(height: AppTheme.spaceMD),
                    _sectionLabel('Personal Information'),
                    _buildTextField(
                      ctrl: _nameCtrl,
                      label: 'Full Name *',
                      hint: 'Dr. Full Name',
                      icon: Icons.person_outline,
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Name is required' : null,
                    ),
                    const SizedBox(height: AppTheme.spaceSM),
                    _buildTextField(
                      ctrl: _emailCtrl,
                      label: 'Email *',
                      hint: 'doctor@netracare.np',
                      icon: Icons.email_outlined,
                      keyboardType: TextInputType.emailAddress,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Email is required';
                        if (!v.contains('@')) return 'Enter a valid email';
                        return null;
                      },
                    ),
                    const SizedBox(height: AppTheme.spaceSM),
                    _buildTextField(
                      ctrl: _phoneCtrl,
                      label: 'Phone *',
                      hint: '+977-98XXXXXXXX',
                      icon: Icons.phone_outlined,
                      keyboardType: TextInputType.phone,
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Phone is required' : null,
                    ),

                    const SizedBox(height: AppTheme.spaceMD),
                    _sectionLabel('Professional Information'),
                    // Specialization dropdown
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.background,
                        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.medical_services_outlined,
                              size: 16, color: AppTheme.textSecondary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: _specialization,
                                isExpanded: true,
                                style: const TextStyle(
                                    fontSize: 14, color: AppTheme.textPrimary),
                                hint: const Text('Specialization'),
                                items: kSpecializations
                                    .map((s) => DropdownMenuItem(
                                        value: s, child: Text(s)))
                                    .toList(),
                                onChanged: (v) =>
                                    setState(() => _specialization = v!),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppTheme.spaceSM),
                    _buildTextField(
                      ctrl: _nhpcCtrl,
                      label: 'NHPC Number *',
                      hint: 'NHPC-XXXXX',
                      icon: Icons.verified_outlined,
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'NHPC number required' : null,
                    ),
                    const SizedBox(height: AppTheme.spaceSM),
                    _buildTextField(
                      ctrl: _qualCtrl,
                      label: 'Qualification *',
                      hint: 'MBBS, MD (Ophthalmology)',
                      icon: Icons.school_outlined,
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Qualification required' : null,
                    ),
                    const SizedBox(height: AppTheme.spaceSM),
                    _buildTextField(
                      ctrl: _expCtrl,
                      label: 'Experience (Years) *',
                      hint: '5',
                      icon: Icons.work_history_outlined,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Experience required' : null,
                    ),
                    const SizedBox(height: AppTheme.spaceSM),
                    _buildTextField(
                      ctrl: _workCtrl,
                      label: 'Working Place *',
                      hint: 'Hospital / Clinic name',
                      icon: Icons.business_outlined,
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Working place required' : null,
                    ),
                    const SizedBox(height: AppTheme.spaceSM),
                    _buildTextField(
                      ctrl: _addrCtrl,
                      label: 'Address *',
                      hint: 'City, District',
                      icon: Icons.location_on_outlined,
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Address required' : null,
                    ),

                    const SizedBox(height: AppTheme.spaceMD),
                    _sectionLabel('Status Flags'),
                    _buildStatusToggles(),

                    const SizedBox(height: AppTheme.spaceLG),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppTheme.radiusMedium)),
                        ),
                        onPressed: _isLoading ? null : _submit,
                        child: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2))
                            : Text(
                                _isEdit ? 'Save Changes' : 'Add Doctor',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold),
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

  Widget _sectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.spaceSM),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: AppTheme.textSecondary,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController ctrl,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
    bool obscureText = false,
    bool readOnly = false,
    Widget? suffixIcon,
  }) {
    return TextFormField(
      controller: ctrl,
      readOnly: readOnly,
      obscureText: obscureText,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      validator: validator,
      style: const TextStyle(fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, size: 18, color: AppTheme.textSecondary),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: readOnly ? const Color(0xFFF9FAFB) : AppTheme.background,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
          borderSide: const BorderSide(color: AppTheme.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
          borderSide: const BorderSide(color: AppTheme.error),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        isDense: true,
      ),
    );
  }

  Widget _buildStatusToggles() {
    return Row(
      children: [
        _toggleChip('Active', _isActive, (v) => setState(() => _isActive = v)),
        const SizedBox(width: AppTheme.spaceSM),
        _toggleChip('Verified', _isVerified, (v) => setState(() => _isVerified = v)),
        const SizedBox(width: AppTheme.spaceSM),
        _toggleChip('Available', _isAvailable, (v) => setState(() => _isAvailable = v)),
      ],
    );
  }

  Widget _toggleChip(String label, bool value, ValueChanged<bool> onChanged) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: value ? const Color(0xFFECFDF5) : const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: value
                ? AppTheme.success.withOpacity(0.5)
                : const Color(0xFFE5E7EB),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              value ? Icons.check_circle : Icons.radio_button_unchecked,
              size: 14,
              color: value ? AppTheme.success : AppTheme.textLight,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: value ? AppTheme.success : AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// DOCTOR DETAIL SHEET
// ============================================================
class _DoctorDetailSheet extends StatelessWidget {
  final AdminDoctor doctor;
  final VoidCallback onShowCredentials;

  const _DoctorDetailSheet({
    required this.doctor,
    required this.onShowCredentials,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppTheme.radiusXL)),
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
                borderRadius: BorderRadius.circular(2)),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppTheme.spaceLG),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                              colors: [Color(0xFFD1FAE5), Color(0xFFDBEAFE)]),
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: Center(
                          child: Text(doctor.initials,
                              style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF059669))),
                        ),
                      ),
                      const SizedBox(width: AppTheme.spaceMD),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(doctor.name,
                                style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.textPrimary)),
                            Text(doctor.specialization,
                                style: const TextStyle(
                                    fontSize: 13, color: Color(0xFF059669))),
                            Text(doctor.workingPlace,
                                style: const TextStyle(
                                    fontSize: 12, color: AppTheme.textSecondary)),
                            Row(
                              children: [
                                const Icon(Icons.star,
                                    size: 13, color: Color(0xFFFBBF24)),
                                Text(' ${doctor.rating}',
                                    style: const TextStyle(
                                        fontSize: 12, color: AppTheme.textSecondary)),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: doctor.isActive
                                        ? const Color(0xFFECFDF5)
                                        : const Color(0xFFF3F4F6),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(doctor.status,
                                      style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: doctor.isActive
                                              ? AppTheme.success
                                              : AppTheme.textSecondary)),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppTheme.spaceLG),
                  _detailGrid(context),
                  const SizedBox(height: AppTheme.spaceMD),
                  // Credentials button
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: onShowCredentials,
                      icon: const Icon(Icons.key_outlined, size: 16),
                      label: const Text('View Login Credentials'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.primary,
                        side: const BorderSide(color: AppTheme.primary),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(AppTheme.radiusMedium)),
                      ),
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

  Widget _detailGrid(BuildContext context) {
    final items = [
      [Icons.badge_outlined, 'Doctor ID', doctor.id],
      [Icons.verified_outlined, 'NHPC No.', doctor.nhpcNumber],
      [Icons.school_outlined, 'Qualification', doctor.qualification],
      [Icons.work_history_outlined, 'Experience', '${doctor.experienceYears} years'],
      [Icons.email_outlined, 'Email', doctor.email],
      [Icons.phone_outlined, 'Phone', doctor.phone],
      [Icons.groups_outlined, 'Patients', '${doctor.patients}'],
      [Icons.assignment_outlined, 'Tests/Month', '${doctor.testsThisMonth}'],
      [Icons.location_on_outlined, 'Address', doctor.address],
      [Icons.calendar_today_outlined, 'Joined', doctor.joinDate],
    ];

    return Wrap(
      spacing: AppTheme.spaceSM,
      runSpacing: AppTheme.spaceSM,
      children: items.map((item) {
        final w = (MediaQuery.of(context).size.width - AppTheme.spaceLG * 2 - AppTheme.spaceSM) / 2;
        return SizedBox(
          width: w,
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
                      Text(item[1] as String,
                          style: const TextStyle(
                              fontSize: 10, color: AppTheme.textLight)),
                      Text(item[2] as String,
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textPrimary),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 2),
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
// CREDENTIALS DIALOG
// ============================================================
class _CredentialsDialog extends StatelessWidget {
  final AdminDoctor doctor;
  const _CredentialsDialog({required this.doctor});

  void _copy(BuildContext context, String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('$label copied to clipboard'),
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusLarge)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFBEB),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.key_outlined,
                color: Color(0xFFF59E0B), size: 18),
          ),
          const SizedBox(width: 8),
          const Text('Login Credentials', style: TextStyle(fontSize: 16)),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Doctor info
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                      colors: [Color(0xFFD1FAE5), Color(0xFFDBEAFE)]),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Center(
                  child: Text(doctor.initials,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Color(0xFF059669))),
                ),
              ),
              const SizedBox(width: AppTheme.spaceSM),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(doctor.name,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 14),
                        overflow: TextOverflow.ellipsis),
                    Text(doctor.specialization,
                        style: const TextStyle(
                            fontSize: 12, color: AppTheme.textSecondary)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spaceMD),

          // Warning
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFBEB),
              borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
              border: Border.all(color: const Color(0xFFFDE68A)),
            ),
            child: const Row(
              children: [
                Icon(Icons.warning_amber_outlined,
                    size: 14, color: Color(0xFFF59E0B)),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Share these credentials securely with the doctor.',
                    style:
                        TextStyle(fontSize: 11, color: Color(0xFF92400E)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppTheme.spaceMD),

          // Credential rows
          _credRow(context, 'Doctor ID', doctor.id, Icons.badge_outlined),
          const SizedBox(height: AppTheme.spaceSM),
          _credRow(context, 'Email (Login)', doctor.email, Icons.email_outlined),
          const SizedBox(height: AppTheme.spaceSM),
          _credRow(context, 'Password', doctor.password, Icons.lock_outline),
        ],
      ),
      actions: [
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primary,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusMedium)),
          ),
          onPressed: () => Navigator.pop(context),
          child: const Text('Done', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }

  Widget _credRow(
      BuildContext context, String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
      ),
      child: Row(
        children: [
          Icon(icon, size: 15, color: AppTheme.textSecondary),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        fontSize: 10, color: AppTheme.textSecondary)),
                Text(value,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'monospace',
                        color: AppTheme.textPrimary)),
              ],
            ),
          ),
          IconButton(
            onPressed: () => _copy(context, value, label),
            icon: const Icon(Icons.copy, size: 16, color: AppTheme.textSecondary),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }
}
