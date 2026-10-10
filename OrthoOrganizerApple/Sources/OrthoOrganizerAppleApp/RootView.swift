import SwiftUI

struct RootView: View {
    @EnvironmentObject private var store: OrganizerStore

    var body: some View {
        #if os(macOS)
        NavigationSplitView {
            SidebarView()
        } detail: {
            SectionView()
        }
        .background(OrthoTheme.canvas)
        #else
        NavigationStack {
            SectionView()
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Menu {
                            ForEach(OrganizerSection.allCases) { section in
                                Button {
                                    store.selectedSection = section
                                } label: {
                                    Label(section.rawValue, systemImage: section.systemImage)
                                }
                            }
                            Divider()
                            Button("Αποσύνδεση", role: .destructive) { store.signOut() }
                        } label: {
                            Image(systemName: "line.3.horizontal")
                        }
                        .accessibilityLabel("Μενού")
                    }
                }
        }
        #endif
    }
}

struct SidebarView: View {
    @EnvironmentObject private var store: OrganizerStore

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            OrthoLogo()
                .padding(.horizontal, 12)
                .padding(.top, 12)
            List(OrganizerSection.allCases, selection: $store.selectedSection) { section in
                Label(section.rawValue, systemImage: section.systemImage)
                    .tag(section)
            }
            .listStyle(.sidebar)
            Spacer()
            Button("Αποσύνδεση", role: .destructive) { store.signOut() }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
        }
        .frame(minWidth: 240)
    }
}

@ViewBuilder
private func SectionViewContent(_ section: OrganizerSection) -> some View {
    switch section {
    case .overview: OverviewView()
    case .duties: DutiesView()
    case .surgicalArchive: SurgicalArchiveView()
    case .statistics: StatisticsView()
    case .settings: SettingsView()
    }
}

struct SectionView: View {
    @EnvironmentObject private var store: OrganizerStore

    var body: some View {
        SectionViewContent(store.selectedSection)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(OrthoTheme.canvas)
    }
}
