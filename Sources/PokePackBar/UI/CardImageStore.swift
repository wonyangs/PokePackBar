import AppKit
import SwiftUI
/// Development audits may provide original scans through PPB_CARD_ART_DIR.
/// Distributed builds fetch low/high WebP variants from the managed CDN and
/// retain them in the application-support cache; originals are not bundled.
actor CardImageStore {
    static let shared = CardImageStore()

    private var mem: [String: Data] = [:]
    private var memOrder: [String] = []       // LRU — 최근 접근이 뒤
    private var memBytes = 0

    /// 개수가 아니라 바이트로 제한한다. 썸네일은 25KB, 고해상도는 150KB 로 편차가 6배라
    /// 개수 상한으로는 메모리 사용량을 예측할 수 없다.
    private let memBudget = 24 * 1024 * 1024

    /// 진행 중인 요청 — 같은 카드를 동시에 여러 뷰가 요청할 때 중복 다운로드를 막는다.
    /// 격자가 스크롤될 때 같은 카드가 반복 요청되는 경로가 실제로 있다.
    private var inFlight: [String: Task<Data?, Never>] = [:]

    /// 정식 앱과 개발용 앱(`AppEnv.dataName`)이 함께 쓴다. 같은 카드는 같은 파일이고 원자적으로
    /// 쓰며 지우지 않으니, 나눌 이유 없이 내려받기만 두 번 하게 된다.
    static let cacheDir: URL = {
        let d = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            // v2 separates the managed-CDN variants from legacy Supabase files.
            // Otherwise an old accepted cache entry can bypass the new origin.
            .appendingPathComponent("PokePackBar/cards-v2")
        try? FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
        return d
    }()

    static func cacheKey(cardID: String, hires: Bool) -> String {
        "\(cardID)\(hires ? "_hires" : "")"
    }

    /// 팩 아트 캐시 키. 카드 ID 는 항상 `-` 를 포함하므로 접두사로 충돌하지 않는다.
    static func packCacheKey(setID: String) -> String { "pack_\(setID)" }

    private static func file(for key: String) -> URL {
        cacheDir.appendingPathComponent("\(key).webp")
    }

    func data(cardID: String, hires: Bool) async -> Data? {
        if let local = SupplementalEnergyCard.data(cardID: cardID),
           SupplementalEnergyCard.accepts(local) { return local }
        if let local = CardArtLibrary.data(cardID), CardArtLibrary.accepts(local, hires: hires) { return local }
        return await data(key: Self.cacheKey(cardID: cardID, hires: hires),
                   urls: CardImageSource.urls(cardID: cardID, hires: hires))
    }

    /// 세트의 부스터 팩 아트.
    func packData(setID: String) async -> Data? {
        if let local = CardArtLibrary.data(Self.packCacheKey(setID: setID)) { return local }
        return await data(key: Self.packCacheKey(setID: setID),
                   urls: [CardImageSource.packURL(setID: setID)].compactMap { $0 })
    }

    /// 디스크에 이미 받아 둔 팩 아트. 없으면 nil — 네트워크를 타지 않는다.
    static func cachedPackData(setID: String) -> Data? {
        try? Data(contentsOf: file(for: packCacheKey(setID: setID)))
    }

    /// 카드와 팩이 같은 캐시·중복요청 억제를 쓴다. 키와 주소만 다르다.
    private func data(key: String, urls sources: [URL]) async -> Data? {
        let hires = key.hasSuffix("_hires")
        if let d = mem[key] { touch(key); return d }

        let file = Self.file(for: key)
        if let d = try? Data(contentsOf: file), CardArtLibrary.accepts(d, hires: hires) { remember(key, d); return d }

        // Deterministic offline diagnostics; never changes system networking.
        if AppEnv.value("PPB_OFFLINE") == "1" { return nil }

        if let existing = inFlight[key] { return await existing.value }

        let task = Task<Data?, Never> {
            let deadline = Date().addingTimeInterval(6)
            for url in sources {
                let remaining = deadline.timeIntervalSinceNow
                guard !Task.isCancelled, remaining > 0 else { return nil }
                let request = URLRequest(url: url, timeoutInterval: remaining)
                guard let (data, response) = try? await URLSession.shared.data(for: request),
                      (response as? HTTPURLResponse)?.statusCode == 200,
                      CardArtLibrary.accepts(data, hires: hires) else { continue }
                return data
            }
            return nil
        }
        inFlight[key] = task
        let data = await task.value
        inFlight[key] = nil

        guard let data else { return nil }
        // 원자적 쓰기 — 강제 종료 시 손상된 캐시 파일이 남지 않게 한다.
        try? data.write(to: file, options: .atomic)
        remember(key, data)
        return data
    }

    private func remember(_ key: String, _ data: Data) {
        if let old = mem[key] { memBytes -= old.count }
        mem[key] = data
        memBytes += data.count
        touch(key)
        while memBytes > memBudget, let oldest = memOrder.first {
            memOrder.removeFirst()
            if let d = mem.removeValue(forKey: oldest) { memBytes -= d.count }
        }
    }

    private func touch(_ key: String) {
        if let i = memOrder.firstIndex(of: key) { memOrder.remove(at: i) }
        memOrder.append(key)
    }
}

