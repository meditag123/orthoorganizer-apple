import WidgetKit
import SwiftUI

struct DutyWidgetEntry: TimelineEntry {
    let date: Date
    let duty: String
}

struct DutyWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> DutyWidgetEntry {
        DutyWidgetEntry(date: .now, duty: "Επόμενη εφημερία · Ενεργή")
    }

    func getSnapshot(in context: Context, completion: @escaping (DutyWidgetEntry) -> Void) {
        completion(DutyWidgetEntry(date: .now, duty: WidgetCache.nextDutyText()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<DutyWidgetEntry>) -> Void) {
        let entry = DutyWidgetEntry(date: .now, duty: WidgetCache.nextDutyText())
        completion(Timeline(entries: [entry], policy: .after(.now.addingTimeInterval(1800))))
    }
}

struct OrthoOrganizerWidgetView: View {
    let entry: DutyWidgetEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("OrthoOrganizer")
                .font(.caption.weight(.bold))
                .foregroundStyle(Color(red: 0.082, green: 0.435, blue: 0.400))
            Text(entry.duty)
                .font(.headline)
                .foregroundStyle(Color(red: 0.063, green: 0.165, blue: 0.263))
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

@main
struct OrthoOrganizerWidget: Widget {
    let kind = "OrthoOrganizerWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: DutyWidgetProvider()) { entry in
            OrthoOrganizerWidgetView(entry: entry)
        }
        .configurationDisplayName("Επόμενη εφημερία")
        .description("Εμφανίζει την επόμενη εφημερία και τον ρόλο.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}
