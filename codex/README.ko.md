# codex-auto: Codex 입력창 자동완성 실험판

**codex-auto는 Codex 0.161.0의 기본 입력창에 영어 단어 자동완성을 추가하고, 기존 Codex의 로컬 데이터·계정·설정을 공유하는 수정 CLI입니다.**

공식 플러그인·스킬이 아닙니다. `/plugin install`은 Claude Code 플러그인만 설치합니다. 검토한 0.161.0에서는 입력 중인 단어 읽기·추천 표시·Tab 치환을 모두 제공하는 공식 확장 지점을 확인하지 못해 소스를 수정했습니다. 모든 버전에서 플러그인 구현이 불가능하다는 뜻은 아닙니다.

## 기능과 데이터 공유

- 별도 입력창 없이 Codex 기본 입력창에서 추천·삽입합니다. 실행 바로가기는 키보드 입력을 처리하지 않습니다.
- 영어 **2글자 이상**, 최대 **5개 후보**. ↑↓ 선택, Tab 삽입, Esc 닫기. **Enter는 메시지를 전송합니다.**
- 추천은 번들 사전으로 계산하며 자동완성 API를 호출하지 않습니다. 일반 대화는 설정된 Codex 모델·제공자를 사용합니다.
- `CODEX_HOME`을 그대로 상속합니다. 없으면 기본 `~/.codex`를 사용합니다. Windows에서는 `%USERPROFILE%\.codex`입니다. 세션·입력 기록·로그인·설정을 공유하며 파일을 복사하거나 동기화하지 않습니다.
- 공유는 같은 컴퓨터의 같은 저장 경로 기준입니다. Windows 기록·로그인이 Mac으로 자동 이동하지 않습니다.
- 오타 교정·저장 단축어는 제외했습니다. 추천 순서는 Claude 플러그인의 업무 용어 우선순위와 다릅니다. 사전은 실행 파일에 포함되므로 루트 `data/`만 수정해도 기존 Codex 실행 파일에 반영되지 않습니다.

## 기존 서버 모드와 내장 모드

**기존 서버 모드**는 설치된 Codex 백그라운드 서버를 사용합니다. **내장 모드**(`--no-daemon`)는 CLI 프로세스 내부에서 처리합니다. 두 방식 모두 같은 데이터 홈과 같은 자동완성 입력창을 사용합니다.

Windows 실행기는 현재 관리 서버 패키지가 있으면 재사용하고, 없으면 내장 모드로 시작합니다. 감지 대상은 `packages/app-server-daemon/current/bin/codex.exe`이며 이전 standalone 설치 구조는 자동 감지하지 않습니다.

**Mac 명령은 Codex 기본 실행 모드를 그대로 사용하여 기존 설치 서버를 재사용하도록 합니다.** `--no-daemon`을 자동으로 붙이지 않으며 내장 모드로 자동 전환하지 않습니다. 먼저 Mac에서 공식 `codex`가 정상적으로 시작하는지 확인하세요. Mac 서버 재사용과 고정 0.161.0 클라이언트의 호환성은 아직 미검증입니다. `this CLI has no complete local package` 오류가 나면 공식 Codex 설치·관리 서버를 확인해야 하며, 자동완성 오류로 판단하면 안 됩니다.

내장 모드는 직접 `codex-auto --no-daemon`을 실행할 때만 선택합니다. Windows에서는 공식·수정 0.161.0 모두 내장 모드 세션 목록이 `Loading`에 멈췄으며 Mac 결과는 아직 모릅니다.

## macOS 설치·테스트

**Mac 빌드·실행은 아직 검증하지 않았습니다. 직접 검증하기 위한 소스 빌드 절차이며 Mac용 완성 바이너리 배포가 아닙니다.** Apple Silicon·Intel 각각 해당 Mac에서 빌드합니다. Windows `.exe`는 Mac에서 실행할 수 없습니다. 첫 빌드에는 네트워크, 수 GB 이상의 디스크 공간과 시간이 필요합니다.

### 1. 개발 도구 준비

Apple Command Line Tools가 없다면 실행하고 설치 창에서 완료될 때까지 기다립니다.

```sh
xcode-select --install
```

Rustup이 없다면:

```sh
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
. "$HOME/.cargo/env"
```

이어서:

```sh
rustup toolchain install 1.95.0 --profile minimal
git --version
cargo +1.95.0 --version
```

### 2. 변경된 저장소 준비

변경 사항이 push된 이후에는:

