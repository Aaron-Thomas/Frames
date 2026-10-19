# Frames: plan

Frames is an iOS gallery for Unsplash's Editorial feed and photo search. It shows photos in an endless grid, opens any photo full screen and keeps working offline with what it has already loaded.

This plan sets out what will be built, the rules it's built to and the order of the work. It was written before any code. The design as built, with its trade-offs and Instruments measurements, is in [README.md](README.md). The coding and testing rules every change is reviewed against are in [CLAUDE.md](CLAUDE.md).

**Principle: smooth first.** Never make the main thread wait, never load the same thing twice and never show a blank screen when there's something useful to show.

## Rules

1. **Nothing heavy on the main thread.** Downloading, decoding and file I/O happen elsewhere.
2. **One load per image.** Callers asking for the same image at the same time share one request. An image already on disk never goes back to the network.
3. **A failure never empties the grid.** Photos already loaded stay on screen while the problem is explained.
4. **Never blank.** An item shows the photo's dominant colour until its image arrives. A screen with nothing to show says why.
5. **Spend API requests carefully.** A demo key gets 50 requests an hour, so pages are as large as allowed, search is debounced and nothing retries on its own.

## What the brief asks for

| Brief | How Frames meets it |
|---|---|
| A grid of 2 or 3 columns | Three columns, or two at accessibility text sizes so captions stay readable. |
| Image and a short description per item | `alt_description`, then `description`, then "Untitled photo". Empty strings count as missing. |
| An endless feed | The next page starts loading when a photo in the last four rows appears. |
| Smooth scrolling | Decoding off the main thread, prefetching ahead of the scroll, a colour placeholder and equatable items. |
| Full screen on tap and a beautiful way back | iOS 18's zoom transition from the tapped item with swipe down to dismiss. A cross-fade on iOS 17. Pinch to zoom in the viewer. |
| Search with the same grid and endless scroll | The same grid and the same feed view model, given a different page loader. |
| A seamless switch between feed and search | Search as you type (debounced) and a cross-fade between grids. The feed keeps its photos and scroll position. |
| The right image size for each context | The smallest Unsplash rendition at least as wide as the view in pixels. Returned URLs are used unchanged. |
| The access key is never committed | A git-ignored `Secrets.xcconfig`. A setup screen if it's missing. |
| Bonus: an advanced image pipeline | Built, not configured: memory and disk caching, deduplication, cancellation, prefetching and downsampled decoding. Measured in Instruments through signposts that count the work it saves. |
| Bonus: tests | Swift Testing for every module, a UI smoke test, a UI scroll test for profiling and an opt-in live contract test. |
| Bonus: offline mode | The saved feed plus disk-cached images, under one status banner. |
| Bonus: animations | The zoom transition, image fade-ins and grid cross-fades, all honouring Reduce Motion. |

## Constraints

- Xcode 26, deployment target iOS 17.0, Swift 6 language mode with complete concurrency checking. Xcode's app template leaves targets on Swift 5, so this is checked at target level.
- SwiftUI throughout, with no UIKit views. `UIImage` is used only as the decoded bitmap type.
- No third-party dependencies. The image pipeline is the heart of the bonus, so it's built rather than taken from a library.
- A project small enough to walk through in three minutes. A requirement or bonus is never cut to save lines.

## Design

The README describes the design as it was built:

- [Architecture](README.md#architecture): the module split, its one-way dependencies and MVVM-C.
- [Image pipeline and performance](README.md#image-pipeline-and-performance): the pipeline's diagram and design, how SwiftUI updates are kept cheap, the signposts and the Instruments results.
- [Technical choices](README.md#technical-choices) and [trade-offs](README.md#trade-offs): search, full screen, offline, errors and the access key.
- [Scenarios](README.md#scenarios) and [tests](README.md#tests): every debug state and how each layer is tested.

## Build order

Each step is a commit with green tests. `/simplify` and `/code-review` run on each major step before it's committed.

1. Xcode project (iOS 17, Swift 6 at target level), `CLAUDE.md`, this plan, `.gitignore` and the secrets config.
2. FramesKit with its modules and test targets.
3. FramesCore: `LoadState`, `LoadFailure`, `Paginator`, `Router` and `HTTPClient`.
4. The `Photo` model with lenient decoding, captions and renditions. `PhotoService` and `UnsplashPhotoService`. Recorded API pages.
5. MockServices and the scenarios.
6. ImagePipeline in three commits: caching with decoding, then deduplication and cancellation, then prefetching and signposts.
7. The feed: `PhotoFeedViewModel`, `PhotoFeedView`, `PhotoItem`, `RemoteImage`, the page footer and the key setup screen.
8. Search.
9. The full-screen viewer and its transitions.
10. Offline: the saved feed and the status banner.
11. The UI smoke test and the live contract test.
12. Profiling on a device and the README's image pipeline section.
13. A final pass: every scenario on iPhone, iPad and at a large text size, then the README, screenshots and the Loom.

Roughly: steps 1 to 7 on day one, 8 to 11 on day two, then profiling, polish and documents on day three.

## Deliverables

- The source on GitHub with its full commit history.
- `README.md` covers setup with the key, how to run and test, the scenarios, technical choices with their reasons, trade-offs, improvements and how AI was used. One section holds everything about the image pipeline: a diagram, its design and the Instruments results.
- `CLAUDE.md` and this plan, both written before the code and kept up to date with it.
- A Loom of three minutes at most. It shows the app working (feed, endless scroll, search, full screen and offline). It then walks through the module graph and the pipeline in code, the Instruments numbers, assumptions, limits and how AI was used.

## Assumptions

- The Editorial feed is `GET /photos`, newest first.
- English copy only.
- A page size of 30 for both endpoints.
- A demo key's 50 requests an hour is the budget for a whole review session, which is why nothing retries on its own and nothing is fetched twice.
