/// Configuration for Testing Mode
///
/// This configuration enables laptop webcam testing for development.
/// Set [isTestMode] to false for production builds on mobile devices.
///
/// Purpose: Allows testing all eye tests using laptop camera before
/// deploying to mobile devices.
class TestModeConfig {
  /// Enable test mode to use laptop webcam for all tests
  /// Set to false for production (mobile camera)
  static const bool isTestMode = true;

  /// Enable webcam capture for tests
  static const bool enableWebcam = true;

  /// Skip image selection dialog (for faster testing)
  static const bool skipImageSelection = false;

  /// Camera preview resolution
  static const String cameraResolution = 'high'; // high, medium, low

  /// Show debug overlay during tests
  static const bool showDebugOverlay = true;
}
