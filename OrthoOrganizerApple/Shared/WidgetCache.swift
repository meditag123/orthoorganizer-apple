import Foundation

enum WidgetCache {
    static let suiteName = "group.com.orthoorganizer.shared"
    private static let dutyKey = "nextDuty"

    static func save(nextDuty: Duty?) {
        let defaults = UserDefaults(suiteName: suiteName)
        if let nextDuty {
            let value: [String: String] = [
                "date": nextDuty.date.formatted(.dateTime.weekday(.wide).day().month(.wide)),
                "type": nextDuty.type.rawValue,
                "hospital": nextDuty.hospital
            ]
            defaults?.set(value, forKey: dutyKey)
        } else {
            defaults?.removeObject(forKey: dutyKey)
        }
    }

    static func nextDutyText() -> String {
        guard let value = UserDefaults(suiteName: suiteName)?.dictionary(forKey: dutyKey) as? [String: String],
              let date = value["date"], let type = value["type"] else {
            return "Δεν υπάρχει εφημερία"
        }
        return "\(date) · \(type)"
    }
}
