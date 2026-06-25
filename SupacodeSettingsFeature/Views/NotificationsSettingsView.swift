import ComposableArchitecture
import SwiftUI

public struct NotificationsSettingsView: View {
  @Bindable var store: StoreOf<SettingsFeature>

  public init(store: StoreOf<SettingsFeature>) {
    self.store = store
  }

  public var body: some View {
    Form {
      Section {
        Toggle(
          isOn: $store.systemNotificationsEnabled
        ) {
          Text("시스템 알림")
        }
        .help("macOS 시스템 알림 표시")
        Toggle(
          isOn: $store.notificationSoundEnabled
        ) {
          Text("알림 소리 재생")
          Text(
            "시스템 알림이 활성화된 경우 설정에 따라 소리가 재생되므로 이 옵션은 무시됩니다."
          )
        }.disabled(store.systemNotificationsEnabled)
      }
      Section("워크트리") {
        Toggle(
          isOn: $store.inAppNotificationsEnabled
        ) {
          Text("알림 배지")
          Text("읽지 않은 알림이 있는 워크트리 옆에 주황색 점을 표시합니다.")
        }
        Toggle(
          isOn: $store.moveNotifiedWorktreeToTop
        ) {
          Text("읽지 않은 워크트리 우선 정렬")
          Text("읽지 않은 알림이 있는 워크트리가 목록 상단에 먼저 표시됩니다.")
        }
      }
      Section("코딩 에이전트") {
        Toggle(isOn: $store.richAgentNotificationsEnabled) {
          Text("풍부한 에이전트 알림")
          Text("에이전트 훅이 일반 알림 대신 마지막 메시지 기반 알림을 전달합니다.")
        }
        Toggle(isOn: $store.notifyOnTurnCompleteEnabled.sending(\.setNotifyOnTurnCompleteEnabled)) {
          Text("턴 완료 알림")
          Text("에이전트가 응답을 마칠 때 알림을 보냅니다.")
        }
        Toggle(isOn: $store.notifyOnAwaitingInputEnabled.sending(\.setNotifyOnAwaitingInputEnabled)) {
          Text("입력 대기 알림")
          Text("Claude가 입력을 기다릴 때 알림을 보냅니다.")
        }
        TextField("제목 템플릿", text: $store.agentNotificationTitleTemplate, prompt: Text("{title}"))
        TextField("본문 템플릿", text: $store.agentNotificationBodyTemplate, prompt: Text("{body}"))
        Text("사용 가능한 토큰: {repo}, {worktree}, {title}, {body}")
          .foregroundStyle(.secondary)
      }
    }
    .formStyle(.grouped)
    .padding(.top, -20)
    .padding(.leading, -8)
    .padding(.trailing, -6)

    .navigationTitle("알림")
  }
}
