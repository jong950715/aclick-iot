# 테스트 가이드

이 문서는 A-Click IoT 프로젝트의 테스트 전략, 모범 사례, 그리고 테스트 작성 방법에 대해 설명합니다.

## 테스트 철학

A-Click IoT 프로젝트는 다음과 같은 테스트 철학을 따릅니다:

1. **테스트 우선**: 가능한 테스트 주도 개발(TDD) 접근 방식을 채택합니다.
2. **적절한 테스트 범위**: 중요 기능은 높은 테스트 커버리지를 유지합니다.
3. **테스트 피라미드**: 유닛 테스트(많음) → 통합 테스트 → 위젯 테스트 → E2E 테스트(적음) 형태의 테스트 피라미드를 따릅니다.
4. **테스트 독립성**: 각 테스트는 다른 테스트에 의존하지 않고 독립적으로 실행될 수 있어야 합니다.
5. **가독성**: 테스트는 명확하고 이해하기 쉽게 작성되어야 합니다.

## 테스트 유형

### 유닛 테스트

개별 클래스, 메서드, 함수의 기능을 검증합니다.

#### 대상:

- 비즈니스 로직 (Controllers)
- 유틸리티 함수
- 리포지토리
- 모델 클래스
- 상태 관리 로직

#### 예시:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:fpdart/fpdart.dart';
import 'package:core/core.dart';

class MockApiService extends Mock implements ApiService {}

void main() {
  late DeviceRepository repository;
  late MockApiService mockApiService;

  setUp(() {
    mockApiService = MockApiService();
    repository = DeviceRepository(apiService: mockApiService);
  });

  group('DeviceRepository', () {
    test('getDeviceById should return DeviceInfo when successful', () async {
      // Arrange
      const deviceId = 'device-123';
      final deviceData = {
        'id': deviceId,
        'name': 'Living Room Sensor',
        'is_online': true,
      };
      
      when(mockApiService.get(endpoint: 'devices/$deviceId'))
          .thenAnswer((_) async => Right(deviceData));

      // Act
      final result = await repository.getDeviceById(deviceId);

      // Assert
      expect(result.isRight(), true);
      result.match(
        (error) => fail('Should not return error'),
        (device) {
          expect(device.id, deviceId);
          expect(device.name, 'Living Room Sensor');
          expect(device.isOnline, true);
        },
      );
      
      verify(mockApiService.get(endpoint: 'devices/$deviceId')).called(1);
    });

    test('getDeviceById should return error when API call fails', () async {
      // Arrange
      const deviceId = 'device-123';
      const errorMessage = 'Network error';
      
      when(mockApiService.get(endpoint: 'devices/$deviceId'))
          .thenAnswer((_) async => const Left(errorMessage));

      // Act
      final result = await repository.getDeviceById(deviceId);

      // Assert
      expect(result.isLeft(), true);
      result.match(
        (error) => expect(error, contains(errorMessage)),
        (device) => fail('Should not return device'),
      );
      
      verify(mockApiService.get(endpoint: 'devices/$deviceId')).called(1);
    });
  });
}
```

### 위젯 테스트

개별 위젯 또는 위젯 트리의 동작을 검증합니다.

#### 대상:

- 개별 위젯
- 화면 컴포넌트
- 위젯 상호작용

#### 예시:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mockito/mockito.dart';
import 'package:core/core.dart';

void main() {
  testWidgets('DeviceCard should display device information correctly',
      (WidgetTester tester) async {
    // Arrange
    final deviceInfo = DeviceInfo(
      id: 'device-123',
      name: 'Living Room Sensor',
      isOnline: true,
    );

    // Build our widget
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DeviceCard(device: deviceInfo),
        ),
      ),
    );

    // Assert
    expect(find.text('Living Room Sensor'), findsOneWidget);
    expect(find.text('Online'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle), findsOneWidget);
  });

  testWidgets('DeviceCard should show offline status when device is offline',
      (WidgetTester tester) async {
    // Arrange
    final deviceInfo = DeviceInfo(
      id: 'device-123',
      name: 'Living Room Sensor',
      isOnline: false,
    );

    // Build our widget
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DeviceCard(device: deviceInfo),
        ),
      ),
    );

    // Assert
    expect(find.text('Offline'), findsOneWidget);
    expect(find.byIcon(Icons.error_outline), findsOneWidget);
  });
}
```

### 통합 테스트

여러 컴포넌트 간의 상호작용을 검증합니다.

#### 대상:

