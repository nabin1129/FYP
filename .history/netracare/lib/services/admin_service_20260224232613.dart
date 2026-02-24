import '../models/admin/admin_doctor_model.dart';
import '../models/admin/admin_user_model.dart';

/// Admin Service — manages all admin CRUD operations in-memory
/// Uses singleton pattern consistent with DoctorService
class AdminService {
  static final AdminService _instance = AdminService._internal();
  factory AdminService() => _instance;
  AdminService._internal();

  final List<AdminDoctor> _doctors = [];
  final List<AdminUser> _users = [];
  bool _initialized = false;

  void initialize() {
    if (_initialized) return;
    _doctors.addAll(AdminDoctor.getInitialDoctors());
    _users.addAll(AdminUser.getInitialUsers());
    _initialized = true;
  }

  // ========================================
  // STATS
  // ========================================

  int get totalDoctors => _doctors.length;
  int get totalUsers => _users.length;
  int get activeDoctors => _doctors.where((d) => d.isActive).length;
  int get activeUsers => _users.where((u) => u.isActive).length;

  int get totalTestsThisMonth =>
      _doctors.fold(0, (sum, d) => sum + d.testsThisMonth);

  int get avgHealthScore {
    if (_users.isEmpty) return 0;
    return (_users.fold(0, (sum, u) => sum + u.healthScore) / _users.length)
        .round();
  }

  double get avgRating {
    if (_doctors.isEmpty) return 0.0;
    return _doctors.fold(0.0, (sum, d) => sum + d.rating) / _doctors.length;
  }

  int get totalPatients =>
      _doctors.fold(0, (sum, d) => sum + d.patients);

  // ========================================
  // DOCTOR OPERATIONS
  // ========================================

  List<AdminDoctor> get doctors {
    if (!_initialized) initialize();
    return List.unmodifiable(_doctors);
  }

  List<AdminDoctor> searchDoctors(String query, {String filter = 'all'}) {
    if (!_initialized) initialize();
    final q = query.toLowerCase();
    return _doctors.where((d) {
      final matchSearch = q.isEmpty ||
          d.name.toLowerCase().contains(q) ||
          d.email.toLowerCase().contains(q) ||
          d.specialization.toLowerCase().contains(q) ||
          d.id.toLowerCase().contains(q);
      final matchFilter = filter == 'all' ||
          (filter == 'active' && d.isActive) ||
          (filter == 'inactive' && !d.isActive);
      return matchSearch && matchFilter;
    }).toList();
  }

  /// Check if a doctor ID already exists
  bool doctorIdExists(String id) {
    if (!_initialized) initialize();
    return _doctors.any((d) => d.id == id);
  }

  /// Check if a doctor email already exists
  bool doctorEmailExists(String email, {String? excludeId}) {
    if (!_initialized) initialize();
    return _doctors.any((d) => d.email == email && d.id != excludeId);
  }

  /// Add a new doctor — ID and password are manually set by admin
  /// Returns error message if validation fails, null on success
  String? addDoctor(AdminDoctor doctor) {
    if (!_initialized) initialize();
    if (doctor.id.trim().isEmpty) return 'Doctor ID cannot be empty';
    if (doctorIdExists(doctor.id)) return 'Doctor ID "${doctor.id}" already exists';
    if (doctorEmailExists(doctor.email)) return 'Email "${doctor.email}" is already registered';
    if (doctor.password.length < 6) return 'Password must be at least 6 characters';
    _doctors.add(doctor);
    return null;
  }

  /// Update an existing doctor
  /// Returns error message on failure, null on success
  String? updateDoctor(String id, AdminDoctor updated) {
    if (!_initialized) initialize();
    final index = _doctors.indexWhere((d) => d.id == id);
    if (index == -1) return 'Doctor not found';
    if (doctorEmailExists(updated.email, excludeId: id)) {
      return 'Email "${updated.email}" is already used by another doctor';
    }
    if (updated.password.length < 6) return 'Password must be at least 6 characters';
    _doctors[index] = updated.copyWith(id: id);
    return null;
  }

  /// Delete a doctor by ID
  bool deleteDoctor(String id) {
    if (!_initialized) initialize();
    final before = _doctors.length;
    _doctors.removeWhere((d) => d.id == id);
    return _doctors.length < before;
  }

  /// Toggle doctor active status
  void toggleDoctorStatus(String id) {
    if (!_initialized) initialize();
    final index = _doctors.indexWhere((d) => d.id == id);
    if (index != -1) {
      _doctors[index].isActive = !_doctors[index].isActive;
    }
  }

  /// Get doctor by ID
  AdminDoctor? getDoctorById(String id) {
    if (!_initialized) initialize();
    try {
      return _doctors.firstWhere((d) => d.id == id);
    } catch (_) {
      return null;
    }
  }

  // ========================================
  // USER OPERATIONS
  // ========================================

  List<AdminUser> get users {
    if (!_initialized) initialize();
    return List.unmodifiable(_users);
  }

  List<AdminUser> searchUsers(String query, {String filter = 'all'}) {
    if (!_initialized) initialize();
    final q = query.toLowerCase();
    return _users.where((u) {
      final matchSearch = q.isEmpty ||
          u.name.toLowerCase().contains(q) ||
          u.email.toLowerCase().contains(q) ||
          u.location.toLowerCase().contains(q);
      final matchFilter = filter == 'all' ||
          (filter == 'active' && u.isActive) ||
          (filter == 'inactive' && !u.isActive);
      return matchSearch && matchFilter;
    }).toList();
  }

  /// Toggle user active status
  void toggleUserStatus(String id) {
    if (!_initialized) initialize();
    final index = _users.indexWhere((u) => u.id == id);
    if (index != -1) {
      _users[index].isActive = !_users[index].isActive;
    }
  }

  /// Delete a user by ID
  bool deleteUser(String id) {
    if (!_initialized) initialize();
    final before = _users.length;
    _users.removeWhere((u) => u.id == id);
    return _users.length < before;
  }

  /// Get user by ID
  AdminUser? getUserById(String id) {
    if (!_initialized) initialize();
    try {
      return _users.firstWhere((u) => u.id == id);
    } catch (_) {
      return null;
    }
  }
}
