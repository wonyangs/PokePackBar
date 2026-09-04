import SwiftUI

/// 도감 — 조합의 진행 상황과 보상.
///
/// **262개가 되면서 평면 목록을 버렸다.** 조합 도감이 7세트만 덮던 시절에는 22줄이라
/// 훑을 수 있었지만, 이제 조합 140개와 세트 122개다. 상점이 이미 같은 문제를 풀었으므로
/// 같은 구조를 쓴다 — 갈래(조합 / 세트) + 시대 → 세트 한 단계.
@MainActor
struct DexView: View {
    let wallet: WalletStore
    let index: CardIndex?

    enum Section: CaseIterable { case theme, set }

    @State private var section: Section = .theme
    @State private var openedEra: String?
    @State private var selected: String?
    /// 확정 카드로 방금 받은 것. 뒤집어 볼 때까지 이 화면이 덮는다.
    @State private var granted: PulledCard?
    /// 그 카드의 가림막이 이미 걷혔는가.
    @State private var revealed = false

    private func statuses(_ dexes: [Dex]) -> [DexStatus] {
        DexProgress.sorted(dexes.map { wallet.dexStatus($0, index: index) })
    }

    var body: some View {
        Group {
            if let granted, let entry = index?.card(granted.id) {
                // **받은 카드를 보여 준다.** 조용히 컬렉션에 넣으면 「확정 카드 1장」이라
                // 적어 놓고 무엇을 줬는지 알 길이 없다. 오리파와 같은 연출을 쓴다.
                PulledCardView(wallet: wallet, card: granted, startOpened: revealed,
                               onReveal: { revealed = true; wallet.markAllRevealed() },
                               onDetail: { selected = nil; self.granted = nil },
                               onDone: { self.granted = nil },
                               name: entry.displayName(wallet.language))
            } else if wallet.dexes.isEmpty {
                Text(wallet.l.dexEmpty)
                    .font(Typography.body).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let selected, let dex = wallet.dexes.first(where: { $0.id == selected }) {
                DexDetailView(wallet: wallet, index: index, dex: dex,
                              onGranted: show) { self.selected = nil }
            } else {
                VStack(spacing: 8) {
                    sectionPicker
                    switch section {
                    case .theme: themeList
                    case .set:   setBrowser
                    }
                }
            }
        }
        .frame(height: PopoverMetrics.tabHeight)
    }

    private var sectionPicker: some View {
        SegmentedTabs(items: [
            .init(value: Section.theme, label: wallet.l.dexThemeSection),
            .init(value: Section.set, label: wallet.l.dexSetSection),
        ], selection: $section)
    }

    /// 조합 도감 — 예전 목록 그대로. 140개라 스크롤로 훑는다.
    private var themeList: some View {
        let all = statuses(wallet.dexes.filter { $0.kind == .theme })
        return ScrollView {
            LazyVStack(spacing: 8) {
                header(all)
                ForEach(all) { status in
                    // 버튼으로 감싸지 않는다. 버튼 라벨 안에 들어간 자식 뷰는
                    // 마우스를 버튼이 가져가 `.help` 툴팁이 뜨지 않는다.
                    DexRow(wallet: wallet, index: index, status: status,
                           onGranted: show)
                        .contentShape(Rectangle())
                        .onTapGesture { selected = status.id }
                }
            }
        }
    }

    /// 받은 카드를 뒤집어 보는 화면으로 넘긴다.
    private func show(_ claim: DexClaim) {
        guard let card = claim.card, let entry = index?.card(card) else { return }
        revealed = false
        granted = PulledCard(id: card, tier: entry.tier, isNew: wallet.cardCount(card) <= 1)
    }

    /// 세트 도감 — 시대를 한 단계 두고 그 안에서 세트를 늘어놓는다.
    @ViewBuilder
    private var setBrowser: some View {
        if let index, let openedEra,
           let era = index.eras.first(where: { $0.name == openedEra }) {
            let ids = Set(era.sets.map(\.id))
            let rows = statuses(wallet.dexes.filter { $0.kind == .set && ids.contains($0.homeSet) })
            VStack(spacing: 6) {
                HStack(spacing: 6) {
                    BackButton(action: { self.openedEra = nil })
                    Text(era.name).font(Typography.bodySemibold)
                    Spacer(minLength: 0)
                    Text(wallet.l.dexCountSummary(rows.filter(\.claimed).count, rows.count))
                        .font(Typography.label).foregroundStyle(.secondary).monospacedDigit()
                }
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(rows) { status in
                            DexRow(wallet: wallet, index: index, status: status,
                                   onGranted: show)
                                .contentShape(Rectangle())
                                .onTapGesture { selected = status.id }
                        }
                    }
                }
            }
        } else if let index {
            eraList(index)
        }
    }

    /// 시대 목록. 시대마다 그 안 세트 도감의 진행을 요약한다.
    private func eraList(_ index: CardIndex) -> some View {
        let all = statuses(wallet.dexes.filter { $0.kind == .set })
        let byEra = Dictionary(grouping: all) { status in
            index.eras.first { $0.sets.contains { $0.id == status.dex.homeSet } }?.name ?? ""
        }
        return ScrollView {
            LazyVStack(spacing: 8) {
                header(all)
                ForEach(index.eras, id: \.name) { era in
                    let rows = byEra[era.name] ?? []
                    if !rows.isEmpty {
                        eraRow(era.name, rows)
                            .contentShape(Rectangle())
                            .onTapGesture { openedEra = era.name }
                    }
                }
            }
        }
    }

    private func eraRow(_ name: String, _ rows: [DexStatus]) -> some View {
        let claimable = rows.contains { $0.isClaimable }
        let steps = rows.reduce(0) { $0 + $1.claimedSteps.count }
        let total = rows.reduce(0) { $0 + $1.steps.count }
        return HStack(spacing: 8) {
            Text(name).font(Typography.bodySemibold).lineLimit(1)
            Spacer(minLength: 0)
            if claimable {
                Image(systemName: "gift.fill")
                    .font(.system(size: 14)).foregroundStyle(Color.accentColor)
            }
            Text("\(steps) / \(total)")
                .font(Typography.body).foregroundStyle(.secondary).monospacedDigit()
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold)).foregroundStyle(.tertiary)
        }
        .padding(.vertical, 9).padding(.horizontal, CardGrid.dexRowPadding)
        .background(claimable ? Color.accentColor.opacity(0.12) : Color.secondary.opacity(0.07),
                    in: RoundedRectangle(cornerRadius: 9))
    }

    /// 누적 혜택도 목록과 함께 스크롤한다.
    ///
    /// 고정해 두면 목록의 첫 줄을 계속 가린다. 같은 스크롤 안에 두면 폭도 저절로 맞는다
    /// (스크롤 밖에 두면 스크롤바가 차지하는 만큼 좌우가 어긋난다).
    private func header(_ all: [DexStatus]) -> some View {
        let l = wallet.l
        let done = wallet.completedDexCount
        let next = wallet.ladder.first { done < $0.completed }
        return VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 6) {
                Text(l.dexPerksHeader).font(Typography.bodySemibold)
                // 칭호가 여기 붙는다. 얻었는데 보여 줄 자리가 없으면 보상이 아니다.
                if let title = wallet.title {
                    Text(title.text(wallet.language))
                        .font(Typography.labelSemibold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 5).padding(.vertical, 1)
                        .background(Color.accentColor, in: Capsule())
                }
                Spacer()
                Text(l.dexCountSummary(all.filter(\.claimed).count, all.count))
                    .font(Typography.label).foregroundStyle(.secondary).monospacedDigit()
            }
            if wallet.perks.isEmpty {
                Text(l.dexPerksNone).font(Typography.label).foregroundStyle(.secondary)
            } else {
                DexPerkLine(wallet: wallet, perks: wallet.perks)
            }
            // 계단 — 영구 혜택이 여기서 나온다. 도감마다 나눠 주면 한 칸이 0.1% 가 된다.
            Text(next.map { l.dexLadderNext(done, $0.completed) } ?? l.dexLadderDone)
                .font(Typography.label).foregroundStyle(.tertiary).monospacedDigit()
        }
        .padding(.horizontal, 8).padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 7))
        .padding(.bottom, 2)
    }
}

