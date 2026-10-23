import AppKit
import SwiftUI

/// 카드 한 장을 크게 보는 화면.
///
/// 카드 뒤에 등급 후광을 깔고 정보는 아래에 붙인다. 컬렉션과 개봉 결과가 같이 쓴다 —
/// 두 곳에서 따로 만들면 한쪽만 손보게 되고 같은 카드가 화면마다 달라 보인다.
///
/// 카드 자체는 `HolographicCardView` 가 그린다 — 기울기와 광택은 그쪽에 있다.
///
/// 팝오버라 모달을 쓸 수 없어 탭 안에서 화면만 바꾼다. 닫기는 X 버튼이 맡는다.
@MainActor
struct CardSpotlightView: View {
    let wallet: WalletStore
    let cardID: String
    let name: String
    let tier: CardTier
    /// 이 카드가 나오는 세트. 카드 번호보다 이게 필요하다 —
    /// 갖고 싶은 카드를 보고 어느 팩을 사야 하는지 알 수 있어야 한다.
    let setID: String
    let setName: String
    /// 팩 이름을 눌러 상점으로 갈 수 있는가. **이미 그 팩 안에서 연 카드면 끈다** —
    /// 눌러도 제자리라 아무 일도 일어나지 않는 버튼이 된다.
    var canVisitPack = true
    /// 원본 등급 이름. 커뮤니티 약칭으로 옮겨 등급 배지 옆에 적는다.
    var rarity: String?
    /// 팩에서 막 뽑은 병렬 판형. 없으면 보유 판형 중 대표를 고른다.
    var finish: CardFinish? = nil
    /// 보유 장수. 0 이면 아직 얻지 못한 카드로 표시한다.
    let ownedCount: Int
    /// 미리 받아 둔 큰 그림이 있으면 기다리지 않는다.
    var preloaded: NSImage?
    let onClose: () -> Void

    @Environment(PopoverNavigation.self) private var nav

    @State private var landed = false
    @State private var confirmingSale = false
    /// 같은 카드 번호의 판형을 직접 바꿔 보게 한다. `nil`이면 방금 뽑은 판형이나
    /// 보유 판형 중 가장 값이 높은 것을 기본으로 쓴다.
    @State private var selectedFinish: CardFinish? = nil
    /// 방금 받은 액수. 잠깐 보여주고 지운다.
    @State private var lastRefund: Int?
    /// 출처 팩과 뽑힐 확률. 세트 전체를 훑어 세므로 카드가 바뀔 때만 다시 구한다.
    @State private var source: CardSource?

    var body: some View {
        GeometryReader { geometry in
            // The shop has an extra picker above this view. Measure its real
            // height instead of assuming that every caller gets the whole tab.
            // 뽑힐 확률 줄은 거의 모든 카드에 있어 늘 자리를 잡는다. 마켓 줄은 온라인일 때만.
            // 보유 줄(중복이 있을 때만 생기고 중복 판매 버튼이 붙는다)과 도감 배지 줄(아직 완성하지
            // 않은 조합에 들 때만 생긴다)은 늘 자리를 잡아 둔다. 카드마다 있고 없고에 따라 카드가
            // 줄어들면 같은 화면에서 어떤 카드는 크고 어떤 카드는 작아 보인다.
            // 도감 배지 줄의 자리는 뒤로가기와 즐겨찾기 줄을 카드 옆에 겹쳐 놓아 만든다. 배지 줄
            // 높이만큼 카드를 줄여 맞췄더니 모든 카드가 작아 보였다.
            // 위 여백 16pt 가 여기 들어 있다.
            let informationHeight: CGFloat = 174 + 21 + (wallet.isOnline ? 21 : 0)
            let cardWidth = min(230, max(150,
                ((geometry.size.height - informationHeight) * 0.717).rounded(.down)))
            // 판매 확인과 판매 완료 안내는 카드를 줄여 자리를 만들지 않고 그쪽으로 스크롤한다.
            // 카드가 줄거나 움직이면 같은 카드를 보는 중에 화면이 출렁인다.
            ScrollViewReader { scroller in
                ScrollView {
                    detail(cardWidth: cardWidth)
                        .frame(minHeight: geometry.size.height)
                }
                .scrollIndicators(.hidden)
                .onChange(of: confirmingSale) {
                    withAnimation(Motion.shift) {
                        scroller.scrollTo(confirmingSale ? SaleAnchor.controls : SaleAnchor.top,
                                          anchor: confirmingSale ? .bottom : .top)
                    }
                }
                .onChange(of: lastRefund) {
                    guard lastRefund != nil else { return }
                    withAnimation(Motion.shift) { scroller.scrollTo(SaleAnchor.controls, anchor: .bottom) }
                }
            }
        }
        .onAppear {
            selectedFinish = finish ?? wallet.bestOwnedFinish(cardID: cardID)
            source = findSource()
            withAnimation(.spring(response: 0.34, dampingFraction: 0.75)) { landed = true }
        }
        .onChange(of: cardID) {
            confirmingSale = false
            lastRefund = nil
            selectedFinish = finish ?? wallet.bestOwnedFinish(cardID: cardID)
            source = findSource()
        }
    }

