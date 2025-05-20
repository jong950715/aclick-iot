# 아키텍처 개요

이 문서는 A-Click IoT 프로젝트의 전체 아키텍처와 디자인 패턴에 대해 설명합니다.

## 아키텍처 원칙

A-Click IoT 프로젝트는 다음 아키텍처 원칙을 따릅니다:

1. **관심사 분리**: 각 컴포넌트는 단일 책임을 가집니다.
2. **계층화**: 명확한 경계를 가진 계층 구조를 유지합니다.
3. **테스트 용이성**: 코드는 단위 테스트가 용이하도록 설계됩니다.
4. **유연성**: 변경 및 확장이 용이한 구조를 지향합니다.
5. **일관성**: 일관된 패턴과 규칙을 따릅니다.

## 아키텍처 다이어그램

### 전체 시스템 구조

```
┌─────────────────┐          ┌─────────────────┐
│    Phone App    │◄────────►│     IoT App     │
└────────┬────────┘          └────────┬────────┘
         │                            │
         │                            │
         ▼                            ▼
┌─────────────────────────────────────────────┐
│               Core Package                  │
└─────────────────────────────────────────────┘
```

### 애플리케이션 계층 구조

```
┌─────────────────────────────────────────────┐
│                    UI                       │
│  (Screens, Widgets, UI Components)          │
└────────────────────┬────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────┐
│             비즈니스 로직                     │
│  (Controllers, State Management)            │
└────────────────────┬────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────┐
│               데이터                         │
│  (Repositories, Data Sources, Models)       │
└─────────────────────────────────────────────┘
```

## 계층 설명

### UI 계층

사용자 인터페이스를 담당하는 계층입니다. 이 계층은 다음과 같은 구성 요소를 포함합니다:

- **Screens**: 전체 화면 UI
- **Widgets**: 재사용 가능한 UI 컴포넌트
- **Navigation**: 화면 간 이동 로직

이 계층의 주요 책임:
- 사용자 입력 처리
- 데이터 표시
- 사용자 피드백 제공
- 상태 변화에 따른 UI 업데이트

```dart
// Screen 예시
class DeviceDetailScreen extends ConsumerWidget {
  final String deviceId;
  
  const DeviceDetailScreen({required this.deviceId, Key? key}) : super(key: key);
  
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final deviceState = ref.watch(deviceStateProvider(deviceId));
    
    return Scaffold(
      appBar: AppBar(title: Text('디바이스 상세 정보')),
      body: deviceState.when(
        data: (device) => DeviceDetailView(device: device),
        loading: () => const CircularProgressIndicator(),
        error: (err, _) => Text('오류: $err'),
      ),
    );
  }
}
```

### 비즈니스 로직 계층

애플리케이션의 핵심 로직을 담당하는 계층입니다. 이 계층은 다음과 같은 구성 요소를 포함합니다:

- **Controllers**: 비즈니스 로직 처리
- **State Providers**: 상태 관리 및 의존성 제공
- **State Classes**: 불변 상태 정의

이 계층의 주요 책임:
- 데이터 처리 및 변환
- 비즈니스 규칙 적용
- 상태 관리
- 에러 처리

```dart
// Controller 예시
class DeviceController {
  final DeviceRepository _repository;
  
  DeviceController({required DeviceRepository repository})
      : _repository = repository;
  
  Future<Either<String, DeviceInfo>> getDeviceDetails(String deviceId) async {
    return await _repository.getDeviceById(deviceId);
  }
  
  Future<Either<String, bool>> toggleDevicePower(String deviceId) async {
    // 비즈니스 로직 구현
  }
}

// Provider 예시
final deviceControllerProvider = Provider<DeviceController>((ref) {
  final repository = ref.watch(deviceRepositoryProvider);
  return DeviceController(repository: repository);
});
```

### 데이터 계층

데이터 액세스 및 관리를 담당하는 계층입니다. 이 계층은 다음과 같은 구성 요소를 포함합니다:

- **Repositories**: 데이터 소스에 대한 추상화 인터페이스
- **Data Sources**: 실제 데이터 접근 구현
- **Models**: 데이터 구조 정의

이 계층의 주요 책임:
- 데이터 저장 및 검색
- 네트워크 통신
- 데이터 캐싱
- 데이터 타입 변환

```dart
// Repository 예시
class DeviceRepository {
  final ApiService _apiService;
  
  DeviceRepository({required ApiService apiService})
      : _apiService = apiService;
  
  Future<Either<String, DeviceInfo>> getDeviceById(String deviceId) async {
    try {
      final result = await _apiService.get(endpoint: 'devices/$deviceId');
      
      return result.match(
        (error) => Left(error),
        (data) => Right(DeviceInfo.fromJson(data)),
      );
    } catch (e) {
      return Left('디바이스 정보를 가져오는 데 실패했습니다: $e');
    }
  }
}
```

## 의존성 주입

A-Click IoT 프로젝트는 두 가지 주요 의존성 주입 메커니즘을 사용합니다:

