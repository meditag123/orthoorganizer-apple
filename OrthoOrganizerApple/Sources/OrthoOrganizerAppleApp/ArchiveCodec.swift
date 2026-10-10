import CryptoKit
import CryptoSwift
import Foundation
import ZIPFoundation

struct DecodedOrganizerArchive {
    var object: [String: Any]
    var entries: [String: Data]
    var header: Data
}

enum OrganizerArchiveCodec {
    private static let magic = Data([0x4f, 0x52, 0x54, 0x48, 0x4f, 0x31, 0x00]) // ORTHO1\0
    private static let magicV2 = Data([0x4f, 0x52, 0x54, 0x48, 0x4f, 0x32, 0x00]) // ORTHO2\0
    private static let keyAAD = Data("ORTHO2-KEY".utf8)

    static func createEmptyArchive(username: String,
                                    email: String,
                                    password: String) throws -> (zip: Data, key: Data, object: [String: Any], entries: [String: Data], header: Data) {
        let key = Data((0..<32).map { _ in UInt8.random(in: 0...255) })
        let salt = Data((0..<16).map { _ in UInt8.random(in: 0...255) })
        let passwordKey = try Scrypt(password: Array(password.utf8),
                                     salt: Array(salt),
                                     dkLen: 32,
                                     N: 32_768,
                                     r: 8,
                                     p: 1).calculate()
        let wrapped = try AES.GCM.seal(key,
                                       using: SymmetricKey(data: Data(passwordKey)),
                                       authenticating: keyAAD)
        var header = magicV2
        header.append(salt)
        header.append(Data(wrapped.nonce))
        header.append(wrapped.ciphertext)
        header.append(wrapped.tag)
        let object: [String: Any] = [
            "schema": 1,
            "created": ISO8601DateFormatter().string(from: .now),
            "account": ["username": username, "email": email, "kind": "local"],
            "settings": [
                "name": "", "aliases": [], "hospital": "", "material_companies": [],
                "widget_enabled": false, "widget_theme": "navy", "remember_session": true,
                "lock_timeout_minutes": 0, "lock_on_resume": false,
                "show_statistics_on_overview": true
            ],
            "duties": [], "coverage": [:], "imports": [], "surgeries": [],
            "surgery_imports": [], "audit": []
        ]
        let zip = try encode(object: object, entries: [:], header: header, key: key)
        let decoded = try decode(zip: zip, key: key)
        return (zip, key, object, decoded.entries, header)
    }

    static func decode(zip: Data, key: Data) throws -> DecodedOrganizerArchive {
        let entries = try unzip(zip)
        guard let raw = entries["archive.ortho"] else { throw OrganizerCloudError.archiveUnavailable }
        let headerLength: Int
        if raw.starts(with: magicV2) && raw.count >= 83 + 28 {
            headerLength = 83
        } else if raw.starts(with: magic) && raw.count >= 23 + 28 {
            headerLength = 23
        } else {
            throw OrganizerCloudError.archiveUnavailable
        }
        let payload = raw.subdata(in: headerLength..<raw.count)
        guard payload.count >= 28 else { throw OrganizerCloudError.archiveUnavailable }
        let nonceData = payload.subdata(in: 0..<12)
        let encrypted = payload.subdata(in: 12..<payload.count)
        let ciphertext = Data(encrypted.dropLast(16))
        let tag = Data(encrypted.suffix(16))
        let nonce = try AES.GCM.Nonce(data: nonceData)
        let sealed = try AES.GCM.SealedBox(nonce: nonce, ciphertext: ciphertext, tag: tag)
        let plain = try AES.GCM.open(sealed, using: SymmetricKey(data: key), authenticating: magic)
        guard let object = try JSONSerialization.jsonObject(with: plain) as? [String: Any] else {
            throw OrganizerCloudError.archiveUnavailable
        }
        return DecodedOrganizerArchive(object: object,
                                       entries: entries,
                                       header: raw.subdata(in: 0..<headerLength))
    }

    static func encode(object: [String: Any],
                       entries: [String: Data],
                       header: Data,
                       key: Data) throws -> Data {
        let plain = try JSONSerialization.data(withJSONObject: object, options: [])
        let sealed = try AES.GCM.seal(plain, using: SymmetricKey(data: key), authenticating: magic)
        var raw = header
        raw.append(Data(sealed.nonce))
        raw.append(sealed.ciphertext)
        raw.append(sealed.tag)
        var updated = entries
        updated["archive.ortho"] = raw
        return try zip(updated)
    }

    static func decryptBlob(_ encrypted: Data, key: Data) throws -> Data {
        guard encrypted.count >= 28 else { throw OrganizerCloudError.archiveUnavailable }
        let nonce = try AES.GCM.Nonce(data: encrypted.subdata(in: 0..<12))
        let body = encrypted.subdata(in: 12..<encrypted.count)
        let sealed = try AES.GCM.SealedBox(nonce: nonce,
                                           ciphertext: Data(body.dropLast(16)),
                                           tag: Data(body.suffix(16)))
        return try AES.GCM.open(sealed, using: SymmetricKey(data: key), authenticating: magic)
    }

    static func encryptBlob(_ data: Data, key: Data) throws -> Data {
        let sealed = try AES.GCM.seal(data,
                                      using: SymmetricKey(data: key),
                                      authenticating: magic)
        var encrypted = Data(sealed.nonce)
        encrypted.append(sealed.ciphertext)
        encrypted.append(sealed.tag)
        return encrypted
    }

    private static func unzip(_ data: Data) throws -> [String: Data] {
        let archive = try Archive(data: data, accessMode: .read)
        var result: [String: Data] = [:]
        for entry in archive {
            var value = Data()
            try archive.extract(entry) { chunk in value.append(chunk) }
            result[entry.path] = value
        }
        return result
    }

    private static func zip(_ entries: [String: Data]) throws -> Data {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("ortho-\(UUID().uuidString)")
            .appendingPathExtension("zip")
        defer { try? FileManager.default.removeItem(at: url) }
        do {
            let archive = try Archive(url: url, accessMode: .create)
            for (path, value) in entries.sorted(by: { $0.key < $1.key }) {
                try archive.addEntry(with: path,
                                     type: .file,
                                     uncompressedSize: Int64(value.count),
                                     bufferSize: 32 * 1024,
                                     provider: { position, size in
                                         let start = Int(position)
                                         guard start < value.count else { return Data() }
                                         let length = min(Int(size), value.count - start)
                                         return value.subdata(in: start..<(start + length))
                                     })
            }
        }
        return try Data(contentsOf: url)
    }
}