    private func detail(cardWidth: CGFloat) -> some View {
        let l = wallet.l
        // 카드는 늘 맨 위에 붙인다. 남는 높이를 카드 위아래로 나누면 아래 정보 줄 수에 따라
        // 카드가 오르내린다. 남는 자리는 맨 아래로 보낸다.
        return VStack(spacing: 0) {
            // 위 여백은 고정이다. 후광이 위 끝에 닿지 않고 뒤로가기, 즐겨찾기 버튼과 카드 윗단 사이가
            // 답답하지 않을 만큼 둔다.
            Color.clear.frame(height: 16).id(SaleAnchor.top)

            // 마우스를 올리면 기울고 광택이 흐른다 — 확대 화면에서만 준다.
            // 격자에서는 크기가 작아 각도가 읽히지 않고, 지나가는 커서마다 반응하면 산만하다.
            // 좌우로 끌면 뒷면까지 돌려 볼 수 있고, 두 번 누르면 앞면으로 돌아온다.
            Group {
                if let displayedFinish {
                    HolographicCardView(cardID: cardID, tier: tier,
                                        finish: displayedFinish, setID: setID,
                                        originalRarity: rarity, width: cardWidth,
                                        dimmed: ownedCount == 0, preloaded: preloaded, spinnable: true)
                } else {
                    HolographicCardView(cardID: cardID, tier: tier, width: cardWidth,
                                        dimmed: ownedCount == 0, preloaded: preloaded, spinnable: true)
                }
            }
                // 상세 화면은 개봉 연출이 아니라 들여다보는 자리다. 후광은 절반만.
                .environment(\.tierGlowScale, 0.5)
                .scaleEffect(landed ? 1 : 0.9)
                .opacity(landed ? 1 : 0)

            // 글자를 키우면서 줄 수를 줄였다. 등급·세트·보유량을 한 줄에 모으고 이름을
            // 한 줄로 묶는다. 작은 창이나 긴 판매 안내는 스크롤로 끝까지 볼 수 있다.
            VStack(spacing: 4) {
                Text(name)
                    .font(Typography.heading)
                    .lineLimit(1).minimumScaleFactor(0.7)

                HStack(spacing: 5) {
                    Text(l.tierBadge(tier))
                        .font(Typography.badgeLarge)
                        .foregroundStyle(tierColor(tier))
                    // 우리 10칸은 게임 규칙용으로 접은 것이라 「무슨 등급인가」에 답하지
                    // 못한다 — 찬란한·ACE SPEC·BREAK·LV.X 가 모두 RRR 이다. 원본을 적는다.
                    // 접기 전과 같은 이름이면(AR·SAR 등) 같은 말을 두 번 하지 않는다.
                    if let detail = rarity.flatMap({ l.rarityLabel($0) }),
                       detail != l.tierBadge(tier) {
                        Text(detail)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                    // 출처 팩 — **눌러서 그 팩을 사러 간다.** 갖고 싶은 카드를 보고 있을 때
                    // 필요한 다음 동작이 그것인데, 예전에는 이름만 적혀 있어서 상점에서
                    // 시대를 짚어 가며 같은 팩을 다시 찾아야 했다.
                    if canVisitPack {
                        Button {
                            nav.shopSet = setID
                            nav.tab = .shop
                        } label: {
                            packLabel(linked: true)
                        }
                        .buttonStyle(.plain)
                        .help(l.packGoBuy)
                    } else {
                        packLabel(linked: false)
                    }
                    Text("·").font(Typography.label).foregroundStyle(.tertiary)
                    Text(ownedCount > 0 ? l.copiesOwned(ownedCount) : l.notOwnedYet)
                        .font(ownedCount > 0 ? Typography.labelSemibold : Typography.label)
                        .foregroundStyle(ownedCount > 0 ? .secondary : .tertiary)
                        .monospacedDigit()
                }
                .lineLimit(1).minimumScaleFactor(0.75)

                priceRow(l)
            }

            dexBadges(l)
                .padding(.top, 6)

            saleControls(l)
                .padding(.top, 5)
                .padding(.bottom, 4)
                .id(SaleAnchor.controls)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
        // 뒤로가기는 왼쪽, 손대는 것은 오른쪽. 다른 화면과 같은 자리다. 줄을 따로 두지 않고 카드
        // 양옆의 빈 곳에 겹쳐 둔다. 카드는 가운데에 놓여 두 버튼과 겹치지 않는다.
        .overlay(alignment: .top) {
            HStack {
                BackButton(action: onClose, hint: l.close)
                Spacer()
                favoriteButton(l)
            }
        }
    }

    private enum SaleAnchor: Hashable { case top, controls }

    /// 이 카드를 처음 얻은 날. **값 줄 끝에 붙인다.**
    ///
    /// 줄을 따로 두었더니 카드가 커서 판매 버튼이 화면 밖으로 밀려났다. 이 화면은 470pt
    /// 안에 다 들어와야 하고(스크롤 없음), 값 줄은 짧아서 자리가 남는다.
    ///
    /// **기록이 없으면 아무것도 안 붙인다.** 이 기록은 나중에 생긴 것이라 그 전에 모은
    /// 카드에는 없다. 「알 수 없음」이라 적으면 대부분의 카드에 쓸모없는 글자가 늘 뜬다.
    @ViewBuilder
    private func acquiredTag(_ l: L) -> some View {
        if let date = wallet.firstAcquired(cardID) {
            Text("·").font(Typography.label).foregroundStyle(.tertiary)
            Text(Self.dayFormatter.string(from: date))
                .font(.system(size: 14)).foregroundStyle(.tertiary)
                .monospacedDigit()
                .help(l.cardFirstAcquired(Self.dayFormatter.string(from: date)))
        }
    }

    /// 숫자만 쓴다 — 값 줄에 곁들이는 것이라 「2026년 9월 1일」은 자리를 너무 먹는다.
    /// 시각은 적지 않는다. 몇 시에 뽑았는지는 아무 뜻이 없다.
    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = .current
        f.setLocalizedDateFormatFromTemplate("yMd")
        return f
    }()

    private var displayedFinish: CardFinish? {
        selectedFinish ?? finish ?? wallet.bestOwnedFinish(cardID: cardID)
    }

    /// 보유한 판형을 재질 선언 순서로 보여 준다. 가격순이면 시세 갱신 때 메뉴 위치가 움직여
    /// 같은 항목을 다시 찾기 어렵다.
    private var availablePrintings: [(printing: CardPrintingKey, count: Int)] {
        let rank = Dictionary(uniqueKeysWithValues:
            CardFinish.allCases.enumerated().map { ($1, $0) })
        return wallet.ownedPrintings(cardID: cardID).sorted {
            rank[$0.printing.finish, default: .max]
                < rank[$1.printing.finish, default: .max]
        }
    }

    /// 팩 그림과 이름. **여기를 누르면 상점의 그 팩으로 간다.**
    ///
    /// 갈매기를 달아 봤더니 눈에 띄지도 않으면서 자리만 먹었다. 대신 이름에 강조색을 준다 —
    /// 누를 수 있는 글자라는 표시로 화면 어디서나 쓰는 방식이고, 그림까지가 한 덩어리로
    /// 눌린다. 갈 곳이 없을 때(그 팩 안에서 연 카드)는 강조색을 빼 평범한 글자로 둔다.
    private func packLabel(linked: Bool) -> some View {
        HStack(spacing: 5) {
            PackImageView(setID: setID, width: 15)
            Text(setName)
                .font(linked ? Typography.bodySemibold : Typography.body)
                .foregroundStyle(linked ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(.primary))
                .lineLimit(1).truncationMode(.tail)
            // 실물 카드 하단의 번호(4/102). 바인더나 시세표에서 같은 카드를 찾을 때 쓴다.
            if let number = CardIndex.shared?.numberLabel(cardID) {
                Text(number)
                    .font(Typography.label).monospacedDigit()
                    .foregroundStyle(.secondary)
                    .lineLimit(1).fixedSize()
            }
        }
        .contentShape(Rectangle())
    }

    private func findSource() -> CardSource? {
        CardIndex.shared.flatMap { CardSource.of(cardID: cardID, index: $0, perks: wallet.openingPerks) }
    }

    /// 이 카드가 실제 시장에서 얼마인가. 갖고 있으면 장수만큼의 값도 함께 보여 준다.
    ///
    /// 등급 배지만으로는 알 수 없는 것을 말해 준다 — 같은 SAR 이라도 리자몽과 나머지는
    /// 스무 배 넘게 차이가 나고, 1999년 세트의 커먼이 최신 세트의 SR 보다 비싸기도 하다.
    ///
    /// 아래에 출처 팩에서 뽑힐 확률과, 온라인이면 마켓 판매 글을 붙인다. 출처 팩 이름만으로는
    /// 그 팩을 몇 개나 사야 하는지 알 수 없고, 사는 것보다 마켓이 빠를 수도 있다.
    @ViewBuilder
    private func priceRow(_ l: L) -> some View {
        let prices = CardPrices.shared
        let price = prices.flatMap { prices in
            (displayedFinish.flatMap({ prices.price(cardID: cardID, finish: $0) }) ?? prices.price(cardID))
                .map { (prices, $0) }
        }
        // 값 정보는 라벨을 붙인 작은 표로 둔다. 가운뎃점으로만 이어 붙인 줄은 시세, 보유 총액,
        // 시세의 출처가 한눈에 구분되지 않았다.
        Grid(alignment: .leading, horizontalSpacing: 8, verticalSpacing: 3) {
            if case let (prices, unit)? = price {
                // 개별 가격은 자르지 않는다. 중복 보유 총액은 별도 행을 쓴다.
                // 시세의 기준(판형별, 카드 대표값, 실거래 참고가)은 줄을 따로 두지 않고 툴팁으로 둔다.
                // 판형 시세가 아닐 때만 정보 표시를 붙여 눈여겨볼 값이라는 것만 알린다.
                GridRow {
                    infoLabel(l.marketPrice)
                    HStack(spacing: 5) {
                        if let displayedFinish { finishPicker(l, displayedFinish) }
                        Text(prices.formattedWithKRW(unit, language: wallet.language))
                            .font(Typography.bodySemibold).monospacedDigit()
                        if !usesExactPrintingPrice(prices) {
                            Image(systemName: "info.circle")
                                .font(.system(size: 13)).foregroundStyle(.tertiary)
                                .accessibilityLabel(Text(priceBasisText(l, prices)))
                        }
                        // 기록은 작은 창으로 띄운다. 여기 펼치면 카드가 밀려 작아진다.
                        if wallet.showsPriceHistory {
                            let series = PriceHistoryRequest.card(cardID, finish: displayedFinish, prices: prices)
                            PriceHistoryButton(wallet: wallet, title: name,
                                               subtitle: displayedFinish.map { l.cardFinishName($0, cardID: cardID) },
                                               kind: series.kind, item: series.item)
                        }
                    }
                    .lineLimit(1).minimumScaleFactor(0.75)
                    .help(priceBasisText(l, prices) + "\n"
                          + l.cardPriceSource(prices, cardID: cardID, finish: displayedFinish))
                }
                // 중복 판매 버튼은 보유 줄 끝에 붙는다. 따로 줄을 두면 중복이 있는 카드만 카드가
                // 작아졌다. 자리가 모자라면 처음 얻은 날, 그다음 판매 금액 순으로 툴팁으로 넘긴다.
                // 한 장만 있어도 이 줄을 둔다. 장수에 따라 줄 수가 달라지면 아래가 비어 보인다.
                if ownedCount > 0 {
                    GridRow {
                        infoLabel(l.marketHoldings)
                        let total = wallet.ownedPrintings(cardID: cardID).reduce(0.0) {
                            $0 + MarketEconomy.usd($1.printing, prices: prices) * Double($1.count)
                        }
                        let value = Text(WonFormatter.money(prices.krw(total), language: wallet.language))
                            .font(Typography.bodySemibold).monospacedDigit()
                            .foregroundStyle(Color.accentColor)
                        ViewThatFits(in: .horizontal) {
                            HStack(spacing: 5) { value; acquiredTag(l); spareSaleButton(l, showsAmount: true) }
                            HStack(spacing: 5) { value; spareSaleButton(l, showsAmount: true) }
                            HStack(spacing: 5) { value; spareSaleButton(l, showsAmount: false) }
                        }
                        .lineLimit(1)
                    }
                }
            }
            if let source, let chance = source.chanceText(l) {
                GridRow {
                    infoLabel(l.pullChanceLabel)
                    Text(chance)
                        .font(Typography.bodySemibold).monospacedDigit()
                        .lineLimit(1).minimumScaleFactor(0.8)
                        .help(source.perPack < 1 ? l.dexPullChance(DexFormat.percent(source.perPack)) : "")
                }
            }
            if wallet.isOnline {
                GridRow {
                    infoLabel(l.cardListingsLabel)
                    CardMarketRow(wallet: wallet, cardID: cardID)
                }
            }
        }
    }

    private func infoLabel(_ text: String) -> some View {
        Text(text).font(.system(size: 14)).foregroundStyle(.tertiary)
            .gridColumnAlignment(.trailing)
    }

    private func usesExactPrintingPrice(_ prices: CardPrices) -> Bool {
        !prices.isReference(cardID: cardID, finish: displayedFinish)
            && displayedFinish.flatMap({ prices.exactPrice(cardID: cardID, finish: $0) }) != nil
    }

    private func priceBasisText(_ l: L, _ prices: CardPrices) -> String {
        let label: String
        if prices.isReference(cardID: cardID, finish: displayedFinish) {
            label = l.completedSalesReference
        } else if displayedFinish.flatMap({ prices.exactPrice(cardID: cardID, finish: $0) }) == nil {
            label = l.fallbackPrintingPrice
        } else {
            label = l.exactPrintingPrice
        }
        return "\(l.priceBasis): \(label)"
    }

    /// 판형이 둘 이상이면 이름 자체를 메뉴로 쓴다. 별도 행을 만들지 않아 작은 팝오버에서도
    /// 카드 크기와 판매 버튼을 밀어내지 않는다.
    @ViewBuilder
    private func finishPicker(_ l: L, _ displayedFinish: CardFinish) -> some View {
        if availablePrintings.count > 1 {
            Menu {
                ForEach(availablePrintings.map(\.printing.finish), id: \.self) { candidate in
                    let count = wallet.cardCount(cardID, finish: candidate)
                    Button {
                        selectedFinish = candidate
                    } label: {
                        Text("\(l.cardFinishName(candidate, cardID: cardID)) · ×\(count)")
                    }
                }
            } label: {
                HStack(spacing: 3) {
                    Text(l.cardFinishName(displayedFinish, cardID: cardID))
                    Image(systemName: "chevron.up.chevron.down")
                        .imageScale(.small)
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.secondary)
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
        } else {
            Text(l.cardFinishName(displayedFinish, cardID: cardID))
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.secondary)
        }
    }

    private func priceLine(_ label: String, _ value: String, highlighted: Bool) -> some View {
        HStack(spacing: 5) {
            Text(label).font(.system(size: 14)).foregroundStyle(.tertiary)
            Text(value)
                .font(Typography.bodySemibold).monospacedDigit()
                .foregroundStyle(highlighted ? AnyShapeStyle(Color.accentColor)
                                             : AnyShapeStyle(.primary))
                .lineLimit(1).minimumScaleFactor(0.8)
        }
    }

    /// 메뉴바에 올릴 카드로 지정한다. 가진 카드에만 준다 — 없는 카드는 그릴 수 없다.
    @ViewBuilder
    private func favoriteButton(_ l: L) -> some View {
        if ownedCount > 0 {
            let isFavorite = wallet.favoriteCardID == cardID
            Button {
                wallet.setFavorite(isFavorite ? nil : cardID)
            } label: {
                Image(systemName: isFavorite ? "star.fill" : "star")
                    .font(.system(size: 17))
                    .foregroundStyle(isFavorite ? Color.yellow : Color.secondary)
            }
            .buttonStyle(.plain)
            .help(isFavorite ? l.favoriteCardClear : l.favoriteCardSet)
        }
    }

    /// 이 카드가 들어가는 도감. 눌러서 그 도감으로 넘어간다.
    ///
    /// 미완성인 것만, 완성에 가까운 것부터 두 개까지 배지로 보여준다 — 한 카드가 여덟 도감에
    /// 걸리는 경우가 있어 전부 늘어놓으면 카드보다 배지가 커진다. 나머지는 「+N」으로 알리고
    /// 누르면 도감 탭을 이 카드 이름으로 검색해 전부 보여 준다.
    private var relatedDexes: (shown: [DexStatus], hidden: Int) {
        let claimed = wallet.claimedDexIDs
        let owned: (String) -> Bool = { wallet.cardCount($0) > 0 }
        var out: [DexStatus] = []
        for dex in wallet.dexes where dex.cards.contains(cardID) && !claimed.contains(dex.id) {
            out.append(DexProgress.status(for: dex, owned: owned, claimed: []))
        }
        out.sort { a, b in
            if a.missing.count != b.missing.count { return a.missing.count < b.missing.count }
            return a.dex.id < b.dex.id
        }
        // 남은 조합이 없으면 이 카드가 나오는 세트의 도감을 보여 준다. 모든 카드가 세트 도감에는
        // 들어 있어서, 조합이 없는 카드만 아래가 비어 보이지 않는다.
        if out.isEmpty, let setDex = wallet.dexes.first(where: { $0.kind == .set && $0.homeSet == setID }) {
            return ([wallet.dexStatus(setDex)], 0)
        }
        return (Array(out.prefix(2)), max(0, out.count - 2))
    }

    @ViewBuilder
    private func dexBadges(_ l: L) -> some View {
        let related = relatedDexes.shown
        let hidden = relatedDexes.hidden
        if !related.isEmpty {
            VStack(spacing: 3) {
                Text(l.dexCardBelongsTo)
                    .font(Typography.caption).foregroundStyle(.tertiary)
                HStack(spacing: 5) {
                    ForEach(related) { status in
                        Button {
                            nav.dexID = status.dex.id
                            nav.tab = .dex
                        } label: {
                            HStack(spacing: 4) {
                                Text(status.dex.name.text(wallet.language))
                                    .font(.system(size: 14, weight: .semibold))
                                    .lineLimit(1)
                                Text(l.dexProgress(status.ownedCount, status.total))
                                    .font(.system(size: 14)).monospacedDigit()
                                    .foregroundStyle(status.isFilled ? Color.accentColor : .secondary)
                            }
                            .padding(.horizontal, 6).padding(.vertical, 2.5)
                            .background(Color.secondary.opacity(0.12), in: Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                    if hidden > 0 {
                        Button {
                            nav.dexSearch = name
                            nav.tab = .dex
                        } label: {
                            Text(verbatim: "+\(hidden)")
                                .font(.system(size: 14, weight: .semibold)).monospacedDigit()
                                .padding(.horizontal, 7).padding(.vertical, 2.5)
                                .background(Color.secondary.opacity(0.12), in: Capsule())
                        }
                        .buttonStyle(.plain)
                        .help(wallet.l.showAllDexes(related.count + hidden))
                    }
                }
            }
            .lineLimit(1)
        } else {
            // 배지가 없어도 같은 높이를 비워 둔다. 남는 자리가 카드 위아래로 나뉘면 카드가 내려앉아,
            // 크기는 같아도 넘겨 볼 때 카드 위치가 들쭉날쭉해진다.
            VStack(spacing: 3) {
                Text(verbatim: " ").font(Typography.caption)
                Text(verbatim: " ").font(.system(size: 14, weight: .semibold)).padding(.vertical, 2.5)
            }
            .hidden()
            .accessibilityHidden(true)
        }
    }

    /// 중복분을 게임에 바로 판다. 값은 시세의 절반이다(`CardSale`). 온라인이면 제값을 받을 수
    /// 있는 마켓 판매를 옆에 둔다.
    ///
    /// 금액을 원으로 적는다. 카드값을 원으로 보여 주면서 파는 자리에서만 토큰 자릿수를
    /// 내놓으면 같은 것을 두 가지 자로 재는 셈이 된다.
    ///
    /// 마지막 한 장은 남긴다 — 수집한 카드가 컬렉션에서 사라지는 것은 되돌릴 수 없다.
    /// 한 장뿐이면 아무것도 뜨지 않는다.
    /// 확인은 인라인이다(`.alert` 금지 — 팝오버가 닫히면 고아 시트가 남는다).
    @ViewBuilder
    private func saleControls(_ l: L) -> some View {
        let spare = wallet.spareCount(cardID)
        let refund = wallet.spareSaleValue(cardID: cardID)
        let bonus = wallet.perks.dustBonus

        if let lastRefund {
            Label(l.sellDone(MarketEconomy.money(tokens: lastRefund, language: wallet.language)),
                  systemImage: "checkmark.circle.fill")
                .font(Typography.bodySemibold)
                .foregroundStyle(.green)
        } else if spare <= 0 {
            // 팔 것이 없으면 아무것도 보여주지 않는다. 못 하는 이유를 적어 두면
            // 대부분의 카드에서 쓸모없는 줄만 남는다.
            EmptyView()
        } else if confirmingSale {
            VStack(spacing: 5) {
                Text(l.sellConfirm(spare, MarketEconomy.money(tokens: refund,
                                                              language: wallet.language)))
                    .font(Typography.label).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                // 추가금이 붙어 있으면 그 사실을 여기서 알린다 — 도감 탭까지 가야
                // 알 수 있으면 혜택을 받고 있다는 것을 모른 채 판다.
                Text(l.quickSaleNote)
                    .font(Typography.caption).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                if bonus > 0 {
                    Text(l.sellBonusIncluded(bonus))
                        .font(Typography.caption).foregroundStyle(Color.accentColor)
                }
                if availablePrintings.count > 1 {
                    Text(l.sellLowestFinishFirst)
                        .font(Typography.caption).foregroundStyle(.tertiary)
                }
                // 제값을 받는 마켓 판매도 여기서 고른다. 두 버튼이 한 줄에 안 들어가는 언어는 위아래로.
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 8) { confirmSaleButtons(l, spare: spare) }
                    VStack(spacing: 6) { confirmSaleButtons(l, spare: spare) }
                }
                .font(Typography.button)
            }
        } else {
            // 판매 버튼은 보유 줄에 있다. 여기는 확인과 완료 안내만 뜬다.
            EmptyView()
        }
    }

    /// 보유 줄 끝의 중복 판매 버튼. 누르면 아래에 확인이 뜨고, 거기서 바로 팔지 마켓에 팔지 고른다.
    @ViewBuilder
    private func spareSaleButton(_ l: L, showsAmount: Bool) -> some View {
        let spare = wallet.spareCount(cardID)
        if spare > 0, !confirmingSale, lastRefund == nil {
            let amount = "+\(MarketEconomy.money(tokens: wallet.spareSaleValue(cardID: cardID), language: wallet.language))"
            Button {
                confirmingSale = true
            } label: {
                // 도감 칩과 같은 알약 모양. 기본 크기 버튼은 이 줄보다 키가 커서 줄 높이가 달라진다.
                HStack(spacing: 4) {
                    Image(systemName: "wonsign.circle").foregroundStyle(Color.accentColor)
                    Text("\(l.sellSpares) ×\(spare)")
                    if showsAmount {
                        Text(amount).monospacedDigit().foregroundStyle(.secondary)
                    }
                }
                .font(.system(size: 14, weight: .semibold))
                .padding(.horizontal, 7).padding(.vertical, 2.5)
                .background(Color.secondary.opacity(0.14), in: Capsule())
                .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .hoverHighlight(cornerRadius: 11)
            .help(showsAmount ? l.quickSaleNote : "\(amount)\n\(l.quickSaleNote)")
        }
    }

    @ViewBuilder
    private func confirmSaleButtons(_ l: L, spare: Int) -> some View {
        Button(l.sellSpares) {
            Task {
                let got = await wallet.sellSparesOnlineAware(cardID: cardID, tier: tier, count: spare)
                confirmingSale = false
                lastRefund = got > 0 ? got : nil
            }
        }
        .buttonStyle(.borderedProminent)
        .disabled(wallet.resourceActionsDisabled)
        marketSaleButton(l)
        Button(l.cancel) { confirmingSale = false }
            .buttonStyle(.borderless)
    }

    /// 제값을 받는 길. 온라인 마켓의 「팔기」를 이 카드로 연다. 로그인하지 않았으면 마켓이 없다.
    @ViewBuilder
    private func marketSaleButton(_ l: L) -> some View {
        if wallet.isOnline {
            Button {
                OnlineWindow.shared.showSelling(wallet: wallet, cardID: cardID)
            } label: {
                Label(l.sellOnMarket, systemImage: "storefront")
                    .font(Typography.button)
            }
            .buttonStyle(.bordered)
            .help(l.sellOnMarketHint)
        }
    }
}
