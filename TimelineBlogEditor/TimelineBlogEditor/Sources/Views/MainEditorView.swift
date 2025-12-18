import SwiftUI

/// Main three-column editor view
struct MainEditorView: View {
    @Bindable var viewModel: BlogViewModel
    @ObservedObject private var previewService: PreviewService

    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    init(viewModel: BlogViewModel) {
        self.viewModel = viewModel
        self.previewService = viewModel.previewService
    }

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            // First column: Days list
            DaysListView(viewModel: viewModel)
                .navigationSplitViewColumnWidth(min: 200, ideal: 250, max: 350)
        } content: {
            // Second column: Events list for selected day
            if let post = viewModel.selectedPost {
                EventsListView(viewModel: viewModel, post: post)
                    .navigationSplitViewColumnWidth(min: 200, ideal: 280, max: 400)
            } else {
                ContentUnavailableView(
                    "No Day Selected",
                    systemImage: "calendar",
                    description: Text("Select a day from the list to view its events")
                )
            }
        } detail: {
            // Third column: Event editor
            if let event = viewModel.selectedEvent {
                EventEditorView(viewModel: viewModel, event: event)
            } else if viewModel.selectedPost != nil {
                ContentUnavailableView(
                    "No Event Selected",
                    systemImage: "list.bullet.clipboard",
                    description: Text("Select an event to edit or create a new one")
                )
            } else {
                ContentUnavailableView(
                    "Welcome",
                    systemImage: "pencil.and.outline",
                    description: Text("Select a day and event to start editing")
                )
            }
        }
        .navigationTitle(viewModel.blogDirectoryURL?.lastPathComponent ?? "Blog Editor")
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                // Preview button
                PreviewButton(viewModel: viewModel, previewService: previewService)

                Button(action: {
                    viewModel.createNewPost()
                }) {
                    Label("New Day", systemImage: "plus.circle")
                }
                .help("Create a new day")

                Menu {
                    Button(action: {
                        Task {
                            await viewModel.loadPosts()
                        }
                    }) {
                        Label("Reload Posts", systemImage: "arrow.clockwise")
                    }

                    Divider()

                    Button(action: {
                        viewModel.closeBlog()
                    }) {
                        Label("Close Blog", systemImage: "xmark.circle")
                    }
                } label: {
                    Label("More", systemImage: "ellipsis.circle")
                }
            }
        }
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK") {
                viewModel.dismissError()
            }
        } message: {
            Text(viewModel.errorMessage ?? "An unknown error occurred")
        }
        .overlay {
            if viewModel.isLoading {
                ZStack {
                    Color.black.opacity(0.3)
                    ProgressView("Loading...")
                        .padding(24)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
            }
        }
    }
}

// MARK: - Preview Button

struct PreviewButton: View {
    @Bindable var viewModel: BlogViewModel
    @ObservedObject var previewService: PreviewService

    var body: some View {
        switch previewService.state {
        case .idle:
            Button(action: {
                Task {
                    await viewModel.startPreview()
                }
            }) {
                Label("Preview", systemImage: "play.circle")
            }
            .help("Start Jekyll preview server")

        case .installingDependencies:
            Button(action: {}) {
                Label {
                    Text("Installing...")
                } icon: {
                    ProgressView()
                        .scaleEffect(0.6)
                        .frame(width: 16, height: 16)
                }
            }
            .disabled(true)
            .help("Running bundle install...")

        case .stoppingExistingServer:
            Button(action: {}) {
                Label {
                    Text("Stopping old server...")
                } icon: {
                    ProgressView()
                        .scaleEffect(0.6)
                        .frame(width: 16, height: 16)
                }
            }
            .disabled(true)
            .help("Killing existing Jekyll process on port 4000...")

        case .starting:
            Button(action: {}) {
                Label {
                    Text("Starting...")
                } icon: {
                    ProgressView()
                        .scaleEffect(0.6)
                        .frame(width: 16, height: 16)
                }
            }
            .disabled(true)

        case .running(let url):
            HStack(spacing: 4) {
                Button(action: {
                    previewService.openInBrowser()
                }) {
                    Label("Open Preview", systemImage: "safari")
                }
                .help("Open \(url.absoluteString) in browser")

                Button(action: {
                    viewModel.stopPreview()
                }) {
                    Image(systemName: "stop.circle")
                }
                .help("Stop preview server")
            }

        case .error(let message):
            Button(action: {
                Task {
                    await viewModel.startPreview()
                }
            }) {
                Label("Retry Preview", systemImage: "exclamationmark.triangle")
            }
            .help("Error: \(message). Click to retry.")
        }
    }
}

#Preview {
    MainEditorView(viewModel: {
        let vm = BlogViewModel()
        // Add some sample data for preview
        return vm
    }())
}