- 리포지토리와 데이터 소스 간 통합
- Provider 간 상호작용
- 전체 기능 흐름

#### 예시:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mockito/mockito.dart';
import 'package:core/core.dart';

class MockDeviceRepository extends Mock implements DeviceRepository {}

void main() {
  late ProviderContainer container;
  late MockDeviceRepository mockRepository;

  setUp(() {
    mockRepository = MockDeviceRepository();
    
    container = ProviderContainer(
      overrides: [
        deviceRepositoryProvider.overrideWithValue(mockRepository),
      ],
    );
  });

  tearDown(() {
    container.dispose();
  });

  group('Device feature integration', () {
    test('DeviceController should properly fetch and transform device data', () async {
      // Arrange
      const deviceId = 'device-123';
      final deviceData = DeviceInfo(
        id: deviceId,
        name: 'Test Device',
        isOnline: true,
      );
      
      when(mockRepository.getDeviceById(deviceId))
          .thenAnswer((_) async => Right(deviceData));

      // Act
      final controller = container.read(deviceControllerProvider);
      final result = await controller.getDeviceDetails(deviceId);

      // Assert
      expect(result.isRight(), true);
      result.match(
        (error) => fail('Should not return error'),
        (device) {
          expect(device.id, deviceId);
          expect(device.name, 'Test Device');
          expect(device.isOnline, true);
        },
      );
      
      verify(mockRepository.getDeviceById(deviceId)).called(1);
    });
  });
}
```

### E2E (종단 간) 테스트

사용자 관점에서 전체 애플리케이션 흐름을 검증합니다.

#### 대상:

- 전체 사용자 여정
- 앱 성능
- 시스템 통합

#### 예시:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:iot_app/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('E2E Tests', () {
    testWidgets('Device Connection Flow', (WidgetTester tester) async {
      // Start the app
      app.main();
      await tester.pumpAndSettle();

      // Navigate to device list
      await tester.tap(find.text('Devices'));
      await tester.pumpAndSettle();

      // Find and tap on a device
      await tester.tap(find.text('Living Room Sensor'));
      await tester.pumpAndSettle();

      // Verify device details screen
      expect(find.text('Device Details'), findsOneWidget);
      expect(find.text('Living Room Sensor'), findsOneWidget);

      // Connect to device
      await tester.tap(find.text('Connect'));
      await tester.pumpAndSettle();

      // Verify connection status
      expect(find.text('Connected'), findsOneWidget);

      // Check sensor data appears
      await tester.pump(const Duration(seconds: 5));
      expect(find.textContaining('Temperature:'), findsOneWidget);
    });
  });
}
```

## 테스트 도구

### 핵심 테스트 패키지

- **flutter_test**: Flutter 위젯 및 통합 테스트를 위한 기본 패키지
- **mockito**: 목(mock) 객체 생성
- **integration_test**: E2E 테스트 지원

### 모의 객체(Mocking)

목(mock) 객체를 사용하여 외부 의존성을 시뮬레이션합니다:

```dart
// Mock 클래스 정의
class MockApiService extends Mock implements ApiService {}

// Mock 사용
final mockApiService = MockApiService();
when(mockApiService.get(endpoint: 'devices'))
    .thenAnswer((_) async => Right({'devices': []}));

// 호출 검증
verify(mockApiService.get(endpoint: 'devices')).called(1);
```

### 상태 테스트

Riverpod 상태 테스트를 위한 패턴:

```dart
// Provider Container 생성
final container = ProviderContainer(
  overrides: [
    apiServiceProvider.overrideWithValue(mockApiService),
  ],
);

// 상태 접근 및 테스트
final deviceState = container.read(deviceStateProvider('device-123'));
expect(deviceState.isConnected, false);

// 상태 변경 로직 테스트
final controller = container.read(deviceControllerProvider);
await controller.connectDevice('device-123');

// 상태 변화 검증
final updatedState = container.read(deviceStateProvider('device-123'));
expect(updatedState.isConnected, true);
```

## 테스트 모범 사례

### 유닛 테스트 모범 사례

1. **단일 책임**: 각 테스트는 하나의 동작만 검증합니다.
2. **명명 규칙**: 테스트 이름은 "should do something when something" 형식을 따릅니다.
3. **AAA 패턴**: Arrange(준비), Act(실행), Assert(검증) 패턴으로 테스트를 구성합니다.
4. **의존성 주입**: 의존성을 주입하여 테스트하기 쉬운 코드를 작성합니다.

