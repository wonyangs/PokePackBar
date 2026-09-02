import SwiftUI

/// 상점 — 팩을 격자로 늘어놓고, 고르면 상세를 보여준다.
///
/// 목록 한 줄에 이름과 가격을 늘어놓는 방식은 팩이 열 개만 넘어도 훑기 어렵다.
/// 팩은 그림으로 알아보는 물건이라 격자가 맞다. 자세한 것은 눌러서 본다.
@MainActor
struct CardShopView: View {
    let wallet: WalletStore
    let index: CardIndex?

    /// 상점의 두 갈래. 파는 물건이 아예 다르므로 한 격자에 섞지 않는다 —
    /// 팩은 세트를 고르는 것이고 오리파는 박스 하나에서 뽑는 것이다.
    enum Section: CaseIterable { case packs, oripa }

    /// 상세를 보고 있는 세트. nil 이면 목록.
    @State private var selectedSet: String?
    /// 들어가 있는 시대. nil 이면 시대 목록이다.
    ///
    /// 세트가 130개가 되면서 한 격자에 다 늘어놓을 수 없게 됐다. 시대로 한 단계를 두면
    /// 첫 화면이 17줄로 끝나고, 찾는 팩이 어느 시대인지는 대개 알고 있다.
    @State private var openedEra: String?
    @State private var section: Section = .packs

    @Environment(PopoverNavigation.self) private var nav

