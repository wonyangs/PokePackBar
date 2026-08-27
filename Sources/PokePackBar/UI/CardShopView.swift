import SwiftUI

/// 상점 — 세트별 카드팩을 산다.
///
/// 확인은 인라인 버튼 morph 로 한다. `.sheet` 와 `.alert` 를 쓰지 않는다 —
/// 팝오버가 닫힐 때 남는 고아 시트가 이후 클릭을 먹통으로 만드는 결함이 있다.
@MainActor
struct CardShopView: View {
    let wallet: WalletStore
    let index: CardIndex?

    var body: some View {
        let l = wallet.l
        // 고정 높이 — 팝오버를 다시 열 때 크기가 줄어드는 것을 막는다.
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                if let index {
                    ForEach(index.sets) { set in
                        PackCard(wallet: wallet, index: index, set: set)
                    }
                } else {
                    Text(l.cardIndexMissing)
                        .font(.callout).foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 40)
                }
            }
        }
        .frame(height: 470)
        .task(id: index?.setIDs.joined()) {
            // 상점이 첫 화면이라 여기가 비어 보이면 앱 전체가 안 뜬 것처럼 보인다.
            // 팩 아트만 미리 받아 둔다(세트당 1장).
            guard let index else { return }
            await CardImageLoader.prefetchPacks(setIDs: index.setIDs)
        }
    }
}

/// 세트 1개의 팩 상품. 가격·구성과 인라인 구매 확인.
@MainActor
private struct PackCard: View {
    let wallet: WalletStore
    let index: CardIndex
    let set: CardSet
    @State private var confirming = false

    private var price: Int { PackPricing.price(setID: set.id, index: index) }
    private var cardCount: Int { PackPricing.cardCount(setID: set.id, index: index) }
    private var canBuy: Bool { wallet.availableTokens >= price }

    var body: some View {
        let l = wallet.l
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 10) {
                PackImageView(setID: set.id, width: 34)
                VStack(alignment: .leading, spacing: 2) {
                    Text(l.packName(set.name))
                        .font(.callout.weight(.semibold))
                        .fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: 6) {
                        Text(l.packContents(cardCount))
                        Text("·")
                        Text(String(set.released.prefix(4)))
                        let owned = wallet.packCount(setID: set.id)
                        if owned > 0 {
                            Text("·")
                            Text("×\(owned)").fontWeight(.bold).monospacedDigit()
                        }
                    }
                    .font(.caption).foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
            controls(l)
        }
        .padding(10)
        .background(Color.secondary.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    @ViewBuilder
    private func controls(_ l: L) -> some View {
        if confirming {
            HStack(spacing: 8) {
                Text(l.packName(set.name)).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                Spacer()
                Button(l.buy) { buy() }.buttonStyle(.borderedProminent).controlSize(.small)
                Button(l.cancel) { confirming = false }.buttonStyle(.borderless).controlSize(.small)
            }
        } else {
            HStack {
                Text("\(l.shopPriceLabel) \(TokenFormatter.compact(price))")
                    .font(.caption2).foregroundStyle(.tertiary).monospacedDigit()
                Spacer()
                if canBuy {
                    Button(l.buy) { confirming = true }.buttonStyle(.bordered).controlSize(.small)
                } else {
                    Text(l.notEnoughTokens).font(.caption2).foregroundStyle(.tertiary)
                }
            }
        }
    }

    private func buy() {
        confirming = false
        // 차감이 실패하면 팩을 주지 않는다. 잔액은 사용량 갱신으로 바뀔 수 있어
        // 확인 화면을 띄운 사이에 부족해질 수 있다.
        guard wallet.spend(price) else { return }
        wallet.addPack(setID: set.id)
    }
}
