public actor RecordingClock: Clock {
    public private(set) var sleeps: [Duration] = []
    public let now = ContinuousClock.now
    public let minimumResolution = Duration.zero

    public init() {}

    public func sleep(until deadline: ContinuousClock.Instant, tolerance: Duration?) async throws {
        try Task.checkCancellation()
        sleeps.append(now.duration(to: deadline))
    }
}
