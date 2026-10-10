import SwiftUI

struct DutyEditorView: View {
    @EnvironmentObject private var store: OrganizerStore
    @Environment(\.dismiss) private var dismiss
    @State private var draft: Duty

    init(duty: Duty) {
        _draft = State(initialValue: duty)
    }

    var body: some View {
        NavigationStack {
            Form {
                DatePicker("Ημερομηνία", selection: $draft.date, displayedComponents: .date)
                Picker("Είδος εφημερίας", selection: $draft.type) {
                    ForEach(DutyType.allCases) { type in
                        Text(type.rawValue).tag(type)
                    }
                }
                TextField("Νοσοκομείο", text: $draft.hospital)
            }
            .navigationTitle("Εφημερία")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Άκυρο") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Αποθήκευση") {
                        store.saveDuty(draft)
                        dismiss()
                    }
                }
            }
        }
        .frame(minWidth: 420, minHeight: 300)
    }
}
