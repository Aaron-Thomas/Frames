import Foundation

public struct LoadedValue<Value> {
    public let value: Value
    public let loadedAt: Date

    public init(value: Value, loadedAt: Date) {
        self.value = value
        self.loadedAt = loadedAt
    }
}

extension LoadedValue: Sendable where Value: Sendable {}
extension LoadedValue: Equatable where Value: Equatable {}
extension LoadedValue: Codable where Value: Codable {}

public enum LoadState<Value> {
    case idle
    case loading(previous: LoadedValue<Value>?)
    case loaded(LoadedValue<Value>)
    case failed(LoadFailure, previous: LoadedValue<Value>?)

    public var isLoading: Bool {
        if case .loading = self { true } else { false }
    }

    public var failure: LoadFailure? {
        if case .failed(let failure, _) = self { failure } else { nil }
    }

    public var lastLoaded: LoadedValue<Value>? {
        switch self {
        case .idle:
            nil
        case .loading(let previous), .failed(_, let previous):
            previous
        case .loaded(let loadedValue):
            loadedValue
        }
    }

    public mutating func startLoading() {
        self = .loading(previous: lastLoaded)
    }

    public mutating func fail(with failure: LoadFailure) {
        self = .failed(failure, previous: lastLoaded)
    }

    public mutating func cancelLoading() {
        self = lastLoaded.map(LoadState.loaded) ?? .idle
    }
}

extension LoadState: Sendable where Value: Sendable {}
extension LoadState: Equatable where Value: Equatable {}
