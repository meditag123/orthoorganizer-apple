import Foundation
import SwiftUI
import WidgetKit

@MainActor
final class OrganizerStore: ObservableObject {
    private let cloud: any OrganizerCloudService
    private let keychain = KeychainSessionStore()
    private var remoteSession: OrganizerRemoteSession?
    @Published var isAuthenticated = false
    @Published var isBusy = false
    @Published var username = ""
    @Published var selectedSection: OrganizerSection = .overview
    @Published var snapshot = OrganizerSnapshot()
    @Published var errorMessage: String?
    @Published var statusMessage: String?
    @Published var isLocked = false
    private var backgroundedAt: Date?

    init(cloud: any OrganizerCloudService = FirebaseCloudService()) {
        self.cloud = cloud
    }

    var upcomingDuties: [Duty] {
        snapshot.duties
            .filter { $0.date >= Calendar.current.startOfDay(for: .now) }
            .sorted { $0.date == $1.date ? $0.type.rawValue < $1.type.rawValue : $0.date < $1.date }
    }

    var nextDuty: Duty? { upcomingDuties.first }

    func refreshWidget() {
        if snapshot.settings.widgetEnabled {
            WidgetCache.save(nextDuty: nextDuty)
        } else {
            WidgetCache.save(nextDuty: nil)
        }
        WidgetCenter.shared.reloadAllTimelines()
    }

    func signIn(username: String, password: String) async {
        guard !username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              password.count >= 6 else {
            errorMessage = "Συμπλήρωσε username και password τουλάχιστον 6 χαρακτήρων."
            return
        }
        isBusy = true
        defer { isBusy = false }
        do {
            let session = try await cloud.signIn(username: username, password: password)
            let loadedSnapshot = try await cloud.downloadSnapshot(using: session)
            remoteSession = session
            keychain.save(session)
            self.username = session.username
            self.snapshot = loadedSnapshot
            refreshWidget()
            isAuthenticated = true
            isLocked = false
            backgroundedAt = nil
            errorMessage = nil
            statusMessage = nil
        } catch {
            if !isLocked { isAuthenticated = false }
            let cloudError = error as? LocalizedError
            errorMessage = cloudError?.errorDescription ?? "Η σύνδεση δεν ολοκληρώθηκε."
        }
    }

    func register(username: String, email: String, password: String) async {
        isBusy = true
        defer { isBusy = false }
        do {
            let session = try await cloud.register(username: username, email: email, password: password)
            remoteSession = session
            keychain.save(session)
            self.username = session.username
            snapshot = OrganizerSnapshot()
            refreshWidget()
            isAuthenticated = true
            errorMessage = nil
            statusMessage = "Ο λογαριασμός δημιουργήθηκε. Έλεγξε το email επιβεβαίωσης."
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "Δεν δημιουργήθηκε ο λογαριασμός."
        }
    }

    func sendPasswordReset(email: String) async {
        isBusy = true
        defer { isBusy = false }
        do {
            try await cloud.sendPasswordReset(email: email)
            errorMessage = nil
            statusMessage = "Στάλθηκε σύνδεσμος επαναφοράς στο email."
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "Δεν στάλθηκε το email επαναφοράς."
        }
    }

    func changePassword(_ password: String) async {
        guard let session = remoteSession else { return }
        isBusy = true
        defer { isBusy = false }
        do {
            try await cloud.changePassword(using: session, newPassword: password)
            statusMessage = "Το password άλλαξε επιτυχώς."
            errorMessage = nil
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "Δεν άλλαξε το password."
        }
    }

    func signOut() {
        remoteSession = nil
        keychain.delete()
        username = ""
        isAuthenticated = false
        selectedSection = .overview
        snapshot = OrganizerSnapshot()
        errorMessage = nil
        statusMessage = nil
        isLocked = false
        backgroundedAt = nil
        refreshWidget()
    }

