import 'package:flutter/material.dart';

class UserModel {
  final int id;
  final String email;
  final String firstName;
  final String lastName;
  final String sector;
  final String role; // 'admin', 'manager', 'staff'
  final String? jobTitle;
  final String? phone;
  final String timezone;
  final String locale;

  UserModel({
    required this.id,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.sector,
    this.role = 'staff',
    this.jobTitle,
    this.phone,
    this.timezone = 'Europe/Istanbul',
    this.locale = 'tr',
  });

  String get fullName => '$firstName $lastName'.trim();
  bool get isManager => role == 'manager' || role == 'admin';
  bool get isStaff => role == 'staff';
  bool get isAdmin => role == 'admin';

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] ?? 0,
      email: json['email'] ?? '',
      firstName: json['first_name'] ?? '',
      lastName: json['last_name'] ?? '',
      sector: json['sector'] ?? 'Diğer',
      role: json['role'] ?? 'staff',
      jobTitle: json['job_title'],
      phone: json['phone'],
      timezone: json['timezone'] ?? 'Europe/Istanbul',
      locale: json['locale'] ?? 'tr',
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'email': email,
    'first_name': firstName,
    'last_name': lastName,
    'sector': sector,
    'role': role,
    'job_title': jobTitle,
    'phone': phone,
    'timezone': timezone,
    'locale': locale,
  };
}

class ShiftTypeModel {
  final int id;
  final String name;
  final String shortName;
  final String startTime;
  final String endTime;
  final Color color;
  final String icon;
  final bool isWorking;
  final bool isNight;
  final bool isPaid;

  ShiftTypeModel({
    required this.id,
    required this.name,
    required this.shortName,
    required this.startTime,
    required this.endTime,
    required this.color,
    this.icon = 'work',
    this.isWorking = true,
    this.isNight = false,
    this.isPaid = true,
  });

  factory ShiftTypeModel.fromJson(Map<String, dynamic> json) {
    Color parsedColor = const Color(0xFF3157D5);
    if (json['color'] != null) {
      String hex = json['color'].toString().replaceAll('#', '');
      if (hex.length == 6) hex = 'FF$hex';
      parsedColor = Color(int.parse('0x$hex'));
    }

    return ShiftTypeModel(
      id: json['id'] ?? 0,
      name: json['name'] ?? 'Vardiya',
      shortName: json['short_name'] ?? 'V',
      startTime: json['start_time'] ?? '08:00',
      endTime: json['end_time'] ?? '16:00',
      color: parsedColor,
      icon: json['icon'] ?? 'work',
      isWorking: json['is_working'] ?? true,
      isNight: json['is_night'] ?? false,
      isPaid: json['is_paid'] ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'short_name': shortName,
    'start_time': startTime,
    'end_time': endTime,
    'color': '#${color.toARGB32().toRadixString(16).substring(2)}',
    'icon': icon,
    'is_working': isWorking,
    'is_night': isNight,
    'is_paid': isPaid,
  };
}

class ShiftModel {
  final int id;
  final int userId;
  final int shiftTypeId;
  final DateTime date;
  final DateTime startDateTime;
  final DateTime endDateTime;
  final String? note;
  final String? location;
  final String status;
  final ShiftTypeModel? shiftType;

  ShiftModel({
    required this.id,
    required this.userId,
    required this.shiftTypeId,
    required this.date,
    required this.startDateTime,
    required this.endDateTime,
    this.note,
    this.location,
    this.status = 'scheduled',
    this.shiftType,
  });

  double get durationHours {
    final diff = endDateTime.difference(startDateTime);
    return diff.inMinutes / 60.0;
  }

  factory ShiftModel.fromJson(Map<String, dynamic> json) {
    return ShiftModel(
      id: json['id'] ?? 0,
      userId: json['user_id'] ?? 0,
      shiftTypeId: json['shift_type_id'] ?? 0,
      date: DateTime.parse(json['date']),
      startDateTime: DateTime.parse(json['start_datetime']),
      endDateTime: DateTime.parse(json['end_datetime']),
      note: json['note'],
      location: json['location'],
      status: json['status'] ?? 'scheduled',
      shiftType: json['shift_type'] != null
          ? ShiftTypeModel.fromJson(json['shift_type'])
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'user_id': userId,
    'shift_type_id': shiftTypeId,
    'date': date.toIso8601String().substring(0, 10),
    'start_datetime': startDateTime.toIso8601String(),
    'end_datetime': endDateTime.toIso8601String(),
    'note': note,
    'location': location,
    'status': status,
    'shift_type': shiftType?.toJson(),
  };

  ShiftModel copyWith({
    int? id,
    int? userId,
    int? shiftTypeId,
    DateTime? date,
    DateTime? startDateTime,
    DateTime? endDateTime,
    String? note,
    String? location,
    String? status,
    ShiftTypeModel? shiftType,
  }) {
    return ShiftModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      shiftTypeId: shiftTypeId ?? this.shiftTypeId,
      date: date ?? this.date,
      startDateTime: startDateTime ?? this.startDateTime,
      endDateTime: endDateTime ?? this.endDateTime,
      note: note ?? this.note,
      location: location ?? this.location,
      status: status ?? this.status,
      shiftType: shiftType ?? this.shiftType,
    );
  }
}

class TeamMemberModel {
  final int id;
  final int userId;
  final String role;
  final String userName;

