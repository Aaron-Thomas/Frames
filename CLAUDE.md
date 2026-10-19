# Frames: an Unsplash gallery

Guidelines for anyone working in this repository, human or agent. Read this and `PLAN.md` before writing code. Every change is reviewed against them.

## What we're building

An iOS gallery for Unsplash's Editorial feed and photo search: an endless three-column grid, a full-screen viewer and an offline mode that shows what has already been loaded. Data comes from `GET /photos` and `GET /search/photos`. Images come from the Unsplash CDN, never from the app bundle.

### Constraints

- Keep the project small enough to walk through in three minutes. Never cut a rule or a feature to save lines.
- No third-party dependencies.
- Deployment target iOS 17.0. Swift 6 language mode with complete concurrency checking, checked at target level.
- SwiftUI only. `UIImage` is allowed as the decoded bitmap type.
- The Unsplash access key never appears in source control or in any document.
- No company names in code, comments or documents.

### Product rules

1. **Nothing heavy on the main thread.** Downloading, decoding and file I/O happen elsewhere.
2. **One load per image.** Callers asking for the same image at the same time share one request. An image already on disk never goes back to the network.
3. **A failure never empties the grid.** Photos already loaded stay on screen while the problem is explained.
4. **Never blank.** An item shows the photo's dominant colour until its image arrives. A screen with nothing to show says why.
5. **Spend API requests carefully.** Thirty photos per page, a debounced search and no automatic retries.
6. **Captions:** `alt_description`, then `description`, then "Untitled photo". Empty or blank strings count as missing.
7. **Use returned image URLs unchanged.** Pick the smallest rendition at least as wide as the view in pixels.
8. **Credit the photographer** in the viewer, as the Unsplash API guidelines ask.

## Architecture

### Modules

```
Frames (app target)     composition root only: reads the key and launch arguments, builds dependencies, shows the coordinator
FramesKit (local package)
  FramesCore            LoadState, LoadFailure, Paginator, Router, HTTPClient. No UI, no persistence.
  ImagePipeline         memory and disk caching, deduplication, cancellation, prefetching, decoding
  FramesCoreUI          shared views: RemoteImage, StatusBanner, PageFooter, photo presentation, pinch to zoom
  GalleryFeature        Photo model, Unsplash service, feed cache, view models, views, coordinator
  MockServices          stand-in backend: recorded API pages and scenarios
  TestHelpers           test doubles and builders, linked by test targets only
```

Dependencies point one way: app → GalleryFeature → FramesCoreUI → ImagePipeline → FramesCore. MockServices depends on GalleryFeature because it implements the feature's service protocol. GalleryFeature never depends on MockServices.

Mocks the running app uses live in MockServices. Test doubles live in TestHelpers and never ship in the app.

### MVVM-C

- **Views** render state and send intents. They hold no business logic and never know about other screens.
- **View models** own state and logic. They're `@MainActor @Observable final class`es.
- **The coordinator** owns navigation through a `Router`, creates screens and their view models and turns intents into navigation. Routes carry IDs, not models.
- **View models that hold state are created by the coordinator**, so re-renders never reset them.
- **Dependencies are injected**, never reached for. The image loader is the one dependency views read from the environment; its default loads nothing.

### Loading

- Remote data is a `LoadState<Value>`. Its non-idle cases carry the previous `LoadedValue`, so a failure can't wipe data.
- Views `switch` on state. A new case must be handled everywhere the compiler says.
- The feed cache sits behind the view model. Views never touch storage.

## Coding guidelines

### Naming and layout

