import Foundation

/// 메뉴바에 올릴 카드를 고른다.
///
/// ```
/// 최애 카드(지정했고 아직 갖고 있다) → 가진 것 중 가장 높은 등급 → 없음(기존 기호)
/// ```
///
/// 순수 함수로 둔다. 입력이 전부 값이라 화면 없이 검증할 수 있고, 메뉴바는 한 번 잘못되면
/// 사용자가 하루 종일 보는 자리라 규칙이 눈으로 확인되는 편이 낫다.
enum MenuBarCard {

    /// 같은 등급이 여럿일 때의 순서. 뽑은 시각을 저장하지 않으므로 규칙으로 고정한다 —
    /// 새로 나온 세트를 먼저, 그 안에서는 카드 번호가 앞인 것을 먼저 쓴다.
    /// 세트 출시일이 같거나 알 수 없으면 세트 ID 로 갈라 항상 같은 결과가 나오게 한다.
    static func precedes(_ a: CardEntry, _ b: CardEntry, sets: [String: CardSet]) -> Bool {
        if a.tier.rank != b.tier.rank { return a.tier.rank > b.tier.rank }
        let releasedA = sets[a.setID]?.released ?? ""
        let releasedB = sets[b.setID]?.released ?? ""
        if releasedA != releasedB { return releasedA > releasedB }
        if a.setID != b.setID { return a.setID < b.setID }
        return number(a.id) < number(b.id)
    }

    /// 카드 ID 뒤쪽 번호. "sv8pt5-160" → 160. 숫자가 아닌 접미(프로모 등)는 뒤로 보낸다.
    static func number(_ cardID: String) -> Int {
        guard let dash = cardID.lastIndex(of: "-") else { return .max }
        let tail = cardID[cardID.index(after: dash)...]
        return Int(tail) ?? .max
    }

    /// 기본 에너지는 후보에서 뺀다. 메뉴바에 에너지 카드가 올라오면 상이 아니라 잡음이다.
    static func isEligible(_ entry: CardEntry) -> Bool { entry.tier != .energy }

    /// 메뉴바에 올릴 카드. 없으면 nil — 호출부가 기존 기호를 쓴다.
    static func resolve(favorite: String?, owned: [String: Int], index: CardIndex?) -> CardEntry? {
        guard let index else { return nil }

        // 최애 카드를 아직 갖고 있으면 그것으로 끝낸다.
        if let favorite, (owned[favorite] ?? 0) > 0,
           let entry = index.card(favorite), isEligible(entry) {
            return entry
        }

        let sets = Dictionary(uniqueKeysWithValues: index.sets.map { ($0.id, $0) })
        return owned
            .filter { $0.value > 0 }
            .compactMap { index.card($0.key) }
            .filter(isEligible)
            .min { precedes($0, $1, sets: sets) }
    }
}
