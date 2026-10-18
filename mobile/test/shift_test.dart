import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shiftly/core/models/shift_models.dart';

void main() {
  group('Shiftly Models & Calculations Tests', () {
    test('ShiftTypeModel parsing and color verification', () {
      final json = {
        'id': 1,
        'name': '24 Saat Nöbet',
        'short_name': '24',
        'start_time': '08:00',
        'end_time': '08:00',
        'color': '#3157D5',
        'is_working': true,
        'is_night': true,
      };

      final shiftType = ShiftTypeModel.fromJson(json);

      expect(shiftType.id, 1);
      expect(shiftType.name, '24 Saat Nöbet');
      expect(shiftType.shortName, '24');
      expect(shiftType.isNight, true);
      expect(shiftType.color, const Color(0xFF3157D5));
    });

    test('ShiftModel duration calculation for 24h shift', () {
      final start = DateTime(2026, 10, 3, 8, 0);
      final end = DateTime(2026, 10, 4, 8, 0);

      final shift = ShiftModel(
        id: 101,
        userId: 1,
        shiftTypeId: 1,
        date: DateTime(2026, 10, 3),
        startDateTime: start,
        endDateTime: end,
        location: 'Ankara Numune Hastanesi',
      );

      expect(shift.durationHours, 24.0);
      expect(shift.location, 'Ankara Numune Hastanesi');
    });

    test('ShiftModel duration calculation for standard 8h day shift', () {
      final start = DateTime(2026, 10, 3, 8, 0);
      final end = DateTime(2026, 10, 3, 16, 0);

      final shift = ShiftModel(
        id: 102,
        userId: 1,
        shiftTypeId: 2,
        date: DateTime(2026, 10, 3),
        startDateTime: start,
        endDateTime: end,
      );

      expect(shift.durationHours, 8.0);
    });

    test('StatisticsModel percentage and hours mapping', () {
      final json = {
        'total_hours_this_week': 32.0,
        'total_hours_this_month': 168.0,
        'night_shift_hours': 48.0,
        'off_days_count': 6,
        'total_shifts_count': 21,
        'day_shift_count': 15,
        'night_shift_count': 6,
        'weekend_shifts_count': 4,
        'distribution': {
          'day_percentage': 71.4,
          'night_percentage': 28.6,
        },
      };

      final stats = StatisticsModel.fromJson(json);

      expect(stats.totalHoursThisWeek, 32.0);
      expect(stats.totalHoursThisMonth, 168.0);
      expect(stats.nightShiftHours, 48.0);
      expect(stats.offDaysCount, 6);
      expect(stats.dayPercentage, 71.4);
    });
  });
}
