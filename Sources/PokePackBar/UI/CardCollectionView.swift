import SwiftUI

/// 컬렉션 — 수집한 카드를 격자로 보고, 클릭하면 상세를 본다.
///
/// **값이 비싼 것부터 늘어놓는다.** 보유 여부로 먼저 갈라 놓으면 가진 카드가 통째로 위에
/// 쌓여, 값의 사다리에서 내가 어디까지 왔는지도 무엇이 아직 없는지도 읽히지 않는다. 못 얻은
/// 카드는 자리를 지키며 흑백으로 남고, 「보유한 카드만」을 켜면 가진 것만 걸러 본다.
@MainActor
struct CardCollectionView: View {
    let wallet: WalletStore
    let index: CardIndex?

    @State private var selectedSet: String?
    @State private var selectedTier: CardTier?
    @State private var selectedCard: String?
    /// 한번에 판매 화면을 열었는가. 탭 안에서 화면만 바꾼다.
    @State private var bulkSelling = false

    /// 가진 카드만 볼 것인가. 기본은 꺼짐 — 전체 목록에서 값순으로 봐야 무엇이 없는지
    /// 알 수 있다. 켜고 끈 선택은 기억한다.
    @AppStorage("collectionShowOwnedOnly") private var ownedOnly = false
    /// 등급별 수집 현황을 펼쳐 둘 것인가. 접어 두는 것이 기본이다 —
    /// 두 줄짜리 표가 늘 떠 있으면 그만큼 카드 볼 자리가 줄어든다.
    @AppStorage("collectionShowTiers") private var showTiers = false

    /// 화면 한 번에 필요한 것을 **한 번의 훑기로** 모두 낸 결과.
    ///
    /// 예전에는 목록·보유 수·중복 여부를 각자 계산했다. 계산 하나하나가 전체를 훑으므로
    /// 한 번 그릴 때마다 18,327장을 네 번 지나갔고 갱신 한 번에 27ms 가 걸렸다. 필요한 것을
    /// 한 자리에서 같이 세면 한 번이면 된다.
    struct Shelf {
        /// 세트·등급 필터만 건 목록. 「몇 장 중 몇 장」의 분모가 여기서 나온다 —
        /// 보유 필터까지 건 목록으로 세면 늘 "90 / 90" 이 되어 아무것도 말해 주지 않는다.
        var pool: [CardEntry] = []
        /// 실제로 격자에 그릴 것.
        var visible: [CardEntry] = []
        /// 필터 안에서 가진 종수.
        var owned = 0
        /// 팔 중복이 하나라도 있는가.
        var hasSpares = false
    }

    /// **미리 세워 둔 값 순 목록에서 거른다.** 거르기는 순서를 지키므로 여기서 다시 정렬할
    /// 이유가 없고, 정렬을 매번 돌리면 카드 그림이 도착할 때마다 화면이 덜컹거린다.
    private func makeShelf() -> Shelf {
        guard let index else { return Shelf() }
        var shelf = Shelf()
        shelf.pool.reserveCapacity(index.cardsByValue.count)
        for entry in index.cardsByValue {
            guard selectedSet == nil || entry.setID == selectedSet,
                  selectedTier == nil || entry.tier == selectedTier else { continue }
            shelf.pool.append(entry)
            let count = wallet.cardCount(entry.id)
            if count > 0 {
                shelf.owned += 1
                if count > 1 { shelf.hasSpares = true }
                shelf.visible.append(entry)
            } else if !ownedOnly {
                shelf.visible.append(entry)
            }
        }
        // 보유 필터가 꺼져 있으면 값 순서를 지켜야 하므로 pool 을 그대로 쓴다 —
        // 위 루프는 가진 것을 먼저 넣지 않는다(순서대로 담는다).
        if !ownedOnly { shelf.visible = shelf.pool }
        return shelf
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

    /// 값이 비싼 것부터. 실제 정렬은 `CardIndex.byValue` 가 하고 여기서는 이름만 빌려 쓴다 —
    /// 목록은 인덱스를 만들 때 한 번 세워지므로 화면은 거르기만 한다.
    static func sorted(_ entries: [CardEntry],
                       prices: CardPrices? = CardPrices.shared) -> [CardEntry] {
        CardIndex.byValue(entries, prices: prices)
    }

    var body: some View {
        let l = wallet.l
        // 한 번만 훑는다. 아래 조각들이 저마다 세면 그리기 한 번에 전체를 네 번 지나간다.
        let shelf = makeShelf()
        return VStack(spacing: 4) {
            if index == nil {
                Text(l.cardIndexMissing)
                    .font(Typography.body).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if bulkSelling {
                // 지금 목록에 걸린 카드만 넘긴다 — 화면에 안 보이는 카드가 팔리면 안 된다.
                BulkSaleView(wallet: wallet, pool: shelf.pool) { bulkSelling = false }
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
                filterBar(shelf)
                viewOptions(shelf)
                if showTiers { tierSummary }
                if shelf.visible.isEmpty { emptyHint }
                grid(shelf)
            }
        }
        .frame(height: PopoverMetrics.tabHeight)
        .onChange(of: ownedOnly) { selectedCard = nil }
    }

    /// 보이는 카드가 없을 때의 안내. 격자 자리는 그대로 두고 위에 한 줄만 얹는다.
    private var emptyHint: some View {
        Text(wallet.l.collectionEmptyHint)
            .font(Typography.label).foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, 3)
            .background(Color.secondary.opacity(0.07), in: RoundedRectangle(cornerRadius: 5))
    }

    /// 필터 — 세트와 등급. 눌러서 목록에서 고른다.
    ///
    /// 가로 스크롤 칩은 세트가 열 개만 돼도 화면 밖으로 밀려 무엇이 있는지 알 수 없다.
    /// 등급까지 더하면 줄이 둘로 늘어난다. 목록으로 열면 전체가 한눈에 들어온다.
    /// 세트 이름은 얼마든지 길어질 수 있다. 메뉴는 라벨을 줄이지 않으므로 폭을 막지 않으면
    /// 긴 세트 하나가 팝오버 전체를 밀어낸다 — 상단 머리글이 이 탭에서만 덜컹거린 원인이다.
    private static let setMenuWidth: CGFloat = 190

    private func filterBar(_ shelf: Shelf) -> some View {
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
            .lineLimit(1)
            .frame(maxWidth: Self.setMenuWidth, alignment: .leading)

            Menu {
                filterOption(l.allSets, isSelected: selectedTier == nil) { selectedTier = nil }
                Divider()
                // 희귀한 것부터 — 찾고 싶은 등급이 대개 위쪽이다.
                ForEach(CardTier.allCases.reversed(), id: \.self) { tier in
                    filterOption("\(tier.rawValue) · \(l.tierName(tier))",
                                 isSelected: selectedTier == tier) { selectedTier = tier }
                }
            } label: {
                // 접었을 때는 약호만 쓴다. 바로 아래 등급 칸이 같은 약호를 쓰고 있어
                // 여기서 이름까지 펼치면 같은 말을 두 번 하면서 줄만 넘친다.
                filterLabel(l.filterTier, selectedTier.map(\.rawValue) ?? l.allSets)
            }
            .menuStyle(.borderlessButton)
            .lineLimit(1)

            Spacer(minLength: 4)
            // 제목 줄을 따로 두지 않는다. 여기 필터가 무엇을 걸고 있는지와 그 결과가
            // 몇 장인지는 같은 줄에서 읽는 편이 자연스럽고, 카드 볼 자리도 그만큼 넓어진다.
            Text(l.collectedOf(shelf.owned, shelf.pool.count))
                .font(Typography.labelSemibold).foregroundStyle(.secondary)
                .monospacedDigit().lineLimit(1)
        }
    }