```sh
git clone https://github.com/magatone/claude-autocomplete.git
cd claude-autocomplete
```

**push 전에는 변경된 작업 폴더를 Mac으로 전달해야 합니다.** 기존 원격 저장소만 받으면 새 패치가 없습니다. 다음 단계는 `codex/inline-word-completion.patch`가 있는 저장소 루트에서 시작합니다.

### 3. 고정 버전 소스 빌드

아래 블록 전체를 실행합니다. 실패하면 서브셸만 중단하며 터미널은 닫지 않습니다.

```sh
(
  set -eu
  patch_file="$PWD/codex/inline-word-completion.patch"
  test -f "$patch_file"
  experiment="$HOME/codex-autocomplete-experiment"
  mkdir -p "$experiment"
  git clone --depth 1 --branch rust-v0.161.0 https://github.com/openai/codex.git "$experiment/source"
  cd "$experiment/source"
  test "$(git rev-parse HEAD)" = 979011409de0a60b52f179721948e65531d26144
  git apply --check "$patch_file"
  git apply "$patch_file"
  cd codex-rs
  CARGO_PROFILE_DEV_DEBUG=0 CARGO_INCREMENTAL=0 cargo +1.95.0 build --locked -p codex-cli --bin codex
  mkdir -p "$experiment/bin"
  cp target/debug/codex "$experiment/bin/codex"
  "$experiment/bin/codex" --version
)
```

성공 시 `codex-cli 0.161.0`이 나옵니다. `source`가 이미 있으면 복제를 중단하므로 기존 작업을 덮어쓰지 않습니다. 이미 이 패치를 적용한 소스를 다시 빌드할 때만 아래를 사용합니다.

```sh
(
  set -eu
  cd "$HOME/codex-autocomplete-experiment/source/codex-rs"
  CARGO_PROFILE_DEV_DEBUG=0 CARGO_INCREMENTAL=0 cargo +1.95.0 build --locked -p codex-cli --bin codex
  cp target/debug/codex "$HOME/codex-autocomplete-experiment/bin/codex"
)
```

`CARGO_TARGET_DIR` 또는 `CARGO_BUILD_TARGET`을 따로 설정했다면 결과 경로가 달라집니다. 이 설치 절차는 해당 설정이 없는 터미널에서 진행하세요.

### 4. codex-auto 명령 등록

작업 폴더·인자를 그대로 전달하고 자식 프로세스에만 자동완성 환경 변수를 설정합니다. 입력 처리 래퍼가 아닙니다. Codex 실행 모드를 강제로 변경하지 않습니다. 등록 전에 공식 `codex --version`과 `codex`를 실행해 정상 시작을 확인한 뒤 종료하세요. 공식 버전이 0.161.0과 다르면 테스트 결과에 두 버전을 함께 기록해주세요.

```sh
(
  set -eu
  test -x "$HOME/codex-autocomplete-experiment/bin/codex"
  mkdir -p "$HOME/.local/bin"
  test ! -e "$HOME/.local/bin/codex-auto"
  test ! -L "$HOME/.local/bin/codex-auto"
  cat > "$HOME/.local/bin/codex-auto" <<'SH'
#!/bin/sh
exec env CODEX_WORD_AUTOCOMPLETE=1 "$HOME/codex-autocomplete-experiment/bin/codex" "$@"
SH
  chmod +x "$HOME/.local/bin/codex-auto"
)
export PATH="$HOME/.local/bin:$PATH"
codex-auto --version
codex-auto login status
```

기존 `~/.local/bin/codex-auto`가 있으면 덮어쓰지 않고 등록을 중단합니다. 기존 명령을 먼저 확인하세요. 이전 내장 모드 안내로 설치했다면 실행 줄에서 자동 추가했던 `--no-daemon`만 제거하고 `"$@"`는 유지하세요. macOS 기본 **zsh**에서는 다음 줄을 `~/.zshrc`에 한 번 추가해야 새 터미널에서도 PATH가 유지됩니다.

```sh
export PATH="$HOME/.local/bin:$PATH"
```

`~/codex-autocomplete-experiment/bin/codex`는 이동하지 마세요. 기존 `codex`는 공식 설치본을 실행합니다. 로그인 상태가 없다면 `codex-auto login`으로 로그인합니다. Mac의 기존 Codex 홈을 그대로 사용합니다.

### 5. 입력창 테스트

원하는 작업 폴더에서:

```sh
codex-auto
```

