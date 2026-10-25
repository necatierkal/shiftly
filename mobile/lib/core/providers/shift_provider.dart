import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../models/shift_models.dart';
import '../services/api_service.dart';
import '../services/local_storage_service.dart';

class ShiftProvider extends ChangeNotifier {
  final ApiService _api;
  final LocalStorageService _storage;

  List<ShiftModel> _shifts = [];
  List<ShiftTypeModel> _shiftTypes = [];
  StatisticsModel? _statistics;
  bool _isLoading = false;
  String? _errorMessage;

  // Yeni Nöbet Yönetim Durumları
  List<DutyPeriodModel> _periods = [];
  List<DutyExcuseModel> _excuses = [];
  DutyPlanModel? _currentPlan;
  DateTime? _lastSyncTime;

  List<ShiftModel> get shifts => _shifts;
  List<ShiftTypeModel> get shiftTypes => _shiftTypes;
  StatisticsModel? get statistics => _statistics;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  List<DutyPeriodModel> get periods => _periods;
  DutyPeriodModel? get activePeriod {
    for (var p in _periods) {
      if (p.isAcceptingExcuses) return p;
    }
    return _periods.isNotEmpty ? _periods.first : null;
  }

  List<DutyExcuseModel> get excuses => _excuses;
  int get pendingExcusesCount =>
      _excuses.where((e) => e.status == 'PENDING').length;
  DutyPlanModel? get currentPlan => _currentPlan;
  DateTime? get lastSyncTime => _lastSyncTime;

  static List<ShiftTypeModel> get defaultShiftTypes => [
        ShiftTypeModel(
          id: 1,
          name: 'Gündüz',
          shortName: 'G',
          startTime: '08:00',
          endTime: '16:00',
          color: const Color(0xFF3157D5),
          icon: 'wb_sunny',
          isWorking: true,
          isNight: false,
        ),
        ShiftTypeModel(
          id: 2,
          name: 'Gece',
          shortName: 'N',
          startTime: '20:00',
          endTime: '08:00',
          color: const Color(0xFF8B5CF6),
          icon: 'nightlight_round',
          isWorking: true,
          isNight: true,
        ),
        ShiftTypeModel(
          id: 3,
          name: '24 Saat Nöbet',
          shortName: '24',
          startTime: '08:00',
          endTime: '08:00',
          color: const Color(0xFFEF4444),
          icon: 'schedule',
          isWorking: true,
          isNight: true,
        ),
        ShiftTypeModel(
          id: 4,
          name: 'İzin',
          shortName: 'İ',
          startTime: '00:00',
          endTime: '23:59',
          color: const Color(0xFF10B981),
          icon: 'beach_access',
          isWorking: false,
          isNight: false,
          isPaid: true,
        ),
        ShiftTypeModel(
          id: 5,
          name: 'Akşam',
          shortName: 'A',
          startTime: '16:00',
          endTime: '24:00',
          color: const Color(0xFFF59E0B),
          icon: 'bedtime',
          isWorking: true,
          isNight: false,
        ),
      ];

  ShiftProvider(this._api, this._storage) {
    _loadFromCache();
  }

  void _loadFromCache() {
    _shiftTypes = _storage.getCachedShiftTypes();
    if (_shiftTypes.isEmpty) {
      _shiftTypes = defaultShiftTypes;
      _storage.saveShiftTypes(_shiftTypes);
    }

    _shifts = _storage.getCachedShifts();
    _linkShiftTypes();

    _periods = _storage.getCachedPeriods();
    _excuses = _storage.getCachedExcuses();
    _currentPlan = _storage.getCachedPlan();
    _lastSyncTime = _storage.getLastSyncTime();

    if (_periods.isEmpty) {
      _seedDefaultPeriods();
    }

    if (_shifts.isEmpty) {
      _seedDefaultShifts();
    } else {
      _calculateOfflineStatistics();
    }
  }

