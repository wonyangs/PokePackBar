import SwiftUI

/// 도감 — 카드 몇 장을 묶은 조합의 진행 상황과 보상.
///
/// 목록에서 구성 카드와 보상까지 보인다. 들어가지 않고도 무엇을 모으는 조합인지 읽혀야
/// 22개를 훑을 수 있다. 상세는 설명과 카드를 크게 보기 위한 자리다.
@MainActor
struct DexView: View {
    let wallet: WalletStore
    let index: CardIndex?

    @State private var selected: String?

    private var statuses: [DexStatus] {
        DexProgress.sorted(DexProgress.statuses(dexes: wallet.dexes,
                                                owned: { wallet.cardCount($0) > 0 },
                                                claimed: wallet.claimedDexIDs))
    }

    var body: some View {
        Group {
            if wallet.dexes.isEmpty {
                Text(wallet.l.dexEmpty)
                    .font(.callout).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let selected, let dex = wallet.dexes.first(where: { $0.id == selected }) {
                DexDetailView(wallet: wallet, index: index, dex: dex) { self.selected = nil }
            } else {
                list
            }
        }
        .frame(height: 470)
    }

    /// 누적 혜택도 목록과 함께 스크롤한다.
    ///
    /// 고정해 두면 목록의 첫 줄을 계속 가린다. 같은 스크롤 안에 두면 폭도 저절로 맞는다
    /// (스크롤 밖에 두면 스크롤바가 차지하는 만큼 좌우가 어긋난다).
    private var list: some View {
        let all = statuses
        return ScrollView {
            LazyVStack(spacing: 8) {
                header(all)
                ForEach(all) { status in
                    // 버튼으로 감싸지 않는다. 버튼 라벨 안에 들어간 자식 뷰는
                    // 마우스를 버튼이 가져가 `.help` 툴팁이 뜨지 않는다.
                    DexRow(wallet: wallet, index: index, status: status)
                        .contentShape(Rectangle())
                        .onTapGesture { selected = status.id }
                }
            }
        }
    }

    private func header(_ all: [DexStatus]) -> some View {
        let l = wallet.l
        let summary = l.dexPerksSummary(wallet.perks)
        return VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 6) {
                Text(l.dexPerksHeader).font(.caption.weight(.semibold))
                Spacer()
                Text(l.dexCountSummary(all.filter(\.claimed).count, all.count))
                    .font(.caption2).foregroundStyle(.secondary).monospacedDigit()
            }
            if wallet.perks.isEmpty {
                Text(l.dexPerksNone).font(.caption2).foregroundStyle(.secondary)
            } else {
                DexPerkLine(wallet: wallet, perks: wallet.perks)
            }
        }
        .padding(.horizontal, 8).padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 7))
        .padding(.bottom, 2)
    }
}

/// 지금 걸려 있는 혜택을 종류별로 늘어놓는다. 각 항목에 설명 툴팁이 붙는다.
@MainActor
private struct DexPerkLine: View {
    let wallet: WalletStore
    let perks: DexPerks

    var body: some View {
        let l = wallet.l
        return HStack(spacing: 4) {
            ForEach(DexPerkKind.allCases, id: \.self) { kind in
                if let text = l.dexPerkSummaryItem(kind, perks) {
                    Text(text)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Color.accentColor)
                        .help(l.dexPerkHelp(kind))
                }
            }
            Spacer(minLength: 0)
        }
    }
}

/// 목록 한 줄 — 이름, 난이도, 구성 카드, 보상, 수령 버튼.
@MainActor
private struct DexRow: View {
    let wallet: WalletStore
    let index: CardIndex?
    let status: DexStatus

    /// 한 줄에 넣는 카드 수와 폭. 폭 332 안에서 카드가 읽힐 만큼 크게 잡는다.
    static let columns = 5
    static let cardWidth: CGFloat = 58
    /// 카드는 한 줄만 쓴다. 22개 도감이 저마다 여러 줄을 쓰면 목록을 훑을 수 없다.
    /// 넘치면 마지막 칸을 "+N" 으로 바꾼다 — 상위 등급부터 정렬돼 있어 앞이 남는다.
    static let maxShown = 5

