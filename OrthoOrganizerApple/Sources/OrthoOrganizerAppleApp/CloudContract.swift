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
}

final class OrganizerRemoteSession {
    let username: String
    let uid: String
    let vaultID: String
    let refreshToken: String
    let archiveKey: Data
    var accessToken: String
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

enum OrganizerCloudError: LocalizedError {
    case invalidCredentials
    case emailNotVerified
    case archiveUnavailable
    case network
    case notConfigured

    var errorDescription: String? {
        switch self {
        case .invalidCredentials: return "Το username ή το password δεν είναι σωστό."
        case .emailNotVerified: return "Άνοιξε πρώτα το email επιβεβαίωσης του cloud λογαριασμού."
        case .archiveUnavailable: return "Δεν βρέθηκε το συγχρονισμένο αρχείο."
        case .network: return "Δεν υπάρχει σύνδεση με την υπηρεσία cloud."
        case .notConfigured: return "Δεν έχει ολοκληρωθεί ακόμη η ρύθμιση του Apple cloud client."
        }
    }
}

enum OrganizerUpdateSource {
    static let manifestURL = URL(string: "https://raw.githubusercontent.com/meditag123/orthoorganizer-releases/main/latest.json")!
}
