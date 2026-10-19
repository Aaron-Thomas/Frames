import SwiftUI

extension View {
    /// Pinch to zoom, then drag to pan while zoomed. Panning is off at full size,
    /// so taps and the presentation's swipe-down dismiss keep working.
    public func pinchToZoom(maximumScale: CGFloat = 4) -> some View {
        modifier(PinchToZoom(maximumScale: maximumScale))
    }
}

private struct PinchToZoom: ViewModifier {
    @State private var scale: CGFloat = 1
    @State private var scaleAtGestureStart: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var offsetAtGestureStart: CGSize = .zero
    let maximumScale: CGFloat

    func body(content: Content) -> some View {
        GeometryReader { proxy in
            content
                .scaleEffect(scale)
                .offset(offset)
                .frame(width: proxy.size.width, height: proxy.size.height)
                .contentShape(.rect)
                .gesture(magnify(in: proxy.size))
                .simultaneousGesture(pan(in: proxy.size), including: scale > 1 ? .all : .subviews)
        }
    }

    private func magnify(in size: CGSize) -> some Gesture {
        MagnifyGesture()
            .onChanged { value in
                scale = min(max(scaleAtGestureStart * value.magnification, 1), maximumScale)
                offset = clamped(offset, in: size)
            }
            .onEnded { _ in
                scaleAtGestureStart = scale
                offsetAtGestureStart = offset
            }
    }

    private func pan(in size: CGSize) -> some Gesture {
        DragGesture()
            .onChanged { value in
                let proposed = CGSize(
                    width: offsetAtGestureStart.width + value.translation.width,
                    height: offsetAtGestureStart.height + value.translation.height
                )
                offset = clamped(proposed, in: size)
            }
            .onEnded { _ in offsetAtGestureStart = offset }
    }

    /// Keeps the zoomed content covering its original frame, so no empty edge can be dragged into view.
    private func clamped(_ proposed: CGSize, in size: CGSize) -> CGSize {
        let horizontalLimit = size.width * (scale - 1) / 2
        let verticalLimit = size.height * (scale - 1) / 2
        return CGSize(
            width: min(max(proposed.width, -horizontalLimit), horizontalLimit),
            height: min(max(proposed.height, -verticalLimit), verticalLimit)
        )
    }
}
