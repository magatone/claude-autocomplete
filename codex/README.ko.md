# codex-auto: Codex CLI 영어 단어 자동완성

기존 Codex와 같은 계정·설정·세션을 사용하면서 기본 입력창에 영어 단어 후보를 표시하는 별도 수정 CLI다. 일반 실행 시 설치된 공식 Codex 버전에 맞는 배포 파일을 찾아 실행한다.

**현재: 로컬 구현·fixture 검증 완료. 첫 GitHub 미리보기는 사전 검사에서 실패했고, CRLF·경로 별칭 오류 수정 후 재검증이 필요하다. 배포 인덱스가 없으므로 새 런처를 지금 설치해도 다운로드 실행은 불가능하다. 기존 설치 명령은 변경하지 않았다.**

## 사용 흐름

1. 공식 Codex를 별도로 업데이트했다면 다음 `codex-auto` 실행이 버전 변경을 감지한다.
2. 해당 버전의 검증된 자동완성 CLI를 다운로드하고 SHA-256·실제 CLI 버전을 확인한다.
3. 검증한 파일을 캐시에 저장하고 실행한다. 다음 실행은 캐시를 재검증하며 네트워크 없이 재사용한다.
4. 해당 버전의 배포가 없거나 검증에 실패하면 실행을 중단한다. 구버전으로 몰래 실행하거나 사용자 PC에서 빌드하지 않는다.

`codex-auto update`는 최신 정식 Codex에 맞는 자동완성 파일을 **먼저** 준비하고 공식 Codex를 정확한 버전으로 업데이트한다. **첫 지원은 기존 npm 설치뿐**이다. standalone·Homebrew는 공식 Codex를 별도로 업데이트한 뒤 `codex-auto`를 실행한다. 같은 공식 버전의 자동완성 패치 갱신도 이 명령으로 받는다.

일반 실행은 공식 Codex를 업데이트하지 않는다. Codex 업데이트 순간 자동완성 파일까지 즉시 교체되는 방식이 아니라 **다음 codex-auto 실행에서 버전을 맞추는 방식**이다. 공식 설치 중 실패하면 두 설치를 원자적으로 되돌릴 수 없으므로 `codex --version`을 확인한 뒤 재시도한다.

## 최초 설치, 첫 배포 이후

GitHub에서 **Code → Download ZIP**으로 내려받고 압축을 푼다. 일반 사용자에게 Python·Git·Rust·컴파일러 설치는 필요 없다. 공식 `codex --version`이 먼저 정상 동작해야 한다. 최초 다운로드에는 인터넷이 필요하다.

