import SwiftUI

struct AdminView: View {
    @EnvironmentObject private var store: OrganizerStore
    @Environment(\.dismiss) private var dismiss
    @State private var policy = OrganizerAppPolicy()
    @State private var userToSuspend: ManagedUser?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Διαχείριση")
                        .font(.largeTitle.weight(.semibold))
                        .foregroundStyle(OrthoTheme.navy)

                    SettingsGroup(title: "Πρόσβαση", icon: "person.badge.key") {
                        Toggle("Νέες εγγραφές", isOn: $policy.registrationOpen)
                        Divider()
                        LabeledContent("Έγκριση λογαριασμών", value: "Πάντα")
                        Divider()
                        Stepper("Ενεργοί χρήστες: \(policy.maximumActiveUsers)", value: $policy.maximumActiveUsers, in: 1...100)
                        Divider()
                        Stepper("Συσκευές ανά χρήστη: \(policy.maximumDevicesPerUser)", value: $policy.maximumDevicesPerUser, in: 1...10)
                        Divider()
                        TextField("Ελάχιστη έκδοση", text: $policy.minimumAppVersion)
                        Divider()
                        LabeledContent("Ενεργοί τώρα", value: "\(store.adminDashboard.users.filter(\.isActive).count) / \(policy.maximumActiveUsers)")
                        Button {
                            Task { await store.saveAdminPolicy(policy) }
                        } label: {
                            Label("Αποθήκευση", systemImage: "checkmark")
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(store.adminBusy)
                    }

                    SettingsGroup(title: "Λογαριασμοί", icon: "person.2") {
                        if store.adminDashboard.users.isEmpty {
                            Text("Δεν υπάρχουν λογαριασμοί")
                                .foregroundStyle(OrthoTheme.muted)
                        } else {
                            ForEach(store.adminDashboard.users) { user in
                                ManagedUserRow(user: user,
                                               canSuspend: user.uid != currentAdminID,
                                               onApprove: {
                                                   Task { await store.setManagedUserStatus(user, status: "active") }
                                               },
                                               onSuspend: { userToSuspend = user },
                                               onRevoke: {
                                                   Task { await store.revokeSessions(for: user) }
                                               })
                                if user.id != store.adminDashboard.users.last?.id {
                                    Divider()
                                }
                            }
                        }
                    }

                    if let error = store.errorMessage {
                        Text(error)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                    if let status = store.statusMessage {
                        Text(status)
                            .font(.footnote)
                            .foregroundStyle(OrthoTheme.teal)
                    }
                }
                .padding(20)
            }
            .background(OrthoTheme.canvas)
            .task {
                await store.loadAdminDashboard()
                policy = store.adminDashboard.policy
            }
            .onChange(of: store.adminDashboard) { _, updated in
                if !store.adminBusy { policy = updated.policy }
            }
            .navigationTitle("Διαχείριση")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Κλείσιμο") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        Task { await store.loadAdminDashboard() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(store.adminBusy)
                }
            }
        }
        .frame(minWidth: 620, minHeight: 640)
        .confirmationDialog("Αναστολή λογαριασμού", item: $userToSuspend) { user in
            Button("Αναστολή", role: .destructive) {
                Task { await store.setManagedUserStatus(user, status: "suspended") }
            }
            Button("Άκυρο", role: .cancel) {}
        }
    }

    private var currentAdminID: String {
        store.adminDashboard.users.first(where: { $0.role == "admin" && $0.status == "active" })?.uid ?? ""
    }
}

private struct ManagedUserRow: View {
    let user: ManagedUser
    let canSuspend: Bool
    let onApprove: () -> Void
    let onSuspend: () -> Void
    let onRevoke: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(user.username)
                    .font(.headline)
                    .foregroundStyle(OrthoTheme.navy)
                Spacer()
                Text(statusTitle)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(statusColor)
            }
            if !user.email.isEmpty {
                Text(user.email)
                    .font(.subheadline)
                    .foregroundStyle(OrthoTheme.muted)
            }
            HStack(spacing: 12) {
                if user.isPending {
                    Button("Έγκριση", action: onApprove)
                        .buttonStyle(.borderedProminent)
                } else if user.isActive && canSuspend {
                    Button("Αναστολή", role: .destructive, action: onSuspend)
                        .buttonStyle(.bordered)
                }
                Button("Ανάκληση συνδέσεων", action: onRevoke)
                    .buttonStyle(.bordered)
            }
            .font(.footnote)
        }
    }

    private var statusTitle: String {
        switch user.status {
        case "active": return "Ενεργός"
        case "suspended": return "Ανεσταλμένος"
        default: return "Σε αναμονή"
        }
    }

    private var statusColor: Color {
        switch user.status {
        case "active": return OrthoTheme.teal
        case "suspended": return .red
        default: return .orange
        }
    }
}
