class ApiConfig {
  // Configure at build/run time using:
  // --dart-define=NETRACARE_API_BASE_URL=http://<host>:5000
  //
  // Fallback remains Android emulator host to preserve existing behavior.
  static const String _defaultBaseUrl = 'http://10.0.2.2:5000';
  static const String _definedBaseUrl = String.fromEnvironment(
    'NETRACARE_API_BASE_URL',
    defaultValue: '',
  );

  static String get baseUrl {
    if (_definedBaseUrl.trim().isNotEmpty) {
      return _definedBaseUrl.trim();
    }
    return _defaultBaseUrl;
  }

  static String get socketUrl => baseUrl;

  // API endpoints
  // Toggle canonical auth/profile namespace at build time:
  // --dart-define=NETRACARE_USE_API_V2_AUTH=true
  static const bool useApiV2Auth = bool.fromEnvironment(
    'NETRACARE_USE_API_V2_AUTH',
    defaultValue: false,
  );

  static const String loginEndpointLegacy = '/auth/login';
  static const String signupEndpointLegacy = '/auth/signup';
  static const String profileEndpointLegacy = '/user/profile';
  static const String profileImageEndpointLegacy = '/user/profile/image';
  static const String forgotPasswordEndpointLegacy = '/auth/forgot-password';
  static const String resetPasswordEndpointLegacy = '/auth/reset-password';
  static const String googleLoginEndpointLegacy = '/auth/google-login';

  static const String loginEndpointV2 = '/api/auth/login';
  static const String signupEndpointV2 = '/api/auth/register';
  static const String profileEndpointV2 = '/api/auth/profile';
  static const String forgotPasswordEndpointV2 = '/api/auth/forgot-password';
  static const String resetPasswordEndpointV2 = '/api/auth/reset-password';
  static const String googleLoginEndpointV2 = '/api/auth/google-login';

  static String get loginEndpoint =>
      useApiV2Auth ? loginEndpointV2 : loginEndpointLegacy;
  static String get signupEndpoint =>
      useApiV2Auth ? signupEndpointV2 : signupEndpointLegacy;
  static String get profileEndpoint =>
      useApiV2Auth ? profileEndpointV2 : profileEndpointLegacy;
  static String get forgotPasswordEndpoint =>
      useApiV2Auth ? forgotPasswordEndpointV2 : forgotPasswordEndpointLegacy;
  static String get resetPasswordEndpoint =>
      useApiV2Auth ? resetPasswordEndpointV2 : resetPasswordEndpointLegacy;
  static String get googleLoginEndpoint =>
      useApiV2Auth ? googleLoginEndpointV2 : googleLoginEndpointLegacy;

  static String? alternateAuthEndpoint(String endpoint) {
    switch (endpoint) {
      case loginEndpointLegacy:
        return loginEndpointV2;
      case loginEndpointV2:
        return loginEndpointLegacy;
      case signupEndpointLegacy:
        return signupEndpointV2;
      case signupEndpointV2:
        return signupEndpointLegacy;
      case profileEndpointLegacy:
        return profileEndpointV2;
      case profileEndpointV2:
        return profileEndpointLegacy;
      case forgotPasswordEndpointLegacy:
        return forgotPasswordEndpointV2;
      case forgotPasswordEndpointV2:
        return forgotPasswordEndpointLegacy;
      case resetPasswordEndpointLegacy:
        return resetPasswordEndpointV2;
      case resetPasswordEndpointV2:
        return resetPasswordEndpointLegacy;
      case googleLoginEndpointLegacy:
        return googleLoginEndpointV2;
      case googleLoginEndpointV2:
        return googleLoginEndpointLegacy;
      default:
        return null;
    }
  }

  static const String testUploadEndpoint = '/tests/upload';
  static const String visualAcuityEndpoint = '/visual-acuity/tests';
  static const String visualAcuityTestsEndpoint = '/visual-acuity/tests';
  static const String colourVisionPlatesEndpoint = '/colour-vision/plates';
  static const String colourVisionTestsEndpoint = '/colour-vision/tests';
  static const String eyeTrackingTestsEndpoint = '/eye-tracking/tests';
  static const String eyeTrackingUploadDataEndpoint =
      '/eye-tracking/upload-data';
  static const String eyeTrackingLatestEndpoint = '/eye-tracking/tests/latest';
  static const String eyeTrackingStatisticsEndpoint =
      '/eye-tracking/tests/statistics';
  static const String eyeTrackingCalibrateEndpoint = '/eye-tracking/calibrate';
  static const String distanceCalibrateEndpoint = '/distance/calibrate';
  static const String distanceActiveCalibrationEndpoint =
      '/distance/calibration/active';
  static const String distanceCalibrationsEndpoint = '/distance/calibrations';
  static const String distanceValidateEndpoint = '/distance/validate';
  static const String medicalRecordsEndpoint = '/user/medical-records';

