import SupacodeSettingsShared
import SwiftUI

/// Circular badge with the agent's mark. When `awaitingInput` flips, the
/// subtree's colorScheme is inverted so `.bar`, `.primary`, and asset
/// variants flip together — a contrast cue that doesn't clash with agent
/// marks that are already orange (Claude).
struct AgentBadgeView: View {
  let agent: SkillAgent
  let size: CGFloat
  let activity: AgentPresenceFeature.Activity
  let showsAwaitingIndicator: Bool
  @Environment(\.pixelLength) private var pixelLength

  @State private var isSpinning = false

  init(
    agent: SkillAgent,
    size: CGFloat = 14,
    activity: AgentPresenceFeature.Activity = .idle,
    showsAwaitingIndicator: Bool = true
  ) {
    self.agent = agent
    self.size = size
    self.activity = activity
    self.showsAwaitingIndicator = showsAwaitingIndicator
  }

  var body: some View {
    ZStack(alignment: .topTrailing) {
      Image(agent.assetName)
        .resizable()
        .aspectRatio(contentMode: .fit)
        .accessibilityLabel(agent.displayName)
        .padding(size * 0.18)
        .frame(width: size, height: size)
        .foregroundStyle(.white)
        .background(.bar.shadow(Self.dropShadow), in: .circle)
        .overlay(Circle().strokeBorder(.separator, lineWidth: pixelLength))
        .overlay {
          if activity == .busy || (activity == .awaitingInput && showsAwaitingIndicator) {
            let spinnerColor = activity == .awaitingInput ? Color.orange : Color.accentColor
            Circle()
              .stroke(
                AngularGradient(
                  gradient: Gradient(colors: [spinnerColor.opacity(0.1), spinnerColor]),
                  center: .center,
                  startAngle: .degrees(0),
                  endAngle: .degrees(360)
                ),
                style: StrokeStyle(lineWidth: 1.5, lineCap: .round)
              )
              .padding(-1.5)
              .rotationEffect(.degrees(isSpinning ? 360 : 0))
              .animation(
                .linear(duration: 1.0).repeatForever(autoreverses: false),
                value: isSpinning
              )
              .onAppear {
                DispatchQueue.main.async {
                  isSpinning = true
                }
              }
              .onDisappear { isSpinning = false }
          }
        }
    }
  }

  private static let dropShadow: ShadowStyle = .drop(
    color: Color.black.opacity(0.05), radius: 1, x: 0, y: 1
  )
}
