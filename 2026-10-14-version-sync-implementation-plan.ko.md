# Codex 자동 버전 동기화 구현 계획서

> Agent 실행 방식: executing-plans로 아래 작업을 순서대로 수행한다. 사용자 지정 저장소에서 작업하며 별도 subagent는 사용하지 않는다.

**목표:** 사용자에게 Python·Git·Rust·컴파일러 설치를 요구하지 않고, 버전별 사전 빌드 배포와 codex-auto 실행·update 명령으로 공식 CLI와 자동완성 버전을 맞춘다.

**구조:** CI가 공식 릴리스를 감지해 수정 CLI를 빌드·검증·배포한다. Windows PowerShell 및 POSIX 셸 런처는 버전별 배포 파일을 검증·캐시·실행한다. 공식 CLI 변경은 update 명령에서만 수행하며 설치 방식별 정확한 버전 지정이 가능한 경우에만 지원한다.

**기술:** 사용자 환경은 PowerShell 5.1/.NET 또는 /bin/sh·curl·shasum. 개발·CI는 Git·Rust·Cargo·OS별 빌드 도구 및 CI 제공 PowerShell. 작업 위치 D:/code/claude-autocomplete, 브랜치 feat/codex-version-sync.

## 공통 제한

- 일반 사용자에게 새 런타임·패키지·컴파일러를 설치하지 않는다.
- 공식 버전 전체, 패치 개정, OS/아키텍처를 정확히 선택한다. prerelease 자동 배포는 첫 범위에서 제외한다.
- 최초 지원 버전은 0.161.0. 0.162.1 실제 패치·빌드·회귀를 첫 전환 기준으로 삼는다.
- 지원 파일이 없거나 검사 실패 시 실행하지 않는다. 구버전 자동 우회와 사용자 PC 빌드는 금지한다.
- 인증·세션·config 및 기존 공식 CLI를 일반 실행 중에 변경하지 않는다.
- 버전 확인·다운로드 중 공식 버전 변경은 1회 재시도 후 중단한다.
- Windows x64, macOS arm64를 각각 검증한다. WSL2 Linux x64는 공통 검증용이다.
- 실제 Mac 입력·IME·기존 서버 확인 전에는 Mac 지원 완료를 선언하지 않는다.
- 각 작업은 실패 테스트 → 최소 구현 → 성공 테스트 순서다. 체크박스와 실제 결과를 갱신한다.
- 검증 전 공개 배포를 완료 처리하지 않는다. 코드·문서 준비와 계정·원격 실행을 구분한다.

## 역할과 사용자 확인 시점

**에이전트:** 아래 코드·워크플로·테스트·문서·검증과 가능한 저장소 설정을 수행한다.

**사용자:** GitHub 개인 계정의 Actions 실패 알림 수신 설정을 확인한다. 원격 권한이 연결되지 않은 경우 계정 연결을 제공하며 비밀값은 채팅으로 보내지 않는다. Mac 또는 테스트 가능한 사람을 통한 Terminal·IME·세션 검사를 수행한다. 실제 공개 배포 전 준비된 결과를 확인한다.

**지금 사용자가 설치할 것은 없다.** 내 초기 패치·런처 작업은 사용자 계정 설정이나 Mac 확보 없이 진행할 수 있다. 원격 실행과 Mac 검사가 필요한 단계에서 정확한 확인 항목을 전달한다.

## 작업 0 기능 패치 사전 검사부터 시작

**파일:** 생성 codex/check-release-patch.ps1, codex/check-release-patch-tests.ps1, codex/evidence/version-sync-start.ko.md.

**입력:** check-release-patch.ps1 -Source <깨끗한 upstream checkout> [-Patch <패치 경로>]. Patch 기본값은 codex/inline-word-completion.patch.

**동작:** Git 및 파일 존재 확인 → checkout 자체 루트 확인 → staged/untracked/수정 파일 거부 → Cargo.lock 제외 기능 패치 apply --check → 변경하지 않고 성공 메시지. 기존 build.ps1 및 0.161.0 실험을 바꾸지 않는다.