  void _linkShiftTypes() {
    for (int i = 0; i < _shifts.length; i++) {
      if (_shifts[i].shiftType == null) {
        final match = _shiftTypes.firstWhere(
          (t) => t.id == _shifts[i].shiftTypeId,
          orElse: () => _shiftTypes.first,
        );
        _shifts[i] = _shifts[i].copyWith(shiftType: match);
      }
    }
  }

  void _seedDefaultPeriods() {
    final now = DateTime.now();
    final firstDayThisMonth = DateTime(now.year, now.month, 1);
    final lastDayThisMonth = DateTime(now.year, now.month + 1, 0);

    final seedPeriod = DutyPeriodModel(
      id: 1,
      teamId: 1,
      name: '${_getMonthName(now.month)} ${now.year} Nöbet Planlama Dönemi',
      startDate: firstDayThisMonth,
      endDate: lastDayThisMonth,
      excuseSubmissionDeadline: DateTime(now.year, now.month, 28, 23, 59),
      isExcuseSubmissionOpen: true,
      status: 'PLANNING',
      createdAt: now,
    );

    _periods = [seedPeriod];
    _storage.savePeriods(_periods);
  }

  String _getMonthName(int month) {
    const names = [
      '',
      'Ocak',
      'Şubat',
      'Mart',
      'Nisan',
      'Mayıs',
      'Haziran',
      'Temmuz',
      'Ağustos',
      'Eylül',
      'Ekim',
      'Kasım',
      'Aralık',
    ];
    return (month >= 1 && month <= 12) ? names[month] : '';
  }

  void _seedDefaultShifts() {
    final List<ShiftModel> seed = [];
    final now = DateTime.now();

    final gunduz = _shiftTypes.firstWhere(
      (t) => t.id == 1,
      orElse: () => defaultShiftTypes[0],
    );
    final gece = _shiftTypes.firstWhere(
      (t) => t.id == 2,
      orElse: () => defaultShiftTypes[1],
    );
    final nobet24 = _shiftTypes.firstWhere(
      (t) => t.id == 3,
      orElse: () => defaultShiftTypes[2],
    );
    final izin = _shiftTypes.firstWhere(
      (t) => t.id == 4,
      orElse: () => defaultShiftTypes[3],
    );

    // Güncel ayın tüm günlerine gerçekçi nöbet döngüsü yerleştir
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    for (int day = 1; day <= daysInMonth; day++) {
      final d = DateTime(now.year, now.month, day);
      final cycle = day % 3;
      if (cycle == 1) {
        seed.add(
          ShiftModel(
            id: 1000 + day,
            userId: 1,
            shiftTypeId: gunduz.id,
            date: d,
            startDateTime: DateTime(d.year, d.month, d.day, 8, 0),
            endDateTime: DateTime(d.year, d.month, d.day, 16, 0),
            location: 'Şehir Hastanesi',
            note: 'Gündüz Servis Nöbeti',
            shiftType: gunduz,
          ),
        );
      } else if (cycle == 2) {
        seed.add(
          ShiftModel(
            id: 1000 + day,
            userId: 1,
            shiftTypeId: (day % 6 == 2) ? nobet24.id : gece.id,
            date: d,
            startDateTime: DateTime(d.year, d.month, d.day, 20, 0),
            endDateTime: DateTime(d.year, d.month, d.day + 1, 8, 0),
            location: 'Acil Servis',
            note: (day % 6 == 2) ? '24 Saat Nöbet' : 'Gece Acil Nöbeti',
            shiftType: (day % 6 == 2) ? nobet24 : gece,
          ),
        );
      } else {
        seed.add(
          ShiftModel(
            id: 1000 + day,
            userId: 1,
            shiftTypeId: izin.id,
            date: d,
            startDateTime: DateTime(d.year, d.month, d.day, 0, 0),
            endDateTime: DateTime(d.year, d.month, d.day, 23, 59),
            note: 'İzin',
            shiftType: izin,
          ),
        );
      }
    }

    _shifts = seed;
    _storage.saveShifts(_shifts);
    _calculateOfflineStatistics();
  }

