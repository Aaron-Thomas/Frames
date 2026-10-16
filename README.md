# Frames

An iOS gallery for Unsplash's Editorial feed and photo search. Photos load in an endless three-column grid, open full screen with a zoom transition and stay available offline once they've been seen.

The approach was planned before any code: [PLAN.md](PLAN.md) has the plan, [CLAUDE.md](CLAUDE.md) has the coding rules every change was reviewed against and [PERFORMANCE.md](PERFORMANCE.md) has the image pipeline's design and its Instruments measurements.

## Setup

1. Create an app at [unsplash.com/developers](https://unsplash.com/developers) and copy its **Access Key**.
2. Copy `Config/Secrets.example.xcconfig` to `Config/Secrets.xcconfig` and replace `your-access-key` with your key. `Secrets.xcconfig` is git-ignored, so the key never reaches the repository.
3. Open `Frames.xcodeproj`, choose the **Frames** scheme with an iPhone simulator on iOS 17 or later, then press **Run**.

Requirements: Xcode 26 and no third-party dependencies. Without a key the app shows a setup screen instead of failing requests. Every scenario below works with no key at all.

## Scenarios

Every state can be forced with a launch argument. In **Product › Scheme › Edit Scheme… › Run › Arguments**, tick one:

| Argument | What it shows |
|---|---|
| none | The live API. |
| `-scenario recorded` | Recorded API pages replayed endlessly. No key needed and no hourly limit, so it's the one for scrolling through thousands of photos and for profiling. Images still come from the CDN. |
| `-scenario slow` | Every page takes two seconds, to show the loading states. |
| `-scenario offline` | No network and nothing saved. |
| `-scenario offlineWithCache` | A saved feed with no network. Images come from the disk cache only, so run `recorded` first to fill it. |
| `-scenario rateLimited` | Two pages load, then the hourly limit is reached. |
| `-imagePipeline basic` | Turns the image pipeline's optimisations off, for comparison in Instruments. |

Each scenario uses its own temporary feed cache, so one run never affects the next.

## Tests

Press **Test** (⌘U) on the **Frames** scheme, or:

```bash
xcodebuild test -project Frames.xcodeproj -scheme Frames -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

- **Unit tests** use Swift Testing, one suite per module. Stubs record every call they receive and return results set up in advance, gates hold calls in flight and time is injected, so nothing sleeps and nothing touches the network.
- **A UI smoke test** runs the `recorded` scenario: it scrolls to the fourth page, opens and closes a photo, then searches.
- **A live contract test** decodes one real page from each endpoint and checks that every photo decoded. It runs only when your key is configured and costs two requests. The rest of the suite runs on recorded data; this is what catches the API changing underneath it.

## Architecture

```
Frames (app target)     composition root only: reads the key and launch arguments, builds dependencies
Packages/FramesKit
  FramesCore            LoadState, LoadFailure, Paginator, Router, HTTPClient. No UI.
  ImagePipeline         memory and disk caching, deduplication, cancellation, prefetching, decoding
  FramesCoreUI          shared views: RemoteImage, StatusBanner, PageFooter, the photo presentation modifier
  GalleryFeature        Photo model, Unsplash service, feed cache, view models, views, coordinator
  MockServices          recorded API pages and scenarios
  Tests/TestHelpers     stubs and builders, linked by tests only
```

Dependencies point one way: app → GalleryFeature → FramesCoreUI → ImagePipeline → FramesCore. The image pipeline knows nothing about photos, so another feature could use it unchanged. The same goes for the paginator, router and shared views.

**MVVM-C.** Views render state and send intents. `@MainActor @Observable` view models own state and logic. `GalleryCoordinator` creates the view models and owns navigation through a small generic `Router`. Every dependency is a protocol injected through `init`. Concrete types are chosen only in the composition root.

## Technical choices

- **SwiftUI throughout, with a `LazyVGrid`.** The brief asks for SwiftUI and judges unnecessary SwiftUI updates, so the grid stays in SwiftUI and the work goes into keeping it cheap: equatable cells, one width measurement and observation split so a loading spinner never redraws the grid. A `UICollectionView` would bring cell reuse and a prefetching data source, but at the cost of bridging code and a UIKit justification. The prefetch window gives the same benefit in a few lines.
- **An image pipeline built, not configured.** No library: memory cache, disk cache, deduplication, cancellation, prefetching and downsampled decoding are each a few lines. Building them is the point of the brief's bonus. [PERFORMANCE.md](PERFORMANCE.md) explains each one and measures them against a basic mode.
- **One feed view model for the Editorial feed and every search.** Both endpoints map to the same `PhotoPage`, so `PhotoFeedViewModel` takes a page loader closure and serves both. Search results get the same grid, endless scroll and states for free.
- **Seamless search.** The query is debounced by 400 ms through an injected `Clock` inside `.task(id:)`, so each keystroke cancels the last search with no extra code. The Editorial grid stays mounted underneath, so clearing a search returns to the same photos at the same scroll position.
- **iOS 18's zoom transition, with a cross-fade on iOS 17.** The zoom comes with interactive swipe down to dismiss. iOS 17 has no zoom transition, so it cross-fades. Both live in one modifier, the project's only version check.
- **Offline is a saved feed plus the disk cache.** The first five Editorial pages are saved as JSON in the Caches directory and shown at launch while the feed refreshes. JSON rather than SwiftData: the data is public, read whole and never queried. Images already seen come from the disk cache with no network.
- **Swift concurrency throughout** rather than Combine: async/await, structured tasks and `.task(id:)` cover debouncing, cancellation and paging with less code and no subscriptions to manage.
- **Every failure keeps what's on screen.** Remote data is a `LoadState` whose failure case keeps the last value, so a failed page never empties the grid. Rate limiting (HTTP 403 with no requests remaining), a rejected key, being offline and server errors each get their own message.
- **Spending requests carefully.** A demo key allows 50 requests an hour, so pages are 30 photos (the maximum), search is debounced and nothing retries on its own.

## Trade-offs and improvements

- **The key ships inside the app.** That's fine for a demo. In production the app would call our own backend, which would hold the key and could cache and rate limit for every user.
- **Grid images use Unsplash's fixed renditions.** Building exact-width URLs from `raw` with `w` and `dpr` would save more bytes on some devices.
- **The dominant colour is the placeholder.** BlurHash would look nicer, at the cost of a decoder.
- With more time: pinch to zoom and swiping between photos in the viewer, reloading automatically when the connection returns, snapshot tests, a full VoiceOver and Dynamic Type audit, localisation (the copy is already `LocalizedStringKey`) and recent searches.

## What changed from the plan

[PLAN.md](PLAN.md) is kept as it was written before the code. Building it changed a few details:

- **The pipeline is a `@MainActor` class rather than an actor.** Its bookkeeping is a few dictionary lookups. Keeping it on the main actor lets a cell read the memory cache synchronously, so a cached image never flashes its placeholder. Downloads and decodes still run off the main thread.
- **Prefetching moved into the pipeline.** One window, owned by the loader, replaced a prefetcher per feed. The basic loader simply ignores it, so no flag travels through the app.
- **The Editorial grid stays mounted under search results** instead of restoring its position with `scrollPosition(id:)`. It's simpler and can't drift, at the cost of keeping one screen of images in memory while searching.
- **The prefetch window follows the scroll direction**, so scrolling back up prefetches the rows above rather than ones already on screen.

## How I used AI

I set the approach before any code was written: the architecture, the module split, the image pipeline design, the scenarios and the rules in [CLAUDE.md](CLAUDE.md). Claude Code helped draft the plan and I edited it.

Claude Code then built the project step by step against the plan, running `/simplify` after each step and `/code-review` at the end. It verified every scenario on the simulator. I reviewed the code and did the Instruments profiling on a device myself.
