import SwiftUI

struct RootView: View {
    @EnvironmentObject private var store: OrganizerStore
    @State private var menuIsOpen = false

    var body: some View {
        #if os(macOS)
        NavigationSplitView {
            SidebarView()
        } detail: {
            SectionView()
        }
        .background(OrthoTheme.canvas)
        #else
        ZStack(alignment: .leading) {
            VStack(spacing: 0) {
                OrthoHeader(
                    title: store.selectedSection.rawValue,
                    onMenu: { withAnimation(.easeInOut(duration: 0.22)) { menuIsOpen = true } },
                    onRefresh: { Task { await store.syncNow() } }
                )
                SectionView()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .allowsHitTesting(!menuIsOpen)

            if menuIsOpen {
                Color.black.opacity(0.30)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.22)) { menuIsOpen = false }
                    }
                    .transition(.opacity)
                    .zIndex(1)

                MobileMenuDrawer {
                    withAnimation(.easeInOut(duration: 0.22)) { menuIsOpen = false }
                }
                .transition(.move(edge: .leading))
                .zIndex(2)
            }
        }
        .background(OrthoTheme.canvas)
        .animation(.easeInOut(duration: 0.22), value: menuIsOpen)
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
            Text(store.username)
                .font(.subheadline)
                .foregroundStyle(OrthoTheme.muted)
                .padding(.horizontal, 16)
            List {
                ForEach(OrganizerSection.allCases) { section in
                    Button {
                        store.selectedSection = section
                    } label: {
                        Label(section.rawValue, systemImage: section.systemImage)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                }
                if store.isAdmin {
                    Button {
                        store.selectedSection = .settings
                    } label: {
                        Label("Διαχείριση χρηστών", systemImage: "person.badge.key")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                }
            }
            .listStyle(.sidebar)
            Spacer()
            Button("Συγχρονισμός") {
                Task { await store.syncNow() }
            }
            .padding(.horizontal, 16)
            Button("Αποσύνδεση λογαριασμού", role: .destructive) { store.signOut() }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
        }
        .frame(minWidth: 260)
    }
}

#if !os(macOS)
private struct MobileMenuDrawer: View {
    @EnvironmentObject private var store: OrganizerStore
    let close: () -> Void

    var body: some View {
        GeometryReader { proxy in
            VStack(alignment: .leading, spacing: 0) {
                VStack(spacing: 10) {
                    OrthoMark()
                    Text("OrthoOrganizer")
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundStyle(OrthoTheme.navy)
                    if !store.username.isEmpty {
                        Text(store.username)
                            .font(.headline)
                            .foregroundStyle(OrthoTheme.muted)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 28)
                .padding(.bottom, 22)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 12) {
                        ForEach(OrganizerSection.allCases) { section in
                            DrawerRow(
                                title: section.rawValue,
                                icon: section.systemImage,
                                selected: store.selectedSection == section
                            ) {
                                store.selectedSection = section
                                close()
                            }
                        }

                        if store.isAdmin {
                            DrawerRow(title: "Διαχείριση χρηστών", icon: "person.badge.key", selected: false) {
                                store.selectedSection = .settings
                                close()
                            }
                        }

                        Divider()
                            .padding(.vertical, 8)

                        DrawerRow(title: "Συγχρονισμός", icon: "arrow.triangle.2.circlepath", selected: false) {
                            Task { await store.syncNow() }
                            close()
                        }

                        DrawerRow(title: "Αποσύνδεση λογαριασμού", icon: "rectangle.portrait.and.arrow.right", selected: false, destructive: true) {
                            store.signOut()
                            close()
                        }
                    }
                    .padding(.horizontal, 20)
                }

                Spacer(minLength: 14)
                Text("v\(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.6.6")")
                    .font(.subheadline)
                    .foregroundStyle(OrthoTheme.muted)
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 18)
            }
            .frame(width: min(360, proxy.size.width * 0.82), height: proxy.size.height)
            .background(Color.white)
            .shadow(color: .black.opacity(0.18), radius: 16, x: 8, y: 0)
        }
        .ignoresSafeArea()
    }
}

private struct DrawerRow: View {
    let title: String
    let icon: String
    let selected: Bool
    var destructive = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .frame(width: 24)
                Text(title)
                    .font(.system(size: 17, weight: selected ? .semibold : .regular, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
                Spacer(minLength: 0)
            }
            .foregroundStyle(destructive ? Color.red : (selected ? Color.white : OrthoTheme.navy))
            .padding(.horizontal, 18)
            .frame(maxWidth: .infinity, minHeight: 58, alignment: .leading)
            .background(
                selected ? OrthoTheme.navy : (destructive ? Color.red.opacity(0.07) : OrthoTheme.mint),
                in: RoundedRectangle(cornerRadius: 17, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 17, style: .continuous)
                    .stroke(selected ? OrthoTheme.navy : OrthoTheme.mintBorder, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }
}
#endif

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