  // Dashboard Helpers
  ShiftModel? get todayShift {
    final now = DateTime.now();
    final todayDate = DateTime(now.year, now.month, now.day);
    try {
      return _shifts.firstWhere((s) {
        final d = DateTime(s.date.year, s.date.month, s.date.day);
        return d.isAtSameMomentAs(todayDate) && s.status != 'cancelled';
      });
    } catch (_) {
      return null;
    }
  }

  ShiftModel? get nextShift {
    final now = DateTime.now();
    final sorted = _shifts
        .where(
          (s) =>
              s.startDateTime.isAfter(now) &&
              s.status != 'cancelled' &&
              (s.shiftType?.isWorking ?? true),
        )
        .toList()
      ..sort((a, b) => a.startDateTime.compareTo(b.startDateTime));
    return sorted.isNotEmpty ? sorted.first : null;
  }

  List<ShiftModel> getShiftsForDate(DateTime date) {
    final target = DateTime(date.year, date.month, date.day);
    return _shifts.where((s) {
      final d = DateTime(s.date.year, s.date.month, s.date.day);
      return d.isAtSameMomentAs(target) && s.status != 'cancelled';
    }).toList();
  }

  List<ShiftModel> get thisWeekShifts {
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    final start = DateTime(monday.year, monday.month, monday.day);
    final end = start.add(const Duration(days: 7));

    return _shifts.where((s) {
      return s.date.isAfter(start.subtract(const Duration(seconds: 1))) &&
          s.date.isBefore(end) &&
          s.status != 'cancelled';
    }).toList();
  }

  // ==========================================
  // NÖBET DÖNEMİ İŞLEMLERİ (PERIODS)
  // ==========================================

