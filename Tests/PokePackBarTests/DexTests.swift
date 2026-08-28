import XCTest
@testable import PokePackBar

/// 번들에 들어간 도감 파일 자체를 검사한다.
///
/// 도감은 사람이 손으로 짓고 스크립트가 난이도를 계산해 넣는다. 두 저장소에 걸친 흐름이라
/// 파일이 어긋난 채로 배포될 수 있는 자리가 여럿이다 — 여기서 전부 막는다.
final class BundledDexTests: XCTestCase {

    private func loadIndexes() throws -> (CardIndex, DexIndex) {
        let cards = try XCTUnwrap(CardIndex.loadBundled(), "카드 목록이 번들에 없다")
        let dexes = DexIndex.loadBundled()
        XCTAssertFalse(dexes.dexes.isEmpty, "도감이 비어 있다 — build_dex.py 를 실행했는가")
        return (cards, dexes)
    }

    /// 구성원이 실제로 존재해야 한다. 없는 카드가 들어 있으면 그 도감은 영원히 완성되지 않고,
    /// 화면에는 빈 자리만 남는다.
    func testEveryMemberExistsInTheCardIndex() throws {
        let (cards, dexes) = try loadIndexes()
        for dex in dexes.dexes {
            XCTAssertNotNil(cards.set(dex.homeSet), "\(dex.id): homeSet 없음 \(dex.homeSet)")
            for card in dex.cards {
                XCTAssertNotNil(cards.card(card), "\(dex.id): 카드 없음 \(card)")
            }
            XCTAssertEqual(Set(dex.cards).count, dex.cards.count, "\(dex.id): 같은 카드가 두 번")
        }
    }