1. **서비스 로케이터 패턴**: 전역 서비스 인스턴스를 관리
2. **Riverpod Provider**: 의존성 주입과 상태 관리 결합

```dart
// 서비스 로케이터 사용 예시
final apiService = ServiceLocator.instance.apiService;

// Riverpod Provider 사용 예시
final repository = ref.watch(deviceRepositoryProvider);
```

자세한 내용은 [의존성 주입 문서](./dependency_injection.md)를 참조하세요.

## 상태 관리

A-Click IoT 프로젝트는 Riverpod를 사용한 반응형 상태 관리 패턴을 구현합니다:

- **상태 정의**: 불변(immutable) 클래스로 상태 정의
- **상태 변경**: 복사 패턴을 사용한 상태 업데이트
- **상태 소비**: ConsumerWidget 및 ref.watch()를 통한 상태 감시

```dart
// 상태 정의 예시
@immutable
class DeviceState {
  final bool isConnected;
  final String name;
  final Map<String, dynamic> metrics;
  
  const DeviceState({
    this.isConnected = false,
    this.name = '',
    this.metrics = const {},
  });
  
  DeviceState copyWith({
    bool? isConnected,
    String? name,
    Map<String, dynamic>? metrics,
  }) {
    return DeviceState(
      isConnected: isConnected ?? this.isConnected,
      name: name ?? this.name,
      metrics: metrics ?? this.metrics,
    );
  }
}

// 상태 Notifier 예시
class DeviceStateNotifier extends StateNotifier<DeviceState> {
  final DeviceRepository _repository;
  
  DeviceStateNotifier({required DeviceRepository repository})
      : _repository = repository,
        super(const DeviceState());
        
  Future<void> connect(String deviceId) async {
    // 상태 업데이트 로직
  }
}
```

자세한 내용은 [상태 관리 문서](./state_management.md)를 참조하세요.

## 통신 아키텍처

### IoT 디바이스와 Phone 앱 간 통신

IoT 디바이스와 Phone 앱 간의 통신은 다음과 같은 프로토콜을 사용합니다:

- **실시간 통신**: WebSocket 기반 양방향 통신
- **명령 전송**: REST API를 통한 제어 명령 전송
- **데이터 동기화**: 주기적 폴링 또는 이벤트 기반 데이터 동기화

```dart
// 통신 프로토콜 사용 예시
final client = ref.watch(protocolClientProvider);
final telemetryStream = client.subscribe('telemetry/$deviceId/stream');
```

## 오류 처리

프로젝트는 Either 타입(fpdart 패키지 사용)을 통한 함수형 오류 처리 패턴을 사용합니다:

```dart
// 오류 처리 예시
Future<Either<String, DeviceInfo>> getDeviceDetails(String deviceId) async {
  try {
    final result = await _repository.getDeviceById(deviceId);
    return result;
  } catch (e) {
    return Left('디바이스 정보를 가져오는 데 실패했습니다: $e');
  }
}

// 결과 처리
final result = await getDeviceDetails('device-001');
return result.match(
  (error) => showErrorDialog(error),
  (device) => showDeviceDetails(device),
);
```

## 아키텍처 결정 기록

이 프로젝트의 주요 아키텍처 결정과 그 이유는 다음과 같습니다:

### ADR 1: Riverpod 상태 관리 선택

- **결정**: 상태 관리 솔루션으로 Riverpod 채택
- **상태**: 승인됨
- **컨텍스트**: 상태 관리 및 의존성 주입 솔루션 필요
- **결정 이유**:
  - Provider 코드 생성 불필요
  - 강력한 코드 완성 및 타입 안전성
  - 의존성 오버라이드 용이성
  - 상태 관리와 DI 통합

### ADR 2: 함수형 오류 처리 패턴

- **결정**: fpdart 패키지의 Either 타입을 사용한 오류 처리 채택
- **상태**: 승인됨
- **컨텍스트**: 일관된 오류 처리 패턴 필요
- **결정 이유**:
  - 타입 안전성 향상
  - 오류 처리 강제화
  - 가독성 향상
  - 함수형 프로그래밍 패턴과의 일관성

## 보안 고려사항

아키텍처 설계 시 고려한 주요 보안 측면:

- **데이터 암호화**: 민감 데이터 저장 및 전송 시 암호화
- **인증 및 권한 부여**: 적절한 인증 메커니즘 및 권한 부여 시스템
- **입력 검증**: 모든 사용자 입력 및 외부 데이터 검증
- **보안 설정**: 안전한 기본 설정 및 최소 권한 원칙

## 참고 자료

- [Flutter 아키텍처 샘플](https://github.com/brianegan/flutter_architecture_samples)
- [Riverpod 문서](https://riverpod.dev/)
- [클린 아키텍처](https://blog.cleancoder.com/uncle-bob/2012/08/13/the-clean-architecture.html)
- [함수형 오류 처리](https://fsharpforfunandprofit.com/posts/recipe-overloading/)
