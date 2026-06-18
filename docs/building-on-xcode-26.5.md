# Xcode 26.5에서 supacode 빌드하기 (트러블슈팅)

> 작성: 2026-06-18 · 환경: macOS 26.5(Tahoe), Xcode 26.5, Zig 0.15.2(mise)

이 fork를 **Xcode 26.5** 환경에서 처음 빌드할 때 마주치는 세 가지 툴체인 벽과 해결법을 정리한다.
세 벽 모두 근본 원인은 동일하다 — **프로젝트가 고정한 툴체인(Zig 0.15.2 / TCA 1.23.1)이 Xcode 26.5의 최신 SDK·Swift 컴파일러보다 오래됐다.** CI는 `macos-26` 러너에서 **Xcode ≤26.3**을 명시적으로 골라 빌드하므로 이 문제를 겪지 않는다(`.github/actions/setup-macos/action.yml` 참고).

핵심 전제: **우리 변경은 전부 Swift(한국어 현지화)이고 ghostty는 손대지 않았다.** 따라서 ghostty/zmx는 "한 번 빌드된 바이너리"만 있으면 되고, 직접 빌드할 필요가 없다.

---

## 벽 1 — ghostty/zmx가 Zig로 빌드되지 않음

### 증상
`make build-ghostty-xcframework`(또는 Xcode의 "Foreign Build: GhosttyKit" 스크립트 페이즈)에서 libSystem 전체가 undefined로 링크 실패:

```
error: undefined symbol: __availability_version_check
error: undefined symbol: _abort
error: undefined symbol: _malloc_size
... (libSystem 심볼 전부)
```

`zig build-exe hello.zig` 같은 최소 예제조차 실패한다 (`SDKROOT`을 명시해도 동일).