/// 지금 걸려 있는 혜택을 종류별로 늘어놓는다. 각 항목에 설명 툴팁이 붙는다.
///
/// 혜택은 도감을 받을수록 늘어 일곱 종류까지 간다. 한 줄에 밀어 넣으면 글자가 항목 가운데서
/// 꺾여 옆 항목과 뒤섞이므로, 넘치면 줄을 늘린다. 각 항목은 알약으로 감싸 경계를 못 박는다 —
/// 구분점을 쓰면 줄이 끊기는 자리마다 점이 떠 버린다.
@MainActor
private struct DexPerkLine: View {
    let wallet: WalletStore
    let perks: DexPerks

    var body: some View {
        let l = wallet.l
        return WrapLayout(spacing: 5, lineSpacing: 3) {
            ForEach(DexPerkKind.allCases, id: \.self) { kind in
                if let text = l.dexPerkSummaryItem(kind, perks) {
                    Text(text)
                        .font(Typography.labelSemibold)
                        .foregroundStyle(Color.accentColor)
                        .fixedSize()
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(.background.opacity(0.65), in: Capsule())
                        // 감지 영역을 못 박는다. 커스텀 배치 안에서는 글자 모양만으로
                        // 영역이 잡히지 않아 마우스를 올려도 설명이 뜨지 않았다.
                        .contentShape(Capsule())
                        .help(l.dexPerkHelp(kind))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// 목록 한 줄 — 이름, 난이도, 구성 카드, 보상, 수령 버튼.
@MainActor
private struct DexRow: View {
    let wallet: WalletStore
    let index: CardIndex?
    let status: DexStatus
    /// 확정 카드를 받았을 때 알린다.
    var onGranted: ((DexClaim) -> Void)? = nil

    /// 한 줄에 넣는 카드 수와 폭. 줄 카드의 여백 안쪽에 맞춘 값이라 `CardGrid` 에서 온다 —
    /// 여기 숫자를 따로 적어 두었더니 팝오버를 넓힐 때 띠만 줄 밖으로 넘쳤다.
    static let columns = CardGrid.dexStrip.columns
    static let cardWidth: CGFloat = CardGrid.dexStrip.width
    /// 카드는 한 줄만 쓴다. 22개 도감이 저마다 여러 줄을 쓰면 목록을 훑을 수 없다.
    /// 넘치면 마지막 칸을 "+N" 으로 바꾼다 — 상위 등급부터 정렬돼 있어 앞이 남는다.
    static let maxShown = columns

    private var dex: Dex { status.dex }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            title
            dexValue
            if dex.kind == .set {
                // 284장을 띠로 늘어놓을 수 없다. 마일스톤 세 칸의 진행을 막대로 보인다.
                DexMilestoneBars(wallet: wallet, status: status)
            } else {
                DexCardStrip(wallet: wallet, index: index, cards: dex.cards,
                             limit: Self.maxShown, onTap: nil)
            }
            footer
        }
        .padding(.vertical, 8).padding(.horizontal, CardGrid.dexRowPadding)
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
                .font(Typography.bodySemibold).lineLimit(1)
            DexStars(tier: dex.tier)
            Spacer(minLength: 0)
            Text(status.claimed ? l.dexComplete : l.dexProgress(status.ownedCount, status.total))
                .font(Typography.body)
                .foregroundStyle(status.claimed ? .green : .secondary)
                .monospacedDigit()
        }
    }

    /// 이 도감에 든 카드값의 합. 난이도의 근거이므로 별 옆에 숫자로도 보여 준다.
    ///
    /// **세트 도감에는 적지 않는다.** 목표가 「전부」가 아니라 「몇 할」이라 그 합이 무엇의
    /// 값인지 말할 수 없고(값싼 것부터 세는 계산값이다), 어차피 무엇을 모으게 될지 고를 수
    /// 없으므로 판단에 쓰이지도 않는다.
    @ViewBuilder
    private var dexValue: some View {
        if dex.kind != .set, let prices = CardPrices.shared {
            Text(wallet.l.dexTotalValue(prices.formattedWithKRW(DexProgress.value(of: dex),
                                                           language: wallet.language)))
                .font(Typography.body).foregroundStyle(.tertiary)
                .lineLimit(1).minimumScaleFactor(0.8)
        }
    }

    /// 보상은 항상 보이고, 다 모으면 수령 버튼이 켜진다.
    private var footer: some View {
        HStack(spacing: 6) {
            DexRewardLine(wallet: wallet, index: index,
                          reward: status.reward(status.claimableStep
                                                ?? status.nextStep ?? status.steps.last ?? 0),
                          homeSet: dex.homeSet)
            Spacer(minLength: 0)
            DexClaimAction(wallet: wallet, status: status, onGranted: onGranted)
        }
    }
}

/// 보상 한 줄 — 통로를 성질 순으로 늘어놓는다. 각 항목에 설명 툴팁이 붙는다.
///
/// **영구 혜택을 앞에 둔다.** 남아 있는 곳은 손제작 도감과 완성 수 계단뿐이라 그것이 보이면
/// 특별한 도감이라는 뜻이다. 그 뒤로 확정 카드 · 부스터 · 스킨 · 토큰 · 팩 순이다.
@MainActor
struct DexRewardLine: View {
    let wallet: WalletStore
    let index: CardIndex?
    let reward: DexReward
    let homeSet: String

    var body: some View {
        let l = wallet.l
        return WrapLayout(spacing: 6, lineSpacing: 3) {
            ForEach(Array(reward.perks.enumerated()), id: \.offset) { _, perk in
                Text(l.dexPerkText(perk))
                    .font(Typography.labelSemibold)
                    .foregroundStyle(Color.accentColor)
                    .fixedSize().contentShape(Rectangle())
                    .help(l.dexPerkHelp(perk.kind))
            }
            if let card = reward.card {
                chip("sparkles", l.dexRewardCard(card.tierFloor), l.dexRewardCardHelp)
            }
            ForEach(Array(reward.coupons.enumerated()), id: \.offset) { _, coupon in
                chip("ticket.fill",
                     l.dexRewardCoupon(index?.set(homeSet)?.name ?? homeSet,
                                       Int((coupon.value * 100).rounded()), coupon.count),
                     l.dexCouponHelp)
            }
            if reward.tokens > 0 {
                chip("wonsign.circle.fill",
                     MarketEconomy.money(tokens: reward.tokens, language: wallet.language),
                     l.walletBalance)
            }
            if reward.packs > 0 {
                chip("shippingbox.fill", l.dexRewardPacks(reward.packs),
                     l.dexRewardPacksHelp(reward.packs,
                                          index?.set(homeSet)?.name ?? homeSet))
            }
        }
    }

    private func chip(_ symbol: String, _ text: String, _ help: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: symbol)
                .font(.system(size: 14)).foregroundStyle(.secondary)
            Text(text).font(Typography.labelSemibold)
        }
        .fixedSize().contentShape(Rectangle()).help(help)
    }
}