/// Serial decoder bounds CPU pressure while keeping ImageIO off the main actor.
private actor CardBitmapDecoder {
    static let shared = CardBitmapDecoder()
    func decode(_ data: Data, hires: Bool) -> CGImage? {
        guard !Task.isCancelled else { return nil }
        return CardArtLibrary.bitmap(data, hires: hires)
    }
}

@MainActor
enum CardImageLoader {
    private static let decodedCache: NSCache<NSString, NSImage> = {
        let cache = NSCache<NSString, NSImage>()
        cache.totalCostLimit = 96 * 1024 * 1024
        cache.countLimit = 256
        return cache
    }()

    static func preparedImage(cardID: String, hires: Bool) -> NSImage? {
        decodedCache.object(forKey: CardImageStore.cacheKey(cardID: cardID, hires: hires) as NSString)
    }

    private static func decoded(_ data: Data, cardID: String, hires: Bool) async -> NSImage? {
        guard let bitmap = await CardBitmapDecoder.shared.decode(data, hires: hires),
              !Task.isCancelled else { return nil }
        let image = NSImage(cgImage: bitmap, size: NSSize(width: bitmap.width, height: bitmap.height))
        decodedCache.setObject(image,
            forKey: CardImageStore.cacheKey(cardID: cardID, hires: hires) as NSString,
            cost: bitmap.bytesPerRow * bitmap.height)
        return image
    }

    /// 이번 프레임에 그릴 그림을 고른다.
    ///
    /// 미리 받아 둔 그림이 있으면 **첫 프레임부터** 그것을 쓴다. `.task` 는 첫 렌더가 끝난
    /// 뒤에 돌기 때문에, 그것만 믿으면 새 카드가 나올 때마다 회색 자리표시가 한 프레임
    /// 스쳐 지나간다(개봉 화면에서 깜빡임으로 보인 원인이다).
    ///
    /// 이미 불러 둔 그림은 **그것이 이 카드의 것일 때만** 쓴다. 뷰가 재사용되면서 `cardID`
    /// 만 바뀌면 이전 카드 그림이 남아 있어, 확인하지 않으면 엉뚱한 카드가 한 프레임 보인다.
    static func displayed(_ loaded: NSImage?, loadedKey: String?,
                          key: String, preloaded: NSImage?) -> NSImage? {
        if let loaded, loadedKey == key { return loaded }
        return preloaded
    }

    /// 디스크 캐시에 이미 있으면 네트워크 없이 즉시 반환한다.
    /// 격자를 다시 그릴 때 매번 비동기로 가면 화면이 한 번 빈 뒤 채워져 깜빡인다.
    static func cachedImage(cardID: String, hires: Bool) -> NSImage? {
        if let data = SupplementalEnergyCard.data(cardID: cardID),
           let image = CardArtLibrary.image(data, hires: hires) { return image }
        if let data = CardArtLibrary.data(cardID), let image = CardArtLibrary.image(data, hires: hires) { return image }
        if let image = readCache(cardID: cardID, hires: hires) { return image }
        // 큰 그림이 없으면 작은 그림으로라도 그린다 — 아래 `image(cardID:hires:)` 와 같은 이유다.
        return hires ? readCache(cardID: cardID, hires: false) : nil
    }

    private static func readCache(cardID: String, hires: Bool) -> NSImage? {
        let key = CardImageStore.cacheKey(cardID: cardID, hires: hires)
        let f = CardImageStore.cacheDir.appendingPathComponent("\(key).webp")
        guard let d = try? Data(contentsOf: f), CardArtLibrary.accepts(d, hires: hires) else { return nil }
        return CardArtLibrary.image(d, hires: hires)
    }

    /// A low-resolution emergency fallback is temporary, never an HD cache hit.
    static func image(cardID: String, hires: Bool) async -> NSImage? {
        guard !Task.isCancelled else { return nil }
        if let ready = preparedImage(cardID: cardID, hires: hires) { return ready }
        if let d = await CardImageStore.shared.data(cardID: cardID, hires: hires) {
            return await decoded(d, cardID: cardID, hires: hires)
        }
        guard hires,
              let d = await CardImageStore.shared.data(cardID: cardID, hires: false) else {
            return nil
        }
        return await decoded(d, cardID: cardID, hires: false)
    }