- [x] 기존 check-launcher.ps1과 check-build-patch.ps1을 독립 프로세스에서 실행해 기준 통과를 확인한다.
- [x] ignored codex/source/rust-v0.162.1에 공식 소스를 준비한다. HEAD 092d3acd6bec3e3a14bdc7e7a2810ab628ab759d를 기록한다.
- [x] 전체 패치의 Cargo.lock 충돌과 기능 패치 apply --check 통과를 확인한다.
- [x] 깨끗한 적용 가능 checkout은 성공, 불일치 내용은 실패, dirty checkout은 실패하고 기존 파일이 보존되는 테스트를 작성한다.
- [x] 검사 스크립트가 없는 상태에서 테스트 실패를 확인한다.
- [x] check-release-patch.ps1을 구현한다. 핵심 명령은 아래와 같다.

~~~powershell
git -C $Source apply --check --exclude=codex-rs/Cargo.lock $Patch
if ($LASTEXITCODE -ne 0) { throw 'Feature patch does not apply.' }
~~~

- [x] powershell.exe -NoProfile -File ./codex/check-release-patch-tests.ps1 실행 후 PASS를 확인한다.
- [x] 실제 0.162.1 checkout에서 같은 스크립트 실행 및 git status --porcelain 빈 결과를 확인한다. 이는 빌드 성공과 구분해 기록한다.

## 작업 1 기능 패치와 릴리스 메타데이터 분리

**파일:** 수정 codex/inline-word-completion.patch, codex/build.ps1, codex/check-build-patch.ps1. 생성 codex/build-release.ps1, codex/check-release-build.ps1.

**인터페이스:** build-release.ps1 -Version <정식 버전> -Source <별도 checkout> -OutputDirectory <결과 폴더>. 결과는 타깃별 바이너리, SHA256 파일, release-info.txt. build.ps1은 기존 고정 실험을 유지하거나 검증된 새 빌더로 위임하며 사용자 변경 checkout 보호를 유지한다.

- [ ] git diff 패키지 순서와 Cargo.lock 정합성 실패를 재현하는 테스트를 작성한다.
- [ ] 기능 패치에서 Cargo.lock diff를 분리한다. 새 빌더는 해당 태그의 workspace 버전과 Rust toolchain을 읽는다.
- [ ] lockfile의 source가 없는 workspace 패키지만 현재 workspace version과 맞춘다. 외부 dependency 변경이 없음을 diff로 확인한다. upstream Cargo metadata와 package 목록을 기준으로 결정하며 전역 문자열 치환은 하지 않는다.
- [ ] 새 빌더가 user checkout을 초기화하거나 기존 결과를 덮어쓰지 않는지 검사한다.
- [ ] toolchain 준비 이후 아래 명령을 실행한다. 프로필은 처음 개발 빌드로 재현한 뒤 배포 단계에서 release를 사용한다.

~~~sh
cargo build --locked -p codex-cli --bin codex
cargo test --locked -p codex-tui word_completion
cargo test --locked -p codex-tui chat_composer
cargo build --locked --release -p codex-cli --bin codex
~~~

- [ ] 0.161.0과 0.162.1에서 --version, 자동완성 테스트, 격리 홈 시작을 검사한다. CI 자원·의존성 실패는 패치 충돌과 구분한다.
- [ ] 기존 build·launcher 보호 검사를 다시 통과시키고 결과·미검증 범위를 기록한다.

## 작업 2 Windows 다운로드와 캐시

**파일:** 생성 codex/sync.ps1, codex/check-sync.ps1. 수정 codex/run.ps1, codex/check-launcher.ps1, codex/install-command.ps1.

