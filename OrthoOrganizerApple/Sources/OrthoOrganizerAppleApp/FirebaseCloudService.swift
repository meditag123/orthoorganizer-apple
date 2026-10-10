import CryptoKit
import Foundation

/// REST implementation of the same Firebase/Firestore contract used by the
/// existing Windows and Android clients. No Firebase SDK is required.
final class FirebaseCloudService: OrganizerCloudService {
    private let projectID = "orthoorganizer-ec5b5"
    private let apiKey = "AIzaSyCq8-7UwQLcZsCuAEOtxBpILdK7fN2jkcc"
    private let chunkSize = 450_000

    func signIn(username: String, password: String) async throws -> OrganizerRemoteSession {
        let cleanUsername = username.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanUsername.isEmpty, password.count >= 6 else { throw OrganizerCloudError.invalidCredentials }
        let index = try await request("GET", firestoreURL("loginIndex/\(sha256Hex(cleanUsername.lowercased()))"))
        let indexFields = fields(index)
        guard let email = stringField(indexFields, "email"),
              let uid = stringField(indexFields, "uid"),
              let vaultID = stringField(indexFields, "vaultId") else {
            throw OrganizerCloudError.invalidCredentials
        }

        let auth = try await request("POST", authURL("signInWithPassword"), body: [
            "email": email,
            "password": password,
            "returnSecureToken": true
        ])
        let idToken = string(auth, "idToken")
        let refreshToken = string(auth, "refreshToken")
        let actualUID = string(auth, "localId")
        guard actualUID == uid else { throw OrganizerCloudError.invalidCredentials }

        let lookup = try await request("POST", authURL("lookup"), body: ["idToken": idToken])
        let users = lookup["users"] as? [[String: Any]] ?? []
        guard users.count == 1, users[0]["localId"] as? String == actualUID else {
            throw OrganizerCloudError.invalidCredentials
        }
        guard users[0]["emailVerified"] as? Bool == true else {
            throw OrganizerCloudError.emailNotVerified
        }

        let keyDocument = try await request("GET", firestoreURL("users/\(actualUID)/vaults/\(vaultID)"), token: idToken)
        guard let encodedKey = stringField(fields(keyDocument), "vaultKey"),
              let archiveKey = Data(base64Encoded: encodedKey),
              sha256Hex(archiveKey) == vaultID else {
            throw OrganizerCloudError.archiveUnavailable
        }

        return OrganizerRemoteSession(username: cleanUsername,
                                      uid: actualUID,
                                      vaultID: vaultID,
                                      refreshToken: refreshToken,
                                      archiveKey: archiveKey,
                                      accessToken: idToken)
    }

    func register(username: String, email: String, password: String) async throws -> OrganizerRemoteSession {
        let cleanUsername = username.trimmingCharacters(in: .whitespacesAndNewlines)
        guard cleanUsername.count >= 3, password.count >= 6, email.contains("@") else {
            throw OrganizerCloudError.invalidCredentials
        }
        let auth = try await request("POST", authURL("signUp"), body: [
            "email": email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
            "password": password,
            "returnSecureToken": true
        ])
        let idToken = string(auth, "idToken")
        let refreshToken = string(auth, "refreshToken")
        let uid = string(auth, "localId")
        let empty = try OrganizerArchiveCodec.createEmptyArchive(username: cleanUsername,
                                                                  email: email,
                                                                  password: password)
        let vaultID = sha256Hex(empty.key)
        let vaultFields: [String: Any] = [
            "vaultKey": ["bytesValue": empty.key.base64EncodedString()],
            "vaultId": ["stringValue": vaultID],
            "username": ["stringValue": cleanUsername],
            "createdAt": ["timestampValue": ISO8601DateFormatter().string(from: .now)]
        ]
        _ = try await request("POST",
                              firestoreURL("users/\(uid)/vaults?documentId=\(vaultID)"),
                              body: ["fields": vaultFields],
                              token: idToken)
        let indexFields: [String: Any] = [
            "username": ["stringValue": cleanUsername],
            "email": ["stringValue": email.lowercased()],
            "uid": ["stringValue": uid],
            "vaultId": ["stringValue": vaultID],
            "updatedAt": ["timestampValue": ISO8601DateFormatter().string(from: .now)]
        ]
        _ = try await request("PATCH",
                              firestoreURL("loginIndex/\(sha256Hex(cleanUsername.lowercased()))"),
                              body: ["fields": indexFields],
                              token: idToken)
        _ = try? await request("POST", authURL("sendOobCode"), body: [
            "requestType": "VERIFY_EMAIL",
            "idToken": idToken
        ])
        let session = OrganizerRemoteSession(username: cleanUsername,
                                             uid: uid,
                                             vaultID: vaultID,
                                             refreshToken: refreshToken,
                                             archiveKey: empty.key,
                                             accessToken: idToken)
        session.archiveObject = empty.object
        session.archiveEntries = empty.entries
        session.archiveHeader = empty.header
        try await upload(snapshot: OrganizerSnapshot(), using: session)
        return session
    }