    private var dex: Dex { status.dex }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            title
            DexCardStrip(wallet: wallet, index: index, cards: dex.cards,
                         limit: Self.maxShown, onTap: nil)
            footer
        }
        .padding(.vertical, 8).padding(.horizontal, 8)
        .background(background, in: RoundedRectangle(cornerRadius: 9))
        .overlay {
            RoundedRectangle(cornerRadius: 9)
                .stroke(status.isClaimable ? Color.accentColor.opacity(0.6) : .clear, lineWidth: 1)
        }
    }

    private var background: Color {
        if status.isClaimable { return Color.accentColor.opacity(0.12) }
        return Color.secondary.opacity(status.claimed ? 0.05 : 0.07)
    }

    private var title: some View {
        let l = wallet.l
        return HStack(spacing: 6) {
            Text(dex.name.text(wallet.language))
                .font(.caption.weight(.bold)).lineLimit(1)
            DexStars(tier: dex.tier)
            Spacer(minLength: 0)
            Text(status.claimed ? l.dexComplete : l.dexProgress(status.ownedCount, status.total))
                .font(.caption2.weight(.medium))
                .foregroundStyle(status.claimed ? .green : .secondary)
                .monospacedDigit()
        }
    }

    /// 보상은 항상 보이고, 다 모으면 수령 버튼이 켜진다.
    private var footer: some View {
        HStack(spacing: 6) {
            DexRewardLine(wallet: wallet, dex: dex)
            Spacer(minLength: 0)
            DexClaimAction(wallet: wallet, status: status)
        }
    }
}

/// 보상 한 줄 — 팩 수와 혜택. 혜택에는 설명 툴팁이 붙는다.
@MainActor
private struct DexRewardLine: View {
    let wallet: WalletStore
    let dex: Dex

    var body: some View {
        let l = wallet.l
        return HStack(spacing: 5) {
            Image(systemName: "shippingbox.fill")
                .font(.system(size: 9)).foregroundStyle(.secondary)
            Text(l.dexRewardPacks(dex.reward.packs))
                .font(.caption2.weight(.semibold))
            ForEach(Array(dex.reward.perks.enumerated()), id: \.offset) { _, perk in
                Text(verbatim: "·").font(.caption2).foregroundStyle(.tertiary)
                Text(l.dexPerkText(perk))
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Color.accentColor)
                    .help(l.dexPerkHelp(perk.kind))
            }
        }
    }
}

/// 수령 버튼 / 수령 완료 표시. 다 모으기 전에는 아무것도 두지 않는다.
@MainActor
private struct DexClaimAction: View {
    let wallet: WalletStore
    let status: DexStatus

    var body: some View {
        let l = wallet.l
        if status.claimed {
            Label(l.dexClaimed, systemImage: "checkmark.circle.fill")
                .font(.caption2).foregroundStyle(.green)
        } else if status.isClaimable {
            Button(l.dexClaim) { wallet.claim(status.dex.id) }
                .buttonStyle(.borderedProminent).controlSize(.small)
        }
    }
}

/// 구성 카드 한 줄. 상위 등급이 앞에 온다(생성 스크립트가 그 순서로 넣는다).
@MainActor
private struct DexCardStrip: View {
    let wallet: WalletStore
    let index: CardIndex?
    let cards: [String]
    let limit: Int
    /// 누르면 무엇을 할지. nil 이면 카드가 버튼이 아니다(목록에서는 줄 전체가 버튼이다).
    let onTap: ((String) -> Void)?

    var body: some View {
        let overflow = cards.count > limit
        let shown = Array(cards.prefix(overflow ? limit - 1 : limit))
        let hidden = cards.count - shown.count
        let grid = Array(repeating: GridItem(.fixed(DexRow.cardWidth), spacing: 5),
                         count: DexRow.columns)
        return LazyVGrid(columns: grid, alignment: .leading, spacing: 5) {
            ForEach(shown, id: \.self) { cardID in
                if let onTap {
                    Button { onTap(cardID) } label: { member(cardID) }
                        .buttonStyle(.plain)
                } else {
                    member(cardID)
                }
            }
            if hidden > 0 {
                Text(verbatim: "+\(hidden)")
                    .font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                    .frame(width: DexRow.cardWidth,
                           height: (DexRow.cardWidth / 0.717).rounded())
                    .background(Color.secondary.opacity(0.12),
                                in: RoundedRectangle(cornerRadius: 4))
            }
        }
    }

    private func member(_ cardID: String) -> some View {
        let owned = wallet.cardCount(cardID) > 0
        let entry = index?.card(cardID)
        return VStack(spacing: 2) {
            CardImageView(cardID: cardID, width: DexRow.cardWidth, dimmed: !owned)
            Text(entry.map { wallet.l.tierBadge($0.tier) } ?? "")
                .font(.system(size: 8, weight: .heavy))
                .foregroundStyle(entry.map { owned ? tierColor($0.tier) : Color.secondary }
                                 ?? Color.secondary)
                .opacity(owned ? 1 : 0.55)
        }
        .help(helpText(cardID, entry: entry, owned: owned))
    }

