import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var store: OrganizerStore
    @State private var updateChecks = true
    @State private var showPasswordChange = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Ρυθμίσεις")
                    .font(.largeTitle.weight(.semibold))
                    .foregroundStyle(OrthoTheme.navy)

                SettingsGroup(title: "Λογαριασμός", icon: "person.crop.circle") {
                    LabeledContent("Username", value: store.username)
                    Divider()
                    Button("Αλλαγή password") { showPasswordChange = true }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Divider()
                    Button("Αποσύνδεση λογαριασμού", role: .destructive) { store.signOut() }
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                SettingsGroup(title: "Εμφάνιση", icon: "paintpalette") {
                    Picker("Χρωματικό θέμα", selection: $store.snapshot.settings.colorTheme) {
                        Text("Navy / Teal").tag("navy")
                        Text("Slate / Blue").tag("slate")
                        Text("Forest / Mint").tag("forest")
                        Text("Burgundy / Rose").tag("burgundy")
                        Text("Amber / Brown").tag("amber")
                    }
                    .pickerStyle(.menu)
                    Divider()
                    Toggle("Εμφάνιση στατιστικών στην επισκόπηση", isOn: $store.snapshot.settings.showStatisticsOnOverview)
                }

                SettingsGroup(title: "Widget", icon: "rectangle.on.rectangle") {
                    Toggle("Ενεργοποίηση widget εφημεριών", isOn: Binding(
                        get: { store.snapshot.settings.widgetEnabled },
                        set: { enabled in
                            store.snapshot.settings.widgetEnabled = enabled
                            store.refreshWidget()
                        }))
                }

                SettingsGroup(title: "Ασφάλεια", icon: "lock.shield") {
                    Picker("Κλείδωμα εφαρμογής", selection: $store.snapshot.settings.lockAfterMinutes) {
                        Text("Ποτέ").tag(0)
                        Text("Μετά από 5 λεπτά").tag(5)
                        Text("Μετά από 15 λεπτά").tag(15)
                        Text("Μετά από 30 λεπτά").tag(30)
                    }
                    .pickerStyle(.menu)
                    Divider()
                    Toggle("Face ID / Touch ID", isOn: Binding(
                        get: { store.snapshot.settings.biometricsEnabled },
                        set: { enabled in
                            if enabled {
                                Task { await store.enableBiometrics() }
                            } else {
                                store.disableBiometrics()
                            }
                        }))
                }

                SettingsGroup(title: "Cloud", icon: "icloud") {
                    Button {
                        Task { await store.syncNow() }
                    } label: {
                        Label("Συγχρονισμός τώρα", systemImage: "arrow.triangle.2.circlepath")
                    }
                    if let status = store.statusMessage {
                        Text(status)
                            .font(.caption)
                            .foregroundStyle(OrthoTheme.teal)
                    }
                }

                SettingsGroup(title: "Ενημερώσεις", icon: "arrow.down.circle") {
                    Toggle("Αυτόματος έλεγχος ενημερώσεων", isOn: $updateChecks)
                    Divider()
                    LabeledContent("Τρέχουσα έκδοση", value: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.6.6")
                }
            }
            .padding(20)
        }
        .onDisappear { store.persistChanges() }
        .sheet(isPresented: $showPasswordChange) {
            PasswordChangeView().environmentObject(store)
        }
    }
}

private struct SettingsGroup<Content: View>: View {
    let title: String
    let icon: String
    let content: Content

    init(title: String, icon: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundStyle(OrthoTheme.teal)
                Text(title)
                    .font(.headline)
                    .foregroundStyle(OrthoTheme.navy)
            }
            content
                .tint(OrthoTheme.teal)
        }
        .padding(16)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(OrthoTheme.divider, lineWidth: 1)
        }
    }
}

struct PasswordChangeView: View {
    @EnvironmentObject private var store: OrganizerStore
    @Environment(\.dismiss) private var dismiss
    @State private var password = ""
    @State private var confirmation = ""

    var body: some View {
        NavigationStack {
            Form {
                SecureField("Νέο password", text: $password)
                SecureField("Επανάληψη password", text: $confirmation)
                if let error = store.errorMessage {
                    Text(error).foregroundStyle(.red)
                }
                if let status = store.statusMessage {
                    Text(status).foregroundStyle(OrthoTheme.teal)
                }
                Button("Αποθήκευση") {
                    guard password == confirmation else {
                        store.errorMessage = "Τα δύο password δεν είναι ίδια."
                        return
                    }
                    Task {
                        await store.changePassword(password)
                        if store.errorMessage == nil { dismiss() }
                    }
                }
                .disabled(store.isBusy || password.count < 6)
            }
            .navigationTitle("Αλλαγή password")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Άκυρο") { dismiss() }
                }
            }
        }
        .frame(minWidth: 420, minHeight: 300)
    }
}
