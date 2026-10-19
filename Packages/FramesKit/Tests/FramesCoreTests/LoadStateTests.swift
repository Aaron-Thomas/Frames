import Foundation
import Testing
import FramesCore

struct LoadStateTests {
    private let loaded = LoadedValue(value: 1, loadedAt: Date(timeIntervalSince1970: 0))

    @Test func loadingKeepsPreviousValue() {
        var state = LoadState.loaded(loaded)
        state.startLoading()
        #expect(state == .loading(previous: loaded))
        #expect(state.isLoading)
    }

    @Test func failureKeepsPreviousValue() {
        var state = LoadState.loaded(loaded)
        state.startLoading()
        state.fail(with: .offline)
        #expect(state == .failed(.offline, previous: loaded))
        #expect(state.failure == .offline)
    }

    @Test func cancellingRestoresPreviousValue() {
        var state = LoadState.loaded(loaded)
        state.startLoading()
        state.cancelLoading()
        #expect(state == .loaded(loaded))
    }

    @Test func cancellingWithNothingLoadedReturnsToIdle() {
        var state = LoadState<Int>.idle
        state.startLoading()
        state.cancelLoading()
        #expect(state == .idle)
    }

    @Test func cancellationErrorsAreRecognised() {
        #expect(CancellationError().isCancellation)
        #expect(URLError(.cancelled).isCancellation)
        #expect(!URLError(.notConnectedToInternet).isCancellation)
    }
}
