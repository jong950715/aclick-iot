# 개발 워크플로우

이 문서는 A-Click IoT 프로젝트의 개발 워크플로우와 협업 프로세스를 설명합니다.

## 개발 사이클

![개발 사이클](./images/dev_cycle.png)

A-Click IoT 프로젝트는 다음 개발 사이클을 따릅니다:

1. **작업 계획**: 작업 선택 및 이해
2. **구현**: 코드 작성 및 로컬 테스트
3. **검토**: 코드 리뷰 및 피드백 반영
4. **통합**: 메인 브랜치에 병합
5. **배포**: 다양한 환경에 배포

## 작업 관리

### Taskmaster 사용

이 프로젝트는 작업 관리를 위해 Taskmaster CLI 도구를 사용합니다:

```bash
# 작업 목록 보기
task-master list

# 특정 작업 상세 정보 보기
task-master show <id>

# 작업 상태 업데이트
task-master set-status --id=<id> --status=<status>

# 복잡한 작업을 하위 작업으로 분해
task-master expand --id=<id> --subtasks=<number>
```

자세한 내용은 [Taskmaster 사용 가이드](./taskmaster.md)를 참조하세요.

## Git 워크플로우

프로젝트는 GitHub Flow 기반의 브랜치 전략을 사용합니다:

### 브랜치 명명 규칙

- `feature/<feature-name>`: 새로운 기능 개발
- `bugfix/<bug-name>`: 버그 수정
- `refactor/<refactor-name>`: 코드 리팩토링
- `docs/<docs-name>`: 문서 업데이트
- `test/<test-name>`: 테스트 추가 또는 수정

### 작업 시작하기

새 기능 작업을 시작하려면:

1. 최신 `main` 브랜치 가져오기:
   ```bash
   git checkout main
   git pull origin main
   ```

2. 새 브랜치 생성:
   ```bash
   git checkout -b feature/your-feature-name
   ```

3. 정기적으로 변경 사항 커밋:
   ```bash
   git add .
   git commit -m "feat: 의미 있는 커밋 메시지"
   ```

4. 원격 저장소에 브랜치 푸시:
   ```bash
   git push -u origin feature/your-feature-name
   ```

### 커밋 메시지 규칙

이 프로젝트는 [Conventional Commits](https://www.conventionalcommits.org/) 표준을 따릅니다:

```
<type>(<scope>): <description>

[optional body]

[optional footer(s)]
```

커밋 타입:
- `feat`: 새 기능 추가
- `fix`: 버그 수정
- `docs`: 문서 변경만
- `style`: 코드 작동에 영향을 주지 않는 서식 변경
- `refactor`: 버그 수정이나 기능 추가가 아닌 코드 변경
- `perf`: 성능 향상을 위한 코드 변경
- `test`: 누락된 테스트 추가 또는 기존 테스트 수정
- `chore`: 빌드 프로세스 또는 보조 도구 및 라이브러리 변경

예시:
```
feat(auth): 소셜 로그인 기능 추가

- Google OAuth 인증 구현
- 사용자 프로필 데이터 저장 처리

Resolves: #123
```

## Pull Request 프로세스

### PR 생성

1. GitHub 저장소에서 "New Pull Request" 클릭
2. 원본 브랜치와 대상 브랜치 선택
3. PR 템플릿 작성:
   - 변경 사항 요약
   - 관련 이슈 연결
   - 테스트 방법 설명
   - 스크린샷 또는 동영상(UI 변경의 경우)

### PR 검토

PR이 생성되면 자동화된 검사가 실행됩니다:
- 린트 검사
- 단위 테스트
- 통합 테스트

모든 검사가 통과된 후에는 지정된 리뷰어가 코드를 검토합니다. 리뷰어는 다음을 확인합니다:
- 코드 품질 및 스타일
- 테스트 범위
- 아키텍처 준수
- 성능 고려사항

### PR 병합

PR을 병합하기 위한 기준:
- 모든 자동화된 검사 통과
- 필요한 리뷰 승인 획득(최소 1명의 리뷰어)
- 모든 PR 코멘트 해결
- 충돌 없음

병합 전략으로는 "Squash and merge"를 사용합니다.

## 코드 리뷰 가이드라인

효과적인 코드 리뷰를 위한 가이드라인:

### 리뷰어

- 48시간 이내에 리뷰 완료하기
- 건설적이고 구체적인 피드백 제공하기
- 코드 규칙 및 패턴 일관성 확인하기
- 필요한 경우 직접 코드 개선 방법 제안하기

### 작성자

- 리뷰 전에 자체 코드 검토 수행하기
- 코드 변경 이유와 맥락 설명하기
- 피드백을 개인적으로 받아들이지 않기
- 리뷰어의 질문에 적시에 응답하기

## 릴리스 프로세스

A-Click IoT 프로젝트는 다음 릴리스 프로세스를 따릅니다:

1. **릴리스 브랜치 생성**: `release/v{major}.{minor}.{patch}`
2. **릴리스 후보 테스트**: QA 팀이 릴리스 브랜치를 테스트
3. **버그 수정**: 릴리스 브랜치에서 직접 수정
4. **릴리스 완료**: 
   - 릴리스 브랜치를 `main`에 병합
   - 적절한 태그 생성 (`v{major}.{minor}.{patch}`)
5. **배포**: CI/CD 파이프라인이 태그된 커밋을 프로덕션에 배포

## 문제 해결

일반적인 개발 워크플로우 문제 해결:

### 병합 충돌

1. 최신 메인 브랜치 가져오기:
   ```bash
   git fetch origin main
   ```
2. 현재 브랜치에 메인 브랜치 변경 사항 통합:
   ```bash
   git merge origin/main
   ```
3. 충돌 해결 및 병합 완료:
   ```bash
   git add .
   git commit -m "Merge main into feature branch and resolve conflicts"
   ```

### CI/CD 실패

1. GitHub Actions 로그 검토
2. 로컬에서 같은 명령 실행해 문제 재현
3. 문제 해결 후 새 커밋 푸시

## 추가 리소스

- [Git 브랜칭 모델](https://nvie.com/posts/a-successful-git-branching-model/)
- [Conventional Commits](https://www.conventionalcommits.org/)
- [Taskmaster CLI 문서](https://taskmaster-cli.dev/)
