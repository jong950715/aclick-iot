import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../network/api_service.dart';
import '../encryption/encryptor.dart';
import 'service_locator.dart';

/// Provider scope configuration for feature-specific dependencies
///
/// This file defines scope-based providers that can be overridden
/// for different features or in testing scenarios

/// Standard scope override configuration
class StandardScopeOverrides extends ProviderScope {
  /// Creates a standard scope with the specified overrides
  StandardScopeOverrides({
    super.key,
    required super.child,
    List<Override> additionalOverrides = const [],
  }) : super(
          overrides: [
            ...additionalOverrides,
          ],
        );
}

/// Feature-specific scope for IoT device configuration
class IoTDeviceScope extends ProviderScope {
  /// Creates a scope with IoT device-specific overrides
  IoTDeviceScope({
    super.key,
    required super.child,
    required String deviceApiUrl,
    required String deviceId,
    List<Override> additionalOverrides = const [],
  }) : super(
          overrides: [
            // Override API service to use device-specific URL
            apiServiceProvider.overrideWith((ref) => ApiService(
                  baseUrl: deviceApiUrl,
                  defaultHeaders: {'Device-ID': deviceId},
                )),
            ...additionalOverrides,
          ],
        );
}

/// Feature-specific scope for secure communications
class SecureScope extends ProviderScope {
  /// Creates a scope with security-specific overrides
  SecureScope({
    super.key,
    required super.child,
    List<Override> additionalOverrides = const [],
  }) : super(
          overrides: [
            // Override encryption to use stronger settings
            encryptorProvider.overrideWith((ref) => Encryptor()),
            ...additionalOverrides,
          ],
        );
}

/// Provider for feature flags
final featureFlagsProvider = Provider<Map<String, bool>>((ref) {
  // Default feature flags
  return {
    'enableAnalytics': true,
    'enableCloudSync': true,
    'enableDevMode': false,
    'enableBetaFeatures': false,
  };
});

/// Feature flag provider that can be scoped per environment
final isFeatureEnabledProvider = Provider.family<bool, String>((ref, featureKey) {
  final featureFlags = ref.watch(featureFlagsProvider);
  return featureFlags[featureKey] ?? false;
});
