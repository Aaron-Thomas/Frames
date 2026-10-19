import Testing
import FramesCore

@MainActor
struct RouterTests {
    private struct Presentation: Identifiable, Equatable {
        let id: Int
    }

    @Test func presentingSetsPresentation() {
        let router = Router<Presentation>()
        router.present(Presentation(id: 1))
        #expect(router.presented == Presentation(id: 1))
    }

    @Test func dismissingClearsPresentation() {
        let router = Router<Presentation>()
        router.present(Presentation(id: 1))
        router.dismiss()
        #expect(router.presented == nil)
    }
}
