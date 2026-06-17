import ComposableArchitecture
import SupacodeSettingsFeature
import SupacodeSettingsShared
import SwiftUI

struct UpdatesSettingsView: View {
  @Bindable var settingsStore: StoreOf<SettingsFeature>
  let updatesStore: StoreOf<UpdatesFeature>

  var body: some View {
    Form {
      Section {
        Picker(selection: $settingsStore.updateChannel) {
          Text("안정(Stable)").tag(UpdateChannel.stable)
          Text("최신(Tip)").tag(UpdateChannel.tip)
        } label: {
          Text("채널")
          Text(
            settingsStore.updateChannel == .stable ? "대부분의 사용자에게 권장됩니다." : "최신 기능을 미리 사용해 보세요.")
        }
        Button {
          updatesStore.send(.checkForUpdates)
        } label: {
          Text("지금 업데이트 확인")
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
        .buttonBorderShape(.roundedRectangle)
      }
      Section("자동 업데이트") {
        Toggle(isOn: $settingsStore.updatesAutomaticallyCheckForUpdates) {
          Text("자동으로 업데이트 확인")
          Text("Supacode가 실행되는 동안 새 버전을 주기적으로 확인합니다.")
        }
        Toggle(isOn: $settingsStore.updatesAutomaticallyDownloadUpdates) {
          Text("업데이트 자동 다운로드 및 설치")
          Text("백그라운드에서 업데이트를 다운로드합니다. 적용하려면 다시 시작하라는 메시지가 표시됩니다.")
        }
        .disabled(!settingsStore.updatesAutomaticallyCheckForUpdates)
      }
    }
    .formStyle(.grouped)
    .padding(.top, -20)
    .padding(.leading, -8)
    .padding(.trailing, -6)
    .navigationTitle("업데이트")
  }
}
