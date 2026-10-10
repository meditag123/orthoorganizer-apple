import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var store: OrganizerStore
    @State private var updateChecks = true
    @State private var showPasswordChange = false

    var body: some View {
        Form {
            Section("Λογαριασμός") {
                LabeledContent("Username", value: store.username)
                Button("Αλλαγή password") { showPasswordChange = true }
                Button("Αποσύνδεση", role: .destructive) { store.signOut() }
            }
            Section("Εμφάνιση") {
                Picker("Χρωματικό θέμα", selection: $store.snapshot.settings.colorTheme) {
                    Text("Navy / Teal").tag("navy")
                    Text("Slate / Blue").tag("slate")
                    Text("Forest / Mint").tag("forest")
                    Text("Burgundy / Rose").tag("burgundy")
                    Text("Amber / Brown").tag("amber")
                }
                Toggle("Εμφάνιση στατιστικών στην επισκόπηση", isOn: $store.snapshot.settings.showStatisticsOnOverview)
            }
            Section("Widget") {
                Toggle("Ενεργοποίηση widget εφημεριών", isOn: Binding(
                    get: { store.snapshot.settings.widgetEnabled },
                    set: { enabled in
                        store.snapshot.settings.widgetEnabled = enabled
                        store.refreshWidget()
                    }))
                Text("Το widget θα εμφανίζει την επόμενη εφημερία και τον ρόλο.")
                    .font(.footnote)
                    .foregroundStyle(OrthoTheme.muted)
            }
            Section("Ασφάλεια") {
                Picker("Κλείδωμα εφαρμογής", selection: $store.snapshot.settings.lockAfterMinutes) {
                    Text("Ποτέ").tag(0)
                    Text("Μετά από 5 λεπτά").tag(5)
                    Text("Μετά από 15 λεπτά").tag(15)
                    Text("Μετά από 30 λεπτά").tag(30)
                }
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
            Section("Ενημερώσεις") {
                Toggle("Αυτόματος έλεγχος ενημερώσεων", isOn: $updateChecks)
                LabeledContent("Τρέχουσα έκδοση", value: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.1.2")
                Text("Οι ενημερώσεις διανέμονται μέσω TestFlight/App Store.")
                    .font(.footnote)
                    .foregroundStyle(OrthoTheme.muted)
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .background(OrthoTheme.canvas)
        .padding(12)
        .onDisappear { store.persistChanges() }
        .sheet(isPresented: $showPasswordChange) {
            PasswordChangeView().environmentObject(store)
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
