import SwiftUI

struct OverviewView: View {
    @EnvironmentObject private var store: OrganizerStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Η σημερινή εικόνα του organizer.")
                    .font(.title3)
                    .foregroundStyle(OrthoTheme.muted)

                if let duty = store.nextDuty {
                    NextDutyCard(duty: duty)
                } else {
                    OrthoCard {
                        HStack(spacing: 12) {
                            Image(systemName: "calendar.badge.exclamationmark")
                                .font(.title2)
                                .foregroundStyle(OrthoTheme.teal)
                            Text("Δεν υπάρχουν επερχόμενες εφημερίες.")
                                .foregroundStyle(OrthoTheme.muted)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                Text("Επόμενες εφημερίες")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(OrthoTheme.navy)

                OrthoCard {
                    if store.upcomingDuties.isEmpty {
                        Text("Δεν υπάρχουν καταχωρημένες εφημερίες.")
                            .foregroundStyle(OrthoTheme.muted)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        LazyVStack(spacing: 0) {
                            ForEach(Array(store.upcomingDuties.prefix(8))) { duty in
                                HStack(spacing: 12) {
                                    Text(duty.date.formatted(.dateTime.day().month(.abbreviated)))
                                        .font(.headline)
                                        .frame(width: 78, alignment: .leading)
                                    Text(duty.type.rawValue)
                                        .font(.subheadline.weight(.medium))
                                        .foregroundStyle(OrthoTheme.ink)
                                    Spacer(minLength: 0)
                                    if !duty.hospital.isEmpty {
                                        Text(duty.hospital)
                                            .font(.caption)
                                            .foregroundStyle(OrthoTheme.muted)
                                            .lineLimit(1)
                                    }
                                }
                                .padding(.vertical, 9)
                                if duty.id != Array(store.upcomingDuties.prefix(8)).last?.id { Divider() }
                            }
                        }
                    }
                }

                HStack(spacing: 12) {
                    MetricCard(title: "Χειρουργεία", value: "\(store.snapshot.surgeries.count)", systemImage: "cross.case")
                    MetricCard(title: "Εφημερίες", value: "\(store.snapshot.duties.count)", systemImage: "calendar")
                }

                if store.snapshot.settings.showStatisticsOnOverview {
                    Text("Γρήγορα στατιστικά")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(OrthoTheme.navy)
                    HStack(spacing: 12) {
                        MetricCard(title: "Κάλυψη εφημεριών", value: "\(store.snapshot.duties.filter { $0.type.isCoverage }.count)", systemImage: "checkmark.seal")
                        MetricCard(title: "Συνημμένα", value: "\(store.snapshot.surgeries.reduce(0) { $0 + $1.attachments.count })", systemImage: "paperclip")
                    }
                }
            }
            .padding(20)
        }
    }
}

private struct NextDutyCard: View {
    let duty: Duty

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Επόμενη εφημερία")
                    .font(.headline)
                    .foregroundStyle(.white.opacity(0.82))
                Spacer()
                Image(systemName: "calendar.badge.clock")
                    .font(.title2)
                    .foregroundStyle(OrthoTheme.mint)
            }
            Text(duty.date.formatted(.dateTime.weekday(.wide).day().month(.wide).year()))
                .font(.title2.weight(.bold))
                .foregroundStyle(.white)
            HStack(spacing: 8) {
                OrthoBadge(text: duty.type.rawValue, tint: OrthoTheme.mint)
                if !duty.hospital.isEmpty {
                    Text(duty.hospital)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.78))
                        .lineLimit(1)
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(OrthoTheme.navy, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}

private struct MetricCard: View {
    let title: String
    let value: String
    let systemImage: String

    var body: some View {
        OrthoCard {
            HStack(spacing: 10) {
                Image(systemName: systemImage)
                    .foregroundStyle(OrthoTheme.teal)
                VStack(alignment: .leading, spacing: 3) {
                    Text(value)
                        .font(.title2.weight(.bold))
                        .foregroundStyle(OrthoTheme.navy)
                    Text(title)
                        .font(.caption)
                        .foregroundStyle(OrthoTheme.muted)
                        .lineLimit(2)
                }
                Spacer(minLength: 0)
            }
        }
    }
}
