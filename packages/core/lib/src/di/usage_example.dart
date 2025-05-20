import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/device_repository.dart';
import 'package:fpdart/fpdart.dart';
import '../repositories/telemetry_repository.dart';
import 'di.dart';

/// 의존성 주입 시스템 사용 예제입니다.
/// 이 파일은 실제 앱에서 사용되지는 않으며, 참고용으로만 제공됩니다.

/// 디바이스 상태 모니터링 화면의 예시
class DeviceMonitoringScreen extends ConsumerWidget {
  final String deviceId;
  
  const DeviceMonitoringScreen({
    Key? key,
    required this.deviceId,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 의존성 주입을 통해 리포지토리 접근
    final deviceRepository = ref.watch(deviceRepositoryProvider);
    final telemetryRepository = ref.watch(telemetryRepositoryProvider);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('디바이스 모니터링'),
      ),
      body: Column(
        children: [
          // 디바이스 정보 표시
          FutureBuilder<Either<String, DeviceInfo>>(
            future: deviceRepository.getDeviceById(deviceId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              
              if (!snapshot.hasData || snapshot.data == null) {
                return const Center(child: Text('디바이스 정보를 불러올 수 없습니다.'));
              }
              
              return snapshot.data!.match(
                (error) => Center(child: Text('오류: $error')),
                (device) => _buildDeviceInfo(device),
              );
            },
          ),
          
          // 원격 측정 데이터 스트림 표시
          Expanded(
            child: StreamBuilder<Either<String, TelemetryData>>(
              stream: telemetryRepository.subscribeTelemetry(deviceId),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: Text('텔레메트리 데이터를 기다리는 중...'));
                }
                
                return snapshot.data!.match(
                  (error) => Center(child: Text('오류: $error')),
                  (telemetry) => _buildTelemetryView(telemetry),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildDeviceInfo(DeviceInfo device) {
    return Card(
      margin: const EdgeInsets.all(16.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('디바이스: ${device.name}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('모델: ${device.model}'),
            Text('펌웨어: ${device.firmwareVersion}'),
            Text('상태: ${device.isOnline ? "온라인" : "오프라인"}'),
          ],
        ),
      ),
    );
  }
  
  Widget _buildTelemetryView(TelemetryData telemetry) {
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '텔레메트리 데이터 (${telemetry.timestamp.toString()})',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                ...telemetry.metrics.entries.map((entry) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(entry.key),
                        Text(entry.value.toString()),
                      ],
                    ),
                  );
                }).toList(),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// 의존성 주입을 활용한 앱 구조의 예시
void exampleUsage() {
  runApp(
    // 전체 앱에 IoT 디바이스 스코프 적용
    IoTDeviceScope(
      deviceApiUrl: 'https://api.example.com/iot',
      deviceId: 'device-123',
      additionalOverrides: [
        // 추가적인 오버라이드 설정
        featureFlagsProvider.overrideWithValue({
          'enableAnalytics': true,
          'enableCloudSync': false,
        }),
      ],
      child: MaterialApp(
        home: Builder(
          builder: (context) {
            // 특정 기능에 보안 스코프 적용
            return SecureScope(
              child: DeviceMonitoringScreen(deviceId: 'device-123'),
            );
          },
        ),
      ),
    ),
  );
}

/// 테스트에서의 사용 예시
void exampleTestUsage() {
  // 테스트 환경에서의 의존성 설정
  final testContainer = createTestContainer();
  
  // 리포지토리 접근
  final deviceRepo = testContainer.read(deviceRepositoryProvider);
  
  // MockAPI 설정
  final mockApiService = testContainer.read(apiServiceProvider);
  
  // 테스트 코드...
  // when(mockApiService.get(...)).thenAnswer(...);
  // final result = await deviceRepo.getDevices();
  // expect(result.isRight(), true);
}
