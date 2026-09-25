import SwiftUI
import UIKit

/// Pinch-to-zoom + pan container.
///
/// Aspect FILL: на минимальном зуме (1.0) карта покрывает viewport по обеим
/// осям — без чёрных полос ни справа/слева, ни сверху/снизу. Одна из сторон
/// при этом точно совпадает с краем экрана (aspect fill), вторая — уходит за
/// край, создавая панораму.
///
/// bouncesZoom = false — жёсткий запрет на уменьшение ниже minZoom (1.0).
/// Без этого UIScrollView разрешает «пружинку» ниже минимума при жесте
/// пинч-ин — визуально это выглядит как уменьшение.
struct ZoomableMapContainer<Content: View>: View {
    let content: () -> Content
    let minZoom: CGFloat
    let maxZoom: CGFloat
    var contentAspect: CGFloat?
    var initialCenterFraction: CGPoint?

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

    /// Aspect FILL: гарантирует, что контент покрывает outerSize по обеим осям.
    private func baseSize(for outerSize: CGSize) -> (width: CGFloat, height: CGFloat) {
        guard let aspect = contentAspect, aspect > 0, outerSize.width > 0, outerSize.height > 0 else {
            return (outerSize.width, outerSize.height)
        }
        // Вписать по ширине. Если высота >= высоты экрана — хватит.
        let fitByWidthHeight = outerSize.width / aspect
        if fitByWidthHeight >= outerSize.height {
            return (outerSize.width, fitByWidthHeight)
        }
        // Иначе вписать по высоте (даёт ширину шире экрана).
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
    let content: () -> Content

    func makeCoordinator() -> Coordinator {
        Coordinator(rootView: content())
    }

    func makeUIView(context: Context) -> UIScrollView {
        let scrollView = UIScrollView()
        scrollView.delegate = context.coordinator
        scrollView.minimumZoomScale = minZoom
        scrollView.maximumZoomScale = maxZoom
        scrollView.zoomScale = min(max(1, minZoom), maxZoom)
        // Жёсткий запрет на уменьшение ниже minZoom. Без этого UIScrollView
        // разрешает «резиновый» bounce ниже минимума при пинч-ине — визуально
        // это выглядит как попытка уменьшить карту (даже если потом возвращает).
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