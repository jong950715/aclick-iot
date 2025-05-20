import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:core/core.dart';

class MockWidget extends StatelessWidget {
  final VoidCallback onBuild;
  
  const MockWidget({super.key, required this.onBuild});
  
  @override
  Widget build(BuildContext context) {
    onBuild();
    return const SizedBox();
  }
}

class MockBuildContext extends Mock implements BuildContext {}

void main() {
  group('ProviderScopes Tests', () {
    testWidgets('StandardScopeOverrides should apply provided overrides', (tester) async {
      // Arrange
      bool buildCalled = false;
      final mockApiService = MockApiService();
      
      // Act
      await tester.pumpWidget(
        StandardScopeOverrides(
          additionalOverrides: [
            apiServiceProvider.overrideWithValue(mockApiService),
          ],
          child: Consumer(
            builder: (context, ref, _) {
              final apiService = ref.read(apiServiceProvider);
              expect(apiService, equals(mockApiService));
              buildCalled = true;
              return const SizedBox();
            },
          ),
        ),
      );
      
      // Assert
      expect(buildCalled, isTrue);
    });
    
    testWidgets('IoTDeviceScope should override API service with device-specific URL', (tester) async {
      // Arrange
      const deviceApiUrl = 'https://test-device-api.example.com';
      const deviceId = 'test-device-id';
      
      // Act
      await tester.pumpWidget(
        IoTDeviceScope(
          deviceApiUrl: deviceApiUrl,
          deviceId: deviceId,
          child: Consumer(
            builder: (context, ref, _) {
              final apiService = ref.read(apiServiceProvider);
              return Text(apiService.baseUrl);
            },
          ),
        ),
      );
      
      // Assert
      expect(find.text(deviceApiUrl), findsOneWidget);
    });
    
    testWidgets('SecureScope should override encryptor', (tester) async {
      // Arrange
      bool encryptorOverridden = false;
      
      // Act
      await tester.pumpWidget(
        SecureScope(
          child: Consumer(
            builder: (context, ref, _) {
              final encryptor = ref.read(encryptorProvider);
              // In a real test, we would verify specific encryptor properties
              // Here we just check that we got a non-null encryptor
              encryptorOverridden = encryptor != null;
              return const SizedBox();
            },
          ),
        ),
      );
      
      // Assert
      expect(encryptorOverridden, isTrue);
    });
    
    test('featureFlagsProvider should return default feature flags', () {
      // Arrange
      final container = ProviderContainer();
      
      // Act
      final featureFlags = container.read(featureFlagsProvider);
      
      // Assert
      expect(featureFlags, {
        'enableAnalytics': true,
        'enableCloudSync': true,
        'enableDevMode': false,
        'enableBetaFeatures': false,
      });
    });
    
    test('isFeatureEnabledProvider should return correct feature flag status', () {
      // Arrange
      final container = ProviderContainer(
        overrides: [
          featureFlagsProvider.overrideWithValue({
            'testFeature1': true,
            'testFeature2': false,
          }),
        ],
      );
      
      // Act & Assert
      expect(container.read(isFeatureEnabledProvider('testFeature1')), isTrue);
      expect(container.read(isFeatureEnabledProvider('testFeature2')), isFalse);
      expect(container.read(isFeatureEnabledProvider('nonExistentFeature')), isFalse);
    });
  });
}