    func testDexIDsAreUnique() throws {
        let (_, dexes) = try loadIndexes()
        let ids = dexes.dexes.map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count, "도감 id 가 중복이다")
    }

    /// 저장된 난이도가 실제 확률과 맞는가.
    ///
    /// 팩 구성(`PackConfig`)이나 세트 구성이 바뀌면 스크립트가 계산해 넣은 값이 조용히
    /// 거짓이 된다. 앱이 같은 식으로 다시 계산해 대조한다 — 확률표와 같은 출처를 쓰므로
    /// 팩을 손보면 여기서 먼저 걸린다.
    func testStoredDifficultyMatchesRecomputedValue() throws {
        let (cards, dexes) = try loadIndexes()
        for dex in dexes.dexes {
            let recomputed = DexDifficulty.packsNeeded(cards: dex.cards, quantile: 0.5,
                                                       index: cards)
            XCTAssertEqual(recomputed, dex.medianPacks,
                           "\(dex.id): 저장된 \(dex.medianPacks)팩 vs 재계산 \(recomputed)팩")
            XCTAssertEqual(DexDifficulty.tier(forMedianPacks: recomputed), dex.tier,
                           "\(dex.id): 티어가 어긋났다")
        }
    }

    /// 최고 난도 두 개는 눈에 보이는 혜택과 패시브를 함께 준다.
    /// 팩이 좋아지는 것이 보이지 않으면 최상위 보상으로 읽히지 않는다.
    func testTopTierDexesGiveAVisiblePackPerk() throws {
        let (_, dexes) = try loadIndexes()
        let top = dexes.dexes.filter { $0.tier == Dex.maxTier }
        XCTAssertFalse(top.isEmpty)
        for dex in top {
            let kinds = Set(dex.reward.perks.map(\.kind))
            XCTAssertTrue(kinds.contains(.extraHitSlot) || kinds.contains(.duplicateGuard),
                          "\(dex.id): 개봉이 좋아지는 혜택이 없다")
            XCTAssertGreaterThanOrEqual(dex.reward.perks.count, 2, "\(dex.id): 패시브가 없다")
        }
    }

    /// 보상 팩 수는 티어 표에서 나온다. 손으로 적은 값이 섞이면 난이도와 보상이 갈라진다.
    func testRewardPacksFollowTheTierTable() throws {
        let (_, dexes) = try loadIndexes()
        for dex in dexes.dexes {
            let expected = DexDifficulty.rewardPacks[dex.tier - 1]
            XCTAssertEqual(dex.reward.packs, expected, "\(dex.id): 보상 팩 수가 티어와 어긋났다")
        }
    }

    /// 구성 카드는 상위 등급이 앞에 온다. 목록에서 뒤가 접힐 때 남는 것이
    /// 희귀한 카드여야 무엇을 모으는 조합인지 읽힌다.
    func testMembersAreSortedByRarityDescending() throws {
        let (cards, dexes) = try loadIndexes()
        for dex in dexes.dexes {
            let ranks = dex.cards.compactMap { cards.card($0)?.tier.rank }
            XCTAssertEqual(ranks, ranks.sorted(by: >), "\(dex.id): 등급 순서가 어긋났다")
        }
    }

    /// 모든 도감을 완성해도 혜택 총합이 상한을 넘지 않아야 한다.
    /// 넘으면 팩이 사실상 공짜가 되고 게임이 성립하지 않는다.
    func testPerkTotalsStayWithinCaps() throws {
        let (_, dexes) = try loadIndexes()
        let all = DexPerks.total(completed: Set(dexes.dexes.map(\.id)), dexes: dexes.dexes)
        XCTAssertLessThanOrEqual(all.tokenGain, DexPerks.caps.tokenGain)
        XCTAssertLessThanOrEqual(all.packDiscount, DexPerks.caps.packDiscount)
        XCTAssertLessThanOrEqual(all.dustBonus, DexPerks.caps.dustBonus)
        XCTAssertLessThanOrEqual(all.hitOdds, DexPerks.caps.hitOdds)
        XCTAssertLessThanOrEqual(all.bonusPacks, DexPerks.caps.bonusPacks)
        XCTAssertLessThanOrEqual(all.extraHitSlot, DexPerks.caps.extraHitSlot)
    }

    /// 난이도가 골고루 있어야 한다. 쉬운 것이 없으면 "우연히 완성했네" 가 일어나지 않고,
    /// 어려운 것이 없으면 장기 목표가 사라진다.
    func testDifficultySpreadCoversEasyAndHard() throws {
        let (_, dexes) = try loadIndexes()
        let tiers = Set(dexes.dexes.map(\.tier))
        XCTAssertTrue(tiers.contains(1), "가장 쉬운 도감이 없다")
        XCTAssertTrue(tiers.contains(5), "최고 난도 도감이 없다")
    }

    /// 구성원이 비었거나 티어가 범위를 벗어난 줄은 걸러진다.
    /// 구성원이 없으면 완성 판정이 항상 참이 되어 보상을 즉시 준다.
    func testMalformedRowsAreDropped() {
        let json = """
        {"version":1,"dexes":[
          {"id":"empty","name":{"ko":"a","en":"a"},"blurb":{"ko":"b","en":"b"},
           "homeSet":"base1","cards":[],"tier":1,"medianPacks":1,
           "reward":{"packs":1,"perks":[]}},
          {"id":"badtier","name":{"ko":"a","en":"a"},"blurb":{"ko":"b","en":"b"},
           "homeSet":"base1","cards":["base1-1"],"tier":9,"medianPacks":1,
           "reward":{"packs":1,"perks":[]}},
          {"id":"ok","name":{"ko":"a","en":"a"},"blurb":{"ko":"b","en":"b"},
           "homeSet":"base1","cards":["base1-1"],"tier":1,"medianPacks":1,
           "reward":{"packs":1,"perks":[]}}
        ]}
        """
        let index = DexIndex.decode(Data(json.utf8))
        XCTAssertEqual(index.dexes.map(\.id), ["ok"])
    }
}

/// 진행·완성 판정은 순수 함수다. 화면 없이 전부 검증한다.
final class DexProgressTests: XCTestCase {

    private func dex(_ id: String, _ cards: [String], tier: Int = 2,
                     perk: DexPerk? = nil) -> Dex {
        Dex(id: id, name: DexText(ko: id, en: id), blurb: DexText(ko: "", en: ""),
            homeSet: "s", cards: cards, tier: tier, medianPacks: 10,
            reward: DexReward(packs: 3, perks: perk.map { [$0] } ?? []))
    }

    func testStatusSplitsOwnedAndMissing() {
        let owned: Set<String> = ["a", "c"]
        let status = DexProgress.status(for: dex("d", ["a", "b", "c", "d"]),
                                        owned: { owned.contains($0) }, claimed: false)
        XCTAssertEqual(status.ownedCount, 2)
        XCTAssertEqual(status.missing, ["b", "d"])
        XCTAssertFalse(status.isFilled)
        XCTAssertEqual(status.fraction, 0.5, accuracy: 0.0001)
    }

    /// 다 모았고 아직 안 받은 것만 수령 대상이다.
    func testClaimableOnlyWhenFilledAndNotClaimed() {
        let partial: Set<String> = ["a"]
        XCTAssertFalse(DexProgress.status(for: dex("d", ["a", "b"]),
                                          owned: { partial.contains($0) }, claimed: false).isClaimable)
        let all: Set<String> = ["a", "b"]
        XCTAssertTrue(DexProgress.status(for: dex("d", ["a", "b"]),
                                         owned: { all.contains($0) }, claimed: false).isClaimable)
        XCTAssertFalse(DexProgress.status(for: dex("d", ["a", "b"]),
                                          owned: { all.contains($0) }, claimed: true).isClaimable,
                       "이미 받은 것은 다시 받을 수 없다")
    }

