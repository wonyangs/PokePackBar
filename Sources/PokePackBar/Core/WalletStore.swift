import Foundation
import Observation

/// 보너스 팩 판정 입력 — 프로바이더 무관 한도 창 1개.
///
/// 기존 사탕 지급 경로가 쓰던 창 추상을 카드 게임 이름으로 옮긴 것이다.
/// 휘발 필드(리셋 시각 등)를 key 에 넣지 않는다 — 창을 안정적으로 식별해야
/// "이미 지급했는지" 판정이 재시작을 건너서도 유지된다.
struct BonusWindow: Sendable {
    let key: String
    let name: String
    let kind: WindowClass
    let utilization: Double   // 0~100+
}

/// 보너스 팩 지급 1건. 순수 판정 결과라 부수효과와 분리해 검증할 수 있다.
struct PackGrant: Equatable, Sendable {
    let windowKey: String
    let windowName: String
    let setID: String
    let count: Int
}

/// 이번 개봉으로 다 모인 도감 1건. 개봉 결과 화면이 이걸 받아 알린다.
/// 보상은 여기서 주지 않는다 — 수령은 도감 화면에서 사용자가 직접 누른다.
struct DexCompletion: Equatable, Sendable, Identifiable {
    let dexID: String
    let name: DexText
    let tier: Int

    var id: String { dexID }
}

/// 재화(토큰) 지갑과 카드·팩 보유량을 관리한다.
///
/// 사용량 적립 로직은 기존 컴패니언 저장소의 것을 그대로 옮겼다. 프로바이더별 장부,
/// 날짜 전환, 역행 시 개별 rebase 는 실제 결함을 고쳐 온 산물이라 재설계하지 않는다.
/// 컴패니언 관련 분기(알 인큐베이션·진화 진행)만 걷어냈다.
@MainActor
@Observable
final class WalletStore {

    private(set) var state = GameState()
    private let fileURL: URL

    /// 개봉 결과 등 UI 가 한 번만 소비해야 하는 알림. nil 이면 표시할 것이 없다.
    var lastGrant: PackGrant?
    func consumeGrant() { lastGrant = nil }

    /// 조합 도감 목록. 테스트가 갈아 끼울 수 있게 주입받는다.
    let dexes: [Dex]

    /// 완성한 도감에서 나온 영구 혜택.
    ///
    /// 매번 다시 모으지 않고 캐시한다 — 팩 가격과 확률표가 화면을 그릴 때마다 읽고,
    /// 사용량 적립도 매 새로고침마다 읽는다.
    private(set) var perks: DexPerks = .none

    init(fileURL: URL? = nil, dexes: [Dex]? = nil) {
        self.fileURL = fileURL ?? Self.defaultURL()
        self.dexes = dexes ?? DexIndex.loadBundled().dexes
        load()
        perks = DexPerks.total(completed: claimedDexIDs, dexes: self.dexes)
    }

