import SwiftUI

/// 한번에 판매 — 값이 낮은 카드의 중복분을 한 번에 판다.
///
/// sv10 100팩을 열면 중복이 164종 807장이 된다. 카드 상세로 들어가 한 종씩 팔면 164번을
/// 눌러야 하고, 그래서 아무도 정리하지 않는다.
///
/// **임계값은 값으로 잡는다.** 등급으로는 잡카드를 가릴 수 없다 — 커먼 한 장이 53,481원이고
/// 게임에서 가장 싼 카드(69원)는 RR 이다.
///
/// **마지막 한 장은 남긴다.** 마지막 장을 팔면 도감 진행이 되돌아가고 컬렉션에서 그 카드가
/// 사라지는데 되돌릴 방법이 없다. 한 장을 남겨도 잡카드는 계속 중복으로 쌓이므로 정리 효과는
/// 그대로고, 이 화면은 반복해서 쓰는 청소 도구가 된다.
///
/// 팝오버라 모달을 쓸 수 없어 탭 안에서 화면만 바꾼다(`.alert`·`.sheet` 은 팝오버가 닫히면
/// 고아 창을 남긴다).
@MainActor
struct BulkSaleView: View {
    let wallet: WalletStore
    /// 지금 목록에 걸린 카드. 세트·등급 필터가 이미 적용된 것이 들어온다 —
    /// 화면에 안 보이는 카드가 팔리면 안 된다.
    let pool: [CardEntry]
    let onClose: () -> Void

    /// 임계값 후보(원). 옛날 세트는 커먼도 비싸서 1,000원으로는 거의 안 잡히고,
    /// 최신 세트는 중복의 98% 가 1,000원 아래다. 세트에 따라 고를 수 있어야 한다.
    static let thresholds = [1_000, 3_000, 5_000, 7_000, 10_000]

    /// 마지막에 고른 임계값을 기억한다.
    @AppStorage("bulkSaleThreshold") private var threshold = 1_000
    @State private var confirming = false
    /// 방금 판 결과. 뜨면 격자 대신 이것만 보여주고 닫기를 기다린다.
    @State private var sold: WalletStore.BulkSale?

    private var targets: [String] {
        WalletStore.bulkSaleTargets(pool, maxWon: threshold,
                                    spares: { wallet.spareCount($0) })
    }

    var body: some View {
        let l = wallet.l
        let ids = targets
        let sale = wallet.bulkSalePreview(ids)
        return VStack(spacing: 6) {
            header(l)
            if let sold {
                result(l, sold)
            } else {
                picker(l)
                summary(l, sale)
                grid(ids)
                Spacer(minLength: 0)
                action(l, sale, ids)
            }
        }
        .frame(height: PopoverMetrics.tabHeight)
    }

    private func header(_ l: L) -> some View {
        HStack(spacing: 6) {
            Button(action: onClose) {
                Image(systemName: "chevron.left")
                    .font(Typography.labelSemibold)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help(l.close)
            Text(l.bulkSell).font(Typography.title)
            Spacer(minLength: 0)
        }
    }

    /// 임계값 칩. 누르면 아래 격자가 그 임계값의 대상으로 바뀐다 —
    /// 되돌릴 수 없는 동작이라 무엇이 사라지는지 눈으로 보고 눌러야 한다.
    private func picker(_ l: L) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(l.bulkSellPrompt)
                .font(Typography.label).foregroundStyle(.secondary)
            HStack(spacing: 4) {
                ForEach(Self.thresholds, id: \.self) { won in
                    let picked = won == threshold
                    Button {
                        threshold = won
                        confirming = false
                    } label: {
                        Text(WonFormatter.money(won, language: wallet.language))
                            .font(Typography.labelSemibold)
                            .monospacedDigit()
                            .foregroundStyle(picked ? Color.white : Color.primary)
                            .padding(.horizontal, 7).padding(.vertical, 4)
                            .background(picked ? AnyShapeStyle(Color.accentColor)
                                               : AnyShapeStyle(Color.secondary.opacity(0.12)),
                                        in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .help(l.bulkSellUpTo(WonFormatter.money(won, language: wallet.language)))
                }
                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func summary(_ l: L, _ sale: WalletStore.BulkSale) -> some View {
        HStack(spacing: 5) {
            if sale.isEmpty {
                Text(l.bulkSellNothing)
                    .font(Typography.label).foregroundStyle(.secondary)
            } else {
                Text(l.bulkSellSummary(sale.kinds, sale.copies,
                                       MarketEconomy.money(tokens: sale.tokens,
                                                           language: wallet.language)))
                    .font(Typography.amount).monospacedDigit()
                    .foregroundStyle(Color.accentColor)
                    .lineLimit(1).minimumScaleFactor(0.8)
            }
            Spacer(minLength: 0)
        }
    }

    /// 팔릴 카드. 배지는 **팔릴 장수**다 — 가진 장수가 아니라 사라질 장수를 적어야
    /// 무엇을 잃는지 읽힌다.
    private func grid(_ ids: [String]) -> some View {
        ScrollView {
            LazyVGrid(columns: CardGrid.collection.items,
                      spacing: CardGrid.collection.spacing) {
                ForEach(ids, id: \.self) { cardID in
                    ZStack(alignment: .bottomTrailing) {
                        CardImageView(cardID: cardID, width: CardGrid.collection.width)
                        Text("−\(wallet.spareCount(cardID))")
                            .font(.system(size: 13, weight: .heavy))
                            .padding(.horizontal, 3).padding(.vertical, 1)
                            .background(.black.opacity(0.65), in: Capsule())
                            .foregroundStyle(.white)
                            .padding(2)
                    }
                }
            }
            .padding(.horizontal, 1)
        }
    }

    @ViewBuilder
    private func action(_ l: L, _ sale: WalletStore.BulkSale, _ ids: [String]) -> some View {
        if sale.isEmpty {
            EmptyView()
        } else if confirming {
            VStack(spacing: 5) {
                Text(l.bulkSellConfirm)
                    .font(Typography.label).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 8) {
                    Button(l.bulkSell) {
                        let got = wallet.sellSpares(ids)
                        confirming = false
                        sold = got.isEmpty ? nil : got
                    }
                    .buttonStyle(.borderedProminent)
                    Button(l.cancel) { confirming = false }
                        .buttonStyle(.borderless)
                }
                .font(Typography.button)
            }
            .padding(.bottom, 4)
        } else {
            Button(l.bulkSell) { confirming = true }
                .buttonStyle(.borderedProminent)
                .font(Typography.button)
                .padding(.bottom, 4)
        }
    }

    private func result(_ l: L, _ sale: WalletStore.BulkSale) -> some View {
        VStack(spacing: 10) {
            Spacer(minLength: 0)
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 40)).foregroundStyle(.green)
            Text(l.bulkSellDone(sale.copies,
                                MarketEconomy.money(tokens: sale.tokens,
                                                    language: wallet.language)))
                .font(Typography.title)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            Button(l.done, action: onClose)
                .buttonStyle(.borderedProminent)
                .font(Typography.button)
                .padding(.bottom, 4)
        }
        .frame(maxWidth: .infinity)
    }
}
