import SwiftUI

struct DutiesView: View {
    @EnvironmentObject private var store: OrganizerStore
    @State private var selectedMonth = 0
    @State private var selectedDuty: Duty?
    @State private var dutyToDelete: Duty?

    private var filteredDuties: [Duty] {
        guard selectedMonth > 0 else { return store.snapshot.duties }
        return store.snapshot.duties.filter { Calendar.current.component(.month, from: $0.date) == selectedMonth }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                OrthoSectionHeader("Εφημερίες", subtitle: "Όλοι οι τύποι και οι ρόλοι σε συγκεντρωτική λίστα")
                Picker("Μήνας", selection: $selectedMonth) {
                    Text("Όλοι οι μήνες").tag(0)
                    ForEach(1...12, id: \.self) { month in
                        Text((DateFormatter().monthSymbols?[month - 1] ?? "Μήνας \(month)").capitalized).tag(month)
                    }
                }
                .pickerStyle(.menu)

                OrthoCard {
                    if filteredDuties.isEmpty {
                        Text("Δεν υπάρχουν εφημερίες για την επιλογή.").foregroundStyle(OrthoTheme.muted)
                    } else {
                        LazyVStack(spacing: 0) {
                            ForEach(filteredDuties) { duty in
                                HStack(spacing: 12) {
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(duty.date.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated).year()))
                                            .font(.headline)
                                        if !duty.hospital.isEmpty { Text(duty.hospital).font(.caption).foregroundStyle(OrthoTheme.muted) }
                                    }
                                    Spacer()
                                    OrthoBadge(text: duty.type.rawValue, tint: duty.type.isCoverage ? OrthoTheme.teal : OrthoTheme.muted)
                                    Button(role: .destructive) { dutyToDelete = duty } label: {
                                        Image(systemName: "trash")
                                    }
                                    .buttonStyle(.borderless)
                                }
                                .padding(.vertical, 10)
                                .contentShape(Rectangle())
                                .onTapGesture { selectedDuty = duty }
                                if duty.id != filteredDuties.last?.id { Divider() }
                            }
                        }
                    }
                }
                Button {
                    selectedDuty = Duty(date: .now, type: .active, hospital: "")
                } label: {
                    Label("Νέα εφημερία", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(24)
        }
        .sheet(item: $selectedDuty) { duty in
            DutyEditorView(duty: duty).environmentObject(store)
        }
        .alert("Διαγραφή εφημερίας;", isPresented: Binding(
            get: { dutyToDelete != nil },
            set: { if !$0 { dutyToDelete = nil } }
        ), presenting: dutyToDelete) { duty in
            Button("Διαγραφή", role: .destructive) { store.deleteDuty(duty); dutyToDelete = nil }
            Button("Ακύρωση", role: .cancel) { dutyToDelete = nil }
        } message: { duty in
            Text("\(duty.shortDate) · \(duty.type.rawValue)")
        }
    }
}
