public struct Paginator<Item: Identifiable & Sendable>: Sendable where Item.ID: Sendable {
    public private(set) var items: [Item] = []
    public private(set) var nextPage = 1
    public private(set) var hasMore = true
    private var indexByID: [Item.ID: Int] = [:]

    public init(items: [Item] = []) {
        appendUnseen(items)
    }

    public func index(of id: Item.ID) -> Int? {
        indexByID[id]
    }

    public mutating func append(_ page: [Item], hasMore: Bool) {
        appendUnseen(page)
        nextPage += 1
        self.hasMore = hasMore && !page.isEmpty
    }

    private mutating func appendUnseen(_ newItems: [Item]) {
        for item in newItems where indexByID[item.id] == nil {
            indexByID[item.id] = items.count
            items.append(item)
        }
    }
}

extension Paginator: Equatable where Item: Equatable {}
