# 프로젝트 구조

이 문서는 A-Click IoT 프로젝트의 전체 구조를 상세하게 설명합니다.

## 최상위 디렉토리

```
/
├── apps/                    # 애플리케이션 디렉토리
├── packages/                # 공유 패키지
├── docs/                    # 프로젝트 문서
├── scripts/                 # 개발 및 배포 스크립트
├── .github/                 # GitHub 워크플로우 및 템플릿
└── tasks/                   # 개발 작업 관리
```

## 애플리케이션

### IoT 앱 (`/apps/iot/`)

IoT 디바이스에서 실행되는 Flutter 애플리케이션입니다.

```
/apps/iot/
├── android/                 # Android 플랫폼 설정
├── ios/                     # iOS 플랫폼 설정
├── lib/                     # 소스 코드
│   ├── main.dart            # 애플리케이션 진입점
│   └── src/                 # 구현 코드
│       ├── controllers/     # 비즈니스 로직 컨트롤러
│       ├── models/          # 데이터 모델
│       ├── providers/       # Riverpod 프로바이더 및 상태 컨테이너
│       ├── screens/         # UI 화면
│       ├── states/          # 상태 정의
│       ├── utils/           # 유틸리티 함수
│       └── widgets/         # 재사용 가능한 위젯
├── test/                    # 테스트 코드
├── .env.development         # 개발 환경 설정
├── .env.staging             # 스테이징 환경 설정
├── .env.production          # 프로덕션 환경 설정
└── pubspec.yaml             # Flutter 패키지 설정
```

### Phone 앱 (`/apps/phone/`)

사용자 모바일 기기에서 실행되는 Flutter 애플리케이션입니다.

```
/apps/phone/
├── android/                 # Android 플랫폼 설정
├── ios/                     # iOS 플랫폼 설정
├── lib/                     # 소스 코드
│   ├── main.dart            # 애플리케이션 진입점
│   └── src/                 # 구현 코드
│       ├── controllers/     # 비즈니스 로직 컨트롤러
│       ├── models/          # 데이터 모델
│       ├── providers/       # Riverpod 프로바이더 및 상태 컨테이너
│       ├── screens/         # UI 화면
│       ├── states/          # 상태 정의
│       ├── utils/           # 유틸리티 함수
│       └── widgets/         # 재사용 가능한 위젯
├── test/                    # 테스트 코드
├── .env.development         # 개발 환경 설정
├── .env.staging             # 스테이징 환경 설정
├── .env.production          # 프로덕션 환경 설정
└── pubspec.yaml             # Flutter 패키지 설정
```

## 공유 패키지

### 코어 패키지 (`/packages/core/`)

양쪽 앱에서 공유하는 핵심 기능을 제공합니다.

```
/packages/core/
├── lib/                     # 소스 코드
│   ├── core.dart            # 라이브러리 진입점
│   └── src/                 # 구현 코드
│       ├── di/              # 의존성 주입
│       ├── encryption/      # 암호화 유틸리티
│       ├── events/          # 이벤트 모델
│       ├── network/         # 네트워크 프로토콜
│       └── repositories/    # 데이터 리포지토리
├── test/                    # 테스트 코드
└── pubspec.yaml             # Flutter 패키지 설정
```

## CI/CD 및 GitHub

```
/.github/
├── workflows/               # GitHub Actions 워크플로우
│   ├── build.yml            # 빌드 워크플로우
│   ├── deploy.yml           # 배포 워크플로우
│   ├── lint.yml             # 린트 워크플로우
│   └── test.yml             # 테스트 워크플로우
├── CODEOWNERS               # 코드 소유자 설정
└── PULL_REQUEST_TEMPLATE.md # PR 템플릿
```

## 개발 작업 관리

```
/tasks/
├── tasks.json              # 작업 관리 JSON 파일
└── 1.2/                    # 개별 작업 파일
    └── ...
```

## 주요 파일 설명

### 애플리케이션 진입점 (`main.dart`)

앱 시작 및 의존성 주입, 프로바이더 설정을 담당합니다.

### 상태 관리 (`src/providers/`, `src/states/`)

Riverpod를 사용한 상태 관리 로직을 포함합니다.

### 비즈니스 로직 (`src/controllers/`)

앱의 주요 기능과 데이터 흐름을 제어합니다.

### 데이터 접근 계층 (`packages/core/src/repositories/`)

데이터 소스에 대한 일관된 인터페이스를 제공합니다.

### 의존성 주입 (`packages/core/src/di/`)

서비스 로케이터 패턴과 Riverpod 프로바이더를 통한 의존성 관리를 구현합니다.

## 코드 조직 원칙

1. **관심사 분리**: 각 코드는 단일 책임을 가지며, 관련된 기능끼리 함께 위치합니다.
2. **계층적 구조**: 의존성 방향은 UI → 비즈니스 로직 → 데이터 흐름입니다.
3. **기능 모듈화**: 기능 단위로 코드를 모듈화하여 유지보수성을 향상시킵니다.
4. **공유 코드 중앙화**: 공통 기능은 `core` 패키지에 위치시켜 중복을 방지합니다.
