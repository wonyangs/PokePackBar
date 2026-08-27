import XCTest
@testable import PokePackBar

final class PackOpeningTests: XCTestCase {

    /// 계층별 장수를 지정해 인덱스를 만든다.
    private func makeIndex(_ setID: String, _ counts: [CardTier: Int]) -> CardIndex {
        var rows: [[String]] = []
        var n = 0
        for (tier, count) in counts.sorted(by: { $0.key.rawValue < $1.key.rawValue }) {
            for _ in 0..<count {
                n += 1
                rows.append(["\(setID)-\(n)", "Card \(n)", tier.rawValue])
            }
        }
        let payload: [String: Any] = [
            "version": 1,
            "sets": [["id": setID, "name": setID, "released": "2000/01/01", "cardCount": n]],
            "cards": rows,
        ]
        let data = try! JSONSerialization.data(withJSONObject: payload)
        return CardIndex.decode(data)!
    }

    /// 실제 배포되는 인덱스. 번들 리소스가 빠지거나 계층 이름이 어긋나면 여기서 드러난다.
    private func bundledIndex() throws -> CardIndex {
        try XCTUnwrap(CardIndex.loadBundled(), "번들에 카드 인덱스가 없다")
    }

    // MARK: 인덱스

    func testBundledIndexLoadsWithExpectedSets() throws {
        let index = try bundledIndex()
        XCTAssertEqual(index.sets.count, 10)
        XCTAssertEqual(index.cards.count, 1284)
        // 세트 ID 가 카드 ID 접두사와 맞아야 풀이 구성된다.
        for s in index.sets {
            XCTAssertFalse((index.pools[s.id] ?? [:]).isEmpty, "\(s.id) 풀이 비었다")
        }
    }

    /// 계층 문자열이 알 수 없는 값이면 조용히 섞지 않고 건너뛴다.
    func testUnknownTierRowsAreSkipped() {
        let payload: [String: Any] = [
            "version": 1,
            "sets": [["id": "x", "name": "X", "released": "2000/01/01", "cardCount": 2]],
            "cards": [["x-1", "Good", "C"], ["x-2", "Bad", "mythic"], ["noDash", "Bad", "C"]],
        ]
        let data = try! JSONSerialization.data(withJSONObject: payload)
        let index = CardIndex.decode(data)!
        XCTAssertEqual(index.cards.count, 1)
        XCTAssertEqual(index.cards.first?.id, "x-1")
    }

    // MARK: 팩 장수

    func testNormalSetYieldsFullPack() {
        let index = makeIndex("s", [.common: 40, .uncommon: 30, .rare: 15, .doubleRare: 10, .superRare: 5, .ultraRare: 2])
        var g = SeededGenerator(seed: 1)
        let pack = PackOpening.draw(setID: "s", index: index, alreadyOwned: [], using: &g)
        XCTAssertEqual(pack.count, PackConfig.cardsPerPack)
    }

    /// common 이 없는 특별 세트는 작은 팩으로 뽑는다.
    ///
    /// 일반 구성을 적용하면 폴백이 아홉 슬롯을 전부 rare 로 채워, 25장짜리 세트에서
    /// 한 팩이 세트의 40% 를 쏟아내고 팩 안의 등급 차이도 사라진다.
    func testSpecialSetYieldsSmallPackWithTierVariety() {
        let index = makeIndex("cel", [.rare: 12, .doubleRare: 12, .superRare: 1])
        var tiers: Set<CardTier> = []
        for seed in 1...200 {
            var g = SeededGenerator(seed: UInt64(seed))
            let pack = PackOpening.draw(setID: "cel", index: index, alreadyOwned: [], using: &g)
            XCTAssertEqual(pack.count, PackConfig.specialPackSize)
            XCTAssertLessThanOrEqual(pack.count, 4, "특별 세트 팩이 세트를 쏟아내면 안 된다")
            tiers.formUnion(pack.map(\.tier))
        }
        XCTAssertGreaterThan(tiers.count, 1, "팩 안에 등급 차이가 있어야 한다")
    }

    func testUnknownSetYieldsEmptyPack() {
        let index = makeIndex("s", [.common: 10])
        var g = SeededGenerator(seed: 1)
        XCTAssertTrue(PackOpening.draw(setID: "nope", index: index, alreadyOwned: [], using: &g).isEmpty)
    }

