import SwiftUI

/// First column view showing all days/posts
struct DaysListView: View {
    @Bindable var viewModel: BlogViewModel

    @State private var searchText = ""
    @State private var showingDeleteConfirmation = false
    @State private var postToDelete: BlogPost?

    private var filteredPosts: [BlogPost] {
        if searchText.isEmpty {
            return viewModel.sortedPosts
        }
        return viewModel.sortedPosts.filter { post in
            post.title.localizedCaseInsensitiveContains(searchText) ||
            post.location.localizedCaseInsensitiveContains(searchText) ||
            post.summary.localizedCaseInsensitiveContains(searchText) ||
            post.tags.contains { $0.localizedCaseInsensitiveContains(searchText) }
        }
    }

    var body: some View {
        List(selection: Binding(
            get: { viewModel.selectedPost?.id },
            set: { id in
                viewModel.selectPost(viewModel.posts.first { $0.id == id })
            }
        )) {
            ForEach(filteredPosts) { post in
                DayRowView(post: post)
                    .tag(post.id)
                    .contextMenu {
                        Button(action: {
                            if let post = viewModel.selectedPost {
                                viewModel.addEvent(to: post)
                            }
                        }) {
                            Label("Add Event", systemImage: "plus")
                        }

                        Divider()

                        Button(role: .destructive, action: {
                            postToDelete = post
                            showingDeleteConfirmation = true
                        }) {
                            Label("Delete Day", systemImage: "trash")
                        }
                    }
            }
        }
        .listStyle(.sidebar)
        .searchable(text: $searchText, prompt: "Search days...")
        .navigationTitle("Days")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: {
                    viewModel.createNewPost()
                }) {
                    Image(systemName: "plus")
                }
                .help("Add new day")
            }
        }
        .confirmationDialog(
            "Delete Day",
            isPresented: $showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let post = postToDelete {
                    Task {
                        await viewModel.deletePost(post)
                    }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to delete \"\(postToDelete?.title ?? "this day")\"? This action cannot be undone.")
        }
        .overlay {
            if filteredPosts.isEmpty && !searchText.isEmpty {
                ContentUnavailableView.search(text: searchText)
            } else if viewModel.posts.isEmpty && !viewModel.isLoading {
                ContentUnavailableView(
                    "No Days Yet",
                    systemImage: "calendar.badge.plus",
                    description: Text("Create your first day to get started")
                )
            }
        }
    }
}

/// Row view for a single day/post in the list
struct DayRowView: View {
    let post: BlogPost

    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(post.title)
                .font(.headline)
                .lineLimit(1)

            HStack(spacing: 8) {
                Text(dateFormatter.string(from: post.date))
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if !post.location.isEmpty {
                    Text("•")
                        .foregroundStyle(.tertiary)

                    Text(post.location)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            if !post.events.isEmpty {
                Text("\(post.events.count) event\(post.events.count == 1 ? "" : "s")")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            if !post.tags.isEmpty {
                HStack(spacing: 4) {
                    ForEach(post.tags.prefix(3), id: \.self) { tag in
                        Text(tag)
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.accentColor.opacity(0.15))
                            .foregroundStyle(Color.accentColor)
                            .clipShape(Capsule())
                    }

                    if post.tags.count > 3 {
                        Text("+\(post.tags.count - 3)")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    DaysListView(viewModel: BlogViewModel())
        .frame(width: 280)
}
