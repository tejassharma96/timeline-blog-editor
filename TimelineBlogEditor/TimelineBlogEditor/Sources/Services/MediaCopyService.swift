import Foundation
import AppKit
import UniformTypeIdentifiers

/// Service for copying media files to the blog's assets directory
actor MediaCopyService {

    enum MediaError: LocalizedError {
        case invalidSourceFile
        case copyFailed(Error)
        case unsupportedMediaType
        case blogDirectoryNotSet

        var errorDescription: String? {
            switch self {
            case .invalidSourceFile:
                return "Invalid source file"
            case .copyFailed(let error):
                return "Failed to copy file: \(error.localizedDescription)"
            case .unsupportedMediaType:
                return "Unsupported media type"
            case .blogDirectoryNotSet:
                return "Blog directory not set"
            }
        }
    }

    private let fileManager = FileManager.default
    private let blogFileService: BlogFileService

    /// Supported image extensions
    static let imageExtensions = ["jpg", "jpeg", "png", "gif", "webp", "heic"]

    /// Supported video extensions
    static let videoExtensions = ["mp4", "mov", "webm", "m4v"]

    /// All supported media extensions
    static var allSupportedExtensions: [String] {
        imageExtensions + videoExtensions
    }

    init(blogFileService: BlogFileService) {
        self.blogFileService = blogFileService
    }

    /// Copies a media file to the appropriate day folder in assets/images
    /// - Parameters:
    ///   - sourceURL: The URL of the source file
    ///   - dayNumber: The day number for organizing the file
    ///   - customFilename: Optional custom filename (without extension)
    /// - Returns: The relative path to use in the blog post (e.g., /assets/images/day1/photo.jpg)
    func copyMedia(from sourceURL: URL, toDayNumber dayNumber: Int, customFilename: String? = nil) async throws -> String {
        guard fileManager.fileExists(atPath: sourceURL.path) else {
            throw MediaError.invalidSourceFile
        }

        let fileExtension = sourceURL.pathExtension.lowercased()
        guard Self.allSupportedExtensions.contains(fileExtension) else {
            throw MediaError.unsupportedMediaType
        }

        // Create the day assets directory
        let dayDirectory = try await blogFileService.createDayAssetsDirectory(dayNumber: dayNumber)

        // Generate the destination filename
        let filename: String
        if let customFilename = customFilename {
            filename = "\(customFilename).\(fileExtension)"
        } else {
            filename = generateUniqueFilename(from: sourceURL, in: dayDirectory)
        }

        let destinationURL = dayDirectory.appendingPathComponent(filename)

        // Copy the file
        do {
            // Remove existing file if it exists
            if fileManager.fileExists(atPath: destinationURL.path) {
                try fileManager.removeItem(at: destinationURL)
            }
            try fileManager.copyItem(at: sourceURL, to: destinationURL)
        } catch {
            throw MediaError.copyFailed(error)
        }

        // Return the relative path for the blog
        return "/assets/images/day\(dayNumber)/\(filename)"
    }

    /// Copies multiple media files to a day folder
    /// - Parameters:
    ///   - sourceURLs: Array of source file URLs
    ///   - dayNumber: The day number for organizing the files
    /// - Returns: Array of relative paths for the blog post
    func copyMediaFiles(from sourceURLs: [URL], toDayNumber dayNumber: Int) async throws -> [String] {
        var relativePaths: [String] = []

        for sourceURL in sourceURLs {
            let relativePath = try await copyMedia(from: sourceURL, toDayNumber: dayNumber)
            relativePaths.append(relativePath)
        }

        return relativePaths
    }

    /// Generates a unique filename for a media file
    private func generateUniqueFilename(from sourceURL: URL, in directory: URL) -> String {
        let originalName = sourceURL.deletingPathExtension().lastPathComponent
        let fileExtension = sourceURL.pathExtension.lowercased()

        // Clean the filename
        let cleanName = originalName
            .replacingOccurrences(of: " ", with: "-")
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_")).inverted)
            .joined()

        var filename = "\(cleanName).\(fileExtension)"
        var counter = 1

        while fileManager.fileExists(atPath: directory.appendingPathComponent(filename).path) {
            filename = "\(cleanName)-\(counter).\(fileExtension)"
            counter += 1
        }

        return filename
    }

    /// Gets the UTTypes for supported media files
    static var supportedContentTypes: [UTType] {
        var types: [UTType] = []

        // Images
        types.append(.jpeg)
        types.append(.png)
        types.append(.gif)
        types.append(.webP)
        types.append(.heic)

        // Videos
        types.append(.mpeg4Movie)
        types.append(.quickTimeMovie)
        types.append(.movie)

        return types
    }

    /// Checks if a file is a supported media type
    static func isSupportedMedia(_ url: URL) -> Bool {
        let ext = url.pathExtension.lowercased()
        return allSupportedExtensions.contains(ext)
    }

    /// Determines the media type from a file extension
    static func mediaType(for url: URL) -> MediaType {
        let ext = url.pathExtension.lowercased()
        if videoExtensions.contains(ext) {
            return .video
        }
        return .image
    }
}
