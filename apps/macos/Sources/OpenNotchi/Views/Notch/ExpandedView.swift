import SwiftUI

struct ExpandedView: View {
    @EnvironmentObject private var vm: NotchViewModel
    @EnvironmentObject private var settings: AppSettings

    var body: some View {
        let activeTab = settings.visibleTabs.contains(vm.tab) ? vm.tab : .home

        VStack(spacing: 4) {
            HeaderView()
                .frame(height: max(vm.notchSize.height, 28))

            ZStack {
                tabContentView(for: activeTab)
                    .id(activeTab)
                    .transition(
                        .asymmetric(
                            insertion: .move(edge: vm.tabTransitionDirection == .forward ? .trailing : .leading)
                                .combined(with: .opacity),
                            removal: .move(edge: vm.tabTransitionDirection == .forward ? .leading : .trailing)
                                .combined(with: .opacity)
                        )
                    )
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()
        }
    }

    @ViewBuilder
    private func tabContentView(for tab: NotchTab) -> some View {
        switch tab {
        case .home: HomeView()
        case .tray: TrayView()
        case .prompter: PrompterView()
        case .clipboard: ClipboardView()
        case .timer: TimerView()
        case .mirror: MirrorView()
        case .markets: MarketsView()
        case .dev: DevToolsView()
        case .notes: NotesView()
        case .smarthome: SmarthomeView()
        case .ai: AIView()
        }
    }
}
