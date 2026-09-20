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

    // Explicit init instead of relying on the synthesized memberwise one: `zoom`/`pinchDelta`
    // below are `private`, and a struct's auto-generated memberwise initializer is only as
    // accessible as its LEAST-accessible stored property — with a private stored property that
    // makes the synthesized init private too, i.e. only callable from within this same file.
    // That was invisible while this type itself was private to VillageMapView.swift (its only
    // call site was already in the same file); now that WorldMapView.swift also constructs one,
    // it needs a real init that only exposes `content`/`minZoom`/`maxZoom` as parameters.
    init(minZoom: CGFloat = 1, maxZoom: CGFloat = 3, @ViewBuilder content: @escaping () -> Content) {
        self.minZoom = minZoom
        self.maxZoom = maxZoom
        self.content = content
    }

    @State private var zoom: CGFloat = 1
    @State private var pinchDelta: CGFloat = 1

    var body: some View {
        GeometryReader { outer in
            // Fills whatever space the parent offers (the whole screen minus the nav bar and
            // bottom dock, per "карту на весь экран") instead of aspect-locking to some fixed
            // ratio — callers size their own content to this same real size (see VillageMapView's
            // mapCanvas / WorldMapView's own canvas, both using a GeometryReader inside `content`
            // to read it back), so nothing needs a hardcoded aspect ratio here.
            let baseWidth = outer.size.width
            let baseHeight = outer.size.height
            let effectiveZoom = max(minZoom, min(maxZoom, zoom * pinchDelta))

            ScrollView([.horizontal, .vertical], showsIndicators: false) {
                content()
                    .frame(width: baseWidth * effectiveZoom, height: baseHeight * effectiveZoom)
            }
            .frame(width: baseWidth, height: baseHeight)
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
