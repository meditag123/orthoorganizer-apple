import SwiftUI

struct LoginView: View {
    @EnvironmentObject private var store: OrganizerStore
    @State private var username = ""
    @State private var password = ""
    @State private var showSignup = false
    @State private var showReset = false

    var body: some View {
        ZStack {
            OrthoTheme.canvas.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 24) {
                    OrthoLogo()
                        .padding(.top, 40)

                    OrthoCard {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Σύνδεση")
                                .font(.title2.weight(.bold))
                            Text("Χρησιμοποίησε τα ίδια στοιχεία με Windows και Android.")
                                .font(.subheadline)
                                .foregroundStyle(OrthoTheme.muted)

                            TextField("Username", text: $username)
                                .textFieldStyle(.roundedBorder)
                                #if os(iOS)
                                .textContentType(.username)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                #endif

                            SecureField("Password", text: $password)
                                .textFieldStyle(.roundedBorder)
                                #if os(iOS)
                                .textContentType(.password)
                                #endif

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

                            Button {
                                Task { await store.signIn(username: username, password: password) }
                            } label: {
                                HStack {
                                    Spacer()
                                    if store.isBusy { ProgressView().tint(.white) }
                                    Text("Σύνδεση")
                                        .fontWeight(.semibold)
                                    Spacer()
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(store.isBusy)

                            HStack {
                                Button("Ξέχασα το password") { showReset = true }
                                    .buttonStyle(.plain)
                                Spacer()
                                Button("Νέος λογαριασμός") { showSignup = true }
                                    .buttonStyle(.plain)
                            }
                            .font(.footnote)
                            .foregroundStyle(OrthoTheme.teal)
                        }
                    }
                    .frame(maxWidth: 470)
                }
                .padding(.horizontal, 20)
            }
        }
        .sheet(isPresented: $showSignup) {
            SignupView().environmentObject(store)
        }
        .sheet(isPresented: $showReset) {
            PasswordResetView().environmentObject(store)
        }
    }
}

struct SignupView: View {
    @EnvironmentObject private var store: OrganizerStore
    @Environment(\.dismiss) private var dismiss
    @State private var username = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirm = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Στοιχεία λογαριασμού") {
                    TextField("Username", text: $username)
                    TextField("Email επαναφοράς", text: $email)
                        #if os(iOS)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        #endif
                    SecureField("Password (τουλάχιστον 6 χαρακτήρες)", text: $password)
                    SecureField("Επανάληψη password", text: $confirm)
                }
                if let error = store.errorMessage {
                    Text(error).foregroundStyle(.red)
                }
                Button("Δημιουργία λογαριασμού") {
                    guard password == confirm else {
                        store.errorMessage = "Τα δύο password δεν είναι ίδια."
                        return
                    }
                    Task {
                        await store.register(username: username, email: email, password: password)
                        if store.isAuthenticated { dismiss() }
                    }
                }
                .disabled(store.isBusy || username.isEmpty || email.isEmpty || password.count < 6)
            }
            .navigationTitle("Νέος λογαριασμός")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Άκυρο") { dismiss() }
                }
            }
        }
        .frame(minWidth: 420, minHeight: 420)
    }
}

struct PasswordResetView: View {
    @EnvironmentObject private var store: OrganizerStore
    @Environment(\.dismiss) private var dismiss
    @State private var email = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Θα σταλεί σύνδεσμος επαναφοράς στο προσωπικό email του λογαριασμού.")
                        .font(.subheadline)
                        .foregroundStyle(OrthoTheme.muted)
                    TextField("Email", text: $email)
                        #if os(iOS)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        #endif
                }
                if let error = store.errorMessage {
                    Text(error).foregroundStyle(.red)
                }
                if let status = store.statusMessage {
                    Text(status).foregroundStyle(OrthoTheme.teal)
                }
                Button("Αποστολή email επαναφοράς") {
                    Task { await store.sendPasswordReset(email: email) }
                }
                .disabled(store.isBusy || email.isEmpty)
            }
            .navigationTitle("Επαναφορά password")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Κλείσιμο") { dismiss() }
                }
            }
        }
        .frame(minWidth: 420, minHeight: 300)
    }
}
