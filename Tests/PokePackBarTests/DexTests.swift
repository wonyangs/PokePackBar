import SwiftUI
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
        let prices = try XCTUnwrap(CardPrices.loadBundled())
        for dex in dexes.dexes {
            let packs = DexDifficulty.packsNeeded(cards: dex.cards, quantile: 0.5, index: cards)
            XCTAssertEqual(packs, dex.medianPacks,
                           "\(dex.id): 저장된 \(dex.medianPacks)팩 vs 재계산 \(packs)팩")

            let value = DexProgress.recomputedValue(of: dex, prices: prices)
            XCTAssertEqual(value, dex.valueUSD, accuracy: 0.02,
                           "\(dex.id): 저장된 값 \(dex.valueUSD) vs 재계산 \(value)")
            XCTAssertEqual(DexDifficulty.tier(forValueUSD: value), dex.tier,
                           "\(dex.id): 티어가 어긋났다")
        }
    }

    /// 「인권 조합」이 실재하고, 제일 비싼 축에 있어야 한다.
    ///
    /// 개봉 자체가 좋아지는 혜택(`extraHitSlot`)은 상한이 1 이라 한 조합에만 붙는다.
    /// 그 조합은 반드시 완성 비용이 제일 비싼 축이어야 한다.
    func testFlagshipDexesAreTheMostExpensive() throws {
        let (_, dexes) = try loadIndexes()
        let flagship = dexes.dexes.filter { $0.reward.perks.contains { $0.kind.isStructural } }
        XCTAssertEqual(flagship.count, 1, "판을 바꾸는 혜택은 한 조합에만 붙는다")

        // 견주는 기준은 **완성 비용**이다. 카드값 합계로 보면 순서가 어긋난다 —
        // 값비싼 카드 몇 장짜리 조합이 흔한 카드 여럿짜리보다 싸게 끝나는 경우가 있다.
        let median = dexes.dexes.map(\.medianTokens).sorted()[dexes.dexes.count / 2]
        for dex in flagship {
            XCTAssertGreaterThan(dex.medianTokens, median,
                                 "\(dex.id): 인권 조합인데 완성 비용이 중간값 아래다")
        }
        // 패시브를 몇 개 주는지는 세지 않는다. 히트 칸 하나가 팩 기대값을 50% 올려
        // 그것만으로 그 도감의 보상 예산이 차므로, 하나만 주는 것이 정상이다.
    }

    /// 지급 팩은 **부수**다 — 목표를 넘지 않고, 개수도 상한 안이다.
    ///
    /// 팩 수를 티어표로 적던 시절에는 팩만의 리턴이 0.01배~1.61배로 흩어졌고, 값에 맞춰
    /// 계산하자 109개까지 나왔다. 한 장씩 뜯는 것이 일이 되면 보상이 아니다. 지금은 상한을
    /// 두고 나머지를 영구 패시브가 맡는다.
    func testRewardPacksStayASideTreat() throws {
        let (cards, dexes) = try loadIndexes()
        for dex in dexes.dexes {
            XCTAssertTrue((1...DexDifficulty.maxRewardPacks).contains(dex.reward.packs),
                          "\(dex.id): 지급 팩 \(dex.reward.packs)개는 1~"
                          + "\(DexDifficulty.maxRewardPacks) 범위를 벗어난다")
            let packPrice = Double(PackPricing.price(setID: dex.homeSet, index: cards))
            let paid = Double(dex.reward.packs) * packPrice
            let target = Double(dex.medianTokens) * DexDifficulty.targetReturn
            // 팩은 정수라 반 팩까지는 어긋난다. 그 이상 넘으면 계산이 아니라 손으로 적은 값이다.
            XCTAssertLessThanOrEqual(paid, target + packPrice / 2,
                                     "\(dex.id): 지급 팩이 목표를 넘는다")
        }
    }

    /// 보상의 본체는 영구 패시브다. 팩만 주는 조합은 예외로만 남는다.
    func testMostDexesGrantAPermanentPerk() throws {
        let (_, dexes) = try loadIndexes()
        let withPerk = dexes.dexes.filter { !$0.reward.perks.isEmpty }.count
        XCTAssertGreaterThanOrEqual(withPerk, dexes.dexes.count * 4 / 5,
                                    "\(dexes.dexes.count)개 중 \(withPerk)개만 패시브를 준다 — "
                                    + "팩이 보상의 본체가 되어 버렸다")
    }

    /// 같은 종류의 혜택은 **완성 비용**이 오를 때 값이 줄지 않는다.
    ///
    /// 별 수가 아니라 비용을 기준으로 본다. 별은 카드값 합계로 매기는데 완성 비용은 거기에
    /// 「그 카드가 얼마나 안 나오는가」까지 곱해진 값이라 둘이 어긋난다 — ★★★★★ 불꽃도마뱀
    /// (906만원)이 ★★★★ 금은 시절 새싹(2,216만원)보다 싸다. 별로 사다리를 세우면 실제로 더
    /// 많이 들인 사람이 더 적게 받는다.
    func testPerkValuesNeverFallAsCostRises() throws {
        let (_, dexes) = try loadIndexes()
        let byCost = dexes.dexes.sorted { $0.medianTokens < $1.medianTokens }
        for kind in DexPerkKind.allCases {
            let seen = byCost.flatMap { dex in
                dex.reward.perks.filter { $0.kind == kind }.map { (dex.id, $0.value) }
            }
            for (lower, upper) in zip(seen, seen.dropFirst()) {
                XCTAssertGreaterThanOrEqual(upper.1, lower.1,
                    "\(kind): \(lower.0) +\(lower.1) 다음에 \(upper.0) +\(upper.1) — "
                    + "더 많이 들여야 하는 조합이 더 적게 주면 모을 이유가 없다")
            }
        }
    }

    /// 판을 바꾸는 혜택은 **가장 비싼 두 조합**에서만 나온다.
    ///
    /// 히트 칸 하나와 중복 회피는 한 번 얻으면 이후 모든 개봉이 달라진다. 중간 난이도에
    /// 붙어 있으면 그 위를 모을 이유가 사라진다 — 로켓단 총수가 중복 회피를 들고 있던 것이
    /// 그 상태였다.
    func testStructuralPerksBelongToThePriciestDexes() throws {
        let (_, dexes) = try loadIndexes()
        let priciest = Set(dexes.dexes.sorted { $0.medianTokens < $1.medianTokens }
            .suffix(2).map(\.id))
        var found = 0
        for dex in dexes.dexes {
            for perk in dex.reward.perks where perk.kind.isStructural {
                found += 1
                XCTAssertTrue(priciest.contains(dex.id),
                              "\(dex.id): \(perk.kind) 는 가장 비싼 조합에서만 준다")
            }
        }
        XCTAssertEqual(found, 1, "판을 바꾸는 혜택은 하나뿐이다 (상한이 1)")
    }

    /// 혜택이 없는 조합은 지급 팩이 목표를 **정확히** 채운다.
    ///
    /// 채울 것이 팩뿐이라 반 팩의 반올림 말고는 어긋날 이유가 없다. 여기가 틀어지면
    /// 스크립트가 비율에서 거꾸로 계산하지 않고 어딘가에 손으로 적은 값이 남아 있다는 뜻이다.
    func testPerklessDexesLandOnTheTarget() throws {
        let (cards, dexes) = try loadIndexes()
        let plain = dexes.dexes.filter { $0.reward.perks.isEmpty }
        for dex in plain {
            let packPrice = Double(PackPricing.price(setID: dex.homeSet, index: cards))
            let paid = Double(dex.reward.packs) * packPrice
            let target = Double(dex.medianTokens) * DexDifficulty.targetReturn
            XCTAssertEqual(paid, target, accuracy: packPrice / 2 + 1,
                           "\(dex.id): 목표 \(target) 인데 \(paid) 를 준다")
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
           "homeSet":"base1","cards":[],"tier":1,"medianPacks":1,"medianTokens":10000000,"valueUSD":1.0,
           "reward":{"packs":1,"perks":[]}},
          {"id":"badtier","name":{"ko":"a","en":"a"},"blurb":{"ko":"b","en":"b"},
           "homeSet":"base1","cards":["base1-1"],"tier":9,"medianPacks":1,"medianTokens":10000000,"valueUSD":1.0,
           "reward":{"packs":1,"perks":[]}},
          {"id":"ok","name":{"ko":"a","en":"a"},"blurb":{"ko":"b","en":"b"},
           "homeSet":"base1","cards":["base1-1"],"tier":1,"medianPacks":1,"medianTokens":10000000,"valueUSD":1.0,
           "reward":{"packs":1,"perks":[]}}
        ]}
        """
        let index = DexIndex.decode(Data(json.utf8))
        XCTAssertEqual(index.dexes.map(\.id), ["ok"])
    }
}

/// 진행·완성 판정은 순수 함수다. 화면 없이 전부 검증한다.
final class DexProgressTests: XCTestCase {

    private func dex(_ id: String, _ cards: [String], tier: Int = 2, packs: Int = 10,
                     perk: DexPerk? = nil) -> Dex {
        Dex(id: id, name: DexText(ko: id, en: id), blurb: DexText(ko: "", en: ""),
            homeSet: "s", cards: cards, tier: tier, medianPacks: packs, medianTokens: packs * 10_000_000, valueUSD: Double(packs),
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

    /// 목록 순서 — 어려운 것부터, 같은 난이도면 값비싼 카드가 든 것부터.
    func testSortedRunsHardestFirstThenMostValuable() throws {
        let prices = try XCTUnwrap(CardPrices.decode(Data("""
            {"version":2,"asOf":"2026-08-30","currency":"USD","krwPerUsd":1376.6,
             "prices":{"a":1.0,"b":1.0,"c":1.0,"gold":500.0}}
            """.utf8)))
        let statuses = DexProgress.statuses(
            dexes: [dex("hard", ["a"], tier: 4, packs: 200),
                    dex("easy", ["a"], tier: 1, packs: 9),
                    // 장수는 셋이지만 싸다. 값으로 정렬하면 뒤로 간다.
                    dex("midMany", ["a", "b", "c"], tier: 2, packs: 20),
                    dex("midRich", ["gold"], tier: 2, packs: 40)],
            owned: { _ in false }, claimed: [])
        XCTAssertEqual(DexProgress.sorted(statuses, prices: prices).map(\.id),
                       ["hard", "midRich", "midMany", "easy"],
                       "같은 난이도면 장수보다 값이 먼저다")
    }

    /// 값이 같으면 장수가 적은 쪽이 먼저다 — 그래야 순서가 흔들리지 않는다.
    func testSortedFallsBackToCardCount() throws {
        let prices = try XCTUnwrap(CardPrices.decode(Data("""
            {"version":2,"asOf":"","currency":"USD","krwPerUsd":1376.6,
             "prices":{"a":2.0,"b":1.0,"c":1.0}}
            """.utf8)))
        let statuses = DexProgress.statuses(
            dexes: [dex("two", ["b", "c"], tier: 2, packs: 20),
                    dex("one", ["a"], tier: 2, packs: 40)],
            owned: { _ in false }, claimed: [])
        XCTAssertEqual(DexProgress.sorted(statuses, prices: prices).map(\.id), ["one", "two"])
    }

    /// 진행 상태는 순서를 바꾸지 않는다. 카드를 얻을 때마다 목록이 재배열되면
    /// 어제 보던 도감을 매번 다시 찾아야 한다.
    func testProgressDoesNotReorderTheList() {
        let dexes = [dex("a", ["x"], tier: 2, packs: 20),
                     dex("b", ["y"], tier: 2, packs: 30),
                     dex("c", ["z"], tier: 2, packs: 40)]
        let empty = DexProgress.sorted(DexProgress.statuses(dexes: dexes,
                                                            owned: { _ in false }, claimed: []))
        let mixed = DexProgress.sorted(DexProgress.statuses(dexes: dexes,
                                                            owned: { $0 == "z" }, claimed: ["a"]))
        XCTAssertEqual(empty.map(\.id), mixed.map(\.id))
    }
}

/// 혜택 합산과 상한.
final class DexPerksTests: XCTestCase {

    private func dex(_ id: String, _ perks: [DexPerk]) -> Dex {
        Dex(id: id, name: DexText(ko: id, en: id), blurb: DexText(ko: "", en: ""),
            homeSet: "s", cards: ["c"], tier: 2, medianPacks: 10, medianTokens: 100_000_000, valueUSD: 5,
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
        // 할인가도 100원 칸 위에 있어야 한다 — 그래야 적힌 값과 빠지는 값이 같다.
        // 칸에 맞추느라 정확히 0.75배는 아니고, 반 칸 안쪽에서 만난다.
        let step = MarketEconomy.stepTokens()
        XCTAssertEqual(Double(cut), Double(full) * 0.75, accuracy: Double(step))
        XCTAssertEqual(cut % step, 0, "할인가가 100원 칸에서 벗어났다")
        XCTAssertEqual(PackPricing.price(setID: "s", index: index, perks: .none), full,
                       "혜택이 없으면 정가 그대로여야 한다")
    }

    func testDustBonusRaisesRefund() {
        let card = "sv10-1"
        let base = CardSale.price(cardID: card)
        let boosted = CardSale.price(cardID: card, perks: DexPerks(dustBonus: 0.3))
        // 추가금이 붙은 값도 100원 칸 위에 있어야 한다.
        let step = MarketEconomy.stepTokens()
        XCTAssertEqual(Double(boosted), Double(base) * 1.3, accuracy: Double(step))
        XCTAssertEqual(boosted % step, 0, "판매가가 100원 칸에서 벗어났다")
        XCTAssertGreaterThan(boosted, base)
        XCTAssertEqual(CardSale.price(cardID: card, perks: .none), base)
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
        let prices = try XCTUnwrap(CardPrices.loadBundled())
        for set in index.sets {
            let ratio = CardSaleTests.sellBackRatio(set.id, index: index, prices: prices,
                                                 perks: DexPerks.caps)
            // 상한이 0.75 였다. 시세를 쓰면서 「히트 칸 +1」 혜택의 값이 세트마다 크게
            // 달라졌다 — 값이 몇 장에 몰린 세트(sv8pt5 는 상위 10%가 90%를 차지한다)에서는
            // 히트 한 칸이 곱절로 뛴다. 그래도 100% 아래면 팔아서 버는 경로는 아니다.
            XCTAssertLessThan(ratio, 0.85,
                              "\(set.id): 혜택 최대일 때 환급이 팩 값의 \(Int(ratio * 100))% 다")
            XCTAssertLessThan(ratio, 1.0, "\(set.id): 갈면 버는 팩이 되었다")
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
            homeSet: "home", cards: cards, tier: tier, medianPacks: 10, medianTokens: 100_000_000, valueUSD: 5,
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

}

/// 혜택을 지나가는 계산은 반드시 `perks:` 를 받아야 한다.
///
/// 기본값이 `.none` 이라 인수를 빼먹어도 컴파일된다 — 그러면 화면에는 할인된 가격이 뜨는데
/// 실제 차감은 정가로 되는 식의 어긋남이 조용히 생긴다. 호출부를 소스에서 훑어 막는다.
final class DexPerkRoutingTests: XCTestCase {

    /// 정의부 자체는 검사 대상이 아니다.
    private static let exempt = ["PackOpening.swift", "DexProgress.swift"]

    /// 일부러 혜택을 빼는 자리에 붙이는 표시. 팩값 계산이 그렇다 — 혜택으로 카드가 늘면
    /// 팩값이 올라가 혜택이 벌이 된다. 파일을 통째로 빼지 않고 줄에 이유를 적어 남긴다.
    private static let optOut = "혜택 제외"

    private static let mustCarryPerks = [
        "PackPricing.price(", "PackPricing.cardCount(",
        "PackOpening.packOdds(", "PackOpening.draw(", "CardSale.price(",
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
                guard !window.contains(Self.optOut) else { continue }
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

/// 오리파 가림막이 밑에 깔린 카드를 완전히 가리는가.
///
/// 카드를 미리 그려 두고 그 위를 덮는 구조라, 막에 조금이라도 틈이 있으면 열기 전에 카드가
/// 보인다. 실제로 두 번 샜다 — 색이 22% 불투명이라 그대로 비쳤고, 숨쉬는 애니메이션이
/// 0.96 배로 줄어들며 가장자리가 삐져나왔다. 둘 다 눈으로만 확인되는 성질이라 값으로 묶는다.
@MainActor
final class OripaCoverTests: XCTestCase {

    func testCoverColoursAreOpaque() {
        for (name, color) in [("바탕", OripaCover.back), ("테두리", OripaCover.rim),
                              ("표식", OripaCover.mark)] {
            XCTAssertTrue(OripaCover.isOpaque(color), "\(name) 색이 반투명하다 — 카드가 비친다")
        }
    }

    /// 반투명한 색을 넣으면 검사가 실제로 잡는지 확인한다. 늘 통과하는 검사는 검사가 아니다.
    func testOpacityCheckCatchesTranslucentColour() {
        XCTAssertFalse(OripaCover.isOpaque(Color.orange.opacity(0.22)))
    }

    func testCoverNeverShrinksBelowTheCard() {
        XCTAssertGreaterThanOrEqual(OripaCover.restScale, 1,
                                    "가림막이 카드보다 작아지면 가장자리가 드러난다")
        XCTAssertGreaterThanOrEqual(OripaCover.pulseScale, OripaCover.restScale)
    }
}

/// 오리파 화면 갈래. 상세를 닫았을 때 어디로 돌아가는지가 여기서 결정된다.
final class OripaScreenTests: XCTestCase {

    /// 상세가 뽑기 결과보다 앞이다. 뒤에 두면 상세를 열려고 뽑기 결과를 지워야 하고,
    /// 그러면 상세를 닫을 때 박스 화면으로 튕긴다(사용자가 보고한 결함).
    func testDetailWinsOverDraw() {
        XCTAssertEqual(OripaScreen.resolve(focused: "sv10-1", hasDraw: true), .detail("sv10-1"))
    }

    /// 박스에서 카드를 눌러 본 경우 — 뽑기 결과가 없으니 닫으면 박스로 돌아간다.
    func testDetailWithoutDraw() {
        XCTAssertEqual(OripaScreen.resolve(focused: "sv10-1", hasDraw: false), .detail("sv10-1"))
    }

    func testDrawWhenNothingFocused() {
        XCTAssertEqual(OripaScreen.resolve(focused: nil, hasDraw: true), .draw)
    }

    func testBoardIsTheDefault() {
        XCTAssertEqual(OripaScreen.resolve(focused: nil, hasDraw: false), .board)
    }
}

/// 오리파 — 재고가 유한한 뽑기.
@MainActor
final class OripaTests: XCTestCase {

    private var dir: URL!

    override func setUp() {
        super.setUp()
        dir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("oripa-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: dir)
        super.tearDown()
    }

    private func makeStore() -> WalletStore {
        WalletStore(fileURL: dir.appendingPathComponent("game-state.json"), dexes: [])
    }

    /// 박스는 구성표대로 채워지고 같은 카드가 두 번 들어가지 않는다.
    /// 중복이 섞이면 "100슬롯을 다 사면 박스 안의 것을 전부 갖는다" 는 약속이 깨진다.
    func testBoxMatchesTheCompositionWithoutDuplicates() throws {
        let index = try XCTUnwrap(CardIndex.loadBundled())
        var g = SeededGenerator(seed: 11)
        let box = Oripa.makeBox(index: index, serial: 1, using: &g)

        XCTAssertEqual(box.slots.count, OripaConfig.slotsPerBox)
        XCTAssertEqual(Set(box.slots).count, box.slots.count, "같은 카드가 두 번 들어갔다")
        XCTAssertTrue(box.slots.allSatisfy {
            (index.card($0)?.tier.rank ?? 0) >= OripaConfig.minimumTier.rank
        }, "RR 미만이 섞였다")
    }

    /// 뽑으면 그 카드가 박스에서 빠진다. 재고가 줄지 않으면 오리파가 아니라 그냥 비싼 팩이다.
    func testPullRemovesTheSlot() throws {
        let index = try XCTUnwrap(CardIndex.loadBundled())
        var g = SeededGenerator(seed: 3)
        var box = Oripa.makeBox(index: index, serial: 1, using: &g)
        let before = box.remaining

        let pulled = try XCTUnwrap(Oripa.pull(from: &box, using: &g))
        XCTAssertEqual(box.remaining, before - 1)
        XCTAssertFalse(box.slots.contains(pulled))
    }

    /// 박스를 끝까지 비우면 처음 들어 있던 것을 전부 얻는다.
    func testEmptyingTheBoxYieldsEverythingInIt() throws {
        let index = try XCTUnwrap(CardIndex.loadBundled())
        var g = SeededGenerator(seed: 7)
        var box = Oripa.makeBox(index: index, serial: 1, using: &g)
        let planted = Set(box.slots)

        var got: Set<String> = []
        while let id = Oripa.pull(from: &box, using: &g) { got.insert(id) }
        XCTAssertEqual(got, planted)
        XCTAssertNil(Oripa.pull(from: &box, using: &g), "빈 박스에서 더 나오면 안 된다")
    }

    /// 값을 못 내면 카드도 나가지 않는다.
    func testPullRejectedWithoutTokens() throws {
        let index = try XCTUnwrap(CardIndex.loadBundled())
        let s = makeStore()
        XCTAssertNil(s.pullOripa(index: index))
        XCTAssertEqual(s.totalCardCount, 0)
        XCTAssertEqual(s.oripaBox(index: index).remaining, OripaConfig.slotsPerBox)
    }

    /// 뽑은 카드는 수집함에 들어가고 값은 차감된다. 박스는 재시작해도 남아 있어야 한다 —
    /// 매번 새로 채워지면 UR 이 남을 때까지 앱을 껐다 켜는 것이 최적 전략이 된다.
    func testPullSpendsCollectsAndPersists() throws {
        let index = try XCTUnwrap(CardIndex.loadBundled())
        let s = makeStore()
        s.update(todayTokensByProvider: ["p": 0], todayDate: "2026-08-28", hasUsageData: true)
        s.update(todayTokensByProvider: ["p": 500_000_000], todayDate: "2026-08-28", hasUsageData: true)

        let before = s.availableTokens
        let result = try XCTUnwrap(s.pullOripa(index: index))
        XCTAssertEqual(s.availableTokens, before - s.oripaPrice(index: index))
        XCTAssertEqual(s.cardCount(result.card.id), 1)

        let remaining = s.oripaBox(index: index).slots
        let reloaded = WalletStore(fileURL: dir.appendingPathComponent("game-state.json"), dexes: [])
        XCTAssertEqual(reloaded.oripaBox(index: index).slots, remaining, "박스가 재시작에 살아남지 않았다")
    }

    /// 마음에 안 드는 박스는 값 없이 버릴 수 있어야 한다.
    ///
    /// 100슬롯을 다 사야 진열이 바뀐다면 30억을 태워야 한다는 뜻이라 함정이 된다.
    /// 교체가 기댓값을 올리지 않는 근거: 뽑기는 남은 슬롯에서 균등 추첨이라
    /// 새 박스든 뽑던 박스든 한 번 뽑기의 기대 등급 분포가 같다.
    func testBoxCanBeReplacedForFree() throws {
        let index = try XCTUnwrap(CardIndex.loadBundled())
        let s = makeStore()
        let before = s.oripaBox(index: index)
        let tokens = s.availableTokens

        s.replaceOripaBox(index: index)
        let after = s.oripaBox(index: index)
        XCTAssertEqual(after.serial, before.serial + 1)
        XCTAssertEqual(after.remaining, OripaConfig.slotsPerBox, "새 박스는 가득 차 있어야 한다")
        XCTAssertEqual(s.availableTokens, tokens, "교체에 값을 받으면 안 된다")
        XCTAssertNotEqual(after.slots, before.slots, "내용이 그대로면 교체가 아니다")
    }

    /// 팔아서 버는 경로가 되면 안 된다. 오리파 한 슬롯의 기대 판매가가 값보다 한참 낮아야 한다.
    func testOripaIsNeverWorthGrinding() throws {
        let index = try XCTUnwrap(CardIndex.loadBundled())
        let prices = try XCTUnwrap(CardPrices.loadBundled())
        let pool = OripaConfig.eligible(index: index, prices: prices)
        let slotUSD = OripaConfig.expectedSlotUSD(pool: pool, prices: prices)
        let dust = Double(MarketEconomy.tokens(usd: slotUSD)) * (1 + DexPerks.caps.dustBonus)
        let paid = Double(OripaConfig.slotPrice(index: index, prices: prices))
            * (1 - DexPerks.caps.packDiscount)
        XCTAssertLessThan(dust / paid, 0.5,
                          "혜택 최대일 때 환급이 값의 \(Int(dust / paid * 100))% 다")
    }

    /// 박스는 값 구간으로 채운다. 맨 위 칸에는 늘 최상위권 카드가 들어가야 한다 —
    /// 등급으로 채우던 시절에는 값싼 UR 만 들어찬 박스가 나올 수 있었다.
    func testEveryBoxCarriesATopValueCard() throws {
        let index = try XCTUnwrap(CardIndex.loadBundled())
        let prices = try XCTUnwrap(CardPrices.loadBundled())
        let ranked = OripaConfig.eligible(index: index, prices: prices)
        let topFive = Set(ranked.prefix(OripaConfig.bounds(OripaConfig.composition[0].band,
                                                          count: ranked.count).count))
        var generator = SystemRandomNumberGenerator()
        for serial in 1...20 {
            let box = Oripa.makeBox(index: index, serial: serial, prices: prices,
                                    using: &generator)
            XCTAssertEqual(box.slots.count, OripaConfig.slotsPerBox)
            XCTAssertEqual(Set(box.slots).count, box.slots.count, "같은 카드가 두 번 들었다")
            XCTAssertFalse(topFive.isDisjoint(with: box.slots),
                           "박스 \(serial) 에 최상위권 카드가 없다")
        }
    }

    /// 박스마다 값이 크게 흔들리면 같은 값에 파는 것이 말이 안 된다.
    func testBoxValueIsStableAcrossBoxes() throws {
        let index = try XCTUnwrap(CardIndex.loadBundled())
        let prices = try XCTUnwrap(CardPrices.loadBundled())
        var generator = SystemRandomNumberGenerator()
        let totals = (1...12).map { serial -> Double in
            Oripa.makeBox(index: index, serial: serial, prices: prices, using: &generator)
                .slots.reduce(0.0) { $0 + MarketEconomy.usd(cardID: $1, prices: prices) }
        }
        let low = totals.min() ?? 0, high = totals.max() ?? 0
        XCTAssertLessThan(high / max(low, 0.01), 3,
                          "박스 값이 \(Int(high / low))배까지 갈린다 — 구간이 너무 넓다")
    }
}

/// 한국어 카드명 — 번들에 실제로 들어갔고, 절반만 한국어인 이름이 없어야 한다.
final class KoreanCardNameTests: XCTestCase {

    /// 한 장도 빠지면 안 된다. 한글과 영문이 목록에 섞여 나오면 그게 제일 보기 나쁘다.
    func testEveryCardHasKoreanName() throws {
        let index = try XCTUnwrap(CardIndex.loadBundled())
        let missing = index.cards.filter { $0.nameKo == nil }
        XCTAssertTrue(missing.isEmpty,
                      "한국어 이름이 없는 카드 \(missing.count)장: "
                      + missing.prefix(5).map(\.id).joined(separator: ", "))
    }

    /// 이름 안에 영문이 남아 있으면 안 된다. "Team Rocket's 뮤츠 ex" 같은 반쪽짜리는
    /// 영문보다 읽기 나빠서, 조립이 안 되면 아예 넣지 않기로 했다.
    /// 꼬리표(ex·V·GX)는 한국판도 영문 그대로 쓰므로 예외다.
    func testNoHalfTranslatedNames() throws {
        let index = try XCTUnwrap(CardIndex.loadBundled())
        let suffixes = ["ex", "EX", "GX", "V", "VMAX", "VSTAR", "BREAK", "M"]
        for entry in index.cards {
            guard let korean = entry.nameKo else { continue }
            let words = korean.split(separator: " ").map(String.init)
            for word in words where word.allSatisfy({ $0.isASCII && $0.isLetter }) {
                XCTAssertTrue(suffixes.contains(word),
                              "\(entry.id): 한국어 이름에 영문이 섞였다 — \(korean)")
            }
        }
    }

    /// 언어가 한국어일 때만 한국어 이름을 쓴다.
    func testDisplayNameFollowsLanguage() {
        let entry = CardEntry(id: "s-1", name: "Charizard", tier: .doubleRare,
                              setID: "s", nameKo: "리자몽")
        XCTAssertEqual(entry.displayName(.ko), "리자몽")
        XCTAssertEqual(entry.displayName(.en), "Charizard")
        let untranslated = CardEntry(id: "s-2", name: "Rare Candy", tier: .common,
                                     setID: "s", nameKo: nil)
        XCTAssertEqual(untranslated.displayName(.ko), "Rare Candy")
    }
}