  Future<void> fetchPeriods({int teamId = 1}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final res = await _api.get('/periods?team_id=$teamId');
      if (res is List) {
        _periods = res.map((item) => DutyPeriodModel.fromJson(item)).toList();
        await _storage.savePeriods(_periods);
        _lastSyncTime = DateTime.now();
        await _storage.setLastSyncTime(_lastSyncTime!);
      }
    } catch (e) {
      // Offline fallback: keep cached periods
      _periods = _storage.getCachedPeriods();
      if (_periods.isEmpty) _seedDefaultPeriods();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> createPeriod({
    required int teamId,
    required String name,
    required DateTime startDate,
    required DateTime endDate,
    DateTime? excuseDeadline,
    bool openExcuses = true,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final body = {
        'team_id': teamId,
        'name': name,
        'start_date': startDate.toIso8601String().substring(0, 10),
        'end_date': endDate.toIso8601String().substring(0, 10),
        'excuse_submission_deadline': excuseDeadline?.toIso8601String(),
        'is_excuse_submission_open': openExcuses,
      };

      final res = await _api.post('/periods', body: body);
      final newPeriod = DutyPeriodModel.fromJson(res);
      _periods.insert(0, newPeriod);
      await _storage.savePeriods(_periods);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      // Local fallback
      final localPeriod = DutyPeriodModel(
        id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        teamId: teamId,
        name: name,
        startDate: startDate,
        endDate: endDate,
        excuseSubmissionDeadline: excuseDeadline,
        isExcuseSubmissionOpen: openExcuses,
        createdAt: DateTime.now(),
      );
      _periods.insert(0, localPeriod);
      await _storage.savePeriods(_periods);
      _isLoading = false;
      notifyListeners();
      return true;
    }
  }

  Future<bool> toggleExcuseSubmission(int periodId, bool isOpen) async {
    try {
      final endpoint = isOpen ? 'open-excuses' : 'close-excuses';
      await _api.post('/periods/$periodId/$endpoint');
    } catch (_) {}

    final index = _periods.indexWhere((p) => p.id == periodId);
    if (index != -1) {
      final old = _periods[index];
      _periods[index] = DutyPeriodModel(
        id: old.id,
        teamId: old.teamId,
        name: old.name,
        startDate: old.startDate,
        endDate: old.endDate,
        excuseSubmissionDeadline: old.excuseSubmissionDeadline,
        isExcuseSubmissionOpen: isOpen,
        status: old.status,
        createdAt: old.createdAt,
      );
      await _storage.savePeriods(_periods);
      notifyListeners();
    }
    return true;
  }

  // ==========================================
  // MAZERET İŞLEMLERİ (EXCUSES)
  // ==========================================

  Future<void> fetchExcuses({int? periodId}) async {
    _isLoading = true;
    notifyListeners();

    try {
      String endpoint = '/excuses';
      if (periodId != null) {
        endpoint += '?period_id=$periodId';
      }
      final res = await _api.get(endpoint);
      if (res is List) {
        _excuses = res.map((item) => DutyExcuseModel.fromJson(item)).toList();
        await _storage.saveExcuses(_excuses);
        _lastSyncTime = DateTime.now();
        await _storage.setLastSyncTime(_lastSyncTime!);
      }
    } catch (_) {
      _excuses = _storage.getCachedExcuses();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> submitExcuse({
    required int periodId,
    required DateTime startDate,
    required DateTime endDate,
    required String type,
    bool isFullDay = true,
    String? startTime,
    String? endTime,
    String? reason,
  }) async {
    _isLoading = true;
    notifyListeners();

    final body = {
      'period_id': periodId,
      'start_date': startDate.toIso8601String().substring(0, 10),
      'end_date': endDate.toIso8601String().substring(0, 10),
      'type': type,
      'is_full_day': isFullDay,
      'start_time': startTime,
      'end_time': endTime,
      'reason': reason,
    };

    try {
      final res = await _api.post('/excuses', body: body);
      final newExcuse = DutyExcuseModel.fromJson(res);
      _excuses.insert(0, newExcuse);
      await _storage.saveExcuses(_excuses);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      // Local fallback
      final localExcuse = DutyExcuseModel(
        id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        periodId: periodId,
        userId: 2,
        startDate: startDate,
        endDate: endDate,
        type: type,
        isFullDay: isFullDay,
        startTime: startTime,
        endTime: endTime,
        reason: reason,
        status: 'PENDING',
        createdAt: DateTime.now(),
      );
      _excuses.insert(0, localExcuse);
      await _storage.saveExcuses(_excuses);
      _isLoading = false;
      notifyListeners();
      return true;
    }
  }

  Future<bool> reviewExcuse(
    int excuseId,
    String status, {
    String? adminNote,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final body = {'status': status, 'admin_note': adminNote};
      await _api.put('/excuses/$excuseId/review', body: body);
    } catch (_) {}

    final index = _excuses.indexWhere((e) => e.id == excuseId);
    if (index != -1) {
      final old = _excuses[index];
      _excuses[index] = DutyExcuseModel(
        id: old.id,
        periodId: old.periodId,
        userId: old.userId,
        startDate: old.startDate,
        endDate: old.endDate,
        type: old.type,
        isFullDay: old.isFullDay,
        startTime: old.startTime,
        endTime: old.endTime,
        reason: old.reason,
        status: status,
        adminNote: adminNote ?? old.adminNote,
        reviewedBy: old.reviewedBy,
        createdAt: old.createdAt,
        user: old.user,
      );
      await _storage.saveExcuses(_excuses);
    }

    _isLoading = false;
    notifyListeners();
    return true;
  }

  // ==========================================
  // NÖBET TASLAĞI & YAYIMLAMA (PLANS)
  // ==========================================

  Future<DutyPlanModel?> generateDraftPlan({
    required int periodId,
    required int teamId,
    List<int>? shiftTypeIds,
    int minRestHours = 11,
    int maxConsecutiveDays = 6,
    int targetShiftsPerPerson = 7,
    bool respectNightRules = true,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final body = {
      'period_id': periodId,
      'team_id': teamId,
      'shift_type_ids': shiftTypeIds ?? [1, 2, 3],
      'min_rest_hours': minRestHours,
      'max_consecutive_days': maxConsecutiveDays,
      'target_shifts_per_person': targetShiftsPerPerson,
      'respect_night_rules': respectNightRules,
    };

    try {
      final res = await _api.post('/plans/generate', body: body);
      _currentPlan = DutyPlanModel.fromJson(res);
      await _storage.savePlan(_currentPlan!);
      _lastSyncTime = DateTime.now();
      await _storage.setLastSyncTime(_lastSyncTime!);
      _isLoading = false;
      notifyListeners();
      return _currentPlan;
    } catch (e) {
      // Local demo solver fallback
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  Future<bool> publishPlan(int planId) async {
    _isLoading = true;
    notifyListeners();

    try {
      final res = await _api.post(
        '/plans/$planId/publish',
        body: {'notes': 'Yönetici tarafından onaylandı ve yayımlandı.'},
      );
      _currentPlan = DutyPlanModel.fromJson(res);
      await _storage.savePlan(_currentPlan!);

      // Convert published plan shifts to active shifts
      if (_currentPlan != null && _currentPlan!.shifts.isNotEmpty) {
        final newShifts = _currentPlan!.shifts
            .where((ps) => ps.assignedUserId != null)
            .map(
              (ps) => ShiftModel(
                id: ps.id,
                userId: ps.assignedUserId!,
                shiftTypeId: ps.shiftTypeId,
                date: ps.date,
                startDateTime: ps.startDateTime,
                endDateTime: ps.endDateTime,
                location: ps.location ?? 'Hastane / Görev Yeri',
                note: ps.note ?? ps.shiftType?.name ?? 'Planlanmış Nöbet',
                shiftType: ps.shiftType,
              ),
            )
            .toList();

        _shifts = newShifts;
        await _storage.saveShifts(_shifts);
        _calculateOfflineStatistics();
      }

      _lastSyncTime = DateTime.now();
      await _storage.setLastSyncTime(_lastSyncTime!);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> fetchPublishedPlan(int periodId) async {
    _isLoading = true;
    notifyListeners();

    try {
      final res = await _api.get('/plans/published/current?period_id=$periodId');
      if (res != null) {
        _currentPlan = DutyPlanModel.fromJson(res);
        await _storage.savePlan(_currentPlan!);
        _lastSyncTime = DateTime.now();
        await _storage.setLastSyncTime(_lastSyncTime!);
      }
    } catch (_) {
      _currentPlan = _storage.getCachedPlan();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<Uint8List?> exportPlanExcel(int planId) async {
    try {
      return await _api.getBytes('/plans/$planId/export/excel');
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return null;
    }
  }

  Future<Uint8List?> exportPlanPdf(int planId) async {
    try {
      return await _api.getBytes('/plans/$planId/export/pdf');
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return null;
    }
  }

  // ==========================================
  // VARDIYA CRUD & İSTATİSTİKLER
  // ==========================================

  Future<void> fetchShiftTypes() async {
    try {
      final res = await _api.get('/shift-types');
      if (res is List) {
        _shiftTypes = res.map((item) => ShiftTypeModel.fromJson(item)).toList();
        await _storage.saveShiftTypes(_shiftTypes);
        _linkShiftTypes();
        notifyListeners();
      }
    } catch (_) {
      // Keep cached types
    }
  }

  Future<void> fetchShifts() async {
    _isLoading = true;
    notifyListeners();

    try {
      final res = await _api.get('/shifts');
      if (res is List) {
        _shifts = res.map((item) => ShiftModel.fromJson(item)).toList();
        _linkShiftTypes();
        await _storage.saveShifts(_shifts);
        _lastSyncTime = DateTime.now();
        await _storage.setLastSyncTime(_lastSyncTime!);
        _calculateOfflineStatistics();
      }
    } catch (_) {
      _shifts = _storage.getCachedShifts();
      _linkShiftTypes();
      _calculateOfflineStatistics();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> addShift({
    required int shiftTypeId,
    required DateTime date,
    required DateTime startDateTime,
    required DateTime endDateTime,
    String? note,
    String? location,
  }) async {
    final type = _shiftTypes.firstWhere(
      (t) => t.id == shiftTypeId,
      orElse: () => _shiftTypes.first,
    );

    final newShift = ShiftModel(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      userId: 1,
      shiftTypeId: shiftTypeId,
      date: date,
      startDateTime: startDateTime,
      endDateTime: endDateTime,
      note: note,
      location: location,
      shiftType: type,
    );

    _shifts.add(newShift);
    _shifts.sort((a, b) => a.startDateTime.compareTo(b.startDateTime));
    await _storage.saveShifts(_shifts);
    _calculateOfflineStatistics();
    notifyListeners();

    try {
      await _api.post('/shifts', body: newShift.toJson());
    } catch (_) {}

    return true;
  }

  Future<bool> createShift({
    required int shiftTypeId,
    required DateTime date,
    required DateTime startDateTime,
    required DateTime endDateTime,
    String? location,
    String? note,
    int? reminderMinutes,
  }) async {
    return addShift(
      shiftTypeId: shiftTypeId,
      date: date,
      startDateTime: startDateTime,
      endDateTime: endDateTime,
      location: location,
      note: note,
    );
  }

  Future<bool> generatePattern({
    required String cycleType,
    required DateTime startDate,
    required DateTime endDate,
    bool overwrite = true,
  }) async {
    if (overwrite) {
      _shifts.removeWhere(
        (s) => !s.date.isBefore(startDate) && !s.date.isAfter(endDate),
      );
    }

    final gunduz = _shiftTypes.firstWhere(
      (t) => t.id == 1,
      orElse: () => defaultShiftTypes[0],
    );
    final gece = _shiftTypes.firstWhere(
      (t) => t.id == 2,
      orElse: () => defaultShiftTypes[1],
    );
    final nobet24 = _shiftTypes.firstWhere(
      (t) => t.id == 3,
      orElse: () => defaultShiftTypes[2],
    );
    final izin = _shiftTypes.firstWhere(
      (t) => t.id == 4,
      orElse: () => defaultShiftTypes[3],
    );
    final aksam = _shiftTypes.firstWhere(
      (t) => t.id == 5,
      orElse: () => defaultShiftTypes[4],
    );

    final totalDays = endDate.difference(startDate).inDays + 1;
    final List<ShiftModel> newShifts = [];

    for (int i = 0; i < totalDays; i++) {
      final d = startDate.add(Duration(days: i));
      ShiftTypeModel currentType;
      DateTime sTime;
      DateTime eTime;

      if (cycleType == '24_48') {
        final step = i % 3;
        if (step == 0) {
          currentType = nobet24;
          sTime = DateTime(d.year, d.month, d.day, 8, 0);
          eTime = DateTime(d.year, d.month, d.day + 1, 8, 0);
        } else {
          currentType = izin;
          sTime = DateTime(d.year, d.month, d.day, 0, 0);
          eTime = DateTime(d.year, d.month, d.day, 23, 59);
        }
      } else if (cycleType == '12_24_12_48') {
        final step = i % 4;
        if (step == 0) {
          currentType = gunduz;
          sTime = DateTime(d.year, d.month, d.day, 8, 0);
          eTime = DateTime(d.year, d.month, d.day, 20, 0);
        } else if (step == 1) {
          currentType = gece;
          sTime = DateTime(d.year, d.month, d.day, 20, 0);
          eTime = DateTime(d.year, d.month, d.day + 1, 8, 0);
        } else {
          currentType = izin;
          sTime = DateTime(d.year, d.month, d.day, 0, 0);
          eTime = DateTime(d.year, d.month, d.day, 23, 59);
        }
      } else {
        // 3 vardiya
        final step = i % 4;
        if (step == 0) {
          currentType = gunduz;
          sTime = DateTime(d.year, d.month, d.day, 8, 0);
          eTime = DateTime(d.year, d.month, d.day, 16, 0);
        } else if (step == 1) {
          currentType = aksam;
          sTime = DateTime(d.year, d.month, d.day, 16, 0);
          eTime = DateTime(d.year, d.month, d.day, 24, 0);
        } else if (step == 2) {
          currentType = gece;
          sTime = DateTime(d.year, d.month, d.day, 20, 0);
          eTime = DateTime(d.year, d.month, d.day + 1, 8, 0);
        } else {
          currentType = izin;
          sTime = DateTime(d.year, d.month, d.day, 0, 0);
          eTime = DateTime(d.year, d.month, d.day, 23, 59);
        }
      }

      newShifts.add(
        ShiftModel(
          id: (DateTime.now().millisecondsSinceEpoch ~/ 1000) + i,
          userId: 1,
          shiftTypeId: currentType.id,
          date: d,
          startDateTime: sTime,
          endDateTime: eTime,
          note: currentType.name,
          shiftType: currentType,
        ),
      );
    }

    _shifts.addAll(newShifts);
    _shifts.sort((a, b) => a.startDateTime.compareTo(b.startDateTime));
    await _storage.saveShifts(_shifts);
    _calculateOfflineStatistics();
    notifyListeners();
    return true;
  }

  Future<bool> updateShift(ShiftModel shift) async {
    final index = _shifts.indexWhere((s) => s.id == shift.id);
    if (index != -1) {
      _shifts[index] = shift;
      _shifts.sort((a, b) => a.startDateTime.compareTo(b.startDateTime));
      await _storage.saveShifts(_shifts);
      _calculateOfflineStatistics();
      notifyListeners();
    }

    try {
      await _api.put('/shifts/${shift.id}', body: shift.toJson());
    } catch (_) {}

    return true;
  }

  Future<bool> deleteShift(int id) async {
    try {
      await _api.delete('/shifts/$id');
    } catch (_) {}

    _shifts.removeWhere((s) => s.id == id);
    await _storage.saveShifts(_shifts);
    _calculateOfflineStatistics();
    notifyListeners();
    return true;
  }

  Future<void> fetchStatistics() async {
    try {
      final res = await _api.get('/statistics');
      if (res != null) {
        _statistics = StatisticsModel.fromJson(res);
        notifyListeners();
        return;
      }
    } catch (_) {}

    _calculateOfflineStatistics();
    notifyListeners();
  }

  void _calculateOfflineStatistics() {
    final now = DateTime.now();
    final currentMonth = now.month;
    final currentYear = now.year;

    double weekHours = 0;
    double monthHours = 0;
    double nightHours = 0;
    int offCount = 0;
    int totalCount = 0;
    int dayCount = 0;
    int nightCount = 0;
    int weekendCount = 0;

    for (var s in thisWeekShifts) {
      if (s.shiftType?.isWorking ?? true) {
        weekHours += s.durationHours;
      }
    }

    for (var s in _shifts) {
      final isWorking = s.shiftType?.isWorking ?? true;
      final isNight = s.shiftType?.isNight ?? false;

      if (!isWorking) {
        offCount++;
      } else {
        totalCount++;
        if (s.date.month == currentMonth && s.date.year == currentYear) {
          monthHours += s.durationHours;
        }
        if (isNight) {
          nightCount++;
          nightHours += s.durationHours;
        } else {
          dayCount++;
        }
        if (s.date.weekday == 6 || s.date.weekday == 7) {
          weekendCount++;
        }
      }
    }

    final totalShifts = dayCount + nightCount;
    final dayPct = totalShifts > 0 ? (dayCount / totalShifts) * 100.0 : 50.0;
    final nightPct =
        totalShifts > 0 ? (nightCount / totalShifts) * 100.0 : 50.0;

    _statistics = StatisticsModel(
      totalHoursThisWeek: weekHours > 0 ? weekHours : 32.0,
      totalHoursThisMonth: monthHours > 0 ? monthHours : 160.0,
      nightShiftHours: nightHours > 0 ? nightHours : 48.0,
      offDaysCount: offCount,
      totalShiftsCount: totalCount,
      dayShiftCount: dayCount,
      nightShiftCount: nightCount,
      weekendShiftsCount: weekendCount,
      dayPercentage: dayPct,
      nightPercentage: nightPct,
    );
  }
}
