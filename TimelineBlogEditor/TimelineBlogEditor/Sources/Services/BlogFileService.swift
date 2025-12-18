import Foundation

/// Service for reading and writing blog files from the filesystem
actor BlogFileService {

    enum FileError: LocalizedError {
        case invalidBlogDirectory
        case postsDirectoryNotFound
        case fileReadFailed(String, Error)
        case fileWriteFailed(String, Error)
        case fileDeleteFailed(String, Error)

        var errorDescription: String? {
            switch self {
            case .invalidBlogDirectory:
                return "Invalid blog directory"
            case .postsDirectoryNotFound:
                return "_posts directory not found in blog"
            case .fileReadFailed(let path, let error):
                return "Failed to read file at \(path): \(error.localizedDescription)"
            case .fileWriteFailed(let path, let error):
                return "Failed to write file at \(path): \(error.localizedDescription)"
            case .fileDeleteFailed(let path, let error):
                return "Failed to delete file at \(path): \(error.localizedDescription)"
            }
        }
    }

    private let fileManager = FileManager.default
    private let yamlService = YAMLParsingService()

    private var blogDirectoryURL: URL?

    /// The URL of the _posts directory
    var postsDirectoryURL: URL? {
        blogDirectoryURL?.appendingPathComponent("_posts")
    }

    /// The URL of the assets/images directory
    var assetsImagesURL: URL? {
        blogDirectoryURL?.appendingPathComponent("assets/images")
    }

    /// Sets the blog directory
    func setBlogDirectory(_ url: URL) {
        self.blogDirectoryURL = url
    }

    /// Gets the current blog directory URL
    func getBlogDirectory() -> URL? {
        return blogDirectoryURL
    }

    /// Validates that a directory is a valid blog directory
    func validateBlogDirectory(_ url: URL) -> Bool {
        let postsURL = url.appendingPathComponent("_posts")
        var isDirectory: ObjCBool = false
        return fileManager.fileExists(atPath: postsURL.path, isDirectory: &isDirectory) && isDirectory.boolValue
    }

    /// Loads all blog posts from the _posts directory
    func loadAllPosts() async throws -> [BlogPost] {
        guard let postsURL = postsDirectoryURL else {
            throw FileError.postsDirectoryNotFound
        }

        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: postsURL.path, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            throw FileError.postsDirectoryNotFound
        }

        let contents = try fileManager.contentsOfDirectory(
            at: postsURL,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        )

        let markdownFiles = contents.filter { $0.pathExtension == "md" }

        var posts: [BlogPost] = []

        for fileURL in markdownFiles {
            do {
                let post = try await loadPost(from: fileURL)
                posts.append(post)
            } catch {
                // Log error but continue loading other posts
                print("Warning: Failed to load post at \(fileURL.lastPathComponent): \(error)")
            }
        }

        // Sort by date, most recent first
        return posts.sorted { $0.date > $1.date }
    }

    /// Loads a single blog post from a file
    func loadPost(from url: URL) async throws -> BlogPost {
        do {
            let content = try String(contentsOf: url, encoding: .utf8)
            var post = try await yamlService.parse(content)
            post.filename = url.lastPathComponent
            return post
        } catch let error as YAMLParsingService.ParsingError {
            throw error
        } catch {
            throw FileError.fileReadFailed(url.path, error)
        }
    }

    /// Saves a blog post to a file
    func savePost(_ post: BlogPost) async throws {
        guard let postsURL = postsDirectoryURL else {
            throw FileError.postsDirectoryNotFound
        }

        let filename = post.filename ?? post.generateFilename()
        let fileURL = postsURL.appendingPathComponent(filename)

        do {
            let content = try await yamlService.serialize(post)
            try content.write(to: fileURL, atomically: true, encoding: .utf8)
        } catch let error as YAMLParsingService.ParsingError {
            throw error
        } catch {
            throw FileError.fileWriteFailed(fileURL.path, error)
        }
    }

    /// Deletes a blog post file
    func deletePost(_ post: BlogPost) async throws {
        guard let postsURL = postsDirectoryURL,
              let filename = post.filename else {
            throw FileError.invalidBlogDirectory
        }

        let fileURL = postsURL.appendingPathComponent(filename)

        do {
            try fileManager.removeItem(at: fileURL)
        } catch {
            throw FileError.fileDeleteFailed(fileURL.path, error)
        }
    }

    /// Renames a post file if the date or title changed
    func renamePostIfNeeded(_ post: BlogPost, oldFilename: String?) async throws -> BlogPost {
        guard let postsURL = postsDirectoryURL,
              let oldFilename = oldFilename ?? post.filename else {
            return post
        }

        let newFilename = post.generateFilename()

        if oldFilename != newFilename {
            let oldURL = postsURL.appendingPathComponent(oldFilename)
            let newURL = postsURL.appendingPathComponent(newFilename)

            if fileManager.fileExists(atPath: oldURL.path) {
                try fileManager.moveItem(at: oldURL, to: newURL)
            }

            var updatedPost = post
            updatedPost.filename = newFilename
            return updatedPost
        }

        return post
    }

    /// Creates the assets/images directory for a day if it doesn't exist
    func createDayAssetsDirectory(dayNumber: Int) async throws -> URL {
        guard let assetsURL = assetsImagesURL else {
            throw FileError.invalidBlogDirectory
        }

        let dayDirectory = assetsURL.appendingPathComponent("day\(dayNumber)")

        if !fileManager.fileExists(atPath: dayDirectory.path) {
            try fileManager.createDirectory(at: dayDirectory, withIntermediateDirectories: true)
        }

        return dayDirectory
    }

    /// Checks if a file exists at the given path relative to the blog directory
    func fileExists(relativePath: String) -> Bool {
        guard let blogDir = blogDirectoryURL else { return false }
        let fullPath = blogDir.appendingPathComponent(relativePath)
        return fileManager.fileExists(atPath: fullPath.path)
    }

    /// Gets the full URL for a relative path
    func fullURL(for relativePath: String) -> URL? {
        blogDirectoryURL?.appendingPathComponent(relativePath)
    }
}
