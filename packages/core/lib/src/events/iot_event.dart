import 'package:fpdart/fpdart.dart';

/// Base class for IoT device events
class IoTEvent {
  final String id;
  final DateTime timestamp;
  final Map<String, dynamic> data;

  IoTEvent({
    required this.id,
    required this.timestamp,
    required this.data,
  });

  /// Creates an IoT event from JSON
  static Either<String, IoTEvent> fromJson(Map<String, dynamic> json) {
    try {
      return Right(IoTEvent(
        id: json['id'] as String,
        timestamp: DateTime.parse(json['timestamp'] as String),
        data: json['data'] as Map<String, dynamic>,
      ));
    } catch (e) {
      return Left('Failed to parse IoT event: $e');
    }
  }

  /// Converts event to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'timestamp': timestamp.toIso8601String(),
      'data': data,
    };
  }
}