    /// 곧바로 내놓을 수 있는 팩 아트. 메모리에 있거나 번들에 있으면 기다릴 것이 없다.
    ///
    /// 팩이 130개가 되면서 번들에서 뺐다 — 열 장에 615KB 였으니 130개면 10.5MB 이고,
    /// 앱 전체가 2.2MB 다. 카드 그림과 같은 길(네트워크 → 디스크 캐시)로 보낸다.
    /// 대신 **디코딩한 것을 메모리에 들고 있는다.** 목록을 오르내릴 때마다 디스크에서
    /// 읽어 다시 디코딩하면 그만큼 버벅인다.
    static func readyPackImage(setID: String) -> NSImage? {
        if let cached = packCache[setID] { return cached }
        if let data = CardArtLibrary.data(CardImageStore.packCacheKey(setID: setID)), let image = NSImage(data: data) {
            packCache[setID] = image
            return image
        }
        // 예전 배포에서 번들에 넣어 둔 것이 남아 있으면 그대로 쓴다.
        if let url = AppResources.bundle?.url(forResource: setID, withExtension: "webp",
                                              subdirectory: "packs"),
           let data = try? Data(contentsOf: url), let image = NSImage(data: data) {
            packCache[setID] = image
            return image
        }
        // 디스크 캐시에 있으면 네트워크를 타지 않는다.
        guard let data = CardImageStore.cachedPackData(setID: setID),
              let image = NSImage(data: data) else { return nil }
        packCache[setID] = image
        return image
    }

    /// 디코딩한 팩 아트를 들고 있는다. 한 장이 180×330 남짓이라 130장이어도 가볍다.
    private static var packCache: [String: NSImage] = [:]

    static func packImage(setID: String) async -> NSImage? {
        if let ready = readyPackImage(setID: setID) { return ready }
        guard let d = await CardImageStore.shared.packData(setID: setID),
              let image = NSImage(data: d) else { return nil }
        packCache[setID] = image
        return image
    }

    /// 세트들의 팩 아트를 미리 받아 둔다.
    static func prefetchPacks(setIDs: [String], timeout: Duration = .seconds(6)) async {
        guard !setIDs.isEmpty else { return }
        await withTaskGroup(of: Void.self) { group in
            for id in Set(setIDs) { group.addTask { _ = await packImage(setID: id) } }
            group.addTask { try? await Task.sleep(for: timeout) }
            // 마감 작업이 먼저 끝나면 남은 것을 취소한다.
            var done = 0
            let total = Set(setIDs).count
            for await _ in group {
                done += 1
                if done >= total { group.cancelAll(); break }
            }
        }
    }

    /// 여러 장을 동시에 받아 둔다. 개봉처럼 정해진 장을 연달아 보여줘야 할 때 쓴다.
    ///
    /// 한 장씩 화면에 뜰 때 받으면 0.5초 안에 못 끝나 빈 자리만 지나간다.
    /// 받아 둔 이미지를 그대로 돌려주므로 표시 시점에는 디스크를 다시 읽지 않는다.
    ///
    /// `timeout` 이 지나면 남은 요청을 취소하고 그때까지 받은 것만 돌려준다 —
    /// 네트워크가 죽었을 때 개봉이 멈춰 있는 것보다 낫다. 못 받은 카드는
    /// 표시 시점에 각자 다시 시도한다.
    static func prefetch(cardIDs: [String], hires: Bool,
                         timeout: Duration = .seconds(6)) async -> [String: NSImage] {
        guard !cardIDs.isEmpty, !Task.isCancelled else { return [:] }
        var seen = Set<String>()
        let ids = cardIDs.filter { seen.insert($0).inserted }
        return await withTaskGroup(of: (String, NSImage?)?.self) { group in
            var next = 0
            let concurrency = min(6, ids.count)
            for id in ids.prefix(concurrency) {
                group.addTask { (id, await image(cardID: id, hires: hires)) }
                next += 1
            }
            group.addTask {
                try? await Task.sleep(for: timeout)
                return nil   // 마감 신호
            }

            var out: [String: NSImage] = [:]
            var remaining = ids.count
            for await result in group {
                guard let result else { group.cancelAll(); break }   // 마감
                if let img = result.1 { out[result.0] = img }
                remaining -= 1
                if remaining == 0 { group.cancelAll(); break }
                if next < ids.count, !Task.isCancelled {
                    let id = ids[next]
                    next += 1
                    group.addTask { (id, await image(cardID: id, hires: hires)) }
                }
            }
            return out
        }
    }
}

