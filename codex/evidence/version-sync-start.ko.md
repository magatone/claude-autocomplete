# 버전 동기화 착수 검증 기록

검사일: 2026-10-14. 프로젝트: D:/code/claude-autocomplete. 브랜치: feat/codex-version-sync.

## 결과

- 기존 check-launcher.ps1: PASS. 데이터 홈·관리 서버·내장 fallback·인자·환경·종료 코드 7 유지.
- 기존 check-build-patch.ps1: PASS. fresh/repeated 적용 및 staged/untracked/unrelated 변경 보호.
- 새 검사기 미구현 상태: RED 확인.
- 새 check-release-patch-tests.ps1: PASS. 명시적·기본 Patch 경로, 공백 Source 경로, metadata lockfile 제외, 실제 기능 변경 없이 확인, dirty/conflict/untracked 거부와 파일 보존.
- 공식 rust-v0.162.1 HEAD: 092d3acd6bec3e3a14bdc7e7a2810ab628ab759d.
- 전체 기존 패치: Cargo.lock 충돌로 apply --check 실패.
- Cargo.lock 제외 기능 패치: apply --check PASS.
- 실제 checkout에서 새 check-release-patch.ps1: PASS. git status --porcelain은 빈 결과.

## 재현

~~~powershell
powershell.exe -NoProfile -File ./codex/check-launcher.ps1
powershell.exe -NoProfile -File ./codex/check-build-patch.ps1
powershell.exe -NoProfile -File ./codex/check-release-patch-tests.ps1
powershell.exe -NoProfile -File ./codex/check-release-patch.ps1 -Source ./codex/source/rust-v0.162.1
~~~

충돌 fixture는 git apply 실패 메시지를 의도적으로 출력한다. 그 거부를 확인하고 최종 PASS로 끝나야 정상이다.

## 아직 확인하지 않은 것

0.162.1 실제 컴파일·Rust 회귀·새 다운로드/캐시/update 런처·Actions 원격 실행·공개 배포·WSL 및 macOS 네이티브 실행은 미검증이다. 로컬 PATH에서 cargo/rustup은 발견되지 않았다. Git Bash가 실행 가능하다는 것은 Mac 검증이 아니다.

현재 공식 codex update에는 목표 버전 지정 옵션이 없다. 준비된 버전으로 함께 갱신하는 첫 어댑터는 기존 npm 설치에 대해 정확한 버전을 지정하는 방식으로 구현한다. 다른 설치 방식은 검증 전 지원 완료로 취급하지 않는다.

다음 작업: 기능 패치와 릴리스 버전 메타데이터 분리 후 0.162.1 실제 빌드·회귀 검사.

## 다음 단계 검증 결과

0.162.1 Windows 개발 CLI 빌드가 5분 39초에 성공했다. 실행 파일은 codex/bin/0.162.1-dev/codex.exe이며 --version 0.162.1과 --help 시작을 확인했다. 새 개발 toolchain은 C:/Users/User/.cxl에만 준비했고 시스템 PATH는 변경하지 않았다.

회귀 컴파일에서 SkillMetadata 경로 타입 변경을 발견해 테스트 fixture에 Into 변환을 추가했다. 수정 이후 자동완성 16개와 입력창·히스토리 411개 검사가 통과했다. 411개에 자동완성 검사가 포함되므로 고유 검사 수를 427개로 더하지 않는다. 실제 터미널·IME·Mac, 최적화 release 빌드, 공개 배포는 미검증이다.

새 workspace-only lockfile 처리 함수는 외부 registry 패키지·이름 충돌·CRLF를 보존하며 기존 검증된 0.161.0 lockfile을 정확히 재현했다. 기존 빌드의 두 패치 적용·반복·사용자 변경 보호 검사와 런처 인자·환경·종료 코드 검사가 통과했다.

버전 stdout 파서와 릴리스 선정 정책도 fixture 검사를 통과했다. 다운로드·캐시·update 명령·Actions workflow 및 실제 알림 수신은 아직 구현·검증 전이다. 사용자 GitHub 설정 완료는 사용자 보고로 기록했다.