    /// 수령한 도감은 구성이 바뀌어도 완성으로 본다.
    /// 나중에 도감에 카드를 추가했다고 이미 준 혜택을 회수하면 안 된다.
    func testClaimedStaysCompleteEvenWhenAMemberIsMissing() {
        let status = DexProgress.status(for: dex("d", ["a", "b"]),
                                        owned: { $0 == "a" }, claimed: true)
        XCTAssertFalse(status.isFilled)
        XCTAssertTrue(status.isComplete)
        XCTAssertFalse(status.isClaimable, "이미 받은 것을 다시 받을 수 없다")
    }

    func testNewlyFilledSkipsAlreadyClaimed() {
        let dexes = [dex("one", ["a"]), dex("two", ["a", "b"])]
        let owned: Set<String> = ["a", "b"]
        let fresh = DexProgress.newlyFilled(dexes: dexes, owned: { owned.contains($0) },
                                            claimed: ["one"], before: ["a"])
        XCTAssertEqual(fresh.map(\.id), ["two"])
    }

    /// 원래 다 모여 있던 도감은 개봉할 때마다 다시 알리지 않는다.
    /// 매번 뜨면 알림이 소음이 되고, 진짜로 방금 채워진 것이 묻힌다.
    func testNewlyFilledIgnoresDexesThatWereAlreadyFull() {
        let dexes = [dex("old", ["a"]), dex("fresh", ["a", "b"])]
        let owned: Set<String> = ["a", "b"]
        let result = DexProgress.newlyFilled(dexes: dexes, owned: { owned.contains($0) },
                                             claimed: [], before: ["a"])
        XCTAssertEqual(result.map(\.id), ["fresh"])
    }

    /// 어려운 것을 먼저 알린다. 쉬운 것 여러 개에 묻히면 힘들게 완성한 것이 안 보인다.
    func testNewlyFilledOrdersHardestFirst() {
        let dexes = [dex("easy", ["a"], tier: 1), dex("hard", ["a"], tier: 5),
                     dex("mid", ["a"], tier: 3)]
        let fresh = DexProgress.newlyFilled(dexes: dexes, owned: { _ in true },
                                            claimed: [], before: [])
        XCTAssertEqual(fresh.map(\.id), ["hard", "mid", "easy"])
    }

    /// 목록 순서 — 받을 것이 맨 위, 받은 것이 맨 아래, 나머지는 완성에 가까운 순.
    func testSortedPutsClaimableFirstAndClaimedLast() {
        let owned: Set<String> = ["a", "b"]
        let statuses = DexProgress.statuses(
            dexes: [dex("done", ["a"]), dex("far", ["x", "y", "z"]),
                    dex("ready", ["a", "b"]), dex("oneAway", ["a", "b", "z"]),
                    dex("twoAway", ["a", "x", "y"])],
            owned: { owned.contains($0) }, claimed: ["done"])
        XCTAssertEqual(DexProgress.sorted(statuses).map(\.id),
                       ["ready", "oneAway", "twoAway", "far", "done"])
    }
}

/// 혜택 합산과 상한.
final class DexPerksTests: XCTestCase {

    private func dex(_ id: String, _ perks: [DexPerk]) -> Dex {
        Dex(id: id, name: DexText(ko: id, en: id), blurb: DexText(ko: "", en: ""),
            homeSet: "s", cards: ["c"], tier: 2, medianPacks: 10,
            reward: DexReward(packs: 3, perks: perks))
    }

    func testPerksAddUp() {
        let dexes = [dex("a", [DexPerk(kind: .tokenGain, value: 0.01)]),
                     dex("b", [DexPerk(kind: .tokenGain, value: 0.02)]),
                     dex("c", [DexPerk(kind: .packDiscount, value: 0.03)]),
                     dex("d", [])]
        let perks = DexPerks.total(completed: ["a", "b", "c", "d"], dexes: dexes)
        XCTAssertEqual(perks.tokenGain, 0.03, accuracy: 0.0001)
        XCTAssertEqual(perks.packDiscount, 0.03, accuracy: 0.0001)
    }

    func testOnlyCompletedDexesCount() {
        let dexes = [dex("a", [DexPerk(kind: .tokenGain, value: 0.01)]),
                     dex("b", [DexPerk(kind: .tokenGain, value: 0.02)])]
        XCTAssertEqual(DexPerks.total(completed: ["a"], dexes: dexes).tokenGain, 0.01, accuracy: 0.0001)
        XCTAssertTrue(DexPerks.total(completed: [], dexes: dexes).isEmpty)
    }

