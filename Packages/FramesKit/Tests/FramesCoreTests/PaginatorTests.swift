import Testing
import FramesCore

struct PaginatorTests {
    private struct Item: Identifiable, Equatable, Sendable {
        let id: Int
    }

    @Test func appendingAdvancesPage() {
        var paginator = Paginator<Item>()
        paginator.append([Item(id: 1), Item(id: 2)], hasMore: true)
        #expect(paginator.items.map(\.id) == [1, 2])
        #expect(paginator.nextPage == 2)
        #expect(paginator.hasMore)
    }

    @Test func repeatedItemsAreDropped() {
        var paginator = Paginator<Item>()
        paginator.append([Item(id: 1), Item(id: 2)], hasMore: true)
        paginator.append([Item(id: 2), Item(id: 3)], hasMore: true)
        #expect(paginator.items.map(\.id) == [1, 2, 3])
        #expect(paginator.index(of: 3) == 2)
    }

    @Test func lastPageStopsPaging() {
        var paginator = Paginator<Item>()
        paginator.append([Item(id: 1)], hasMore: false)
        #expect(!paginator.hasMore)
    }

    @Test func emptyPageStopsPaging() {
        var paginator = Paginator<Item>()
        paginator.append([], hasMore: true)
        #expect(!paginator.hasMore)
    }

    @Test func initialItemsAreIndexed() {
        let paginator = Paginator(items: [Item(id: 7), Item(id: 7), Item(id: 8)])
        #expect(paginator.items.map(\.id) == [7, 8])
        #expect(paginator.index(of: 8) == 1)
        #expect(paginator.nextPage == 1)
    }
}