/// 세트 도감의 마일스톤 막대.
///
/// 칸마다 「몇 할 · 몇 종」과 수령 여부를 적는다. 목표가 「전부」가 아니라 「몇 할」이라
/// 빠진 카드 목록은 뜻을 갖지 않고, 284장을 띠로 보여 줄 화면도 없다.
@MainActor
private struct DexMilestoneBars: View {
    let wallet: WalletStore
    let status: DexStatus

    var body: some View {
        let l = wallet.l
        return VStack(alignment: .leading, spacing: 3) {
            ForEach(status.steps, id: \.self) { step in
                let need = status.need(step)
                let reached = status.isReached(step)
                let claimed = status.isClaimed(step)
                HStack(spacing: 6) {
                    Text(l.dexMilestone(Int((status.dex.milestones[safe: step]?.fraction ?? 1) * 100)))
                        .font(Typography.label)
                        .foregroundStyle(reached ? AnyShapeStyle(.primary)
                                                 : AnyShapeStyle(.secondary))
                        .frame(width: 74, alignment: .leading)
                    GeometryReader { geometry in
                        let filled = min(1, Double(status.ownedCount) / Double(max(1, need)))
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.secondary.opacity(0.18))
                            Capsule()
                                .fill(claimed ? Color.green : Color.accentColor)
                                .frame(width: geometry.size.width * filled)
                        }
                    }
                    .frame(height: 6)
                    Text(l.dexMilestoneNeed(need, status.total))
                        .font(Typography.label).foregroundStyle(.tertiary).monospacedDigit()
                        .fixedSize()
                    if claimed {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 13)).foregroundStyle(.green)
                    }
                }
            }
        }
    }
}

