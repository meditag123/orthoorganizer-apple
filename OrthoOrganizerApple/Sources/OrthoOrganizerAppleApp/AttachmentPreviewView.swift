import SwiftUI
import UniformTypeIdentifiers

#if os(iOS)
import UIKit
#else
import AppKit
#endif

struct AttachmentDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.data] }
    var data: Data

    init(data: Data) { self.data = data }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

struct AttachmentTransfer: Transferable {
    let data: Data

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .data) { transfer in
            transfer.data
        }
    }
}

struct AttachmentPreviewView: View {
    @Environment(\.dismiss) private var dismiss
    let data: Data
    let name: String
    @State private var showExporter = false
    @GestureState private var magnification: CGFloat = 1

    private var image: Image? {
        #if os(iOS)
        guard let uiImage = UIImage(data: data) else { return nil }
        return Image(uiImage: uiImage)
        #else
        guard let nsImage = NSImage(data: data) else { return nil }
        return Image(nsImage: nsImage)
        #endif
    }

    var body: some View {
        NavigationStack {
            Group {
                if let image {
                    ScrollView([.horizontal, .vertical]) {
                        image
                            .resizable()
                            .scaledToFit()
                            .frame(minWidth: 280, minHeight: 220)
                            .padding()
                            .scaleEffect(magnification)
                            .gesture(
                                MagnificationGesture()
                                    .updating($magnification) { value, state, _ in
                                        state = min(max(value, 1), 5)
                                    }
                            )
                    }
                } else {
                    ContentUnavailableView("Δεν υπάρχει οπτική προεπισκόπηση", systemImage: "doc")
                }
            }
            .navigationTitle(name)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Κλείσιμο") { dismiss() }
                }
                ToolbarItemGroup(placement: .confirmationAction) {
                    ShareLink(item: AttachmentTransfer(data: data), preview: SharePreview(name))
                    Button("Λήψη") { showExporter = true }
                    Button("Εκτύπωση") { printAttachment() }
                }
            }
        }
        .fileExporter(isPresented: $showExporter,
                      document: AttachmentDocument(data: data),
                      contentType: .data,
                      defaultFilename: name) { _ in
            // The export result is intentionally handled as a no-op here. The
            // system file exporter already reports any failure to the user.
        }
        .frame(minWidth: 520, minHeight: 520)
    }

    private func printAttachment() {
        #if os(iOS)
        guard let image = UIImage(data: data) else { return }
        let controller = UIPrintInteractionController.shared
        controller.printingItem = image
        controller.present(animated: true, completionHandler: nil)
        #else
        guard let image = NSImage(data: data) else { return }
        let imageView = NSImageView(image: image)
        imageView.frame = NSRect(x: 0, y: 0, width: image.size.width, height: image.size.height)
        NSPrintOperation(view: imageView).run()
        #endif
    }
}