    /// 한 도감이 혜택 두 개를 줄 수 있다. 최고 난도 조합이 그렇다.
    func testOneDexCanCarryTwoPerks() {
        let dexes = [dex("top", [DexPerk(kind: .extraHitSlot, value: 1),
                                 DexPerk(kind: .hitOdds, value: 0.05)])]
        let perks = DexPerks.total(completed: ["top"], dexes: dexes)
        XCTAssertEqual(perks.extraHitSlot, 1)
        XCTAssertEqual(perks.hitOdds, 0.05, accuracy: 0.0001)
    }

    /// 켜고 끄는 혜택은 여러 번 붙어도 한 번만 켜진다.
    func testToggleStyleaPerkStaysOnce() {
        let dexes = [dex("a", [DexPerk(kind: .duplicateGuard, value: 1)]),
                     dex("b", [DexPerk(kind: .duplicateGuard, value: 1)])]
        XCTAssertTrue(DexPerks.total(completed: ["a", "b"], dexes: dexes).duplicateGuard)
        XCTAssertFalse(DexPerks.total(completed: [], dexes: dexes).duplicateGuard)
    }

    /// 세이브에 남은 낯선 id 는 무시한다 — 도감을 지우거나 이름을 바꿔도 세이브가 깨지지 않아야 한다.
    func testUnknownCompletedIDsAreIgnored() {
        let perks = DexPerks.total(completed: ["gone"], dexes: [dex("a", [DexPerk(kind: .tokenGain, value: 0.01)])])
        XCTAssertTrue(perks.isEmpty)
    }

    /// 상한을 넘겨도 상한에서 멈춘다. 도감이 계속 늘어나므로 이 방어가 있어야 한다.
    func testTotalsClampToCaps() {
        let many = (0..<100).map { dex("d\($0)", [DexPerk(kind: .packDiscount, value: 0.01)]) }
        let perks = DexPerks.total(completed: Set(many.map(\.id)), dexes: many)
        XCTAssertEqual(perks.packDiscount, DexPerks.caps.packDiscount, accuracy: 0.0001)
    }
}

/// 혜택이 실제 계산에 반영되는가. 화면에만 반영되고 뽑기에 안 걸리면 보상이 거짓이 된다.
final class DexPerkEffectTests: XCTestCase {

    private func makeIndex() -> CardIndex {
        var cards: [[String]] = []
        for i in 1...40 { cards.append(["s-\(i)", "c\(i)", "C"]) }
        for i in 41...60 { cards.append(["s-\(i)", "u\(i)", "U"]) }
        for i in 61...70 { cards.append(["s-\(i)", "r\(i)", "R"]) }
        for i in 71...75 { cards.append(["s-\(i)", "rr\(i)", "RR"]) }
        for i in 76...78 { cards.append(["s-\(i)", "ur\(i)", "UR"]) }
        let payload: [String: Any] = [
            "version": 1,
            "sets": [["id": "s", "name": "Set", "released": "2020/01/01", "cardCount": cards.count]],
            "cards": cards,
        ]
        let data = try! JSONSerialization.data(withJSONObject: payload)
        return CardIndex.decode(data)!
    }

    func testPackDiscountLowersPrice() {
        let index = makeIndex()
        let full = PackPricing.price(setID: "s", index: index)
        let cut = PackPricing.price(setID: "s", index: index,
                                    perks: DexPerks(packDiscount: 0.25))
        XCTAssertEqual(cut, Int(Double(full) * 0.75))
        XCTAssertEqual(PackPricing.price(setID: "s", index: index, perks: .none), full,
                       "혜택이 없으면 정가 그대로여야 한다")
    }

    func testDustBonusRaisesRefund() {
        let base = CardDust.value(for: .rare)
        let boosted = CardDust.value(for: .rare, perks: DexPerks(dustBonus: 0.3))
        XCTAssertEqual(boosted, Int(Double(base) * 1.3))
        XCTAssertEqual(CardDust.value(for: .rare, perks: .none), base)
    }

