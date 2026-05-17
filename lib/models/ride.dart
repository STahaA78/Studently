DateTime _parseServerDateTime(dynamic jsonVal) {
  if (jsonVal == null) return DateTime.now();
  final s = jsonVal is String ? jsonVal : jsonVal.toString();
  final tzPattern = RegExp(r'([Zz]|[+\-]\d{2}:\d{2})$');
  DateTime dt;
  try {
    if (tzPattern.hasMatch(s)) {
      dt = DateTime.parse(s);
    } else {
      dt = DateTime.parse(s + 'Z');
    }
  } catch (_) {
    dt = DateTime.parse(s);
  }
  return dt.toLocal();
}


class RideOffer {
  final String id;
  final String driverId;
  final String driverName;
  final String driverGender;
  final String campus;
  final String homeLocation;
  final String direction;
  final String vehicleType;
  final List<String> availableDays;
  final int totalSeats;
  final int availableSeats;
  final int costPerSeat;
  final String genderPreference;
  final String groupChatName;
  final String departureTime;
  final String status;
  final List<String> passengers;
  final DateTime createdAt;
  final DateTime activatedAt;

  RideOffer({
    required this.id,
    required this.driverId,
    required this.driverName,
    required this.driverGender,
    required this.campus,
    required this.homeLocation,
    required this.direction,
    required this.vehicleType,
    required this.availableDays,
    required this.totalSeats,
    required this.availableSeats,
    required this.costPerSeat,
    required this.genderPreference,
    required this.groupChatName,
    required this.departureTime,
    required this.status,
    required this.passengers,
    required this.createdAt,
    required this.activatedAt,
  });

  String get directionLabel =>
      direction == 'campus_to_home' ? 'Campus → Home' : 'Home → Campus';

  factory RideOffer.fromJson(Map<String, dynamic> json) {
    return RideOffer(
      id: json['_id'],
      driverId: json['driver_id'],
      driverName: json['driver_name'] ?? 'Unknown',
      driverGender: json['driver_gender'] ?? 'Other',
      campus: json['campus'],
      homeLocation: json['home_location'],
      direction: json['direction'],
      vehicleType: json['vehicle_type'] ?? 'car',
      availableDays: List<String>.from(json['available_days'] ?? []),
      totalSeats: json['total_seats'],
      availableSeats: json['available_seats'],
      costPerSeat: json['cost_per_seat'] ?? 0,
      genderPreference: json['gender_preference'] ?? 'mix',
      groupChatName: json['group_chat_name'] ?? '',
      departureTime: json['departure_time'] ?? '',
      status: json['status'],
      passengers: List<String>.from(json['passengers'] ?? []),
      createdAt: _parseServerDateTime(json['created_at']),
      activatedAt: _parseServerDateTime(json['activated_at']),
    );
  }
}

class RideRequest {
  final String id;
  final String requesterId;
  final String requesterName;
  final String requesterGender;
  final String campus;
  final String otherLocation;
  final String direction;
  final String genderPreference;
  final DateTime neededDatetime;
  final String status;
  final DateTime createdAt;

  RideRequest({
    required this.id,
    required this.requesterId,
    required this.requesterName,
    required this.requesterGender,
    required this.campus,
    required this.otherLocation,
    required this.direction,
    required this.genderPreference,
    required this.neededDatetime,
    required this.status,
    required this.createdAt,
  });

  String get directionLabel =>
      direction == 'campus_to_other' ? 'Campus → Other' : 'Other → Campus';

  factory RideRequest.fromJson(Map<String, dynamic> json) {
    return RideRequest(
      id: json['_id'],
      requesterId: json['requester_id'],
      requesterName: json['requester_name'] ?? 'Unknown',
      requesterGender: json['requester_gender'] ?? 'Other',
      campus: json['campus'],
      otherLocation: json['other_location'],
      direction: json['direction'],
      genderPreference: json['gender_preference'] ?? 'mix',
      neededDatetime: _parseServerDateTime(json['needed_datetime']),
      status: json['status'],
      createdAt: _parseServerDateTime(json['created_at']),
    );
  }
}
