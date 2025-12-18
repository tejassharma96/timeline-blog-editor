import SwiftUI

/// Third column view for editing a single event
struct EventEditorView: View {
    @Bindable var viewModel: BlogViewModel
    let event: BlogEvent

    @State private var title: String = ""
    @State private var time: String = ""
    @State private var text: String = ""
    @State private var place: String = ""

    @State private var showingMediaPicker = false
    @State private var showingChipEditor = false
    @State private var editingChipIndex: Int?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Basic info section
                basicInfoSection

                Divider()

                // Media section
                mediaSection

                Divider()

                // Chips section
                chipsSection

                Divider()

                // Text content section
                textSection
            }
            .padding(20)
        }
        .navigationTitle("Event Editor")
        .onAppear {
            loadEventData()
        }
        .onChange(of: event.id) {
            loadEventData()
        }
        .sheet(isPresented: $showingMediaPicker) {
            MediaPickerView(viewModel: viewModel, event: event)
        }
        .sheet(isPresented: $showingChipEditor) {
            ChipEditorSheet(
                viewModel: viewModel,
                event: event,
                editingIndex: editingChipIndex
            )
        }
    }

    private func loadEventData() {
        title = event.title
        time = event.time ?? ""
        text = event.text
        place = event.place ?? ""
    }

    // MARK: - Basic Info Section

    private var basicInfoSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Basic Info")
                .font(.title2)
                .fontWeight(.semibold)

            VStack(alignment: .leading, spacing: 12) {
                // Title
                VStack(alignment: .leading, spacing: 4) {
                    Text("Title")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("Event title", text: $title)
                        .textFieldStyle(.roundedBorder)
                        .onChange(of: title) { _, newValue in
                            var updated = event
                            updated.title = newValue
                            viewModel.updateEvent(updated)
                        }
                }

                HStack(spacing: 16) {
                    // Time
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Time")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextField("HH:MM", text: $time)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 100)
                            .onChange(of: time) { _, newValue in
                                var updated = event
                                updated.time = newValue.isEmpty ? nil : newValue
                                viewModel.updateEvent(updated)
                            }
                    }

                    // Place
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Place")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextField("Place name", text: $place)
                            .textFieldStyle(.roundedBorder)
                            .onChange(of: place) { _, newValue in
                                var updated = event
                                updated.place = newValue.isEmpty ? nil : newValue
                                viewModel.updateEvent(updated)
                            }
                    }
                }
            }
        }
    }

    // MARK: - Media Section

    private var mediaSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Media")
                    .font(.title2)
                    .fontWeight(.semibold)

                Spacer()

                Button(action: { showingMediaPicker = true }) {
                    Label("Add Media", systemImage: "plus.circle")
                }
                .buttonStyle(.bordered)
            }

            if event.media.isEmpty {
                ContentUnavailableView(
                    "No Media",
                    systemImage: "photo.on.rectangle.angled",
                    description: Text("Add photos or videos to this event")
                )
                .frame(height: 150)
            } else {
                MediaGridView(viewModel: viewModel, event: event)
            }
        }
    }

    // MARK: - Chips Section

    private var chipsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Tags & Locations")
                    .font(.title2)
                    .fontWeight(.semibold)

                Spacer()

                Button(action: {
                    editingChipIndex = nil
                    showingChipEditor = true
                }) {
                    Label("Add Tag", systemImage: "plus.circle")
                }
                .buttonStyle(.bordered)
            }

            if event.chips.isEmpty {
                Text("No tags added")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .italic()
            } else {
                FlowLayout(spacing: 8) {
                    ForEach(Array(event.chips.enumerated()), id: \.element.id) { index, chip in
                        ChipView(chip: chip)
                            .contextMenu {
                                Button(action: {
                                    editingChipIndex = index
                                    showingChipEditor = true
                                }) {
                                    Label("Edit", systemImage: "pencil")
                                }

                                Button(role: .destructive, action: {
                                    viewModel.removeChip(from: event, at: index)
                                }) {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                    }
                }
            }
        }
    }

    // MARK: - Text Section

    private var textSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Description")
                .font(.title2)
                .fontWeight(.semibold)

            TextEditor(text: $text)
                .font(.body)
                .frame(minHeight: 150)
                .padding(8)
                .background(Color(nsColor: .textBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.secondary.opacity(0.2))
                )
                .onChange(of: text) { _, newValue in
                    var updated = event
                    updated.text = newValue
                    viewModel.updateEvent(updated)
                }

            Text("Supports Markdown formatting")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }
}

// MARK: - Media Grid

struct MediaGridView: View {
    @Bindable var viewModel: BlogViewModel
    let event: BlogEvent

    @State private var editingMediaIndex: Int?
    @State private var editingCaption: String = ""

    let columns = [
        GridItem(.adaptive(minimum: 120, maximum: 180), spacing: 12)
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(Array(event.media.enumerated()), id: \.element.id) { index, media in
                MediaThumbnailView(viewModel: viewModel, media: media)
                    .contextMenu {
                        Button(action: {
                            editingMediaIndex = index
                            editingCaption = media.caption ?? ""
                        }) {
                            Label("Edit Caption", systemImage: "text.bubble")
                        }

                        Button(role: .destructive, action: {
                            viewModel.removeMedia(from: event, at: index)
                        }) {
                            Label("Remove", systemImage: "trash")
                        }
                    }
            }
        }
        .sheet(item: $editingMediaIndex) { index in
            CaptionEditorSheet(
                caption: $editingCaption,
                onSave: {
                    viewModel.updateMediaCaption(for: event, mediaIndex: index, caption: editingCaption.isEmpty ? nil : editingCaption)
                    editingMediaIndex = nil
                },
                onCancel: {
                    editingMediaIndex = nil
                }
            )
        }
    }
}

