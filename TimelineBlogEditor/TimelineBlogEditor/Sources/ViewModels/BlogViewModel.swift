import Foundation
import SwiftUI
import Observation

/// Main view model for the blog editor
@Observable
@MainActor
final class BlogViewModel {

    // MARK: - State

    var blogDirectoryURL: URL?
    var posts: [BlogPost] = []
    var selectedPost: BlogPost?
    var selectedEvent: BlogEvent?

    var isLoading = false
    var errorMessage: String?
    var showError = false

    // MARK: - Services

    private let fileService = BlogFileService()
    private var mediaCopyService: MediaCopyService?
    let previewService = PreviewService()

    // MARK: - Auto-save

    private var saveTask: Task<Void, Never>?
    private let saveDebounceInterval: TimeInterval = 1.0

    // MARK: - Computed Properties

    var hasBlogSelected: Bool {
        blogDirectoryURL != nil
    }

    var sortedPosts: [BlogPost] {
        posts.sorted { $0.date > $1.date }
    }

    // MARK: - Blog Directory Management

    func selectBlogDirectory(_ url: URL) async {
        let isValid = await fileService.validateBlogDirectory(url)

        guard isValid else {
            showError(message: "Selected directory does not contain a _posts folder")
            return
        }

        await fileService.setBlogDirectory(url)
        blogDirectoryURL = url
        mediaCopyService = MediaCopyService(blogFileService: fileService)

        await loadPosts()
    }

    func closeBlog() {
        previewService.stopPreview()
        blogDirectoryURL = nil
        posts = []
        selectedPost = nil
        selectedEvent = nil
    }

    // MARK: - Preview

    func startPreview() async {
        guard let blogDir = blogDirectoryURL else { return }
        await previewService.startPreview(blogDirectory: blogDir)
    }

    func stopPreview() {
        previewService.stopPreview()
    }

    // MARK: - Post Management

    func loadPosts() async {
        isLoading = true
        defer { isLoading = false }

        do {
            posts = try await fileService.loadAllPosts()
        } catch {
            showError(message: "Failed to load posts: \(error.localizedDescription)")
        }
    }

    func selectPost(_ post: BlogPost?) {
        selectedPost = post
        selectedEvent = nil
    }

    func selectEvent(_ event: BlogEvent?) {
        selectedEvent = event
    }

    func createNewPost() {
        let nextDayNumber = (posts.compactMap { $0.dayNumber }.max() ?? 0) + 1
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: posts.first?.date ?? Date()) ?? Date()

        var newPost = BlogPost(
            title: "Day \(nextDayNumber) — New Day",
            date: tomorrow,
            location: "",
            summary: "",
            events: []
        )
        newPost.filename = newPost.generateFilename()

        posts.insert(newPost, at: 0)
        selectedPost = newPost
        selectedEvent = nil