    /// 카드 한 장이 늘고, 그 한 장이 히트 슬롯이어야 한다.
    /// 장수만 늘고 히트가 안 늘면 커먼 한 장을 더 주는 것과 같아 보상이 되지 않는다.
    func testExtraHitSlotAddsOneCardAndOneHit() {
        let index = makeIndex()
        let perks = DexPerks(extraHitSlot: 1)
        XCTAssertEqual(PackPricing.cardCount(setID: "s", index: index), 10)
        XCTAssertEqual(PackPricing.cardCount(setID: "s", index: index, perks: perks), 11)

        let hitTiers: Set<CardTier> = [.rare, .doubleRare, .ultraRare]
        func hitShare(_ perks: DexPerks) -> Double {
            let odds = PackOpening.packOdds(setID: "s", index: index, perks: perks)
            let cards = Double(PackPricing.cardCount(setID: "s", index: index, perks: perks))
            return odds.filter { hitTiers.contains($0.tier) }
                .reduce(0) { $0 + $1.probability * cards }
        }
        // 다른 칸에서도 레어가 나오므로 절대값이 아니라 증가분을 본다.
        XCTAssertEqual(hitShare(perks) - hitShare(.none), 1, accuracy: 0.001,
                       "레어 이상이 정확히 한 장 늘어야 한다")
        XCTAssertGreaterThan(hitShare(.none), 1, "확정 한 장 위에 다른 칸의 몫이 얹힌다")
    }

    /// 중복 회피는 카드 장수도 등급 분포도 바꾸지 않는다.
    /// 바꾸면 갈갈 회수율이 함께 올라가고, 이 혜택을 고른 이유가 사라진다.
    func testDuplicateGuardChangesNeitherSizeNorOdds() {
        let index = makeIndex()
        let guarded = DexPerks(duplicateGuard: true)
        XCTAssertEqual(PackPricing.cardCount(setID: "s", index: index, perks: guarded),
                       PackPricing.cardCount(setID: "s", index: index, perks: .none))
        // 부동소수 비교라 값끼리 대조한다 — 마지막 자리 차이로 실패하면 무엇도 알려 주지 않는다.
        let guardedOdds = PackOpening.packOdds(setID: "s", index: index, perks: guarded)
        let plainOdds = PackOpening.packOdds(setID: "s", index: index, perks: .none)
        XCTAssertEqual(guardedOdds.map(\.tier), plainOdds.map(\.tier))
        for (a, b) in zip(guardedOdds, plainOdds) {
            XCTAssertEqual(a.probability, b.probability, accuracy: 1e-9, "\(a.tier) 확률이 달라졌다")
        }
    }

    /// 이미 가진 레어가 나오면 다시 뽑는다.
    ///
    /// 레어 후보가 둘뿐인 세트에서 하나를 갖고 있으면, 혜택이 켜진 팩의 레어 자리에는
    /// 반드시 나머지 한 장이 온다 — 다시 뽑을 때 방금 나온 카드를 후보에서 빼기 때문이다.
    func testDuplicateGuardRerollsAnOwnedHit() {
        var cards: [[String]] = []
        for i in 1...20 { cards.append(["s-\(i)", "c\(i)", "C"]) }
        for i in 21...30 { cards.append(["s-\(i)", "u\(i)", "U"]) }
        for i in 91...96 { cards.append(["s-\(i)", "r\(i)", "R"]) }
        let payload: [String: Any] = [
            "version": 1,
            "sets": [["id": "s", "name": "Set", "released": "2020/01/01", "cardCount": cards.count]],
            "cards": cards,
        ]
        let index = CardIndex.decode(try! JSONSerialization.data(withJSONObject: payload))!

        for seed in UInt64(1)...30 {
            var g = SeededGenerator(seed: seed)
            let pack = PackOpening.draw(setID: "s", index: index, alreadyOwned: ["s-91"],
                                        perks: DexPerks(duplicateGuard: true), using: &g)
            // 마지막 장이 레어 이상 확정 칸이다. 다른 칸에서도 레어가 나올 수 있으므로
            // 전체가 아니라 그 칸만 본다.
            XCTAssertNotEqual(pack.last?.id, "s-91", "seed \(seed): 확정 칸에 중복이 그대로 나왔다")
        }
    }

    /// 혜택이 없으면 중복도 그대로 나온다 — 위 검사가 무엇을 잠그는지 분명히 한다.
    func testWithoutTheGuardOwnedHitsStillAppear() {
        var cards: [[String]] = []
        for i in 1...20 { cards.append(["s-\(i)", "c\(i)", "C"]) }
        for i in 21...30 { cards.append(["s-\(i)", "u\(i)", "U"]) }
        for i in 91...96 { cards.append(["s-\(i)", "r\(i)", "R"]) }
        let payload: [String: Any] = [
            "version": 1,
            "sets": [["id": "s", "name": "Set", "released": "2020/01/01", "cardCount": cards.count]],
            "cards": cards,
        ]
        let index = CardIndex.decode(try! JSONSerialization.data(withJSONObject: payload))!

        var sawOwned = false
        for seed in UInt64(1)...30 {
            var g = SeededGenerator(seed: seed)
            let pack = PackOpening.draw(setID: "s", index: index, alreadyOwned: ["s-91"], using: &g)
            if pack.last?.id == "s-91" { sawOwned = true }
        }
        XCTAssertTrue(sawOwned, "혜택 없이는 확정 칸에도 중복이 나와야 한다")
    }

