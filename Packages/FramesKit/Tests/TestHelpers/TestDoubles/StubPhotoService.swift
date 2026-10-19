import GalleryFeature

public actor StubPhotoService: PhotoService {
    public enum Invocation: Hashable, Sendable {
        case editorial(page: Int)
        case search(query: String, page: Int)
    }

    public struct NotStubbedError: Error {}

    private struct StubbedResult: Sendable {
        let result: Result<PhotoPage, any Error>
        let gate: Gate?
    }

    public private(set) var invocations: [Invocation] = []
    private var results: ArraySlice<StubbedResult> = []

    public init() {}

    public func stub(_ result: Result<PhotoPage, any Error>, until gate: Gate? = nil) {
        results.append(StubbedResult(result: result, gate: gate))
    }

    public func editorialPhotos(page: Int) async throws -> PhotoPage {
        invocations.append(.editorial(page: page))
        return try await resolveNext()
    }

    public func searchPhotos(matching query: String, page: Int) async throws -> PhotoPage {
        invocations.append(.search(query: query, page: page))
        return try await resolveNext()
    }

    private func resolveNext() async throws -> PhotoPage {
        guard let stubbed = results.popFirst() else { throw NotStubbedError() }
        await stubbed.gate?.wait()
        try Task.checkCancellation()
        return try stubbed.result.get()
    }
}
