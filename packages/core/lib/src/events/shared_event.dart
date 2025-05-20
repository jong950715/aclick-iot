import 'package:fpdart/fpdart.dart';

/// Base class for shared events between IoT and Phone applications
class SharedEvent {
  final String id;
  final DateTime timestamp;
  final String eventType;
  final Map<String, dynamic> payload;

  SharedEvent({
    required this.id,
    required this.timestamp,
    required this.eventType,
    required this.payload,
  });

  /// Creates a shared event from JSON
  static Either<String, SharedEvent> fromJson(Map<String, dynamic> json) {
    try {
      return Right(SharedEvent(
        id: json['id'] as String,
        timestamp: DateTime.parse(json['timestamp'] as String),
        eventType: json['event_type'] as String,
        payload: json['payload'] as Map<String, dynamic>,
      ));
    } catch (e) {
      return Left('Failed to parse shared event: $e');
    }
  }

  /// Converts event to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'timestamp': timestamp.toIso8601String(),
      'event_type': eventType,
      'payload': payload,
    };
  }
}
