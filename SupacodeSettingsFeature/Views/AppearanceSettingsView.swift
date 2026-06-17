import ComposableArchitecture
import SupacodeSettingsShared
import SwiftUI

public struct AppearanceSettingsView: View {
  @Bindable var store: StoreOf<SettingsFeature>

  public init(store: StoreOf<SettingsFeature>) {
    self.store = store
  }

  public var body: some View {
    let openActionOptions = OpenWorktreeAction.availableCases
    Form {
      Section {
        LabeledContent("모양") {
          HStack(spacing: 12) {
            let appearanceMode = $store.appearanceMode
            ForEach(AppearanceMode.allCases) { mode in
              AppearanceOptionCardView(
                mode: mode,
                isSelected: mode == appearanceMode.wrappedValue
              ) {
                appearanceMode.wrappedValue = mode
              }
            }
          }
        }
        Toggle(isOn: $store.terminalThemeSyncEnabled) {
          Text("Supacode 터미널 테마")
          Text("꺼져 있을 경우, Ghostty 설정 테마를 따릅니다.")
        }
      }
      Section {
        Picker(selection: $store.confirmQuitMode) {
          ForEach(ConfirmQuitMode.allCases, id: \.self) { mode in
            Text(mode.label).tag(mode)
          }
        } label: {
          Text("종료 전 확인")
          Text(store.confirmQuitMode.subtitle)
        }
        Toggle(isOn: $store.terminateSessionsOnQuit) {
          Text("종료 시 세션 종료")
          Text(
            """
            종료 시 모든 탭을 닫고 백그라운드 셸을 중지합니다.
            터미널 지속성은 [zmx \u{2197}](https://github.com/neurosnap/zmx)에 의해 지원됩니다.
            """
          )
        }
      }
      Section("에디터") {
        Picker(
          selection: $store.defaultEditorID
        ) {
          Text("자동")
            .tag(OpenWorktreeAction.automaticSettingsID)
          ForEach(openActionOptions) { action in
            Text(action.labelTitle)
              .tag(action.settingsID)
          }
        } label: {
          Text("기본 에디터")
          Text("저장소 오버라이드가 없는 워크트리에 적용됩니다.")
        }
      }
      Section {
        Toggle(isOn: $store.analyticsEnabled) {
          Text("분석 데이터 공유")
          Text("익명 사용 데이터는 Supacode 개선에 도움이 됩니다.")
        }
        Toggle(isOn: $store.crashReportsEnabled) {
          Text("충돌 보고서 공유")
          Text("익명 충돌 보고서는 안정성 개선에 도움이 됩니다.")
        }
      } header: {
        Text("분석")
      } footer: {
        Text("분석 변경 사항을 적용하려면 Supacode를 다시 시작해야 합니다.")
      }
      Section("고급") {
        Toggle(isOn: $store.hideSingleTabBar) {
          Text("단일 탭일 때 탭 막대 숨기기")
          Text("하나의 탭만 열려 있을 때 탭 막대를 자동으로 숨깁니다.")
        }
        Picker(selection: $store.automatedActionPolicy.sending(\.setAutomatedActionPolicy)) {
          ForEach(AutomatedActionPolicy.allCases, id: \.self) { policy in
            Text(policy.displayName).tag(policy)
          }
        } label: {
          Text("임의의 작업 허용")
          Text("명령 및 파괴적인 작업에 대한 확인 대화상자를 건너뜁니다.")
        }
      }
    }
    .formStyle(.grouped)
    .padding(.top, -20)
    .padding(.leading, -8)
    .padding(.trailing, -6)

    .navigationTitle("일반")
  }
}