/// 수령 버튼 / 수령 완료 표시. 다 모으기 전에는 아무것도 두지 않는다.
@MainActor
private struct DexClaimAction: View {
    let wallet: WalletStore
    let status: DexStatus
    /// 확정 카드를 받았을 때 알린다. 화면이 그 카드를 뒤집어 보여 준다.
    var onGranted: ((DexClaim) -> Void)? = nil

    var body: some View {
        let l = wallet.l
        if let step = status.claimableStep {
            Button(l.dexClaim) {
                // 확정 카드를 받았으면 무엇이 나왔는지 보여 준다. 조용히 컬렉션에 넣으면
                // 「MUR 이상 1장」이라 적어 놓고 무엇을 줬는지 알 길이 없다.
                if let claim = wallet.claim(status.dex.id, step: step), claim.card != nil {
                    onGranted?(claim)
                }
            }
            .buttonStyle(.borderedProminent).font(Typography.button)
        } else if status.claimed {
            Label(l.dexClaimed, systemImage: "checkmark.circle.fill")
                .font(Typography.label).foregroundStyle(.green)
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
        return LazyVGrid(columns: CardGrid.dexStrip.items, alignment: .leading,
                         spacing: CardGrid.dexStrip.spacing) {
            ForEach(shown, id: \.self) { cardID in
                if let onTap {
                    Button { onTap(cardID) } label: { member(cardID) }
                        .buttonStyle(.plain)
                } else {
                    member(cardID)
                }
            }
            if hidden > 0 {
                // 카드 칸과 **같은 틀**로 쌓는다. 등급 줄을 빼면 이 칸만 낮아지고,
                // 격자는 낮은 칸을 줄 가운데에 놓으므로 혼자 아래로 내려가 보인다.
                VStack(spacing: 2) {
                    Text(verbatim: "+\(hidden)")
                        .font(Typography.bodySemibold).foregroundStyle(.secondary)
                        .frame(width: DexRow.cardWidth,
                               height: (DexRow.cardWidth / 0.717).rounded())
                        .background(Color.secondary.opacity(0.12),
                                    in: RoundedRectangle(cornerRadius: 4))
                    // 등급 줄 자리를 비워 둔다. 빈 글자라도 같은 글꼴이면 같은 높이다.
                    Text(verbatim: " ").font(.system(size: 13, weight: .heavy))
                }
            }
        }
    }

    private func member(_ cardID: String) -> some View {
        let owned = wallet.cardCount(cardID) > 0
        let entry = index?.card(cardID)
        return VStack(spacing: 2) {
            CardImageView(cardID: cardID, width: DexRow.cardWidth, dimmed: !owned)
            Text(entry.map { wallet.l.tierBadge($0.tier) } ?? "")
                .font(.system(size: 13, weight: .heavy))
                .foregroundStyle(entry.map { owned ? tierColor($0.tier) : Color.secondary }
                                 ?? Color.secondary)
                .opacity(owned ? 1 : 0.55)
        }
        .help(helpText(cardID, entry: entry, owned: owned))
    }

    /// 마우스를 올리면 카드 이름과, 없으면 한 팩에서 나올 확률을 알려 준다.
    private func helpText(_ cardID: String, entry: CardEntry?, owned: Bool) -> String {
        guard let entry else { return cardID }
        guard !owned, let index else { return entry.displayName(wallet.language) }
        let chance = DexDifficulty.pullProbability(cardID: cardID, index: index,
                                                   perks: wallet.perks)
        return "\(entry.displayName(wallet.language)) — \(wallet.l.dexPullChance(DexFormat.percent(chance)))"
    }
}

/// 도감 상세 — 설명, 구성 카드 전체, 보상, 뽑으러 가기.
@MainActor
private struct DexDetailView: View {
    let wallet: WalletStore
    let index: CardIndex?
    let dex: Dex
    /// 확정 카드를 받았을 때 알린다.
    var onGranted: ((DexClaim) -> Void)? = nil
    let onClose: () -> Void

