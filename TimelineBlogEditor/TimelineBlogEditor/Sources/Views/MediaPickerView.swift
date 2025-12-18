import SwiftUI
import AppKit
import UniformTypeIdentifiers

/// View for selecting and importing media files
struct MediaPickerView: View {
    @Bindable var viewModel: BlogViewModel
    let event: BlogEvent

    @Environment(\.dismiss) private var dismiss

    @State private var selectedURLs: [URL] = []
    @State private var isImporting = false
    @State private var errorMessage: String?
    @State private var isDragging = false

    var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                Text("Add Media")
                    .font(.title2)
                    .fontWeight(.semibold)

                Spacer()

                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            // Drop zone
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(
                        isDragging ? Color.accentColor : Color.secondary.opacity(0.3),
                        style: StrokeStyle(lineWidth: 2, dash: [6])
                    )
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(isDragging ? Color.accentColor.opacity(0.1) : Color(nsColor: .controlBackgroundColor))
                    )

                VStack(spacing: 12) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 40))
                        .foregroundStyle(isDragging ? Color.accentColor : .secondary)

                    Text("Drop files here")
                        .font(.headline)
                        .foregroundStyle(isDragging ? .primary : .secondary)

                    Text("or")
                        .font(.subheadline)
                        .foregroundStyle(.tertiary)

                    Button(action: selectFiles) {
                        Label("Choose Files", systemImage: "folder")
                    }
                    .buttonStyle(.bordered)

                    Text("Supports: JPG, PNG, GIF, WEBP, HEIC, MP4, MOV")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .padding(30)
            }
            .frame(height: 200)
            .onDrop(of: [.fileURL], isTargeted: $isDragging) { providers in
                handleDrop(providers: providers)
            }

            // Selected files preview
            if !selectedURLs.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Selected Files")
                            .font(.headline)

                        Spacer()

                        Button(action: { selectedURLs.removeAll() }) {
                            Text("Clear All")
                                .font(.caption)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                    }

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(selectedURLs, id: \.absoluteString) { url in
                                SelectedFilePreview(url: url) {
                                    selectedURLs.removeAll { $0 == url }
                                }
                            }
                        }
                    }
                }
            }

            // Error message
            if let error = errorMessage {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.yellow)
                    Text(error)
                        .font(.callout)
                }
                .padding(12)
                .background(Color.yellow.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            // Action buttons
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(.bordered)

                Spacer()

                Button(action: importSelectedFiles) {
                    if isImporting {
                        ProgressView()
                            .scaleEffect(0.8)
                            .frame(width: 16, height: 16)
                    } else {
                        Text("Import \(selectedURLs.count) File\(selectedURLs.count == 1 ? "" : "s")")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(selectedURLs.isEmpty || isImporting)
            }
        }
        .padding(24)
        .frame(width: 500, height: 450)
    }

    private func selectFiles() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = true
        panel.allowedContentTypes = MediaCopyService.supportedContentTypes
        panel.message = "Select photos or videos to add"
        panel.prompt = "Select"

        if panel.runModal() == .OK {
            let validURLs = panel.urls.filter { MediaCopyService.isSupportedMedia($0) }
            selectedURLs.append(contentsOf: validURLs)

            if validURLs.count < panel.urls.count {
                errorMessage = "Some files were skipped (unsupported format)"
            }
        }
    }

    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        for provider in providers {
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, error in
                guard let data = item as? Data,
                      let url = URL(dataRepresentation: data, relativeTo: nil),
                      MediaCopyService.isSupportedMedia(url) else {
                    return
                }

                Task { @MainActor in
                    if !selectedURLs.contains(url) {
                        selectedURLs.append(url)
                    }
                }
            }
        }
        return true
    }

    private func importSelectedFiles() {
        guard !selectedURLs.isEmpty else { return }

        isImporting = true
        errorMessage = nil

        Task {
            await viewModel.addMedia(to: event, from: selectedURLs)

            await MainActor.run {
                isImporting = false
                dismiss()
            }
        }
    }
}

/// Preview for a selected file
struct SelectedFilePreview: View {
    let url: URL
    let onRemove: () -> Void

    @State private var thumbnail: NSImage?

    var body: some View {
        VStack(spacing: 4) {
            ZStack(alignment: .topTrailing) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.secondary.opacity(0.1))

                    if let image = thumbnail {
                        Image(nsImage: image)
                            .resizable()
                            .scaledToFill()
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    } else {
                        Image(systemName: iconForFile)
                            .font(.title)
                            .foregroundStyle(.secondary)
                    }

                    // Video indicator
                    if MediaCopyService.mediaType(for: url) == .video {
                        Image(systemName: "play.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.white)
                            .shadow(radius: 2)
                    }
                }
                .frame(width: 80, height: 80)

                Button(action: onRemove) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.body)
                        .foregroundStyle(.white)
                        .background(Circle().fill(Color.black.opacity(0.5)))
                }
                .buttonStyle(.plain)
                .offset(x: 4, y: -4)
            }

            Text(url.lastPathComponent)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .frame(width: 80)
        }
        .task {
            await loadThumbnail()
        }
    }

    private var iconForFile: String {
        let type = MediaCopyService.mediaType(for: url)
        switch type {
        case .image: return "photo"
        case .video: return "video"
        default: return "doc"
        }
    }

    private func loadThumbnail() async {
        let type = MediaCopyService.mediaType(for: url)

        if type == .image {
            thumbnail = NSImage(contentsOf: url)
        }
        // Video thumbnails could be generated with AVAssetImageGenerator
    }
}

#Preview {
    MediaPickerView(
        viewModel: BlogViewModel(),
        event: BlogEvent(title: "Test", text: "")
    )
}