### 위젯 테스트 모범 사례

1. **최소한의 위젯 트리**: 필요한 위젯만 포함하여 테스트합니다.
2. **사용자 상호작용 시뮬레이션**: tap, drag 등의 메서드를 사용합니다.
3. **비동기 작업 처리**: `pumpAndSettle`을 사용하여 애니메이션 완료를 기다립니다.
4. **Provider 오버라이드**: 테스트에 필요한 Provider만 오버라이드합니다.

## CI/CD 테스트

CI/CD 파이프라인에서 테스트 실행:

```yaml
# .github/workflows/test.yml 예시
name: Test

on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]

jobs:
  test:
    name: Flutter Tests
    runs-on: ubuntu-latest
    
    steps:
      - uses: actions/checkout@v3
      
      - name: Setup Flutter
        uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.29.3'
          channel: 'stable'
          cache: true
      
      - name: Install dependencies
        run: flutter pub get
      
      - name: Verify formatting
        run: dart format --output=none --set-exit-if-changed .
      
      - name: Analyze project source
        run: flutter analyze
      
      - name: Run tests
        run: flutter test --coverage
      
      - name: Upload coverage to Codecov
        uses: codecov/codecov-action@v3
        with:
          token: ${{ secrets.CODECOV_TOKEN || '' }}
          file: ./coverage/lcov.info
          flags: unittests
          fail_ci_if_error: false
```

## 테스트 커버리지

테스트 커버리지를 측정하고 목표를 설정합니다:

```bash
# 커버리지 측정
flutter test --coverage

# 커버리지 보고서 생성 (lcov 필요)
genhtml coverage/lcov.info -o coverage/html

# 커버리지 보고서 열기
open coverage/html/index.html
```

### 커버리지 목표

- **비즈니스 로직**: 90% 이상
- **데이터 계층**: 85% 이상
- **UI 컴포넌트**: 75% 이상

## 테스트 경험 개선

### 테스트 도우미(Test Helpers)

반복되는 테스트 로직을 도우미 함수로 추출합니다:

```dart
// 테스트 도우미 예시
Widget createWidgetUnderTest({
  required DeviceInfo deviceInfo,
  bool isLoading = false,
}) {
  return MaterialApp(
    home: ProviderScope(
      overrides: [
        deviceStateProvider(deviceInfo.id).overrideWith(
          (ref) => DeviceStateNotifier(
            repository: MockDeviceRepository(),
            deviceId: deviceInfo.id,
          ),
        ),
      ],
      child: DeviceDetailScreen(deviceId: deviceInfo.id),
    ),
  );
}
```

### 자동 목킹(Auto-mocking)

테스트 설정을 단순화하기 위해 자동 목킹 도구를 사용합니다:

```dart
// 테스트 디렉토리에 mocks.dart 파일 생성
import 'package:mockito/annotations.dart';
import 'package:core/core.dart';

@GenerateMocks([
  ApiService,
  DeviceRepository,
  SettingsRepository,
])
void main() {}
```

## 테스트 디버깅

테스트 실패 시 디버깅 방법:

1. **테스트 로그 활성화**:
   ```dart
   test('Failed test', () {
     debugPrint('Current state: $state');
     // ...
   });
   ```

2. **단계별 실행**:
   ```bash
   flutter test --name="specific test name" --pause-on-error
   ```

3. **Widget Inspector**: 위젯 테스트에서 위젯 트리 검사:
   ```dart
   await tester.pumpWidget(myWidget);
   debugDumpApp();
   ```

## 테스트 자동화

### 테스트 자동화 스크립트

테스트 실행을 자동화하는 스크립트:

```bash
#!/bin/bash
# run_tests.sh

# 포맷 검사
echo "Running format check..."
dart format --output=none --set-exit-if-changed .

# 린트 검사
echo "Running lint check..."
flutter analyze

# 유닛 테스트 및 위젯 테스트
echo "Running unit and widget tests..."
flutter test --coverage

# 커버리지 보고서 생성
echo "Generating coverage report..."
genhtml coverage/lcov.info -o coverage/html

echo "Tests completed!"
```

### pre-commit 훅

Git pre-commit 훅을 사용하여 커밋 전 테스트 실행:

```bash
#!/bin/sh
# .git/hooks/pre-commit

echo "Running tests before commit..."
flutter test --quiet

if [ $? -ne 0 ]; then
  echo "Tests failed! Commit aborted."
  exit 1
fi
```
