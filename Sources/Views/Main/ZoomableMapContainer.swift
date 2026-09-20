import SwiftUI
import UIKit

/// Pinch-to-zoom + pan container — native equivalent of Components/ZoomableMap.vue. Originally
/// private to VillageMapView.swift; pulled out into its own file so WorldMapView can share the
/// exact same pinch/pan behaviour instead of the world map's old static button-grid-in-a-
/// ScrollView (no zoom, no free pan) — see WorldMapView's own doc comment for why that changed.
///
/// Was implemented with a plain SwiftUI `ScrollView` + `MagnificationGesture`, which has no
/// notion of a pinch ANCHOR — only a scalar zoom delta (`value`), with no `.location`. Growing
/// the content's `.frame(width:height:)` unconditionally re-lays it out from the ScrollView's own
/// top-left content origin, so any point that wasn't already at that origin visually slides
/// toward it as the frame grows — reported as: "зум карты города поправить правильно увеличение,
/// сейчас если на карте в средине, начиная увеличивать карта сдвигается к верхнему правому углу".
/// (iOS 17's `MagnifyGesture` DOES expose `.location`/`.startLocation`, but project.yml pins
/// `deploymentTarget.iOS` to "16.0", ruling that API out.)
///
/// Fixed by dropping the hand-rolled gesture entirely and hosting the content inside a real
/// `UIScrollView`, whose pinch-to-zoom has always been anchor-preserving natively (the same
/// `UIPinchGestureRecognizer` → `zoomScale` → `viewForZooming` delegate machinery Photos/Maps/
/// Safari use) — instead of reimplementing that anchor math by hand.
struct ZoomableMapContainer<Content: View>: View {
    let content: () -> Content
    let minZoom: CGFloat
    let maxZoom: CGFloat
    // Content's own natural width/height ratio (e.g. VillageLayout's viewboxWidth/viewboxHeight)
    // — nil keeps the old behaviour of stretching content to exactly fill the container on both
    // axes at zoom 1 (WorldMapView's flat tile grid has no "natural" aspect to preserve; any
    // container size is equally valid for it).
    //
    // When given, the content is instead scaled to FIT THE CONTAINER'S HEIGHT while keeping this
    // aspect ratio — mirroring Components/ZoomableMap.vue's own camera math (`scale = boxH /
    // WORLD_H`, see its comment). On a portrait phone showing a village map that's wider than it
    // is tall, fitting to height makes the rendered map WIDER than the screen even at zoom 1, so
    // it's pannable left/right immediately — without this, content exactly matched the
    // container's own (portrait) box on both axes with nothing left to pan to, which is what
    // made the village map read as "cropped to the screen, doesn't scroll" (the reported bug).
    var contentAspect: CGFloat?

    init(minZoom: CGFloat = 1, maxZoom: CGFloat = 3, contentAspect: CGFloat? = nil, @ViewBuilder content: @escaping () -> Content) {
        self.minZoom = minZoom
        self.maxZoom = maxZoom
        self.contentAspect = contentAspect
        self.content = content
    }

    // Pulled out of `body` on purpose: a plain `if/else` with assignment statements (as this used
    // to be, inline inside GeometryReader's trailing closure) gets parsed as SwiftUI's
    // @ViewBuilder DSL there, not as ordinary Swift — each branch's assignment is a `Void`-typed
    // statement, and the builder tries (and fails) to turn it into a View ("type '()' cannot
    // conform to 'View'"). A regular function outside any @ViewBuilder context has no such
    // restriction, so the same branching compiles fine here and is called as a single expression
    // (a `let` with a function-call initializer) from inside the closure.
    private func baseSize(for outerSize: CGSize) -> (width: CGFloat, height: CGFloat) {
        if let contentAspect, contentAspect > 0 {
            let height = outerSize.height
            return (height * contentAspect, height)
        }
        return (outerSize.width, outerSize.height)
    }