    /// 레어의 몫이 상위 등급으로 넘어간다. 전체 합은 여전히 1 이다.
    func testHitOddsMovesWeightFromRareToHigherTiers() {
        let index = makeIndex()
        func probability(_ tier: CardTier, _ perks: DexPerks) -> Double {
            PackOpening.packOdds(setID: "s", index: index, perks: perks)
                .first { $0.tier == tier }?.probability ?? 0
        }
        let boosted = DexPerks(hitOdds: 0.15)
        XCTAssertLessThan(probability(.rare, boosted), probability(.rare, .none))
        XCTAssertGreaterThan(probability(.doubleRare, boosted), probability(.doubleRare, .none))
        XCTAssertGreaterThan(probability(.ultraRare, boosted), probability(.ultraRare, .none))

        for perks in [DexPerks.none, boosted, DexPerks(extraHitSlot: 1), DexPerks.caps] {
            let total = PackOpening.packOdds(setID: "s", index: index, perks: perks)
                .reduce(0) { $0 + $1.probability }
            XCTAssertEqual(total, 1, accuracy: 0.0001, "확률 합이 1 이 아니다")
        }
    }

    /// 뽑기도 같은 슬롯 수를 써야 한다. 확률표만 늘어나고 실제 팩은 10장이면 표가 거짓이 된다.
    func testDrawReturnsTheExtraCard() {
        let index = makeIndex()
        var g = SeededGenerator(seed: 99)
        let plain = PackOpening.draw(setID: "s", index: index, alreadyOwned: [], using: &g)
        var g2 = SeededGenerator(seed: 99)
        let boosted = PackOpening.draw(setID: "s", index: index, alreadyOwned: [],
                                       perks: DexPerks(extraHitSlot: 1), using: &g2)
        XCTAssertEqual(plain.count, 10)
        XCTAssertEqual(boosted.count, 11)
    }

    /// 혜택을 전부 모은 상태에서도 팩을 사서 가는 것이 남는 장사가 되면 안 된다.
    ///
    /// 실제 배포되는 세트로 검사한다 — 세트마다 등급 구성이 달라 합성 데이터로는
    /// 최악의 세트를 못 만든다(실측 최악은 sv10).
    ///
    /// 기준이 무혜택 60% 가 아니라 75% 인 이유: `extraHitSlot` 은 히트 카드를 한 장 더
    /// 얹으므로 이 비율을 혼자 32% → 53% 로 밀어 올린다. 그 위에 남는 여유가 얼마 없다.
    /// 상한을 이 선에 맞춰 잡았고(할인·환급 각 10%), 100% 에는 한참 못 미쳐 팩을 돌려
    /// 재화를 늘리는 순환은 성립하지 않는다. 이 검사가 깨지면 상한을 내려야 한다.
    func testRecyclingStaysUnprofitableEvenWithEveryPerk() throws {
        let index = try XCTUnwrap(CardIndex.loadBundled())
        let perks = DexPerks.caps
        for set in index.sets {
            let odds = PackOpening.packOdds(setID: set.id, index: index, perks: perks)
            let cards = Double(PackPricing.cardCount(setID: set.id, index: index, perks: perks))
            let dust = odds.reduce(0.0) {
                $0 + $1.probability * cards * Double(CardDust.value(for: $1.tier, perks: perks))
            }
            let price = Double(PackPricing.price(setID: set.id, index: index, perks: perks))
            XCTAssertLessThan(dust / price, 0.75,
                              "\(set.id): 혜택 최대일 때 환급이 팩 값의 75% 를 넘는다")
        }
    }
}

/// 지갑 통합 — 수집이 완성을 기록하고 보상을 주는가.
@MainActor
final class DexWalletTests: XCTestCase {

    private var dir: URL!