    // MARK: 계층 폴백

    /// 그 세트에 없는 계층은 히트 후보에서 빠진다. 빼지 않으면 폴백으로 흘러가 확률이 왜곡된다.
    func testHitNeverYieldsTierAbsentFromSet() {
        // 1999년 세트를 흉내낸다 — ultra·secret 이 없다.
        let pool: [CardTier: [String]] = [.common: ["a"], .uncommon: ["b"], .rare: ["c"], .doubleRare: ["d"]]
        for seed in 1...500 {
            var g = SeededGenerator(seed: UInt64(seed))
            let tier = PackOpening.hitTier(available: pool, using: &g)
            XCTAssertTrue(tier == .rare || tier == .doubleRare, "없는 계층 \(tier) 이 나왔다")
        }
    }

    /// 요청한 계층이 비어 있으면 폴백 체인을 따라가 슬롯을 비우지 않는다.
    func testPickFallsBackWhenTierEmpty() {
        let pool: [CardTier: [String]] = [.rare: ["r1"], .doubleRare: ["h1"]]
        var g = SeededGenerator(seed: 3)
        let picked = PackOpening.pick(tier: .common, from: pool, avoiding: [], using: &g)
        XCTAssertNotNil(picked, "폴백이 없으면 슬롯이 빈다")
    }

    func testPickReturnsNilOnlyWhenPoolEmpty() {
        var g = SeededGenerator(seed: 3)
        XCTAssertNil(PackOpening.pick(tier: .common, from: [:], avoiding: [], using: &g))
    }

    /// 에너지는 다른 계층으로 대체하지 않는다. 없으면 그 슬롯을 일반 카드로 채운다.
    func testEnergySlotOnlyAppearsWhenSetHasEnergy() {
        let withEnergy = makeIndex("e", [.common: 20, .uncommon: 20, .rare: 10, .doubleRare: 5, .energy: 6])
        let without = makeIndex("n", [.common: 20, .uncommon: 20, .rare: 10, .doubleRare: 5])
        var g1 = SeededGenerator(seed: 5)
        var g2 = SeededGenerator(seed: 5)

        let a = PackOpening.draw(setID: "e", index: withEnergy, alreadyOwned: [], using: &g1)
        let b = PackOpening.draw(setID: "n", index: without, alreadyOwned: [], using: &g2)
        XCTAssertEqual(a.filter { $0.tier == .energy }.count, 1)
        XCTAssertEqual(b.filter { $0.tier == .energy }.count, 0)
        XCTAssertEqual(b.count, PackConfig.cardsPerPack)
    }

    // MARK: 신규 판정

    func testIsNewReflectsExistingCollection() {
        let index = makeIndex("s", [.common: 1, .uncommon: 1, .rare: 1])
        var g = SeededGenerator(seed: 9)
        let owned = Set(index.cards.map(\.id))
        let pack = PackOpening.draw(setID: "s", index: index, alreadyOwned: owned, using: &g)
        XCTAssertFalse(pack.isEmpty)
        XCTAssertTrue(pack.allSatisfy { !$0.isNew }, "이미 가진 카드는 신규가 아니다")

        var g2 = SeededGenerator(seed: 9)
        let fresh = PackOpening.draw(setID: "s", index: index, alreadyOwned: [], using: &g2)
        XCTAssertTrue(fresh.allSatisfy { $0.isNew })
    }

    // MARK: 재현성과 분포

    func testSameSeedYieldsSamePack() {
        let index = try! bundledIndex()
        var g1 = SeededGenerator(seed: 42)
        var g2 = SeededGenerator(seed: 42)
        let a = PackOpening.draw(setID: "sv10", index: index, alreadyOwned: [], using: &g1)
        let b = PackOpening.draw(setID: "sv10", index: index, alreadyOwned: [], using: &g2)
        XCTAssertEqual(a, b)
    }

