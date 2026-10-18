import 'package:flutter/material.dart';

class UserModel {
  final int id;
  final String email;
  final String firstName;
  final String lastName;
  final String sector;
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
    this.jobTitle,
    this.phone,
    this.timezone = 'Europe/Istanbul',
    this.locale = 'tr',
  });

  String get fullName => '$firstName $lastName';

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] ?? 0,
      email: json['email'] ?? '',
      firstName: json['first_name'] ?? '',
      lastName: json['last_name'] ?? '',
      sector: json['sector'] ?? 'Diğer',
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