    var body: some View {
        GeometryReader { outer in
            let base = baseSize(for: outer.size)
            // `base` is the content's size AT ZOOM 1 — UIScrollView's own zoomScale (minZoom...
            // maxZoom) handles everything beyond that natively; unlike the old code, nothing here
            // multiplies this by a live zoom value.
            PinchZoomScrollView(minZoom: minZoom, maxZoom: maxZoom, contentSize: CGSize(width: base.width, height: base.height), content: content)
                .frame(width: outer.size.width, height: outer.size.height)
        }
    }
}

/// UIScrollView-backed host for a fixed-size SwiftUI subtree, giving it native anchor-preserving
/// pinch-zoom and free panning. See ZoomableMapContainer's own doc comment for why this replaced
/// a hand-rolled MagnificationGesture.
private struct PinchZoomScrollView<Content: View>: UIViewRepresentable {
    let minZoom: CGFloat
    let maxZoom: CGFloat
    let contentSize: CGSize
    let content: () -> Content

    func makeCoordinator() -> Coordinator {
        Coordinator(rootView: content())
    }

    func makeUIView(context: Context) -> UIScrollView {
        let scrollView = UIScrollView()
        scrollView.delegate = context.coordinator
        scrollView.minimumZoomScale = minZoom
        scrollView.maximumZoomScale = maxZoom
        scrollView.zoomScale = minZoom
        scrollView.bouncesZoom = true
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.backgroundColor = .clear
        // Default is `.automatic`, which has UIKit silently pad the scroll view's content with
        // extra insets derived from ITS OWN safeAreaInsets whenever it thinks part of itself
        // overlaps the unsafe area (notch/home indicator). This view is already confined well
        // below GameHeaderBar and above the bottom dock via SwiftUI's `.safeAreaInset` (a
        // SwiftUI-only mechanism UIKit has no visibility into), so there's nothing for this
        // auto-adjustment to correctly compensate for — at best it's a no-op, at worst it's an
        // extra, invisible-from-here offset UIKit adds on its own that the old pure-SwiftUI
        // ScrollView this replaced could never have introduced. Explicitly opting out removes
        // that whole class of "map content quietly shifts near the header/footer" risk (see
        // VillageMapView's/WorldMapView's own map-vs-header/footer layering notes).
        scrollView.contentInsetAdjustmentBehavior = .never

        let hostedView = context.coordinator.hostingController.view!
        hostedView.backgroundColor = .clear
        hostedView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(hostedView)

        let widthConstraint = hostedView.widthAnchor.constraint(equalToConstant: contentSize.width)
        let heightConstraint = hostedView.heightAnchor.constraint(equalToConstant: contentSize.height)
        NSLayoutConstraint.activate([
            hostedView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            hostedView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            hostedView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            hostedView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            widthConstraint,
            heightConstraint,
        ])
        context.coordinator.widthConstraint = widthConstraint
        context.coordinator.heightConstraint = heightConstraint
        context.coordinator.lastContentSize = contentSize

        return scrollView
    }

    func updateUIView(_ scrollView: UIScrollView, context: Context) {
        // Refresh the hosted SwiftUI content with whatever this render pass produced (village
        // queue timers ticking down, resource counts changing, etc.) without touching the
        // scroll view's own zoom/pan state.
        context.coordinator.hostingController.rootView = content()

        if scrollView.minimumZoomScale != minZoom { scrollView.minimumZoomScale = minZoom }
        if scrollView.maximumZoomScale != maxZoom { scrollView.maximumZoomScale = maxZoom }

        if context.coordinator.lastContentSize != contentSize {
            context.coordinator.lastContentSize = contentSize
            context.coordinator.widthConstraint?.constant = contentSize.width
            context.coordinator.heightConstraint?.constant = contentSize.height
        }
    }

    final class Coordinator: NSObject, UIScrollViewDelegate {
        let hostingController: UIHostingController<Content>
        var widthConstraint: NSLayoutConstraint?
        var heightConstraint: NSLayoutConstraint?
        var lastContentSize: CGSize = .zero

        init(rootView: Content) {
            hostingController = UIHostingController(rootView: rootView)
            hostingController.view.backgroundColor = .clear
            super.init()
        }

        func viewForZooming(in scrollView: UIScrollView) -> UIView? {
            hostingController.view
        }
    }
}