  TeamMemberModel({
    required this.id,
    required this.userId,
    required this.role,
    required this.userName,
  });

  factory TeamMemberModel.fromJson(Map<String, dynamic> json) {
    final user = json['user'];
    String name = 'Üye';
    if (user != null) {
      name = '${user['first_name'] ?? ''} ${user['last_name'] ?? ''}'.trim();
    }
    return TeamMemberModel(
      id: json['id'] ?? 0,
      userId: json['user_id'] ?? 0,
      role: json['role'] ?? 'member',
      userName: name.isEmpty ? 'Kullanıcı' : name,
    );
  }
}

class TeamModel {
  final int id;
  final String name;
  final String? description;
  final String inviteCode;
  final int ownerId;
  final List<TeamMemberModel> members;

  TeamModel({
    required this.id,
    required this.name,
    this.description,
    required this.inviteCode,
    required this.ownerId,
    this.members = const [],
  });

  factory TeamModel.fromJson(Map<String, dynamic> json) {
    var rawMembers = json['members'] as List? ?? [];
    return TeamModel(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      description: json['description'],
      inviteCode: json['invite_code'] ?? '',
      ownerId: json['owner_id'] ?? 0,
      members: rawMembers.map((m) => TeamMemberModel.fromJson(m)).toList(),
    );
  }
}

class ShiftSwapModel {
  final int id;
  final int requesterId;
  final int? targetUserId;
  final int requesterShiftId;
  final int? targetShiftId;
  final String status;
  final String? message;
  final DateTime createdAt;
  final ShiftModel? requesterShift;
  final ShiftModel? targetShift;

  ShiftSwapModel({
    required this.id,
    required this.requesterId,
    this.targetUserId,
    required this.requesterShiftId,
    this.targetShiftId,
    required this.status,
    this.message,
    required this.createdAt,
    this.requesterShift,
    this.targetShift,
  });

  factory ShiftSwapModel.fromJson(Map<String, dynamic> json) {
    return ShiftSwapModel(
      id: json['id'] ?? 0,
      requesterId: json['requester_id'] ?? 0,
      targetUserId: json['target_user_id'],
      requesterShiftId: json['requester_shift_id'] ?? 0,
      targetShiftId: json['target_shift_id'],
      status: json['status'] ?? 'PENDING',
      message: json['message'],
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
      requesterShift: json['requester_shift'] != null
          ? ShiftModel.fromJson(json['requester_shift'])
          : null,
      targetShift: json['target_shift'] != null
          ? ShiftModel.fromJson(json['target_shift'])
          : null,
    );
  }
}

class StatisticsModel {
  final double totalHoursThisWeek;
  final double totalHoursThisMonth;
  final double nightShiftHours;
  final int offDaysCount;
  final int totalShiftsCount;
  final int dayShiftCount;
  final int nightShiftCount;
  final int weekendShiftsCount;
  final double dayPercentage;
  final double nightPercentage;

  StatisticsModel({
    this.totalHoursThisWeek = 0.0,
    this.totalHoursThisMonth = 0.0,
    this.nightShiftHours = 0.0,
    this.offDaysCount = 0,
    this.totalShiftsCount = 0,
    this.dayShiftCount = 0,
    this.nightShiftCount = 0,
    this.weekendShiftsCount = 0,
    this.dayPercentage = 50.0,
    this.nightPercentage = 50.0,
  });

