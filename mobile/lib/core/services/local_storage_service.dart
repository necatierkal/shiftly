import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/shift_models.dart';

class LocalStorageService {
  static const String _keyToken = 'auth_token';
  static const String _keyRefreshToken = 'refresh_token';
  static const String _keyUser = 'cached_user';
  static const String _keyShifts = 'cached_shifts';
  static const String _keyShiftTypes = 'cached_shift_types';
  static const String _keyOnboardingDone = 'onboarding_done';
  static const String _keyCustomApiUrl = 'custom_api_url';
  static const String _keyLastSync = 'last_sync_timestamp';
  static const String _keyCachedPeriods = 'cached_duty_periods';
  static const String _keyCachedExcuses = 'cached_duty_excuses';
  static const String _keyCachedPlan = 'cached_duty_plan';

  late SharedPreferences _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // Token
  Future<void> saveTokens({required String access, required String refresh}) async {
    await _prefs.setString(_keyToken, access);
    await _prefs.setString(_keyRefreshToken, refresh);
  }

  String? getAccessToken() => _prefs.getString(_keyToken);
  String? getRefreshToken() => _prefs.getString(_keyRefreshToken);

  Future<void> clearAuth() async {
    await _prefs.remove(_keyToken);
    await _prefs.remove(_keyRefreshToken);
    await _prefs.remove(_keyUser);
  }

  // Onboarding
  bool isOnboardingDone() => _prefs.getBool(_keyOnboardingDone) ?? false;
  Future<void> setOnboardingDone(bool done) async {
    await _prefs.setBool(_keyOnboardingDone, done);
  }

  // Custom API Base URL
  String? getCustomApiUrl() => _prefs.getString(_keyCustomApiUrl);
  Future<void> setCustomApiUrl(String? url) async {
    if (url == null || url.trim().isEmpty) {
      await _prefs.remove(_keyCustomApiUrl);
    } else {
      await _prefs.setString(_keyCustomApiUrl, url.trim());
    }
  }

  // Last Sync Time
  DateTime? getLastSyncTime() {
    final raw = _prefs.getString(_keyLastSync);
    if (raw == null) return null;
    try {
      return DateTime.parse(raw);
    } catch (_) {
      return null;
    }
  }

  Future<void> setLastSyncTime(DateTime time) async {
    await _prefs.setString(_keyLastSync, time.toIso8601String());
  }

  // Cached User
  Future<void> saveUser(UserModel user) async {
    await _prefs.setString(_keyUser, jsonEncode(user.toJson()));
  }

  UserModel? getCachedUser() {
    final raw = _prefs.getString(_keyUser);
    if (raw == null) return null;
    try {
      return UserModel.fromJson(jsonDecode(raw));
    } catch (_) {
      return null;
    }
  }

  // Cached Shifts
  Future<void> saveShifts(List<ShiftModel> shifts) async {
    final rawList = shifts.map((s) => s.toJson()).toList();
    await _prefs.setString(_keyShifts, jsonEncode(rawList));
  }

  List<ShiftModel> getCachedShifts() {
    final raw = _prefs.getString(_keyShifts);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list.map((item) => ShiftModel.fromJson(item)).toList();
    } catch (_) {
      return [];
    }
  }

  // Cached Shift Types
  Future<void> saveShiftTypes(List<ShiftTypeModel> types) async {
    final rawList = types.map((t) => t.toJson()).toList();
    await _prefs.setString(_keyShiftTypes, jsonEncode(rawList));
  }

  List<ShiftTypeModel> getCachedShiftTypes() {
    final raw = _prefs.getString(_keyShiftTypes);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list.map((item) => ShiftTypeModel.fromJson(item)).toList();
    } catch (_) {
      return [];
    }
  }

  // Cached Duty Periods
  Future<void> savePeriods(List<DutyPeriodModel> periods) async {
    final rawList = periods.map((p) => p.toJson()).toList();
    await _prefs.setString(_keyCachedPeriods, jsonEncode(rawList));
  }

  List<DutyPeriodModel> getCachedPeriods() {
    final raw = _prefs.getString(_keyCachedPeriods);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list.map((item) => DutyPeriodModel.fromJson(item)).toList();
    } catch (_) {
      return [];
    }
  }

  // Cached Duty Excuses
  Future<void> saveExcuses(List<DutyExcuseModel> excuses) async {
    final rawList = excuses.map((e) => e.toJson()).toList();
    await _prefs.setString(_keyCachedExcuses, jsonEncode(rawList));
  }

  List<DutyExcuseModel> getCachedExcuses() {
    final raw = _prefs.getString(_keyCachedExcuses);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list.map((item) => DutyExcuseModel.fromJson(item)).toList();
    } catch (_) {
      return [];
    }
  }

  // Cached Duty Plan
  Future<void> savePlan(DutyPlanModel plan) async {
    await _prefs.setString(_keyCachedPlan, jsonEncode(plan.toJson()));
  }

  DutyPlanModel? getCachedPlan() {
    final raw = _prefs.getString(_keyCachedPlan);
    if (raw == null) return null;
    try {
      return DutyPlanModel.fromJson(jsonDecode(raw));
    } catch (_) {
      return null;
    }
  }
}
