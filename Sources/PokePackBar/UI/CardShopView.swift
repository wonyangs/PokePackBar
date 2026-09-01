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

    /// 상세를 보고 있는 세트. nil 이면 격자.
    @State private var selectedSet: String?
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
                } else {
                    VStack(spacing: 8) {
                        sectionPicker
                        switch section {
                        case .packs: grid(index)
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
        .task(id: index?.setIDs.joined()) {
            // 상점이 첫 화면이라 여기가 비어 보이면 앱 전체가 안 뜬 것처럼 보인다.
            guard let index else { return }
            await CardImageLoader.prefetchPacks(setIDs: index.setIDs)
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
        guard let requested = nav.shopSet else { return }
        section = .packs
        selectedSet = requested
        nav.shopSet = nil
    }

    private func grid(_ index: CardIndex) -> some View {
        ScrollView {
            LazyVGrid(columns: Array(repeating: GridItem(spacing: 8), count: 2), spacing: 10) {
                ForEach(index.sets) { set in
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

/// 격자 한 칸 — 그림과 이름과 가격만. 나머지는 눌러서 본다.
@MainActor
private struct PackGridCell: View {
    let wallet: WalletStore
    let index: CardIndex
    let set: CardSet

    var body: some View {
        let price = PackPricing.price(setID: set.id, index: index, perks: wallet.perks)
        let owned = wallet.packCount(setID: set.id)
        return VStack(spacing: 5) {
            ZStack(alignment: .topTrailing) {
                PackImageView(setID: set.id, width: 78)
                if owned > 0 {
                    Text("×\(owned)")
                        .font(.system(size: 14, weight: .heavy))
                        .padding(.horizontal, 4).padding(.vertical, 1.5)
                        .background(Color.accentColor, in: Capsule())
                        .foregroundStyle(.white)
                        .padding(3)
                }
            }
            Text(set.name)
                .font(Typography.bodySemibold)
                .lineLimit(2).multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
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

    private var price: Int { PackPricing.price(setID: set.id, index: index, perks: wallet.perks) }
    private var cardsPerPack: Int { PackPricing.cardCount(setID: set.id, index: index, perks: wallet.perks) }
    private var members: [CardEntry] { index.cards.filter { $0.setID == set.id } }
    private var ownedCount: Int { members.filter { wallet.cardCount($0.id) > 0 }.count }

    /// 잔액으로 살 수 있는 최대 수량. 한 번에 스무 개면 충분하다.
    private var maxQuantity: Int { max(1, min(20, wallet.availableTokens / max(price, 1))) }
    private var total: Int { price * quantity }
    private var canBuy: Bool { wallet.availableTokens >= total }

    var body: some View {
        let l = wallet.l
        // 스크롤을 두지 않는다. 팩 하나를 살지 말지 정하는 화면에서 정보가 화면 밖에
        // 숨으면 끌어내려 봐야 하는데, 그러느니 그림을 줄이는 편이 낫다.
        VStack(spacing: 7) {
            HStack {
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 17)).foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help(l.close)
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

    private func summaryRows(_ l: L) -> some View {
        let rate = members.isEmpty ? 0 : Double(ownedCount) / Double(members.count) * 100
        return HStack {
            Text(l.packTotalCards).font(Typography.label).foregroundStyle(.secondary)
            Text("\(members.count)").font(Typography.labelSemibold).monospacedDigit()
            Spacer()
            Text(l.packCollected).font(Typography.label).foregroundStyle(.secondary)
            Text("\(ownedCount)/\(members.count) (\(String(format: "%.0f", rate))%)")
                .font(Typography.labelSemibold).monospacedDigit()
        }
        .padding(.horizontal, 8).padding(.vertical, 6)
        .background(Color.secondary.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 7))
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
                    Text(entry.tier.rawValue)
                        .font(.system(size: 14, weight: .heavy))
                        .foregroundStyle(tierColor(entry.tier))
                        .lineLimit(1).fixedSize()
                        .frame(width: 38, alignment: .leading)
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
