import Foundation
import Yams

/// Service for parsing and serializing YAML frontmatter in blog posts
actor YAMLParsingService {

    enum ParsingError: LocalizedError {
        case invalidFrontmatter
        case missingFrontmatterDelimiters
        case yamlDecodingFailed(Error)
        case yamlEncodingFailed(Error)

        var errorDescription: String? {
            switch self {
            case .invalidFrontmatter:
                return "Invalid frontmatter format"
            case .missingFrontmatterDelimiters:
                return "Missing frontmatter delimiters (---)"
            case .yamlDecodingFailed(let error):
                return "Failed to decode YAML: \(error.localizedDescription)"
            case .yamlEncodingFailed(let error):
                return "Failed to encode YAML: \(error.localizedDescription)"
            }
        }
    }

    private let decoder: YAMLDecoder
    private let encoder: YAMLEncoder

    init() {
        self.decoder = YAMLDecoder()
        self.encoder = YAMLEncoder()
    }

    /// Parses a markdown file content into a BlogPost
    /// - Parameter content: The full content of the markdown file
    /// - Returns: A parsed BlogPost
    func parse(_ content: String) throws -> BlogPost {
        let (frontmatter, body) = try extractFrontmatterAndBody(from: content)

        do {
            var post = try decoder.decode(BlogPost.self, from: frontmatter)
            post.bodyContent = body.trimmingCharacters(in: .whitespacesAndNewlines)
            return post
        } catch {
            throw ParsingError.yamlDecodingFailed(error)
        }
    }

    /// Serializes a BlogPost back to markdown file content
    /// - Parameter post: The BlogPost to serialize
    /// - Returns: The full markdown file content
    func serialize(_ post: BlogPost) throws -> String {
        do {
            var yamlContent = try encoder.encode(post)

            // Ensure the YAML content ends with a newline before the closing delimiter
            if !yamlContent.hasSuffix("\n") {
                yamlContent += "\n"
            }

            var result = "---\n\(yamlContent)---\n"

            if !post.bodyContent.isEmpty {
                result += "\n\(post.bodyContent)\n"
            }

            // Add the day-timeline include if it contains events
            if !post.events.isEmpty && !post.bodyContent.contains("day-timeline.html") {
                result += "\n{% include day-timeline.html events=page.events %}\n"
            }

            return result
        } catch {
            throw ParsingError.yamlEncodingFailed(error)
        }
    }

    /// Extracts frontmatter and body from markdown content
    private func extractFrontmatterAndBody(from content: String) throws -> (frontmatter: String, body: String) {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)

        guard trimmed.hasPrefix("---") else {
            throw ParsingError.missingFrontmatterDelimiters
        }

        // Find the closing --- delimiter
        let lines = content.components(separatedBy: .newlines)
        var frontmatterEndIndex: Int?

        for (index, line) in lines.enumerated() {
            if index > 0 && line.trimmingCharacters(in: .whitespaces) == "---" {
                frontmatterEndIndex = index
                break
            }
        }

        guard let endIndex = frontmatterEndIndex else {
            throw ParsingError.missingFrontmatterDelimiters
        }

        let frontmatterLines = Array(lines[1..<endIndex])
        let bodyLines = Array(lines[(endIndex + 1)...])

        let frontmatter = frontmatterLines.joined(separator: "\n")
        let body = bodyLines.joined(separator: "\n")

        return (frontmatter, body)
    }
}

// MARK: - Custom Date Coding Strategy

extension YAMLDecoder {
    /// Creates a decoder configured for blog post dates (YYYY-MM-DD format)
    static func blogDecoder() -> YAMLDecoder {
        let decoder = YAMLDecoder()
        return decoder
    }
}

extension YAMLEncoder {
    /// Creates an encoder configured for blog post dates (YYYY-MM-DD format)
    static func blogEncoder() -> YAMLEncoder {
        let encoder = YAMLEncoder()
        return encoder
    }
}
