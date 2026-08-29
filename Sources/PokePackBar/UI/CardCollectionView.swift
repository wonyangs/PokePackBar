import SwiftUI

/// 컬렉션 — 수집한 카드를 격자로 보고, 클릭하면 상세를 본다.
///
/// 아직 못 얻은 카드도 자리를 남겨 흑백으로 보여준다. 수집 진행도가 드러나야
/// 무엇을 더 모아야 하는지 알 수 있다.
@MainActor
struct CardCollectionView: View {
    let wallet: WalletStore
    let index: CardIndex?

    @State private var selectedSet: String?
    @State private var selectedTier: CardTier?
    @State private var selectedCard: String?

    private var visible: [CardEntry] {
        guard let index else { return [] }
        let pool = Self.filtered(index.cards, set: selectedSet, tier: selectedTier)
        return Self.sorted(pool, owned: { wallet.cardCount($0) > 0 })
    }

    /// 세트와 등급을 함께 건다. 둘 다 nil 이면 전체다.
    ///
    /// 순수 함수로 분리해 검증할 수 있게 둔다 — 필터를 눈으로만 확인하면
    /// 등급이나 세트를 추가할 때 조용히 어긋난다.
    static func filtered(_ entries: [CardEntry], set: String?, tier: CardTier?) -> [CardEntry] {
        entries.filter { entry in
            (set == nil || entry.setID == set) && (tier == nil || entry.tier == tier)
        }
    }

    /// 보유한 카드를 위로, 그 안에서 희귀한 것을 앞으로 정렬한다.
    ///
    /// 순수 함수로 분리해 검증할 수 있게 둔다. 격자 정렬은 눈으로만 확인하면
    /// 등급을 하나 추가할 때 조용히 어긋난다.
    static func sorted(_ entries: [CardEntry], owned: (String) -> Bool) -> [CardEntry] {
        entries.sorted { a, b in
            let ownedA = owned(a.id), ownedB = owned(b.id)
            if ownedA != ownedB { return ownedA }              // 보유분이 위
            if a.tier.rank != b.tier.rank { return a.tier.rank > b.tier.rank }   // 희귀한 것이 앞
            return a.id < b.id                                  // 나머지는 안정적으로
        }
    }

    var body: some View {
        let l = wallet.l
        VStack(spacing: 6) {
            if index == nil {
                Text(l.cardIndexMissing)
                    .font(.callout).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let selectedCard, let entry = index?.card(selectedCard) {
                // 하단에 작게 붙이면 카드를 제대로 볼 수 없다. 화면을 통째로 내준다.
                CardSpotlightView(wallet: wallet, cardID: entry.id,
                                  name: entry.displayName(wallet.language),
                                  tier: entry.tier, setID: entry.setID,
                                  setName: index?.set(entry.setID)?.name ?? entry.setID,
                                  ownedCount: wallet.cardCount(entry.id)) {
                    self.selectedCard = nil
                }
            } else {
                // 카드가 없어도 격자를 보여준다. 무엇을 모을 수 있는지 알아야
                // 어느 팩을 살지 정할 수 있다 — 빈 화면은 그 판단을 막는다.
                header
                filterBar
                tierSummary
                if wallet.distinctCardCount == 0 { emptyHint }
                grid
            }
        }
        .frame(height: 470)
    }

    /// 아직 한 장도 없을 때의 안내. 격자는 그대로 두고 위에 한 줄만 얹는다.
    private var emptyHint: some View {
        Text(wallet.l.collectionEmptyHint)
            .font(.caption2).foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, 3)
            .background(Color.secondary.opacity(0.07), in: RoundedRectangle(cornerRadius: 5))
    }

    private var header: some View {
        let l = wallet.l
        let owned = visible.filter { wallet.cardCount($0.id) > 0 }.count
        return HStack {
            Text(l.collection).font(.callout.weight(.semibold))
            Spacer()
            Text(l.collectedOf(owned, visible.count))
                .font(.caption.weight(.semibold)).foregroundStyle(.secondary).monospacedDigit()
        }
    }

    /// 필터 — 세트와 등급. 눌러서 목록에서 고른다.
    ///
    /// 가로 스크롤 칩은 세트가 열 개만 돼도 화면 밖으로 밀려 무엇이 있는지 알 수 없다.
    /// 등급까지 더하면 줄이 둘로 늘어난다. 목록으로 열면 전체가 한눈에 들어온다.
    private var filterBar: some View {
        let l = wallet.l
        return HStack(spacing: 6) {
            Menu {
                filterOption(l.allSets, isSelected: selectedSet == nil) { selectedSet = nil }
                Divider()
                ForEach(index?.sets ?? []) { set in
                    filterOption(set.name, isSelected: selectedSet == set.id) { selectedSet = set.id }
                }
            } label: {
                filterLabel(l.filterSet, selectedSet.flatMap { id in index?.set(id)?.name } ?? l.allSets)
            }
            .menuStyle(.borderlessButton)

            Menu {
                filterOption(l.allSets, isSelected: selectedTier == nil) { selectedTier = nil }
                Divider()
                // 희귀한 것부터 — 찾고 싶은 등급이 대개 위쪽이다.
                ForEach(CardTier.allCases.reversed(), id: \.self) { tier in
                    filterOption("\(tier.rawValue) · \(l.tierName(tier))",
                                 isSelected: selectedTier == tier) { selectedTier = tier }
                }
            } label: {
                filterLabel(l.filterTier, selectedTier.map { "\($0.rawValue) · \(l.tierName($0))" } ?? l.allSets)
            }
            .menuStyle(.borderlessButton)
        }
    }