`recom` 입력 → ↑↓ 선택 → Tab 삽입이 전송 없이 동작하는지 확인합니다. Esc 닫기, `Recom` 대문자 유지, 한글·영어 혼합 입력도 확인하세요. **자동완성만 확인할 때 Enter를 누르면 실제 전송됩니다.** 이후 선택적으로 `codex-auto resume --all`을 확인하고 `Loading`에 머무르면 별도로 알려주세요.

문제가 있으면 macOS 버전, `uname -m`, 터미널 앱, CLI 버전, 입력 문자열과 누른 키 순서를 함께 전달해주세요.

명령만 제거하려면 `~/.local/bin/codex-auto`를 삭제합니다. 기존 Codex 데이터를 포함하는 공유 홈은 삭제하지 마세요.

## Windows 설치·재빌드

현재 개발 PC에는 패키지와 명령이 설치되어 있습니다. 새 설치에는 Git, **Rust 1.95.0**의 Rustup/Cargo, MSVC C++ 빌드 도구가 필요합니다. 스크립트는 개발 도구를 설치하지 않습니다.

저장소 루트에서 실행합니다. 목적지가 이미 있으면 중단합니다.

```powershell
$ErrorActionPreference = 'Stop'
$package = Join-Path $env:USERPROFILE 'codex-autocomplete-experiment'
if (Test-Path -LiteralPath $package) { throw 'Package already exists. Inspect it before replacing files.' }
Copy-Item -LiteralPath .\codex -Destination $package -Recurse
& "$package\build.ps1"
if ($LASTEXITCODE -ne 0) { throw 'Build failed; do not install the command.' }
& .\codex\install-command.ps1
```

새 터미널에서:

```powershell
codex-auto --version
codex-auto
codex-auto resume --all
```

설치기는 PowerShell·CMD 명령을 등록하고 필요하면 사용자 `bin`을 PATH에 추가합니다. 실행 파일을 다운로드하지 않으며 빌드된 패키지가 필요합니다. 빌드 스크립트는 다른 커밋이나 별도의 소스 변경이 있으면 덮어쓰지 않고 중단합니다. 동일 패치를 적용한 소스의 반복 빌드는 지원합니다.

집중 검증 명령:

```powershell
& "$env:USERPROFILE\codex-autocomplete-experiment\check-launcher.ps1"
& "$env:USERPROFILE\codex-autocomplete-experiment\check-build-patch.ps1"
```

## 확인한 범위와 제한

2026-10-12 Windows에서 기존 ChatGPT 로그인 재사용, 기존 세션 목록, 기본 입력창 Tab 삽입, 최초·반복 빌드, 인자·환경·종료 코드 전달을 확인했습니다. 앞선 기능 테스트는 **자동완성 16개를 포함한 composer/history 총 412개**이며 고유 테스트 428개라는 뜻은 아닙니다. 이후 사용자가 로컬 자동완성 동작을 확인했습니다. 자동화된 수동 UI 확인에서는 모델에 메시지를 전송하지 않았습니다.

Mac 빌드·실행, 실제 한글 IME 조합, 전체 Rust 테스트, 지연 측정, 릴리스 최적화 빌드, 기존 대화를 재개한 뒤 실제 전송은 검증하지 않았습니다. 이전 Windows 실험용 `state/`는 보존했으며 자동 병합하지 않습니다.

**0.161.0 고정판이므로 공식 Codex 업데이트가 이 실행 파일에 반영되지 않습니다.** 새 버전에는 패치 이식·재빌드가 필요하고 공유 데이터·서버 호환성을 다시 확인해야 합니다. 같은 세션을 두 CLI에서 동시에 편집하지 마세요.

## 포함 파일·라이선스

공식 `rust-v0.161.0`, 커밋 `979011409de0a60b52f179721948e65531d26144`에 패치를 적용합니다. 패치에는 Rust 입력창 수정·테스트·번들 사전·워크스페이스 버전 정합성 수정만 포함합니다. 실험 계획서·개인 검증 기록·소스 체크아웃·컴파일된 실행 파일은 포함하지 않습니다.

`Cargo.lock`의 워크스페이스 패키지 버전은 `--locked` 빌드를 위해 0.161.0에 맞췄으며 외부 의존성 버전은 바꾸지 않았습니다. Codex의 Apache-2.0 LICENSE·NOTICE는 복제한 원본 소스에 유지됩니다. 단어 데이터의 출처·CC BY-SA 4.0 안내와 업무 용어 MIT 라이선스는 패치에 포함됩니다. [push 전 검토 기록](REVIEW.ko.md)을 참고하세요.