    override func setUp() {
        super.setUp()
        dir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("dex-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: dir)
        super.tearDown()
    }

    private func dex(_ id: String, _ cards: [String], tier: Int = 2, packs: Int = 3,
                     perk: DexPerk? = nil) -> Dex {
        Dex(id: id, name: DexText(ko: id, en: id), blurb: DexText(ko: "", en: ""),
            homeSet: "home", cards: cards, tier: tier, medianPacks: 10,
            reward: DexReward(packs: packs, perks: perk.map { [$0] } ?? []))
    }

    private func makeStore(_ dexes: [Dex]) -> WalletStore {
        WalletStore(fileURL: dir.appendingPathComponent("game-state.json"), dexes: dexes)
    }

    /// 다 모이면 개봉 화면이 알리기만 한다. 보상은 수령을 눌러야 들어온다.
    func testCollectAnnouncesButDoesNotGrant() {
        let s = makeStore([dex("d", ["a", "b"], packs: 5,
                               perk: DexPerk(kind: .packDiscount, value: 0.02))])
        XCTAssertTrue(s.collect(["a"]).isEmpty, "아직 다 모이지 않았다")

        let filled = s.collect(["b"])
        XCTAssertEqual(filled.map(\.dexID), ["d"])
        XCTAssertEqual(s.packCount(setID: "home"), 0, "수령 전에는 팩이 들어오지 않는다")
        XCTAssertTrue(s.perks.isEmpty, "수령 전에는 혜택이 켜지지 않는다")
        XCTAssertEqual(s.claimableDexes.map(\.id), ["d"])
    }

    func testClaimGrantsPacksAndTurnsOnPerks() {
        let s = makeStore([dex("d", ["a"], packs: 5,
                               perk: DexPerk(kind: .packDiscount, value: 0.02))])
        s.collect(["a"])

        XCTAssertNotNil(s.claim("d"))
        XCTAssertEqual(s.packCount(setID: "home"), 5)
        XCTAssertEqual(s.claimedDexIDs, ["d"])
        XCTAssertEqual(s.perks.packDiscount, 0.02, accuracy: 0.0001)
        XCTAssertTrue(s.claimableDexes.isEmpty)
    }

    /// 다 모으지 않은 도감은 수령할 수 없다. 화면이 잘못 눌러도 지급되면 안 된다.
    func testClaimRejectedWhenNotFilled() {
        let s = makeStore([dex("d", ["a", "b"], packs: 5)])
        s.collect(["a"])
        XCTAssertNil(s.claim("d"))
        XCTAssertEqual(s.packCount(setID: "home"), 0)
        XCTAssertTrue(s.claimedDexIDs.isEmpty)
    }

    /// 두 번 주면 도감으로 팩을 무한히 만들 수 있다.
    func testClaimIsNeverGrantedTwice() {
        let s = makeStore([dex("d", ["a"], packs: 4)])
        s.collect(["a"])
        XCTAssertNotNil(s.claim("d"))
        XCTAssertNil(s.claim("d"))
        XCTAssertNil(s.claim("nope"))
        XCTAssertEqual(s.packCount(setID: "home"), 4)
    }

    /// **도감 기능이 생기기 전에 이미 모아 둔 카드도 수령 대상이어야 한다.**
    ///
    /// 완성을 이벤트로만 기록하면(개봉할 때만 판정) 예전에 모아 둔 조합은 영영 뜨지 않는다.
    /// 실제로 그렇게 나갔고, 사용자가 "완성했는데 효과가 안 붙는다" 고 알려 줬다.
    func testAlreadyOwnedCardsAreClaimableWithoutANewPull() {
        let dexes = [dex("d", ["a", "b"], packs: 3,
                         perk: DexPerk(kind: .tokenGain, value: 0.01))]
        let seeded = makeStore(dexes)
        seeded.collect(["a", "b"])          // 도감이 없던 시절에 모았다고 가정

        // 도감 목록이 나중에 붙은 상태로 다시 읽는다.
        let later = makeStore(dexes)
        XCTAssertEqual(later.claimableDexes.map(\.id), ["d"], "예전에 모은 조합도 수령 가능해야 한다")
        XCTAssertNotNil(later.claim("d"))
        XCTAssertEqual(later.perks.tokenGain, 0.01, accuracy: 0.0001)
    }

    /// 한 번의 수집으로 여러 도감이 채워질 수 있다. 전부 알려야 한다.
    func testMultipleDexesCanFillAtOnce() {
        let s = makeStore([dex("one", ["a"], tier: 1, packs: 1),
                           dex("two", ["a", "b"], tier: 4, packs: 20)])
        let filled = s.collect(["a", "b"])
        XCTAssertEqual(filled.map(\.dexID), ["two", "one"], "어려운 것을 먼저 알린다")
    }

    /// 재시작 후에도 수령 기록과 혜택이 유지돼야 한다.
    func testClaimSurvivesReload() {
        let dexes = [dex("d", ["a"], perk: DexPerk(kind: .tokenGain, value: 0.05))]
        let first = makeStore(dexes)
        first.collect(["a"])
        first.claim("d")

        let second = makeStore(dexes)
        XCTAssertEqual(second.claimedDexIDs, ["d"])
        XCTAssertEqual(second.perks.tokenGain, 0.05, accuracy: 0.0001)
    }

    /// 적립 혜택은 사용량을 부풀리지 않는다. 사용량은 통계이므로 곱해 버리면 화면이 거짓이 된다.
    func testTokenGainAddsToBalanceWithoutInflatingUsage() {
        let dexes = [dex("d", ["a"], perk: DexPerk(kind: .tokenGain, value: 0.10))]
        let s = makeStore(dexes)
        s.update(todayTokensByProvider: ["p": 0], todayDate: "2026-08-27", hasUsageData: true)
        s.collect(["a"])
        s.claim("d")

        s.update(todayTokensByProvider: ["p": 1_000], todayDate: "2026-08-27", hasUsageData: true)
        XCTAssertEqual(s.usedSinceInstall, 1_000, "사용량은 실제 값 그대로여야 한다")
        XCTAssertEqual(s.availableTokens, 1_100, "잔액에만 10% 가 더 붙는다")
    }

    /// 혜택이 없으면 잔액이 사용량과 같아야 한다 — 적립 경로를 건드린 회귀를 잡는다.
    func testBalanceUnchangedWithoutPerks() {
        let s = makeStore([])
        s.update(todayTokensByProvider: ["p": 0], todayDate: "2026-08-27", hasUsageData: true)
        s.update(todayTokensByProvider: ["p": 5_000], todayDate: "2026-08-27", hasUsageData: true)
        XCTAssertEqual(s.availableTokens, 5_000)
    }

    /// 보너스 팩 혜택은 지급 개수에 더해진다.
    func testBonusPackPerkRaisesGrantCount() {
        var tierMap: [String: Int] = [:]
        var g = SeededGenerator(seed: 7)
        let windows = [BonusWindow(key: "w", name: "W", kind: .session, utilization: 100)]
        let grants = WalletStore.evaluateGrants(windows: windows, grantTier: &tierMap,
                                               availableSets: ["s"], bonusPacks: 3, using: &g)
        XCTAssertEqual(grants.first?.count, PackConfig.bonusPackCount + 3)
    }
}

/// 혜택을 지나가는 계산은 반드시 `perks:` 를 받아야 한다.
///
/// 기본값이 `.none` 이라 인수를 빼먹어도 컴파일된다 — 그러면 화면에는 할인된 가격이 뜨는데
/// 실제 차감은 정가로 되는 식의 어긋남이 조용히 생긴다. 호출부를 소스에서 훑어 막는다.
final class DexPerkRoutingTests: XCTestCase {

