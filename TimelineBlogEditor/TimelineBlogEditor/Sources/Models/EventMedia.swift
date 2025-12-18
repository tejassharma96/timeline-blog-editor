import Foundation

/// Represents media attached to an event
/// Can be either a simple string path or an object with src, caption, and type
enum EventMedia: Identifiable, Codable, Equatable {
    case simple(path: String)
    case detailed(src: String, caption: String?, type: MediaType?)
    case youtube(id: String, caption: String?)
    case map(place: String?, lat: Double?, lng: Double?, src: String?, caption: String?)

    var id: String {
        switch self {
        case .simple(let path):
            return path
        case .detailed(let src, _, _):
            return src
        case .youtube(let id, _):
            return "youtube-\(id)"
        case .map(let place, let lat, let lng, let src, _):
            if let src = src { return "map-\(src)" }
            if let place = place { return "map-\(place)" }
            if let lat = lat, let lng = lng { return "map-\(lat)-\(lng)" }
            return "map-unknown"
        }
    }

    var displayPath: String {
        switch self {
        case .simple(let path):
            return path
        case .detailed(let src, _, _):
            return src
        case .youtube(let id, _):
            return "YouTube: \(id)"
        case .map(let place, _, _, let src, _):
            return place ?? src ?? "Map"
        }
    }

    var caption: String? {
        switch self {
        case .simple:
            return nil
        case .detailed(_, let caption, _):
            return caption
        case .youtube(_, let caption):
            return caption
        case .map(_, _, _, _, let caption):
            return caption
        }
    }

    var mediaType: MediaType {
        switch self {
        case .simple(let path):
            return MediaType.fromPath(path)
        case .detailed(let src, _, let type):
            return type ?? MediaType.fromPath(src)
        case .youtube:
            return .youtube
        case .map:
            return .map
        }
    }

    enum CodingKeys: String, CodingKey {
        case src
        case caption
        case type
        case id
        case place
        case lat
        case lng
    }

    init(from decoder: Decoder) throws {
        // Try decoding as a simple string first
        if let container = try? decoder.singleValueContainer(),
           let path = try? container.decode(String.self) {
            self = .simple(path: path)
            return
        }

        // Otherwise, decode as an object
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // Check for youtube type
        if let typeString = try container.decodeIfPresent(String.self, forKey: .type),
           typeString == "youtube",
           let youtubeId = try container.decodeIfPresent(String.self, forKey: .id) {
            let caption = try container.decodeIfPresent(String.self, forKey: .caption)
            self = .youtube(id: youtubeId, caption: caption)
            return
        }

        // Check for map type
        if let typeString = try container.decodeIfPresent(String.self, forKey: .type),
           typeString == "map" {
            let place = try container.decodeIfPresent(String.self, forKey: .place)
            let lat = try container.decodeIfPresent(Double.self, forKey: .lat)
            let lng = try container.decodeIfPresent(Double.self, forKey: .lng)
            let src = try container.decodeIfPresent(String.self, forKey: .src)
            let caption = try container.decodeIfPresent(String.self, forKey: .caption)
            self = .map(place: place, lat: lat, lng: lng, src: src, caption: caption)
            return
        }

        // Standard detailed media
        let src = try container.decode(String.self, forKey: .src)
        let caption = try container.decodeIfPresent(String.self, forKey: .caption)
        let typeString = try container.decodeIfPresent(String.self, forKey: .type)
        let type = typeString.flatMap { MediaType(rawValue: $0) }
        self = .detailed(src: src, caption: caption, type: type)
    }

    func encode(to encoder: Encoder) throws {
        switch self {
        case .simple(let path):
            var container = encoder.singleValueContainer()
            try container.encode(path)

        case .detailed(let src, let caption, let type):
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(src, forKey: .src)
            try container.encodeIfPresent(caption, forKey: .caption)
            try container.encodeIfPresent(type?.rawValue, forKey: .type)

        case .youtube(let id, let caption):
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode("youtube", forKey: .type)
            try container.encode(id, forKey: .id)
            try container.encodeIfPresent(caption, forKey: .caption)

        case .map(let place, let lat, let lng, let src, let caption):
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode("map", forKey: .type)
            try container.encodeIfPresent(place, forKey: .place)
            try container.encodeIfPresent(lat, forKey: .lat)
            try container.encodeIfPresent(lng, forKey: .lng)
            try container.encodeIfPresent(src, forKey: .src)
            try container.encodeIfPresent(caption, forKey: .caption)
        }
    }

    /// Creates a detailed media item from a simple path, preserving the path
    func withCaption(_ caption: String?) -> EventMedia {
        switch self {
        case .simple(let path):
            if let caption = caption, !caption.isEmpty {
                return .detailed(src: path, caption: caption, type: nil)
            }
            return self
        case .detailed(let src, _, let type):
            return .detailed(src: src, caption: caption, type: type)
        case .youtube(let id, _):
            return .youtube(id: id, caption: caption)
        case .map(let place, let lat, let lng, let src, _):
            return .map(place: place, lat: lat, lng: lng, src: src, caption: caption)
        }
    }
}

/// The type of media
enum MediaType: String, Codable, Equatable {
    case image
    case video
    case youtube
    case map

    static func fromPath(_ path: String) -> MediaType {
        let lowercased = path.lowercased()
        if lowercased.hasSuffix(".mp4") || lowercased.hasSuffix(".webm") || lowercased.hasSuffix(".mov") {
            return .video
        }
        return .image
    }
}
