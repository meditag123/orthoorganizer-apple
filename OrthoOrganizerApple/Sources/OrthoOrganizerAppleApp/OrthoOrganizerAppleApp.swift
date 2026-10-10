import SwiftUI

@main
struct OrthoOrganizerAppleApp: App {
    @StateObject private var store = OrganizerStore()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            Group {
                if store.isLocked {
                    LockView()
                } else if store.isAuthenticated {
                    RootView()
                } else {
                    LoginView()
                }
            }
            .environmentObject(store)
            .tint(OrthoTheme.accent(for: store.snapshot.settings.colorTheme))
            .task { await store.restoreSession() }
            .onChange(of: scenePhase) { _, phase in
                store.handleScenePhase(phase)
            }
        }
        #if os(macOS)
        .defaultSize(width: 1180, height: 760)
        #endif
    }
}
