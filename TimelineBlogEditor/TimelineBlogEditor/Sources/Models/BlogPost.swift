import Foundation

/// Represents a single blog post (a "Day" in the timeline)
struct BlogPost: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var layout: String = "post"
    var title: String
    var date: Date
    var location: String
    var coverImage: String?
    var summary: String
    var tags: [String]
    var events: [BlogEvent]

    /// The markdown body content after the frontmatter
    var bodyContent: String = ""

    /// The original filename (without path)
    var filename: String?

    enum CodingKeys: String, CodingKey {
        case layout
        case title
        case date
        case location
        case coverImage = "cover_image"
        case summary
        case tags
        case events
    }

    init(
        id: UUID = UUID(),
        layout: String = "post",
        title: String,
        date: Date,
        location: String,
        coverImage: String? = nil,
        summary: String,
        tags: [String] = [],
        events: [BlogEvent] = [],
        bodyContent: String = "",
        filename: String? = nil
    ) {
        self.id = id
        self.layout = layout
        self.title = title
        self.date = date
        self.location = location
        self.coverImage = coverImage
        self.summary = summary
        self.tags = tags
        self.events = events
        self.bodyContent = bodyContent
        self.filename = filename
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        self.id = UUID()
        self.layout = try container.decodeIfPresent(String.self, forKey: .layout) ?? "post"
        self.title = try container.decode(String.self, forKey: .title)
        self.date = try container.decode(Date.self, forKey: .date)
        self.location = try container.decodeIfPresent(String.self, forKey: .location) ?? ""
        self.coverImage = try container.decodeIfPresent(String.self, forKey: .coverImage)
        self.summary = try container.decodeIfPresent(String.self, forKey: .summary) ?? ""
        self.tags = try container.decodeIfPresent([String].self, forKey: .tags) ?? []
        self.events = try container.decodeIfPresent([BlogEvent].self, forKey: .events) ?? []
        self.bodyContent = ""
        self.filename = nil
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(layout, forKey: .layout)
        try container.encode(title, forKey: .title)
        try container.encode(date, forKey: .date)
        try container.encode(location, forKey: .location)
        try container.encodeIfPresent(coverImage, forKey: .coverImage)
        try container.encode(summary, forKey: .summary)
        if !tags.isEmpty {
            try container.encode(tags, forKey: .tags)
        }
        try container.encode(events, forKey: .events)
    }

    /// Extracts the day number from the title (e.g., "Day 1 — To Honolulu" -> 1)
    var dayNumber: Int? {
        let pattern = #"Day\s+(\d+)"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
              let match = regex.firstMatch(in: title, range: NSRange(title.startIndex..., in: title)),
              let range = Range(match.range(at: 1), in: title) else {
            return nil
        }
        return Int(title[range])
    }

    /// Generates the expected filename for this post
    func generateFilename() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateString = formatter.string(from: date)

        // Create slug from title
        let slug = title
            .lowercased()
            .replacingOccurrences(of: "—", with: "-")
            .replacingOccurrences(of: " ", with: "-")
            .components(separatedBy: CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-")).inverted)
            .joined()
            .replacingOccurrences(of: "--", with: "-")

        return "\(dateString)-\(slug).md"
    }
}
