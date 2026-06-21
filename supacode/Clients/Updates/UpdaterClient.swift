import ComposableArchitecture
import SupacodeSettingsShared

struct UpdaterClient {
  var configure: @MainActor @Sendable (_ checks: Bool, _ downloads: Bool, _ checkInBackground: Bool) -> Void
  var setUpdateChannel: @MainActor @Sendable (UpdateChannel) -> Void
  var checkForUpdates: @MainActor @Sendable () -> Void
}

extension UpdaterClient: DependencyKey {
  // 이 빌드는 supacode 원본(supacode.sh)의 개인 소프트 포크입니다. Sparkle 자동
  // 업데이트는 의도적으로 비활성화합니다 — 원본 appcast/서명키를 그대로 두면
  // "업데이트 확인"이 원본 릴리스를 받아 custom/main 커스터마이즈를 덮어쓰기
  // 때문입니다. `SPUStandardUpdaterController`를 아예 생성하지 않으므로 Sparkle이
  // 초기화되지 않고, 모든 진입점(메뉴/팔레트/설정/백그라운드 체크)이 이 클라이언트를
  // 통과하므로 여기 하나만 no-op으로 두면 전부 무력화됩니다. 배포는 `make
  // install-dev-build`로 로컬 설치합니다.
  static let liveValue = UpdaterClient(
    configure: { _, _, _ in },
    setUpdateChannel: { _ in },
    checkForUpdates: {},
  )

  static let testValue = UpdaterClient(
    configure: { _, _, _ in },
    setUpdateChannel: { _ in },
    checkForUpdates: {},
  )
}

extension DependencyValues {
  var updaterClient: UpdaterClient {
    get { self[UpdaterClient.self] }
    set { self[UpdaterClient.self] = newValue }
  }
}
