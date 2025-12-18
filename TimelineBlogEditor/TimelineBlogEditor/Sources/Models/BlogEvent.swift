import Foundation

/// Represents a single event within a day's timeline
struct BlogEvent: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var title: String
    var time: String?
    var text: String
    var media: [EventMedia]
    var chips: [EventChip]
    var place: String?
    var tags: [String]?

    enum CodingKeys: String, CodingKey {
        case title
        case time
        case text
        case media
        case chips
        case place
        case tags
    }

    init(
        id: UUID = UUID(),
        title: String,
        time: String? = nil,
        text: String = "",
        media: [EventMedia] = [],
        chips: [EventChip] = [],
        place: String? = nil,
        tags: [String]? = nil
    ) {
        self.id = id
        self.title = title
        self.time = time
        self.text = text
        self.media = media
        self.chips = chips
        self.place = place
        self.tags = tags
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        self.id = UUID()
        self.title = try container.decode(String.self, forKey: .title)
        self.time = try container.decodeIfPresent(String.self, forKey: .time)
        self.text = try container.decodeIfPresent(String.self, forKey: .text) ?? ""
        self.media = try container.decodeIfPresent([EventMedia].self, forKey: .media) ?? []
        self.chips = try container.decodeIfPresent([EventChip].self, forKey: .chips) ?? []
        self.place = try container.decodeIfPresent(String.self, forKey: .place)
        self.tags = try container.decodeIfPresent([String].self, forKey: .tags)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(title, forKey: .title)
        try container.encodeIfPresent(time, forKey: .time)
        if !text.isEmpty {
            try container.encode(text, forKey: .text)
        }
        if !media.isEmpty {
            try container.encode(media, forKey: .media)
        }
        if !chips.isEmpty {
            try container.encode(chips, forKey: .chips)
        }
        try container.encodeIfPresent(place, forKey: .place)
        if let tags = tags, !tags.isEmpty {
            try container.encode(tags, forKey: .tags)
        }
    }
}