    func sendPasswordReset(email: String) async throws {
        _ = try await request("POST", authURL("sendOobCode"), body: [
            "requestType": "PASSWORD_RESET",
            "email": email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        ])
    }

    func changePassword(using session: OrganizerRemoteSession, newPassword: String) async throws {
        guard newPassword.count >= 6 else { throw OrganizerCloudError.invalidCredentials }
        let token = try await accessToken(for: session)
        _ = try await request("POST", authURL("update"), body: [
            "idToken": token,
            "password": newPassword,
            "returnSecureToken": true
        ])
    }

    func downloadSnapshot(using session: OrganizerRemoteSession) async throws -> OrganizerSnapshot {
        let profileDocument: [String: Any]
        let token = try await accessToken(for: session)
        do {
            profileDocument = try await request("GET", firestoreURL("users/\(session.uid)/cloud/profile"), token: token)
        } catch {
            throw OrganizerCloudError.archiveUnavailable
        }
        let profile = fields(profileDocument)
        let archiveID = stringField(profile, "archiveId") ?? ""
        let chunkCount = intField(profile, "chunkCount")
        let totalBytes = intField(profile, "totalBytes")
        let expectedHash = stringField(profile, "archiveSha256") ?? ""
        guard !archiveID.isEmpty, chunkCount > 0, chunkCount <= 10_000, totalBytes > 0 else {
            throw OrganizerCloudError.archiveUnavailable
        }

        // Firebase ID tokens are short-lived. The profile request above is
        // intentionally retried through the token refresh path when needed.
        // The current session keeps the refresh token for the next app launch.
        var archive = Data(capacity: totalBytes)
        for index in 0..<chunkCount {
            let path = "users/\(session.uid)/archives/\(archiveID)/chunks/\(String(format: "%08d", index))"
            let document = try await request("GET", firestoreURL(path), token: token)
            let chunkFields = fields(document)
            guard intField(chunkFields, "index") == index,
                  stringField(chunkFields, "archiveId") == archiveID,
                  let payload = stringField(chunkFields, "payload"),
                  let bytes = Data(base64Encoded: payload) else {
                throw OrganizerCloudError.archiveUnavailable
            }
            archive.append(bytes)
        }
        guard archive.count == totalBytes, sha256Hex(archive) == expectedHash else {
            throw OrganizerCloudError.archiveUnavailable
        }

        let decoded = try OrganizerArchiveCodec.decode(zip: archive, key: session.archiveKey)
        session.archiveID = archiveID
        session.archiveObject = decoded.object
        session.archiveEntries = decoded.entries
        session.archiveHeader = decoded.header
        return OrganizerSnapshot.fromCloudObject(decoded.object)
    }