    /// 정의부 자체는 검사 대상이 아니다.
    private static let exempt = ["PackOpening.swift", "DexProgress.swift"]

    private static let mustCarryPerks = [
        "PackPricing.price(", "PackPricing.cardCount(",
        "PackOpening.packOdds(", "PackOpening.draw(", "CardDust.value(",
        "PackOpening.packSlots(",
    ]

    /// 실제 개봉은 천장을 세는 호출이어야 한다. 편의 오버로드를 쓰면 보장이 사라진다.
    private static let mustCarryPity = ["PackOpening.draw("]

    func testProductionCallSitesPassPerks() throws {
        let sources = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Sources/PokePackBar")
        let enumerator = try XCTUnwrap(FileManager.default.enumerator(at: sources,
                                                                     includingPropertiesForKeys: nil))
        var offenders: [String] = []
        for case let url as URL in enumerator where url.pathExtension == "swift" {
            guard !Self.exempt.contains(url.lastPathComponent) else { continue }
            let lines = try String(contentsOf: url, encoding: .utf8)
                .split(separator: "\n", omittingEmptySubsequences: false)
            for (offset, line) in lines.enumerated() {
                guard Self.mustCarryPerks.contains(where: { line.contains($0) }) else { continue }
                // 호출이 여러 줄로 나뉘면 다음 줄에 perks: 가 온다.
                let window = lines[offset..<min(offset + 3, lines.count)].joined()
                if !window.contains("perks:") {
                    offenders.append("\(url.lastPathComponent):\(offset + 1) (perks)")
                }
                if Self.mustCarryPity.contains(where: { line.contains($0) }),
                   !window.contains("pity:") {
                    offenders.append("\(url.lastPathComponent):\(offset + 1) (pity)")
                }
            }
        }
        XCTAssertTrue(offenders.isEmpty, """
            도감 혜택을 전달하지 않는 호출부가 있다. 표시와 실제 동작이 갈라진다.
            perks: wallet.perks 를 넘긴다: \(offenders.joined(separator: ", "))
            """)
    }
}
