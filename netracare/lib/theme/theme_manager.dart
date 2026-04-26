import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'accessibility_modes.dart';

class ThemeManager extends ChangeNotifier {
  ThemeManager._(this._prefs, this._settings);

  static const _storageKey = 'netracare.theme_settings';

  final SharedPreferences _prefs;
  ThemeSettings _settings;

  ThemeSettings get settings => _settings;
  ThemeMode get themeMode => _settings.themeMode;
  AccessibilityMode get accessibilityMode => _settings.accessibilityMode;
  double get textScale => _settings.textScale;

  static Future<ThemeManager> create() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);

    final settings = raw == null
        ? const ThemeSettings()
        : ThemeSettings.fromJson(jsonDecode(raw) as Map<String, Object?>);

    return ThemeManager._(prefs, settings);
  }

  Future<void> updateThemeMode(ThemeMode themeMode) {
    return _update(_settings.copyWith(themeMode: themeMode));
  }

  Future<void> updateAccessibilityMode(AccessibilityMode mode) {
    return _update(_settings.copyWith(accessibilityMode: mode));
  }

  Future<void> updateTextScale(double textScale) {
    return _update(_settings.copyWith(textScale: textScale));
  }

  Future<void> reset() {
    return _update(const ThemeSettings());
  }

  Future<void> _update(ThemeSettings next) async {
    if (_settings == next) {
      return;
    }

    _settings = next;
    await _prefs.setString(_storageKey, jsonEncode(_settings.toJson()));
    notifyListeners();
  }
}
