import SwiftUI

/// Main three-column editor view
struct MainEditorView: View {
    @Bindable var viewModel: BlogViewModel

    @State private var columnVisibility: NavigationSplitViewVisibility = .all

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

#Preview {
    MainEditorView(viewModel: {
        let vm = BlogViewModel()
        // Add some sample data for preview
        return vm
    }())
}
