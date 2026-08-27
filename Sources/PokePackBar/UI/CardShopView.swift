import SwiftUI

/// 상점 — 팩을 격자로 늘어놓고, 고르면 상세를 보여준다.
///
/// 목록 한 줄에 이름과 가격을 늘어놓는 방식은 팩이 열 개만 넘어도 훑기 어렵다.
/// 팩은 그림으로 알아보는 물건이라 격자가 맞다. 자세한 것은 눌러서 본다.
@MainActor
struct CardShopView: View {
    let wallet: WalletStore
    let index: CardIndex?

    /// 상세를 보고 있는 세트. nil 이면 격자.
    @State private var selectedSet: String?

    var body: some View {
        Group {
            if let index {
                if let selectedSet, let set = index.set(selectedSet) {
                    PackDetailView(wallet: wallet, index: index, set: set) {
                        self.selectedSet = nil
                    }
                } else {
                    grid(index)
                }
            } else {
                Text(wallet.l.cardIndexMissing)
                    .font(.callout).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        // 고정 높이 — 팝오버를 다시 열 때 크기가 줄어드는 것을 막는다.
        .frame(height: 470)
        .task(id: index?.setIDs.joined()) {
            // 상점이 첫 화면이라 여기가 비어 보이면 앱 전체가 안 뜬 것처럼 보인다.
            guard let index else { return }
            await CardImageLoader.prefetchPacks(setIDs: index.setIDs)
        }
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
        let l = wallet.l
        let price = PackPricing.price(setID: set.id, index: index)
        let owned = wallet.packCount(setID: set.id)
        return VStack(spacing: 5) {
            ZStack(alignment: .topTrailing) {
                PackImageView(setID: set.id, width: 78)
                if owned > 0 {
                    Text("×\(owned)")
                        .font(.system(size: 9, weight: .heavy))
                        .padding(.horizontal, 4).padding(.vertical, 1.5)
                        .background(Color.accentColor, in: Capsule())
                        .foregroundStyle(.white)
                        .padding(3)
                }
            }
            Text(set.name)
                .font(.caption.weight(.semibold))
                .lineLimit(2).multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Text(TokenFormatter.grouped(price))
                .font(.caption2).monospacedDigit()
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

    private var price: Int { PackPricing.price(setID: set.id, index: index) }
    private var cardsPerPack: Int { PackPricing.cardCount(setID: set.id, index: index) }
    private var members: [CardEntry] { index.cards.filter { $0.setID == set.id } }
    private var ownedCount: Int { members.filter { wallet.cardCount($0.id) > 0 }.count }

    /// 잔액으로 살 수 있는 최대 수량. 한 번에 스무 개면 충분하다.
    private var maxQuantity: Int { max(1, min(20, wallet.availableTokens / max(price, 1))) }
    private var total: Int { price * quantity }
    private var canBuy: Bool { wallet.availableTokens >= total }

    var body: some View {
        let l = wallet.l
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 17)).foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help(l.close)
            }

            ScrollView {
                VStack(spacing: 10) {
                    PackImageView(setID: set.id, width: 104)
                        .shadow(radius: 6, y: 2)

                    VStack(spacing: 2) {
                        Text(set.name).font(.title3.weight(.semibold))
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                        Text("\(String(set.released.prefix(4)))  ·  \(l.packContents(cardsPerPack))")
                            .font(.caption).foregroundStyle(.secondary)
                    }

                    summaryRows(l)
                    oddsTable(l)
                }
                .padding(.horizontal, 2)
            }

            purchaseBar(l)
        }
    }

    private func summaryRows(_ l: L) -> some View {
        let rate = members.isEmpty ? 0 : Double(ownedCount) / Double(members.count) * 100
        return VStack(spacing: 4) {
            row(l.packTotalCards, "\(members.count)")
            row(l.packCollected, "\(ownedCount) / \(members.count)  (\(String(format: "%.1f", rate))%)")
        }
        .padding(8)
        .background(Color.secondary.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).font(.caption).foregroundStyle(.secondary)
            Spacer()
            Text(value).font(.caption.weight(.semibold)).monospacedDigit()
        }
    }

    /// 등급별 보유 장수와 히트 확률. 확률은 뽑기가 실제로 쓰는 계산과 같은 것이다.
    private func oddsTable(_ l: L) -> some View {
        let odds = Dictionary(uniqueKeysWithValues:
            PackOpening.hitOdds(setID: set.id, index: index).map { ($0.tier, $0.probability) })
        let pool = index.pools[set.id] ?? [:]
        let tiers = CardTier.allCases.reversed().filter { !(pool[$0] ?? []).isEmpty }

        return VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(l.packOdds).font(.caption.weight(.semibold))
                Spacer()
            }
            ForEach(tiers, id: \.self) { tier in
                let owned = (pool[tier] ?? []).filter { wallet.cardCount($0) > 0 }.count
                HStack(spacing: 6) {
                    Text(tier.rawValue)
                        .font(.system(size: 10, weight: .heavy))
                        .foregroundStyle(tierColor(tier))
                        .frame(width: 30, alignment: .leading)
                    Text(l.tierName(tier)).font(.caption2).foregroundStyle(.secondary)
                    Spacer()
                    Text("\(owned)/\((pool[tier] ?? []).count)")
                        .font(.caption2).foregroundStyle(.tertiary).monospacedDigit()
                    Text(odds[tier].map { String(format: "%.1f%%", $0 * 100) } ?? "—")
                        .font(.caption2.weight(.semibold)).monospacedDigit()
                        .frame(width: 42, alignment: .trailing)
                }
            }
            Text(l.packOddsHint).font(.system(size: 9)).foregroundStyle(.tertiary)
        }
        .padding(8)
        .background(Color.secondary.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func purchaseBar(_ l: L) -> some View {
        VStack(spacing: 6) {
            HStack(spacing: 8) {
                Text(l.packQuantity).font(.caption).foregroundStyle(.secondary)
                Stepper(value: $quantity, in: 1...maxQuantity) {
                    Text("\(quantity)").font(.callout.weight(.semibold)).monospacedDigit()
                }
                .fixedSize()
                Spacer()
                Text(TokenFormatter.grouped(total))
                    .font(.caption.weight(.semibold)).monospacedDigit()
                    .foregroundStyle(canBuy ? .primary : .secondary)
            }
            Button(canBuy ? l.buyCount(quantity) : l.notEnoughTokens) { buy() }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(!canBuy)
                .frame(maxWidth: .infinity)
        }
        .padding(.top, 8)
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
