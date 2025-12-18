import SwiftUI

/// Second column view showing events for a selected day
struct EventsListView: View {
    @Bindable var viewModel: BlogViewModel
    let post: BlogPost

    @State private var showingDeleteConfirmation = false
    @State private var eventToDelete: BlogEvent?
    @State private var isEditingPostMetadata = false

    var body: some View {
        List(selection: Binding(
            get: { viewModel.selectedEvent?.id },
            set: { id in
                viewModel.selectEvent(post.events.first { $0.id == id })
            }
        )) {
            // Post metadata section
            Section {
                PostMetadataView(viewModel: viewModel, post: post)
            } header: {
                Text("Day Info")
            }

            // Events section
            Section {
                if post.events.isEmpty {
                    Text("No events yet")
                        .foregroundStyle(.secondary)
                        .italic()
                } else {
                    ForEach(post.events) { event in
                        EventRowView(event: event)
                            .tag(event.id)
                            .contextMenu {
                                Button(role: .destructive, action: {
                                    eventToDelete = event
                                    showingDeleteConfirmation = true
                                }) {
                                    Label("Delete Event", systemImage: "trash")
                                }
                            }
                    }
                    .onMove { source, destination in
                        viewModel.moveEvent(from: source, to: destination)
                    }
                    .onDelete { indexSet in
                        if let index = indexSet.first {
                            eventToDelete = post.events[index]
                            showingDeleteConfirmation = true
                        }
                    }
                }
            } header: {
                HStack {
                    Text("Events")
                    Spacer()
                    Text("\(post.events.count)")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .listStyle(.inset)
        .navigationTitle(post.title)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button(action: {
                    viewModel.addEvent(to: post)
                }) {
                    Image(systemName: "plus")
                }
                .help("Add new event")
            }
        }
        .confirmationDialog(
            "Delete Event",
            isPresented: $showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let event = eventToDelete {
                    viewModel.deleteEvent(event)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to delete \"\(eventToDelete?.title ?? "this event")\"?")
        }
    }
}

/// Editable post metadata view
struct PostMetadataView: View {
    @Bindable var viewModel: BlogViewModel
    let post: BlogPost

    @State private var title: String = ""
    @State private var date: Date = Date()
    @State private var location: String = ""
    @State private var summary: String = ""
    @State private var tagsText: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Title
            LabeledContent("Title") {
                TextField("Title", text: $title)
                    .textFieldStyle(.plain)
                    .onChange(of: title) { _, newValue in
                        viewModel.updatePostTitle(newValue)
                    }
            }

            // Date
            LabeledContent("Date") {
                DatePicker("", selection: $date, displayedComponents: .date)
                    .labelsHidden()
                    .onChange(of: date) { _, newValue in
                        viewModel.updatePostDate(newValue)
                    }
            }

            // Location
            LabeledContent("Location") {
                TextField("Location", text: $location)
                    .textFieldStyle(.plain)
                    .onChange(of: location) { _, newValue in
                        viewModel.updatePostLocation(newValue)
                    }
            }

            // Summary
            LabeledContent("Summary") {
                TextField("Summary", text: $summary, axis: .vertical)
                    .textFieldStyle(.plain)
                    .lineLimit(2...4)
                    .onChange(of: summary) { _, newValue in
                        viewModel.updatePostSummary(newValue)
                    }
            }

            // Tags
            LabeledContent("Tags") {
                TextField("comma, separated, tags", text: $tagsText)
                    .textFieldStyle(.plain)
                    .onChange(of: tagsText) { _, newValue in
                        let tags = newValue.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
                        viewModel.updatePostTags(tags)
                    }
            }
        }
        .font(.callout)
        .onAppear {
            title = post.title
            date = post.date
            location = post.location
            summary = post.summary
            tagsText = post.tags.joined(separator: ", ")
        }
        .onChange(of: post.id) {
            title = post.title
            date = post.date
            location = post.location
            summary = post.summary
            tagsText = post.tags.joined(separator: ", ")
        }
    }
}

/// Row view for a single event in the list
struct EventRowView: View {
    let event: BlogEvent

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(event.title)
                    .font(.headline)
                    .lineLimit(1)

                Spacer()

                if let time = event.time, !time.isEmpty {
                    Text(time)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.1))
                        .clipShape(Capsule())
                }
            }

            if !event.text.isEmpty {
                Text(event.text.trimmingCharacters(in: .whitespacesAndNewlines))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            HStack(spacing: 12) {
                if !event.media.isEmpty {
                    Label("\(event.media.count)", systemImage: "photo.on.rectangle")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }

                if !event.chips.isEmpty {
                    Label("\(event.chips.count)", systemImage: "tag")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }

                if let place = event.place, !place.isEmpty {
                    Label(place, systemImage: "mappin")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    let vm = BlogViewModel()
    return EventsListView(
        viewModel: vm,
        post: BlogPost(
            title: "Day 1 — Test",
            date: Date(),
            location: "Test Location",
            summary: "Test summary",
            events: [
                BlogEvent(title: "Breakfast", time: "08:00", text: "Had some food"),
                BlogEvent(title: "Lunch", time: "12:30", text: "More food")
            ]
        )
    )
    .frame(width: 300)
}