Windows x64, PowerShell 5.1 이상:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\codex\install-command.ps1
```

macOS Apple Silicon, macOS 14 이상:

```sh
sh codex/install-command.sh
```

새 터미널에서:

```sh
codex-auto --version
codex-auto
codex-auto update
```

설치기는 기존 `codex-auto` 명령을 새 런처로 교체한다. Windows는 사용자 bin·PATH, Mac은 ~/.local/bin 및 zsh/bash 프로필을 등록한다. 런처 스크립트 자체가 변경되면 새 ZIP으로 설치기를 다시 실행한다. `update`는 버전별 실행 파일을 갱신한다.

Windows 캐시: %LOCALAPPDATA%/codex-auto/windows-x64/<버전>. Mac 캐시: ${XDG_CACHE_HOME:-$HOME/.cache}/codex-auto/macos-arm64/<버전>. 검증 실패 시 기존 정상 캐시를 보존한다. 실행 중 파일을 교체하지 않고 별도 파일을 만든 뒤 현재 포인터를 전환한다.

## 입력창과 기존 Codex 데이터

영문 두 글자 이상이면 후보 최대 5개가 나온다. ↑↓ 선택, Tab 삽입, Esc 닫기. **Enter는 실제 메시지를 전송한다.** 자동완성만 확인할 때 Enter를 누르지 않는다. 후보는 내장 로컬 사전이며 대화는 기존 설정의 모델·제공자를 사용한다. 오타 교정·저장 단축어는 Codex 기능에 포함되지 않는다.

CODEX_HOME을 그대로 상속하며 기본 ~/.codex를 사용한다. 로그인·설정·세션을 복사하거나 다른 장치와 동기화하지 않는다. 같은 세션을 두 CLI에서 동시에 수정하지 않는다.

Windows는 현재 관리형 서버 경로가 있으면 재사용하고 없으면 --no-daemon을 추가한다. Mac은 기본 Codex 시작 방식을 유지한다. 실제 서버 연결·세션 조회·한글 IME는 별도로 검증해야 한다.

## 운영자: 자동 빌드·배포

[릴리스 workflow](../.github/workflows/codex-auto-release.yml)는 정식 rust-v0.161.0 이상 미처리 릴리스를 검색한다. **첫 검증 전에는 수동 실행만 허용하며 매시간 17분 예약은 비활성화했다.** 미리보기와 첫 배포 검증 이후 예약을 별도로 켠다. 버전별 Windows x64·macOS arm64 네이티브 release 빌드, 입력창 회귀 테스트, 버전·해시·라이선스 검사가 모두 통과해야 공개한다. prerelease·Intel Mac·Linux 실행 파일 배포는 첫 범위에서 제외한다.

첫 확인은 Actions → **Codex Auto releases → Run workflow**에서 version=0.162.1, publish=false로 수행한다. 빌드 산출물과 로그를 확인한 뒤 publish=true로 실행한다. 예약 자동화는 workflow가 기본 브랜치에 있어야 동작한다. 예약 지연·비활성화 가능성이 있으므로 상태를 확인한다.

배포 태그는 codex-<버전>-p<패치번호>다. 공개한 태그는 재사용하지 않는다. 패치를 수정해 다시 공개할 때 `codex/patch-revision.txt`를 올린다. 실패는 별도 codex-auto-state 브랜치에 버전·패치 해시별로 기록한다. 같은 실패를 반복하지 않으며 패치 변경 또는 retry_failed=true로 재시도한다. 미리보기 실패도 상태 브랜치에 기록되므로 같은 패치 재시도에는 retry_failed=true를 사용한다.

공유 codex-auto-index 릴리스의 index.tsv는 완성된 모든 버전 배포를 보존한다. 헤더 codex-auto-index-v1 다음 줄은 **버전, 패치번호, 플랫폼, SHA-256** 네 필드이며 탭으로 구분한다. 클라이언트가 고정 GitHub URL을 조합하므로 임의 다운로드 주소를 받지 않는다. 게시 이후 인덱스 갱신 실패는 다음 예약 실행에서 복구한다.

GitHub 기본 토큰은 읽기 권한, 게시·실패 기록 작업만 쓰기 권한이다. PAT와 별도 알림 서비스는 필요 없다. Actions 실패 이메일 설정은 사용자 설정 완료 보고를 받았으며 실제 수신은 아직 확인하지 않았다.

## 개발 검증과 한계

Windows 0.162.1 개발 빌드의 --version·--help, word_completion 16개와 composer/history 총 411개 검사를 통과했다. 411개에는 자동완성 16개가 포함된다. 다운로드·손상·오프라인·업데이트 fixture와 WSL2 셸 검사를 통과했다.

**Mac 네이티브 빌드·실제 터미널·한글 IME, release 최적화 빌드, 실제 GitHub 다운로드·배포·알림 수신은 미검증이다.** WSL2는 POSIX 공통 흐름 검사용이며 Mac 대체 검증이 아니다. 결과는 [검증 기록](evidence/version-sync-validation.ko.md)에 정리한다.

개발자는 Git·공식 소스가 지정한 Rust·Windows MSVC 또는 Apple 빌드 도구가 필요하다. `build-release.ps1`은 깨끗한 공식 태그 checkout만 받으며 기존 출력 폴더는 덮어쓰지 않는다. `build.ps1`은 과거 0.161.0 실험 재현용이다. 기능 패치와 고정 lockfile 메타데이터는 분리했다.

Codex Apache-2.0 LICENSE·NOTICE, 단어 데이터 CC BY-SA 4.0 출처와 업무 용어 MIT 라이선스, 적용한 소스 패치를 배포에 포함한다.
