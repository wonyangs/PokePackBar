import AppKit
import SwiftUI
/// 카드 이미지를 받아 로컬(Application Support)에 캐시한다. 번들에 포함하지 않는다.
///
/// 전체 카드 이미지는 세트 10종만 해도 229MB 라 배포에 넣을 수 없다.
/// 사용자가 실제로 뽑은 카드만 받으므로 실사용 캐시는 수십 MB 수준에 머문다.
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

    static let cacheDir: URL = {
        let d = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("PokePackBar/cards")
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
        await data(key: Self.cacheKey(cardID: cardID, hires: hires),
                   url: CardImageSource.url(cardID: cardID, hires: hires))
    }

    /// 세트의 부스터 팩 아트.
    func packData(setID: String) async -> Data? {
        await data(key: Self.packCacheKey(setID: setID), url: CardImageSource.packURL(setID: setID))
    }

    /// 디스크에 이미 받아 둔 팩 아트. 없으면 nil — 네트워크를 타지 않는다.
    static func cachedPackData(setID: String) -> Data? {
        try? Data(contentsOf: file(for: packCacheKey(setID: setID)))
    }

    /// 카드와 팩이 같은 캐시·중복요청 억제를 쓴다. 키와 주소만 다르다.
    private func data(key: String, url source: URL?) async -> Data? {

        if let d = mem[key] { touch(key); return d }

        let file = Self.file(for: key)
        if let d = try? Data(contentsOf: file), !d.isEmpty { remember(key, d); return d }

        if let existing = inFlight[key] { return await existing.value }

        let task = Task<Data?, Never> {
            guard let url = source else { return nil }
            guard let (d, resp) = try? await URLSession.shared.data(from: url),
                  (resp as? HTTPURLResponse)?.statusCode == 200, !d.isEmpty else { return nil }
            return d
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

@MainActor
enum CardImageLoader {

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
        if let image = readCache(cardID: cardID, hires: hires) { return image }
        // 큰 그림이 없으면 작은 그림으로라도 그린다 — 아래 `image(cardID:hires:)` 와 같은 이유다.
        return hires ? readCache(cardID: cardID, hires: false) : nil
    }

    private static func readCache(cardID: String, hires: Bool) -> NSImage? {
        let key = CardImageStore.cacheKey(cardID: cardID, hires: hires)
        let f = CardImageStore.cacheDir.appendingPathComponent("\(key).webp")
        guard let d = try? Data(contentsOf: f), let img = NSImage(data: d) else { return nil }
        return img
    }

    /// **큰 그림이 없으면 작은 그림으로 물러난다.**
    ///
    /// 큰 그림은 장당 160KB 라 17,666장을 다 올리면 2.8GB 다(작은 그림은 전부 합쳐 480MB).
    /// 스토리지 한도가 1GB 이므로 새로 넣은 세트는 작은 그림만 올린다. 물러나지 않으면
    /// 개봉 연출과 카드 상세가 그 세트에서 **빈 자리**가 된다 — 조금 흐린 그림이 훨씬 낫다.
    static func image(cardID: String, hires: Bool) async -> NSImage? {
        if let d = await CardImageStore.shared.data(cardID: cardID, hires: hires) {
            return NSImage(data: d)
        }
        guard hires,
              let d = await CardImageStore.shared.data(cardID: cardID, hires: false) else {
            return nil
        }
        return NSImage(data: d)
    }

    /// 곧바로 내놓을 수 있는 팩 아트. 메모리에 있거나 번들에 있으면 기다릴 것이 없다.
    ///
    /// 팩이 130개가 되면서 번들에서 뺐다 — 열 장에 615KB 였으니 130개면 10.5MB 이고,
    /// 앱 전체가 2.2MB 다. 카드 그림과 같은 길(네트워크 → 디스크 캐시)로 보낸다.
    /// 대신 **디코딩한 것을 메모리에 들고 있는다.** 목록을 오르내릴 때마다 디스크에서
    /// 읽어 다시 디코딩하면 그만큼 버벅인다.
    static func readyPackImage(setID: String) -> NSImage? {
        if let cached = packCache[setID] { return cached }
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
        guard !cardIDs.isEmpty else { return [:] }
        return await withTaskGroup(of: (String, NSImage?)?.self) { group in
            for id in Set(cardIDs) {
                group.addTask { (id, await image(cardID: id, hires: hires)) }
            }
            group.addTask {
                try? await Task.sleep(for: timeout)
                return nil   // 마감 신호
            }

            var out: [String: NSImage] = [:]
            var remaining = Set(cardIDs).count
            for await result in group {
                guard let result else { group.cancelAll(); break }   // 마감
                if let img = result.1 { out[result.0] = img }
                remaining -= 1
                if remaining == 0 { group.cancelAll(); break }
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
                return
            }
            if let cached = CardImageLoader.cachedImage(cardID: cardID, hires: hires) {
                image = cached; imageKey = wanted
                return
            }
            let fetched = await CardImageLoader.image(cardID: cardID, hires: hires)
            guard wanted == key else { return }   // 받는 동안 다른 카드로 넘어갔다
            image = fetched; imageKey = wanted
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
            image = await CardImageLoader.packImage(setID: setID)
        }
    }
}
