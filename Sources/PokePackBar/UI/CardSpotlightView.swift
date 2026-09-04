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
    /// 보유 장수. 0 이면 아직 얻지 못한 카드로 표시한다.
    let ownedCount: Int
    /// 미리 받아 둔 큰 그림이 있으면 기다리지 않는다.
    var preloaded: NSImage?
    let onClose: () -> Void

    @Environment(PopoverNavigation.self) private var nav

    @State private var landed = false
    @State private var confirmingSale = false
    /// 방금 받은 액수. 잠깐 보여주고 지운다.
    @State private var lastRefund: Int?

    var body: some View {
        let l = wallet.l
        VStack(spacing: 0) {
            // 뒤로가기는 왼쪽, 손대는 것은 오른쪽. 다른 화면과 같은 자리다.
            HStack {
                BackButton(action: onClose, hint: l.close)
                Spacer()
                favoriteButton(l)
            }

            Spacer(minLength: 0)

            // 마우스를 올리면 기울고 광택이 흐른다 — 확대 화면에서만 준다.
            // 격자에서는 크기가 작아 각도가 읽히지 않고, 지나가는 커서마다 반응하면 산만하다.
            HolographicCardView(cardID: cardID, tier: tier, width: 230,
                                dimmed: ownedCount == 0, preloaded: preloaded)
                .scaleEffect(landed ? 1 : 0.9)
                .opacity(landed ? 1 : 0)

            Spacer(minLength: 0)

            // 글자를 키우면서 줄 수를 줄였다. 등급·세트·보유량을 한 줄에 모으고 이름을
            // 한 줄로 묶어, 스크롤 없이 470pt 안에 들어오게 한다.
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
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            withAnimation(.spring(response: 0.34, dampingFraction: 0.75)) { landed = true }
        }
        .onChange(of: cardID) {
            confirmingSale = false
            lastRefund = nil
        }
    }

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
        }
        .contentShape(Rectangle())
    }

    /// 이 카드가 실제 시장에서 얼마인가. 갖고 있으면 장수만큼의 값도 함께 보여 준다.
    ///
    /// 등급 배지만으로는 알 수 없는 것을 말해 준다 — 같은 SAR 이라도 리자몽과 나머지는
    /// 스무 배 넘게 차이가 나고, 1999년 세트의 커먼이 최신 세트의 SR 보다 비싸기도 하다.
    @ViewBuilder
    private func priceRow(_ l: L) -> some View {
        if let prices = CardPrices.shared, let unit = prices.price(cardID) {
            // 한 줄로 둔다. 줄을 나누면 그만큼 아래가 밀려 판매 버튼이 화면 밖으로 나간다.
            HStack(spacing: 5) {
                Text(prices.formattedWithKRW(unit, language: wallet.language))
                    .font(Typography.bodySemibold).monospacedDigit()
                if ownedCount > 1, let total = prices.total(cardID, count: ownedCount) {
                    Text("·").font(Typography.label).foregroundStyle(.tertiary)
                    Text(l.marketHoldings).font(.system(size: 14)).foregroundStyle(.tertiary)
                    Text(WonFormatter.money(prices.krw(total), language: wallet.language))
                        .font(Typography.bodySemibold).monospacedDigit()
                        .foregroundStyle(Color.accentColor)
                }
                acquiredTag(l)
            }
            .lineLimit(1).minimumScaleFactor(0.75)
            .help(l.marketPriceSource(prices.asOf))
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
    /// 미완성인 것만, 완성에 가까운 것부터 최대 두 개까지 보여준다 — 한 카드가 여덧 도감에
    /// 걸리는 경우가 있어 전부 늘어놓으면 카드보다 배지가 커진다.
    private var relatedDexes: [DexStatus] {
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
        return Array(out.prefix(2))
    }

    @ViewBuilder
    private func dexBadges(_ l: L) -> some View {
        let related = relatedDexes
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
                }
            }
            .lineLimit(1)
        }
    }

    /// 중복분을 판다. 값은 시세 그대로다.
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
        let refund = CardSale.price(cardID: cardID, perks: wallet.perks) * spare
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
                if bonus > 0 {
                    Text(l.sellBonusIncluded(bonus))
                        .font(Typography.caption).foregroundStyle(Color.accentColor)
                }
                HStack(spacing: 8) {
                    Button(l.sellSpares) {
                        let got = wallet.sellSpares(cardID: cardID, tier: tier, count: spare)
                        confirmingSale = false
                        lastRefund = got > 0 ? got : nil
                    }
                    .buttonStyle(.borderedProminent)
                    Button(l.cancel) { confirmingSale = false }
                        .buttonStyle(.borderless)
                }
                .font(Typography.button)
            }
        } else {
            Button {
                confirmingSale = true
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "wonsign.circle")
                    Text("\(l.sellSpares) ×\(spare)")
                    Text("+\(MarketEconomy.money(tokens: refund, language: wallet.language))")
                        .monospacedDigit().foregroundStyle(.secondary)
                }
                .font(Typography.button)
            }
            .buttonStyle(.bordered)
        }
    }
}