    static func defaultURL() -> URL {
        // 상태 파일 위치. `PPB_STATE_DIR` 환경변수가 있으면 그 디렉토리를 쓴다 — 개발·QA 격리용.
        // 공백만 있는 값은 무시한다(상대경로로 해석되는 것 방지).
        let override = (ProcessInfo.processInfo.environment["PPB_STATE_DIR"] ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let dir: URL
        if !override.isEmpty {
            dir = URL(fileURLWithPath: override, isDirectory: true)
        } else {
            dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("PokePackBar")
        }
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("game-state.json")
    }

    var l: L { L(state.language) }
    var language: AppLanguage { state.language }
    func setLanguage(_ lang: AppLanguage) { state.language = lang; save() }

    // MARK: 재화

    /// 상점에서 쓸 수 있는 토큰 = 누적 사용량 − 지출 + 갈아 돌려받은 것 + 도감 혜택 적립분.
    var availableTokens: Int {
        max(0, state.usedSinceInstall - state.spentTokens + state.refundedTokens + state.perkTokens)
    }

    var usedSinceInstall: Int { state.usedSinceInstall }

    /// 설치 기준선이 아직 안 잡혔는가 — 사용량 데이터가 한 번도 도착하지 않은 상태.
    /// UI 가 "아직 0" 과 "측정 시작 전" 을 구분해 안내할 수 있게 노출한다.
    var awaitingFirstUsage: Bool { !state.installBaselineSet }

    /// 재화를 차감한다. 잔액이 부족하면 아무것도 하지 않고 false.
    @discardableResult
    func spend(_ amount: Int) -> Bool {
        guard amount > 0, availableTokens >= amount else { return false }
        state.spentTokens += amount
        save()
        return true
    }

    // MARK: 사용량 적립

    /// 사용량 갱신. 앱 델리게이트가 매 새로고침마다 호출한다.
    ///
    /// `hasUsageData` 는 표시용 스냅샷 존재 여부이고, 전달된 map 은 오늘 날짜가 확인된
    /// 프로바이더 데이터만 담는다. 오래된 스냅샷이나 오늘 값이 없는 갱신은
    /// 장부 기준점을 움직일 관측으로 취급하지 않는다.
    func update(todayTokensByProvider: [String: Int], todayDate: String, hasUsageData: Bool) {
        let hasCurrentProviderData = hasUsageData && !todayTokensByProvider.isEmpty

        if !state.installBaselineSet {
            // 설치 기준선 — 실제 데이터가 도착한 시점의 오늘 값을 기준으로 잡는다.
            // 그 전의 과거 사용량은 재화로 세지 않는다.
            guard hasCurrentProviderData else { return }
            state.installBaselineSet = true
            state.claimedTodayTokensByProvider = todayTokensByProvider
            state.lastDate = todayDate
            AppLog.write("wallet install baseline set date=\(todayDate)")
            save()
            return
        }

        // 유효한 사용량이 있는 갱신만 장부를 움직인다. 빈 갱신으로 날짜·장부를 건드리면
        // 다음 정상 스냅샷을 당일 전체 신규 사용량으로 오인할 수 있다.
        guard hasCurrentProviderData else { return }

        let dateChanged = todayDate != state.lastDate

        if state.claimedTodayTokensByProvider == nil {
            // 아직 프로바이더별로 분해된 기준값이 없다. 첫 유효 관측을 기준점으로만 저장하고
            // 과거 사용량을 소급 지급하지 않는다.
            state.claimedTodayTokensByProvider = todayTokensByProvider
            state.lastDate = todayDate
            AppLog.write("wallet ledger seeded date=\(todayDate) providers=\(todayTokensByProvider.keys.sorted().joined(separator: ","))")
        } else if dateChanged {
            // 일자별 스냅샷은 서로 비교할 수 없다. 새 날짜에는 현재 누적값 전체를 그 날짜의
            // 사용량으로 적립한다.
            //
            // 이전 날짜에 알려졌던 프로바이더가 첫 새로고침에서 빠질 수 있다(오늘 데이터 없음,
            // 오래된 응답, 일시 실패). 그 프로바이더를 장부에서 아예 제거하면 같은 날짜에
            // 복구될 때 현재 누적값을 "이미 적립한 값" 으로 seed 해 사용량이 누락된다.
            // 그래서 알려진 프로바이더의 새 날짜 기준을 0 으로 열어 둔다.
            state.lastDate = todayDate
            var newLedger = Dictionary(uniqueKeysWithValues:
                state.claimedTodayTokensByProvider!.keys.map { ($0, 0) })
            for (providerID, current) in todayTokensByProvider {
                newLedger[providerID] = current
            }
            state.claimedTodayTokensByProvider = newLedger
            let delta = todayTokensByProvider.values.reduce(0, +)
            if delta > 0 { accrue(delta) }
        } else {
            var ledger = state.claimedTodayTokensByProvider ?? [:]
            var delta = 0
            for (providerID, current) in todayTokensByProvider {
                guard let previous = ledger[providerID] else {
                    // 새로 관측된 프로바이더의 과거 로그를 소급하지 않는다. 다음 갱신부터
                    // 증가분을 추적할 수 있도록 현재 값을 seed 한다.
                    ledger[providerID] = current
                    continue
                }
                if current < previous {
                    // 전체 합계가 아니라 해당 프로바이더의 줄만 rebase 한다. 다른 프로바이더가
                    // 이번 갱신에서 보고하지 않았다면 map 에 줄 자체가 없으므로 기준값을 건드리지 않는다.
                    ledger[providerID] = current
                    AppLog.write("wallet usage regression provider=\(providerID) date=\(todayDate) previous=\(previous) current=\(current) drop=\(previous - current) — rebased provider ledger")
                    continue
                }
                delta += current - previous
                ledger[providerID] = current
            }
            state.claimedTodayTokensByProvider = ledger
            if delta > 0 { accrue(delta) }
        }

        save()
    }

    /// 사용량 증가분을 장부에 넣는다. 도감 혜택이 있으면 그만큼 별도로 더 쌓는다.
    ///
    /// `usedSinceInstall` 에 배수를 곱하지 않는 이유: 그 값은 실제 사용량이라
    /// 곱해 버리면 사용량 표시가 거짓이 된다. 잔액에만 반영한다.
    private func accrue(_ delta: Int) {
        state.usedSinceInstall += delta
        guard perks.tokenGain > 0 else { return }
        let bonus = Int((Double(delta) * perks.tokenGain).rounded())
        if bonus > 0 { state.perkTokens += bonus }
    }

    // MARK: 팩 보유량

    func packCount(setID: String) -> Int { state.packs[setID] ?? 0 }

    var totalPackCount: Int { state.packs.values.reduce(0, +) }

    /// 보유한 팩 — 개수가 0 이 아닌 것만, 세트 ID 순.
    var ownedPacks: [(setID: String, count: Int)] {
        state.packs.filter { $0.value > 0 }
            .sorted { $0.key < $1.key }
            .map { (setID: $0.key, count: $0.value) }
    }

    func addPack(setID: String, count: Int = 1) {
        guard count > 0 else { return }
        state.packs[setID, default: 0] += count
        save()
    }

    /// 팩 1개를 소비한다. 보유량이 없으면 false — 호출부는 개봉을 진행하지 않는다.
    @discardableResult
    func consumePack(setID: String) -> Bool {
        let owned = state.packs[setID] ?? 0
        guard owned > 0 else { return false }
        if owned == 1 { state.packs.removeValue(forKey: setID) } else { state.packs[setID] = owned - 1 }
        state.packsOpened += 1
        save()
        return true
    }

    // MARK: 카드 갈기

    /// 갈 수 있는 장수 — 보유분에서 한 장은 남긴다. 컬렉션에서 사라지면 안 된다.
    func spareCount(_ cardID: String) -> Int { max(0, cardCount(cardID) - 1) }

    /// 중복분을 판다. 받은 액수를 반환하고, 팔 것이 없으면 0.
    ///
    /// 시세 그대로 값을 쳐 준다(도감 판매 추가금이 있으면 그만큼 더). 마지막 한 장은
    /// 남긴다 — 수집한 카드가 컬렉션에서 없어지는 것은 되돌릴 수 없고, 실수로 그렇게 되면
    /// 잃은 것이 크다.
    @discardableResult
    func sellSpares(cardID: String, tier: CardTier, count: Int) -> Int {
        let spare = spareCount(cardID)
        let amount = min(max(count, 0), spare)
        guard amount > 0 else { return 0 }

        state.cards[cardID] = cardCount(cardID) - amount
        let refund = CardSale.price(cardID: cardID, perks: perks) * amount
        state.refundedTokens += refund
        state.cardsDisenchanted += amount
        save()
        AppLog.write("sold \(amount)x \(cardID) (\(tier.rawValue)) for \(refund)")
        return refund
    }

    // MARK: 최애 카드 (메뉴바)

    var favoriteCardID: String? { state.favoriteCardID }

    /// 최애 카드를 지정한다. 갖고 있지 않은 카드는 받지 않는다 —
    /// 메뉴바에 못 그리는 카드를 가리킨 채로 두면 아이콘이 조용히 사라진다.
    func setFavorite(_ cardID: String?) {
        if let cardID, cardCount(cardID) == 0 { return }
        guard state.favoriteCardID != cardID else { return }
        state.favoriteCardID = cardID
        save()
        AppLog.write("favorite card = \(cardID ?? "none")")
    }

    /// 메뉴바에 올릴 카드. 최애 → 최고 등급 → 없음.
    func menuBarCard(index: CardIndex?) -> CardEntry? {
        MenuBarCard.resolve(favorite: state.favoriteCardID, owned: state.cards, index: index)
    }

    // MARK: 카드 보유량

    func cardCount(_ cardID: String) -> Int { state.cards[cardID] ?? 0 }

    var distinctCardCount: Int { state.cards.count }

    var totalCardCount: Int { state.cards.values.reduce(0, +) }

    /// 모은 카드를 지금 시세로 매긴 총액(달러). 중복도 장수만큼 센다.
    ///
    /// "몇 장 모았나" 만으로는 컬렉션이 자라는 감각이 약하다. 1999년 커먼 한 장이 최신
    /// SR 보다 비싸기도 해서, 장수와 값이 서로 다른 이야기를 한다.
    func collectionValueUSD(prices: CardPrices? = CardPrices.shared) -> Double {
        let owned = state.cards.reduce(0.0) { running, entry in
            running + MarketEconomy.usd(cardID: entry.key, prices: prices) * Double(entry.value)
        }
        let held = unrevealed.reduce(0.0) { running, entry in
            running + MarketEconomy.usd(cardID: entry.key, prices: prices) * Double(entry.value)
        }
        return max(0, owned - held)
    }

    // MARK: 개봉 연출 중 값 감추기

    /// 아직 뒤집어 보지 않은 카드. 컬렉션 가치 **표시에서만** 뺀다.
    ///
    /// 카드는 뽑는 순간 수집함에 들어간다 — 연출이 끝날 때까지 미루면 도중에 팝오버를 닫는
    /// 순간 뽑은 카드가 사라진다. 그런데 머리글의 컬렉션 가치는 늘 보이므로, 값이 먼저
    /// 올라가면 무엇이 나왔는지 카드를 뒤집기 전에 알게 된다. 그래서 값만 늦춘다.
    ///
    /// 저장하지 않는다. 앱을 다시 켜면 이미 다 본 것으로 친다 — 연출은 그 자리에서 끝난다.
    private(set) var unrevealed: [String: Int] = [:]

    /// 이 카드들을 아직 안 본 것으로 둔다.
    func holdForReveal(_ cardIDs: [String]) {
        var held: [String: Int] = [:]
        for id in cardIDs { held[id, default: 0] += 1 }
        unrevealed = held
    }

    /// 한 장을 봤다.
    func markRevealed(_ cardID: String) {
        guard let count = unrevealed[cardID] else { return }
        if count <= 1 { unrevealed.removeValue(forKey: cardID) } else { unrevealed[cardID] = count - 1 }
    }

    /// 남은 전부를 봤다 — 요약 화면은 카드를 한꺼번에 보여 준다.
    func markAllRevealed() {
        guard !unrevealed.isEmpty else { return }
        unrevealed = [:]
    }

    /// 개봉 결과를 수집함에 넣는다. 같은 카드가 여러 장 나오면 그만큼 쌓인다.
    ///
    /// 새로 완성된 도감을 함께 처리하고 그 목록을 돌려준다. 카드가 들어오는 경로가
    /// 여기뿐이라 판정을 여기 두면 호출부가 잊을 수 없다 — 화면마다 판정을 심으면
    /// 언젠가 한 곳이 빠지고, 그 화면으로 얻은 카드는 도감을 완성시키지 못한다.
    @discardableResult
    func collect(_ cardIDs: [String]) -> [DexCompletion] {
        guard !cardIDs.isEmpty else { return [] }
        let before = Set(state.cards.keys)
        for id in cardIDs { state.cards[id, default: 0] += 1 }
        save()

        return DexProgress.newlyFilled(dexes: dexes, owned: { (state.cards[$0] ?? 0) > 0 },
                                       claimed: claimedDexIDs, before: before)
            .map { DexCompletion(dexID: $0.id, name: $0.name, tier: $0.tier) }
    }

    /// 세트의 천장 카운터. 개봉이 이 값을 읽고, 개봉 후 `setPity` 로 되돌려 준다.
    func pity(setID: String) -> Int { state.packPity[setID] ?? 0 }

    func setPity(_ value: Int, setID: String) {
        if value == 0 { state.packPity.removeValue(forKey: setID) } else { state.packPity[setID] = value }
        save()
    }

    // MARK: 오리파

    /// 지금 걸려 있는 박스. 없으면 새로 채운다.
    ///
    /// 화면을 그릴 때마다 호출되므로 이미 있으면 그대로 돌려준다. 박스를 새로 채우는 것은
    /// 처음 열 때와 다 팔렸을 때뿐이다.
    func oripaBox(index: CardIndex) -> OripaBox {
        if let box = state.oripa, !box.isEmpty { return box }
        var generator = SystemRandomNumberGenerator()
        let box = Oripa.makeBox(index: index, serial: (state.oripa?.serial ?? 0) + 1,
                                using: &generator)
        state.oripa = box
        save()
        return box
    }

    /// 박스를 버리고 새로 받는다. 값은 받지 않는다.
    ///
    /// 마음에 안 드는 박스를 비우려면 100슬롯을 다 사야 한다면, 그건 30억을 태워야 진열이
    /// 바뀐다는 뜻이라 기능이 아니라 함정이다. 실제 오리파 사이트도 박스를 여러 개 늘어놓고
    /// 고르게 한다.
    ///
    /// 무료로 둬도 기댓값이 오르지 않는다 — 뽑기는 남은 슬롯에서 균등 추첨이라 새 박스든
    /// 뽑던 박스든 한 번 뽑기의 기댓값이 같다. 교체로 얻는 것은 "원하는 카드가 든 박스를
    /// 고를 수 있다" 는 것뿐이고, 그 카드를 실제로 뽑으려면 여전히 100슬롯을 헤쳐야 한다.
    func replaceOripaBox(index: CardIndex) {
        var generator = SystemRandomNumberGenerator()
        let serial = (state.oripa?.serial ?? 0) + 1
        state.oripa = Oripa.makeBox(index: index, serial: serial, using: &generator)
        save()
        AppLog.write("oripa box replaced serial=\(serial)")
    }

    /// 오리파 슬롯 값. 팩 할인 혜택이 여기에도 걸린다 — 같은 상점에서 사는 물건이다.
    func oripaPrice(index: CardIndex? = CardIndex.shared) -> Int {
        let base = index.map { OripaConfig.slotPrice(index: $0) } ?? 30_000_000
        guard perks.packDiscount > 0 else { return base }
        return max(1, Int((Double(base) * (1 - perks.packDiscount)).rounded()))
    }

    /// 한 슬롯을 뽑는다. 잔액이 모자라면 아무것도 하지 않고 nil.
    ///
    /// 차감을 먼저 한다. 뽑기가 먼저면 실패했을 때 카드만 나가고 값을 못 받는다.
    @discardableResult
    func pullOripa(index: CardIndex) -> (card: PulledCard, completions: [DexCompletion])? {
        var box = oripaBox(index: index)
        guard !box.isEmpty, spend(oripaPrice(index: index)) else { return nil }

        var generator = SystemRandomNumberGenerator()
        guard let id = Oripa.pull(from: &box, using: &generator) else { return nil }
        let isNew = cardCount(id) == 0
        state.oripa = box
        let completions = collect([id])   // 저장까지 여기서 한다
        // 가림막을 걷기 전까지는 값을 올리지 않는다 — 오리파도 뒤집어 보는 연출이다.
        holdForReveal([id])
        AppLog.write("oripa pulled \(id) box=\(box.serial) remaining=\(box.remaining)")
        return (PulledCard(id: id, tier: index.card(id)?.tier ?? .doubleRare, isNew: isNew),
                completions)
    }

    // MARK: 조합 도감

    /// 보상까지 받은 도감. 혜택은 이 목록에서만 나온다.
    var claimedDexIDs: Set<String> { Set(state.claimedDex) }

    var claimedDexCount: Int { state.claimedDex.count }

    /// 지금 보유 카드로 다 모였고 아직 수령하지 않은 도감.
    ///
    /// 완성 여부를 저장하지 않고 매번 보유 카드에서 계산한다 — 도감 기능이 생기기 전에
    /// 모아 둔 카드도 그래야 완성으로 잡힌다. 이벤트로만 기록하면 그런 도감은 영영 안 뜬다.
    var claimableDexes: [Dex] {
        dexes.filter { dex in
            !claimedDexIDs.contains(dex.id) && dex.cards.allSatisfy { (state.cards[$0] ?? 0) > 0 }
        }
    }

    /// 보상을 수령한다. 팩을 주고 혜택을 켠다.
    ///
    /// 두 번 주면 도감으로 팩을 무한히 만들 수 있으므로 이미 수령한 것은 거른다.
    /// 다 모으지 못한 도감도 거른다 — 화면이 잘못 눌러도 지급되지 않아야 한다.
    @discardableResult
    func claim(_ dexID: String) -> Dex? {
        guard let dex = dexes.first(where: { $0.id == dexID }),
              !claimedDexIDs.contains(dexID),
              dex.cards.allSatisfy({ (state.cards[$0] ?? 0) > 0 }) else { return nil }

        state.claimedDex.append(dexID)
        if dex.reward.packs > 0 { state.packs[dex.homeSet, default: 0] += dex.reward.packs }
        // 혜택은 즉시 반영한다 — 수령 직후의 구매·개봉부터 적용되어야 보상으로 읽힌다.
        perks = DexPerks.total(completed: claimedDexIDs, dexes: dexes)
        save()
        AppLog.write("dex claimed \(dexID) tier=\(dex.tier) packs=\(dex.reward.packs)")
        return dex
    }

    // MARK: 보너스 팩 (한도 달성 보상)

    /// 지급 판정 — 한도 창이 100% 를 새로 넘어선 순간에만 지급한다.
    ///
    /// - 100% 미만이면 맵에서 제거해 다시 무장한다.
    /// - 이미 지급한 창은 재지급하지 않는다.
    /// - 세트는 주어진 목록에서 무작위로 하나 고른다. 난수 생성기를 주입받아 검증 가능하게 둔다.
    ///
    /// 부수효과(보유량 증가·알림)와 분리했다.
    static func evaluateGrants(
        windows: [BonusWindow],
        grantTier: inout [String: Int],
        availableSets: [String],
        using generator: inout some RandomNumberGenerator
    ) -> [PackGrant] {
        guard !availableSets.isEmpty else { return [] }
        var grants: [PackGrant] = []
        for w in windows {
            guard w.utilization >= 100 else { grantTier[w.key] = nil; continue }
            guard (grantTier[w.key] ?? 0) < 1 else { continue }
            grantTier[w.key] = 1
            // 한도 종류와 무관하게 1개다. 세션 한도가 주간보다 자주 차므로,
            // 주간에 가중을 주면 보상이 세션 쪽으로 쏠린다.
            let setID = availableSets[Int(generator.next(upperBound: UInt64(availableSets.count)))]
            grants.append(PackGrant(windowKey: w.key, windowName: w.name,
                                    setID: setID, count: PackConfig.bonusPackCount))
        }
        return grants
    }

    /// 한도 창 상태로부터 보너스 팩을 지급한다. 매 새로고침 완료 시(한도 로드 후) 호출한다.
    ///
    /// - 첫 실행에는 지급 없이 현재 100% 인 창만 시드한다. 설치 직후 이미 차 있던 창에
    ///   소급 지급하지 않기 위한 것이다.
    /// - 한도가 아직 로드되지 않았으면 시드도 지급도 하지 않고 다음 새로고침에 재시도한다.
    @discardableResult
    func grantBonusPacks(from windows: [BonusWindow], limitsReady: Bool,
                         availableSets: [String]) -> [PackGrant] {
        guard limitsReady, !availableSets.isEmpty else { return [] }

        if !state.packGrantSeeded {
            for w in windows where w.utilization >= 100 { state.packGrantTier[w.key] = 1 }
            state.packGrantSeeded = true
            save()
            return []
        }

        let before = state.packGrantTier
        var generator = SystemRandomNumberGenerator()
        let grants = Self.evaluateGrants(windows: windows, grantTier: &state.packGrantTier,
                                         availableSets: availableSets, using: &generator)
        for g in grants {
            state.packs[g.setID, default: 0] += g.count
            lastGrant = g
            AppLog.write("bonus packs granted window=\(g.windowKey) set=\(g.setID) count=\(g.count)")
        }

        // 지급이 없어도 재무장(창이 100% 아래로 내려가 맵에서 제거된 것)은 영속해야 한다.
        // 안 하면 재시작 시 남아 있는 지급 표시 때문에 다음 100% 도달이 "이미 지급" 으로 오판된다.
        if !grants.isEmpty || state.packGrantTier != before { save() }
        return grants
    }

    // MARK: 영속

    private func load() {
        guard let data = try? Data(contentsOf: fileURL) else { return }   // 파일 없음 = 신규 설치
        guard let decoded = try? JSONDecoder().decode(GameState.self, from: data) else {
            // 디코드 실패(전면 손상) → 새로 시작하되, 다음 저장이 원본을 덮어써 영구 유실되기 전에
            // 보존해 수동 복구 여지를 남긴다.
            let backup = fileURL.appendingPathExtension("corrupt")
            try? FileManager.default.removeItem(at: backup)
            try? FileManager.default.moveItem(at: fileURL, to: backup)
            AppLog.write("game state decode failed — original backed up to \(backup.lastPathComponent), starting fresh")
            return
        }
        state = decoded
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(state) else { return }
        try? data.write(to: fileURL, options: .atomic)   // 부분 쓰기 손상 방지
    }
}
