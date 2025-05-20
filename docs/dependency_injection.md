# 의존성 주입 구조

본 문서는 IoT 프로젝트의 의존성 주입(Dependency Injection) 구조에 대해 설명합니다.

## 개요

IoT 프로젝트는 Riverpod를 활용한 의존성 주입 시스템을 사용합니다. 이 시스템은 두 가지 주요 접근 방식을 결합합니다:

1. **서비스 로케이터 패턴**: 전역 서비스 인스턴스를 관리
2. **Riverpod Provider**: 각 기능별 의존성 관리 및 테스트 가능한 구조 제공

이러한 접근 방식은 코드 재사용성, 테스트 용이성, 유지 관리성을 향상시킵니다.

## 주요 구성 요소

### 1. 서비스 로케이터 (Service Locator)

`ServiceLocator` 클래스는 싱글톤 패턴을 사용하여 전역 서비스 인스턴스를 관리합니다:

```dart
// 서비스 로케이터 사용 예시
final apiService = ServiceLocator.instance.apiService;
final encryptor = ServiceLocator.instance.encryptor;
```

### 2. Provider 기반 의존성 주입

Riverpod provider를 통해 의존성을 선언적으로 관리합니다:

```dart
// Provider 정의
final apiServiceProvider = Provider<ApiService>((ref) {
  return ref.read(serviceLocatorProvider).apiService;
});

// Provider 사용
final deviceRepository = Provider<DeviceRepository>((ref) {
  final apiService = ref.watch(apiServiceProvider);
  return DeviceRepository(apiService: apiService);
});
```

### 3. 기능별 Provider 스코프

특정 기능이나 환경에 따라 의존성을 오버라이드할 수 있는 스코프를 제공합니다:

```dart
// IoT 디바이스별 스코프 사용 예시
IoTDeviceScope(
  deviceApiUrl: 'https://device-api.example.com',
  deviceId: 'device-001',
  child: MyDeviceConfigScreen(),
)
```

### 4. 테스트를 위한 Provider 오버라이드

단위 테스트 및 위젯 테스트를 위한 Mock 객체 오버라이드를 지원합니다:

```dart
// 테스트 컨테이너 생성
final container = createTestContainer();

// 또는 위젯 테스트에서 사용
testWidgets('Widget test with DI', (tester) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: TestProviders.testOverrides,
      child: MyWidget(),
    ),
  );
});
```

## 리포지토리 계층

리포지토리 계층은 데이터 액세스를 추상화하고 비즈니스 로직과 분리합니다:

1. **DeviceRepository**: 디바이스 정보 관리
2. **SettingsRepository**: 앱 설정 관리 
3. **TelemetryRepository**: 원격 측정 데이터 관리

각 리포지토리는 의존성 주입을 통해 필요한 서비스를 제공받습니다.

## 모범 사례

1. **생성자 주입 사용**: 명시적인 의존성을 위해 생성자 주입 방식을 사용하세요.

```dart
class MyService {
  final ApiService apiService;
  final Logger logger;
  
  MyService({required this.apiService, required this.logger});
}
```

2. **계층 구조 준수**: 다음 계층 구조를 유지하세요:
   - Providers: 의존성 선언
   - Repositories: 데이터 액세스 추상화
   - Services: 비즈니스 로직
   - Controllers: UI 관련 로직
   - Widgets: UI 컴포넌트

3. **Override 패턴**: 테스트와 특수 환경을 위한 오버라이드 패턴을 활용하세요.

```dart
ProviderScope(
  overrides: [
    apiServiceProvider.overrideWithValue(mockApiService),
  ],
  child: MyApp(),
)
```

4. **Ref 전달 제한**: `Ref` 객체를 깊이 전달하지 말고, 상위 수준에서만 사용하세요.

## 테스트 방법

1. **단위 테스트**:

```dart
test('DeviceRepository should return devices', () async {
  final container = createTestContainer();
  final repository = container.read(deviceRepositoryProvider);
  
  // Given - 테스트 준비
  final mockApiService = container.read(apiServiceProvider) as MockApiService;
  when(mockApiService.get(endpoint: 'devices')).thenAnswer((_) async => 
    Right({'devices': [/* mock data */]}));
  
  // When - 테스트 실행
  final result = await repository.getDevices();
  
  // Then - 결과 검증
  expect(result.isRight(), true);
  expect(result.getRight().getOrElse(() => []), isNotEmpty);
});
```

2. **위젯 테스트**:

```dart
testWidgets('Widget should display device list', (tester) async {
  // Given - 테스트 준비 및 모의 객체 설정
  final mockDevices = [/* mock devices */];
  
  // Provider 오버라이드
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...TestProviders.testOverrides,
        deviceRepositoryProvider.overrideWith((ref) {
          final mockRepo = MockDeviceRepository();
          when(mockRepo.getDevices()).thenAnswer((_) async => Right(mockDevices));
          return mockRepo;
        }),
      ],
      child: DeviceListScreen(),
    ),
  );
  
  // 위젯이 렌더링될 때까지 대기
  await tester.pump();
  
  // Then - UI 검증
  expect(find.text('Device List'), findsOneWidget);
  expect(find.byType(DeviceCard), findsNWidgets(mockDevices.length));
});
```

## 정리

의존성 주입 시스템은 앱의 모듈성, 테스트 가능성 및 유지 관리성을 크게 향상시킵니다. 서비스 로케이터와 Riverpod provider를 함께 사용하면 제어의 역전(IoC)과 의존성 주입의 이점을 모두 활용할 수 있습니다.
