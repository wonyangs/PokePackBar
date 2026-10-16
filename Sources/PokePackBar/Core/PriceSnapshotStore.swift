import Foundation
import CoreFoundation

/// Explicit snapshot application, never a background price mutation. All consumers
/// use the same immutable pair, and a notification invalidates the visible UI.
final class PriceSnapshotStore: @unchecked Sendable {
    static let shared = PriceSnapshotStore()
    static let changed = Notification.Name("PokePackBar.priceSnapshotChanged")
    struct Snapshot: Sendable { let cards: CardPrices; let packs: PackMarketPrices }
    private let lock = NSLock()
    private var snapshot: Snapshot? { didSet { generation += 1 } }
    private var generation = 0
    /// 시세가 바뀔 때마다 하나씩 오른다. 시세로 계산한 값을 다시 쓸지 판단할 때 본다.
    var currentGeneration: Int { lock.withLock { generation } }
    let url: URL
    private let bundledCards = CardPrices.loadBundled()
    private let bundledPacks = PackMarketPrices.loadBundled()
    var cards: CardPrices? { lock.withLock { snapshot?.cards ?? bundledCards } }
    var packs: PackMarketPrices? { lock.withLock { snapshot?.packs ?? bundledPacks } }
    var usesImportedSnapshot: Bool { lock.withLock { snapshot != nil } }

    init(url: URL? = nil) {
        self.url = url ?? AppEnv.supportDirectory.appendingPathComponent("price-snapshot.json")
        // Online previews and the server evaluator must use the same bundled
        // prices. Never inherit the host user's private imported snapshot.
        let environment = ProcessInfo.processInfo.environment
        let authoritative = CommandLine.arguments.contains("--server-rules")
            || CommandLine.arguments.contains("--audit-online-game")
            || environment["PPB_SERVER_URL"] != nil
            || UserDefaults.standard.bool(forKey: "ppb.server.enabled")
        if url == nil && authoritative {
            if CommandLine.arguments.contains("--server-rules"),
               let path = environment["PPB_RULE_PRICES"], let data = try? Self.read(URL(fileURLWithPath: path)) {
                // Full catalogue validation runs in ServerRulesBridge after
                // initialization; calling it here recurses through CardIndex.
                if let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let cardsObject = object["cardPrices"], let packsObject = object["packPrices"],
                   let cardsData = try? JSONSerialization.data(withJSONObject: cardsObject, options: [.sortedKeys]),
                   let packsData = try? JSONSerialization.data(withJSONObject: packsObject, options: [.sortedKeys]),
                   let cards = CardPrices.decode(cardsData), let packs = PackMarketPrices.decode(packsData) {
                    snapshot = Snapshot(cards: cards, packs: packs)
                }
            }
            return
        }
        if let data = try? Self.read(self.url) { snapshot = try? Self.validate(data) }
    }

    static func read(_ url: URL) throws -> Data {
        let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
        guard size > 0 && size <= 25_000_000 else { throw SnapshotError.invalid }
        return try Data(contentsOf: url)
    }

    enum SnapshotError: LocalizedError {
        case invalid
        // 로그에는 원인을 남긴다: schemaVersion 1, USD cardPrices 와 packPrices 를 기대한다.
        var errorDescription: String? { L.current.priceSnapshotInvalid }
    }

    static func validate(_ data: Data) throws -> Snapshot {
        guard data.count <= 25_000_000,
              let object = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              object["schemaVersion"] as? Int == 1,
              let cardsObject = object["cardPrices"] as? [String: Any],
              let packsObject = object["packPrices"] as? [String: Any],
              let representatives = cardsObject["prices"] as? [String: Any],
              let printings = cardsObject["printingPrices"] as? [String: Any],
              representatives.values.allSatisfy(validPrice),
              printings.values.allSatisfy(validPrice),
              printings.keys.allSatisfy({ key in
                  let parts = key.split(separator: "#", omittingEmptySubsequences: false)
                  return parts.count == 2 && !parts[0].isEmpty && CardFinish(rawValue: String(parts[1])) != nil
              }),
              let cards = CardPrices.decode(try JSONSerialization.data(withJSONObject: cardsObject, options: [.sortedKeys])),
              let packs = PackMarketPrices.decode(try JSONSerialization.data(withJSONObject: packsObject, options: [.sortedKeys]))
        else { throw SnapshotError.invalid }
        // An accidentally partial export must not reprice most of the collection to fallback values.
        if let bundled = CardPrices.loadBundled(), let index = CardIndex.shared {
            guard index.cards.allSatisfy({ card in
                (bundled.price(card.id) == nil || cards.price(card.id) != nil) &&
                CardFinish.allCases.allSatisfy { finish in
                    bundled.exactPrice(cardID: card.id, finish: finish) == nil || cards.exactPrice(cardID: card.id, finish: finish) != nil
                }
            })
            else { throw SnapshotError.invalid }
        }
        if let bundled = PackMarketPrices.loadBundled(), let index = CardIndex.shared {
            guard index.sets.allSatisfy({ bundled.entry(setID: $0.id) == nil || packs.entry(setID: $0.id) != nil })
            else { throw SnapshotError.invalid }
        }
        return Snapshot(cards: cards, packs: packs)
    }

    private static func validPrice(_ value: Any) -> Bool {
        guard let number = value as? NSNumber, CFGetTypeID(number) != CFBooleanGetTypeID() else { return false }
        return number.doubleValue.isFinite && number.doubleValue >= 0 && number.doubleValue < 10_000_000
    }

    func apply(_ data: Data) throws {
        let candidate = try Self.validate(data)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        if FileManager.default.fileExists(atPath: url.path) {
            let previous = try Data(contentsOf: url)
            try previous.write(to: url.appendingPathExtension("previous"), options: .atomic)
        }
        try data.write(to: url, options: .atomic)
        lock.withLock { snapshot = candidate }
        NotificationCenter.default.post(name: Self.changed, object: nil)
    }

    /// Online cache is scoped by server/account; never overwrite the offline import.
    func applyOnline(_ data: Data, cacheURL: URL) throws {
        let candidate = try Self.validate(data)
        try Self.cacheOnline(data, at: cacheURL)
        installOnline(candidate)
    }

    /// 이미 검증한 온라인 시세를 적용한다. 8MB 시세 검증은 0.6초 넘게 걸려서, 호출하는 쪽이
    /// 메인 스레드 밖에서 `validate` 를 마친 뒤 결과만 넘긴다. 적용은 지금처럼 한 번에 바꾸고 알린다.
    func installOnline(_ candidate: Snapshot) {
        lock.withLock { snapshot = candidate }
        NotificationCenter.default.post(name: Self.changed, object: nil)
    }

    /// 검증을 마친 온라인 시세 원본을 계정별 캐시에 남긴다.
    static func cacheOnline(_ data: Data, at cacheURL: URL) throws {
        try FileManager.default.createDirectory(at: cacheURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: cacheURL, options: .atomic)
    }

    func reset() throws {
        if FileManager.default.fileExists(atPath: url.path) {
            let previous = try Data(contentsOf: url)
            try previous.write(to: url.appendingPathExtension("previous"), options: .atomic)
            try FileManager.default.removeItem(at: url)
        }
        lock.withLock { snapshot = nil }
        NotificationCenter.default.post(name: Self.changed, object: nil)
    }
}