    var body: some View {
        Group {
            if let index {
                if let selectedSet, let set = index.set(selectedSet) {
                    // 상세는 한 단계 들어간 화면이라 갈래 선택을 감춘다.
                    PackDetailView(wallet: wallet, index: index, set: set) {
                        self.selectedSet = nil
                    }
                } else if let openedEra, let era = index.eras.first(where: { $0.name == openedEra }) {
                    // 시대 안 — 갈래 선택을 감춘다. 한 단계 들어온 화면이다.
                    packGrid(index, era: era)
                } else {
                    VStack(spacing: 8) {
                        sectionPicker
                        switch section {
                        case .packs: eraList(index)
                        case .oripa: OripaView(wallet: wallet, index: index)
                        }
                    }
                }
            } else {
                Text(wallet.l.cardIndexMissing)
                    .font(Typography.body).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        // 고정 높이 — 팝오버를 다시 열 때 크기가 줄어드는 것을 막는다.
        .frame(height: PopoverMetrics.tabHeight)
        // 시대 목록에 쓸 대표 그림만 미리 받는다. 130개를 전부 미리 받으면 첫 화면을
        // 띄우는 데만 그 요청이 다 끝나야 한다 — 나머지는 그 시대에 들어갈 때 받는다.
        .task(id: index?.eras.count) {
            guard let index else { return }
            await CardImageLoader.prefetchPacks(setIDs: index.eras.compactMap { $0.cover?.id })
        }
        .task(id: openedEra) {
            guard let openedEra, let index,
                  let era = index.eras.first(where: { $0.name == openedEra }) else { return }
            await CardImageLoader.prefetchPacks(setIDs: era.sets.map(\.id))
        }
        // 도감의 「이 팩 사러 가기」로 들어온 경우 그 팩 상세를 바로 연다.
        // 한 번 읽고 지운다 — 남겨 두면 다음에 상점 탭을 눌렀을 때 또 그 팩이 뜬다.
        .onAppear(perform: consumeRequestedSet)
        .onChange(of: nav.shopSet) { consumeRequestedSet() }
    }

    private var sectionPicker: some View {
        SegmentedTabs(items: [
            .init(value: Section.packs, label: wallet.l.shopPacksSection),
            .init(value: Section.oripa, label: wallet.l.oripaTitle),
        ], selection: $section)
    }

    private func consumeRequestedSet() {
        guard let requested = nav.shopSet, let index else { return }
        section = .packs
        // 그 팩이 든 시대를 함께 연다 — 상세를 닫았을 때 빈 시대 목록으로 튕기지 않는다.
        openedEra = index.eras.first { $0.sets.contains { $0.id == requested } }?.name
        selectedSet = requested
        nav.shopSet = nil
    }

    /// 시대 목록. 상점의 첫 화면이다.
    private func eraList(_ index: CardIndex) -> some View {
        ScrollView {
            LazyVStack(spacing: 6) {
                ForEach(index.eras) { era in
                    Button { openedEra = era.name } label: {
                        EraRow(wallet: wallet, era: era)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 1)
        }
    }

    /// 한 시대의 팩 격자.
    private func packGrid(_ index: CardIndex, era: CardEra) -> some View {
        VStack(spacing: 6) {
            HStack(spacing: 6) {
                BackButton(action: { openedEra = nil }, hint: wallet.l.back)
                Text(era.name).font(Typography.title).lineLimit(1)
                Text(era.years)
                    .font(Typography.label).foregroundStyle(.tertiary).monospacedDigit()
                Spacer(minLength: 0)
                Text(wallet.l.shopPackCount(era.sets.count))
                    .font(Typography.label).foregroundStyle(.secondary).monospacedDigit()
            }
            ScrollView {
                LazyVGrid(columns: CardGrid.packShelf.items,
                          spacing: CardGrid.packShelf.spacing) {
                    ForEach(era.sets) { set in
                        Button { selectedSet = set.id } label: {
                            PackGridCell(wallet: wallet, index: index, set: set)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 1)
            }
        }
    }

}

/// 팩 카드 목록의 한 칸. 컬렉션 격자와 같은 모양이다 — 같은 카드가 화면마다 다르게
/// 보이면 어디서 봤는지 헷갈린다.
@MainActor
private struct PackCardCell: View {
    let entry: CardEntry
    let count: Int

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            CardImageView(cardID: entry.id, width: CardGrid.collection.width, dimmed: count == 0)
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
}

/// 시대 한 줄 — 대표 그림, 이름, 연도, 세트 수와 보유 팩.
@MainActor
private struct EraRow: View {
    let wallet: WalletStore
    let era: CardEra

    var body: some View {
        let owned = era.sets.reduce(0) { $0 + wallet.packCount(setID: $1.id) }
        return HStack(spacing: 9) {
            PackImageView(setID: era.cover?.id ?? "", width: 34)
            VStack(alignment: .leading, spacing: 1) {
                Text(era.name).font(Typography.bodySemibold).lineLimit(1)
                Text(era.years)
                    .font(Typography.label).foregroundStyle(.tertiary).monospacedDigit()
            }
            Spacer(minLength: 4)
            if owned > 0 {
                Text("×\(owned)")
                    .font(.system(size: 14, weight: .heavy))
                    .padding(.horizontal, 5).padding(.vertical, 1.5)
                    .background(Color.accentColor, in: Capsule())
                    .foregroundStyle(.white)
            }
            Text(wallet.l.shopPackCount(era.sets.count))
                .font(Typography.label).foregroundStyle(.secondary).monospacedDigit()
            Image(systemName: "chevron.right")
                .font(.system(size: 13)).foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 8).padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.secondary.opacity(0.07), in: RoundedRectangle(cornerRadius: 8))
        .contentShape(RoundedRectangle(cornerRadius: 8))
    }
}

/// 격자 한 칸 — 그림과 이름과 가격만. 나머지는 눌러서 본다.
@MainActor
private struct PackGridCell: View {
    let wallet: WalletStore
    let index: CardIndex
    let set: CardSet

    /// 팩 그림 폭. 칸 폭에서 좌우 여백만큼 뺀다 — 칸 끝까지 채우면 그림이 배경 모서리에
    /// 닿아 칸의 경계가 사라진다.
    private static let artWidth = CardGrid.packShelf.width - 20

    var body: some View {
        let price = PackPricing.price(setID: set.id, index: index, perks: wallet.perks)
        let owned = wallet.packCount(setID: set.id)
        return VStack(spacing: 5) {
            ZStack(alignment: .topTrailing) {
                PackImageView(setID: set.id, width: Self.artWidth)
                if owned > 0 {
                    Text("×\(owned)")
                        .font(.system(size: 14, weight: .heavy))
                        .padding(.horizontal, 4).padding(.vertical, 1.5)
                        .background(Color.accentColor, in: Capsule())
                        .foregroundStyle(.white)
                        .padding(3)
                }
            }
            // 한 줄로 못 박는다. 두 줄을 허용하면 이름 길이에 따라 칸 높이가 들쭉날쭉해져
            // 격자가 어긋나 보인다.
            Text(set.name)
                .font(Typography.bodySemibold)
                .lineLimit(1).minimumScaleFactor(0.7)
                .padding(.horizontal, 4)
            Text(MarketEconomy.money(tokens: price, language: wallet.language))
                .font(Typography.amount).monospacedDigit()
                .lineLimit(1).minimumScaleFactor(0.75)
                .foregroundStyle(wallet.availableTokens >= price ? .secondary : .tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Color.secondary.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

/// 팩 상세 — 무엇이 들었고 얼마나 모았는지, 그리고 몇 개를 살지.
@MainActor
private struct PackDetailView: View {
    let wallet: WalletStore
    let index: CardIndex
    let set: CardSet
    let onClose: () -> Void

    @State private var quantity = 1
    /// 이 팩에서 나올 수 있는 카드를 다 보고 있는가.
    @State private var browsingCards = false
    /// 그 목록에서 크게 보고 있는 카드.
    @State private var spotlight: String?

    private var price: Int { PackPricing.price(setID: set.id, index: index, perks: wallet.perks) }
    private var cardsPerPack: Int { PackPricing.cardCount(setID: set.id, index: index, perks: wallet.perks) }
    /// 이 팩에서 나올 수 있는 카드. **값이 비싼 것부터** — 무엇을 노리고 사는지가 먼저 읽혀야 한다.
    /// 인덱스가 이미 값순으로 세워 둔 것을 거르므로 여기서 다시 정렬하지 않는다.
    private var members: [CardEntry] { index.cardsByValue.filter { $0.setID == set.id } }
    private var ownedCount: Int { members.filter { wallet.cardCount($0.id) > 0 }.count }

    /// 잔액으로 살 수 있는 최대 수량. 한 번에 스무 개면 충분하다.
    private var maxQuantity: Int { max(1, min(20, wallet.availableTokens / max(price, 1))) }
    private var total: Int { price * quantity }
    private var canBuy: Bool { wallet.availableTokens >= total }

    var body: some View {
        if let spotlight, let entry = index.card(spotlight) {
            // 목록을 통째로 내준다. 아래에 작게 붙이면 카드를 제대로 볼 수 없다.
            CardSpotlightView(wallet: wallet, cardID: entry.id,
                              name: entry.displayName(wallet.language),
                              tier: entry.tier, setID: entry.setID,
                              setName: set.name,
                              canVisitPack: false,
                              rarity: entry.rarity,
                              ownedCount: wallet.cardCount(entry.id)) {
                self.spotlight = nil
            }
        } else if browsingCards {
            cardList(wallet.l)
        } else {
            detail(wallet.l)
        }
    }

    private func detail(_ l: L) -> some View {
        // 스크롤을 두지 않는다. 팩 하나를 살지 말지 정하는 화면에서 정보가 화면 밖에
        // 숨으면 끌어내려 봐야 하는데, 그러느니 그림을 줄이는 편이 낫다.
        VStack(spacing: 7) {
            HStack {
                BackButton(action: onClose, hint: l.close)
                Spacer()
            }

            HStack(alignment: .top, spacing: 10) {
                PackImageView(setID: set.id, width: 62)
                    .shadow(radius: 4, y: 2)
                VStack(alignment: .leading, spacing: 3) {
                    Text(set.name)
                        .font(Typography.title)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("\(String(set.released.prefix(4)))  ·  \(l.packContents(cardsPerPack))")
                        .font(Typography.label).foregroundStyle(.secondary)
                    if let blurb = l.packBlurb(set.id) {
                        Text(blurb)
                            .font(Typography.label).foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer(minLength: 0)
            }

            summaryRows(l)
            oddsTable(l)
            Spacer(minLength: 0)
            purchaseBar(l)
        }
    }

    /// 카드 목록으로 들어가는 버튼. 수집률을 함께 적는다.
    ///
    /// 처음에는 「전체 카드 226 · 수집률 12/226」이라 적힌 회색 줄에 갈매기만 붙여 두었다.
    /// 그 줄은 원래 **읽는 것**이라 눌러 볼 생각이 들지 않았다. 하는 일을 글자로 적고
    /// 테두리를 둘러 버튼처럼 보이게 한다 — 확률표는 등급별 비중만 말해 주고, 무엇이
    /// 들었는지는 결국 카드를 봐야 안다.
    private func summaryRows(_ l: L) -> some View {
        Button { browsingCards = true } label: {
            HStack(spacing: 6) {
                Image(systemName: "square.grid.2x2")
                Text(l.packSeeCards)
                Spacer(minLength: 0)
                Text("\(ownedCount)/\(members.count)")
                    .monospacedDigit().foregroundStyle(.secondary)
            }
            .font(Typography.button)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
    }

    /// 이 팩에서 나올 수 있는 카드 전부.
    ///
    /// 값이 비싼 것부터 세운다. 등급순으로 세우면 시장과 어긋나 — 1999년 커먼이 최신 SR
    /// 보다 비싸다 — 「이 팩에서 뭘 노리나」가 안 읽힌다. 아직 못 얻은 카드도 흐리게
    /// 보여 준다. 무엇을 모을 수 있는지 알아야 살지 말지 정할 수 있다.
    private func cardList(_ l: L) -> some View {
        VStack(spacing: 6) {
            HStack(spacing: 6) {
                BackButton(action: { browsingCards = false }, hint: l.back)
                Text(set.name).font(Typography.title).lineLimit(1)
                Spacer(minLength: 0)
                Text("\(ownedCount)/\(members.count)")
                    .font(Typography.labelSemibold).foregroundStyle(.secondary).monospacedDigit()
            }
            ScrollView {
                LazyVGrid(columns: CardGrid.collection.items,
                          spacing: CardGrid.collection.spacing) {
                    ForEach(members) { entry in
                        let count = wallet.cardCount(entry.id)
                        Button { spotlight = entry.id } label: {
                            PackCardCell(entry: entry, count: count)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 1)
            }
        }
    }

    /// 카드 한 장이 각 등급일 확률. 합은 100% 다.
    ///
    /// 칸별로 나눠 적어 봤더니 표가 네 덩이가 되어 읽히지 않았다. 구조가 궁금한 사람보다
    /// "이 팩에서 UR 이 얼마나 나오나" 를 보려는 사람이 훨씬 많다. 대신 확정 한 장과
    /// 천장은 표 아래 한 줄로 적는다 — 보장을 숨기지는 않는다.
    private func oddsTable(_ l: L) -> some View {
        let odds = PackOpening.packOdds(setID: set.id, index: index, perks: wallet.perks)
        let pool = index.pools[set.id] ?? [:]

        return VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(l.packOdds).font(Typography.labelSemibold)
                Spacer()
                Text(l.packOddsColumns).font(.system(size: 14)).foregroundStyle(.tertiary)
            }
            .padding(.bottom, 1)

            ForEach(odds, id: \.tier) { entry in
                let all = (pool[entry.tier] ?? []).count
                let owned = (pool[entry.tier] ?? []).filter { wallet.cardCount($0) > 0 }.count
                HStack(spacing: 5) {
                    // 칸이 30pt 였다. 14pt 헤비에서 "SAR"·"RRR" 이 그보다 넓어 두 줄로
                    // 꺾였다. 가장 긴 배지가 들어갈 만큼 넓히고 꺾이지 않게 못 박는다.
                    // 등급을 늘리면서 "BREAK"·"LV.X" 가 들어왔고 38pt 를 다시 넘겼다.
                    Text(entry.tier.rawValue)
                        .font(.system(size: 14, weight: .heavy))
                        .foregroundStyle(tierColor(entry.tier))
                        .lineLimit(1).fixedSize()
                        .frame(width: 62, alignment: .leading)
                    Text("\(owned)/\(all)")
                        .font(.system(size: 14)).foregroundStyle(.tertiary).monospacedDigit()
                    Spacer()
                    Text(percentText(entry.probability))
                        .font(.system(size: 14, weight: .semibold)).monospacedDigit()
                        .frame(width: 48, alignment: .trailing)
                }
            }

            VStack(alignment: .leading, spacing: 1) {
                Text(l.packGuaranteeNote(PackConfig.hitSlotCount(wallet.perks),
                                         pity: PackConfig.pityThreshold))
                Text(l.godPackNote(PackConfig.godPackOneIn))
            }
            .font(.system(size: 14)).foregroundStyle(.tertiary)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.top, 2)
        }
        .padding(.horizontal, 8).padding(.vertical, 6)
        .background(Color.secondary.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 7))
    }

    /// 아주 낮은 확률을 0% 로 반올림하지 않는다 — 1.1% 와 0.04% 는 다른 이야기다.
    private func percentText(_ p: Double) -> String {
        let pct = p * 100
        if pct >= 99.95 { return "100%" }
        if pct < 1 { return String(format: "%.2f%%", pct) }
        return String(format: "%.1f%%", pct)
    }

    private func purchaseBar(_ l: L) -> some View {
        VStack(spacing: 5) {
            HStack(spacing: 8) {
                Text(l.packQuantity).font(Typography.label).foregroundStyle(.secondary)
                Stepper(value: $quantity, in: 1...maxQuantity) {
                    Text("\(quantity)").font(Typography.title).monospacedDigit()
                }
                .fixedSize()
                Spacer()
                Text(MarketEconomy.money(tokens: total, language: wallet.language))
                    .font(Typography.amount).monospacedDigit()
                    .lineLimit(1).minimumScaleFactor(0.75)
                    .foregroundStyle(canBuy ? .primary : .secondary)
            }
            Button(canBuy ? l.buyCount(quantity) : l.notEnoughTokens) { buy() }
                .buttonStyle(.borderedProminent)
                .font(Typography.button)
                .disabled(!canBuy)
                .frame(maxWidth: .infinity)
        }
        // 잔액이 줄면 살 수 있는 수량도 줄어든다. 남은 수량이 한도를 넘으면 끌어내린다.
        .onChange(of: wallet.availableTokens) {
            if quantity > maxQuantity { quantity = maxQuantity }
        }
    }

    private func buy() {
        // 총액을 한 번에 차감한다. 개당 차감하면 중간에 실패했을 때 몇 개를 준 건지 흐려진다.
        guard wallet.spend(total) else { return }
        wallet.addPack(setID: set.id, count: quantity)
        quantity = 1
    }
}
