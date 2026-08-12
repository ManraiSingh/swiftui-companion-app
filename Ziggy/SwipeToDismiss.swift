import SwiftUI

/// Left-edge swipe to go back, the way a pushed screen behaves.
///
/// These screens are presented with `.fullScreenCover`, which has no gesture
/// of its own, so this adds one.
///
/// The gesture lives on a narrow strip pinned to the left edge — it is not
/// attached to the screen as a whole. That distinction matters more than it
/// looks. It used to sit on the whole view and merely *check* in its handler
/// that the drag began near the edge, but a recogniser covering the screen is
/// armed over the drawing canvas too, and once a drag passes its threshold it
/// can claim the touch before PencilKit sees it. Which one wins is a race, so
/// it worked on some phones and left others unable to draw at all. Confining
/// the strip means it cannot compete for a touch it was never meant to get.
struct SwipeToDismiss: ViewModifier {

    @Environment(\.dismiss) private var dismiss

    @State private var offset: CGFloat = 0

    /// Kept just inside the drawing surfaces. Both the Doodle canvas and the
    /// trace board sit 16pt from the screen edge, so arming any wider than
    /// that would let a stroke started on the canvas border pull the screen
    /// away instead of drawing. A real edge swipe starts within a few points
    /// of the bezel anyway, so this loses nothing in practice.
    private let edgeWidth: CGFloat = 12

    /// How far you have to pull before letting go counts as "go back".
    private let dismissDistance: CGFloat = 90

    /// The screen follows your finger, but only so far — enough to feel
    /// live without dragging the whole layout across the display.
    private let maxPeek: CGFloat = 120

    private func startedAtEdge(_ value: DragGesture.Value) -> Bool {
        value.startLocation.x <= edgeWidth
    }

    func body(content: Content) -> some View {
        content
            .offset(x: offset)
            .animation(.interactiveSpring(response: 0.3, dampingFraction: 0.85), value: offset)
            .overlay(alignment: .leading) {
                // The only place the gesture exists. Nothing interactive sits
                // in this sliver, and a real edge swipe starts within a few
                // points of the bezel anyway.
                Color.clear
                    .frame(width: edgeWidth)
                    .contentShape(Rectangle())
                    .gesture(edgeDrag)
                    .ignoresSafeArea()
            }
    }

    private var edgeDrag: some Gesture {
        DragGesture(minimumDistance: 12, coordinateSpace: .global)
            .onChanged { value in
                guard startedAtEdge(value) else { return }
                // Rightward, and more sideways than up/down, so a
                // scroll never gets mistaken for a back swipe.
                guard value.translation.width > 0,
                      abs(value.translation.width) > abs(value.translation.height)
                else { return }

                offset = min(value.translation.width, maxPeek)
            }
            .onEnded { value in
                guard startedAtEdge(value) else { return }

                let pulledFarEnough = value.translation.width > dismissDistance
                let flickedHard = value.predictedEndTranslation.width > 220

                if pulledFarEnough || flickedHard {
                    dismiss()
                }

                offset = 0
            }
    }
}

extension View {
    /// Adds left-edge swipe-to-go-back to a full-screen presented view.
    func swipeToDismiss() -> some View {
        modifier(SwipeToDismiss())
    }
}