        scheduleSave(for: newPost)
    }

    func deletePost(_ post: BlogPost) async {
        do {
            try await fileService.deletePost(post)
            posts.removeAll { $0.id == post.id }

            if selectedPost?.id == post.id {
                selectedPost = nil
                selectedEvent = nil
            }
        } catch {
            showError(message: "Failed to delete post: \(error.localizedDescription)")
        }
    }

    // MARK: - Post Updates

    func updatePost(_ post: BlogPost) {
        guard let index = posts.firstIndex(where: { $0.id == post.id }) else { return }
        posts[index] = post

        if selectedPost?.id == post.id {
            selectedPost = post
        }

        scheduleSave(for: post)
    }

    func updatePostTitle(_ title: String) {
        guard var post = selectedPost else { return }
        post.title = title
        updatePost(post)
    }

    func updatePostDate(_ date: Date) {
        guard var post = selectedPost else { return }
        post.date = date
        updatePost(post)
    }

    func updatePostLocation(_ location: String) {
        guard var post = selectedPost else { return }
        post.location = location
        updatePost(post)
    }

    func updatePostSummary(_ summary: String) {
        guard var post = selectedPost else { return }
        post.summary = summary
        updatePost(post)
    }

    func updatePostCoverImage(_ path: String?) {
        guard var post = selectedPost else { return }
        post.coverImage = path
        updatePost(post)
    }

    func updatePostTags(_ tags: [String]) {
        guard var post = selectedPost else { return }
        post.tags = tags
        updatePost(post)
    }

    func updatePostBody(_ body: String) {
        guard var post = selectedPost else { return }
        post.bodyContent = body
        updatePost(post)
    }

    // MARK: - Event Management

    func addEvent(to post: BlogPost) {
        guard var updatedPost = posts.first(where: { $0.id == post.id }) else { return }

        let newEvent = BlogEvent(title: "New Event", text: "")
        updatedPost.events.append(newEvent)

        updatePost(updatedPost)
        selectedEvent = newEvent
    }

    func updateEvent(_ event: BlogEvent) {
        guard var post = selectedPost,
              let eventIndex = post.events.firstIndex(where: { $0.id == event.id }) else { return }

        post.events[eventIndex] = event
        updatePost(post)
        selectedEvent = event
    }

    func deleteEvent(_ event: BlogEvent) {
        guard var post = selectedPost else { return }

        post.events.removeAll { $0.id == event.id }
        updatePost(post)

        if selectedEvent?.id == event.id {
            selectedEvent = nil
        }
    }

    func moveEvent(from source: IndexSet, to destination: Int) {
        guard var post = selectedPost else { return }

        post.events.move(fromOffsets: source, toOffset: destination)
        updatePost(post)
    }

    // MARK: - Media Management

    func addMedia(to event: BlogEvent, from urls: [URL]) async {
        guard let post = selectedPost,
              let dayNumber = post.dayNumber,
              let mediaCopyService = mediaCopyService else {
            showError(message: "Cannot add media: Invalid post or day number")
            return
        }

        do {
            let relativePaths = try await mediaCopyService.copyMediaFiles(from: urls, toDayNumber: dayNumber)

            var updatedEvent = event
            for path in relativePaths {
                updatedEvent.media.append(.simple(path: path))
            }

            updateEvent(updatedEvent)
        } catch {
            showError(message: "Failed to copy media: \(error.localizedDescription)")
        }
    }

    func updateMediaCaption(for event: BlogEvent, mediaIndex: Int, caption: String?) {
        guard mediaIndex < event.media.count else { return }

        var updatedEvent = event
        updatedEvent.media[mediaIndex] = updatedEvent.media[mediaIndex].withCaption(caption)
        updateEvent(updatedEvent)
    }

    func removeMedia(from event: BlogEvent, at index: Int) {
        guard index < event.media.count else { return }

        var updatedEvent = event
        updatedEvent.media.remove(at: index)
        updateEvent(updatedEvent)
    }

    func moveMedia(in event: BlogEvent, from source: IndexSet, to destination: Int) {
        var updatedEvent = event
        updatedEvent.media.move(fromOffsets: source, toOffset: destination)
        updateEvent(updatedEvent)
    }

    // MARK: - Chip Management

    func addChip(to event: BlogEvent, label: String, url: String?) {
        var updatedEvent = event
        let chip: EventChip = url.map { EventChip.linked(label: label, url: $0) } ?? EventChip.simple(label: label)
        updatedEvent.chips.append(chip)
        updateEvent(updatedEvent)
    }

    func removeChip(from event: BlogEvent, at index: Int) {
        guard index < event.chips.count else { return }

        var updatedEvent = event
        updatedEvent.chips.remove(at: index)
        updateEvent(updatedEvent)
    }

    func updateChip(in event: BlogEvent, at index: Int, label: String, url: String?) {
        guard index < event.chips.count else { return }

        var updatedEvent = event
        let chip: EventChip = url.map { EventChip.linked(label: label, url: $0) } ?? EventChip.simple(label: label)
        updatedEvent.chips[index] = chip
        updateEvent(updatedEvent)
    }

    // MARK: - Auto-save

    private func scheduleSave(for post: BlogPost) {
        saveTask?.cancel()

        saveTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(self?.saveDebounceInterval ?? 1.0))

            guard !Task.isCancelled else { return }

            await self?.savePost(post)
        }
    }

    private func savePost(_ post: BlogPost) async {
        do {
            // Handle filename changes
            let renamedPost = try await fileService.renamePostIfNeeded(post, oldFilename: post.filename)
            try await fileService.savePost(renamedPost)

            // Update local state if filename changed
            if renamedPost.filename != post.filename,
               let index = posts.firstIndex(where: { $0.id == post.id }) {
                posts[index].filename = renamedPost.filename
                if selectedPost?.id == post.id {
                    selectedPost?.filename = renamedPost.filename
                }
            }
        } catch {
            showError(message: "Failed to save post: \(error.localizedDescription)")
        }
    }

    // MARK: - Error Handling

    private func showError(message: String) {
        errorMessage = message
        showError = true
    }

    func dismissError() {
        errorMessage = nil
        showError = false
    }

    // MARK: - Helpers

    func getFullMediaURL(for relativePath: String) async -> URL? {
        return await fileService.fullURL(for: relativePath.hasPrefix("/") ? String(relativePath.dropFirst()) : relativePath)
    }
}
