import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/l10n/app_strings.dart';
import '../models/models.dart';

class AppPreferencesStore {
  static const _keyProfiles = 'lbm_profiles_v1';
  static const _keyActiveProfileId = 'lbm_active_profile_id';
  static const _keyThemeMode = 'lbm_theme_mode';
  static const _keyLanguage = 'lbm_language';
  static const _keyStatsIntervalMs = 'lbm_stats_interval_ms';

  Future<List<ConnectionProfile>> loadProfiles() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyProfiles);
    if (raw != null && raw.isNotEmpty) {
      try {
        final list = ConnectionProfile.decodeList(raw);
        if (list.isNotEmpty) return list;
      } catch (_) {}
    }
    return const [
      ConnectionProfile(
        id: 'default',
        name: 'Home Livebox',
        url: 'http://livebox.home/',
        username: 'admin',
      ),
    ];
  }

  Future<void> saveProfiles(List<ConnectionProfile> profiles) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyProfiles, ConnectionProfile.encodeList(profiles));
  }

  Future<String?> loadActiveProfileId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyActiveProfileId);
  }

  Future<void> saveActiveProfileId(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyActiveProfileId, id);
  }

  Future<ThemeMode> loadThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    final val = prefs.getString(_keyThemeMode);
    switch (val) {
      case 'light':
        return ThemeMode.light;
      case 'system':
        return ThemeMode.system;
      default:
        return ThemeMode.dark;
    }
  }

  Future<void> saveThemeMode(ThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    final val = switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.system => 'system',
      ThemeMode.dark => 'dark',
    };
    await prefs.setString(_keyThemeMode, val);
  }

  Future<AppLanguage> loadLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyLanguage) == 'fr'
        ? AppLanguage.fr
        : AppLanguage.en;
  }

  Future<void> saveLanguage(AppLanguage lang) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _keyLanguage,
      lang == AppLanguage.fr ? 'fr' : 'en',
    );
  }

  Future<int> loadStatsIntervalMs() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyStatsIntervalMs) ?? 2000;
  }

  Future<void> saveStatsIntervalMs(int ms) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyStatsIntervalMs, ms);
  }
}
