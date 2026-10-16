import Foundation

/// 카드 한 장을 어느 팩에서, 얼마나 자주 얻는가. 카드 상세와 마켓 판매 글이 같이 쓴다.
///
/// 출처 팩은 카드 번호의 세트가 아니라 실제로 뽑히는 본팩이다. Trainer Gallery, Shiny Vault 같은
/// 별도 번호 서브셋은 부모 팩에서 나온다(`CardEntry.setID`).
struct CardSource: Equatable {
    let setID: String
    let setName: String
    /// 실물 카드 하단의 번호(4/102).
    let number: String?
    /// 그 팩 하나에서 이 카드가 나오는 기대 장수. 칸마다 실제로 뽑히는 풀로 나눠 센 값이라
    /// 같은 등급이라도 카드마다 다르다(`PackOpening.cardPullRates`).
    let perPack: Double

    /// `perks` 는 상점 확률표와 같은 것을 넘긴다(`WalletStore.openingPerks`). 실제 확률 모드면 혜택이 빠진다.
    static func of(cardID: String, index: CardIndex, perks: DexPerks) -> CardSource? {
        guard let entry = index.card(cardID) else { return nil }
        let rate = PackOpening.cardPullRates(setID: entry.setID, index: index, perks: perks)[cardID] ?? 0
        return CardSource(setID: entry.setID, setName: index.set(entry.setID)?.name ?? entry.setID,
                          number: index.numberLabel(cardID), perPack: rate)
    }

    /// 몇 팩에 한 장 꼴인가. 팩마다 한 장 넘게 나오면 nil, 나오지 않으면 nil.
    var packsPerCard: Int? {
        guard perPack > 0, perPack < 1 else { return nil }
        return max(1, Int((1 / perPack).rounded()))
    }

    /// 확률 줄에 적을 말. 「약 120팩에 1장」처럼 팩 수로 읽는다 — 0.83% 보다 얼마나 사야 하는지가 바로 읽힌다.
    func chanceText(_ l: L) -> String? {
        guard perPack > 0 else { return nil }
        guard let packs = packsPerCard else { return l.pullEveryPack }
        return l.pullOneIn(Self.grouped(packs))
    }

    private static func grouped(_ value: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }
}
