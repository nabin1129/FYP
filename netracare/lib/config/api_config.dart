class ApiConfig {
  // Change this to your backend URL
  // For local development (Android Emulator): use http://10.0.2.2:5000
  // For local development (iOS Simulator): use http://localhost:5000
  // For local development (Web): use http://localhost:5000
  // For physical device: use your computer's IP address, e.g., http://192.168.1.100:5000
  //
  // NOTE: Use 10.0.2.2 on Android emulator to reach host machine
  static const String baseUrl = 'http://10.0.2.2:5000';

  // API endpoints
  static const String loginEndpoint = '/auth/login';
  static const String signupEndpoint = '/auth/signup';
  static const String profileEndpoint = '/user/profile';
  static const String testUploadEndpoint = '/tests/upload';
  static const String visualAcuityEndpoint = '/visual-acuity/tests';
  static const String visualAcuityTestsEndpoint = '/visual-acuity/tests';
  static const String colourVisionPlatesEndpoint = '/colour-vision/plates';
  static const String colourVisionTestsEndpoint = '/colour-vision/tests';
  static const String eyeTrackingTestsEndpoint = '/eye-tracking/tests';

  // Doctor Consultation endpoints
  static const String consultationDoctorsEndpoint = '/consultation/doctors';
  static const String consultationBookEndpoint = '/consultation/book';
  static const String consultationHistoryEndpoint = '/consultation/history';
  static const String consultationChatEndpoint = '/consultation/chat';

  // ========================================
  // NEW API v2 - Doctor-Patient Linking
  // ========================================

  // Doctor Authentication & Profile
  static const String doctorRegisterEndpoint = '/api/doctors/register';
  static const String doctorLoginEndpoint = '/api/doctors/login';
  static const String doctorProfileEndpoint = '/api/doctors/profile';
  static const String doctorAvailabilityEndpoint = '/api/doctors/availability';
  static const String doctorListEndpoint = '/api/doctors/list';
  static const String doctorSearchEndpoint = '/api/doctors/search';
  static const String doctorStatsEndpoint = '/api/doctors/stats';

  // Doctor's Patient Management
  static const String doctorPatientsEndpoint = '/api/doctors/patients';

  // Consultations
  static const String bookConsultationEndpoint = '/api/consultations/book';
  static const String patientConsultationsEndpoint =
      '/api/consultations/patient/history';
  static const String patientUpcomingEndpoint =
      '/api/consultations/patient/upcoming';
  static const String doctorPendingEndpoint =
      '/api/consultations/doctor/pending';
  static const String doctorScheduleEndpoint =
      '/api/consultations/doctor/schedule';
  static const String doctorConsultationsEndpoint =
      '/api/consultations/doctor/history';

  // Notifications
  static const String userNotificationsEndpoint = '/api/notifications/user';
  static const String userNotificationCountEndpoint =
      '/api/notifications/user/count';
  static const String doctorNotificationsEndpoint = '/api/notifications/doctor';
  static const String doctorNotificationCountEndpoint =
      '/api/notifications/doctor/count';

  // Helper method to get consultation detail endpoint
  static String consultationDetailEndpoint(int consultationId) =>
      '/api/consultations/$consultationId';

  // Helper method to get consultation messages endpoint
  static String consultationMessagesEndpoint(int consultationId) =>
      '/api/consultations/$consultationId/messages';

  // Helper method to get doctor's consultation messages endpoint
  static String doctorConsultationMessagesEndpoint(int consultationId) =>
      '/api/consultations/$consultationId/doctor/messages';

  // Helper method to schedule consultation
  static String scheduleConsultationEndpoint(int consultationId) =>
      '/api/consultations/$consultationId/schedule';

  // Helper method to start consultation
  static String startConsultationEndpoint(int consultationId) =>
      '/api/consultations/$consultationId/start';

  // Helper method to complete consultation
  static String completeConsultationEndpoint(int consultationId) =>
      '/api/consultations/$consultationId/complete';

  // Helper method to cancel consultation
  static String cancelConsultationEndpoint(int consultationId) =>
      '/api/consultations/$consultationId/cancel';

  // Helper method to share test result
  static String shareTestEndpoint(int consultationId) =>
      '/api/consultations/$consultationId/share-test';

  // Helper method to get patient detail for doctor
  static String doctorPatientDetailEndpoint(int patientId) =>
      '/api/doctors/patients/$patientId';

  // Helper method for doctor details
  static String doctorDetailEndpoint(int doctorId) => '/api/doctors/$doctorId';

  // ========================================
  // Admin Panel
  // ========================================
  static const String adminStatsEndpoint = '/api/admin/stats';
  static const String adminAnalyticsOverviewEndpoint =
      '/api/admin/analytics/overview';
  static const String adminLoginEndpoint = '/api/admin/login';
  static const String adminUsersEndpoint = '/api/admin/users';
  static const String adminDoctorsEndpoint = '/api/admin/doctors';
  static const String adminCreateDoctorEndpoint = '/api/doctors/admin/create';
  static const String adminReminderCreateEndpoint =
      '/api/notifications/admin/reminders';

  static String adminUserDetailEndpoint(int userId) =>
      '/api/admin/users/$userId';
  static String adminDoctorUpdateEndpoint(int doctorId) =>
      '/api/doctors/admin/$doctorId';
  static String adminDoctorDetailEndpoint(int doctorId) =>
      '/api/admin/doctors/$doctorId';
  static String adminUserReportEndpoint(int userId) =>
      '/api/ai-report/admin/users/$userId/report';
  static String adminUserReportPdfEndpoint(int userId) =>
      '/api/ai-report/admin/users/$userId/report-pdf';

  // ========================================
  // AI Report
  // ========================================
  static const String aiReportGenerateEndpoint = '/api/ai-report/generate';
  static const String aiReportPdfEndpoint = '/api/ai-report/generate-pdf';
  static const String aiReportInsightsEndpoint = '/api/ai-report/insights';
}
