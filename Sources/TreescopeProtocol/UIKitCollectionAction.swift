import Foundation

public enum UIKitCollectionScrollPosition: String, Codable, Hashable, Sendable {
    case top
    case centeredVertically
    case bottom
    case left
    case centeredHorizontally
    case right
}

public enum UIKitCollectionAction: Hashable, Sendable {
    case query(identifier: String)
    case scroll(identifier: String, section: Int, item: Int, position: UIKitCollectionScrollPosition)
}

public struct UIKitCollectionItem: Codable, Hashable, Sendable {
    public var section: Int
    public var item: Int

    public init(section: Int, item: Int) {
        self.section = section
        self.item = item
    }
}

public struct UIKitCollectionActionResult: Codable, Hashable, Sendable {
    public var status: String
    public var identifier: String
    public var section: Int?
    public var item: Int?
    public var sectionCount: Int?
    public var itemCount: Int?
    public var visibleItems: [UIKitCollectionItem]
    public var contentOffset: Point?
    public var contentSize: Size?
    public var visibleCollectionIdentifiers: [String]
    public var message: String?

    public init(status: String,
                identifier: String,
                section: Int? = nil,
                item: Int? = nil,
                sectionCount: Int? = nil,
                itemCount: Int? = nil,
                visibleItems: [UIKitCollectionItem] = [],
                contentOffset: Point? = nil,
                contentSize: Size? = nil,
                visibleCollectionIdentifiers: [String] = [],
                message: String? = nil) {
        self.status = status
        self.identifier = identifier
        self.section = section
        self.item = item
        self.sectionCount = sectionCount
        self.itemCount = itemCount
        self.visibleItems = visibleItems
        self.contentOffset = contentOffset
        self.contentSize = contentSize
        self.visibleCollectionIdentifiers = visibleCollectionIdentifiers
        self.message = message
    }
}

extension UIKitCollectionAction: Codable {
    private enum CodingKeys: String, CodingKey {
        case t, identifier, section, item, position
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .query(let identifier):
            try c.encode("query", forKey: .t)
            try c.encode(identifier, forKey: .identifier)
        case .scroll(let identifier, let section, let item, let position):
            try c.encode("scroll", forKey: .t)
            try c.encode(identifier, forKey: .identifier)
            try c.encode(section, forKey: .section)
            try c.encode(item, forKey: .item)
            try c.encode(position, forKey: .position)
        }
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        switch try c.decode(String.self, forKey: .t) {
        case "query":
            self = .query(identifier: try c.decode(String.self, forKey: .identifier))
        case "scroll":
            self = .scroll(identifier: try c.decode(String.self, forKey: .identifier),
                           section: try c.decode(Int.self, forKey: .section),
                           item: try c.decode(Int.self, forKey: .item),
                           position: try c.decode(UIKitCollectionScrollPosition.self, forKey: .position))
        case let other:
            throw DecodingError.dataCorruptedError(forKey: .t, in: c, debugDescription: "unknown UIKitCollectionAction \(other)")
        }
    }
}
