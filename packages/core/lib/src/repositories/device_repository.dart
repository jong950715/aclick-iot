import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpdart/fpdart.dart';
import '../network/api_service.dart';
import '../di/service_locator.dart';

/// Device information model
class DeviceInfo {
  final String id;
  final String name;
  final String model;
  final String firmwareVersion;
  final bool isOnline;

  const DeviceInfo({
    required this.id,
    required this.name,
    required this.model,
    required this.firmwareVersion,
    required this.isOnline,
  });

  /// Create from JSON
  factory DeviceInfo.fromJson(Map<String, dynamic> json) {
    return DeviceInfo(
      id: json['id'] as String,
      name: json['name'] as String,
      model: json['model'] as String,
      firmwareVersion: json['firmware_version'] as String,
      isOnline: json['is_online'] as bool,
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'model': model,
      'firmware_version': firmwareVersion,
      'is_online': isOnline,
    };
  }
}

/// Repository for device management
class DeviceRepository {
  final ApiService _apiService;

  /// Constructor with dependency injection
  DeviceRepository({required ApiService apiService}) : _apiService = apiService;

  /// Get list of registered devices
  Future<Either<String, List<DeviceInfo>>> getDevices() async {
    try {
      final result = await _apiService.get(endpoint: 'devices');
      
      if (result.isLeft()) {
        return Left(result.getLeft().getOrElse(() => 'Failed to get devices'));
      }
      
      final devicesJson = result.getRight().getOrElse(() => {})['devices'] as List<dynamic>;
      final devices = devicesJson
          .map((json) => DeviceInfo.fromJson(json as Map<String, dynamic>))
          .toList();
      
      return Right(devices);
    } catch (e) {
      return Left('Failed to get devices: $e');
    }
  }

  /// Get device details by ID
  Future<Either<String, DeviceInfo>> getDeviceById(String deviceId) async {
    try {
      final result = await _apiService.get(endpoint: 'devices/$deviceId');
      
      if (result.isLeft()) {
        return Left(result.getLeft().getOrElse(() => 'Failed to get device'));
      }
      
      final deviceJson = result.getRight().getOrElse(() => {});
      final device = DeviceInfo.fromJson(deviceJson);
      
      return Right(device);
    } catch (e) {
      return Left('Failed to get device: $e');
    }
  }

  /// Register a new device
  Future<Either<String, DeviceInfo>> registerDevice(DeviceInfo device) async {
    try {
      final result = await _apiService.post(
        endpoint: 'devices',
        data: device.toJson(),
      );
      
      if (result.isLeft()) {
        return Left(result.getLeft().getOrElse(() => 'Failed to register device'));
      }
      
      final deviceJson = result.getRight().getOrElse(() => {});
      final registeredDevice = DeviceInfo.fromJson(deviceJson);
      
      return Right(registeredDevice);
    } catch (e) {
      return Left('Failed to register device: $e');
    }
  }

  /// Update device information
  Future<Either<String, DeviceInfo>> updateDevice(DeviceInfo device) async {
    try {
      final result = await _apiService.put(
        endpoint: 'devices/${device.id}',
        data: device.toJson(),
      );
      
      if (result.isLeft()) {
        return Left(result.getLeft().getOrElse(() => 'Failed to update device'));
      }
      
      final deviceJson = result.getRight().getOrElse(() => {});
      final updatedDevice = DeviceInfo.fromJson(deviceJson);
      
      return Right(updatedDevice);
    } catch (e) {
      return Left('Failed to update device: $e');
    }
  }

  /// Remove a device
  Future<Either<String, bool>> removeDevice(String deviceId) async {
    try {
      final result = await _apiService.delete(endpoint: 'devices/$deviceId');
      
      if (result.isLeft()) {
        return Left(result.getLeft().getOrElse(() => 'Failed to remove device'));
      }
      
      return const Right(true);
    } catch (e) {
      return Left('Failed to remove device: $e');
    }
  }
}

/// Provider for device repository
final deviceRepositoryProvider = Provider<DeviceRepository>((ref) {
  final apiService = ref.watch(apiServiceProvider);
  return DeviceRepository(apiService: apiService);
});
