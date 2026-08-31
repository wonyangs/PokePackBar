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

    /// **어떤 칸도 상위 등급을 못 뽑는 칸이어서는 안 된다.**
    ///
    /// 예전 구조는 아홉 칸이 커먼·언커먼 확정이었다. 그러면 확률을 정직하게 공시할수록
    /// "열 장 중 아홉 장은 절대 레어가 아니다" 가 드러나 불쾌해진다. 실물 팩도 포일 칸이
    /// 세 개라 레어가 나올 자리가 여럿이다.
    func testEverySlotCanRollRareOrBetter() {
        for (weights, count) in PackOpening.standardSlotTables(perks: .none) {
            XCTAssertGreaterThan(count, 0)
            let total = weights.reduce(0) { $0 + $1.weight }
            let rareOrBetter = weights
                .filter { $0.tier.rank >= CardTier.rare.rank }
                .reduce(0) { $0 + $1.weight }
            XCTAssertGreaterThan(Double(rareOrBetter) / Double(total), 0,
                                 "상위 등급을 못 뽑는 칸이 있다: \(weights)")
        }
    }

    /// 마지막 칸 하나는 레어 이상만 뽑는다. 팩마다 최소 한 장을 보장하는 자리다.
    func testTheLastSlotIsAlwaysRareOrBetter() {
        let tables = PackOpening.standardSlotTables(perks: .none)
        let hit = try! XCTUnwrap(tables.last)
        XCTAssertEqual(hit.count, PackConfig.hitSlots)
        XCTAssertTrue(hit.weights.allSatisfy { $0.tier.rank >= CardTier.rare.rank },
                      "확정 칸에 커먼·언커먼이 섞였다")
        XCTAssertEqual(tables.reduce(0) { $0 + $1.count }, PackConfig.cardsPerPack)
    }

    /// 천장 — 연속으로 레어만 나오면 다음은 RR 이상을 보장한다.
    func testPityForcesDoubleRareOrBetter() {
        let pool: [CardTier: [String]] = [.rare: ["r"], .doubleRare: ["rr"], .ultraRare: ["ur"]]
        for seed in UInt64(1)...30 {
            var g = SeededGenerator(seed: seed)
            let tier = PackOpening.hitTier(available: pool, pity: PackConfig.pityThreshold, using: &g)
            XCTAssertGreaterThan(tier.rank, CardTier.rare.rank, "seed \(seed): 천장이 안 걸렸다")
        }
    }

    /// 세트에 RR 이상이 아예 없으면 천장을 걸지 않는다 — 걸면 슬롯이 비어 버린다.
    func testPityDoesNotEmptyASetWithoutHigherTiers() {
        let pool: [CardTier: [String]] = [.rare: ["r"]]
        var g = SeededGenerator(seed: 3)
        XCTAssertEqual(PackOpening.hitTier(available: pool, pity: 99, using: &g), .rare)
    }

    /// 카운터는 레어에서 오르고 RR 이상에서 0 으로 돌아간다.
    func testPityCounterRisesAndResets() {
        XCTAssertEqual(PackOpening.nextPity(after: [.rare], from: 0), 1)
        XCTAssertEqual(PackOpening.nextPity(after: [.rare], from: 4), 5)
        XCTAssertEqual(PackOpening.nextPity(after: [.doubleRare], from: 4), 0)
        XCTAssertEqual(PackOpening.nextPity(after: [.ultraRare], from: 99), 0)
        XCTAssertEqual(PackOpening.nextPity(after: [.rare, .doubleRare], from: 2), 0,
                       "한 팩에 확정 칸이 둘이면 마지막 결과가 카운터를 정한다")
    }

    // MARK: 갓팩

    /// 갓팩은 전 칸이 레어 이상이다. 한 장이라도 커먼이 섞이면 갓팩이 아니다.
    func testGodPackHoldsOnlyRareOrBetter() {
        let index = makeIndex("s", [.common: 30, .uncommon: 20, .rare: 10,
                                    .doubleRare: 6, .ultraRare: 3])
        var found = 0
        for seed in UInt64(1)...3000 {
            var g = SeededGenerator(seed: seed)
            var pity = 0
            let pack = PackOpening.draw(setID: "s", index: index, alreadyOwned: [],
                                        pity: &pity, using: &g)
            guard pack.isGodPack else { continue }
            found += 1
            XCTAssertEqual(pack.cards.count, PackConfig.cardsPerPack)
            XCTAssertTrue(pack.cards.allSatisfy { $0.tier.rank >= CardTier.rare.rank },
                          "seed \(seed): 갓팩에 레어 미만이 섞였다")
            XCTAssertEqual(pity, 0, "갓팩은 천장을 초기화한다")
        }
        XCTAssertGreaterThan(found, 0, "3000번 뽑는 동안 갓팩이 한 번도 안 나왔다")
    }

    /// 공시한 확률과 실제 등장 빈도가 맞아야 한다. 표시만 하고 다르게 굴리면 그게 조작이다.
    func testGodPackRateMatchesTheDisclosedNumber() {
        let index = makeIndex("s", [.common: 30, .uncommon: 20, .rare: 10, .doubleRare: 6])
        let trials = 30_000
        var gods = 0
        var g = SeededGenerator(seed: 20260828)
        var pity = 0
        for _ in 0..<trials {
            if PackOpening.draw(setID: "s", index: index, alreadyOwned: [],
                                pity: &pity, using: &g).isGodPack { gods += 1 }
        }
        let expected = Double(trials) / Double(PackConfig.godPackOneIn)
        // 30,000번이면 표준편차가 10 남짓이라 ±40% 밖으로 벗어나면 확률이 어긋난 것이다.
        XCTAssertGreaterThan(Double(gods), expected * 0.6, "갓팩이 공시보다 드물다 (\(gods)회)")
        XCTAssertLessThan(Double(gods), expected * 1.4, "갓팩이 공시보다 잦다 (\(gods)회)")
    }

    /// 확률표에도 갓팩이 섞여 있어야 한다. 뽑기에만 넣으면 표가 실제보다 짜게 나온다.
    func testOddsAccountForGodPacks() {
        let index = makeIndex("s", [.common: 30, .uncommon: 20, .rare: 10,
                                    .doubleRare: 6, .ultraRare: 3])
        let odds = PackOpening.packOdds(setID: "s", index: index)
        let ultra = odds.first { $0.tier == .ultraRare }?.probability ?? 0

        // 갓팩을 뺀 값 — 확정 칸의 UR 몫만 남는다.
        let hitTotal = PackConfig.hitWeights.reduce(0) { $0 + $1.weight }
        let hitOnly = Double(1) / Double(hitTotal) / Double(PackConfig.cardsPerPack)
        XCTAssertGreaterThan(ultra, hitOnly, "확률표가 갓팩을 세지 않았다")
    }

    /// 특별 세트에는 갓팩이 없다. 원래 전 칸이 레어 이상이라 구분이 성립하지 않는다.
    func testSpecialSetsHaveNoGodPack() {
        let index = makeIndex("c", [.rare: 8, .doubleRare: 6, .superRare: 3])
        for seed in UInt64(1)...200 {
            var g = SeededGenerator(seed: seed)
            var pity = 0
            XCTAssertFalse(PackOpening.draw(setID: "c", index: index, alreadyOwned: [],
                                            pity: &pity, using: &g).isGodPack)
        }
    }

    /// 에너지는 그 계층이 있는 세트에서만 나온다. 없는 세트에 억지로 끼워 넣지 않는다.
    ///
    /// 확정 슬롯이 아니라 일반 칸의 추첨 결과이므로 장수는 팩마다 다르다.
    /// 여기서 잠그는 것은 "없는 세트에서 나오지 않는다" 와 "장수가 줄지 않는다" 두 가지다.
    func testEnergyOnlyAppearsWhenSetHasEnergy() {
        let withEnergy = makeIndex("e", [.common: 20, .uncommon: 20, .rare: 10, .doubleRare: 5, .energy: 6])
        let without = makeIndex("n", [.common: 20, .uncommon: 20, .rare: 10, .doubleRare: 5])

        var sawEnergy = false
        for seed in UInt64(1)...30 {
            var g = SeededGenerator(seed: seed)
            let pack = PackOpening.draw(setID: "e", index: withEnergy, alreadyOwned: [], using: &g)
            if pack.contains(where: { $0.tier == .energy }) { sawEnergy = true }
        }
        XCTAssertTrue(sawEnergy, "에너지가 있는 세트에서는 나와야 한다")

        for seed in UInt64(1)...30 {
            var g = SeededGenerator(seed: seed)
            let pack = PackOpening.draw(setID: "n", index: without, alreadyOwned: [], using: &g)
            XCTAssertEqual(pack.filter { $0.tier == .energy }.count, 0)
            XCTAssertEqual(pack.count, PackConfig.cardsPerPack)
        }
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

/// 카드를 넘길 때 두 장이 겹쳐 반투명해지지 않아야 한다.
///
/// `SpotlightCard` 는 `.id(card.id)` 로 매번 새로 만들어진다. 그 교체가 애니메이션 트랜잭션
/// 안에서 일어나면 SwiftUI 가 기본 전환인 페이드를 걸어, 나가는 카드와 들어오는 카드가 동시에
/// 반투명해지고 밑장이 비친다. 사용자에게 "카드가 커질 때 깜빡인다" 로 보고된 결함이다.
/// `.transition(.identity)` 는 트랜잭션이 열려 있어도 그 페이드를 막는다.
final class RevealTransitionTests: XCTestCase {

    func testCardSwapDoesNotCrossFade() throws {
        let source = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Sources/PokePackBar/UI/PacksView.swift")
        let text = try String(contentsOf: source, encoding: .utf8)
        // 호출 지점을 기준으로 삼는다. 모디파이어 이름만 찾으면 그것을 설명하는 주석이
        // 먼저 걸린다(실제로 한 번 걸렸다).
        let anchor = try XCTUnwrap(text.range(of: "SpotlightCard(card: card"),
                                   "SpotlightCard 호출 지점을 찾지 못했다")
        let modifiers = text[anchor.upperBound...].prefix(400)
        XCTAssertTrue(modifiers.contains(".id(card.id)"), "카드마다 뷰를 새로 만들어야 한다")
        XCTAssertTrue(modifiers.contains(".transition(.identity)"),
                      "SpotlightCard 에 .transition(.identity) 가 있어야 한다 — "
                      + "없으면 카드 교체에 기본 페이드가 걸려 두 장이 겹쳐 보인다")
    }
}

/// 카드 그림을 어느 프레임에 그리는가. 개봉 화면에서 카드가 깜빡이던 원인이 여기였다.
@MainActor
final class CardImageDisplayTests: XCTestCase {

    private func image() -> NSImage { NSImage(size: NSSize(width: 2, height: 2)) }

    /// 아직 아무것도 못 불렀어도 미리 받아 둔 그림이 있으면 그것을 그린다.
    /// `.task` 는 첫 렌더 뒤에 돌기 때문에, 이걸 안 하면 회색 자리표시가 한 프레임 보인다.
    func testPreloadedShowsOnFirstFrame() {
        let ready = image()
        XCTAssertIdentical(CardImageLoader.displayed(nil, loadedKey: nil,
                                                     key: "sv10-1-true", preloaded: ready), ready)
    }

    /// 이전 카드 그림이 남아 있으면 쓰지 않는다. 뷰가 재사용되면서 cardID 만 바뀌는
    /// 경로가 있어, 확인하지 않으면 엉뚱한 카드가 한 프레임 보인다.
    func testStaleImageFromAnotherCardIsNotUsed() {
        let old = image(), ready = image()
        let shown = CardImageLoader.displayed(old, loadedKey: "sv10-1-true",
                                              key: "sv10-2-true", preloaded: ready)
        XCTAssertIdentical(shown, ready)
    }

    /// 미리 받아 둔 것이 없고 이전 카드 그림뿐이면 아무것도 그리지 않는다 —
    /// 엉뚱한 카드를 보여 주느니 자리표시가 낫다.
    func testStaleImageWithoutPreloadedShowsNothing() {
        XCTAssertNil(CardImageLoader.displayed(image(), loadedKey: "sv10-1-true",
                                               key: "sv10-2-true", preloaded: nil))
    }

    /// 제 카드 것으로 불러 둔 그림은 미리 받아 둔 것보다 우선한다(해상도가 더 높을 수 있다).
    func testLoadedImageForThisCardWins() {
        let loaded = image(), ready = image()
        let shown = CardImageLoader.displayed(loaded, loadedKey: "sv10-1-true",
                                              key: "sv10-1-true", preloaded: ready)
        XCTAssertIdentical(shown, loaded)
    }
}

/// 카드를 들춰 다음 장을 훔쳐보는 동작. 손맛을 결정하는 값이라 값으로 못박아 둔다.
final class RevealPeekTests: XCTestCase {

    func testRestShowsNothing() {
        XCTAssertEqual(RevealPeek.amount(.zero), 0)
        XCTAssertFalse(RevealPeek.advances(.zero))
    }

    /// 문턱에 닿으면 넘어간다. 그 전에는 제자리로 돌아가야 한다.
    func testAdvancesOnlyAtThreshold() {
        let short = CGSize(width: RevealPeek.threshold - 1, height: 0)
        let exact = CGSize(width: RevealPeek.threshold, height: 0)
        XCTAssertFalse(RevealPeek.advances(short))
        XCTAssertTrue(RevealPeek.advances(exact))
    }

    /// 위로 들춰도 먹어야 한다. 가로만 재면 실물처럼 위로 들추는 사람은 못 넘긴다.
    func testUpwardDragCounts() {
        XCTAssertTrue(RevealPeek.advances(CGSize(width: 0, height: -RevealPeek.threshold)))
    }

    /// 비스듬히 끌면 가로·세로를 합친 거리로 잰다. 44+44 는 62 를 넘는다.
    func testDiagonalDragUsesMagnitude() {
        let diagonal = CGSize(width: 44, height: -44)
        XCTAssertGreaterThan(RevealPeek.distance(diagonal), RevealPeek.threshold)
        XCTAssertTrue(RevealPeek.advances(diagonal))
    }

    /// 들출수록 빛이 세지고, 문턱을 넘으면 더 세지지 않는다.
    func testAmountRisesThenSaturates() {
        let steps = stride(from: 0.0, through: Double(RevealPeek.threshold), by: 6.0)
            .map { RevealPeek.amount(CGSize(width: $0, height: 0)) }
        for (a, b) in zip(steps, steps.dropFirst()) {
            XCTAssertLessThanOrEqual(a, b, "들출수록 세져야 한다")
        }
        XCTAssertEqual(RevealPeek.amount(CGSize(width: RevealPeek.threshold, height: 0)), 1)
        XCTAssertEqual(RevealPeek.amount(CGSize(width: RevealPeek.threshold * 4, height: 0)), 1,
                       "문턱을 넘겨 끌어도 1 에서 멈춘다")
    }

    /// 기울기는 손이 가는 쪽으로, 한계 안에서.
    func testTiltFollowsHandAndIsCapped() {
        XCTAssertEqual(RevealPeek.tilt(.zero), 0)
        XCTAssertGreaterThan(RevealPeek.tilt(CGSize(width: 30, height: 0)), 0)
        XCTAssertLessThan(RevealPeek.tilt(CGSize(width: -30, height: 0)), 0)
        XCTAssertEqual(RevealPeek.tilt(CGSize(width: 9999, height: 0)), RevealPeek.maxTilt)
        XCTAssertEqual(RevealPeek.tilt(CGSize(width: -9999, height: 0)), -RevealPeek.maxTilt)
    }

    /// 카드가 팝오버 폭을 넘으면 좌우가 잘리고, 넘치는 자식이 팝오버 자체를 밀어 넓힌다.
    @MainActor
    func testRevealCardFitsPopoverWidth() {
        XCTAssertLessThanOrEqual(RevealPeek.cardWidth, PopoverMetrics.contentWidth,
                                 "개봉 카드가 팝오버 안쪽 폭보다 넓다")
    }

    /// 밑장이 눈에 보일 만큼 삐져나와야 한다. 줄이는 비율과 내리는 거리가 서로 상쇄돼
    /// 0 에 가까워지면 카드가 한 장으로 보인다 — "뒤에 카드가 안 보인다" 는 지적이 그것이었다.
    func testNextCardPeeksOutFromUnderTheTop() {
        let edge = RevealPeek.visibleDeckEdge(cardWidth: RevealPeek.cardWidth)
        XCTAssertGreaterThan(edge, 4, "밑장이 \(edge)pt 밖에 안 나온다 — 덱으로 안 읽힌다")
        XCTAssertLessThan(edge, RevealPeek.deckOffset, "줄인 만큼은 반드시 깎여야 한다")
    }

    /// 밑장은 위 카드보다 작아야 뒤에 있는 것으로 읽히고, 너무 작으면 다른 카드처럼 보인다.
    func testDeckScaleStaysSubtle() {
        XCTAssertGreaterThan(RevealPeek.deckScale, 0.9)
        XCTAssertLessThan(RevealPeek.deckScale, 1.0)
    }

    /// 커먼·에너지는 후광 세기가 0 이다 — 들춰도 아무것도 안 비치는 것이 정상이고,
    /// 그 실망까지가 카드깡이다. 이 값이 0 이 아니게 되면 빛이 등급 신호로 작동하지 않는다.
    @MainActor
    func testPeekShowsNothingForCommonNextCard() {
        XCTAssertEqual(TierGlow.strength(for: .common), 0)
        XCTAssertEqual(TierGlow.strength(for: .energy), 0)
        XCTAssertGreaterThan(TierGlow.strength(for: .ultraRare), 0.9)
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
    func testEveryTierInTheSetGetsOdds() throws {
        let index = try XCTUnwrap(CardIndex.loadBundled())
        for set in index.sets {
            let listed = Set(PackOpening.packOdds(setID: set.id, index: index).map(\.tier))
            let present = Set((index.pools[set.id] ?? [:]).filter { !$0.value.isEmpty }.keys)
            XCTAssertEqual(listed, present, "\(set.id): 확률 목록과 실제 보유 등급이 다르다")
        }
    }

    /// 확률의 합은 항상 1 이다 — 카드 한 장이 어느 등급인지의 분포이므로.
    func testProbabilitiesSumToOne() throws {
        let index = try XCTUnwrap(CardIndex.loadBundled())
        for set in index.sets {
            let total = PackOpening.packOdds(setID: set.id, index: index)
                .reduce(0) { $0 + $1.probability }
            XCTAssertEqual(total, 1.0, accuracy: 0.0001, "\(set.id) 확률 합이 1 이 아니다")
        }
    }

    /// 희귀할수록 확률이 낮다. 뒤집히면 등급 체계가 의미를 잃는다.
    /// 에너지는 등급 축이 아니라 별도 슬롯이므로 뺀다.
    func testRarerTiersAreNotMoreLikely() throws {
        let index = try XCTUnwrap(CardIndex.loadBundled())
        for set in index.sets {
            let odds = PackOpening.packOdds(setID: set.id, index: index)
                .filter { $0.tier != .energy }
            for (a, b) in zip(odds, odds.dropFirst()) {
                XCTAssertLessThanOrEqual(a.probability, b.probability,
                                         "\(set.id): \(a.tier.rawValue) 가 \(b.tier.rawValue) 보다 흔하다")
            }
        }
    }

    /// 표시한 확률이 실제 뽑기에서 나오는 비율과 맞아야 한다.
    /// 표시용 계산을 따로 두면 둘이 조용히 갈라진다.
    func testOddsMatchActualDraws() throws {
        let index = try XCTUnwrap(CardIndex.loadBundled())
        let setID = "sv10"
        let expected = Dictionary(uniqueKeysWithValues:
            PackOpening.packOdds(setID: setID, index: index).map { ($0.tier, $0.probability) })

        var observed: [CardTier: Int] = [:]
        var drawn = 0
        for seed in 1...4_000 {
            var g = SeededGenerator(seed: UInt64(seed))
            for card in PackOpening.draw(setID: setID, index: index, alreadyOwned: [], using: &g) {
                observed[card.tier, default: 0] += 1
                drawn += 1
            }
        }
        for (tier, want) in expected {
            let got = Double(observed[tier] ?? 0) / Double(drawn)
            XCTAssertEqual(got, want, accuracy: 0.01, "\(tier.rawValue) 표시 \(want) 실제 \(got)")
        }
    }
}

final class CardDustTests: XCTestCase {

    /// 희귀할수록 환급이 크다.
    func testDustRisesWithRarity() {
        let ordered = CardTier.allCases.sorted { $0.rank < $1.rank }
        let values = ordered.map { CardDust.value(for: $0) }
        for (a, b) in zip(values, values.dropFirst()) {
            XCTAssertLessThanOrEqual(a, b, "환급액이 뒤집혔다: \(values)")
        }
    }

    /// 팩을 사서 전부 갈았을 때 기대 환급이 팩 값보다 훨씬 낮아야 한다.
    /// 넘으면 사서 갈기만 반복하는 것이 이득이 되어 게임이 무너진다.
    func testGrindingAPackNeverPaysForItself() throws {
        let index = try XCTUnwrap(CardIndex.loadBundled())
        for set in index.sets {
            let cards = Double(PackPricing.cardCount(setID: set.id, index: index))
            let dust = PackOpening.packOdds(setID: set.id, index: index)
                .reduce(0.0) { $0 + $1.probability * cards * Double(CardDust.value(for: $1.tier)) }
            let price = Double(PackPricing.price(setID: set.id, index: index))
            XCTAssertLessThan(dust, price * 0.6,
                              "\(set.id): 기대 환급 \(Int(dust)) 이 팩 값 \(Int(price)) 의 60% 를 넘는다")
        }
    }
}
