import SwiftUI
import UniformTypeIdentifiers
import CryptoKit

struct SurgeryEditorView: View {
    @EnvironmentObject private var store: OrganizerStore
    @Environment(\.dismiss) private var dismiss
    @State private var draft: Surgery
    @State private var assistantsText: String
    @State private var previewAttachment: Attachment?
    @State private var previewData: Data?
    @State private var loadingAttachment = false
    @State private var showImporter = false
    @State private var pendingFiles: [String: Data] = [:]
    @State private var attachmentError: String?
    @State private var companyChoice: String
    @State private var customCompany: String

    private let defaultMaterialCompanies = ["DMPS", "MEDIPLAT", "PHAREL", "COOPER", "KALTEQ", "OPTIMUM", "MEDINOR"]

    init(surgery: Surgery) {
        _draft = State(initialValue: surgery)
        _assistantsText = State(initialValue: surgery.assistants.joined(separator: ", "))
        let knownCompanies = ["DMPS", "MEDIPLAT", "PHAREL", "COOPER", "KALTEQ", "OPTIMUM", "MEDINOR"]
        if surgery.company.isEmpty {
            _companyChoice = State(initialValue: "")
            _customCompany = State(initialValue: "")
        } else if knownCompanies.contains(surgery.company) {
            _companyChoice = State(initialValue: surgery.company)
            _customCompany = State(initialValue: "")
        } else {
            _companyChoice = State(initialValue: "__other__")
            _customCompany = State(initialValue: surgery.company)
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Ασθενής") {
                    TextField("Ονοματεπώνυμο", text: $draft.patientName)
                    TextField("Πατρώνυμο", text: $draft.patronymic)
                    TextField("ΑΜΚΑ", text: $draft.amka)
                        .onChange(of: draft.amka) { _, _ in updateAgeFromAMKA() }
                    TextField("ΕΑΜΑ", text: $draft.eama)
                    TextField("Ηλικία", text: $draft.age)
                }
                Section("Επέμβαση") {
                    DatePicker("Ημερομηνία", selection: $draft.date, displayedComponents: .date)
                    TextField("Διάγνωση", text: $draft.diagnosis, axis: .vertical)
                    TextField("Είδος επέμβασης", text: $draft.procedure, axis: .vertical)
                    TextField("Πλευρά", text: $draft.side)
                    Picker("Εταιρεία υλικών", selection: $companyChoice) {
                        Text("Δεν έχει επιλεγεί").tag("")
                        ForEach(availableMaterialCompanies, id: \.self) { company in
                            Text(company).tag(company)
                        }
                        Text("Άλλη").tag("__other__")
                    }
                    if companyChoice == "__other__" {
                        TextField("Όνομα άλλης εταιρείας", text: $customCompany)
                    }
                }
                Section("Χειρουργική ομάδα") {
                    TextField("Χειρουργός / χειρουργοί", text: $draft.surgeon)
                    TextField("Βοηθοί, χωρισμένοι με κόμμα", text: $assistantsText, axis: .vertical)
                }
                if !draft.attachments.isEmpty {
                    Section("Συνημμένα") {
                        ForEach(draft.attachments) { attachment in
                            Button {
                                loadingAttachment = true
                                Task {
                                    if let local = pendingFiles[attachment.sourceID] {
                                        previewData = local
                                    } else {
                                        previewData = try? await store.loadAttachment(attachment)
                                    }
                                    loadingAttachment = false
                                    previewAttachment = attachment
                                }
                            } label: {
                                HStack {
                                    Label(attachment.name, systemImage: "paperclip")
                                    Spacer()
                                    Image(systemName: "eye")
                                }
                            }
                            .buttonStyle(.plain)
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    pendingFiles.removeValue(forKey: attachment.sourceID)
                                    draft.attachments.removeAll { $0.id == attachment.id }
                                } label: {
                                    Label("Διαγραφή", systemImage: "trash")
                                }
                            }
                        }
                        if loadingAttachment { ProgressView("Άνοιγμα συνημμένου…") }
                        Button {
                            showImporter = true
                        } label: {
                            Label("Προσθήκη συνημμένου", systemImage: "paperclip.badge.plus")
                        }
                    }
                } else {
                    Section("Συνημμένα") {
                        Button {
                            showImporter = true
                        } label: {
                            Label("Προσθήκη συνημμένου", systemImage: "paperclip.badge.plus")
                        }
                    }
                }
                if let attachmentError {
                    Text(attachmentError)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }
            .navigationTitle(draft.patientName.isEmpty ? "Νέα επέμβαση" : "Επεξεργασία επέμβασης")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Άκυρο") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Αποθήκευση") {
                        draft.company = companyChoice == "__other__" ? customCompany.trimmingCharacters(in: .whitespacesAndNewlines) : companyChoice
                        if !draft.company.isEmpty,
                           !defaultMaterialCompanies.contains(draft.company),
                           !store.snapshot.settings.materialCompanies.contains(draft.company) {
                            store.snapshot.settings.materialCompanies.append(draft.company)
                        }
                        draft.assistants = assistantsText
                            .split(separator: ",")
                            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                            .filter { !$0.isEmpty }
                        store.saveSurgery(draft, pendingAttachments: pendingFiles)
                        dismiss()
                    }
                    .disabled(draft.patientName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                              draft.procedure.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .frame(minWidth: 460, minHeight: 560)
        .sheet(item: $previewAttachment) { attachment in
            if let previewData {
                AttachmentPreviewView(data: previewData, name: attachment.name)
            } else {
                ContentUnavailableView("Δεν άνοιξε το συνημμένο", systemImage: "exclamationmark.triangle")
            }
        }
        .fileImporter(isPresented: $showImporter,
                      allowedContentTypes: [.item],
                      allowsMultipleSelection: true) { result in
            switch result {
            case .success(let urls):
                importAttachments(urls)
            case .failure(let error):
                attachmentError = error.localizedDescription
            }
        }
    }

    private func importAttachments(_ urls: [URL]) {
        attachmentError = nil
        for url in urls {
            let hasScope = url.startAccessingSecurityScopedResource()
            defer { if hasScope { url.stopAccessingSecurityScopedResource() } }
            do {
                let data = try Data(contentsOf: url)
                guard !data.isEmpty else { continue }
                let sourceID = UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased()
                let attachment = Attachment(sourceID: sourceID,
                                            name: url.lastPathComponent,
                                            category: "Χειρουργείο",
                                            size: data.count,
                                            sha256: data.sha256Hex)
                draft.attachments.append(attachment)
                pendingFiles[sourceID] = data
            } catch {
                attachmentError = "Δεν ήταν δυνατή η ανάγνωση του \(url.lastPathComponent)."
            }
        }
    }

    private func updateAgeFromAMKA() {
        let digits = draft.amka.filter(\.isNumber)
        guard digits.count == 11,
              let day = Int(digits.prefix(2)),
              let month = Int(digits.dropFirst(2).prefix(2)),
              let yearPart = Int(digits.dropFirst(4).prefix(2)),
              let birthDay = Calendar.current.date(from: DateComponents(year: 2000 + yearPart,
                                                                          month: month,
                                                                          day: day)) else { return }
        let today = Calendar.current.startOfDay(for: .now)
        var birth = birthDay
        if birth > today {
            birth = Calendar.current.date(byAdding: .year, value: -100, to: birth) ?? birth
        }
        let age = Calendar.current.dateComponents([.year], from: birth, to: today).year ?? 0
        if (0...120).contains(age) { draft.age = "\(age)" }
    }

    private var availableMaterialCompanies: [String] {
        var values = defaultMaterialCompanies
        for company in store.snapshot.settings.materialCompanies where !values.contains(company) {
            values.append(company)
        }
        return values
    }
}

private extension Data {
    var sha256Hex: String {
        SHA256.hash(data: self).map { String(format: "%02x", $0) }.joined()
    }
}
