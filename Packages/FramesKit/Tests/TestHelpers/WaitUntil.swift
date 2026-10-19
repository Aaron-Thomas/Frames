/// Yields until the condition holds, so a test never depends on real time. The budget is generous because
/// some conditions wait on work running on other threads, which a busy machine can slow down.
@MainActor
@discardableResult
public func waitUntil(_ condition: () async -> Bool) async -> Bool {
    var remainingYields = 100_000
    while await !condition(), remainingYields > 0 {
        remainingYields -= 1
        await Task.yield()
    }
    return await condition()
}