    /// 히트 계층 분포가 설정한 가중치를 따라간다. 확률표를 건드리면 여기서 드러난다.
    func testHitDistributionApproximatesConfiguredWeights() {
        // 가중치에 등장하는 등급을 모두 담아야 재정규화가 개입하지 않는다.
        // 하나라도 빠지면 그 등급의 가중치가 나머지로 분배되어 분포가 어긋난다.
        let pool: [CardTier: [String]] = Dictionary(
            uniqueKeysWithValues: PackConfig.hitWeights.map { ($0.tier, ["\($0.tier.rawValue)-1"]) })
        var counts: [CardTier: Int] = [:]
        let trials = 20_000
        for seed in 1...trials {
            var g = SeededGenerator(seed: UInt64(seed))
            counts[PackOpening.hitTier(available: pool, using: &g), default: 0] += 1
        }
        let total = Double(trials)
        for (tier, weight) in PackConfig.hitWeights {
            let observed = Double(counts[tier] ?? 0) / total * 100
            XCTAssertEqual(observed, Double(weight), accuracy: 2.0,
                           "\(tier) 기대 \(weight)% 관측 \(String(format: "%.1f", observed))%")
        }
    }

    /// 배포되는 모든 세트에서 팩이 정상적으로 나온다. 계층이 빈 세트가 섞여 있어도 빈 팩이 없어야 한다.
    func testEverySetProducesNonEmptyPack() throws {
        let index = try bundledIndex()
        for s in index.sets {
            var g = SeededGenerator(seed: 11)
            let pack = PackOpening.draw(setID: s.id, index: index, alreadyOwned: [], using: &g)
            XCTAssertFalse(pack.isEmpty, "\(s.id) 에서 빈 팩이 나왔다")
            XCTAssertLessThanOrEqual(pack.count, PackConfig.cardsPerPack)
        }
    }
}

final class CardImageSourceTests: XCTestCase {

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: "cardImageBaseURL")
        super.tearDown()
    }

    /// 카드 ID 에서 세트를 떼어 경로를 만든다. 업로드 때 오브젝트 이름을 카드 ID 로
    /// 통일했기 때문에 가능한 것이다 — 원본 CDN 은 파일명이 카드 번호와도 ID 와도
    /// 어긋나는 카드가 있어 경로를 추론할 수 없었다.
    func testBuildsPathFromCardID() throws {
        UserDefaults.standard.set("https://example.test/public", forKey: "cardImageBaseURL")
        let small = try XCTUnwrap(CardImageSource.url(cardID: "sv8pt5-1", hires: false))
        let hires = try XCTUnwrap(CardImageSource.url(cardID: "sv8pt5-1", hires: true))
        XCTAssertEqual(small.absoluteString, "https://example.test/public/cards/sv8pt5/sv8pt5-1.webp")
        XCTAssertEqual(hires.absoluteString, "https://example.test/public/cards/sv8pt5/sv8pt5-1_hires.webp")
    }

    /// 하이픈이 여러 개인 카드 ID 에서도 세트는 첫 하이픈 앞까지다.
    func testSetIDIsPrefixBeforeFirstDash() throws {
        UserDefaults.standard.set("https://example.test/public", forKey: "cardImageBaseURL")
        let url = try XCTUnwrap(CardImageSource.url(cardID: "cel25c-15_A1", hires: false))
        XCTAssertEqual(url.absoluteString, "https://example.test/public/cards/cel25c/cel25c-15_A1.webp")
    }

    /// 기본 주소 끝의 슬래시가 중복 슬래시를 만들지 않아야 한다.
    func testTrailingSlashInBaseIsNormalized() throws {
        UserDefaults.standard.set("https://example.test/public/", forKey: "cardImageBaseURL")
        let url = try XCTUnwrap(CardImageSource.url(cardID: "sv10-1", hires: false))
        XCTAssertFalse(url.absoluteString.contains("//cards"), "슬래시가 중복됐다: \(url)")
    }

    /// 하이픈이 없는 값은 카드 ID 가 아니다. 주소를 만들지 않는다.
    func testRejectsMalformedCardID() {
        UserDefaults.standard.set("https://example.test/public", forKey: "cardImageBaseURL")
        XCTAssertNil(CardImageSource.url(cardID: "nodash", hires: false))
    }

    /// 배포 기본값이 채워져 있어야 한다. 비어 있으면 카드가 한 장도 표시되지 않는다.
    func testDefaultBaseURLIsConfigured() {
        XCTAssertFalse(CardImageSource.defaultBaseURL.isEmpty,
                       "이미지 기본 주소가 비어 있으면 카드가 표시되지 않는다")
        XCTAssertTrue(CardImageSource.defaultBaseURL.hasPrefix("https://"))
    }

    /// 설정이 비어 있으면 기본값으로 돌아간다.
    func testFallsBackToDefaultWhenOverrideBlank() {
        UserDefaults.standard.set("   ", forKey: "cardImageBaseURL")
        XCTAssertEqual(CardImageSource.baseURL, CardImageSource.defaultBaseURL)
    }
}

