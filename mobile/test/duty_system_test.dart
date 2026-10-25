import 'package:flutter_test/flutter_test.dart';
import 'package:shiftly/core/models/shift_models.dart';

void main() {
  group('Shiftly Duty & Permission System Tests', () {
    test('UserModel role validation and getters', () {
      final manager = UserModel(
        id: 1,
        email: 'yonetici@shiftly.app',
        firstName: 'Kemal',
        lastName: 'Yönetici',
        sector: 'Sağlık',
        role: 'manager',
      );

      final staff = UserModel(
        id: 2,
        email: 'personel1@shiftly.app',
        firstName: 'Necati',
        lastName: 'Yılmaz',
        sector: 'Sağlık',
        role: 'staff',
      );

      expect(manager.isManager, isTrue);
      expect(manager.isStaff, isFalse);
      expect(manager.fullName, 'Kemal Yönetici');

      expect(staff.isManager, isFalse);
      expect(staff.isStaff, isTrue);
      expect(staff.fullName, 'Necati Yılmaz');
    });

    test('DutyPeriodModel isAcceptingExcuses logic', () {
      final now = DateTime.now();
      final openPeriod = DutyPeriodModel(
        id: 1,
        teamId: 1,
        name: 'Kasım 2026 Dönemi',
        startDate: DateTime(2026, 11, 1),
        endDate: DateTime(2026, 11, 30),
        isExcuseSubmissionOpen: true,
        excuseSubmissionDeadline: now.add(const Duration(days: 3)),
        createdAt: now,
      );

      final closedPeriod = DutyPeriodModel(
        id: 2,
        teamId: 1,
        name: 'Eski Dönem',
        startDate: DateTime(2026, 10, 1),
        endDate: DateTime(2026, 10, 31),
        isExcuseSubmissionOpen: false,
        excuseSubmissionDeadline: now.subtract(const Duration(days: 1)),
        createdAt: now,
      );

      expect(openPeriod.isAcceptingExcuses, isTrue);
      expect(closedPeriod.isAcceptingExcuses, isFalse);
    });

    test('DutyExcuseModel status and type formatting', () {
      final excuse = DutyExcuseModel(
        id: 10,
        periodId: 1,
        userId: 2,
        startDate: DateTime(2026, 11, 5),
        endDate: DateTime(2026, 11, 7),
        type: 'ANNUAL_LEAVE',
        reason: 'Yıllık izin kullanımı',
        status: 'APPROVED',
        createdAt: DateTime.now(),
      );

      expect(excuse.typeDisplay, 'Yıllık İzin');
      expect(excuse.statusDisplay, 'Onaylandı');
      expect(excuse.isFullDay, isTrue);
    });

    test('DutyPlanModel unassigned and published status', () {
      final plan = DutyPlanModel(
        id: 5,
        periodId: 1,
        teamId: 1,
        version: 2,
        status: 'PUBLISHED',
        unassignedCount: 0,
        fairnessScore: 0.95,
        publishedAt: DateTime.now(),
        createdAt: DateTime.now(),
      );

      expect(plan.isPublished, isTrue);
      expect(plan.isDraft, isFalse);
      expect(plan.unassignedCount, 0);
    });
  });
}
