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
///
/// `overlay` — NEW: любой SwiftUI-контент, который должен ВСЕГДА висеть поверх карты и НЕ
/// зумиться/панорамироваться вместе с ней (название деревни, бейдж уровня, кнопки HUD и т.п.).
/// Рендерится в отдельном слое ZStack НАД PinchZoomScrollView, поэтому жесты UIScrollView его
/// не касаются, и его размер/положение на экране остаются неизменными при любом zoomScale.
/// Если overlay не передан — поведение контейнера остаётся ровно таким же, как раньше.
struct ZoomableMapContainer<Content: View, Overlay: View>: View {
    let content: () -> Content
    let overlay: () -> Overlay
    let minZoom: CGFloat
    let maxZoom: CGFloat
    var contentAspect: CGFloat?
    var initialCenterFraction: CGPoint?

    // ИЗМЕНЕНО: minZoom теперь 1.0 — карта открывается ровно по размеру картинки и НЕ может
    // быть уменьшена меньше этого значения. maxZoom 2.0 — максимальное увеличение ровно х2.
    init(
        minZoom: CGFloat = 1.0,
        maxZoom: CGFloat = 2.0,
        contentAspect: CGFloat? = nil,
        initialCenterFraction: CGPoint? = nil,
        @ViewBuilder content: @escaping () -> Content,
        @ViewBuilder overlay: @escaping () -> Overlay
    ) {
        self.minZoom = minZoom
        self.maxZoom = maxZoom
        self.contentAspect = contentAspect
        self.initialCenterFraction = initialCenterFraction
        self.content = content
        self.overlay = overlay
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
            // "карта тоже скрывается под хедером и футером" — GeometryReader reports its FULL
            // proposed size in `.size` regardless of any ancestor `.safeAreaInset` (MainTabView
            // reserves GameHeaderBar/bottomDock that way); it only tells you about that reserved
            // space separately, via `.safeAreaInsets`, and leaves subtracting it up to you. The
            // previous round's fixes (contentInsetAdjustmentBehavior, scrollViewDidZoom offset
            // clamping) both assumed this view was "already confined below the header / above
            // the dock" and only ever touched pan/zoom offset — never this root sizing — so the
            // map's actual viewport (and everything positioned inside it, incl. the village name
            // plate) kept being sized to the FULL screen and rendering straight under both bars
            // even at rest. Subtracting the insets here is safe even if some future SwiftUI
            // version DOES pre-shrink `.size` — insets would just read as ~0 and this is a no-op.
            let safeSize = CGSize(
                width: max(0, outer.size.width - outer.safeAreaInsets.leading - outer.safeAreaInsets.trailing),
                height: max(0, outer.size.height - outer.safeAreaInsets.top - outer.safeAreaInsets.bottom)
            )
            let base = baseSize(for: safeSize)

            // ZStack:
            //   слой 0 (снизу) — UIScrollView с картой (зумится + панорамируется);
            //   слой 1 (сверху) — overlay (название деревни и прочий фиксированный HUD).
            // Overlay находится ВНЕ PinchZoomScrollView, поэтому:
            //   • жесты pinch/pan его не трогают;
            //   • его размер и позиция на экране неизменны при любом zoomScale.
            ZStack {
                // `base` is the content's size AT ZOOM 1 — UIScrollView's own zoomScale (minZoom...
                // maxZoom) handles everything beyond that natively; unlike the old code, nothing
                // here multiplies this by a live zoom value.
                PinchZoomScrollView(
                    minZoom: minZoom,
                    maxZoom: maxZoom,
                    contentSize: CGSize(width: base.width, height: base.height),
                    initialCenterFraction: initialCenterFraction,
                    content: content
                )
                .frame(width: safeSize.width, height: safeSize.height)

                // Overlay слой — рендерится поверх карты, не участвует в жестах скролла.
                // .allowsHitTesting(true) по умолчанию — если overlay не должен ловить тапы,
                // навесьте .allowsHitTesting(false) на конкретные элементы снаружи.
                overlay()
                    .frame(width: safeSize.width, height: safeSize.height)
            }
            // GeometryReader also PLACES itself across the full region (it's the one view
            // that greedily fills everything offered to it, safe area included) — shrinking
            // just the size above would otherwise leave this new, smaller frame still pinned
            // to the GeometryReader's own top-left corner, which itself starts underneath the
            // header. `.position` re-centers it inside the actual safe sub-rectangle instead
            // (top-left at (leading, top) insets, sized safeSize).
            .position(x: outer.safeAreaInsets.leading + safeSize.width / 2, y: outer.safeAreaInsets.top + safeSize.height / 2)
        }
    }
}

// Удобный init для случая, когда overlay не нужен (чтобы старые вызовы продолжали компилироваться).
extension ZoomableMapContainer where Overlay == EmptyView {
    init(
        minZoom: CGFloat = 1.0,
        maxZoom: CGFloat = 2.0,
        contentAspect: CGFloat? = nil,
        initialCenterFraction: CGPoint? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.init(
            minZoom: minZoom,
            maxZoom: maxZoom,
            contentAspect: contentAspect,
            initialCenterFraction: initialCenterFraction,
            content: content,
            overlay: { EmptyView() }
        )
    }
}

