import 'package:fpdart/fpdart.dart';

/// Base class for Phone application events
class PhoneEvent {
  final String id;
  final DateTime timestamp;
  final Map<String, dynamic> data;

  PhoneEvent({
    required this.id,
    required this.timestamp,
    required this.data,
  });

  /// Creates a Phone event from JSON
  static Either<String, PhoneEvent> fromJson(Map<String, dynamic> json) {
    try {
      return Right(PhoneEvent(
        id: json['id'] as String,
        timestamp: DateTime.parse(json['timestamp'] as String),
        data: json['data'] as Map<String, dynamic>,
      ));
    } catch (e) {
      return Left('Failed to parse Phone event: $e');
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