/// 등급 체계 — 국내 커뮤니티 약칭과 순위, 그리고 그것에 기대는 정렬들.
final class CardTierOrderingTests: XCTestCase {

    /// 선언 순서가 곧 등급 순서다. 생성 스크립트의 TIER_ORDER 와 어긋나면
    /// 인덱스의 등급 문자열이 엉뚱한 순위를 받는다.
    func testRankAscendsInDeclaredOrder() {
        let expected = ["E", "C", "U", "R", "RR", "RRR", "AR", "SR", "SAR", "UR"]
        XCTAssertEqual(CardTier.allCases.map(\.rawValue), expected)
        XCTAssertEqual(CardTier.allCases.map(\.rank), Array(0..<expected.count))
    }

    /// 폴백은 순위가 가까운 등급부터 본다. 같은 거리면 낮은 등급을 먼저 —
    /// 의도보다 희귀한 카드를 얹어 주는 쪽으로 새지 않게 한다.
    func testFallbackPrefersNearestThenLowerTier() {
        let chain = CardTier.artRare.fallbackChain
        XCTAssertEqual(chain.first, .artRare)
        // AR(6) 기준 거리 1 은 RRR(5) 과 SR(7) — 낮은 쪽이 먼저다.
        XCTAssertEqual(Array(chain.dropFirst().prefix(2)), [.tripleRare, .superRare])
        XCTAssertFalse(chain.contains(.energy), "에너지는 등급 대체가 아니다")
    }

    /// 에너지는 다른 등급으로 대체하지 않는다.
    func testEnergyFallsBackOnlyToItself() {
        XCTAssertEqual(CardTier.energy.fallbackChain, [.energy])
    }

    /// 개봉은 등급 오름차순 — 가장 희귀한 카드가 마지막에 나온다.
    func testRevealOrderPutsRarestLast() {
        let cards = [
            PulledCard(id: "a-1", tier: .ultraRare, isNew: true),
            PulledCard(id: "a-2", tier: .common, isNew: true),
            PulledCard(id: "a-3", tier: .doubleRare, isNew: true),
            PulledCard(id: "a-4", tier: .common, isNew: false),
        ]
        let ordered = PackOpening.revealOrder(cards)
        XCTAssertEqual(ordered.map(\.tier), [.common, .common, .doubleRare, .ultraRare])
        // 같은 등급 안에서는 뽑힌 순서 유지
        XCTAssertEqual(ordered.prefix(2).map(\.id), ["a-2", "a-4"])
    }

    /// 실제 팩에서도 마지막 카드가 그 팩의 최고 등급이어야 한다.
    func testDrawnPackRevealsItsBestCardLast() throws {
        let index = try XCTUnwrap(CardIndex.loadBundled())
        for seed in 1...50 {
            var g = SeededGenerator(seed: UInt64(seed))
            let pack = PackOpening.draw(setID: "sv10", index: index, alreadyOwned: [], using: &g)
            let ordered = PackOpening.revealOrder(pack)
            let best = try XCTUnwrap(pack.map(\.tier.rank).max())
            XCTAssertEqual(ordered.last?.tier.rank, best)
        }
    }
}

@MainActor
final class CollectionSortTests: XCTestCase {

    private func entry(_ id: String, _ tier: CardTier) -> CardEntry {
        CardEntry(id: id, name: id, tier: tier, setID: "s")
    }

    /// 보유한 카드가 위로, 그 안에서 희귀한 것이 앞으로.
    func testOwnedFirstThenRarestFirst() {
        let entries = [
            entry("s-1", .common), entry("s-2", .ultraRare),
            entry("s-3", .doubleRare), entry("s-4", .superRare),
        ]
        // 보유: 커먼과 더블레어
        let owned: Set<String> = ["s-1", "s-3"]
        let sorted = CardCollectionView.sorted(entries) { owned.contains($0) }

        XCTAssertEqual(sorted.map(\.id), ["s-3", "s-1", "s-2", "s-4"],
                       "보유분(RR, C)이 먼저 · 그 안에서 희귀도순 · 미보유분도 희귀도순")
    }