/// UIScrollView-backed host for a fixed-size SwiftUI subtree, giving it native anchor-preserving
/// pinch-zoom and free panning. See ZoomableMapContainer's own doc comment for why this replaced
/// a hand-rolled MagnificationGesture.
private struct PinchZoomScrollView<Content: View>: UIViewRepresentable {
    let minZoom: CGFloat
    let maxZoom: CGFloat
    let contentSize: CGSize
    let initialCenterFraction: CGPoint?
    let content: () -> Content

    func makeCoordinator() -> Coordinator {
        Coordinator(rootView: content())
    }

    func makeUIView(context: Context) -> UIScrollView {
        let scrollView = UIScrollView()
        scrollView.delegate = context.coordinator
        scrollView.minimumZoomScale = minZoom
        scrollView.maximumZoomScale = maxZoom
        // ИЗМЕНЕНО: при minZoom = 1.0 и maxZoom = 2.0 начальный зум будет ровно 1.0.
        // Раньше здесь было `scrollView.zoomScale = minZoom`, что при minZoom = 0.5
        // заставляло карту открываться уже уменьшенной.
        scrollView.zoomScale = min(max(1, minZoom), maxZoom)
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

        // Runs on every SwiftUI render pass (the map's own queue timers tick every second), but
        // `didSetInitialOffset` makes it a true one-shot: the FIRST pass where the scroll view
        // actually has real, laid-out bounds (before that, bounds/contentSize can still be .zero,
        // and setting contentOffset against a zero-size scroll view is silently discarded by
        // UIKit) centers on `initialCenterFraction`; every pass after that leaves the player's own
        // pan/zoom alone. Reads `scrollView.contentSize`/`bounds` (UIKit's own live numbers) rather
        // than recomputing from `contentSize`/`minZoom` by hand, so this stays correct regardless
        // of exactly how UIScrollView's zoom machinery scales contentSize internally.
        if !context.coordinator.didSetInitialOffset,
           let fraction = initialCenterFraction,
           scrollView.bounds.width > 0, scrollView.bounds.height > 0,
           scrollView.contentSize.width > 0, scrollView.contentSize.height > 0 {
            context.coordinator.didSetInitialOffset = true
            scrollView.contentOffset = Coordinator.clampedOffset(
                target: CGPoint(x: fraction.x * scrollView.contentSize.width - scrollView.bounds.width / 2,
                                 y: fraction.y * scrollView.contentSize.height - scrollView.bounds.height / 2),
                scrollView: scrollView
            )
        }
    }

    final class Coordinator: NSObject, UIScrollViewDelegate {
        let hostingController: UIHostingController<Content>
        var widthConstraint: NSLayoutConstraint?
        var heightConstraint: NSLayoutConstraint?
        var lastContentSize: CGSize = .zero
        var didSetInitialOffset = false

        init(rootView: Content) {
            hostingController = UIHostingController(rootView: rootView)
            hostingController.view.backgroundColor = .clear
            super.init()
        }

        func viewForZooming(in scrollView: UIScrollView) -> UIView? {
            hostingController.view
        }

        // "карта и все отрывающиеся окна должны быть экран - хедер - нижний бар, сейчас карта
        // заходит под бар и хедер на максимальном уменьшение" — without this delegate callback,
        // nothing ever re-clamps `contentOffset` after a pinch-out-past-minimum gesture releases
        // (bouncesZoom = true lets the gesture overshoot before UIKit springs it back), so a
        // leftover offset from that bounce could park the visible viewport somewhere that isn't
        // (0,0)-anchored — e.g. with the top-left corner (where the village name/tier badge live,
        // see mapCanvas's own `.position(x: 46, y: ...)`) scrolled out from under the header.
        //
        // Also centers the content whenever it's now SMALLER than the scroll view's own bounds —
        // possible since minZoom can go below 1 (see the init's own comment,
        // "нельзя уменьшить карту, меньше чем окно по вертикали"). UIScrollView pins undersized
        // content to its top-left corner by default; the standard fix (the same technique Apple's
        // own PhotoScroller sample uses) is a symmetric contentInset covering the leftover space
        // on each axis, recomputed from contentSize vs. bounds every time zoomScale changes.
        func scrollViewDidZoom(_ scrollView: UIScrollView) {
            let bounds = scrollView.bounds.size
            let content = scrollView.contentSize
            let horizontalInset = max(0, (bounds.width - content.width) / 2)
            let verticalInset = max(0, (bounds.height - content.height) / 2)
            scrollView.contentInset = UIEdgeInsets(top: verticalInset, left: horizontalInset, bottom: verticalInset, right: horizontalInset)

            if scrollView.zoomScale <= scrollView.minimumZoomScale, horizontalInset == 0, verticalInset == 0 {
                // Content still exactly fills (or exceeds) the viewport at minimum zoom — the old
                // "nowhere valid to pan to" case — pin to the top-left corner.
                scrollView.contentOffset = .zero
                return
            }
            scrollView.contentOffset = Coordinator.clampedOffset(target: scrollView.contentOffset, scrollView: scrollView)
        }

        static func clampedOffset(target: CGPoint, scrollView: UIScrollView) -> CGPoint {
            let maxX = max(0, scrollView.contentSize.width - scrollView.bounds.width)
            let maxY = max(0, scrollView.contentSize.height - scrollView.bounds.height)
            return CGPoint(x: min(max(0, target.x), maxX), y: min(max(0, target.y), maxY))
        }
    }
}