  factory StatisticsModel.fromJson(Map<String, dynamic> json) {
    final dist = json['distribution'] as Map<String, dynamic>? ?? {};
    return StatisticsModel(
      totalHoursThisWeek:
          (json['total_hours_this_week'] as num?)?.toDouble() ?? 0.0,
      totalHoursThisMonth:
          (json['total_hours_this_month'] as num?)?.toDouble() ?? 0.0,
      nightShiftHours: (json['night_shift_hours'] as num?)?.toDouble() ?? 0.0,
      offDaysCount: json['off_days_count'] ?? 0,
      totalShiftsCount: json['total_shifts_count'] ?? 0,
      dayShiftCount: json['day_shift_count'] ?? 0,
      nightShiftCount: json['night_shift_count'] ?? 0,
      weekendShiftsCount: json['weekend_shifts_count'] ?? 0,
      dayPercentage: (dist['day_percentage'] as num?)?.toDouble() ?? 50.0,
      nightPercentage: (dist['night_percentage'] as num?)?.toDouble() ?? 50.0,
    );
  }
}

// ==========================================
// YENİ NÖBET YÖNETİMİ MODELLERİ (AŞAMA 1-5)
// ==========================================

class DutyPeriodModel {
  final int id;
  final int teamId;
  final String name;
  final DateTime startDate;
  final DateTime endDate;
  final DateTime? excuseSubmissionDeadline;
  final bool isExcuseSubmissionOpen;
  final String status;
  final DateTime createdAt;

  DutyPeriodModel({
    required this.id,
    required this.teamId,
    required this.name,
    required this.startDate,
    required this.endDate,
    this.excuseSubmissionDeadline,
    this.isExcuseSubmissionOpen = false,
    this.status = 'DRAFT',
    required this.createdAt,
  });

  bool get isAcceptingExcuses {
    if (!isExcuseSubmissionOpen) return false;
    if (excuseSubmissionDeadline == null) return true;
    return DateTime.now().isBefore(excuseSubmissionDeadline!);
  }

  factory DutyPeriodModel.fromJson(Map<String, dynamic> json) {
    return DutyPeriodModel(
      id: json['id'] ?? 0,
      teamId: json['team_id'] ?? 0,
      name: json['name'] ?? '',
      startDate: DateTime.parse(json['start_date']),
      endDate: DateTime.parse(json['end_date']),
      excuseSubmissionDeadline: json['excuse_submission_deadline'] != null
          ? DateTime.parse(json['excuse_submission_deadline'])
          : null,
      isExcuseSubmissionOpen: json['is_excuse_submission_open'] ?? false,
      status: json['status'] ?? 'DRAFT',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'team_id': teamId,
    'name': name,
    'start_date': startDate.toIso8601String().substring(0, 10),
    'end_date': endDate.toIso8601String().substring(0, 10),
    'excuse_submission_deadline': excuseSubmissionDeadline?.toIso8601String(),
    'is_excuse_submission_open': isExcuseSubmissionOpen,
    'status': status,
    'created_at': createdAt.toIso8601String(),
  };
}

class DutyExcuseModel {
  final int id;
  final int periodId;
  final int userId;
  final DateTime startDate;
  final DateTime endDate;
  final String type; // ANNUAL_LEAVE, SICK_LEAVE, CONGRESS, SPECIAL, OTHER
  final bool isFullDay;
  final String? startTime;
  final String? endTime;
  final String? reason;
  final String status; // PENDING, APPROVED, REJECTED, INFO_REQUESTED
  final String? adminNote;
  final int? reviewedBy;
  final DateTime createdAt;
  final UserModel? user;

  DutyExcuseModel({
    required this.id,
    required this.periodId,
    required this.userId,
    required this.startDate,
    required this.endDate,
    required this.type,
    this.isFullDay = true,
    this.startTime,
    this.endTime,
    this.reason,
    this.status = 'PENDING',
    this.adminNote,
    this.reviewedBy,
    required this.createdAt,
    this.user,
  });

  String get typeDisplay {
    switch (type) {
      case 'ANNUAL_LEAVE':
        return 'Yıllık İzin';
      case 'SICK_LEAVE':
        return 'Sağlık Raporu';
      case 'CONGRESS':
        return 'Kongre / Eğitim';
      case 'SPECIAL':
        return 'Özel Mazeret';
      default:
        return 'Diğer Mazeret';
    }
  }

  String get statusDisplay {
    switch (status) {
      case 'APPROVED':
        return 'Onaylandı';
      case 'REJECTED':
        return 'Reddedildi';
      case 'INFO_REQUESTED':
        return 'Bilgi İstendi';
      default:
        return 'İnceleniyor';
    }
  }

  Color get statusColor {
    switch (status) {
      case 'APPROVED':
        return const Color(0xFF10B981);
      case 'REJECTED':
        return const Color(0xFFEF4444);
      case 'INFO_REQUESTED':
        return const Color(0xFFF59E0B);
      default:
        return const Color(0xFF3157D5);
    }
  }

