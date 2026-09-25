import SwiftUI

/// Drop-in замена системного `AsyncImage(url:content:)`, но с диском под капотом —
/// см. `ImageCache.swift`. Раньше `ImageCache` был написан, но нигде не использовался: все
/// картинки с игрового сервера (карта деревни, поля, иконки построек на карте мира, аватар
/// игрока в шапке) продолжали грузиться через обычный `AsyncImage`, который никакого файла
/// на диске не оставляет — при каждом перезапуске приложения (и часто при каждом повторном
/// показе экрана) всё качалось заново. Этот файл — недостающее звено: тот же API, что у
/// `AsyncImage` (замена — это буквально переименование в местах использования), только
/// `content` вызывается на основе `ImageCache.shared.image(for:)`.
///
/// `.task(id: url)` перезапускает загрузку, если `url` меняется (например, игрок переключил
/// деревню с другой кастомной картой) — как и `AsyncImage`, который делает то же самое через
/// свой внутренний `id`.
struct CachedAsyncImage<Content: View>: View {
    let url: URL?
    @ViewBuilder var content: (AsyncImagePhase) -> Content

    @State private var phase: AsyncImagePhase = .empty

    var body: some View {
        content(phase)
            .task(id: url) {
                guard let url else {
                    phase = .empty
                    return
                }
                phase = .empty
                if let uiImage = await ImageCache.shared.image(for: url) {
                    phase = .success(Image(uiImage: uiImage))
                } else {
                    phase = .failure(CachedAsyncImageError.loadFailed)
                }
            }
    }
}

private enum CachedAsyncImageError: LocalizedError {
    case loadFailed

    var errorDescription: String? {
        "Не удалось загрузить изображение."
    }
}
