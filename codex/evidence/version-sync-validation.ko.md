# 버전 동기화 검증 기록

2026-10-14, Windows PowerShell 5.1 / WSL2 Ubuntu, 작업 브랜치 feat/codex-version-sync.

## 실제 빌드

공식 rust-v0.162.1, commit 092d3acd6bec3e3a14bdc7e7a2810ab628ab759d. 기능 패치의 SHA-256은 c8932f73ad9ce5a5c5f1a30965f2f08c1a21f0880f23ae23e368518de803bc14다.

Rust 1.95.0·기존 MSVC BuildTools로 Windows dev 빌드 성공, 5분 39초. 버전·도움말 검사 성공. word_completion 16개 및 chat_composer/history 411개 통과. 411개에는 자동완성 16개가 포함된다. 실행 파일은 무시된 개발 캐시이며 사용자 명령에 설치하지 않았다.

## 자동 업데이트 검증

Windows: 엄격한 버전·배포 인덱스 파싱, 정확한 플랫폼 선택, 최초 다운로드, 오프라인 정상 캐시, 같은 버전 패치 갱신, 손상 캐시 복구, 잘못된 다운로드 시 이전 캐시 보존, 동시 잠금, 공식 버전 변경 경쟁 재시도 및 반복 변경 거부를 fixture로 검사했다.

npm updater: 자동완성 배포 부재 시 공식 변경 금지, exact npm target, 같은 공식 버전 패치 갱신, 미지원 설치 방식 차단, 설치 실패 노출을 검사했다. 사용자 npm 설치를 실제 변경하지 않았다.

런처: 인자·빈 문자열·따옴표·끝 역슬래시·cwd·CODEX_HOME·자식에만 자동완성 환경변수·exit code·update 분리 검사를 통과했다.

WSL2: POSIX 다운로드·캐시·런처·npm updater fixture 통과. Darwin/arm64 플랫폼 선택은 WSL에서 모의 검사했다. 실제 Mac 실행을 뜻하지 않는다.

CI: stable backlog·draft/prerelease 제외·중복 제거·필수 파일·패치 해시·실패 억제·재시도 정책 검사. 공유 TSV 인덱스 검사. 배포 fixture에서 미리보기 무게시, 해시 불일치 차단, 양쪽 파일 검증, draft 업로드 후 공개, 인덱스 게시, 공개 태그 불변성 검사. 실제 GitHub API 게시 없이 수행했다.

actionlint 1.7.12로 두 workflow의 YAML 문법·job 의존성·표현식·reusable 연결 검사 통과. 개발 캐시에만 검사 도구를 받았고 사용자 의존성에 추가하지 않았다.

## 미검증

GitHub native release 빌드·실제 배포/다운로드·Actions 이메일 수신, macOS 실기기·IME·서버/세션, 새 Windows live TUI, 전체 Rust suite는 아직 확인하지 않았다. WSL은 Mac 대체가 아니다.

기존 사용자의 설치된 codex-auto/PATH/프로필/공식 Codex는 변경하지 않았다. 공개 릴리스가 없으며 자동 업데이트는 활성화되지 않았다. 2026-10-15 GitHub 반영 준비에서 예약 트리거를 제거했고 첫 검증은 수동 미리보기만 허용한다.

## 다음 검증

workflow를 기본 브랜치에 반영한 뒤 수동 version=0.162.1, publish=false로 네이티브 빌드를 확인한다. 성공 시 publish=true로 첫 배포 및 공유 인덱스를 만든다. 이후 ZIP 설치와 공식 버전 변경 후 다운로드를 Windows/Mac에서 확인한다. Mac 후보·Tab·Esc·한글 조합과 서버 연결은 실제 사용자 터미널에서 검사한다.

## 2026-10-15 첫 GitHub 미리보기 실패와 수정

[실행 38667389270](https://github.com/magatone/claude-autocomplete/actions/runs/38667389270): discovery 성공, Windows·macOS 모두 공통 사전 검사에서 실패했다. Rust 컴파일과 공개 배포는 실행되지 않았다.

Windows는 CRLF로 checkout한 here-string fixture의 기대값이 LF만 가정해 실패했다. fixture를 명시적으로 LF로 정규화하고 CRLF lockfile 보존 검사는 유지했다. 수정 전 실패를 CRLF 파일 복사본으로 재현했고 수정 후 PowerShell 5.1·7.6.7에서 통과했다.

Mac은 /var와 /private/var 경로 별칭을 다른 checkout으로 판단했다. Git --show-prefix로 실제 checkout 루트 여부를 검사하도록 수정했다. Windows junction 회귀로 수정 전 동일 실패를 재현했으며 수정 후 별칭 루트 허용·하위 디렉터리 거부·checkout 보호가 통과했다.

PowerShell 7 공통 CI 검사 전체가 로컬에서 통과했다. 실제 Mac 수정본 실행·최적화 빌드는 재검증해야 한다. 이전 Re-run jobs는 이전 커밋으로 재실행하므로 수정 브랜치 또는 수정 병합 후 main에서 새 Run workflow를 사용한다. 버전 0.162.1, retry_failed=true, publish=false로 실행한다.