    /// 등급별 보유 현황. 두 줄로 전부 보여준다 — 가로로 흘리면 뒤쪽 등급이 가려진다.
    /// 누르면 그 등급만 걸린다(다시 누르면 해제).
    private var tierSummary: some View {
        let counts = tierCounts
        let tiers = CardTier.allCases.reversed().map { $0 }
        return LazyVGrid(columns: Array(repeating: GridItem(spacing: 3), count: 5), spacing: 3) {
            ForEach(tiers, id: \.self) { tier in
                let stat = counts[tier] ?? (owned: 0, total: 0)
                Button { apply { selectedTier = selectedTier == tier ? nil : tier } } label: {
                    VStack(spacing: 0) {
                        Text(tier.rawValue)
                            .font(.system(size: 8, weight: .heavy))
                            .foregroundStyle(tierColor(tier))
                        Text("\(stat.owned)/\(stat.total)")
                            .font(.system(size: 8))
                            .foregroundStyle(stat.owned > 0 ? .secondary : .tertiary)
                            .monospacedDigit()
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 2)
                    .background(selectedTier == tier ? tierColor(tier).opacity(0.18) : Color.secondary.opacity(0.07),
                                in: RoundedRectangle(cornerRadius: 4))
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .strokeBorder(selectedTier == tier ? tierColor(tier) : .clear, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    /// 등급별 (보유 종수, 전체 종수). 세트 필터는 반영하고 등급 필터는 반영하지 않는다 —
    /// 등급으로 거른 뒤에도 다른 등급이 몇 장인지 보여야 옮겨 다닐 수 있다.
    private var tierCounts: [CardTier: (owned: Int, total: Int)] {
        guard let index else { return [:] }
        var out: [CardTier: (owned: Int, total: Int)] = [:]
        for entry in Self.filtered(index.cards, set: selectedSet, tier: nil) {
            var stat = out[entry.tier] ?? (owned: 0, total: 0)
            stat.total += 1
            if wallet.cardCount(entry.id) > 0 { stat.owned += 1 }
            out[entry.tier] = stat
        }
        return out
    }

    /// 목록 항목. 지금 걸린 값에는 체크를 붙인다 — 열었을 때 어디에 있는지 알 수 있어야 한다.
    @ViewBuilder
    private func filterOption(_ title: String, isSelected: Bool,
                              _ change: @escaping () -> Void) -> some View {
        Button { apply(change) } label: {
            if isSelected {
                Label(title, systemImage: "checkmark")
            } else {
                Text(title)
            }
        }
    }

    /// 라벨은 반드시 단일 Text 여야 한다.
    /// `borderlessButton` 메뉴 스타일은 HStack 라벨의 첫 요소만 그려서,
    /// 제목과 선택값을 따로 두면 선택값이 통째로 사라진다.
    private func filterLabel(_ title: String, _ value: String) -> Text {
        Text(title).foregroundColor(.secondary) + Text("  \(value)").fontWeight(.semibold)
    }

    /// 필터가 바뀌면 고른 카드를 놓는다 — 필터 밖으로 나간 카드가 열려 있으면
    /// 닫았을 때 목록에 없는 것을 보고 있던 셈이 된다.
    private func apply(_ change: @escaping () -> Void) {
        change()
        selectedCard = nil
    }

    private var grid: some View {
        ScrollView {
            LazyVGrid(columns: Array(repeating: GridItem(spacing: 6), count: 5), spacing: 6) {
                ForEach(visible) { entry in
                    let count = wallet.cardCount(entry.id)
                    Button {
                        selectedCard = entry.id
                    } label: {
                        ZStack(alignment: .bottomTrailing) {
                            CardImageView(cardID: entry.id, width: 54, dimmed: count == 0)
                            // 등급은 카드 위에 항상 띄운다 — 눌러서 확인해야 알 수 있으면
                            // 무엇이 귀한 카드인지 훑어볼 수가 없다.
                            Text(entry.tier.rawValue)
                                .font(.system(size: 7, weight: .heavy))
                                .padding(.horizontal, 2.5).padding(.vertical, 1)
                                .background(tierColor(entry.tier).opacity(count == 0 ? 0.45 : 1),
                                            in: RoundedRectangle(cornerRadius: 3))
                                .foregroundStyle(.white)
                                .padding(2)
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                            if count > 1 {
                                Text("\(count)")
                                    .font(.system(size: 8, weight: .heavy))
                                    .padding(.horizontal, 3).padding(.vertical, 1)
                                    .background(.black.opacity(0.65), in: Capsule())
                                    .foregroundStyle(.white)
                                    .padding(2)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 1)
        }
    }
}
