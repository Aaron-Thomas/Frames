import Foundation

extension Error {
    public var isCancellation: Bool {
        self is CancellationError || (self as? URLError)?.code == .cancelled
    }
}