    /// 같은 보유 상태·같은 등급이면 카드 ID 로 안정적으로 정렬한다.
    func testStableWithinSameOwnershipAndTier() {
        let entries = [entry("s-9", .rare), entry("s-2", .rare), entry("s-5", .rare)]
        let sorted = CardCollectionView.sorted(entries) { _ in false }
        XCTAssertEqual(sorted.map(\.id), ["s-2", "s-5", "s-9"])
    }
}

@MainActor
final class CardImagePrefetchTests: XCTestCase {

    /// 빈 목록은 네트워크를 타지 않고 즉시 돌아온다.
    /// 카드가 없는 세트에서 개봉을 시도해도 준비 화면에 갇히지 않아야 한다.
    func testEmptyPrefetchReturnsImmediately() async {
        let started = ContinuousClock.now
        let result = await CardImageLoader.prefetch(cardIDs: [], hires: true)
        XCTAssertTrue(result.isEmpty)
        XCTAssertLessThan(started.duration(to: .now), .milliseconds(200))
    }

    /// 이미지 주소가 설정되지 않았으면 받을 수 없다. 그래도 마감 시간까지 기다리지 않고
    /// 곧바로 빈 결과로 끝나야 한다 — 준비 화면이 6초 동안 멈춰 있으면 고장으로 보인다.
    func testPrefetchWithoutImageSourceFailsFast() async throws {
        let key = "cardImageBaseURL"
        let previous = UserDefaults.standard.string(forKey: key)
        UserDefaults.standard.set("", forKey: key)
        defer { UserDefaults.standard.set(previous, forKey: key) }

        // 기본 주소가 비어 있으면 URL 자체가 만들어지지 않는다.
        guard CardImageSource.baseURL.isEmpty else {
            throw XCTSkip("이미지 주소가 설정돼 있어 이 경로를 재현할 수 없다")
        }
        let started = ContinuousClock.now
        let result = await CardImageLoader.prefetch(cardIDs: ["sv10-1", "sv10-2"], hires: true,
                                                    timeout: .seconds(5))
        XCTAssertTrue(result.isEmpty)
        XCTAssertLessThan(started.duration(to: .now), .seconds(2), "마감까지 기다리면 안 된다")
    }

    /// 배포하는 모든 세트에 팩 아트 주소가 만들어져야 한다.
    /// 하나라도 빠지면 그 세트만 상점에서 빈 상자로 보인다.
    func testEverySetHasAPackArtURL() throws {
        let index = try XCTUnwrap(CardIndex.loadBundled())
        for set in index.sets {
            let url = try XCTUnwrap(CardImageSource.packURL(setID: set.id), "\(set.id) 팩 주소 없음")
            XCTAssertTrue(url.absoluteString.hasSuffix("/cards/packs/\(set.id).webp"),
                          "예상과 다른 경로: \(url.absoluteString)")
        }
    }

    /// 팩 아트와 카드는 캐시 키가 겹치면 안 된다. 겹치면 한쪽이 다른 쪽 그림을 보여준다.
    func testPackAndCardCacheKeysDoNotCollide() {
        let packKey = CardImageStore.packCacheKey(setID: "sv10")
        let cardKeys = ["sv10-1", "sv10-1_hires"].map {
            CardImageStore.cacheKey(cardID: $0, hires: false)
        }
        XCTAssertFalse(cardKeys.contains(packKey))
        // 카드 ID 는 항상 '-' 를 품고, 팩 키는 'pack_' 로 시작한다.
        XCTAssertTrue(packKey.hasPrefix("pack_"))
    }
}

@MainActor
final class PackArtAndGlowTests: XCTestCase {

    /// 판매하는 세트는 팩 아트가 번들에 있어야 한다. 없으면 상점과 대기 화면이
    /// 네트워크를 기다리게 되는데, 그러라고 번들에 넣은 것이다.
    func testEveryShippedSetHasBundledPackArt() throws {
        let index = try XCTUnwrap(CardIndex.loadBundled())
        for set in index.sets {
            XCTAssertNotNil(CardImageLoader.bundledPackImage(setID: set.id),
                            "\(set.id) (\(set.name)) 팩 아트가 번들에 없다")
        }
    }