**인터페이스:** sync.ps1을 dot-source하며 Get-CodexVersion -Output <stdout 문자열>은 검증된 버전 문자열을 반환한다. Get-CodexAutoBinary -CodexPath <확정한 공식 경로> -RefreshPatch <bool>은 검증된 절대 바이너리 경로를 반환한다. 오류는 throw, 진행 안내는 stderr/Warning, 반환값에는 로그를 섞지 않는다. 다운로드 위치는 magatone/claude-autocomplete GitHub Releases로 고정한다.

- [ ] 버전 출력·손상 해시·누락 배포·오프라인 캐시·동시 실행·업데이트 경쟁 테스트를 먼저 작성한다. 버전 입력 예는 아래와 같다.

~~~powershell
$version = Get-CodexVersion -Output 'codex-cli 0.162.1'
if ($version -cne '0.162.1') { throw 'Version parse failed.' }
~~~

- [ ] 예상 형태 전체를 검증하고 버전·플랫폼 값 검증을 파일 경로 생성 전에 수행한다.
- [ ] LOCALAPPDATA/codex-auto 캐시, 고정 HTTPS 다운로드, SHA256 및 실제 --version 확인, 임시→준비완료 이동, 키별 잠금을 구현한다.
- [ ] 실제 Codex 탐색은 현재 사용자 command resolution을 보존하고 자기 자신·수정 바이너리를 거부한다. official .ps1/.cmd 및 native binary를 fixture로 검사한다.
- [ ] run.ps1은 반환된 경로를 기존 ProcessStartInfo 실행 로직에 연결한다. no-daemon 판단·인자 escaping·CODEX_HOME 상속은 유지한다.
- [ ] 설치기는 source 빌드 완료 전제를 제거하고 런처를 등록한다. 사용자 시스템의 실제 공식 Codex 업데이트나 PATH 변경은 fixture 검사와 분리한다.
- [ ] Python·Git·Rust가 없는 제한 PATH fixture에서 동작을 확인한다. 기존 종료 코드 7 및 공백·빈 인자 검사도 통과해야 한다.

## 작업 3 Mac WSL POSIX 런처

**파일:** 생성 codex/sync.sh, codex/run.sh, codex/install-command.sh, codex/check-sync.sh, codex/check-launcher.sh. 언어별 fixture로 동일 프로토콜 검사.

**인터페이스:** sync.sh를 source하며 codex_version <stdout>은 정식 버전을 출력한다. codex_auto_binary <공식 실행 파일 경로> <refresh|cached>는 검증된 절대 바이너리 경로만 stdout에 출력한다. 실패는 nonzero. Windows와 같은 릴리스 태그·파일명·캐시 정책을 사용한다.

- [ ] sh stub과 공통 fixture로 버전·인자·환경·종료 코드 및 다운로드 실패 검사를 작성한다.
- [ ] /bin/sh 구문만 사용한다. uname으로 플랫폼을 분류하고 unsupported target을 거부한다.
- [ ] curl 및 macOS shasum -a 256, Linux sha256sum을 실행 전 점검한다. jq·Python·GNU 전용 옵션을 요구하지 않는다.
- [ ] HOME/.cache 또는 XDG_CACHE_HOME 캐시와 실행 권한, 잠금, 검증 완료 디렉터리 전환을 구현한다.
- [ ] run.sh는 env CODEX_WORD_AUTOCOMPLETE=1과 exec를 사용하고 인자를 그대로 전달한다. --no-daemon은 사용자가 지정한 경우만 전달한다.
- [ ] 아래 검사를 WSL2 또는 Linux CI와 실제 macOS runner에서 각각 수행한다.

~~~sh
sh -n codex/sync.sh codex/run.sh codex/install-command.sh
sh codex/check-sync.sh
sh codex/check-launcher.sh
~~~

- [ ] Git Bash 로컬 검사는 POSIX 기본 검사로만 기록한다. Linux와 Mac 네이티브 실행 검증으로 확대 해석하지 않는다.

## 작업 4 codex-auto update 명령

**파일:** 생성 codex/update.ps1, codex/update.sh, codex/check-update.ps1, codex/check-update.sh. 수정 run.ps1/run.sh.