  factory DutyExcuseModel.fromJson(Map<String, dynamic> json) {
    return DutyExcuseModel(
      id: json['id'] ?? 0,
      periodId: json['period_id'] ?? 0,
      userId: json['user_id'] ?? 0,
      startDate: DateTime.parse(json['start_date']),
      endDate: DateTime.parse(json['end_date']),
      type: json['type'] ?? 'OTHER',
      isFullDay: json['is_full_day'] ?? true,
      startTime: json['start_time'],
      endTime: json['end_time'],
      reason: json['reason'],
      status: json['status'] ?? 'PENDING',
      adminNote: json['admin_note'],
      reviewedBy: json['reviewed_by'],
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
      user: json['user'] != null ? UserModel.fromJson(json['user']) : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'period_id': periodId,
    'user_id': userId,
    'start_date': startDate.toIso8601String().substring(0, 10),
    'end_date': endDate.toIso8601String().substring(0, 10),
    'type': type,
    'is_full_day': isFullDay,
    'start_time': startTime,
    'end_time': endTime,
    'reason': reason,
    'status': status,
    'admin_note': adminNote,
    'reviewed_by': reviewedBy,
    'created_at': createdAt.toIso8601String(),
    'user': user?.toJson(),
  };
}

class DutyPlanShiftModel {
  final int id;
  final int planId;
  final int shiftTypeId;
  final int? assignedUserId;
  final DateTime date;
  final DateTime startDateTime;
  final DateTime endDateTime;
  final String? location;
  final String? note;
  final ShiftTypeModel? shiftType;
  final UserModel? assignedUser;

  DutyPlanShiftModel({
    required this.id,
    required this.planId,
    required this.shiftTypeId,
    this.assignedUserId,
    required this.date,
    required this.startDateTime,
    required this.endDateTime,
    this.location,
    this.note,
    this.shiftType,
    this.assignedUser,
  });

  bool get isAssigned => assignedUserId != null;

  factory DutyPlanShiftModel.fromJson(Map<String, dynamic> json) {
    return DutyPlanShiftModel(
      id: json['id'] ?? 0,
      planId: json['plan_id'] ?? 0,
      shiftTypeId: json['shift_type_id'] ?? 0,
      assignedUserId: json['assigned_user_id'],
      date: DateTime.parse(json['date']),
      startDateTime: DateTime.parse(json['start_datetime']),
      endDateTime: DateTime.parse(json['end_datetime']),
      location: json['location'],
      note: json['note'],
      shiftType: json['shift_type'] != null
          ? ShiftTypeModel.fromJson(json['shift_type'])
          : null,
      assignedUser: json['assigned_user'] != null
          ? UserModel.fromJson(json['assigned_user'])
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'plan_id': planId,
    'shift_type_id': shiftTypeId,
    'assigned_user_id': assignedUserId,
    'date': date.toIso8601String().substring(0, 10),
    'start_datetime': startDateTime.toIso8601String(),
    'end_datetime': endDateTime.toIso8601String(),
    'location': location,
    'note': note,
    'shift_type': shiftType?.toJson(),
    'assigned_user': assignedUser?.toJson(),
  };
}

class DutyPlanModel {
  final int id;
  final int periodId;
  final int teamId;
  final int version;
  final String status; // DRAFT, PUBLISHED, ARCHIVED
  final String? notes;
  final double fairnessScore;
  final int unassignedCount;
  final DateTime? publishedAt;
  final DateTime createdAt;
  final List<DutyPlanShiftModel> shifts;

  DutyPlanModel({
    required this.id,
    required this.periodId,
    required this.teamId,
    required this.version,
    required this.status,
    this.notes,
    this.fairnessScore = 1.0,
    this.unassignedCount = 0,
    this.publishedAt,
    required this.createdAt,
    this.shifts = const [],
  });

  bool get isPublished => status == 'PUBLISHED';
  bool get isDraft => status == 'DRAFT';

  factory DutyPlanModel.fromJson(Map<String, dynamic> json) {
    var rawShifts = json['shifts'] as List? ?? [];
    return DutyPlanModel(
      id: json['id'] ?? 0,
      periodId: json['period_id'] ?? 0,
      teamId: json['team_id'] ?? 0,
      version: json['version'] ?? 1,
      status: json['status'] ?? 'DRAFT',
      notes: json['notes'],
      fairnessScore: (json['fairness_score'] as num?)?.toDouble() ?? 1.0,
      unassignedCount: json['unassigned_count'] ?? 0,
      publishedAt: json['published_at'] != null
          ? DateTime.parse(json['published_at'])
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
      shifts: rawShifts.map((s) => DutyPlanShiftModel.fromJson(s)).toList(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'period_id': periodId,
    'team_id': teamId,
    'version': version,
    'status': status,
    'notes': notes,
    'fairness_score': fairnessScore,
    'unassigned_count': unassignedCount,
    'published_at': publishedAt?.toIso8601String(),
    'created_at': createdAt.toIso8601String(),
    'shifts': shifts.map((s) => s.toJson()).toList(),
  };
}
