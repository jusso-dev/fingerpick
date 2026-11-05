import FingerPickKit
import SwiftUI

struct RootView: View {
    @State private var model = GameModel()
    @State private var haptics = HapticsDirector(service: NoHaptics())
    @State private var idleTimer = IdleTimerController()
    @State private var announcer = Announcer()
    @State private var showsSettings = false
    @AppStorage(Haptics.enabledKey) private var hapticsEnabled = true
    @AppStorage(FirstRunHint.seenKey) private var hasSeenHint = false
    @AppStorage(GameSettings.modeKey) private var mode = ModeChoice.single
    @AppStorage(GameSettings.winnerCountKey) private var winnerCount = GameSettings.defaultWinnerCount
    @AppStorage(GameSettings.teamCountKey) private var teamCount = GameSettings.defaultTeamCount
    @AppStorage(GameSettings.countdownKey) private var countdownSeconds = GameSettings.defaultCountdown
    @AppStorage(GameSettings.minimumFingersKey) private var minimumFingers = GameSettings.defaultMinimumFingers
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.layoutDirection) private var layoutDirection

    var body: some View {
        ZStack(alignment: .top) {
            Color(.systemBackground)
                .ignoresSafeArea()
            RingsView(model: model, diameter: model.layout.ringDiameter)
                .ignoresSafeArea()
            MultitouchSurface(onEvent: { model.handle($0) }, onLayout: { model.updateLayout($0) })
                .ignoresSafeArea()
            GeometryReader { proxy in
                labels(safeArea: proxy.safeAreaInsets)
            }
            .ignoresSafeArea()
            if !hasSeenHint && model.isIdle {
                FirstRunHint { hasSeenHint = true }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .transition(.opacity)
            }
        }
        .animation(.default, value: hasSeenHint)
        .sheet(isPresented: $showsSettings) {
            SettingsView()
                .presentationDetents([.medium, .large])
        }
        // During a round, edge swipes need a second swipe, and the home indicator and status bar hide.
        .defersSystemGestures(on: model.isRoundActive ? .all : [])
        .persistentSystemOverlays(model.isRoundActive ? .hidden : .automatic)
        .statusBarHidden(model.isRoundActive)
        .onChange(of: configuration, initial: true) {
            model.updateConfiguration(configuration)
        }
        .onChange(of: model.isRoundActive) {
            // The first finger also dismisses the hint.
            if model.isRoundActive { hasSeenHint = true }
        }
        .onChange(of: hapticsEnabled, initial: true) {
            haptics.service = Haptics.make(enabled: hapticsEnabled)
        }
        .onChange(of: IdleInputs(model: model, scenePhase: scenePhase), initial: true) {
            idleTimer.update(model: model, scenePhase: scenePhase)
        }
        .onAppear {
            model.onEvents = { [haptics, announcer, model] events in
                haptics.handle(events, countdownDuration: model.engine.configuration.countdownDuration)
                announcer.handle(events, model: model)
            }
        }
    }
}

extension RootView {
    private var configuration: RoundConfiguration {
        GameSettings.configuration(
            mode: mode, winnerCount: winnerCount, teamCount: teamCount,
            countdownSeconds: countdownSeconds, minimumFingers: minimumFingers
        )
    }

    /// Prompt and result, placed in the play area's reveal rect: the whole screen, or the larger
    /// side of an active fold, so text never crosses it. Coordinates are the touch view's (full
    /// screen, unmirrored), so this container keeps a fixed left-to-right direction for placement
    /// and gives the text back the user's direction.
    @ViewBuilder
    private func labels(safeArea: EdgeInsets) -> some View {
        let layout = model.layout
        let area = layout.revealRect
        let safe = CGRect(
            x: safeArea.leading, y: safeArea.top,
            width: max(0, layout.size.width - safeArea.leading - safeArea.trailing),
            height: max(0, layout.size.height - safeArea.top - safeArea.bottom)
        )
        let region = area.intersection(safe).isNull ? area : area.intersection(safe)
        let top = layout.labelTop(from: region.minY + 24, height: 60)
        ZStack(alignment: .topLeading) {
            PromptView(model: model)
                .environment(\.layoutDirection, layoutDirection)
                .frame(width: region.width)
                .offset(x: region.minX, y: top)
            if model.isIdle {
                settingsButton(layout: layout, safe: safe)
            }
            if let reveal = model.reveal {
                ResultView(reveal: reveal)
                    .id(reveal.startedAt)
                    .environment(\.layoutDirection, layoutDirection)
                    .frame(width: region.width, height: region.height)
                    .offset(x: region.minX, y: region.minY)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .environment(\.layoutDirection, .leftToRight)
    }
}

extension RootView {
    /// Small Settings button in a safe-area corner clear of any occlusion (inner camera). It
    /// only shows on the empty waiting screen, so it never sits in the play area during a round.
    private func settingsButton(layout: PlayLayout, safe: CGRect) -> some View {
        let size = CGSize(width: 44, height: 44)
        let corner = layout.controlCorner(controlSize: size, safeFrame: safe)
        let rect = layout.controlRect(corner, controlSize: size, safeFrame: safe)
        return Button {
            showsSettings = true
        } label: {
            Image(systemName: "gearshape.fill")
                .font(.title2)
                .frame(width: size.width, height: size.height)
                .contentShape(.rect)
        }
        .accessibilityLabel("Settings")
        .accessibilityIdentifier("settings.open")
        .offset(x: rect.minX, y: rect.minY)
    }
}

/// Everything the screen-awake decision depends on.
private struct IdleInputs: Equatable {
    let isRoundActive: Bool
    let isShowingResult: Bool
    let lastActivityAt: TimeInterval?
    let scenePhase: ScenePhase

    @MainActor
    init(model: GameModel, scenePhase: ScenePhase) {
        isRoundActive = model.isRoundActive
        isShowingResult = model.reveal != nil
        lastActivityAt = model.lastActivityAt
        self.scenePhase = scenePhase
    }
}

#Preview {
    RootView()
}
