public actor Gate {
    private var isOpen = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    public init() {}

    public func wait() async {
        guard !isOpen else { return }
        await withCheckedContinuation { continuation in waiters.append(continuation) }
    }

    public func open() {
        isOpen = true
        waiters.forEach { waiter in waiter.resume() }
        waiters.removeAll()
    }
}
