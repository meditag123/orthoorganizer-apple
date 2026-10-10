import SwiftUI
import UniformTypeIdentifiers

struct DutiesView: View {
    @EnvironmentObject private var store: OrganizerStore
    @State private var selectedMonth = Calendar.current.component(.month, from: .now)
    @State private var selectedYear = Calendar.current.component(.year, from: .now)
    @State private var selectedDuty: Duty?
    @State private var dutyToDelete: Duty?
    @State private var showImageImporter = false
    @State private var scheduleImageData: Data?
    @State private var scheduleImageName = ""
    @State private var showImagePreview = false

    private var filteredDuties: [Duty] {
        store.snapshot.duties
            .filter {
                Calendar.current.component(.month, from: $0.date) == selectedMonth &&
                Calendar.current.component(.year, from: $0.date) == selectedYear
            }
            .sorted { $0.date < $1.date }
    }

    private var monthName: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "el_GR")
        return formatter.monthSymbols[safe: selectedMonth - 1]?.capitalized ?? "Μήνας"
    }

    private var years: [Int] {
        let current = Calendar.current.component(.year, from: .now)
        let stored = store.snapshot.duties.map { Calendar.current.component(.year, from: $0.date) }
        return Array(Set([current - 1, current, current + 1] + stored)).sorted()
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Οργάνωσε το πρόγραμμα του μήνα σε μία καθαρή προβολή.")
                    .font(.title3)
                    .foregroundStyle(OrthoTheme.muted)

                Text("Εφημερίες")
                    .font(.largeTitle.weight(.semibold))
                    .foregroundStyle(OrthoTheme.navy)

                HStack(spacing: 0) {
                    Button {
                        selectedDuty = Duty(date: .now, type: .active, hospital: "")
                    } label: {
                        Label("Νέα εφημερία", systemImage: "plus")
                            .frame(maxWidth: .infinity, minHeight: 48)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(OrthoTheme.navy)

                    Button {
                        showImageImporter = true
                    } label: {
                        Label("Εικόνα μόνο", systemImage: "photo")
                            .frame(maxWidth: .infinity, minHeight: 48)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(OrthoTheme.navy)
                    .background(OrthoTheme.mint)
                }
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                OrthoCard {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Προβολή προγράμματος")
                            .font(.headline)
                            .foregroundStyle(OrthoTheme.navy)
                        HStack {
                            Picker("Μήνας", selection: $selectedMonth) {
                                ForEach(1...12, id: \.self) { month in
                                    Text(monthTitle(month)).tag(month)
                                }
                            }
                            .pickerStyle(.menu)
                            Spacer()
                            Picker("Έτος", selection: $selectedYear) {
                                ForEach(years, id: \.self) { year in
                                    Text(String(year)).tag(year)
                                }
                            }
                            .pickerStyle(.menu)
                        }
                        if let scheduleImageData {
                            Button {
                                showImagePreview = true
                            } label: {
                                HStack(spacing: 10) {
                                    Image(systemName: "photo.on.rectangle")
                                        .foregroundStyle(OrthoTheme.teal)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(scheduleImageName.isEmpty ? "Εικόνα προγράμματος" : scheduleImageName)
                                            .foregroundStyle(OrthoTheme.ink)
                                        Text("Πάτησε για προεπισκόπηση")
                                            .font(.caption)
                                            .foregroundStyle(OrthoTheme.muted)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .foregroundStyle(OrthoTheme.muted)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                Text("Πρόγραμμα εφημεριών")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(OrthoTheme.navy)
                Text("\(monthName) \(selectedYear)")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(OrthoTheme.teal)

                OrthoCard {
                    if filteredDuties.isEmpty {
                        Text("Δεν υπάρχουν εφημερίες για τον επιλεγμένο μήνα.")
                            .foregroundStyle(OrthoTheme.muted)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        LazyVStack(spacing: 0) {
                            ForEach(filteredDuties) { duty in
                                HStack(spacing: 12) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(duty.date.formatted(.dateTime.day().month(.twoDigits).year()))
                                            .font(.headline)
                                        Text(duty.date.formatted(.dateTime.weekday(.abbreviated)))
                                            .font(.caption)
                                            .foregroundStyle(OrthoTheme.muted)
                                    }
                                    .frame(width: 92, alignment: .leading)

                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(duty.type.rawValue)
                                            .font(.headline)
                                            .foregroundStyle(OrthoTheme.ink)
                                        if !duty.hospital.isEmpty {
                                            Text(duty.hospital)
                                                .font(.subheadline)
                                                .foregroundStyle(OrthoTheme.muted)
                                                .lineLimit(1)
                                        }
                                    }
                                    Spacer(minLength: 0)
                                    Image(systemName: "chevron.right")
                                        .foregroundStyle(OrthoTheme.muted)
                                }
                                .padding(.vertical, 10)
                                .contentShape(Rectangle())
                                .onTapGesture { selectedDuty = duty }
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    Button(role: .destructive) { dutyToDelete = duty } label: {
                                        Label("Διαγραφή", systemImage: "trash")
                                    }
                                }
                                if duty.id != filteredDuties.last?.id { Divider() }
                            }
                        }
                    }
                }
            }
            .padding(20)
        }
        .sheet(item: $selectedDuty) { duty in
            DutyEditorView(duty: duty).environmentObject(store)
        }
        .sheet(isPresented: $showImagePreview) {
            if let scheduleImageData {
                AttachmentPreviewView(data: scheduleImageData, name: scheduleImageName.isEmpty ? "Πρόγραμμα εφημεριών" : scheduleImageName)
            }
        }
        .fileImporter(isPresented: $showImageImporter, allowedContentTypes: [.image]) { result in
            guard case .success(let url) = result else { return }
            let hasScope = url.startAccessingSecurityScopedResource()
            defer { if hasScope { url.stopAccessingSecurityScopedResource() } }
            scheduleImageData = try? Data(contentsOf: url)
            scheduleImageName = url.lastPathComponent
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

    private func monthTitle(_ month: Int) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "el_GR")
        return formatter.monthSymbols[safe: month - 1]?.capitalized ?? "Μήνας \(month)"
    }
}

private extension Array {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