    /// 보기 방식 — 무엇을 보여줄지와, 등급표를 펼칠지.
    ///
    /// 위 줄이 「무엇을 거를까」라면 이 줄은 「어떻게 볼까」다. 한 줄에 다 넣으면 397pt 를
    /// 넘어 팝오버가 밀린다.
    private func viewOptions(_ shelf: Shelf) -> some View {
        let l = wallet.l
        return HStack(spacing: 6) {
            Toggle(l.ownedOnly, isOn: $ownedOnly)
                .toggleStyle(.checkbox)
                .font(Typography.label)
            Spacer(minLength: 4)
            // 잡카드 정리로 들어가는 문. 중복이 없으면 누를 것이 없으므로 감춘다.
            if shelf.hasSpares {
                Button { bulkSelling = true } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "wonsign.circle")
                        Text(l.bulkSell)
                    }
                    .font(Typography.label)
                    .foregroundStyle(Color.accentColor)
                }
                .buttonStyle(.plain)
                .help(l.bulkSellPrompt)
            }
            Button {
                showTiers.toggle()
            } label: {
                HStack(spacing: 3) {
                    Text(l.tierSummaryToggle)
                    Image(systemName: showTiers ? "chevron.up" : "chevron.down")
                        .font(.system(size: 13))
                }
                .font(Typography.label)
                .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
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
                            .font(.system(size: 13, weight: .heavy))
                            .foregroundStyle(tierColor(tier))
                        Text("\(stat.owned)/\(stat.total)")
                            .font(.system(size: 13))
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

    private func grid(_ shelf: Shelf) -> some View {
        ScrollView {
            // 칸을 고정한다. 유연 칸에 고정 폭 카드를 넣으면 칸은 넓어지고 카드만 작게
            // 남아 사이가 벌어진다 — 창을 넓힌 뒤 실제로 그렇게 보였다.
            LazyVGrid(columns: CardGrid.collection.items,
                      spacing: CardGrid.collection.spacing) {
                ForEach(shelf.visible) { entry in
                    let count = wallet.cardCount(entry.id)
                    Button {
                        selectedCard = entry.id
                    } label: {
                        ZStack(alignment: .bottomTrailing) {
                            CardImageView(cardID: entry.id, width: CardGrid.collection.width, dimmed: count == 0)
                            // 등급은 카드 위에 항상 띄운다 — 눌러서 확인해야 알 수 있으면
                            // 무엇이 귀한 카드인지 훑어볼 수가 없다.
                            Text(entry.tier.rawValue)
                                .font(.system(size: 13, weight: .heavy))
                                .padding(.horizontal, 2.5).padding(.vertical, 1)
                                .background(tierColor(entry.tier).opacity(count == 0 ? 0.45 : 1),
                                            in: RoundedRectangle(cornerRadius: 3))
                                .foregroundStyle(.white)
                                .padding(2)
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                            if count > 1 {
                                Text("\(count)")
                                    .font(.system(size: 13, weight: .heavy))
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
