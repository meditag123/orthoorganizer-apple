import Foundation

enum OrganizerSection: String, CaseIterable, Identifiable {
    case overview = "Επισκόπηση"
    case duties = "Εφημερίες"
    case surgicalArchive = "Χειρουργικό αρχείο"
    case statistics = "Στατιστικά"
    case settings = "Ρυθμίσεις"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .overview: return "rectangle.grid.2x2"
        case .duties: return "calendar"
        case .surgicalArchive: return "cross.case"
        case .statistics: return "chart.bar.xaxis"
        case .settings: return "gearshape"
        }
    }
}

enum DutyType: String, CaseIterable, Codable, Identifiable {
    case active = "Ενεργή"
    case readiness = "Ετοιμότητας"
    case activeFirst = "Ενεργή 1ος"
    case activeSecond = "Ενεργή 2ος"
    case activeThird = "Ενεργή 3ος"
    case closed = "Κλειστή εφημερία"
    case mixed = "Μικτή"

    var id: String { rawValue }

    var isCoverage: Bool {
        switch self {
        case .active, .activeFirst, .activeSecond, .activeThird, .mixed: return true
        case .readiness, .closed: return false
        }
    }
}

struct Duty: Identifiable, Hashable, Codable {
    var id: UUID = UUID()
    var date: Date
    var type: DutyType
    var hospital: String

    var shortDate: String {
        date.formatted(.dateTime.day().month(.abbreviated).year())
    }
}

struct Attachment: Identifiable, Hashable, Codable {
    var id: UUID = UUID()
    var sourceID: String = ""
    var name: String
    var category: String
    var size: Int = 0
    var sha256: String = ""
    var createdAt: Date = .now
}

struct Surgery: Identifiable, Hashable, Codable {
    var id: UUID = UUID()
    var patientName: String
    var patronymic: String = ""
    var amka: String = ""
    var eama: String = ""
    var age: String = ""
    var date: Date
    var procedure: String
    var diagnosis: String = ""
    var side: String = ""
    var company: String = ""
    var surgeon: String = ""
    var assistants: [String] = []
    var attachments: [Attachment] = []
}

struct OrganizerSettings: Codable {
    var colorTheme: String = "navy"
    var showStatisticsOnOverview: Bool = true
    var widgetEnabled: Bool = false
    var lockAfterMinutes: Int = 0
    var biometricsEnabled: Bool = false
    var materialCompanies: [String] = []
}

struct OrganizerSnapshot: Codable {
    var duties: [Duty] = []
    var surgeries: [Surgery] = []
    var settings: OrganizerSettings = .init()
}

extension Date {
    static func organizerDate(_ value: String) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: value)
    }
}
