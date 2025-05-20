# 개발 환경 설정

이 문서는 A-Click IoT 프로젝트의 개발 환경 설정 방법을 설명합니다.

## 사전 요구사항

개발 환경 설정을 위해 다음 도구가 필요합니다:

- **Flutter 3.29.3** 이상
- **Dart 3.3.0** 이상
- **Git**
- **Android Studio** 또는 **Visual Studio Code**
- **Xcode** (macOS 개발 환경의 경우)

## Flutter 설치

### Windows

1. [Flutter SDK](https://flutter.dev/docs/get-started/install/windows) 다운로드
2. ZIP 파일을 원하는 위치에 압축 해제 (예: `C:\flutter`)
3. 환경 변수에 Flutter 경로 추가:
   - 검색창에서 "환경 변수 편집" 검색
   - "시스템 환경 변수 편집" 선택
   - "환경 변수" 클릭
   - "Path" 변수 선택 후 "편집" 클릭
   - "새로 만들기" 클릭하고 Flutter 경로 추가 (예: `C:\flutter\bin`)
   - "확인" 클릭하여 모든 대화 상자 닫기
4. 명령 프롬프트를 열고 다음 명령 실행:
   ```bash
   flutter doctor
   ```
5. 필요한 종속성 설치를 위해 Flutter doctor의 지시 사항 따르기

### macOS

1. [Flutter SDK](https://flutter.dev/docs/get-started/install/macos) 다운로드
2. ZIP 파일 압축 해제 (예: `~/development`)
3. 환경 변수에 Flutter 경로 추가:
   ```bash
   echo 'export PATH="$PATH:`pwd`/flutter/bin"' >> ~/.zshrc
   source ~/.zshrc
   ```
4. 다음 명령 실행:
   ```bash
   flutter doctor
   ```
5. 필요한 종속성 설치를 위해 Flutter doctor의 지시 사항 따르기

### Flutter 버전 고정

프로젝트에서는 Flutter 3.29.3 버전을 표준으로 사용합니다. 설치 후 버전을 고정하세요:

```bash
flutter version 3.29.3
```

## IDE 설정

### Visual Studio Code

1. [Visual Studio Code](https://code.visualstudio.com/) 설치
2. Flutter 및 Dart 확장 프로그램 설치:
   - `Ctrl+Shift+X` (Windows) 또는 `Cmd+Shift+X` (macOS)로 확장 탭 열기
   - "Flutter" 검색 및 설치
   - Dart 확장 프로그램도 자동으로 설치됨
3. 사용자 설정 구성:
   - `settings.json`에 다음 설정 추가:
   ```json
   {
     "editor.formatOnSave": true,
     "editor.formatOnType": true,
     "dart.previewFlutterUiGuides": true,
     "dart.openDevTools": "flutter",
     "dart.debugExternalPackageLibraries": true,
     "dart.debugSdkLibraries": false,
     "[dart]": {
       "editor.defaultFormatter": "Dart-Code.dart-code",
       "editor.formatOnSave": true,
       "editor.formatOnType": true,
       "editor.rulers": [80],
       "editor.selectionHighlight": false,
       "editor.suggest.snippetsPreventQuickSuggestions": false,
       "editor.suggestSelection": "first",
       "editor.tabCompletion": "onlySnippets",
       "editor.wordBasedSuggestions": "off"
     }
   }
   ```

### Android Studio

1. [Android Studio](https://developer.android.com/studio) 설치
2. Flutter 및 Dart 플러그인 설치:
   - `File > Settings > Plugins` (Windows/Linux) 또는 `Android Studio > Preferences > Plugins` (macOS)
   - "Flutter" 검색 및 설치
   - Dart 플러그인도 자동으로 설치됨
3. Flutter SDK 경로 설정:
   - Android Studio 시작 화면에서 `Configure > Settings > Languages & Frameworks > Flutter`
   - Flutter SDK 경로 입력 (예: `C:\flutter` 또는 `~/development/flutter`)

## 프로젝트 설정

### 저장소 복제

```bash
git clone https://github.com/your-org/aclick-iot.git
cd aclick-iot
```

### 종속성 설치

모든 프로젝트 종속성을 설치합니다:

```bash
# 코어 패키지 종속성 설치
cd packages/core
flutter pub get

# IoT 앱 종속성 설치
cd ../../apps/iot
flutter pub get

# Phone 앱 종속성 설치
cd ../phone
flutter pub get
```

또는 루트 디렉토리에서 모든 종속성을 한 번에 설치할 수 있습니다:

```bash
flutter pub get --no-example
```

### 환경 설정

각 앱에는 여러 환경(개발, 스테이징, 프로덕션)에 대한 환경 설정 파일이 있습니다. 로컬 개발을 위해 `.env.development`를 설정합니다:

```bash
# IoT 앱
cd apps/iot
cp .env.development.example .env.development

# Phone 앱
cd ../phone
cp .env.development.example .env.development
```

필요에 따라 환경 변수를 편집합니다.

## 앱 실행

### IoT 앱

```bash
cd apps/iot
flutter run
```

### Phone 앱

```bash
cd apps/phone
flutter run
```

### 다양한 플랫폼으로 실행

특정 플랫폼에서 앱을 실행하려면:

```bash
flutter run -d windows  # Windows
flutter run -d macos    # macOS
flutter run -d ios      # iOS 시뮬레이터
flutter run -d android  # Android 에뮬레이터
```

## 개발 도구

### Taskmaster

이 프로젝트는 작업 관리를 위해 Taskmaster를 사용합니다. 다음 명령으로 현재 작업을 확인할 수 있습니다:

```bash
task-master list
```

또는 기존 스크립트를 사용:

```bash
node scripts/dev.js list
```

### Code Generation

프로젝트에서 코드 생성 도구를 사용하는 경우:

```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

## 문제 해결

### 종속성 문제

종속성 문제가 발생하면 다음 명령을 시도하세요:

```bash
flutter clean
flutter pub cache repair
flutter pub get
```

### IDE 문제

IDE에서 문제가 발생하면:

1. Flutter 확장 프로그램 재설치
2. IDE 재시작
3. `flutter doctor` 실행하여 모든 것이 올바르게 설정되었는지 확인

## 다음 단계

환경 설정이 완료되면 다음 문서를 참조하세요:

- [코딩 규칙](./coding_standards.md)
- [개발 워크플로우](./workflow.md)
- [아키텍처 개요](./architecture.md)
