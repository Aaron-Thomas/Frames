import SwiftUI

extension View {
    @ViewBuilder
    public func photoTransitionSource(id: some Hashable, in namespace: Namespace.ID) -> some View {
        if #available(iOS 18, *) {
            matchedTransitionSource(id: id, in: namespace)
        } else {
            self
        }
    }

    /// Zooms from the tapped item on iOS 18 and later. iOS 17 has no zoom transition, so it cross-fades instead.
    @ViewBuilder
    public func photoPresentation<Item, Content>(item: Binding<Item?>,
                                                 in namespace: Namespace.ID,
                                                 @ViewBuilder content: @escaping (Item) -> Content) -> some View
    where Item: Identifiable, Content: View {
        if #available(iOS 18, *) {
            fullScreenCover(item: item) { presented in
                content(presented)
                    .navigationTransition(.zoom(sourceID: presented.id, in: namespace))
            }
        } else {
            overlay {
                if let presented = item.wrappedValue {
                    content(presented)
                        .accessibilityAddTraits(.isModal)
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.25), value: item.wrappedValue?.id)
        }
    }
}