/// 카드 한 장을 표시한다. 캐시에 있으면 즉시, 없으면 받아서 채운다.
///
/// 카드 비율은 실제 카드와 같은 0.717(245x342) 로 고정한다. 세트마다 원본 해상도가
/// 달라서(600x825 부터 1423x1984 까지) 이미지 비율에 맡기면 격자가 들쭉날쭉해진다.
@MainActor
struct CardImageView: View {
    let cardID: String
    var hires = false
    var width: CGFloat = 88
    /// 아직 얻지 못한 카드를 실루엣으로 보여줄 때 쓴다.
    var dimmed = false
    /// 미리 받아 둔 이미지. 있으면 디스크도 네트워크도 건너뛴다.
    var preloaded: NSImage?

    /// Attached to the fitted Image, not its fixed-ratio outer holder. The
    /// overlay receives the EXACT displayed scan, including an HD replacement.
    var imageOverlay: ((NSImage) -> AnyView)? = nil

    @State private var image: NSImage?
    /// `image` 가 어느 카드 것인지. 뷰가 재사용되면서 `cardID` 만 바뀌는 경로가 있어,
    /// 꼬리표가 없으면 새 카드 자리에 이전 카드 그림이 한 프레임 그려진다.
    @State private var imageKey: String?

    private var height: CGFloat { (width / 0.717).rounded() }

    private var key: String { "\(cardID)-\(hires)" }

    var body: some View {
        ZStack {
            if let image = CardImageLoader.displayed(image, loadedKey: imageKey,
                                                     key: key, preloaded: preloaded) {
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fit)
                    .saturation(dimmed ? 0 : 1)
                    .opacity(dimmed ? 0.35 : 1)
                    .overlay { if let imageOverlay { imageOverlay(image) } }
            } else {
                RoundedRectangle(cornerRadius: width * 0.05)
                    .fill(Color.secondary.opacity(0.12))
                    .overlay(
                        Image(systemName: "rectangle.on.rectangle.angled")
                            .font(.system(size: width * 0.28))
                            .foregroundStyle(.tertiary)
                    )
            }
        }
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: width * 0.05))
        .task(id: key) {
            let wanted = key
            if let preloaded {
                image = preloaded; imageKey = wanted
                if !hires || CardArtLibrary.isHighResolution(preloaded) { return }
            }
            if let cached = CardImageLoader.preparedImage(cardID: cardID, hires: hires) {
                image = cached; imageKey = wanted
                if !hires || CardArtLibrary.isHighResolution(cached) { return }
            }
            // 아무것도 없던 자리에 늦게 도착한 그림만 짧게 떠오른다. 처음부터 있던 그림(미리
            // 받은 것)은 첫 프레임에 그대로 그린다 — 거기까지 흐리면 개봉 화면이 깜빡인다.
            let hadImage = CardImageLoader.displayed(image, loadedKey: imageKey, key: wanted,
                                                     preloaded: preloaded) != nil
            let fetched = await CardImageLoader.image(cardID: cardID, hires: hires)
            guard !Task.isCancelled, wanted == key else { return }
            guard let fetched else { return }
            if hadImage {
                image = fetched; imageKey = wanted
            } else {
                withAnimation(.easeOut(duration: 0.2)) { image = fetched; imageKey = wanted }
            }
        }
    }
}

/// 부스터 팩 한 개를 표시한다.
///
/// 카드와 비율이 다르다. 팩은 세로로 더 길어서(약 0.55) 카드 비율(0.717)로 그리면
/// 위아래가 잘리거나 좌우에 빈 공간이 생긴다.
@MainActor
struct PackImageView: View {
    let setID: String
    var width: CGFloat = 34
    /// 미리 받아 둔 그림. 있으면 디스크도 네트워크도 건너뛴다.
    var preloaded: NSImage?

    @State private var image: NSImage?

    init(setID: String, width: CGFloat = 34, preloaded: NSImage? = nil) {
        self.setID = setID
        self.width = width
        self.preloaded = preloaded
        // 메모리나 디스크에 있으면 첫 렌더부터 그려 둔다. task 를 기다리면 한 프레임
        // 빈 상자가 스치고, 목록을 오르내릴 때마다 그 깜빡임이 반복된다.
        _image = State(initialValue: preloaded ?? CardImageLoader.readyPackImage(setID: setID))
    }

    private var height: CGFloat { (width / 0.55).rounded() }

    var body: some View {
        ZStack {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fit)
            } else {
                RoundedRectangle(cornerRadius: width * 0.08)
                    .fill(Color.secondary.opacity(0.12))
                    .overlay(
                        Image(systemName: "shippingbox")
                            .font(.system(size: width * 0.34))
                            .foregroundStyle(.tertiary)
                    )
            }
        }
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: width * 0.06))
        .task(id: setID) {
            guard image == nil else { return }   // 번들·미리 받기로 이미 채워졌다
            let fetched = await CardImageLoader.packImage(setID: setID)
            // 빈 상자 자리에 늦게 온 팩 그림은 짧게 떠오른다.
            withAnimation(.easeOut(duration: 0.2)) { image = fetched }
        }
    }
}
