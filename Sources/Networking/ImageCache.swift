import Foundation
import UIKit
import CryptoKit

/// Дисковый кеш изображений. Первый запрос URL — скачивает и сохраняет
/// в файл под хешем URL; последующие — читают с диска мгновенно, без сети.
///
/// Зачем нужен: карта деревни может быть кастомной (admin-uploaded), и
/// каждый запуск приложения тащил бы её с сервера заново. Даже если сервер
/// отдаёт с ETag/304, это всё равно round-trip. Локальный файл — 0 мс.
///
/// Кеш живёт в Caches/ — iOS может очистить его при нехватке места, это
/// нормально (в отличие от Documents/, который бэкапится в iCloud и
/// раздувает бэкап игрока). При очистке следующая загрузка просто заново
/// скачает картинку.
actor ImageCache {
    static let shared = ImageCache()

    private let cacheDirectory: URL
    private let session: URLSession
    private var inFlight: [String: Task<UIImage?, Never>] = [:]

    private init() {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        cacheDirectory = caches.appendingPathComponent("ImageCache", isDirectory: true)
        try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)

        // Своя URLSession с URLCache побольше — для случая, когда диск-кеш
        // пуст, но HTTP-ответ сервер разрешает кешировать (Cache-Control).
        let config = URLSessionConfiguration.default
        config.urlCache = URLCache(
            memoryCapacity: 20 * 1024 * 1024,  // 20 MB RAM
            diskCapacity: 200 * 1024 * 1024,   // 200 MB на диске
            diskPath: "ImageURLCache"
        )
        config.requestCachePolicy = .returnCacheDataElseLoad
        session = URLSession(configuration: config)
    }

    /// Главный entrypoint. Возвращает UIImage из кеша или скачивает с сети.
    /// Параллельные запросы одного и того же URL ждут одну загрузку
    /// (см. inFlight), а не качают файл N раз одновременно.
    func image(for url: URL) async -> UIImage? {
        let key = cacheKey(for: url)
        let fileURL = cacheDirectory.appendingPathComponent(key)

        // 1. Диск-кеш.
        if let image = UIImage(contentsOfFile: fileURL.path) {
            return image
        }

        // 2. Уже качается кем-то другим? Ждём ту же задачу.
        if let task = inFlight[key] {
            return await task.value
        }

        // 3. Качаем.
        let task = Task<UIImage?, Never> { [session] in
            do {
                let (data, response) = try await session.data(from: url)
                guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                    return nil
                }
                guard let image = UIImage(data: data) else { return nil }

                // Сохраняем на диск как PNG (или можно оставить исходные data —
                // тогда не тратим CPU на перекодирование).
                try? data.write(to: fileURL, options: .atomic)
                return image
            } catch {
                return nil
            }
        }
        inFlight[key] = task
        let image = await task.value
        inFlight[key] = nil
        return image
    }

    /// Полная очистка кеша — можно дёрнуть в настройках или при logout.
    func clear() {
        try? FileManager.default.removeItem(at: cacheDirectory)
        try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }

    /// Хеш URL → имя файла. SHA256 от абсолютного URL — коллизий нет,
    /// длина фиксированная, читаемые символы (base64url) безопасны для FS.
    private func cacheKey(for url: URL) -> String {
        let digest = SHA256.hash(data: Data(url.absoluteString.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}