    /// 번들 팩 아트는 두 번째 조회부터 같은 객체를 돌려준다 —
    /// 격자를 다시 그릴 때마다 디코딩하면 스크롤이 걸린다.
    func testBundledPackArtIsCached() throws {
        let first = try XCTUnwrap(CardImageLoader.bundledPackImage(setID: "base1"))
        let second = try XCTUnwrap(CardImageLoader.bundledPackImage(setID: "base1"))
        XCTAssertTrue(first === second)
    }

    /// 후광 세기는 등급이 오를수록 약해지지 않아야 한다.
    /// 뒤집히면 빛이 등급 신호로 작동하지 않는다.
    func testGlowStrengthNeverDecreasesWithRarity() throws {
        let ordered = CardTier.allCases.sorted { $0.rank < $1.rank }
        let strengths = ordered.map(TierGlow.strength(for:))
        for (a, b) in zip(strengths, strengths.dropFirst()) {
            XCTAssertLessThanOrEqual(a, b, "세기가 뒤집혔다: \(strengths)")
        }
        XCTAssertEqual(try XCTUnwrap(strengths.last), 1.0, accuracy: 0.001, "최고 등급은 최대 세기")
    }

    /// 흔한 카드는 빛나지 않는다. 전부 빛나면 빛으로 등급을 구분할 수 없다.
    func testCommonTiersDoNotGlow() {
        XCTAssertEqual(TierGlow.strength(for: .common), 0)
        XCTAssertEqual(TierGlow.strength(for: .energy), 0)
        XCTAssertGreaterThan(TierGlow.strength(for: .uncommon), 0)
    }
}

final class RevealTimingTests: XCTestCase {

    /// 한번에 열기는 등급과 무관하게 일정한 간격으로 넘긴다.
    /// 등급별로 다르게 주면 리듬이 들쭉날쭉해 넘어가는 흐름을 읽기 어렵다.
    func testHoldIsOneSecondForEveryTier() {
        XCTAssertEqual(RevealTiming.hold, .seconds(1))
    }

    /// 한 팩을 한번에 열 때 총 소요가 현실적인 범위여야 한다.
    func testWholePackAutoPlayStaysReasonable() {
        let total = (0..<PackConfig.cardsPerPack)
            .reduce(Duration.zero) { acc, _ in acc + RevealTiming.hold }
        XCTAssertLessThanOrEqual(total, .seconds(12))
    }
}

@MainActor
final class CollectionFilterTests: XCTestCase {

    private func entry(_ id: String, _ setID: String, _ tier: CardTier) -> CardEntry {
        CardEntry(id: id, name: id, tier: tier, setID: setID)
    }

    private var sample: [CardEntry] {
        [entry("a-1", "a", .common), entry("a-2", "a", .ultraRare),
         entry("b-1", "b", .common), entry("b-2", "b", .artRare)]
    }

    func testNoFilterKeepsEverything() {
        XCTAssertEqual(CardCollectionView.filtered(sample, set: nil, tier: nil).count, 4)
    }

    func testSetAndTierFiltersCombine() {
        XCTAssertEqual(CardCollectionView.filtered(sample, set: "a", tier: nil).map(\.id),
                       ["a-1", "a-2"])
        XCTAssertEqual(CardCollectionView.filtered(sample, set: nil, tier: .common).map(\.id),
                       ["a-1", "b-1"])
        // 둘을 함께 걸면 교집합이다 — 한쪽만 적용되면 여기서 드러난다.
        XCTAssertEqual(CardCollectionView.filtered(sample, set: "a", tier: .ultraRare).map(\.id),
                       ["a-2"])
        XCTAssertTrue(CardCollectionView.filtered(sample, set: "a", tier: .artRare).isEmpty)
    }

    /// 배포하는 모든 등급으로 필터를 걸 수 있어야 한다.
    /// 실제 카드가 없는 등급이 목록에 있으면 고르고도 빈 화면만 본다.
    func testEveryTierInTheMenuHasCardsSomewhere() throws {
        let index = try XCTUnwrap(CardIndex.loadBundled())
        for tier in CardTier.allCases {
            let hits = CardCollectionView.filtered(index.cards, set: nil, tier: tier)
            XCTAssertFalse(hits.isEmpty, "\(tier.rawValue) 등급 카드가 하나도 없다")
        }
    }
}

final class PackOddsTests: XCTestCase {