    func upload(snapshot: OrganizerSnapshot, using session: OrganizerRemoteSession) async throws {
        var object = session.archiveObject
        object["duties"] = snapshot.duties.map(Self.dutyObject)
        object["surgeries"] = snapshot.surgeries.map(Self.surgeryObject)
        var settings = object["settings"] as? [String: Any] ?? [:]
        settings["widget_theme"] = snapshot.settings.colorTheme
        settings["widget_enabled"] = snapshot.settings.widgetEnabled
        settings["lock_timeout_minutes"] = snapshot.settings.lockAfterMinutes
        settings["biometrics_enabled"] = snapshot.settings.biometricsEnabled
        settings["show_statistics_on_overview"] = snapshot.settings.showStatisticsOnOverview
        settings["material_companies"] = snapshot.settings.materialCompanies
        object["settings"] = settings

        var entries = session.archiveEntries
        let pendingObjects = session.pendingObjects
        for (sourceID, data) in pendingObjects {
            entries["objects/\(sourceID).enc"] = try OrganizerArchiveCodec.encryptBlob(data, key: session.archiveKey)
        }
        let zip = try OrganizerArchiveCodec.encode(object: object,
                                                   entries: entries,
                                                   header: session.archiveHeader,
                                                   key: session.archiveKey)
        let newArchiveID = sha256Hex(zip)
        let token = try await accessToken(for: session)
        let count = Int(ceil(Double(zip.count) / Double(chunkSize)))
        for index in 0..<count {
            let start = index * chunkSize
            let end = min(zip.count, start + chunkSize)
            let bytes = zip.subdata(in: start..<end)
            let fields: [String: Any] = [
                "archiveId": ["stringValue": newArchiveID],
                "index": ["integerValue": "\(index)"],
                "chunkCount": ["integerValue": "\(count)"],
                "payload": ["bytesValue": bytes.base64EncodedString()],
                "size": ["integerValue": "\(bytes.count)"],
                "sha256": ["stringValue": sha256Hex(bytes)]
            ]
            let path = "users/\(session.uid)/archives/\(newArchiveID)/chunks/\(String(format: "%08d", index))"
            _ = try await request("PATCH", firestoreURL(path), body: ["fields": fields], token: token)
        }
        let profileFields: [String: Any] = [
            "vaultId": ["stringValue": session.vaultID],
            "archiveId": ["stringValue": newArchiveID],
            "chunkCount": ["integerValue": "\(count)"],
            "totalBytes": ["integerValue": "\(zip.count)"],
            "archiveSha256": ["stringValue": newArchiveID],
            "username": ["stringValue": session.username],
            "schema": ["integerValue": "1"],
            "updatedAt": ["timestampValue": ISO8601DateFormatter().string(from: .now)]
        ]
        _ = try await request("PATCH", firestoreURL("users/\(session.uid)/cloud/profile"), body: ["fields": profileFields], token: token)

        session.archiveID = newArchiveID
        session.archiveObject = object
        session.archiveEntries = try OrganizerArchiveCodec.decode(zip: zip, key: session.archiveKey).entries
        for sourceID in pendingObjects.keys { session.pendingObjects.removeValue(forKey: sourceID) }
    }

    func loadAttachment(_ attachment: Attachment, using session: OrganizerRemoteSession) async throws -> Data {
        guard !attachment.sourceID.isEmpty,
              let encrypted = session.archiveEntries["objects/\(attachment.sourceID).enc"] else {
            throw OrganizerCloudError.archiveUnavailable
        }
        return try OrganizerArchiveCodec.decryptBlob(encrypted, key: session.archiveKey)
    }

    private func accessToken(for session: OrganizerRemoteSession) async throws -> String {
        let result = try await request("POST", "https://securetoken.googleapis.com/v1/token?key=\(apiKey)", body: [
            "grant_type": "refresh_token",
            "refresh_token": session.refreshToken
        ])
        let token = string(result, "id_token")
        session.accessToken = token
        return token
    }

    private func request(_ method: String,
                         _ urlString: String,
                         body: [String: Any]? = nil,
                         token: String? = nil) async throws -> [String: Any] {
        guard let url = URL(string: urlString) else { throw OrganizerCloudError.network }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("el", forHTTPHeaderField: "X-Firebase-Locale")
        if let token { request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        if let body { request.httpBody = try JSONSerialization.data(withJSONObject: body, options: []) }
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                throw mapHTTPError(data)
            }
            guard data.isEmpty else {
                return (try JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
            }
            return [:]
        } catch let error as OrganizerCloudError {
            throw error
        } catch {
            throw OrganizerCloudError.network
        }
    }

    private func mapHTTPError(_ data: Data) -> OrganizerCloudError {
        let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
        let message = ((object?["error"] as? [String: Any])?["message"] as? String) ?? ""
        if message.contains("EMAIL_NOT_FOUND") || message.contains("INVALID_LOGIN_CREDENTIALS") ||
            message.contains("INVALID_PASSWORD") || message.contains("EMAIL_EXISTS") {
            return .invalidCredentials
        }
        if message.contains("NOT_FOUND") { return .archiveUnavailable }
        return .network
    }

    private func authURL(_ endpoint: String) -> String {
        "https://identitytoolkit.googleapis.com/v1/accounts:\(endpoint)?key=\(apiKey)"
    }

    private func firestoreURL(_ path: String) -> String {
        "https://firestore.googleapis.com/v1/projects/\(projectID)/databases/(default)/documents/\(path)"
    }

    private func fields(_ document: [String: Any]) -> [String: Any] {
        document["fields"] as? [String: Any] ?? [:]
    }

