import SwiftUI
import UIKit

/// Pinch-to-zoom + pan container с сохранением состояния.
///
/// Отличие от предыдущей версии: контейнер принимает ссылку на
/// `VillageMapViewState` и через неё:
///   • читает `zoomScale`/`contentOffset` при первом показе (если
///     `hasBeenInitialized == true`) либо центрирует на
///     `initialCenterFraction` (первый раз);
///   • пишет обратно в delegate-колбэках, чтобы при возврате на вкладку
///     карта открылась в том же положении и с тем же зумом.
///
/// Aspect FILL: на минимальном зуме карта покрывает viewport по обеим осям
/// без чёрных полос.
struct ZoomableMapContainer<Content: View>: View {
    let content: () -> Content
    let minZoom: CGFloat
    let maxZoom: CGFloat
    var contentAspect: CGFloat?
    var initialCenterFraction: CGPoint?
    let state: VillageMapViewState

    init(
        minZoom: CGFloat = 1.0,
        maxZoom: CGFloat = 2.0,
        contentAspect: CGFloat? = nil,
        initialCenterFraction: CGPoint? = nil,
        state: VillageMapViewState,
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

private struct PinchZoomScrollView<Content: View>: UIViewRepresentable {
    let minZoom: CGFloat
    let maxZoom: CGFloat
    let contentSize: CGSize
    let initialCenterFraction: CGPoint?
    let state: VillageMapViewState
    let content: () -> Content

    func makeCoordinator() -> Coordinator {
        Coordinator(rootView: content(), state: state)
    }

    func makeUIView(context: Context) -> UIScrollView {
        let scrollView = UIScrollView()
        scrollView.delegate = context.coordinator
        scrollView.minimumZoomScale = minZoom
        scrollView.maximumZoomScale = maxZoom
        // Ставим стартовый зум из state. Реальное центрирование и
        // восстановление contentOffset произойдут в updateUIView, когда
        // у scrollView появятся настоящие bounds.
        scrollView.zoomScale = min(max(state.zoomScale, minZoom), maxZoom)
        // Жёсткий запрет на bounce ниже minZoom: пользователь физически
        // не сможет сжать карту меньше 1.3.
        scrollView.bouncesZoom = false
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.backgroundColor = .clear
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
        context.coordinator.hostingController.rootView = content()

        if scrollView.minimumZoomScale != minZoom { scrollView.minimumZoomScale = minZoom }
        if scrollView.maximumZoomScale != maxZoom { scrollView.maximumZoomScale = maxZoom }

        if context.coordinator.lastContentSize != contentSize {
            context.coordinator.lastContentSize = contentSize
            context.coordinator.widthConstraint?.constant = contentSize.width
            context.coordinator.heightConstraint?.constant = contentSize.height
        }

        // Однократное применение состояния, когда у scrollView уже есть
        // настоящие bounds и contentSize.
        if !context.coordinator.didApplyInitialState,
           scrollView.bounds.width > 0, scrollView.bounds.height > 0,
           scrollView.contentSize.width > 0, scrollView.contentSize.height > 0 {
            context.coordinator.didApplyInitialState = true

            let zoom = min(max(state.zoomScale, minZoom), maxZoom)
            scrollView.zoomScale = zoom
            // После установки zoomScale UIScrollView пересчитывает
            // contentSize = baseSize * zoomScale (hosted view имеет
            // фиксированные width/height constraints) — синхронно.

            if state.hasBeenInitialized, state.contentOffset != .zero {
                // Восстанавливаем то, что игрок оставил в прошлый раз.
                scrollView.contentOffset = Coordinator.clampedOffset(
                    target: state.contentOffset, scrollView: scrollView)
            } else if let fraction = initialCenterFraction {
                // Первый показ: центрируем на главном здании.
                scrollView.contentOffset = Coordinator.clampedOffset(
                    target: CGPoint(x: fraction.x * scrollView.contentSize.width - scrollView.bounds.width / 2,
                                    y: fraction.y * scrollView.contentSize.height - scrollView.bounds.height / 2),
                    scrollView: scrollView)
                state.hasBeenInitialized = true
            } else {
                state.hasBeenInitialized = true
            }

            // Фиксируем применённые значения — они же станут стартовыми
            // при следующем показе.
            state.zoomScale = scrollView.zoomScale
            state.contentOffset = scrollView.contentOffset
        }
    }

    final class Coordinator: NSObject, UIScrollViewDelegate {
        let hostingController: UIHostingController<Content>
        let state: VillageMapViewState
        var widthConstraint: NSLayoutConstraint?
        var heightConstraint: NSLayoutConstraint?
        var lastContentSize: CGSize = .zero
        var didApplyInitialState = false

        init(rootView: Content, state: VillageMapViewState) {
            self.hostingController = UIHostingController(rootView: rootView)
            self.state = state
            self.hostingController.view.backgroundColor = .clear
            super.init()
        }

        func viewForZooming(in scrollView: UIScrollView) -> UIView? {
            hostingController.view
        }

        func scrollViewDidZoom(_ scrollView: UIScrollView) {
            let bounds = scrollView.bounds.size
            let content = scrollView.contentSize
            let horizontalInset = max(0, (bounds.width - content.width) / 2)
            let verticalInset = max(0, (bounds.height - content.height) / 2)
            scrollView.contentInset = UIEdgeInsets(top: verticalInset, left: horizontalInset, bottom: verticalInset, right: horizontalInset)

            if scrollView.zoomScale <= scrollView.minimumZoomScale, horizontalInset == 0, verticalInset == 0 {
                scrollView.contentOffset = .zero
            } else {
                scrollView.contentOffset = Coordinator.clampedOffset(target: scrollView.contentOffset, scrollView: scrollView)
            }

            state.zoomScale = scrollView.zoomScale
            state.contentOffset = scrollView.contentOffset
        }

        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            // Первый показ сам выставляет contentOffset — не пишем в state,
            // пока инициализация не завершена.
            guard didApplyInitialState else { return }
            state.contentOffset = scrollView.contentOffset
        }

        static func clampedOffset(target: CGPoint, scrollView: UIScrollView) -> CGPoint {
            let maxX = max(0, scrollView.contentSize.width - scrollView.bounds.width)
            let maxY = max(0, scrollView.contentSize.height - scrollView.bounds.height)
            return CGPoint(x: min(max(0, target.x), maxX), y: min(max(0, target.y), maxY))
        }
    }
}