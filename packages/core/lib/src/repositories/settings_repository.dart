import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpdart/fpdart.dart';
import '../di/service_locator.dart';

/// Settings model
class AppSettings {
  final bool isDarkMode;
  final bool notificationsEnabled;
  final int refreshIntervalSeconds;
  final bool autoConnectEnabled;
  final Map<String, dynamic> additionalSettings;

  const AppSettings({
    this.isDarkMode = false,
    this.notificationsEnabled = true,
    this.refreshIntervalSeconds = 30,
    this.autoConnectEnabled = true,
    this.additionalSettings = const {},
  });

  /// Create from JSON
  factory AppSettings.fromJson(Map<String, dynamic> json) {
    return AppSettings(
      isDarkMode: json['is_dark_mode'] as bool? ?? false,
      notificationsEnabled: json['notifications_enabled'] as bool? ?? true,
      refreshIntervalSeconds: json['refresh_interval_seconds'] as int? ?? 30,
      autoConnectEnabled: json['auto_connect_enabled'] as bool? ?? true,
      additionalSettings: json['additional_settings'] as Map<String, dynamic>? ?? {},
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'is_dark_mode': isDarkMode,
      'notifications_enabled': notificationsEnabled,
      'refresh_interval_seconds': refreshIntervalSeconds,
      'auto_connect_enabled': autoConnectEnabled,
      'additional_settings': additionalSettings,
    };
  }

  /// Create a copy with updated fields
  AppSettings copyWith({
    bool? isDarkMode,
    bool? notificationsEnabled,
    int? refreshIntervalSeconds,
    bool? autoConnectEnabled,
    Map<String, dynamic>? additionalSettings,
  }) {
    return AppSettings(
      isDarkMode: isDarkMode ?? this.isDarkMode,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      refreshIntervalSeconds: refreshIntervalSeconds ?? this.refreshIntervalSeconds,
      autoConnectEnabled: autoConnectEnabled ?? this.autoConnectEnabled,
      additionalSettings: additionalSettings ?? this.additionalSettings,
    );
  }
}

/// Interface for settings storage
abstract class SettingsStorage {
  Future<Either<String, AppSettings>> loadSettings();
  Future<Either<String, bool>> saveSettings(AppSettings settings);
}

/// Implementation of settings storage using local storage
class LocalSettingsStorage implements SettingsStorage {
  final String _storageKey = 'app_settings';
  
  // This would use shared_preferences in a real implementation
  Map<String, String>? _mockStorage;
  
  LocalSettingsStorage() {
    _mockStorage = {};
  }
  
  @override
  Future<Either<String, AppSettings>> loadSettings() async {
    try {
      // In a real implementation, this would use shared_preferences
      final jsonString = _mockStorage?[_storageKey];
      
      if (jsonString == null) {
        // Return default settings if none exist
        return Right(const AppSettings());
      }
      
      final json = jsonDecode(jsonString) as Map<String, dynamic>;
      return Right(AppSettings.fromJson(json));
    } catch (e) {
      return Left('Failed to load settings: $e');
    }
  }
  
  @override
  Future<Either<String, bool>> saveSettings(AppSettings settings) async {
    try {
      // In a real implementation, this would use shared_preferences
      final jsonString = jsonEncode(settings.toJson());
      _mockStorage?[_storageKey] = jsonString;
      
      return const Right(true);
    } catch (e) {
      return Left('Failed to save settings: $e');
    }
  }
}

/// Repository for app settings
class SettingsRepository {
  final SettingsStorage _storage;
  
  /// Constructor with dependency injection
  SettingsRepository({required SettingsStorage storage}) : _storage = storage;
  
  /// Load settings from storage
  Future<Either<String, AppSettings>> loadSettings() {
    return _storage.loadSettings();
  }
  
  /// Save settings to storage
  Future<Either<String, bool>> saveSettings(AppSettings settings) {
    return _storage.saveSettings(settings);
  }
  
  /// Update a specific setting
  Future<Either<String, AppSettings>> updateSetting<T>({
    required String key, 
    required T value,
  }) async {
    final settingsResult = await loadSettings();
    
    if (settingsResult.isLeft()) {
      return Left(settingsResult.getLeft().getOrElse(() => 'Failed to load settings'));
    }
    
    final currentSettings = settingsResult.getRight().getOrElse(() => const AppSettings());
    
    // Update the correct setting based on the key
    AppSettings updatedSettings;
    
    switch (key) {
      case 'isDarkMode':
        updatedSettings = currentSettings.copyWith(isDarkMode: value as bool);
        break;
      case 'notificationsEnabled':
        updatedSettings = currentSettings.copyWith(notificationsEnabled: value as bool);
        break;
      case 'refreshIntervalSeconds':
        updatedSettings = currentSettings.copyWith(refreshIntervalSeconds: value as int);
        break;
      case 'autoConnectEnabled':
        updatedSettings = currentSettings.copyWith(autoConnectEnabled: value as bool);
        break;
      default:
        // For custom settings, update the additionalSettings map
        final newAdditionalSettings = Map<String, dynamic>.from(currentSettings.additionalSettings);
        newAdditionalSettings[key] = value;
        updatedSettings = currentSettings.copyWith(additionalSettings: newAdditionalSettings);
    }
    
    // Save the updated settings
    final saveResult = await saveSettings(updatedSettings);
    
    if (saveResult.isLeft()) {
      return Left(saveResult.getLeft().getOrElse(() => 'Failed to save settings'));
    }
    
    return Right(updatedSettings);
  }
  
  /// Reset settings to defaults
  Future<Either<String, AppSettings>> resetToDefaults() {
    return saveSettings(const AppSettings()).then(
      (result) => result.isRight() 
          ? const Right(AppSettings()) 
          : Left(result.getLeft().getOrElse(() => 'Failed to reset settings')),
    );
  }
}

/// Provider for settings storage
final settingsStorageProvider = Provider<SettingsStorage>((ref) {
  return LocalSettingsStorage();
});

/// Provider for settings repository
final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  final storage = ref.watch(settingsStorageProvider);
  return SettingsRepository(storage: storage);
});