    func handleScenePhase(_ phase: ScenePhase) {
        switch phase {
        case .background:
            backgroundedAt = .now
        case .active:
            guard isAuthenticated,
                  snapshot.settings.lockAfterMinutes > 0,
                  let backgroundedAt,
                  Date().timeIntervalSince(backgroundedAt) >= Double(snapshot.settings.lockAfterMinutes * 60) else {
                return
            }
            isLocked = true
        default:
            break
        }
    }

    func unlockWithBiometrics() async -> Bool {
        guard snapshot.settings.biometricsEnabled,
              await BiometricAuth.authenticate(reason: "Ξεκλείδωσε το OrthoOrganizer") else {
            return false
        }
        isLocked = false
        backgroundedAt = nil
        return true
    }

    func addDuty() {
        snapshot.duties.append(Duty(date: .now, type: .active, hospital: ""))
        refreshWidget()
        persistChanges()
    }

    func saveDuty(_ duty: Duty) {
        if let index = snapshot.duties.firstIndex(where: { $0.id == duty.id }) {
            snapshot.duties[index] = duty
        } else {
            snapshot.duties.append(duty)
        }
        refreshWidget()
        persistChanges()
    }

    func deleteDuty(_ duty: Duty) {
        snapshot.duties.removeAll { $0.id == duty.id }
        refreshWidget()
        persistChanges()
    }

    func saveSurgery(_ surgery: Surgery, pendingAttachments: [String: Data] = [:]) {
        if let index = snapshot.surgeries.firstIndex(where: { $0.id == surgery.id }) {
            snapshot.surgeries[index] = surgery
        } else {
            snapshot.surgeries.append(surgery)
        }
        for (sourceID, data) in pendingAttachments {
            remoteSession?.pendingObjects[sourceID] = data
        }
        persistChanges()
    }

    func deleteSurgery(_ surgery: Surgery) {
        snapshot.surgeries.removeAll { $0.id == surgery.id }
        persistChanges()
    }

    func persistChanges() {
        guard let session = remoteSession else { return }
        Task {
            do {
                try await cloud.upload(snapshot: snapshot, using: session)
            } catch {
                errorMessage = (error as? LocalizedError)?.errorDescription ?? "Δεν αποθηκεύτηκε η αλλαγή στο cloud."
            }
        }
    }

    func loadAttachment(_ attachment: Attachment) async throws -> Data {
        guard let session = remoteSession else { throw OrganizerCloudError.archiveUnavailable }
        return try await cloud.loadAttachment(attachment, using: session)
    }

    func restoreSession() async {
        guard !isAuthenticated, let session = keychain.load() else { return }
        if UserDefaults.standard.bool(forKey: "orthoorganizer.biometrics.enabled") {
            guard await BiometricAuth.authenticate(reason: "Ξεκλείδωσε το OrthoOrganizer") else {
                errorMessage = "Δεν έγινε βιομετρική ταυτοποίηση."
                return
            }
        }
        isBusy = true
        defer { isBusy = false }
        do {
            let loadedSnapshot = try await cloud.downloadSnapshot(using: session)
            remoteSession = session
            username = session.username
            snapshot = loadedSnapshot
            refreshWidget()
            isAuthenticated = true
            errorMessage = nil
            statusMessage = nil
        } catch {
            // Keep the stored session until an explicit logout; a temporary
            // network failure should not force the user to re-enter credentials.
            errorMessage = (error as? LocalizedError)?.errorDescription
        }
    }

    func enableBiometrics() async {
        guard await BiometricAuth.authenticate(reason: "Ενεργοποίηση βιομετρικού ξεκλειδώματος") else {
            errorMessage = "Η συσκευή δεν επιβεβαίωσε το βιομετρικό ξεκλείδωμα."
            return
        }
        snapshot.settings.biometricsEnabled = true
        UserDefaults.standard.set(true, forKey: "orthoorganizer.biometrics.enabled")
        persistChanges()
    }

    func disableBiometrics() {
        snapshot.settings.biometricsEnabled = false
        UserDefaults.standard.set(false, forKey: "orthoorganizer.biometrics.enabled")
        persistChanges()
    }
}