**인터페이스:** 런처 첫 인자가 정확히 update일 때 관리 명령으로 처리한다. -- 뒤의 update와 프롬프트 텍스트는 가로채지 않는다. update 명령은 현재 및 목표 버전·결과를 출력하고 성공 0/실패 nonzero로 종료한다. 일반 입력창을 시작하지 않는다.

- [ ] 준비되지 않은 목표 버전에서는 official installer가 호출되지 않는 테스트를 먼저 작성한다.
- [ ] 프로젝트 준비 완료 릴리스 및 공식 npm 버전을 조회하고 목표 정식 버전을 결정한다. prerelease나 임의 main은 선택하지 않는다.
- [ ] 목표 자동완성 파일과 공식 npm 패키지 조회·다운로드 가능성을 검증한 뒤 정확한 설치 호출을 수행한다.

~~~sh
npm install -g @openai/codex@0.162.1
~~~

- [ ] npm 호출은 해당 npm 설치의 확인된 명령 경로를 사용하며 새 npm을 설치하지 않는다. 목표 버전은 검증된 값으로만 전달한다.
- [ ] 같은 공식 버전의 새 패치 개정도 갱신한다. installer 실패·권한 부족·PATH 변경·최종 버전 불일치·외부 update 경쟁을 검사한다.
- [ ] 지원하지 않는 standalone/Homebrew 설치는 변경 전에 설명하고 중단한다. 설치 어댑터의 정확한 타깃·복구 검증을 완료하기 전 자동 지원으로 표기하지 않는다.
- [ ] 공식 최신 업데이트를 무조건 실행하지 않는다. 사전 검증한 버전과 다른 버전을 설치할 수 있는 codex update 호출로 대체하지 않는다.
- [ ] 계정·세션·공식 CLI를 실제로 변경하지 않는 installer stub 테스트를 먼저 완료한다. 실제 설치 검증은 격리 prefix를 사용한다.

## 작업 5 Actions 릴리스 감지와 OS별 빌드

**파일:** 생성 .github/workflows/codex-auto-release.yml, codex/ci/discover.ps1, codex/ci/check-discovery.ps1, codex/ci/publish.ps1.

**인터페이스:** discovery는 공식 릴리스·우리 릴리스·실패 상태를 받아 Version, UpstreamCommit, PatchRevision을 출력한다. 워크플로는 목표 버전과 패치 SHA를 matrix의 불변 입력으로 전달한다. 결과물 이름은 codex-auto-windows-x64.exe, codex-auto-macos-arm64 및 각 .sha256. 태그 예는 codex-0.162.1-p1.

- [ ] 여러 릴리스가 검사 사이에 나와도 누락되지 않는 fixture, draft/prerelease 제외, 누락 assets 재처리, 실패의 예약 반복 억제·수동 재시도 검사를 작성한다.
- [ ] 공식 릴리스 목록은 페이지네이션을 적용한다. 조회 오류는 빈 목록으로 처리하지 않는다.
- [ ] 첫 cron은 아래와 같이 기본 브랜치에 둔다. workflow_dispatch는 특정 버전과 재시도 선택을 받는다.

~~~yaml
on:
  schedule:
    - cron: '17 * * * *'
  workflow_dispatch:
    inputs:
      version:
        description: 'Exact stable Codex version, or empty for discovery'
        required: false
~~~

