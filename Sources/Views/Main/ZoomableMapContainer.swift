import SwiftUI
import UIKit

/// Pinch-to-zoom + pan container с опциональным сохранением состояния.
///
/// Параметр `state` опционален: если передан — зум/панорама сохраняются
/// (используется в VillageMapView), если нет — каждый показ начинается
/// с нуля (используется в FieldsMapView/WorldMapView).
///
/// Жёсткий запрет на overscroll и rubber-band: используем сабкласс
/// `LockedScrollView`, который клампит `contentOffset` и `zoomScale`
/// в их допустимые диапазоны ещё до применения. `bounces = false` /
/// `bouncesZoom = false` — этого одного недостаточно: UIKit во время
/// жеста применяет резиновый эффект на слой трансформации, не меняя
/// публично видимый `contentOffset`, поэтому ни `didScroll`, ни
/// `didZoom` не видят overscroll, а пользователь его видит.
struct ZoomableMapContainer<Content: View>: View {
    let content: () -> Content
    let minZoom: CGFloat
    let maxZoom: CGFloat
    var contentAspect: CGFloat?
    var initialCenterFraction: CGPoint?
    let state: VillageMapViewState?

    init(
        minZoom: CGFloat = 1.0,
        maxZoom: CGFloat = 2.0,
        contentAspect: CGFloat? = nil,
        initialCenterFraction: CGPoint? = nil,
        state: VillageMapViewState? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.minZoom = minZoom
        self.maxZoom = maxZoom
        self.contentAspect = contentAspect
        self.initialCenterFraction = initialCenterFraction
        self.state = state
        self.content = content
    }

    private func baseSize(for outerSize: CGSize) -> (width: CGFloat, height: CGFloat) {
        guard let aspect = contentAspect, aspect > 0, outerSize.width > 0, outerSize.height > 0 else {
            return (outerSize.width, outerSize.height)
        }
        let fitByWidthHeight = outerSize.width / aspect
        if fitByWidthHeight >= outerSize.height {
            return (outerSize.width, fitByWidthHeight)
        }
        let fitByHeightWidth = outerSize.height * aspect
        return (fitByHeightWidth, outerSize.height)
    }

    var body: some View {
        GeometryReader { outer in
            let base = baseSize(for: outer.size)
            PinchZoomScrollView(
                minZoom: minZoom,
                maxZoom: maxZoom,
                contentSize: CGSize(width: base.width, height: base.height),
                initialCenterFraction: initialCenterFraction,
                state: state,
                content: content
            )
            .frame(width: outer.size.width, height: outer.size.height)
        }
    }
}

/// UIScrollView-сабкласс, жёстко клампящий contentOffset и zoomScale
/// в допустимые диапазоны на каждом `setContentOffset`/`setZoomScale`.
///
/// Ключевой момент: UIKit дёргает эти сеттеры ВО ВРЕМЯ жеста, ещё до
/// того, как пользователь отпустил палец. Если клампить значения прямо
/// здесь, `UIScrollView` физически не может отрисовать сдвиг за край —
/// ни в contentOffset, ни в transform. Это решает то, с чем не справляется
/// один только `bounces = false`.
private final class LockedScrollView: UIScrollView {
    override func setContentOffset(_ contentOffset: CGPoint, animated: Bool) {
        let maxX = max(0, contentSize.width - bounds.width)
        let maxY = max(0, contentSize.height - bounds.height)
        let clamped = CGPoint(
            x: min(max(0, contentOffset.x), maxX),
            y: min(max(0, contentOffset.y), maxY)
        )
        super.setContentOffset(clamped, animated: animated)
    }

    override func setZoomScale(_ scale: CGFloat, animated: Bool) {
        let clamped = min(max(minimumZoomScale, scale), maximumZoomScale)
        super.setZoomScale(clamped, animated: animated)
    }
}

private struct PinchZoomScrollView<Content: View>: UIViewRepresentable {
    let minZoom: CGFloat
    let maxZoom: CGFloat
    let contentSize: CGSize
    let initialCenterFraction: CGPoint?
    let state: VillageMapViewState?
    let content: () -> Content

    func makeCoordinator() -> Coordinator {
        Coordinator(rootView: content(), state: state)
    }