    @Environment(PopoverNavigation.self) private var nav

    /// 크게 보고 있는 카드. 값이 있으면 카드 화면이 상세를 덮는다.
    @State private var spotlight: String?

    private var status: DexStatus {
        DexProgress.status(for: dex, owned: { wallet.cardCount($0) > 0 },
                           claimed: wallet.claimedDexIDs,
                           setCards: { index?.cards(inSet: $0) ?? [] })
    }

    var body: some View {
        if let spotlight, let entry = index?.card(spotlight) {
            CardSpotlightView(wallet: wallet, cardID: entry.id,
                              name: entry.displayName(wallet.language),
                              tier: entry.tier, setID: entry.setID,
                              setName: index?.set(entry.setID)?.name ?? entry.setID,
                              rarity: entry.rarity,
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
                BackButton(action: onClose, hint: l.close)
                Spacer()
            }

            VStack(spacing: 4) {
                Text(dex.name.text(wallet.language))
                    .font(Typography.heading)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 6) {
                    DexStars(tier: dex.tier)
                    Text(state.claimed ? l.dexComplete
                                       : l.dexProgress(state.ownedCount, state.total))
                        .font(Typography.bodySemibold)
                        .foregroundStyle(state.claimed ? .green : .secondary)
                        .monospacedDigit()
                }
                if dex.kind != .set, let prices = CardPrices.shared {
                    Text(wallet.l.dexTotalValue(prices.formattedWithKRW(DexProgress.value(of: dex),
                                                                   language: wallet.language)))
                        .font(Typography.title)
                        .foregroundStyle(Color.accentColor)
                        .lineLimit(1).minimumScaleFactor(0.8)
                }
                Text(dex.blurb.text(wallet.language))
                    .font(Typography.body).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 6)
            }
            .padding(.vertical, 8)