- [ ] 빌드는 windows-2022 x64와 macos-15 arm64를 사용하고 실제 runner 아키텍처를 검사한다. Linux 검사는 ubuntu-24.04로 수행한다.
- [ ] actions 버전은 구현 시 실제 검증한 commit SHA로 고정한다. 기본 contents:read, publish job만 contents:write를 사용하고 GITHUB_TOKEN을 활용한다.
- [ ] 공개 전 필수 파일·해시·버전·테스트 결과가 모두 있어야 한다. 임시 draft는 준비 완료로 취급하지 않으며 실패한 작업은 공개 배포하지 않는다.
- [ ] 버전·패치별 concurrency, 디스크 여유, Rust 캐시, 작업 timeout을 명시한다. release build는 소스와 라이선스·NOTICE 제공도 포함한다.
- [ ] 실패 로그에 버전·단계·원인을 남기고 workflow를 실패시킨다. 실패 기록 재사용은 계정의 알림을 없애는 것과 구분한다.
- [ ] push 전 로컬 discovery 테스트와 YAML 파싱 검사를 마친다. 원격 Actions 실행·공개 배포는 실제 권한과 검증 결과를 확인한 뒤 처리한다.

## 작업 6 사용자 검증과 지원 상태

**파일:** 수정 README.md, README.ko.md, codex/README.md, codex/README.ko.md. 생성 codex/evidence/version-sync-validation.ko.md.

- [ ] 문서에서 과거 고정 소스 빌드 안내를 개발자 절차로 분리한다. 두 명령과 첫 다운로드·미지원 버전·오프라인·복구 안내를 작성한다.
- [ ] Windows 실제 CLI, WSL/Linux fixture, macOS runner 검사 결과를 날짜·타깃·커밋과 함께 기록한다.
- [x] GitHub 알림·Actions·기본 읽기 권한 설정을 안내했고 사용자가 설정 완료를 보고했다. 실제 실패 알림 수신 검증과 cron 수신 계정 확인은 workflow 준비 후 수행한다.
- [ ] 사용자 Mac에서는 공식 codex 및 codex-auto 버전, 후보·Tab·Esc·Enter·한글 IME·서버 연결·세션 조회를 확인한다. 모델 메시지를 자동 전송하지 않는다.
- [ ] Mac 실제 검사가 남으면 미검증으로 표시한다. 다운로드 성공을 네이티브 CLI 검증 성공으로 표현하지 않는다.

## 단계별 종료 기준

**첫 단계:** 기획서·구현 계획 저장, 기존 기준 테스트, 0.162.1 적용 감사와 비파괴 검사 테스트 완료. 아직 새 실행 파일·배포·자동 업데이트가 완성됐다는 뜻은 아니다.

**두 번째 단계:** 실제 버전별 빌드와 두 OS 런처·update의 fixture 테스트 완료. 원격 계정·Mac 실기기 없이 가능한 작업은 여기까지 먼저 수행한다.

**최종 단계:** GitHub Actions 실제 빌드·검증·배포와 사용 환경별 설치·업데이트 확인. 사용자에게 실제로 필요한 계정·Mac 확인만 남긴다.

## 검증된 근거와 현재 상태

기준 테스트 2개는 통과했다. 0.162.1 공식 소스 HEAD는 092d3acd6bec3e3a14bdc7e7a2810ab628ab759d이다. 기존 패치는 Cargo.lock에서 실패하며 이를 제외한 기능 패치는 apply --check가 통과했다. 현재 로컬 PATH에서 cargo/rustup은 발견되지 않았으며 실제 컴파일은 미실행이다. Git Bash는 권한 있는 로컬 실행에서 사용 가능하지만 WSL/Mac 네이티브 검증은 아니다.

