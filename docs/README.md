# A-Click IoT 프로젝트

A-Click IoT 프로젝트는 IoT 디바이스와 모바일 애플리케이션 간의 통합을 위한 Flutter 기반 솔루션입니다.

## 목차

- [개요](#개요)
- [프로젝트 구조](#프로젝트-구조)
- [시작하기](#시작하기)
- [개발 가이드](#개발-가이드)
- [아키텍처](#아키텍처)
- [기여하기](#기여하기)

## 개요

A-Click IoT 프로젝트는 두 개의 주요 애플리케이션으로 구성되어 있습니다:

1. **IoT 앱**: IoT 디바이스에서 실행되며 센서 데이터를 수집하고 처리
2. **Phone 앱**: 사용자의 모바일 기기에서 실행되며 IoT 디바이스와 통신하고 데이터를 시각화

이 두 애플리케이션은 코드 재사용성과 일관된 개발 경험을 위해 공유 패키지를 사용합니다.

## 프로젝트 구조

```
/
├── apps/                    # 애플리케이션 디렉토리
│   ├── iot/                 # IoT 디바이스 애플리케이션
│   └── phone/               # 모바일 폰 애플리케이션
├── packages/                # 공유 패키지
│   └── core/                # 핵심 공유 기능
├── docs/                    # 프로젝트 문서
└── scripts/                 # 개발 및 배포 스크립트
```

자세한 프로젝트 구조는 [프로젝트 구조 문서](./project_structure.md)를 참조하세요.

## 시작하기

### 사전 요구사항

- Flutter 3.29.3 이상
- Dart 3.3.0 이상
- Android Studio 또는 Visual Studio Code
- Git

### 개발 환경 설정

1. 저장소 복제:
   ```bash
   git clone https://github.com/your-org/aclick-iot.git
   cd aclick-iot
   ```

2. 의존성 설치:
   ```bash
   flutter pub get
   ```

3. 앱 실행:
   ```bash
   # IoT 앱 실행
   cd apps/iot
   flutter run
   
   # Phone 앱 실행
   cd apps/phone
   flutter run
   ```

자세한 환경 설정 가이드는 [개발 환경 설정](./setup.md)을 참조하세요.

## 개발 가이드

주요 개발 가이드:

- [상태 관리](./state_management.md) - Riverpod 기반 상태 관리 패턴
- [의존성 주입](./dependency_injection.md) - 서비스 및 리포지토리 의존성 관리
- [코딩 규칙](./coding_standards.md) - 코드 스타일 및 모범 사례
- [테스트 가이드](./testing.md) - 단위, 통합, 위젯 테스트 방법

## 아키텍처

이 프로젝트는 클린 아키텍처 원칙을 따르며 다음과 같은 주요 계층으로 구성됩니다:

- **표현 계층**: UI 컴포넌트 및 화면
- **비즈니스 로직 계층**: 상태 관리 및 유스케이스
- **데이터 계층**: 리포지토리 및 데이터 소스

자세한 아키텍처 설명은 [아키텍처 문서](./architecture.md)를 참조하세요.

## 기여하기

기여 방법:

1. 이슈 생성 또는 기존 이슈 선택
2. 기능 브랜치 생성 (`git checkout -b feature/your-feature`)
3. 변경사항 커밋 (`git commit -m 'Add some feature'`)
4. 브랜치 푸시 (`git push origin feature/your-feature`)
5. Pull Request 생성

자세한 기여 가이드는 [기여 가이드](./contributing.md)를 참조하세요.
