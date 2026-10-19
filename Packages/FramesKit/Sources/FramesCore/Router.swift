import Observation

@MainActor
@Observable
public final class Router<Presentation: Identifiable> {
    public var presented: Presentation?

    public init() {}

    public func present(_ presentation: Presentation) {
        presented = presentation
    }

    public func dismiss() {
        presented = nil
    }
}
