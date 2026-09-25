import SwiftUI
import UIKit

/// Pinch-to-zoom + pan container — native equivalent of Components/ZoomableMap.vue.
///
/// ИЗМЕНЕНО: убрано вычитание safeAreaInsets из outer.size. Раньше здесь
/// считался `safeSize = outer.size - safeAreaInsets`, из-за чего карта
/// зажималась в маленький прямоугольник между глобальным хедером и нижним
/// доком MainTabView (safeAreaInset'ы), а потом ещё и вписывалась по высоте —
/// получались чёрные полосы сверху/снизу. Теперь используем outer.size как
/// есть: вызывающая сторона (VillageMapView) сама решает, игнорировать ли
/// safe area через `.ignoresSafeArea()` на карте — и карта заполняет всё.
struct ZoomableMapContainer<Content: View>: View {
    let content: () -> Content
    let minZoom: CGFloat
    let maxZoom: CGFloat
    // Content's own natural width/height ratio. nil = растянуть на оба измерения.
    // Для деревни передаём 940/1672 → карта вписывается по ВЫСОТЕ, а ширина
    // получается шире экрана (можно панорамировать влево/вправо).
    var contentAspect: CGFloat?
    // Доля (0...1, 0...1) контента, которую надо центрировать во viewport
    // при первом показе. nil = верхний-левый угол по умолчанию.
    var initialCenterFraction: CGPoint?

    // minZoom = 1.0 — запрет уменьшения меньше базового размера.
    // maxZoom = 2.0 — максимальное увеличение ×2.
    init(
        minZoom: CGFloat = 1.0,
        maxZoom: CGFloat = 2.0,
        contentAspect: CGFloat? = nil,
        initialCenterFraction: CGPoint? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.minZoom = minZoom
        self.maxZoom = maxZoom
        self.contentAspect = contentAspect
        self.initialCenterFraction = initialCenterFraction
        self.content = content
    }

    private func baseSize(for outerSize: CGSize) -> (width: CGFloat, height: CGFloat) {
        if let contentAspect, contentAspect > 0 {
            // Вписываем по высоте: height = full height, width = height * aspect.
            // Для карты 940×1672 (aspect = 0.562) и iPhone'а (393×852) ширина
            // получается 852 * 0.562 ≈ 479 — шире экрана, панорамируется.
            let height = outerSize.height
            return (height * contentAspect, height)
        }
        return (outerSize.width, outerSize.height)
    }

    var body: some View {
        GeometryReader { outer in
            // ВАЖНО: не вычитаем safeAreaInsets. outer.size здесь — это то,
            // что предложил родитель (VillageMapView); после .ignoresSafeArea()
            // на карте это будет полный размер экрана, включая области под
            // глобальным хедером и нижним доком.
            let base = baseSize(for: outer.size)
            PinchZoomScrollView(
                minZoom: minZoom,
                maxZoom: maxZoom,
                contentSize: CGSize(width: base.width, height: base.height),
                initialCenterFraction: initialCenterFraction,
                content: content
            )
            .frame(width: outer.size.width, height: outer.size.height)
        }
    }
}

/// UIScrollView-backed host for a fixed-size SwiftUI subtree, giving it native
/// anchor-preserving pinch-zoom and free panning.
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
        // Начальный зум всегда 1.0 — даже если minZoom ниже (например, 0.5).
        // Сейчас minZoom = 1.0, так что строка просто подтверждает поведение.
        scrollView.zoomScale = min(max(1, minZoom), maxZoom)
        scrollView.bouncesZoom = true
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

        // Однократное центрирование на initialCenterFraction — до первого
        // layout pass'а scrollView.bounds/contentSize = .zero, поэтому флаг
        // didSetInitialOffset срабатывает только на первом проходе, где обе
        // величины уже положительные. Дальше не трогаем панораму/зум игрока.
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

        // Клампим contentOffset после пинч-аут (bouncesZoom может оставить
        // смещение вне допустимого прямоугольника) и центрируем контент,
        // когда он меньше bounds (обычно при minZoom < 1 — сейчас не наш
        // случай, но оставляем на будущее).
        func scrollViewDidZoom(_ scrollView: UIScrollView) {
            let bounds = scrollView.bounds.size
            let content = scrollView.contentSize
            let horizontalInset = max(0, (bounds.width - content.width) / 2)
            let verticalInset = max(0, (bounds.height - content.height) / 2)
            scrollView.contentInset = UIEdgeInsets(top: verticalInset, left: horizontalInset, bottom: verticalInset, right: horizontalInset)

            if scrollView.zoomScale <= scrollView.minimumZoomScale, horizontalInset == 0, verticalInset == 0 {
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