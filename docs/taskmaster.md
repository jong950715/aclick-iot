# Taskmaster 사용 가이드

이 문서는 A-Click IoT 프로젝트에서 사용하는 Taskmaster CLI 도구의 사용 방법을 설명합니다.

## Taskmaster란?

Taskmaster는 프로젝트의 작업 관리를 위한 CLI 도구로, 다음과 같은 기능을 제공합니다:

- 작업 생성 및 관리
- 작업 상태 추적
- 작업 종속성 관리
- 작업 복잡도 분석
- 작업 분해(하위 작업 생성)

## 설치

Taskmaster는 두 가지 방식으로 사용할 수 있습니다:

### 1. 전역 CLI 도구로 설치

```bash
# npm을 통한 전역 설치
npm install -g claude-task-master

# 또는 npm 최신 버전에서
npm install -g task-master
```

### 2. 프로젝트 스크립트로 사용

프로젝트에는 이미 `scripts/dev.js` 스크립트가 포함되어 있어 별도 설치 없이 사용 가능합니다:

```bash
# 스크립트를 통한 사용
node scripts/dev.js <command>
```

## 기본 명령어

### 작업 목록 보기

```bash
# 전역 CLI 사용 시
task-master list

# 스크립트 사용 시
node scripts/dev.js list
```

이 명령은 모든 작업 목록과 각 작업의 ID, 제목, 상태, 종속성을 표시합니다.

### 특정 작업 상세 정보 보기

```bash
# 전역 CLI 사용 시
task-master show <task-id>

# 스크립트 사용 시
node scripts/dev.js show <task-id>
```

예: `task-master show 1.2`

### 작업 상태 변경

```bash
# 전역 CLI 사용 시
task-master set-status --id=<task-id> --status=<status>

# 스크립트 사용 시
node scripts/dev.js set-status --id=<task-id> --status=<status>
```

가능한 상태 값:
- `pending`: 대기 중
- `in-progress`: 진행 중
- `done`: 완료됨
- `review`: 검토 중
- `deferred`: 연기됨
- `cancelled`: 취소됨

예: `task-master set-status --id=1.2 --status=done`

## 작업 생성 및 관리

### 새 작업 추가

```bash
# 전역 CLI 사용 시
task-master add-task --prompt="작업 설명"

# 스크립트 사용 시
node scripts/dev.js add-task --prompt="작업 설명"
```

예: `task-master add-task --prompt="로그인 화면 구현 - 이메일 및 비밀번호 입력 폼, 유효성 검증, 인증 처리"`

### 작업 의존성 추가

```bash
# 전역 CLI 사용 시
task-master add-dependency --id=<task-id> --dependsOn=<dependency-id>

# 스크립트 사용 시
node scripts/dev.js add-dependency --id=<task-id> --dependsOn=<dependency-id>
```

예: `task-master add-dependency --id=2.3 --dependsOn=2.1`

### 작업 의존성 제거

```bash
# 전역 CLI 사용 시
task-master remove-dependency --id=<task-id> --dependsOn=<dependency-id>

# 스크립트 사용 시
node scripts/dev.js remove-dependency --id=<task-id> --dependsOn=<dependency-id>
```

예: `task-master remove-dependency --id=2.3 --dependsOn=2.1`

## 작업 분석 및 분해

### 작업 복잡도 분석

```bash
# 전역 CLI 사용 시
task-master analyze-complexity --research

# 스크립트 사용 시
node scripts/dev.js analyze-complexity --research
```

`--research` 플래그는 심층 분석을 활성화합니다. 이 명령은 `scripts/task-complexity-report.json` 파일을 생성합니다.

### 복잡도 보고서 보기

```bash
# 전역 CLI 사용 시
task-master complexity-report

# 스크립트 사용 시
node scripts/dev.js complexity-report
```

### 작업 분해

```bash
# 전역 CLI 사용 시
task-master expand --id=<task-id> [--subtasks=<number>] [--research] [--prompt="추가 컨텍스트"]

# 스크립트 사용 시
node scripts/dev.js expand --id=<task-id> [--subtasks=<number>] [--research] [--prompt="추가 컨텍스트"]
```

옵션:
- `--subtasks=<number>`: 생성할 하위 작업 수 (선택적)
- `--research`: 심층 연구를 통한 하위 작업 생성 (선택적)
- `--prompt="추가 컨텍스트"`: 하위 작업 생성을 위한 추가 정보 (선택적)

