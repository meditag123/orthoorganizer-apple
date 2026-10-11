import Foundation

/// Shared cloud contract used by the Windows and Android clients.
/// The SwiftUI screens depend on this small protocol instead of knowing how
/// Firebase, the encrypted archive, or the update manifest are implemented.
protocol OrganizerCloudService {
    func signIn(username: String, password: String) async throws -> OrganizerRemoteSession
    func register(username: String, email: String, password: String) async throws -> OrganizerRemoteSession
    func sendPasswordReset(email: String) async throws
    func changePassword(using session: OrganizerRemoteSession, newPassword: String) async throws
    func downloadSnapshot(using session: OrganizerRemoteSession) async throws -> OrganizerSnapshot
    func loadAttachment(_ attachment: Attachment, using session: OrganizerRemoteSession) async throws -> Data
    func upload(snapshot: OrganizerSnapshot, using session: OrganizerRemoteSession) async throws
    func loadAdminDashboard(using session: OrganizerRemoteSession) async throws -> AdminDashboard
    func updateAdminPolicy(_ policy: OrganizerAppPolicy, using session: OrganizerRemoteSession) async throws
    func updateManagedUser(_ user: ManagedUser, using session: OrganizerRemoteSession) async throws
    func revokeManagedUserSessions(_ user: ManagedUser, using session: OrganizerRemoteSession) async throws
}

struct OrganizerAppPolicy: Hashable {
    var registrationOpen: Bool = true
    var approvalRequired: Bool = true
    var maximumActiveUsers: Int = 10
    var maximumDevicesPerUser: Int = 2
    var minimumAppVersion: String = "0.6.6"
    var activeUserCount: Int = 0
}

struct ManagedUser: Identifiable, Hashable {
    var id: String { uid }
    let uid: String
    var username: String
    var email: String
    var status: String
    var role: String
    var deviceCount: Int
    var lastSeen: String
    var sessionVersion: Int

    var isActive: Bool { status == "active" }
    var isPending: Bool { status == "pending" }
}

struct AdminDashboard: Hashable {
    var policy = OrganizerAppPolicy()
    var users: [ManagedUser] = []
}

final class OrganizerRemoteSession {
    let username: String
    let uid: String
    let vaultID: String
    let refreshToken: String
    let archiveKey: Data
    var accessToken: String
    var role: String = "user"
    var sessionVersion: Int = 1
    var deviceID: String = InstallationIdentity.current
    var requiresApproval = false
    var archiveID: String = ""
    var archiveObject: [String: Any] = [:]
    var archiveEntries: [String: Data] = [:]
    var archiveHeader = Data()
    /// New attachment bytes are kept only for the current upload and are
    /// encrypted into the archive before the metadata is committed.
    var pendingObjects: [String: Data] = [:]

    init(username: String, uid: String, vaultID: String, refreshToken: String, archiveKey: Data, accessToken: String = "") {
        self.username = username
        self.uid = uid
        self.vaultID = vaultID
        self.refreshToken = refreshToken
        self.archiveKey = archiveKey
        self.accessToken = accessToken
    }
}

enum OrganizerCloudError: LocalizedError, Equatable {
    case invalidCredentials
    case emailNotVerified
    case archiveUnavailable
    case network
    case notConfigured
    case registrationClosed
    case accountPending
    case accountSuspended
    case deviceLimitReached
    case userLimitReached
    case minimumVersionRequired
    case notAuthorized

    var errorDescription: String? {
        switch self {
        case .invalidCredentials: return "Το username ή το password δεν είναι σωστό."
        case .emailNotVerified: return "Άνοιξε πρώτα το email επιβεβαίωσης του cloud λογαριασμού."
        case .archiveUnavailable: return "Δεν βρέθηκε το συγχρονισμένο αρχείο."
        case .network: return "Δεν υπάρχει σύνδεση με την υπηρεσία cloud."
        case .notConfigured: return "Δεν έχει ολοκληρωθεί ακόμη η ρύθμιση του Apple cloud client."
        case .registrationClosed: return "Οι νέες εγγραφές είναι προσωρινά κλειστές."
        case .accountPending: return "Ο λογαριασμός δημιουργήθηκε και περιμένει έγκριση διαχειριστή."
        case .accountSuspended: return "Ο λογαριασμός έχει ανασταλεί από τον διαχειριστή."
        case .deviceLimitReached: return "Έχει συμπληρωθεί το όριο συσκευών για αυτόν τον λογαριασμό."
        case .userLimitReached: return "Έχει συμπληρωθεί το μέγιστο όριο ενεργών χρηστών."
        case .minimumVersionRequired: return "Απαιτείται νεότερη έκδοση της εφαρμογής."
        case .notAuthorized: return "Δεν έχεις δικαιώματα διαχειριστή."
        }
    }
}

enum InstallationIdentity {
    static var current: String {
        let key = "orthoorganizer.installation.id"
        if let value = UserDefaults.standard.string(forKey: key), !value.isEmpty {
            return value
        }
        let value = UUID().uuidString.lowercased()
        UserDefaults.standard.set(value, forKey: key)
        return value
    }
}

enum OrganizerUpdateSource {
    static let manifestURL = URL(string: "https://raw.githubusercontent.com/meditag123/orthoorganizer-releases/main/latest.json")!
}
