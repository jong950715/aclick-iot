# 기여 가이드

이 문서는 A-Click IoT 프로젝트에 기여하는 방법에 대한 가이드라인을 제공합니다.

## 시작하기

### 저장소 설정

1. 저장소를 포크합니다.
2. 로컬 머신에 클론합니다:
   ```bash
   git clone https://github.com/your-username/aclick-iot.git
   cd aclick-iot
   ```
3. 원본 저장소를 업스트림으로 추가합니다:
   ```bash
   git remote add upstream https://github.com/original-org/aclick-iot.git
   ```

4. 최신 변경사항을 가져옵니다:
   ```bash
   git fetch upstream
   git checkout main
   git merge upstream/main
   ```

### 개발 환경 설정

환경 설정에 대한 자세한 내용은 [환경 설정 문서](./setup.md)를 참조하세요.

## 기능 개발 프로세스

### 이슈 생성 또는 선택

1. 기존 이슈를 검토하고 작업할 이슈를 선택하거나, 새 이슈를 생성합니다.
2. 이슈에 대한 작업 의사를 표시합니다.

### 작업 브랜치 생성

1. 최신 `main` 브랜치에서 새 브랜치를 생성합니다:
   ```bash
   git checkout main
   git pull upstream main
   git checkout -b feature/your-feature-name
   ```

### 코드 작성

1. 프로젝트의 [코딩 규칙](./coding_standards.md)을 준수합니다.
2. 모든 새로운 코드에 대한 테스트를 작성합니다.
3. 작은 단위의 커밋으로 작업을 진행합니다.

### 테스트 실행

```bash
# 포맷팅 확인
dart format --output=none --set-exit-if-changed .

# 린트 검사
flutter analyze

# 테스트 실행
flutter test
```

### 변경사항 커밋

```bash
git add .
git commit -m "feat: 의미 있는 커밋 메시지"
```

커밋 메시지는 [Conventional Commits](https://www.conventionalcommits.org/) 형식을 따릅니다:

- `feat`: 새 기능
- `fix`: 버그 수정
- `docs`: 문서 변경
- `style`: 코드 스타일 변경
- `refactor`: 코드 리팩토링
- `test`: 테스트 코드 추가/수정
- `chore`: 빌드 프로세스 변경 등

### 브랜치 푸시

```bash
git push -u origin feature/your-feature-name
```

### Pull Request 생성

1. GitHub 저장소 페이지로 이동합니다.
2. "Compare & pull request" 버튼을 클릭합니다.
3. PR 템플릿에 따라 필요한 정보를 입력합니다.
4. 코드 검토자를 지정합니다.
5. "Create pull request" 버튼을 클릭합니다.

## Pull Request 가이드라인

### PR 설명

모든 PR은 다음 정보를 포함해야 합니다:

1. 변경사항에 대한 간결한 설명
2. 관련 이슈 참조 (예: "Resolves #123")
3. 테스트 방법 설명
4. UI 변경의 경우 스크린샷 또는 GIF
5. 특별한 주의가 필요한 부분 강조

### PR 크기

PR은 가능한 작게 유지하세요:

- 한 번에 하나의 기능 또는 버그 수정에 집중
- 가능한 경우 큰 변경을 더 작은 PR로 분할
- 일반적으로 500줄 미만의 변경을 권장

### 코드 검토 프로세스

1. 적어도 한 명의 코드 리뷰어가 승인해야 합니다.
2. 모든 자동화된 테스트와 검사가 통과해야 합니다.
3. 모든 피드백을 적절하게 처리해야 합니다.

## 브랜치 관리

### 브랜치 명명 규칙

- `feature/<feature-name>`: 새로운 기능
- `bugfix/<bug-name>`: 버그 수정
- `docs/<docs-name>`: 문서 업데이트
- `refactor/<refactor-name>`: 코드 리팩토링
- `test/<test-name>`: 테스트 추가 또는 수정

### 브랜치 수명

기능 브랜치는 짧게 유지하고 가능한 빨리 병합합니다. 일반적으로 브랜치 수명은 1-2주를 넘지 않아야 합니다.

## 버전 관리

이 프로젝트는 [유의적 버전](https://semver.org/) 관리를 따릅니다:

- **주(Major) 버전**: 하위 호환성이 없는 API 변경
- **부(Minor) 버전**: 하위 호환성이 있는 기능 추가
- **수(Patch) 버전**: 하위 호환성이 있는 버그 수정

## 이슈 보고

### 버그 보고

버그 보고 시 다음 정보를 포함해주세요:

1. 버그 설명
2. 재현 단계
3. 예상 동작과 실제 동작
4. 스크린샷 또는 동영상 (가능한 경우)
5. 환경 정보 (OS, Flutter 버전 등)

### 기능 요청

기능 요청 시 다음 정보를 포함해주세요:

1. 해결하려는 문제 설명
2. 제안하는 해결책
3. 대안 고려사항
4. 추가 컨텍스트 또는 스크린샷

## 문서 기여

문서 개선도 중요한 기여입니다:

1. 오타 수정
2. 명확성 개선
3. 예제 추가
4. 설명 확장

모든 문서 변경은 일반 PR 프로세스를 따릅니다.

## 커뮤니티 행동 강령

### 우리의 약속

개방적이고 환영받는 환경을 조성하기 위해 우리는 기여자로서 다음을 약속합니다:

- 모든 참여자에게 괴롭힘 없는 경험 제공
- 공감과 친절함으로 의사소통
- 다양한 관점과 경험 존중
- 건설적인 피드백 제공 및 수용
- 공동체의 이익을 위한 책임 수용

### 금지된 행동

금지된 행동은 다음과 같습니다:

- 성적 언어나 이미지 사용 및 원치 않는 성적 관심 또는 접근
- 트롤링, 모욕적/비하적 발언, 개인적/정치적 공격
- 공개적 또는 개인적 괴롭힘
- 동의 없는 개인 정보 공개
- 전문적 환경에서 부적절한 기타 행동

## 라이선스

기여함으로써, 귀하는 귀하의 기여가 프로젝트의 라이선스에 따라 라이선스가 부여됨에 동의합니다.
