import Foundation

/// 오리파 — 카드샵이 팩을 미리 다 까서 상위 등급만 골라 담아 파는 뽑기.
///
/// 부스터 팩과 근본이 다르다. 팩은 매번 독립 추첨이지만 오리파는 **재고가 유한하다.**
/// 100슬롯짜리 박스에 무엇이 들었는지 미리 정해져 있고, 한 장씩 팔려 나가면 남은 것이 줄어든다.
/// "아직 UR 이 남아 있다" 는 긴장이 여기서 나온다.
///
/// 실물 오리파의 고질적인 문제는 검증 불가능성이다 — 공식 제품이 아니라서 당첨 카드가 실제로
/// 들어 있는지조차 확인할 수 없다. 여기서는 반대로 간다. **박스 안 카드를 전부 공개하고**
/// 남은 개수를 실시간으로 보여 준다. 팩 확률을 칸별로 공시하기로 한 것과 같은 원칙이다.
enum OripaConfig {
    /// 한 슬롯 값. 일반 팩(1천만)의 세 배다.
    ///
    /// 팩으로 UR 을 노리면 중간 390팩(39억)이 든다. 이 값이면 오리파 쪽이 2.6배 빠르고,
    /// 대신 원하는 카드가 그 박스에 들어 있어야 한다. 가루 회수율은 12.7% 로 일반 팩(32%)의
    /// 절반도 안 되므로 갈아서 버는 경로로는 쓸 수 없다.
    static let slotPrice = 30_000_000

    /// 박스 구성. 전 세트의 상위 등급에서 뽑는다 — 오리파는 시리즈를 가리지 않는다.
    static let composition: [(tier: CardTier, count: Int)] = [
        (.ultraRare, 1), (.specialArtRare, 4), (.superRare, 10),
        (.artRare, 15), (.tripleRare, 20), (.doubleRare, 50),
    ]

    static var slotsPerBox: Int { composition.reduce(0) { $0 + $1.count } }
}

/// 뽑기 한 박스. 남은 슬롯이 곧 재고다.
struct OripaBox: Codable, Sendable, Equatable {
    /// 남은 카드 ID. 한 장 뽑으면 여기서 빠진다.
    var slots: [String]
    /// 몇 번째 박스인가. 다 팔리면 새 박스가 들어오고 이 값이 오른다.
    var serial: Int

    var remaining: Int { slots.count }

    var isEmpty: Bool { slots.isEmpty }
}

enum Oripa {

    /// 새 박스를 만든다. 등급별로 정해진 수만큼 서로 다른 카드를 고른다.
    ///
    /// 같은 카드를 두 번 넣지 않는다 — 100슬롯을 다 사면 박스 안의 것을 전부 갖게 되는 것이
    /// 이 뽑기의 확정 경로이고, 중복이 섞이면 그 약속이 깨진다.
    static func makeBox(index: CardIndex, serial: Int,
                        using generator: inout some RandomNumberGenerator) -> OripaBox {
        var slots: [String] = []
        for entry in OripaConfig.composition {
            var pool = index.cards.filter { $0.tier == entry.tier }.map(\.id)
            guard !pool.isEmpty else { continue }
            for _ in 0..<entry.count {
                guard !pool.isEmpty else { break }
                let pick = Int(generator.next(upperBound: UInt64(pool.count)))
                slots.append(pool.remove(at: pick))
            }
        }
        return OripaBox(slots: slots, serial: serial)
    }

    /// 한 슬롯을 뽑는다. 남은 것 중 무작위로 하나를 빼서 돌려준다.
    static func pull(from box: inout OripaBox,
                     using generator: inout some RandomNumberGenerator) -> String? {
        guard !box.slots.isEmpty else { return nil }
        let pick = Int(generator.next(upperBound: UInt64(box.slots.count)))
        return box.slots.remove(at: pick)
    }

    /// 남은 등급별 개수. 화면이 "UR 아직 1장 남음" 을 보여줄 때 쓴다.
    static func remainingByTier(_ box: OripaBox, index: CardIndex) -> [(tier: CardTier, count: Int)] {
        var counts: [CardTier: Int] = [:]
        for id in box.slots {
            guard let tier = index.card(id)?.tier else { continue }
            counts[tier, default: 0] += 1
        }
        return counts.map { (tier: $0.key, count: $0.value) }
            .sorted { $0.tier.rank > $1.tier.rank }
    }
}
