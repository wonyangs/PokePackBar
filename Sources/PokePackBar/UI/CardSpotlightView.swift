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
            HStack {
                favoriteButton(l)
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help(l.close)
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
                    // 출처 팩 — 그림까지 함께 둔다. 이름만으로는 상점에서 어느 것인지 못 찾는다.
                    PackImageView(setID: setID, width: 15)
                    Text(setName)
                        .font(Typography.body)
                        .lineLimit(1).truncationMode(.tail)
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
            out.append(DexProgress.status(for: dex, owned: owned, claimed: false))
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