extension Int: @retroactive Identifiable {
    public var id: Int { self }
}

// MARK: - Media Thumbnail

struct MediaThumbnailView: View {
    @Bindable var viewModel: BlogViewModel
    let media: EventMedia

    @State private var thumbnailImage: NSImage?

    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.secondary.opacity(0.1))
                    .aspectRatio(1, contentMode: .fit)

                if let image = thumbnailImage {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                } else {
                    Image(systemName: iconForMediaType)
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                }

                // Video indicator
                if media.mediaType == .video {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Image(systemName: "play.circle.fill")
                                .font(.title2)
                                .foregroundStyle(.white)
                                .shadow(radius: 2)
                                .padding(8)
                        }
                    }
                }
            }

            if let caption = media.caption, !caption.isEmpty {
                Text(caption)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }
        }
        .task {
            await loadThumbnail()
        }
    }

    private var iconForMediaType: String {
        switch media.mediaType {
        case .image: return "photo"
        case .video: return "video"
        case .youtube: return "play.rectangle"
        case .map: return "map"
        }
    }

    private func loadThumbnail() async {
        guard media.mediaType == .image || media.mediaType == .video else { return }

        if let url = await viewModel.getFullMediaURL(for: media.displayPath) {
            if media.mediaType == .image {
                thumbnailImage = NSImage(contentsOf: url)
            } else if media.mediaType == .video {
                // For videos, try to generate a thumbnail
                thumbnailImage = await generateVideoThumbnail(url: url)
            }
        }
    }

    private func generateVideoThumbnail(url: URL) async -> NSImage? {
        // Simple placeholder for video - in production you'd use AVAssetImageGenerator
        return nil
    }
}

// MARK: - Chip View

struct ChipView: View {
    let chip: EventChip

    var body: some View {
        HStack(spacing: 4) {
            if chip.url != nil {
                Image(systemName: "link")
                    .font(.caption2)
            }
            Text(chip.label)
        }
        .font(.callout)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.accentColor.opacity(0.15))
        .foregroundStyle(Color.accentColor)
        .clipShape(Capsule())
    }
}

// MARK: - Flow Layout

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(
            in: proposal.width ?? 0,
            spacing: spacing,
            subviews: subviews
        )
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(
            in: bounds.width,
            spacing: spacing,
            subviews: subviews
        )

        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(
                x: bounds.minX + result.positions[index].x,
                y: bounds.minY + result.positions[index].y
            ), proposal: .unspecified)
        }
    }

    struct FlowResult {
        var size: CGSize = .zero
        var positions: [CGPoint] = []

        init(in maxWidth: CGFloat, spacing: CGFloat, subviews: Subviews) {
            var x: CGFloat = 0
            var y: CGFloat = 0
            var rowHeight: CGFloat = 0

            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)

                if x + size.width > maxWidth && x > 0 {
                    x = 0
                    y += rowHeight + spacing
                    rowHeight = 0
                }

                positions.append(CGPoint(x: x, y: y))
                rowHeight = max(rowHeight, size.height)
                x += size.width + spacing

                self.size.width = max(self.size.width, x)
            }

            self.size.height = y + rowHeight
        }
    }
}

// MARK: - Caption Editor Sheet

struct CaptionEditorSheet: View {
    @Binding var caption: String
    let onSave: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Text("Edit Caption")
                .font(.headline)

            TextField("Caption", text: $caption, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(3...6)

            HStack {
                Button("Cancel", action: onCancel)
                    .buttonStyle(.bordered)

                Button("Save", action: onSave)
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(20)
        .frame(width: 400)
    }
}

// MARK: - Chip Editor Sheet

struct ChipEditorSheet: View {
    @Bindable var viewModel: BlogViewModel
    let event: BlogEvent
    let editingIndex: Int?

    @State private var label: String = ""
    @State private var url: String = ""

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 16) {
            Text(editingIndex == nil ? "Add Tag" : "Edit Tag")
                .font(.headline)

            VStack(alignment: .leading, spacing: 8) {
                Text("Label")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("Tag label", text: $label)
                    .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("URL (optional)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("https://...", text: $url)
                    .textFieldStyle(.roundedBorder)
            }

            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(.bordered)

                Button(editingIndex == nil ? "Add" : "Save") {
                    if let index = editingIndex {
                        viewModel.updateChip(in: event, at: index, label: label, url: url.isEmpty ? nil : url)
                    } else {
                        viewModel.addChip(to: event, label: label, url: url.isEmpty ? nil : url)
                    }
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(label.isEmpty)
            }
        }
        .padding(20)
        .frame(width: 400)
        .onAppear {
            if let index = editingIndex, index < event.chips.count {
                let chip = event.chips[index]
                label = chip.label
                url = chip.url ?? ""
            }
        }
    }
}

#Preview {
    EventEditorView(
        viewModel: BlogViewModel(),
        event: BlogEvent(
            title: "Test Event",
            time: "08:00",
            text: "Some description",
            media: [.simple(path: "/assets/images/day1/photo.jpg")],
            chips: [.simple(label: "Test"), .linked(label: "Google", url: "https://google.com")]
        )
    )
    .frame(width: 500, height: 800)
}
