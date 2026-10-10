import SwiftUI

struct LockView: View {
    @EnvironmentObject private var store: OrganizerStore
    @State private var password = ""

    var body: some View {
        ZStack {
            OrthoTheme.canvas.ignoresSafeArea()
            OrthoCard {
                VStack(spacing: 16) {
                    OrthoLogo()
                    Image(systemName: "lock.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(OrthoTheme.teal)
                    Text("Η εφαρμογή είναι κλειδωμένη")
                        .font(.headline)
                    Text(store.username)
                        .font(.subheadline)
                        .foregroundStyle(OrthoTheme.muted)

                    if store.snapshot.settings.biometricsEnabled {
                        Button {
                            Task { _ = await store.unlockWithBiometrics() }
                        } label: {
                            Label("Ξεκλείδωμα με Face ID / Touch ID", systemImage: "faceid")
                        }
                        .buttonStyle(.borderedProminent)
                    }

                    SecureField("Password", text: $password)
                        .textFieldStyle(.roundedBorder)
                    Button("Ξεκλείδωμα") {
                        Task {
                            await store.signIn(username: store.username, password: password)
                            if store.isAuthenticated { store.isLocked = false }
                        }
                    }
                    .buttonStyle(.bordered)
                    .disabled(password.count < 6 || store.isBusy)

                    Button("Αποσύνδεση", role: .destructive) { store.signOut() }
                        .buttonStyle(.plain)
                        .font(.footnote)
                }
                .frame(maxWidth: 360)
            }
            .padding(20)
        }
    }
}