예: `task-master expand --id=3.1 --subtasks=5 --research --prompt="React 컴포넌트로 구현하고 스타일링은 CSS 모듈 사용"`

### 하위 작업 제거

```bash
# 전역 CLI 사용 시
task-master clear-subtasks --id=<task-id>

# 스크립트 사용 시
node scripts/dev.js clear-subtasks --id=<task-id>
```

예: `task-master clear-subtasks --id=3.1`

## 작업 업데이트

### 다중 작업 업데이트

특정 ID 이후의 모든 작업을 업데이트합니다:

```bash
# 전역 CLI 사용 시
task-master update --from=<task-id> --prompt="변경 사항 설명"

# 스크립트 사용 시
node scripts/dev.js update --from=<task-id> --prompt="변경 사항 설명"
```

예: `task-master update --from=4 --prompt="GraphQL 대신 REST API를 사용하는 것으로 변경되었습니다."`

### 단일 작업 업데이트

```bash
# 전역 CLI 사용 시
task-master update-task --id=<task-id> --prompt="변경 사항 설명"

# 스크립트 사용 시
node scripts/dev.js update-task --id=<task-id> --prompt="변경 사항 설명"
```

예: `task-master update-task --id=3.2 --prompt="React 컴포넌트를 클래스형에서 함수형으로 변경"`

## 작업 파일 생성

```bash
# 전역 CLI 사용 시
task-master generate

# 스크립트 사용 시
node scripts/dev.js generate
```

이 명령은 `tasks/tasks.json` 파일을 기반으로 개별 작업 파일을 `tasks/` 디렉토리에 생성합니다.

## 다음 작업 찾기

```bash
# 전역 CLI 사용 시
task-master next

# 스크립트 사용 시
node scripts/dev.js next
```

이 명령은 종속성 그래프를 기반으로 다음에 작업할 수 있는 작업을 제안합니다.

## 종속성 관리

### 종속성 유효성 검사

```bash
# 전역 CLI 사용 시
task-master validate-dependencies

# 스크립트 사용 시
node scripts/dev.js validate-dependencies
```

### 종속성 문제 수정

```bash
# 전역 CLI 사용 시
task-master fix-dependencies

# 스크립트 사용 시
node scripts/dev.js fix-dependencies
```

## 모델 관리

AI 모델 설정을 관리합니다:

```bash
# 전역 CLI 사용 시
task-master models

# 스크립트 사용 시
node scripts/dev.js models
```

## 작업 파일 형식

개별 작업 파일은 다음 형식을 따릅니다:

```
# Task ID: <id>
# Title: <title>
# Status: <status>
# Dependencies: <comma-separated list of dependency IDs>
# Priority: <priority>

# Description:
<brief description>

# Details:
<detailed implementation notes>

# Test Strategy:
<verification approach>
```

## 모범 사례

### 작업 관리 워크플로우

1. **작업 식별 및 생성**: 새 기능이나 변경사항을 작업으로 생성
2. **작업 분석**: 복잡한 작업은 `analyze-complexity` 명령으로 분석
3. **작업 분해**: 복잡한 작업은 `expand` 명령으로 하위 작업으로 분해
4. **작업 구현**: 작업 상태를 `in-progress`로 변경하고 구현 시작
5. **업데이트**: 구현 중 변경사항이 있으면 `update-task` 명령으로 작업 업데이트
6. **완료**: 작업 완료 후 상태를 `done`으로 변경

### 유용한 팁

- 작업 ID는 계층 구조를 나타냅니다 (예: `1.2.3`은 1번 작업의 2번 하위 작업의 3번 하위 작업)
- 종속성 관리를 통해 작업 순서를 효과적으로 계획할 수 있습니다
- 주기적으로 `validate-dependencies`를 실행하여 종속성 문제를 확인하세요
- 중요한 컨텍스트 변경 시 `update --from` 명령을 사용하여 영향받는 모든 작업을 업데이트하세요

## 문제 해결

### 일반적인 문제

#### 작업 파일이 생성되지 않는 경우

```bash
# 수동으로 작업 파일 생성
task-master generate
```

#### 종속성 오류가 발생하는 경우

```bash
# 종속성 문제 해결
task-master fix-dependencies
```

#### 작업 업데이트가 적용되지 않는 경우

작업 상태가 `done`인 경우 업데이트되지 않습니다. 상태를 변경 후 다시 시도하세요:

```bash
task-master set-status --id=<task-id> --status=pending
task-master update-task --id=<task-id> --prompt="변경 사항"
```