    private func string(_ object: [String: Any], _ key: String) -> String {
        object[key] as? String ?? ""
    }

    private func stringField(_ fields: [String: Any], _ key: String) -> String? {
        let field = fields[key] as? [String: Any]
        return field?["stringValue"] as? String ?? field?["bytesValue"] as? String
    }

    private func intField(_ fields: [String: Any], _ key: String) -> Int {
        let field = fields[key] as? [String: Any]
        if let value = field?["integerValue"] as? String { return Int(value) ?? 0 }
        return field?["integerValue"] as? Int ?? 0
    }

    private func sha256Hex(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    private static func dutyObject(_ duty: Duty) -> [String: Any] {
        ["id": duty.id.uuidString,
         "date": isoDay(duty.date),
         "type": duty.type.rawValue,
         "hospital": duty.hospital]
    }

    private static func surgeryObject(_ surgery: Surgery) -> [String: Any] {
        ["id": surgery.id.uuidString,
         "patient": surgery.patientName,
         "patronymic": surgery.patronymic,
         "amka": surgery.amka,
         "eama": surgery.eama,
         "age": surgery.age,
         "date": isoDay(surgery.date),
         "procedure": surgery.procedure,
         "diagnosis": surgery.diagnosis,
         "side": surgery.side,
         "company": surgery.company,
         "surgeons": surgery.surgeon,
         "assistants": surgery.assistants.joined(separator: ", "),
         "attachments": surgery.attachments.map { [
            "id": $0.sourceID.isEmpty ? $0.id.uuidString : $0.sourceID,
            "name": $0.name,
            "category": $0.category,
            "size": $0.size,
            "sha256": $0.sha256
         ] }]
    }

    private static func isoDay(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}

private extension OrganizerSnapshot {
    static func fromCloudObject(_ object: [String: Any]) -> OrganizerSnapshot {
        let duties = (object["duties"] as? [[String: Any]] ?? []).compactMap { row -> Duty? in
            guard let dateValue = row["date"] as? String,
                  let date = Date.organizerDate(dateValue) else { return nil }
            return Duty(id: UUID(uuidString: row["id"] as? String ?? "") ?? UUID(),
                        date: date,
                        type: DutyType(rawValue: row["type"] as? String ?? "") ?? .active,
                        hospital: row["hospital"] as? String ?? "")
        }
        let surgeries = (object["surgeries"] as? [[String: Any]] ?? []).compactMap { row -> Surgery? in
            guard let dateValue = row["date"] as? String,
                  let date = Date.organizerDate(dateValue) else { return nil }
            let assistants = (row["assistants"] as? String ?? "")
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            let attachments = (row["attachments"] as? [[String: Any]] ?? []).map {
                Attachment(id: UUID(),
                           sourceID: $0["id"] as? String ?? "",
                           name: $0["name"] as? String ?? "",
                           category: $0["category"] as? String ?? "",
                           size: $0["size"] as? Int ?? 0,
                           sha256: $0["sha256"] as? String ?? "")
            }
            return Surgery(id: UUID(uuidString: row["id"] as? String ?? "") ?? UUID(),
                           patientName: row["patient"] as? String ?? "",
                           patronymic: row["patronymic"] as? String ?? "",
                           amka: row["amka"] as? String ?? "",
                           eama: row["eama"] as? String ?? "",
                           age: row["age"] as? String ?? "",
                           date: date,
                           procedure: row["procedure"] as? String ?? "",
                           diagnosis: row["diagnosis"] as? String ?? "",
                           side: row["side"] as? String ?? "",
                           company: row["company"] as? String ?? "",
                           surgeon: row["surgeons"] as? String ?? "",
                           assistants: assistants,
                           attachments: attachments)
        }
        let settings = object["settings"] as? [String: Any] ?? [:]
        let customCompanies = settings["material_companies"] as? [String] ?? []
        return OrganizerSnapshot(duties: duties,
                                 surgeries: surgeries,
                                 settings: OrganizerSettings(colorTheme: settings["widget_theme"] as? String ?? "navy",
                                                             showStatisticsOnOverview: settings["show_statistics_on_overview"] as? Bool ?? true,
                                                             widgetEnabled: settings["widget_enabled"] as? Bool ?? false,
                                                             lockAfterMinutes: settings["lock_timeout_minutes"] as? Int ?? 0,
                                                             biometricsEnabled: settings["biometrics_enabled"] as? Bool ?? false,
                                                             materialCompanies: customCompanies))
    }
}
