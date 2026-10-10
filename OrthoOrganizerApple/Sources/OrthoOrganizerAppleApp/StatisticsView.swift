import SwiftUI

struct StatisticsView: View {
    @EnvironmentObject private var store: OrganizerStore
    @State private var mode = 0

    private var currentYear: Int { Calendar.current.component(.year, from: .now) }
    private var currentYearSurgeries: Int {
        store.snapshot.surgeries.filter { Calendar.current.component(.year, from: $0.date) == currentYear }.count
    }
    private var currentYearDuties: Int {
        store.snapshot.duties.filter {
            Calendar.current.component(.year, from: $0.date) == currentYear
        }.count
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                OrthoSectionHeader("Στατιστικά", subtitle: "Ξεχωριστά χειρουργεία και εφημερίες")
                Picker("Κατηγορία", selection: $mode) {
                    Text("Χειρουργεία").tag(0)
                    Text("Εφημερίες").tag(1)
                }
                .pickerStyle(.segmented)
                HStack(spacing: 14) {
                    MetricCard(title: mode == 0 ? "Σύνολο επεμβάσεων" : "Σύνολο εφημεριών", value: mode == 0 ? "\(store.snapshot.surgeries.count)" : "\(store.snapshot.duties.count)", systemImage: mode == 0 ? "cross.case" : "calendar")
                    MetricCard(title: "Τρέχον έτος", value: mode == 0 ? "\(currentYearSurgeries)" : "\(currentYearDuties)", systemImage: "chart.bar")
                }
                OrthoCard {
                    Text(mode == 0 ? "Ανά είδος επέμβασης" : "Ανά τύπο εφημερίας")
                        .font(.headline)
                    Divider().padding(.vertical, 6)
                    if mode == 0 {
                        let counts = Dictionary(grouping: store.snapshot.surgeries.filter { !$0.procedure.isEmpty }, by: \.procedure)
                            .mapValues(\.count)
                            .sorted { $0.value > $1.value }
                        if counts.isEmpty {
                            Text("Δεν υπάρχουν καταχωρημένες επεμβάσεις.").foregroundStyle(OrthoTheme.muted)
                        } else {
                            ForEach(Array(counts.enumerated()), id: \.offset) { item in
                                HStack {
                                    Text(item.element.key)
                                    Spacer()
                                    Text("\(item.element.value)").fontWeight(.semibold)
                                }
                                .padding(.vertical, 5)
                            }
                        }
                    } else {
                        let counts = Dictionary(grouping: store.snapshot.duties, by: \.type.rawValue)
                            .mapValues(\.count)
                            .sorted { $0.value > $1.value }
                        if counts.isEmpty {
                            Text("Δεν υπάρχουν καταχωρημένες εφημερίες.").foregroundStyle(OrthoTheme.muted)
                        } else {
                            ForEach(Array(counts.enumerated()), id: \.offset) { item in
                                HStack {
                                    Text(item.element.key)
                                    Spacer()
                                    Text("\(item.element.value)").fontWeight(.semibold)
                                }
                                .padding(.vertical, 5)
                            }
                        }
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
            }
        }
    }
}