    /// 세트에 있는 등급은 하나도 빠짐없이 확률을 받는다.
    /// 히트 슬롯만 확률을 주고 나머지를 문구로 넘기면 커먼이 왜 없는지 알 수 없다.
    func testEveryTierInTheSetGetsOdds() throws {
        let index = try XCTUnwrap(CardIndex.loadBundled())
        for set in index.sets {
            let listed = Set(PackOpening.packOdds(setID: set.id, index: index).map(\.tier))
            let present = Set((index.pools[set.id] ?? [:]).filter { !$0.value.isEmpty }.keys)
            XCTAssertEqual(listed, present, "\(set.id): 확률 목록과 실제 보유 등급이 다르다")
        }
    }

    /// 기대 장수의 합이 그 팩의 장수와 같아야 한다.
    func testExpectedCountsSumToPackSize() throws {
        let index = try XCTUnwrap(CardIndex.loadBundled())
        for set in index.sets {
            let total = PackOpening.packOdds(setID: set.id, index: index)
                .reduce(0) { $0 + $1.expectedPerPack }
            XCTAssertEqual(total, Double(PackPricing.cardCount(setID: set.id, index: index)),
                           accuracy: 0.0001, "\(set.id) 기대 장수 합이 팩 장수와 다르다")
        }
    }

    /// 고정 슬롯으로 반드시 들어오는 등급은 100% 다.
    func testGuaranteedTiersAreCertain() throws {
        let index = try XCTUnwrap(CardIndex.loadBundled())
        let odds = PackOpening.packOdds(setID: "sv10", index: index)
        let common = try XCTUnwrap(odds.first { $0.tier == .common })
        XCTAssertEqual(common.packProbability, 1.0, accuracy: 0.0001)
        XCTAssertGreaterThan(common.expectedPerPack, 1)

        let ultra = try XCTUnwrap(odds.first { $0.tier == .ultraRare })
        XCTAssertLessThan(ultra.packProbability, 0.05, "UR 이 흔하면 안 된다")
    }

    /// 표시한 기대 장수가 실제 뽑기 결과와 맞아야 한다.
    func testExpectedCountsMatchActualDraws() throws {
        let index = try XCTUnwrap(CardIndex.loadBundled())
        let setID = "sv10"
        let expected = Dictionary(uniqueKeysWithValues:
            PackOpening.packOdds(setID: setID, index: index).map { ($0.tier, $0.expectedPerPack) })

        var observed: [CardTier: Int] = [:]
        let packs = 4_000
        for seed in 1...packs {
            var g = SeededGenerator(seed: UInt64(seed))
            for card in PackOpening.draw(setID: setID, index: index, alreadyOwned: [], using: &g) {
                observed[card.tier, default: 0] += 1
            }
        }
        for (tier, want) in expected {
            let got = Double(observed[tier] ?? 0) / Double(packs)
            XCTAssertEqual(got, want, accuracy: 0.06, "\(tier.rawValue) 표시 \(want) 실제 \(got)")
        }
    }
}

final class CardDustTests: XCTestCase {

    /// 희귀할수록 환급이 크다.
    func testDustRisesWithRarity() {
        let ordered = CardTier.allCases.sorted { $0.rank < $1.rank }
        let values = ordered.map(CardDust.value(for:))
        for (a, b) in zip(values, values.dropFirst()) {
            XCTAssertLessThanOrEqual(a, b, "환급액이 뒤집혔다: \(values)")
        }
    }

    /// 팩을 사서 전부 갈았을 때 기대 환급이 팩 값보다 훨씬 낮아야 한다.
    /// 넘으면 사서 갈기만 반복하는 것이 이득이 되어 게임이 무너진다.
    func testGrindingAPackNeverPaysForItself() throws {
        let index = try XCTUnwrap(CardIndex.loadBundled())
        for set in index.sets {
            let dust = PackOpening.packOdds(setID: set.id, index: index)
                .reduce(0.0) { $0 + $1.expectedPerPack * Double(CardDust.value(for: $1.tier)) }
            let price = Double(PackPricing.price(setID: set.id, index: index))
            XCTAssertLessThan(dust, price * 0.6,
                              "\(set.id): 기대 환급 \(Int(dust)) 이 팩 값 \(Int(price)) 의 60% 를 넘는다")
        }
    }
}