  static String eyeTrackingResultDetailEndpoint(int resultId) =>
      '/eye-tracking/$resultId';
  static String eyeTrackingGenerateReportEndpoint(int resultId) =>
      '/eye-tracking/$resultId/generate-report';

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
  static const String doctorChangePasswordEndpoint =
      '/api/doctors/change-password';
  static const String doctorAllUsersEndpoint = '/api/doctors/all-users';
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
  static const String doctorSlotsEndpoint = '/api/consultations/doctor/slots';
  static const String availableDoctorSlotsEndpoint =
      '/api/consultations/slots/available';

  // Notifications
  static const String userNotificationsEndpoint = '/api/notifications/user';
  static const String userNotificationCountEndpoint =
      '/api/notifications/user/count';
  static const String adminNotificationsEndpoint = '/api/notifications/admin';
  static const String doctorNotificationsEndpoint = '/api/notifications/doctor';
  static const String doctorNotificationCountEndpoint =
      '/api/notifications/doctor/count';

  // Helper method to get consultation detail endpoint
  static String consultationDetailEndpoint(int consultationId) =>
      '/api/consultations/$consultationId';

  // Helper method to get consultation messages endpoint
  static String consultationMessagesEndpoint(int consultationId) =>
      '/api/consultations/$consultationId/messages';

  static String consultationMessagesEndpointRaw(String consultationId) =>
      '/api/consultations/$consultationId/messages';

  // Helper method to get doctor's consultation messages endpoint
  static String doctorConsultationMessagesEndpoint(int consultationId) =>
      '/api/consultations/$consultationId/doctor/messages';

  static String doctorConsultationMessagesEndpointRaw(String consultationId) =>
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

  static String shareTestEndpointRaw(String consultationId) =>
      '/api/consultations/$consultationId/share-test';

  static String consultationDetailEndpointRaw(String consultationId) =>
      '/api/consultations/$consultationId';

  // Helper method for doctor slot details
  static String doctorSlotDetailEndpoint(int slotId) =>
      '/api/consultations/doctor/slots/$slotId';

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
  static const String aiReportSendToDoctorEndpoint =
      '/api/ai-report/send-to-doctor';
  static const String aiReportMyDoctorsEndpoint = '/api/ai-report/my-doctors';

  // ========================================
  // Blink Detection / Fatigue
  // ========================================
  static const String blinkAnalyzeFrameEndpoint =
      '/blink-detection/analyze-frame';
  static const String blinkSubmitEndpoint = '/blink-detection/submit';
  static const String blinkFatiguePredictEndpoint = '/blink-fatigue/predict';
  static const String blinkFatigueSubmitEndpoint = '/blink-fatigue/test/submit';
  static const String blinkFatigueHistoryEndpoint = '/blink-fatigue/history';
  static const String blinkFatigueStatsEndpoint = '/blink-fatigue/stats';

  static String blinkFatigueHistoryDetailEndpoint(int testId) =>
      '/blink-fatigue/history/$testId';

  // ========================================
  // Pupil Reflex
  // ========================================
  static const String pupilReflexSubmitEndpoint =
      '/api/pupil-reflex/test/submit';
  static const String pupilReflexTestsEndpoint = '/api/pupil-reflex/tests';
  static const String pupilReflexStartTestEndpoint =
      '/api/pupil-reflex/start-test';
  static const String pupilReflexAnalyzeVideoEndpoint =
      '/api/pupil-reflex/analyze-video';

  static String pupilReflexTestDetailEndpoint(int testId) =>
      '/api/pupil-reflex/tests/$testId';
  static String pupilReflexResultsEndpoint(int testId) =>
      '/api/pupil-reflex/results/$testId';

  // ========================================
  // Chat
  // ========================================
  static const String chatRoomsEndpoint = '/api/chat/rooms';

  static String chatRoomMessagesEndpoint(int consultationId) =>
      '/api/chat/rooms/$consultationId/messages';
}
