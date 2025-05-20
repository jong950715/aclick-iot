import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpdart/fpdart.dart';
import '../network/protocol_client.dart';
import '../di/service_locator.dart';

/// Telemetry data model
class TelemetryData {
  final String deviceId;
  final DateTime timestamp;
  final Map<String, dynamic> metrics;
  final String type;

  const TelemetryData({
    required this.deviceId,
    required this.timestamp,
    required this.metrics,
    required this.type,
  });

  /// Create from JSON
  factory TelemetryData.fromJson(Map<String, dynamic> json) {
    return TelemetryData(
      deviceId: json['device_id'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      metrics: json['metrics'] as Map<String, dynamic>,
      type: json['type'] as String,
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'device_id': deviceId,
      'timestamp': timestamp.toIso8601String(),
      'metrics': metrics,
      'type': type,
    };
  }
}

/// Repository for telemetry data
class TelemetryRepository {
  final ProtocolClient _protocolClient;

  /// Constructor with dependency injection
  TelemetryRepository({required ProtocolClient protocolClient}) 
      : _protocolClient = protocolClient;

  /// Send telemetry data to the server
  Future<Either<String, bool>> sendTelemetry(TelemetryData data) async {
    try {
      final result = await _protocolClient.send(
        path: 'telemetry',
        data: data.toJson(),
      );
      
      return result.match(
        (error) => Left(error),
        (_) => const Right(true),
      );
    } catch (e) {
      return Left('Failed to send telemetry: $e');
    }
  }

  /// Get historical telemetry data for a device
  Future<Either<String, List<TelemetryData>>> getHistory(
    String deviceId, {
    DateTime? from,
    DateTime? to,
    String? type,
  }) async {
    try {
      // Build query parameters
      final queryParams = <String, String>{};
      
      if (from != null) {
        queryParams['from'] = from.toIso8601String();
      }
      
      if (to != null) {
        queryParams['to'] = to.toIso8601String();
      }
      
      if (type != null) {
        queryParams['type'] = type;
      }
      
      final result = await _protocolClient.fetch(
        path: 'telemetry/$deviceId/history',
        queryParams: queryParams,
      );
      
      return result.match(
        (error) => Left(error),
        (data) {
          final telemetryList = (data['telemetry'] as List<dynamic>)
              .map((item) => TelemetryData.fromJson(item as Map<String, dynamic>))
              .toList();
          return Right(telemetryList);
        },
      );
    } catch (e) {
      return Left('Failed to get telemetry history: $e');
    }
  }

  /// Subscribe to real-time telemetry updates
  Stream<Either<String, TelemetryData>> subscribeTelemetry(String deviceId) {
    return _protocolClient.subscribe('telemetry/$deviceId/stream').map(
      (result) => result.match(
        (error) => Left(error),
        (data) => Right(TelemetryData.fromJson(data)),
      ),
    );
  }

  /// Get the latest telemetry data for a device
  Future<Either<String, TelemetryData>> getLatestTelemetry(
    String deviceId, {
    String? type,
  }) async {
    try {
      // Build query parameters
      final queryParams = <String, String>{};
      
      if (type != null) {
        queryParams['type'] = type;
      }
      
      final result = await _protocolClient.fetch(
        path: 'telemetry/$deviceId/latest',
        queryParams: queryParams,
      );
      
      return result.match(
        (error) => Left(error),
        (data) => Right(TelemetryData.fromJson(data)),
      );
    } catch (e) {
      return Left('Failed to get latest telemetry: $e');
    }
  }
}

/// Provider for telemetry repository
final telemetryRepositoryProvider = Provider<TelemetryRepository>((ref) {
  final protocolClient = ref.watch(protocolClientProvider);
  return TelemetryRepository(protocolClient: protocolClient);
});