    func makeUIView(context: Context) -> UIScrollView {
        // Используем LockedScrollView вместо UIScrollView — он сам
        // клампит contentOffset/zoomScale на каждом сеттере.
        let scrollView = LockedScrollView()
        scrollView.delegate = context.coordinator
        scrollView.minimumZoomScale = minZoom
        scrollView.maximumZoomScale = maxZoom
        scrollView.zoomScale = min(max(state?.zoomScale ?? 1.0, minZoom), maxZoom)

        // Дополнительно выключаем штатные bounce-механизмы.
        // Даже если LockedScrollView не поймает какой-то путь (например,
        // приватный _rubberBand-код), bounce не сработает.
        scrollView.bouncesZoom = false
        scrollView.bounces = false
        scrollView.alwaysBounceHorizontal = false
        scrollView.alwaysBounceVertical = false

        // Никаких contentInset — иначе UIKit добавит лишнее пространство
        // в scrollable-область, и края карты «поедут».
        scrollView.contentInset = .zero
        scrollView.contentInsetAdjustmentBehavior = .never

        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.backgroundColor = .clear

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
        context.coordinator.hostingController.rootView = content()

        if scrollView.minimumZoomScale != minZoom { scrollView.minimumZoomScale = minZoom }
        if scrollView.maximumZoomScale != maxZoom { scrollView.maximumZoomScale = maxZoom }

        if context.coordinator.lastContentSize != contentSize {
            context.coordinator.lastContentSize = contentSize
            context.coordinator.widthConstraint?.constant = contentSize.width
            context.coordinator.heightConstraint?.constant = contentSize.height
        }

        if !context.coordinator.didApplyInitialState,
           scrollView.bounds.width > 0, scrollView.bounds.height > 0,
           scrollView.contentSize.width > 0, scrollView.contentSize.height > 0 {
            context.coordinator.didApplyInitialState = true

            let zoom = min(max(state?.zoomScale ?? 1.0, minZoom), maxZoom)
            scrollView.zoomScale = zoom

            if let state {
                if state.hasBeenInitialized, state.contentOffset != .zero {
                    scrollView.contentOffset = state.contentOffset
                } else if let fraction = initialCenterFraction {
                    scrollView.contentOffset = CGPoint(
                        x: fraction.x * scrollView.contentSize.width - scrollView.bounds.width / 2,
                        y: fraction.y * scrollView.contentSize.height - scrollView.bounds.height / 2
                    )
                    state.hasBeenInitialized = true
                } else {
                    state.hasBeenInitialized = true
                }
                state.zoomScale = scrollView.zoomScale
                state.contentOffset = scrollView.contentOffset
            } else if let fraction = initialCenterFraction {
                scrollView.contentOffset = CGPoint(
                    x: fraction.x * scrollView.contentSize.width - scrollView.bounds.width / 2,
                    y: fraction.y * scrollView.contentSize.height - scrollView.bounds.height / 2
                )
            }
        }
    }

    final class Coordinator: NSObject, UIScrollViewDelegate {
        let hostingController: UIHostingController<Content>
        let state: VillageMapViewState?
        var widthConstraint: NSLayoutConstraint?
        var heightConstraint: NSLayoutConstraint?
        var lastContentSize: CGSize = .zero
        var didApplyInitialState = false

        init(rootView: Content, state: VillageMapViewState?) {
            self.hostingController = UIHostingController(rootView: rootView)
            self.state = state
            self.hostingController.view.backgroundColor = .clear
            super.init()
        }

        func viewForZooming(in scrollView: UIScrollView) -> UIView? {
            hostingController.view
        }

        func scrollViewDidZoom(_ scrollView: UIScrollView) {
            // Никаких ручных contentInset — UIScrollView сам центрирует
            // undersized контент через встроенные механизмы, а наш
            // LockedScrollView клампит contentOffset.
            state?.zoomScale = scrollView.zoomScale
            state?.contentOffset = scrollView.contentOffset
        }

        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            guard didApplyInitialState else { return }
            // Не трогаем contentOffset вручную (это дёргало карту во время
            // жеста) — только фиксируем позицию в state для восстановления
            // при следующем показе.
            state?.contentOffset = scrollView.contentOffset
        }
    }
}