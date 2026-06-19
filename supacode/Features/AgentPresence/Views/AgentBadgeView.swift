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
  @Environment(\.pixelLength) private var pixelLength

  @State private var isPulsing = false

  init(agent: SkillAgent, size: CGFloat = 14, activity: AgentPresenceFeature.Activity = .idle) {
    self.agent = agent
    self.size = size
    self.activity = activity
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
          if activity == .busy {
            Circle()
              .stroke(Color.accentColor, lineWidth: 1.5)
              .scaleEffect(isPulsing ? 1.4 : 1.0)
              .opacity(isPulsing ? 0 : 0.6)
              .animation(
                .easeOut(duration: 1.2).repeatForever(autoreverses: false),
                value: isPulsing
              )
              .onAppear {
                DispatchQueue.main.async {
                  isPulsing = true
                }
              }
              .onDisappear { isPulsing = false }
          }
        }
      
      if activity == .awaitingInput {
        Circle()
          .fill(Color.orange)
          .frame(width: size * 0.4, height: size * 0.4)
          .overlay(Circle().stroke(.background, lineWidth: 1))
          .offset(x: size * 0.1, y: -size * 0.1)
      }
    }
  }

  private static let dropShadow: ShadowStyle = .drop(
    color: Color.black.opacity(0.05), radius: 1, x: 0, y: 1
  )
}