- Descriptive names only. **No one-letter or abbreviated identifiers.** Use `$0` only in trivial one-line closures.
- A view model's view shares its name: `PhotoFeedViewModel` is shown by `PhotoFeedView`.
- A property, parameter or local that holds a view model is named `viewModel`, or `<role>ViewModel` when there is more than one: `editorialViewModel`, `searchViewModel`. Never a short noun such as `feed` or `gallery`.
- Views that make up a grid or list are items, never cells: `PhotoItem`, not `PhotoCell`.
- Plain words, not jargon: `captionBackground`, not `bottomScrim`.
- One main type per file, named after it. An extension used by more than one file lives in `Type+Purpose.swift`. A private helper used by one file stays in that file.
- Imports list Apple frameworks first, then the project's modules, each group in alphabetical order: `import SwiftUI` before `import FramesCore`.
- Every type is laid out in this order: static properties, variables, constants, computed properties, initialisers, then methods (internal before private). In a view, `body` and the private properties that build it follow the initialiser.
- Classes are `final`. Everything is `private` unless it needs to be wider. `public` is only for module boundaries.
- With four or more arguments, a call puts each argument on its own line. A declaration keeps its first parameter on the opening line and puts each further parameter on its own line, aligned under it. Three or fewer stay on one line unless it runs past 120 characters.

### Protocols and dependency injection

- **Prefer protocols at every boundary.** The photo service, the HTTP client, the image loader and the feed cache are protocols.
- **Time is injected.** Waiting goes through Swift's `Clock` protocol and the current date through a `now: () -> Date` closure.
- **Inject dependencies through `init`.** No singletons, no `static let shared` of our own and no default arguments that quietly reach for a live implementation.
- **Concrete types are chosen in one place:** the composition root in the app target.
- Test doubles conform to the same protocols as production code.

### State and async work

- Use `@Observable`. **Never `ObservableObject` or `@Published`.**
- Async work starts in `.task` or `.refreshable`, **never in `init` or `.onAppear`**. A view model may own a task it starts in response to an intent, such as loading the next page.
- Swift 6 strict concurrency. Domain types are `Sendable` value types. No `@unchecked Sendable` or `nonisolated(unsafe)`.
- Prefer Swift concurrency over locks, `DispatchQueue` or other manual synchronisation, in tests as well as app code.

### Errors

- **Catch cancellation first and handle it silently** (`error.isCancellation`). Cancellation is never shown as a failure.
- Never swallow any other error on a path that affects what the user sees.
- `try?` only where failure is harmless by design, such as a cache save.
- No force unwraps, `try!` or `fatalError` in app code.

### Performance

- Views read only what they render. Split a view when one part reads state another part doesn't need.
- Items are `Equatable` and take value types.
- No `GeometryReader` per item. Measure once at grid level.
- Decode images off the main thread at the size they're shown.
- Check new views with `Self._printChanges()` before calling them done, then remove the call.

### SwiftUI

- **Reuse, don't duplicate.** Anything used twice becomes a shared view in FramesCoreUI or a shared helper.
- Small views. When a body grows and a part isn't already its own view, move that part into a private property or method.
- System text styles only, so Dynamic Type works.
- Copy that depends on a model value lives in a `private extension` at the bottom of the view file as a computed `LocalizedStringKey`.
- Status is never shown by colour alone. Items are combined accessibility elements whose label is the caption.
- Animations are subtle, keyed to a value and honour Reduce Motion.
- Previews live in `*+Previews.swift` files and use the same scenarios as the app.

### Comments

Only for a constraint the code can't show. No comments that narrate what the next line does.

## Testing

- **Swift Testing only:** `@Test`, `#expect`, `#require`. XCTest only for UI tests.
- **Stubs record invocations and return stubbed results.** Assert on what was called as well as what was shown.
- One behaviour per test, named as the shortest statement of it: `emptyQueryShowsEditorialFeed`, not `whenTheQueryIsEmptyTheEditorialFeedShouldBeShown`.
- **Cover every state and failure path**, not just the happy path.
- No sleeps and no real time. Inject the clock and `now`. Gate stubbed calls when a test needs one in flight.
- View model tests run on `@MainActor`.
- The live contract test runs only when `UNSPLASH_ACCESS_KEY` is set.

## Scenarios

Every debug state is a named `Scenario`, selected with the `-scenario <name>` launch argument and listed in the shared scheme. With no scenario the app uses the live API.

- Each scenario keeps its feed cache in memory, so one run never affects the next.
- A new state is a new preset, not new plumbing.

## Workflow

- Plan non-trivial work before writing it (`/plan`).
- Run `/simplify` after each step and fix what it finds. Run `/code-review` before the work is committed.
- Tests must be green before every commit. Never squash.
- Verify every scenario on the simulator before writing docs.
- No em dashes in any document.