            ScrollView {
                if dex.kind == .set {
                    // 세트 도감은 목표가 「몇 할」이라 빠진 카드 목록이 뜻을 갖지 않는다.
                    // 칸마다 무엇이 걸려 있는지를 대신 늘어놓는다.
                    VStack(alignment: .leading, spacing: 8) {
                        DexMilestoneBars(wallet: wallet, status: state)
                        ForEach(state.steps, id: \.self) { step in
                            let reward = state.reward(step)
                            if !reward.isEmpty {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(l.dexMilestone(Int((dex.milestones[safe: step]?.fraction ?? 1) * 100)))
                                        .font(Typography.labelSemibold)
                                        .foregroundStyle(state.isClaimed(step) ? .green : .secondary)
                                    DexRewardLine(wallet: wallet, index: index,
                                                  reward: reward, homeSet: dex.homeSet)
                                }
                                .padding(.vertical, 5).padding(.horizontal, 8)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.secondary.opacity(0.07),
                                            in: RoundedRectangle(cornerRadius: 6))
                            }
                        }
                    }
                    .padding(.horizontal, 2)
                } else {
                    DexCardStrip(wallet: wallet, index: index, cards: dex.cards,
                                 limit: dex.cards.count) { spotlight = $0 }
                }
            }

            Spacer(minLength: 0)

            VStack(spacing: 6) {
                VStack(alignment: .leading, spacing: 3) {
                    if dex.kind != .set {
                        HStack(spacing: 6) {
                            DexRewardLine(wallet: wallet, index: index, reward: dex.reward,
                                          homeSet: dex.homeSet)
                            Spacer(minLength: 0)
                        }
                    }
                    // 상세에서는 혜택 뜻을 **보이는 글자로** 적는다. 마우스를 올려야만
                    // 알 수 있으면 「판매 추가금 +2.5%」가 무슨 말인지 알 길이 없다.
                    ForEach(Array(dex.reward.perks.enumerated()), id: \.offset) { _, perk in
                        Text(l.dexPerkHelp(perk.kind))
                            .font(Typography.caption).foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.vertical, 4).padding(.horizontal, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 6))

                HStack(spacing: 8) {
                    DexClaimAction(wallet: wallet, status: state, onGranted: onGranted)
                    if !state.isFilled {
                        Button {
                            nav.shopSet = dex.homeSet
                            nav.tab = .shop
                        } label: {
                            Label(l.dexGoBuyPack, systemImage: "cart").font(Typography.button)
                        }
                        .buttonStyle(.bordered)
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
                    .font(.system(size: 13.5))
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
