import Foundation

/// Represents a chip/tag attached to an event
/// Can be either a simple string label or an object with label and URL
enum EventChip: Identifiable, Codable, Equatable {
    case simple(label: String)
    case linked(label: String, url: String)

    var id: String {
        switch self {
        case .simple(let label):
            return label
        case .linked(let label, let url):
            return "\(label)-\(url)"
        }
    }

    var label: String {
        switch self {
        case .simple(let label):
            return label
        case .linked(let label, _):
            return label
        }
    }

    var url: String? {
        switch self {
        case .simple:
            return nil
        case .linked(_, let url):
            return url
        }
    }

    enum CodingKeys: String, CodingKey {
        case label
        case url
    }

    init(from decoder: Decoder) throws {
        // Try decoding as a simple string first
        if let container = try? decoder.singleValueContainer(),
           let label = try? container.decode(String.self) {
            self = .simple(label: label)
            return
        }

        // Otherwise, decode as an object
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let label = try container.decode(String.self, forKey: .label)
        let url = try container.decodeIfPresent(String.self, forKey: .url)

        if let url = url {
            self = .linked(label: label, url: url)
        } else {
            self = .simple(label: label)
        }
    }

    func encode(to encoder: Encoder) throws {
        switch self {
        case .simple(let label):
            var container = encoder.singleValueContainer()
            try container.encode(label)

        case .linked(let label, let url):
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(label, forKey: .label)
            try container.encode(url, forKey: .url)
        }
    }

    /// Creates a linked chip from a simple label
    func withURL(_ url: String?) -> EventChip {
        guard let url = url, !url.isEmpty else {
            return .simple(label: self.label)
        }
        return .linked(label: self.label, url: url)
    }
}
