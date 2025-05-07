class Device {
  final String id;
  final String name;
  final String? sensorId;
  final String? assignedUserId;
  final bool isActive;
  final String mode;
  final DeviceStatus? status;
  final int? speedPercentage;
  final int? timerMinutes;
  final int?
      nodeRole; // 1: Coordinator (IR Sensor), 2: Weight Sensor, 3: Touch Sensor

  Device({
    required this.id,
    required this.name,
    this.sensorId,
    this.assignedUserId,
    required this.isActive,
    required this.mode,
    this.status,
    this.speedPercentage,
    this.timerMinutes,
    this.nodeRole,
  });

  Device copyWith({
    String? id,
    String? name,
    String? sensorId,
    String? assignedUserId,
    bool? isActive,
    String? mode,
    DeviceStatus? status,
    int? speedPercentage,
    int? timerMinutes,
    int? nodeRole,
  }) {
    return Device(
      id: id ?? this.id,
      name: name ?? this.name,
      sensorId: sensorId ?? this.sensorId,
      assignedUserId: assignedUserId ?? this.assignedUserId,
      isActive: isActive ?? this.isActive,
      mode: mode ?? this.mode,
      status: status ?? this.status,
      speedPercentage: speedPercentage ?? this.speedPercentage,
      timerMinutes: timerMinutes ?? this.timerMinutes,
      nodeRole: nodeRole ?? this.nodeRole,
    );
  }

  factory Device.fromJson(Map<String, dynamic> json) => Device.fromMap(json);

  factory Device.fromMap(Map<String, dynamic> map) {
    return Device(
      id: map['id'],
      name: map['name'] ?? '',
      sensorId: map['sensor_id'],
      assignedUserId: map['user_id'],
      isActive: map['is_active'] ?? false,
      mode: map['mode'] ?? 'auto',
      status:
          map['status'] != null ? DeviceStatus.fromMap(map['status']) : null,
      speedPercentage: map['speed_percentage']?.toInt(),
      timerMinutes: map['timer_minutes']?.toInt(),
      nodeRole: map['node_role']?.toInt(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'sensor_id': sensorId,
      'user_id': assignedUserId,
      'is_active': isActive,
      'mode': mode,
      'speed_percentage': speedPercentage,
      'timer_minutes': timerMinutes,
      'node_role': nodeRole,
    };
  }
}

class DeviceStatus {
  final bool motorOn;
  final DateTime updatedAt;

  DeviceStatus({
    required this.motorOn,
    required this.updatedAt,
  });

  factory DeviceStatus.fromMap(Map<String, dynamic> map) {
    return DeviceStatus(
      motorOn: map['motor_on'] ?? false,
      updatedAt: map['updated_at'] != null
          ? DateTime.parse(map['updated_at'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'motor_on': motorOn,
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}

class DeviceLog {
  final String id;
  final String deviceId;
  final String? userId;
  final String action;
  final DateTime timestamp;

  DeviceLog({
    required this.id,
    required this.deviceId,
    this.userId,
    required this.action,
    required this.timestamp,
  });

  factory DeviceLog.fromMap(Map<String, dynamic> map) {
    return DeviceLog(
      id: map['id'],
      deviceId: map['device_id'] ?? '',
      userId: map['user_id'],
      action: map['action'] ?? '',
      timestamp: map['created_at'] != null
          ? DateTime.parse(map['created_at'])
          : DateTime.now(),
    );
  }
}
