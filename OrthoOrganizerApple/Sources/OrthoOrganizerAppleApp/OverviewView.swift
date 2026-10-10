import SwiftUI

struct OverviewView: View {
    @EnvironmentObject private var store: OrganizerStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                OrthoSectionHeader("Επισκόπηση", subtitle: "Η σημερινή εικόνα του organizer")

                if let duty = store.nextDuty {
                    OrthoCard {
                        HStack(alignment: .top, spacing: 14) {
                            Image(systemName: "calendar.badge.clock")
                                .font(.title)
                                .foregroundStyle(OrthoTheme.teal)
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Επόμενη εφημερία")
                                    .font(.subheadline)
                                    .foregroundStyle(OrthoTheme.muted)
                                Text(duty.date.formatted(.dateTime.weekday(.wide).day().month(.wide)))
                                    .font(.title3.weight(.bold))
                                HStack(spacing: 8) {
                                    OrthoBadge(text: duty.type.rawValue, tint: OrthoTheme.teal)
                                    if !duty.hospital.isEmpty { Text(duty.hospital).foregroundStyle(OrthoTheme.muted) }
                                }
                            }
                            Spacer()
                        }
                    }
                } else {
                    OrthoCard { Text("Δεν υπάρχουν καταχωρημένες εφημερίες.").foregroundStyle(OrthoTheme.muted) }
                }

                OrthoSectionHeader("Επόμενες εφημερίες")
                OrthoCard {
                    VStack(spacing: 0) {
                        ForEach(Array(store.upcomingDuties.prefix(6))) { duty in
                            HStack {
                                Text(duty.shortDate).frame(width: 120, alignment: .leading)
                                Text(duty.type.rawValue).fontWeight(.medium)
                                Spacer()
                                if !duty.hospital.isEmpty { Text(duty.hospital).foregroundStyle(OrthoTheme.muted) }
                            }
                            .padding(.vertical, 10)
                            if duty.id != store.upcomingDuties.prefix(6).last?.id { Divider() }
                        }
                    }
                }

                HStack(spacing: 14) {
                    MetricCard(title: "Χειρουργεία", value: "\(store.snapshot.surgeries.count)", systemImage: "cross.case")
                    MetricCard(title: "Εφημερίες", value: "\(store.snapshot.duties.count)", systemImage: "calendar")
                }
                if store.snapshot.settings.showStatisticsOnOverview {
                    OrthoSectionHeader("Γρήγορα στατιστικά")
                    HStack(spacing: 14) {
                        MetricCard(title: "Ενεργές εφημερίες", value: "\(store.snapshot.duties.filter { $0.type.isCoverage }.count)", systemImage: "checkmark.seal")
                        MetricCard(title: "Συνημμένα", value: "\(store.snapshot.surgeries.reduce(0) { $0 + $1.attachments.count })", systemImage: "paperclip")
                    }
                }
            }
            .padding(24)
        }
    }
}

private struct MetricCard: View {
    let title: String
    let value: String
    let systemImage: String

    var body: some View {
        OrthoCard {
            HStack(spacing: 12) {
                Image(systemName: systemImage).foregroundStyle(OrthoTheme.teal)
                VStack(alignment: .leading, spacing: 3) {
                    Text(value).font(.title2.weight(.bold))
                    Text(title).font(.caption).foregroundStyle(OrthoTheme.muted)
                }
                Spacer()
            }
        }
    }
}
