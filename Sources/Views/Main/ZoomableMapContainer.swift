import SwiftUI

/// Simple pinch-to-zoom + native pan (via a nested ScrollView, so panning "just works" once
/// zoomed instead of needing a hand-rolled drag gesture) — native equivalent of
/// Components/ZoomableMap.vue. Originally private to VillageMapView.swift; pulled out into its
/// own file so WorldMapView can share the exact same pinch/pan behaviour instead of the world
/// map's old static button-grid-in-a-ScrollView (no zoom, no free pan) — see WorldMapView's own
/// doc comment for why that changed.
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

    // Explicit init instead of relying on the synthesized memberwise one: `zoom`/`pinchDelta`
    // below are `private`, and a struct's auto-generated memberwise initializer is only as
    // accessible as its LEAST-accessible stored property — with a private stored property that
    // makes the synthesized init private too, i.e. only callable from within this same file.
    // That was invisible while this type itself was private to VillageMapView.swift (its only
    // call site was already in the same file); now that WorldMapView.swift also constructs one,
    // it needs a real init that only exposes its non-private parameters.
    init(minZoom: CGFloat = 1, maxZoom: CGFloat = 3, contentAspect: CGFloat? = nil, @ViewBuilder content: @escaping () -> Content) {
        self.minZoom = minZoom
        self.maxZoom = maxZoom
        self.contentAspect = contentAspect
        self.content = content
    }

    @State private var zoom: CGFloat = 1
    @State private var pinchDelta: CGFloat = 1

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
            let baseWidth = base.width
            let baseHeight = base.height
            let effectiveZoom = max(minZoom, min(maxZoom, zoom * pinchDelta))

            ScrollView([.horizontal, .vertical], showsIndicators: false) {
                content()
                    .frame(width: baseWidth * effectiveZoom, height: baseHeight * effectiveZoom)
            }
            .frame(width: outer.size.width, height: outer.size.height)
            .simultaneousGesture(
                MagnificationGesture()
                    .onChanged { value in pinchDelta = value }
                    .onEnded { value in
                        zoom = max(minZoom, min(maxZoom, zoom * value))
                        pinchDelta = 1
                    }
            )
        }
    }
}
