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

  // Cached Shifts (Offline support)
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
}
