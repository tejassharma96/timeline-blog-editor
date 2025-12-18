import SwiftUI
import AppKit

/// Initial view for selecting a blog directory
struct BlogSelectorView: View {
    @Bindable var viewModel: BlogViewModel

    @State private var isDragging = false

    var body: some View {
        VStack(spacing: 32) {
            // Header
            VStack(spacing: 12) {
                Image(systemName: "doc.text.image")
                    .font(.system(size: 64))
                    .foregroundStyle(.secondary)

                Text("Timeline Blog Editor")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("Select a Jekyll blog directory to get started")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }

            // Drop zone
            VStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(
                            isDragging ? Color.accentColor : Color.secondary.opacity(0.3),
                            style: StrokeStyle(lineWidth: 2, dash: [8])
                        )
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(isDragging ? Color.accentColor.opacity(0.1) : Color.clear)
                        )

                    VStack(spacing: 12) {
                        Image(systemName: "folder.badge.plus")
                            .font(.system(size: 40))
                            .foregroundStyle(isDragging ? Color.accentColor : .secondary)

                        Text("Drop your blog folder here")
                            .font(.headline)
                            .foregroundStyle(isDragging ? .primary : .secondary)

                        Text("or")
                            .font(.subheadline)
                            .foregroundStyle(.tertiary)

                        Button(action: selectFolder) {
                            Label("Choose Folder", systemImage: "folder")
                                .font(.headline)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                    }
                    .padding(40)
                }
                .frame(maxWidth: 400, maxHeight: 250)
                .onDrop(of: [.fileURL], isTargeted: $isDragging) { providers in
                    handleDrop(providers: providers)
                }

                // Requirements hint
                VStack(alignment: .leading, spacing: 4) {
                    Label("Must contain a _posts/ directory", systemImage: "checkmark.circle")
                    Label("Posts should use YAML frontmatter", systemImage: "checkmark.circle")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .padding(48)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK") {
                viewModel.dismissError()
            }
        } message: {
            Text(viewModel.errorMessage ?? "An unknown error occurred")
        }
    }

    private func selectFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = "Select your Jekyll blog directory"
        panel.prompt = "Select"

        if panel.runModal() == .OK, let url = panel.url {
            Task {
                await viewModel.selectBlogDirectory(url)
            }
        }
    }

    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }

        provider.loadItem(forTypeIdentifier: "public.file-url", options: nil) { item, error in
            guard let data = item as? Data,
                  let url = URL(dataRepresentation: data, relativeTo: nil),
                  url.hasDirectoryPath else {
                return
            }

            Task { @MainActor in
                await viewModel.selectBlogDirectory(url)
            }
        }

        return true
    }
}

#Preview {
    BlogSelectorView(viewModel: BlogViewModel())
}
