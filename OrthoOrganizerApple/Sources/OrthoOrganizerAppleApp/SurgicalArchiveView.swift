import SwiftUI

struct SurgicalArchiveView: View {
    @EnvironmentObject private var store: OrganizerStore
    @State private var query = ""
    @State private var selectedSurgery: Surgery?
    @State private var surgeryToDelete: Surgery?

    private var rows: [Surgery] {
        guard !query.isEmpty else { return store.snapshot.surgeries }
        return store.snapshot.surgeries.filter {
            $0.patientName.localizedCaseInsensitiveContains(query) ||
            $0.amka.localizedCaseInsensitiveContains(query) ||
            $0.procedure.localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                OrthoSectionHeader("Χειρουργικό αρχείο", subtitle: "Αναζήτηση, επεξεργασία και συνημμένα")
                HStack {
                    TextField("Αναζήτηση ασθενούς, ΑΜΚΑ ή επέμβασης", text: $query)
                        .textFieldStyle(.roundedBorder)
                    Button {
                        selectedSurgery = Surgery(patientName: "", date: .now, procedure: "")
                    } label: {
                        Label("Νέα εγγραφή", systemImage: "plus")
                    }
                    .buttonStyle(.borderedProminent)
                }
                if rows.isEmpty {
                    OrthoCard { Text("Δεν υπάρχουν εγγραφές.").foregroundStyle(OrthoTheme.muted) }
                } else {
                    LazyVStack(spacing: 12) {
                        ForEach(rows) { surgery in
                            OrthoCard {
                                HStack(alignment: .top, spacing: 12) {
                                    Image(systemName: "cross.case.fill")
                                        .foregroundStyle(OrthoTheme.teal)
                                    VStack(alignment: .leading, spacing: 5) {
                                        Text(surgery.patientName.isEmpty ? "Νέα εγγραφή" : surgery.patientName)
                                            .font(.headline)
                                        Text(surgery.procedure.isEmpty ? "Δεν έχει συμπληρωθεί επέμβαση" : surgery.procedure)
                                            .foregroundStyle(OrthoTheme.ink)
                                        HStack {
                                            if !surgery.date.formatted(.dateTime.day().month(.abbreviated).year()).isEmpty {
                                                Text(surgery.date.formatted(.dateTime.day().month(.abbreviated).year()))
                                            }
                                            if !surgery.side.isEmpty { Text("· \(surgery.side)") }
                                            if !surgery.company.isEmpty { Text("· \(surgery.company)") }
                                        }
                                        .font(.caption)
                                        .foregroundStyle(OrthoTheme.muted)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .foregroundStyle(OrthoTheme.muted)
                                }
                            }
                            .contentShape(Rectangle())
                            .onTapGesture { selectedSurgery = surgery }
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) { surgeryToDelete = surgery } label: {
                                    Label("Διαγραφή", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
            }
            .padding(24)
        }
        .sheet(item: $selectedSurgery) { surgery in
            SurgeryEditorView(surgery: surgery)
                .environmentObject(store)
        }
        .alert("Διαγραφή χειρουργείου;", isPresented: Binding(
            get: { surgeryToDelete != nil },
            set: { if !$0 { surgeryToDelete = nil } }
        ), presenting: surgeryToDelete) { surgery in
            Button("Διαγραφή", role: .destructive) { store.deleteSurgery(surgery); surgeryToDelete = nil }
            Button("Ακύρωση", role: .cancel) { surgeryToDelete = nil }
        } message: { surgery in
            Text(surgery.patientName.isEmpty ? "Η εγγραφή θα διαγραφεί οριστικά από το αρχείο." : surgery.patientName)
        }
    }
}