### 원인
Zig 0.15.2의 Mach-O 링커가 **Xcode 26.4+ SDK**의 TBD 파일을 소화하지 못한다 ([ziglang/zig#31272](https://github.com/ziglang/zig/issues/31272), Codeberg #31658). `libSystem.tbd`가 링크 라인에 안 들어가 모든 심볼이 빠진다.

- Zig 0.16.0에서 링커는 고쳐졌지만, ghostty가 `requireZig(0.15.2)`로 **정확히 0.15.2를 강제**하고 `std.process.EnvMap` 등 0.16에서 사라진 API를 써서 **컴파일 자체가 안 됨** → Zig 버전 업으로는 해결 불가.

### 해결 — CI에서 빌드해 받아오기
`macos-26` 러너는 Xcode ≤26.3을 갖고 있어 ghostty/zmx가 빌드된다. 임시 워크플로로 빌드 산출물(`.build/ghostty`, `.build/zmx`)을 artifact로 받아온다.

1. 아래 워크플로를 임시 브랜치에 추가하고 push (트리거됨):

```yaml
# .github/workflows/build-thirdparty.yml (임시, 받은 뒤 삭제)
name: build-thirdparty
on:
  push:
    branches: [ci/build-ghostty]
  workflow_dispatch:
jobs:
  build:
    runs-on: macos-26
    env:
      MISE_HTTP_TIMEOUT: 120
      MISE_GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
    steps:
      - uses: actions/checkout@v6
        with: { submodules: recursive }
      - name: Select Xcode <= 26.3   # setup-macos 액션에서 그대로 복사
        shell: bash
        run: |
          set -euo pipefail
          selected=""
          for app in /Applications/Xcode_26.3*.app /Applications/Xcode_26.2*.app \
            /Applications/Xcode_26.1*.app /Applications/Xcode_26.0*.app; do
            if [ -d "$app" ]; then selected="$app"; break; fi
          done
          [ -n "$selected" ] || { echo "No Xcode <= 26.3"; ls -d /Applications/Xcode_*.app; exit 1; }
          sudo xcode-select -s "$selected/Contents/Developer"
          xcodebuild -version
      - uses: jdx/mise-action@v4
        with: { version: 2026.3.0, cache: true }
      - run: make build-ghostty-xcframework
      - run: make build-zmx
      - name: Package
        run: |
          tar czf thirdparty-build.tgz -C .build \
            --exclude='*/.zig-cache' --exclude='*/.zig-global-cache' --exclude='zmx/slices' \
            ghostty zmx
      - uses: actions/upload-artifact@v6
        with: { name: thirdparty-build, path: thirdparty-build.tgz, retention-days: 7 }
```

> ⚠️ fork가 회사 계정으로 push 안 되면(개인 계정이 fork 소유) `gh auth switch`로 fork 소유 계정 활성화 필요. push 후 정리할 때 다시 회사 계정으로 되돌릴 것.

2. 빌드 완료(약 16분) 후 받아서 `.build/`에 푼다:

```bash
gh run download <RUN_ID> -n thirdparty-build -D /tmp/tp
mkdir -p .build && tar xzf /tmp/tp/thirdparty-build.tgz -C .build
```

3. git-wt는 Zig가 아니라 그냥 번들 셸 스크립트라 로컬에서 서브모듈 init만:

```bash
git submodule update --init Resources/git-wt
```

검증: `ls .build/ghostty/GhosttyKit.xcframework` , `lipo -info .build/zmx/bin/zmx` (arm64/x86_64 universal).

---

## 벽 2 — Xcode 빌드가 ghostty를 또 재빌드하려 함 (fingerprint 불일치)

### 증상
artifact를 풀어놨는데도 Xcode 빌드의 "Foreign Build: GhosttyKit" 페이즈가 `build-ghostty.sh`를 다시 실행 → 벽 1의 링커 에러 재발.

### 원인
`build-ghostty.sh`는 `.build/ghostty/fingerprint`(저장값)와 실행 시점 계산값을 비교해 다르면 재빌드한다. fingerprint에는 patches 적용분의 `git diff` 해시가 들어가는데, 이게 git 환경(CI vs 로컬)에 따라 미묘하게 달라 값이 안 맞는다. **산출물 자체는 동일 ghostty SHA·동일 patches로 빌드된 것이라 유효하다** — 문제는 fingerprint 문자열뿐.

### 해결 — fingerprint를 로컬 계산값으로 덮어쓰기
중요한 건 "파일값 == 로컬이 계산하는 값"이다. CI 값은 무관.

```bash
# 1) 로컬 계산값 확인
./scripts/build-ghostty.sh --print-fingerprint
# 2) 그 값을 파일에 기록 (write → run 순서 엄수: 안 그러면 재빌드 트리거)
printf '%s\n' "<위에서_나온_값>" > .build/ghostty/fingerprint
# 3) 검증 — 둘 다 즉시 exit 0(재빌드 없음)이어야 함
./scripts/build-ghostty.sh   # ~0.2s, exit 0
./scripts/build-zmx.sh       # zmx는 보통 이미 일치 (patches 없음)
```

> zmx도 동일 메커니즘(`build-zmx.sh`)이지만 patches가 없어 fingerprint가 대개 그냥 일치한다. ghostty만 손보면 되는 경우가 많다.

---

## 벽 3 — TCA가 Swift 컴파일러에서 컴파일 실패

### 증상
```
swift-composable-architecture/.../Binding+Observation.swift:86:5:
error: type 'WritableKeyPath<Root, Value>' does not conform to the 'Sendable' protocol
```

### 원인
Xcode 26.5의 Swift 컴파일러가 KeyPath의 Sendable 규칙을 경고→에러로 승격. 프로젝트가 고정한 **TCA 1.23.1**이 이를 못 넘긴다 ([pointfreeco/swift-composable-architecture#3844](https://github.com/pointfreeco/swift-composable-architecture/pull/3844)). CI(≤26.3)에서는 통과하므로 업스트림도 안 겪은 영역.

### 해결 — TCA를 1.23.2로 bump
1.23.2가 `WritableKeyPath` → `_SendableWritableKeyPath`로 바꿔 해결. **1.23.1 → 1.23.2는 breaking change 없는 패치**라 안전(부족하면 폴백 후보는 1.26.0).

```swift
// Tuist/Package.swift
.package(url: "https://github.com/pointfreeco/swift-composable-architecture", exact: "1.23.2"),
```

```bash
mise exec -- tuist install        # 의존성 재resolve
mise exec -- tuist generate --no-open
```

> 이 변경은 `main`에 커밋되어 있다 (`build: bump TCA to 1.23.2 for Xcode 26.5 compatibility`).

---

## 전체 빌드 절차 (요약)

`.build/`가 갖춰진 상태(벽 1~2 해결 완료)에서는:

```bash
mise exec -- tuist generate --no-open
xcodebuild -workspace supacode.xcworkspace -scheme supacode \
  -configuration Debug build -skipMacroValidation
# 실행
open "$(xcodebuild -workspace supacode.xcworkspace -scheme supacode -configuration Debug \
  -showBuildSettings -json | jq -r '.[0].buildSettings.BUILT_PRODUCTS_DIR')/supacode.app"
```

### 참고
- `make build-app` / `make run-app`은 `xcbeautify`(로그 포매터)가 필요하다. 없으면 `brew install xcbeautify` 하거나 위처럼 `xcodebuild`를 직접 호출한다.
- `.build/`를 청소하거나 ghostty 서브모듈이 업데이트되면 **벽 1~2를 다시 거쳐야 한다** (임시 워크플로 재생성 → artifact 재조달 → fingerprint 재갱신).
- 근본 해결은 ghostty가 Zig 0.16+로 마이그레이션될 때까지 대기하거나, 로컬에 Xcode ≤26.3을 추가 설치하는 것이다 (그 경우 `xcode-select`로 전환 후 모든 것을 네이티브로 빌드 가능 — CI artifact·fingerprint 우회 불필요).
