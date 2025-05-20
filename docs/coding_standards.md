# 코딩 규칙

이 문서는 A-Click IoT 프로젝트의 코딩 규칙과 스타일 가이드를 정의합니다.

## 일반 원칙

모든 코드는 다음 핵심 원칙을 준수해야 합니다:

1. **가독성**: 코드는 명확하고 이해하기 쉬워야 합니다.
2. **일관성**: 전체 코드베이스에서 일관된 패턴과 스타일을 유지합니다.
3. **간결성**: 코드는 간결하되 명확성을 희생하지 않아야 합니다.
4. **유지보수성**: 코드는 미래의 수정 및 확장이 용이해야 합니다.
5. **테스트 가능성**: 코드는 단위 테스트가 용이하도록 작성되어야 합니다.

## Dart 스타일 가이드

A-Click IoT 프로젝트는 공식 [Dart 스타일 가이드](https://dart.dev/guides/language/effective-dart/style)를 따릅니다.

### 명명 규칙

#### 파일명

- `snake_case`를 사용합니다.
- 소문자와 밑줄만 사용합니다.
- 예: `device_repository.dart`, `home_screen.dart`

#### 클래스/열거형/타입 별칭/확장

- `PascalCase`를 사용합니다.
- 각 단어의 첫 글자를 대문자로 표기합니다.
- 예: `DeviceRepository`, `HomeScreen`, `ConnectionState`

#### 변수/함수/파라미터

- `camelCase`를 사용합니다.
- 첫 단어는 소문자로 시작하고, 이후 단어는 대문자로 시작합니다.
- 예: `deviceId`, `isConnected`, `fetchDeviceData()`

#### 상수

- `camelCase`를 사용합니다.
- 예: `maxRetryCount`, `apiBaseUrl`

#### Private 변수/함수

- 이름 앞에 밑줄(`_`)을 붙입니다.
- 예: `_deviceCache`, `_calculateChecksum()`

### 주석

- 모든 public API 요소는 문서 주석(`///`)을 사용하여 설명합니다.
- 함수의 경우 파라미터와 반환 값을 설명합니다.
- 복잡한 로직에는 일반 주석(`//`)을 사용하여 설명합니다.

```dart
/// 디바이스 정보를 가져옵니다.
///
/// [deviceId]로 지정된 디바이스의 상세 정보를 조회합니다.
/// 성공하면 [DeviceInfo]를 반환하고, 실패하면 오류 메시지를 반환합니다.
Future<Either<String, DeviceInfo>> getDeviceById(String deviceId) async {
  // API에서 디바이스 정보 요청
  final response = await _apiService.get('devices/$deviceId');
  
  // 응답 처리
  return response.match(
    (error) => Left(error),
    (data) => Right(DeviceInfo.fromJson(data)),
  );
}
```

### 포맷팅

- [dart_style](https://github.com/dart-lang/dart_style) 포맷터를 사용합니다.
- 들여쓰기는 2칸 공백을 사용합니다.
- 한 줄은 80자를 넘지 않도록 합니다.

## Flutter 규칙

### 위젯 구성

- 위젯은 작고 재사용 가능하게 유지합니다.
- 복잡한 위젯은 더 작은 위젯으로 분해합니다.
- 상태 관리 로직과 UI 로직을 분리합니다.

### 상태 관리

- 상태 로직은 UI 코드와 분리합니다.
- Riverpod를 사용한 상태 관리 패턴을 따릅니다.
- 불변(immutable) 상태 객체를 사용합니다.

```dart
@immutable
class DeviceState {
  final bool isConnected;
  final String name;
  
  const DeviceState({
    this.isConnected = false,
    this.name = '',
  });
  
  DeviceState copyWith({
    bool? isConnected,
    String? name,
  }) {
    return DeviceState(
      isConnected: isConnected ?? this.isConnected,
      name: name ?? this.name,
    );
  }
}
```

### Provider 구성

- Provider는 기능 또는 도메인별로 구성합니다.
- 관련 Provider는 동일한 파일에 함께 배치합니다.
- Provider 이름은 명확하고 일관되게 지정합니다.

```dart
// Provider 예시
final deviceStateProvider = StateNotifierProvider.family<DeviceStateNotifier, DeviceState, String>(
  (ref, deviceId) {
    final repository = ref.watch(deviceRepositoryProvider);
    return DeviceStateNotifier(repository: repository, deviceId: deviceId);
  },
);
```

## 아키텍처 패턴

### 계층 구분

코드는 다음 계층으로 구성됩니다:

- **UI**: 화면 및 위젯
- **상태 관리**: Provider 및 상태 객체
- **비즈니스 로직**: Controller 및 서비스
- **데이터**: Repository 및 데이터 소스
- **모델**: 데이터 구조

계층 간 의존성 방향은 항상 외부에서 내부로 향해야 합니다(UI → 비즈니스 로직 → 데이터).

### 파일 구조

각 앱의 파일 구조:

```
lib/
├── main.dart
└── src/
    ├── controllers/
    ├── models/
    ├── providers/
    ├── screens/
    ├── states/
    ├── utils/
    └── widgets/
```

### 모델 클래스

모델 클래스는 다음 패턴을 따릅니다:

- `fromJson`/`toJson` 메서드 구현
- `copyWith` 메서드 구현
- `==` 연산자 및 `hashCode` 재정의
- 불변(immutable) 속성 사용

```dart
class DeviceInfo {
  final String id;
  final String name;
  final bool isOnline;
  
  const DeviceInfo({
    required this.id,
    required this.name,
    this.isOnline = false,
  });
  
  factory DeviceInfo.fromJson(Map<String, dynamic> json) {
    return DeviceInfo(
      id: json['id'] as String,
      name: json['name'] as String,
      isOnline: json['is_online'] as bool? ?? false,
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'is_online': isOnline,
    };
  }
  
  DeviceInfo copyWith({
    String? id,
    String? name,
    bool? isOnline,
  }) {
    return DeviceInfo(
      id: id ?? this.id,
      name: name ?? this.name,
      isOnline: isOnline ?? this.isOnline,
    );
  }
  
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DeviceInfo &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          isOnline == other.isOnline;
  
  @override
  int get hashCode => id.hashCode ^ name.hashCode ^ isOnline.hashCode;
}
```

## 오류 처리

- `try-catch` 블록을 사용하여 예외를 잡습니다.
- Either 타입(fpdart 패키지)을 사용하여 오류를 처리합니다.
- 명시적 오류 메시지를 사용합니다.
- 글로벌 오류 핸들러를 구현합니다.

```dart
Future<Either<String, DeviceInfo>> getDeviceById(String deviceId) async {
  try {
    final result = await _apiService.get(endpoint: 'devices/$deviceId');
    
    return result.match(
      (error) => Left('디바이스 정보를 가져오는 데 실패했습니다: $error'),
      (data) => Right(DeviceInfo.fromJson(data)),
    );
  } catch (e) {
    return Left('예상치 못한 오류가 발생했습니다: $e');
  }
}
```

## 성능 고려사항

- 불필요한 빌드를 방지하기 위해 `const` 생성자를 사용합니다.
- 무거운 계산은 UI 스레드에서 수행하지 않습니다.
- 큰 목록에는 `ListView.builder`를 사용합니다.
- 이미지는 적절하게 캐싱합니다.
- 불필요한 상태 업데이트를 방지합니다.

## 보안 가이드라인

- 민감한 정보(API 키, 비밀번호)를 코드에 하드코딩하지 않습니다.
- 환경 파일(`.env`)을 사용하여 구성 정보를 관리합니다.
- 사용자 입력은 항상 검증합니다.
- 네트워크 통신에는 HTTPS를 사용합니다.

## 린트 규칙

프로젝트는 [flutter_lints](https://pub.dev/packages/flutter_lints) 패키지와 사용자 정의 린트 규칙을 사용합니다.

```yaml
# analysis_options.yaml
include: package:flutter_lints/flutter.yaml

linter:
  rules:
    - always_declare_return_types
    - avoid_empty_else
    - avoid_print
    - avoid_relative_lib_imports
    - avoid_returning_null_for_future
    - avoid_web_libraries_in_flutter
    - cancel_subscriptions
    - close_sinks
    - package_prefixed_library_names
    - prefer_const_constructors
    - prefer_final_fields
    - prefer_final_locals
    - prefer_interpolation_to_compose_strings
    - prefer_single_quotes
    - test_types_in_equals
    - unawaited_futures
```

## 코드 리뷰 체크리스트

코드 리뷰 시 다음 항목을 확인합니다:

1. 코딩 규칙 준수
2. 비즈니스 로직의 정확성
3. 오류 처리의 적절성
4. 성능 고려사항
5. 테스트 커버리지
6. 보안 관행
7. 코드 중복 방지
8. 문서화 완성도

## 기여 전 체크리스트

코드 기여 전 다음 단계를 완료하세요:

1. 코드 포맷팅
   ```bash
   dart format .
   ```

2. 린트 검사
   ```bash
   flutter analyze
   ```

3. 테스트 실행
   ```bash
   flutter test
   ```
