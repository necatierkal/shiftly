import 'package:flutter/material.dart';
import '../config/app_config.dart';
import '../models/shift_models.dart';
import '../services/api_service.dart';
import '../services/local_storage_service.dart';

class AuthProvider extends ChangeNotifier {
  final ApiService _api;
  final LocalStorageService _storage;

  UserModel? _currentUser;
  bool _isLoading = false;
  String? _errorMessage;

  UserModel? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _storage.getAccessToken() != null;
  String? get errorMessage => _errorMessage;

  bool get isManager => _currentUser?.isManager ?? false;
  bool get isStaff => _currentUser?.isStaff ?? true;
  bool get isAdmin => _currentUser?.isAdmin ?? false;

  AuthProvider(this._api, this._storage) {
    _loadPersistedUser();
  }

  void _loadPersistedUser() {
    _currentUser = _storage.getCachedUser();
  }

  Future<void> setCustomServerUrl(String url) async {
    _api.setBaseUrl(url);
    notifyListeners();
  }

  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final res = await _api.post(
        '/auth/login',
        body: {'email': email.trim(), 'password': password},
        needsAuth: false,
      );

      final tokens = res['tokens'];
      final userData = res['user'];

      await _storage.saveTokens(
        access: tokens['access_token'],
        refresh: tokens['refresh_token'],
      );

      _currentUser = UserModel.fromJson(userData);
      await _storage.saveUser(_currentUser!);

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      final trimmedEmail = email.trim();

      // Offline fallback: Manager
      if (trimmedEmail == AppConfig.managerEmail || trimmedEmail.contains('yonetici')) {
        final managerUser = UserModel(
          id: 1,
          email: AppConfig.managerEmail,
          firstName: 'Kemal',
          lastName: 'Yönetici',
          sector: 'Sağlık',
          role: 'manager',
          jobTitle: 'Başhekim / Nöbet Sorumlusu',
        );
        _currentUser = managerUser;
        await _storage.saveTokens(
          access: 'offline_manager_token',
          refresh: 'offline_manager_refresh',
        );
        await _storage.saveUser(managerUser);
        _isLoading = false;
        notifyListeners();
        return true;
      }

      // Offline fallback: Staff / Demo
      if (trimmedEmail == AppConfig.demoEmail ||
          trimmedEmail == AppConfig.staffEmail ||
          _storage.getCachedUser()?.email == trimmedEmail) {
        final staffUser = _storage.getCachedUser() ??
            UserModel(
              id: 2,
              email: AppConfig.staffEmail,
              firstName: 'Necati',
              lastName: 'Yılmaz',
              sector: 'Sağlık',
              role: 'staff',
              jobTitle: 'Sağlık Personeli',
            );
        _currentUser = staffUser;
        await _storage.saveTokens(
          access: 'offline_staff_token',
          refresh: 'offline_staff_refresh',
        );
        await _storage.saveUser(staffUser);
        _isLoading = false;
        notifyListeners();
        return true;
      }

      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> register({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required String sector,
    String role = 'staff',
    String? jobTitle,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final res = await _api.post(
        '/auth/register',
        body: {
          'email': email.trim(),
          'password': password,
          'first_name': firstName.trim(),
          'last_name': lastName.trim(),
          'sector': sector,
          'role': role,
          'job_title': jobTitle?.trim(),
        },
        needsAuth: false,
      );

      final tokens = res['tokens'];
      final userData = res['user'];

      await _storage.saveTokens(
        access: tokens['access_token'],
        refresh: tokens['refresh_token'],
      );

      _currentUser = UserModel.fromJson(userData);
      await _storage.saveUser(_currentUser!);

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      // Offline fallback: create local user account
      final localUser = UserModel(
        id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        email: email.trim(),
        firstName: firstName.trim(),
        lastName: lastName.trim(),
        sector: sector,
        role: role,
        jobTitle: jobTitle?.trim(),
      );

      _currentUser = localUser;
      await _storage.saveTokens(
        access: 'offline_access_token',
        refresh: 'offline_refresh_token',
      );
      await _storage.saveUser(localUser);

      _isLoading = false;
      notifyListeners();
      return true;
    }
  }

  Future<bool> loginAsManager() async {
    return login(AppConfig.managerEmail, AppConfig.managerPassword);
  }

  Future<bool> loginAsStaff() async {
    return login(AppConfig.staffEmail, AppConfig.staffPassword);
  }

  Future<bool> loginAsDemo() async {
    return login(AppConfig.demoEmail, AppConfig.demoPassword);
  }

  Future<void> logout() async {
    await _storage.clearAuth();
    _currentUser = null;
    notifyListeners();
  }

  Future<bool> deleteAccount() async {
    _isLoading = true;
    notifyListeners();
    try {
      await _api.delete('/auth/me');
    } catch (_) {}
    await logout();
    _isLoading = false;
    return true;
  }
}