    /// 마우스를 올리면 카드 이름과, 없으면 한 팩에서 나올 확률을 알려 준다.
    private func helpText(_ cardID: String, entry: CardEntry?, owned: Bool) -> String {
        guard let entry else { return cardID }
        guard !owned, let index else { return entry.name }
        let chance = DexDifficulty.pullProbability(cardID: cardID, index: index,
                                                   perks: wallet.perks)
        return "\(entry.name) — \(wallet.l.dexPullChance(DexFormat.percent(chance)))"
    }
}

/// 도감 상세 — 설명, 구성 카드 전체, 보상, 뽑으러 가기.
@MainActor
private struct DexDetailView: View {
    let wallet: WalletStore
    let index: CardIndex?
    let dex: Dex
    let onClose: () -> Void

    @Environment(PopoverNavigation.self) private var nav

    /// 크게 보고 있는 카드. 값이 있으면 카드 화면이 상세를 덮는다.
    @State private var spotlight: String?

    private var status: DexStatus {
        DexProgress.status(for: dex, owned: { wallet.cardCount($0) > 0 },
                           claimed: wallet.claimedDexIDs.contains(dex.id))
    }

    var body: some View {
        if let spotlight, let entry = index?.card(spotlight) {
            CardSpotlightView(wallet: wallet, cardID: entry.id, name: entry.name,
                              tier: entry.tier, setID: entry.setID,
                              setName: index?.set(entry.setID)?.name ?? entry.setID,
                              ownedCount: wallet.cardCount(entry.id)) {
                self.spotlight = nil
            }
        } else {
            detail
        }
    }

    private var detail: some View {
        let l = wallet.l
        let state = status
        return VStack(spacing: 0) {
            HStack {
                Button(action: onClose) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help(l.close)
                Spacer()
            }

            VStack(spacing: 4) {
                Text(dex.name.text(wallet.language))
                    .font(.title3.weight(.semibold))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 6) {
                    DexStars(tier: dex.tier)
                    Text(state.claimed ? l.dexComplete
                                       : l.dexProgress(state.ownedCount, state.total))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(state.claimed ? .green : .secondary)
                        .monospacedDigit()
                }
                Text(dex.blurb.text(wallet.language))
                    .font(.caption).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 6)
            }
            .padding(.vertical, 8)

            ScrollView {
                DexCardStrip(wallet: wallet, index: index, cards: dex.cards,
                             limit: dex.cards.count) { spotlight = $0 }
            }

            Spacer(minLength: 0)

            VStack(spacing: 6) {
                HStack(spacing: 6) {
                    DexRewardLine(wallet: wallet, dex: dex)
                    Spacer(minLength: 0)
                }
                .padding(.vertical, 4).padding(.horizontal, 8)
                .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 6))

                HStack(spacing: 8) {
                    DexClaimAction(wallet: wallet, status: state)
                    if !state.isFilled {
                        Button {
                            nav.shopSet = dex.homeSet
                            nav.tab = .shop
                        } label: {
                            Label(l.dexGoBuyPack, systemImage: "cart").font(.caption)
                        }
                        .buttonStyle(.bordered).controlSize(.small)
                    }
                }
            }
            .padding(.bottom, 6)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onChange(of: dex.id) { spotlight = nil }
    }
}

/// 난이도 별. 채운 별과 빈 별을 함께 그려 5단 중 어디인지 바로 읽히게 한다.
@MainActor
struct DexStars: View {
    let tier: Int

    var body: some View {
        HStack(spacing: 0.5) {
            ForEach(1...Dex.maxTier, id: \.self) { step in
                Image(systemName: step <= tier ? "star.fill" : "star")
                    .font(.system(size: 6.5))
                    .foregroundStyle(step <= tier ? Color.orange : Color.secondary.opacity(0.35))
            }
        }
        .accessibilityLabel(Text(verbatim: "\(tier)/\(Dex.maxTier)"))
    }
}

enum DexFormat {
    /// 아주 작은 확률까지 읽히게 한다. 0.2% 를 0% 로 적으면 불가능한 카드처럼 보인다.
    static func percent(_ value: Double) -> String {
        let scaled = value * 100
        if scaled >= 10 { return String(format: "%.0f%%", scaled) }
        if scaled >= 1 { return String(format: "%.1f%%", scaled) }
        return String(format: "%.2f%%", scaled)
    }
}