관련 공식 문서: [Actions 예약](https://docs.github.com/en/actions/reference/workflows-and-actions/events-that-trigger-workflows#schedule), [Runner 타깃](https://docs.github.com/en/actions/reference/runners/github-hosted-runners), [Actions 알림](https://docs.github.com/en/actions/concepts/workflows-and-actions/notifications-for-workflow-runs).


**착수 결과:** 작업 0 완료. 기본 Patch 경로, 공백 경로, lockfile 제외, dirty/conflict/untracked 입력 거부 및 upstream checkout 비변경 검사를 통과했다. 작업 1 이후와 실제 바이너리 빌드·CI·Mac 검증은 미완료다.

## 추가 진행 기록

2026-10-14 사용자 GitHub 설정 완료 보고를 반영했다. Rust 1.95.0을 개발 캐시 C:/Users/User/.cxl에 준비했고 시스템 PATH는 수정하지 않았다. Windows MSVC BuildTools가 이미 설치되어 있다.

기능 패치와 0.161.0 고정 메타데이터를 분리했고, 기존 두 패치 최초·반복 적용 및 checkout 보호 테스트가 통과했다. 새 release-lock 함수는 workspace 패키지만 갱신하며 검증된 0.161.0 lockfile을 재현했다. 0.162.1 Windows 개발 빌드가 5분 39초에 성공했고 --version은 0.162.1이다.

0.162.1에서 테스트 fixture의 경로 타입 변경이 발견되어 Into 변환으로 수정했다. Rust 자동완성·입력창 검사는 진행 중이다. 버전 출력 파서와 릴리스 선정 정책 테스트는 통과했지만 다운로드·캐시·update 명령·Actions workflow는 아직 구현하지 않았다.

**회귀 완료:** 타입 fixture 수정 후 0.162.1 word_completion 16개, chat_composer/history 411개 검사 통과. 411개에는 자동완성 검사가 포함된다. release 프로필·live TUI·Mac·배포는 남아 있다.

## 2026-10-14 현재 구현 상태, 이전 진행 기록 이후

완료: 기능·lockfile 패치 분리, Windows 0.162.1 개발 빌드·입력창 회귀, Windows/POSIX 버전 선택·다운로드·검증·캐시 런처, npm 한정 update, ZIP 설치기, Actions 탐지·네이티브 빌드·검증·게시 코드와 로컬 fixture/actionlint 검사.

남음: 원격 workflow 최초 실행, optimized release 빌드, 실제 GitHub 게시/다운로드, 새 런처 실제 설치, 실패 이메일 수신, Mac 실기기/IME/서버 검증. 설치된 사용자 Codex와 기존 codex-auto는 변경하지 않았다.

실제 공용 인덱스는 JSON 대신 index.tsv를 사용한다. 헤더 codex-auto-index-v1, 이후 버전·패치번호·플랫폼·SHA-256 네 필드를 탭으로 구분한다. POSIX에서 jq/Python을 요구하지 않으려는 결정이다. URL은 고정 GitHub 저장소/태그/파일명으로만 생성한다. 언어별 독립 fixture는 같은 프로토콜을 검사한다.

Actions 파일은 codex-auto-release.yml 및 reusable codex-auto-build.yml이다. CI 스크립트는 codex/ci/discover.ps1, build.ps1, publish.ps1, refresh-index.ps1, record-failure.ps1이다. 별도 codex-auto-state 브랜치에 실패 태그·패치 해시를 기록하며, 공개 태그 소스 변경에는 patch-revision.txt 증가가 필요하다.

macos-14 runner의 예정된 지원 종료를 피하기 위해 빌드 runner는 macos-15 arm64를 사용하고 macOS deployment target은 14.0으로 지정한다. Windows는 windows-2022 x64다. publish=false는 릴리스 미게시 미리보기다. 실패 기록용 상태 브랜치 쓰기는 미리보기 실패에도 수행된다. 기본 브랜치 반영 전 예약은 활성화되지 않는다.

검증 상세: [version-sync-validation.ko.md](codex/evidence/version-sync-validation.ko.md). 사용자 다음 역할은 CI 빌드 이후 Mac 실기기 확인이며, 원격 실행/배포 결과를 로컬 검사 성공으로 대신하지 않는다.

## 2026-10-15 GitHub 반영

사용자가 GitHub 반영을 요청했다. 첫 미리보기보다 예약 자동 배포가 먼저 실행되지 않도록 schedule 트리거를 제거했다. 현재 수동 workflow_dispatch만 허용하며, 네이티브 검증·첫 배포 검증 이후 매시간 17분 예약을 별도 변경으로 활성화한다. README 한국어·영어 및 설치/업데이트 지원 범위와 미검증 안내를 동기화했다.
