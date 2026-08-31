import SwiftUI

/// 팩 — 미개봉 팩 목록과 개봉.
///
/// 개봉 연출을 모달로 띄우지 않는다. 팝오버가 닫힐 때 남는 고아 시트가 이후 클릭을
/// 먹통으로 만드는 결함이 있어, 같은 자리에서 화면 상태만 바꾼다.
@MainActor
struct PacksView: View {
    let wallet: WalletStore
    let index: CardIndex?

    /// 개봉 결과. 값이 있으면 목록 대신 결과를 보여준다.
    @State private var opened: OpenedPack?
    /// 이미지를 받는 중. 카드는 이미 정해졌고 그림만 기다린다.
    @State private var preparing: PendingPack?

    struct PendingPack: Identifiable {
        let id = UUID()
        let setID: String
        let setName: String
        let cards: [PulledCard]
        /// 전 칸이 레어 이상으로 나온 팩. 대기 화면과 개봉 화면이 다르게 움직인다.
        let isGodPack: Bool
        /// 이 개봉으로 새로 완성된 도감. 요약 화면에서 알린다.
        let completions: [DexCompletion]
    }

    struct OpenedPack: Identifiable {
        let id: UUID
        let setName: String
        let cards: [PulledCard]
        /// 미리 받아 둔 그림. 표시 시점에 네트워크를 타지 않는다.
        let hires: [String: NSImage]
        let thumbs: [String: NSImage]
        let isGodPack: Bool
        let completions: [DexCompletion]
    }

    var body: some View {
        Group {
            if let opened {
                RevealView(wallet: wallet, index: index, opened: opened) { self.opened = nil }
            } else if let preparing {
                PreparingView(wallet: wallet, pending: preparing) { loaded in
                    opened = loaded
                    self.preparing = nil
                }
            } else if wallet.ownedPacks.isEmpty {
                emptyState
            } else {
                packList
            }
        }
        .frame(height: PopoverMetrics.tabHeight)
    }

    private var emptyState: some View {
        let l = wallet.l
        return VStack(spacing: 8) {
            Image(systemName: "shippingbox")
                .font(.system(size: 40)).foregroundStyle(.tertiary)
            Text(l.packsEmptyTitle).font(Typography.title)
            Text(l.packsEmptyHint)
                .font(Typography.body).foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var packList: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(wallet.ownedPacks, id: \.setID) { entry in
                    if let index, let set = index.set(entry.setID) {
                        OwnedPackRow(wallet: wallet, index: index, set: set, count: entry.count) {
                            open(set: set, index: index)
                        }
                    }
                }
            }
        }
    }

    private func open(set: CardSet, index: CardIndex) {
        // 보유량을 먼저 줄인다. 뽑기가 먼저면 실패 시 팩이 사라진 채 카드도 없는 상태가 된다.
        guard wallet.consumePack(setID: set.id) else { return }
        var generator = SystemRandomNumberGenerator()
        let owned = Set(wallet.state.cards.keys)
        var pity = wallet.pity(setID: set.id)
        let pulled = PackOpening.draw(setID: set.id, index: index, alreadyOwned: owned,
                                      perks: wallet.perks, pity: &pity, using: &generator)
        wallet.setPity(pity, setID: set.id)
        // 수집이 도감 완성까지 처리하고 그 목록을 돌려준다.
        let completions = wallet.collect(pulled.cards.map(\.id))
        // 카드는 이미 들어갔지만 머리글의 컬렉션 가치는 뒤집은 만큼만 올린다 —
        // 값이 먼저 오르면 무엇이 나왔는지 카드를 보기 전에 알게 된다.
        wallet.holdForReveal(pulled.cards.map(\.id))
        preparing = PendingPack(setID: set.id, setName: set.name,
                                cards: PackOpening.revealOrder(pulled.cards),
                                isGodPack: pulled.isGodPack,
                                completions: completions)
    }
}

/// 개봉 직전 — 카드 그림을 미리 받는다.
///
/// 한 장씩 0.5초로 넘기는데 그때 받기 시작하면 시간 안에 못 끝나 빈 자리만 지나간다.
/// 최소 1초는 이 화면을 유지한다. 더 빨리 끝나도 곧바로 넘기면 깜빡임으로 보인다.
@MainActor
private struct PreparingView: View {
    let wallet: WalletStore
    let pending: PacksView.PendingPack
    let onReady: (PacksView.OpenedPack) -> Void

    private static let minimumDisplay = Duration.milliseconds(1000)

    /// 갓팩일 때 부풀어 오르는 빛. 대기 화면에서 미리 터뜨려 개봉 전에 알린다 —
    /// 카드가 다 지나간 뒤에 알면 기대할 시간이 없다.
    @State private var glow = false

    var body: some View {
        let l = wallet.l
        let god = pending.isGodPack
        return VStack(spacing: 12) {
            Spacer(minLength: 0)
            // 기다리는 동안 무엇을 뜯고 있는지 보여준다. 팩 아트는 상점에서 이미 받아 둔
            // 경우가 많아 여기서는 대개 즉시 뜬다.
            PackImageView(setID: pending.setID, width: 150)
                .shadow(radius: 8, y: 3)
                .background {
                    if god {
                        RoundedRectangle(cornerRadius: 24)
                            .fill(Color.orange)
                            .blur(radius: 44)
                            .opacity(glow ? 0.85 : 0.2)
                            .scaleEffect(glow ? 1.2 : 0.8)
                    }
                }
                .scaleEffect(god && glow ? 1.06 : 1)
            VStack(spacing: 3) {
                if god {
                    Text(l.godPackTitle)
                        .font(Typography.display)
                        .foregroundStyle(Color.orange)
                    Text(l.godPackHint).font(Typography.body).foregroundStyle(.secondary)
                } else {
                    Text(l.packPreparing).font(Typography.title)
                    Text(pending.setName).font(Typography.body).foregroundStyle(.secondary)
                }
            }
            ProgressView().controlSize(.small)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            guard god else { return }
            withAnimation(.easeOut(duration: 0.7).repeatForever(autoreverses: true)) {
                glow = true
            }
        }
        .task(id: pending.id) {
            let ids = pending.cards.map(\.id)
            // 큰 그림과 요약용 작은 그림을 함께 받는다. 요약에서 또 기다리지 않게 한다.
            async let hires = CardImageLoader.prefetch(cardIDs: ids, hires: true)
            async let thumbs = CardImageLoader.prefetch(cardIDs: ids, hires: false)
            async let floor: Void = { try? await Task.sleep(for: Self.minimumDisplay) }()

            let (big, small, _) = await (hires, thumbs, floor)
            guard !Task.isCancelled else { return }
            onReady(PacksView.OpenedPack(id: pending.id, setName: pending.setName,
                                         cards: pending.cards, hires: big, thumbs: small,
                                         isGodPack: pending.isGodPack,
                                         completions: pending.completions))
        }
    }
}

/// 보유 팩 1줄.
@MainActor
private struct OwnedPackRow: View {
    let wallet: WalletStore
    let index: CardIndex
    let set: CardSet
    let count: Int
    let onOpen: () -> Void

    var body: some View {
        let l = wallet.l
        HStack(spacing: 10) {
            PackImageView(setID: set.id, width: 34)
            VStack(alignment: .leading, spacing: 2) {
                Text(l.packName(set.name))
                    .font(Typography.title)
                    .fixedSize(horizontal: false, vertical: true)
                Text("\(l.packContents(PackPricing.cardCount(setID: set.id, index: index, perks: wallet.perks)))  ·  ×\(count)")
                    .font(Typography.body).foregroundStyle(.secondary).monospacedDigit()
            }
            Spacer(minLength: 0)
            Button(l.openPack, action: onOpen)
                .buttonStyle(.borderedProminent).font(Typography.button)
        }
        .padding(10)
        .background(Color.secondary.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

/// 개봉 결과 — 한 장씩 크게 보여준다.
///
/// 넘기는 것은 사용자가 한다. 자동으로 흘러가면 카드를 보기도 전에 지나가고,
/// 뜯는 맛도 없다. 카드를 누르거나 끌어서 넘긴다 — 넘기기 버튼은 두지 않는다.
@MainActor
private struct RevealView: View {
    let wallet: WalletStore
    let index: CardIndex?
    let opened: PacksView.OpenedPack
    let onDone: () -> Void

    /// 지금 보고 있는 장 번호. 카드 수와 같아지면 요약으로 넘어간다.
    @State private var position = 0
    /// 결과 화면에서 크게 보고 있는 카드.
    @State private var spotlight: PulledCard?

    private var isSummary: Bool { position >= opened.cards.count }
    private var newCount: Int { opened.cards.filter(\.isNew).count }

    var body: some View {
        VStack(spacing: 8) {
            if let focused = spotlight {
                CardSpotlightView(wallet: wallet, cardID: focused.id,
                                  name: index?.card(focused.id)?.displayName(wallet.language) ?? focused.id,
                                  tier: focused.tier,
                                  setID: index?.card(focused.id)?.setID ?? "",
                                  setName: opened.setName,
                                  ownedCount: wallet.cardCount(focused.id),
                                  preloaded: opened.hires[focused.id]) {
                    spotlight = nil
                }
            } else if isSummary {
                summary
            } else {
                current
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onChange(of: opened.id) { position = 0 }
        // 연출을 끝까지 보지 않고 화면을 벗어나도 값은 제자리로 돌아와야 한다 —
        // 감춘 채로 남으면 가진 것보다 적게 표시된다.
        .onDisappear { wallet.markAllRevealed() }
    }

    /// 다음 장으로. **카드끼리 넘어갈 때는 애니메이션 트랜잭션을 열지 않는다.**
    ///
    /// `SpotlightCard` 는 `.id(card.id)` 로 매번 새로 만들어진다. 그 교체를 애니메이션 안에서
    /// 하면 SwiftUI 가 기본 전환(페이드)을 걸어, 나가는 카드와 들어오는 카드가 동시에 반투명해
    /// 지면서 밑장이 비쳐 보인다 — 카드가 커질 때 깜빡이는 것처럼 보이던 것이 이것이다.
    /// 올라오는 움직임은 카드 자신의 `onAppear` 스프링이 맡으므로 여기서 열 이유가 없다.
    ///
    /// 마지막 장에서 요약으로 넘어갈 때만 화면이 통째로 바뀌므로 그때는 애니메이션을 준다.
    private func advance() {
        // 방금 본 장을 컬렉션 가치에 얹는다. 넘긴 뒤에 올려야 머리글이 카드보다 앞서지 않는다.
        wallet.markRevealed(opened.cards[min(position, opened.cards.count - 1)].id)
        if position + 1 >= opened.cards.count {
            wallet.markAllRevealed()
            withAnimation(.easeOut(duration: 0.22)) { position += 1 }
        } else {
            position += 1
        }
    }

    /// 한번에 열기 — 남은 카드를 한 장씩 넘기지 않고 결과 화면으로 바로 간다.
    ///
    /// 예전에는 1초에 한 장씩 자동으로 넘겼다. 그러면 열 장을 다 볼 때까지 10초를 기다려야
    /// 하고, 그동안 할 수 있는 것도 없다. 결과를 보고 싶다는 뜻이니 결과를 바로 준다.
    private func skipToSummary() {
        // 요약이 열 장을 한꺼번에 보여 주므로 값도 한꺼번에 올린다.
        wallet.markAllRevealed()
        withAnimation(.easeOut(duration: 0.22)) { position = opened.cards.count }
    }

    // MARK: 한 장씩

    /// 카드 아래 정보. 등급만 있으면 무엇을 뽑았는지가 배지 한 글자에 달린다 —
    /// 이름과 값까지 있어야 이 카드가 무엇인지, 얼마짜리인지 그 자리에서 읽힌다.
    @ViewBuilder
    private func revealInfo(_ l: L, card: PulledCard) -> some View {
        VStack(spacing: 3) {
            Text(index?.card(card.id)?.displayName(wallet.language) ?? card.id)
                .font(Typography.title)
                .lineLimit(1).minimumScaleFactor(0.7)
            HStack(spacing: 5) {
                Text(l.tierBadge(card.tier))
                    .font(Typography.badge)
                    .foregroundStyle(tierColor(card.tier))
                Text(l.tierName(card.tier)).font(Typography.label).foregroundStyle(.secondary)
                if let prices = CardPrices.shared, let usd = prices.price(card.id) {
                    Text("·").font(Typography.label).foregroundStyle(.tertiary)
                    Text(prices.formattedWithKRW(usd, language: wallet.language))
                        .font(Typography.labelSemibold).monospacedDigit()
                        .foregroundStyle(Color.accentColor)
                }
            }
            .lineLimit(1).minimumScaleFactor(0.8)
        }
    }

    /// 다음 장. 마지막 장에서는 없다 — 밑에 깔 것이 없다.
    private var nextCard: PulledCard? {
        position + 1 < opened.cards.count ? opened.cards[position + 1] : nil
    }

    private var current: some View {
        let l = wallet.l
        let card = opened.cards[min(position, opened.cards.count - 1)]
        let isLast = position + 1 >= opened.cards.count
        return VStack(spacing: 8) {
            HStack {
                if opened.isGodPack {
                    Text(l.godPackBadge)
                        .font(.system(size: 14, weight: .heavy))
                        .padding(.horizontal, 5).padding(.vertical, 2)
                        .background(Color.orange, in: Capsule())
                        .foregroundStyle(.white)
                }
                Text(opened.setName).font(Typography.body).foregroundStyle(.secondary).lineLimit(1)
                Spacer()
                Text("\(position + 1) / \(opened.cards.count)")
                    .font(Typography.bodySemibold).foregroundStyle(.secondary).monospacedDigit()
            }

            Spacer(minLength: 0)

            RevealStack(card: card,
                        next: nextCard,
                        newBadge: l.newCardBadge,
                        preloaded: opened.hires[card.id],
                        nextPreloaded: nextCard.map { opened.hires[$0.id] } ?? nil,
                        onAdvance: advance)

            revealInfo(l, card: card)

            Spacer(minLength: 0)

            // 마지막 장에는 누를 것이 없다 — 카드를 넘기면 결과로 간다.
            // 자리는 남겨 둔다. 버튼이 사라지면 카드가 아래로 내려앉아 흔들린다.
            Button(l.openAll, action: skipToSummary)
                .buttonStyle(.bordered).font(Typography.button)
                .opacity(isLast ? 0 : 1)
                .disabled(isLast)
                .accessibilityHidden(isLast)
        }
        .padding(.vertical, 2)
    }

    // MARK: 요약

    private var summary: some View {
        let l = wallet.l
        return VStack(spacing: 8) {
            VStack(spacing: 2) {
                Text(opened.isGodPack ? l.godPackTitle : l.packOpened)
                    .font(opened.isGodPack ? Typography.badgeLarge : Typography.title)
                    .foregroundStyle(opened.isGodPack ? Color.orange : Color.primary)
                Text("\(opened.setName)  ·  \(l.packOpenSummary(new: newCount, total: opened.cards.count))")
                    .font(Typography.body).foregroundStyle(.secondary)
                // 무엇이 나왔는지는 카드 그림이 말해 주지만, 얼마어치가 나왔는지는 숫자로만
                // 알 수 있다. 팩값과 나란히 놓고 보라고 여기 둔다.
                if let prices = CardPrices.shared {
                    let worth = opened.cards.reduce(0.0) {
                        $0 + MarketEconomy.usd(cardID: $1.id, prices: prices)
                    }
                    Text(l.packTotalValue(prices.formattedWithKRW(worth,
                                                                  language: wallet.language)))
                        .font(Typography.amount).monospacedDigit()
                        .foregroundStyle(Color.accentColor)
                        .lineLimit(1).minimumScaleFactor(0.8)
                        .padding(.top, 1)
                }
            }
            .padding(.top, 2)

            // 우연히 완성된 도감을 이 자리에서 알린다. 나중에 도감 탭을 열어야 알게 되면
            // 개봉과 완성이 이어지지 않아 "우연히 됐네" 가 성립하지 않는다.
            if !opened.completions.isEmpty {
                VStack(spacing: 4) {
                    ForEach(opened.completions) { done in
                        DexCompletionBanner(wallet: wallet, completion: done)
                    }
                }
            }

            // 스크롤로 감싸지 않는다. 열 장이 두 줄로 들어가므로 감쌀 이유가 없고,
            // 감싸면 결과를 다 보려고 굴려야 한다.
            LazyVGrid(columns: CardGrid.packSummary.items,
                      spacing: CardGrid.packSummary.spacing) {
                // 요약은 희귀한 것부터 — 무엇을 건졌는지 먼저 보인다.
                ForEach(Array(opened.cards.reversed().enumerated()), id: \.offset) { _, card in
                    Button { spotlight = card } label: {
                        PulledCardCell(wallet: wallet, card: card, preloaded: opened.thumbs[card.id])
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 2)

            Spacer(minLength: 0)

            Button(l.done, action: onDone)
                .buttonStyle(.borderedProminent).font(Typography.button)
                .padding(.bottom, 2)
        }
    }
}

/// 한 장씩 넘기는 자리. 카드를 누르거나 끌어서 넘긴다.
///
/// **다음 장이 실제로 이 카드 밑에 깔려 있다.** 위 카드를 끌어 올리면 가려져 있던 만큼
/// 그대로 드러난다 — 실물 덱에서 맨 위 카드를 들춰 다음 장을 훔쳐보는 그 동작이다.
/// 빛만 비추던 이전 방식은 무엇이 오는지가 아니라 등급만 알려 줘서 들춰 볼 이유가 약했다.
///
/// 밑장은 조금 작게, 살짝 아래로 내려 깔고 어둡게 둔다. 같은 자리에 같은 크기로 두면
/// 가만히 있을 때 카드가 한 장인지 여러 장인지 구분되지 않는다. 들출수록 밝아져
/// 올라오는 카드가 된다.
@MainActor
private struct RevealStack: View {
    let card: PulledCard
    let next: PulledCard?
    let newBadge: String
    let preloaded: NSImage?
    /// 다음 장의 그림. 개봉 준비 단계에서 이미 받아 둔 것이라 들출 때 기다릴 것이 없다.
    let nextPreloaded: NSImage?
    let onAdvance: () -> Void

    @State private var drag: CGSize = .zero

    /// 얼마나 들췄는가(0~1). 밑장의 밝기와 후광, 위 카드의 그림자에 함께 쓴다.
    private var peek: Double { RevealPeek.amount(drag) }

    var body: some View {
        ZStack {
            if let next {
                ZStack {
                    TierGlow(tier: next.tier, width: RevealPeek.cardWidth).opacity(peek)
                    CardImageView(cardID: next.id, hires: true, width: RevealPeek.cardWidth,
                                  preloaded: nextPreloaded)
                }
                .scaleEffect(RevealPeek.deckScale)
                .offset(y: RevealPeek.deckOffset)
                // 덮여 있는 동안은 그늘에 있다. 들어 올릴수록 제 색을 찾는다.
                .brightness(-0.16 * (1 - peek))
                .allowsHitTesting(false)
            }
            SpotlightCard(card: card, newBadge: newBadge, preloaded: preloaded)
                // 카드가 바뀔 때마다 뷰를 새로 만든다 — 첫 장을 포함해 매번 등장 애니메이션이 돈다.
                .id(card.id)
                // 교체는 즉시. 기본 전환(페이드)이 걸리면 두 장이 겹쳐 반투명해진다.
                .transition(.identity)
                .offset(drag)
                .rotationEffect(.degrees(RevealPeek.tilt(drag)), anchor: .bottom)
                // 가만히 있어도 옅은 그림자를 남긴다 — 밑장과 겹쳐 보이지 않게 하는 층 표시다.
                .shadow(color: .black.opacity(0.18 + 0.24 * peek),
                        radius: 4 + 9 * peek, y: 2 + 5 * peek)
        }
        .contentShape(Rectangle())
        // 누르면 바로 넘어간다. 끌기에 최소 거리를 두었으므로 탭과 부딪히지 않는다.
        .onTapGesture(perform: advance)
        .gesture(
            DragGesture(minimumDistance: 6)
                .onChanged { drag = $0.translation }
                .onEnded { value in
                    if RevealPeek.advances(value.translation) {
                        advance()
                    } else {
                        // 덜 들췄으면 제자리로. 다음 장 빛도 함께 사그라든다.
                        withAnimation(.spring(response: 0.32, dampingFraction: 0.7)) {
                            drag = .zero
                        }
                    }
                }
        )
    }

    private func advance() {
        drag = .zero
        onAdvance()
    }
}

/// 한 장씩 보여줄 때의 카드. 밑장 자리에서 제자리로 올라온다.
///
/// 예전에는 0.86 배에서 부풀어 올랐다. 밑장을 실제로 깔아 두게 되면서 그 연출이 어긋났다 —
/// 눈에 보이던 밑장이 사라졌다가 엉뚱한 크기로 다시 튀어나오는 것처럼 보인다. 그래서
/// 시작 위치를 밑장이 놓여 있던 자리(`RevealPeek.deckScale`·`deckOffset`)로 맞췄다.
///
/// 별도 뷰로 둔 이유는 첫 장 때문이다. 바깥에서 transition 만 걸면 이미 자리에 있는
/// 첫 장은 상태 변화가 없어 애니메이션이 돌지 않는다. 뷰가 새로 생기면서
/// onAppear 가 도는 구조라야 매 장이 같게 등장한다.
@MainActor
private struct SpotlightCard: View {
    let card: PulledCard
    let newBadge: String
    let preloaded: NSImage?

    @State private var landed = false

    var body: some View {
        ZStack(alignment: .topTrailing) {
            TierGlow(tier: card.tier, width: RevealPeek.cardWidth)
            CardImageView(cardID: card.id, hires: true, width: RevealPeek.cardWidth,
                          preloaded: preloaded)
            if card.isNew {
                NewBadge(text: newBadge)
                    .padding(5)
            }
        }
        .scaleEffect(landed ? 1 : RevealPeek.deckScale)
        .offset(y: landed ? 0 : RevealPeek.deckOffset)
        .onAppear {
            withAnimation(.spring(response: 0.34, dampingFraction: 0.7)) { landed = true }
        }
    }
}

/// 도감 완성 알림. 개봉 요약 위에 붙는다.
///
/// 어려운 것을 위에 둔다(`DexProgress.newlyCompleted` 가 그 순서로 준다) —
/// 쉬운 것 여러 개에 묻히면 힘들게 완성한 것이 눈에 안 들어온다.
@MainActor
private struct DexCompletionBanner: View {
    let wallet: WalletStore
    let completion: DexCompletion

    @State private var landed = false

    var body: some View {
        let l = wallet.l
        HStack(spacing: 6) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 17)).foregroundStyle(Color.accentColor)
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 5) {
                    Text(completion.name.text(wallet.language))
                        .font(Typography.bodySemibold).lineLimit(1)
                    DexStars(tier: completion.tier)
                }
                Text(l.dexCompletedBanner)
                    .font(Typography.label).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 5).padding(.horizontal, 8)
        .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 7))
        .scaleEffect(landed ? 1 : 0.94)
        .opacity(landed ? 1 : 0)
        .onAppear {
            withAnimation(.spring(response: 0.34, dampingFraction: 0.72)) { landed = true }
        }
    }
}

/// 새로 얻은 카드 표시. 카드 안쪽 모서리에 붙인다 —
/// 바깥으로 내밀면 격자에서 위가 잘린다.
@MainActor
struct NewBadge: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.system(size: 13, weight: .heavy))
            .padding(.horizontal, 4).padding(.vertical, 1.5)
            .background(Color.accentColor, in: Capsule())
            .foregroundStyle(.white)
    }
}

/// 카드를 들췄을 때의 반응. 순수 계산만 모아 둔다 — 이 값들이 손맛을 결정하므로
/// 테스트로 못박는다.
///
/// 거리는 가로·세로를 합친 크기로 잰다. 가로만 보면 위로 들춰 보는 동작이 먹지 않고,
/// 실물 카드깡에서 카드를 들추는 방향은 사람마다 다르다.
enum RevealPeek {
    /// 넘어가는 데 필요한 이동 거리(pt). 짧으면 훔쳐보려다 넘어가고,
    /// 길면 카드가 손에 붙어 안 떨어진다.
    static let threshold: CGFloat = 62
    /// 손을 따라 기울어지는 정도의 한계. 밑변을 축으로 돌려 들어 올리는 느낌을 준다.
    static let maxTilt = 11.0
    /// 가로 이동 몇 pt 마다 1도씩 기울일지.
    static let tiltPerPoint = 16.0

    static func distance(_ translation: CGSize) -> CGFloat {
        (translation.width * translation.width
            + translation.height * translation.height).squareRoot()
    }

    /// 들춘 정도(0~1). 문턱을 넘으면 1 에서 멈춘다 — 더 끌어도 빛이 더 세지지는 않는다.
    static func amount(_ translation: CGSize) -> Double {
        min(1, max(0, Double(distance(translation)) / Double(threshold)))
    }

    static func tilt(_ translation: CGSize) -> Double {
        max(-maxTilt, min(maxTilt, Double(translation.width) / tiltPerPoint))
    }

    static func advances(_ translation: CGSize) -> Bool {
        distance(translation) >= threshold
    }

    /// 개봉 화면에서 카드를 그리는 폭(pt).
    ///
    /// 탭 높이(`PopoverMetrics.tabHeight`) 안에서 머리글·이름·등급·값·버튼·여백이 130pt
    /// 남짓을 쓰고, 밑장이 7pt 더 삐져나온다. 남는 세로를 카드가 다 먹으면 위아래가
    /// 답답해지므로 45pt 정도를 남긴 값이다.
    static let cardWidth: CGFloat = 260

    // MARK: 덱 — 밑에 깔리는 다음 장

    /// 밑장을 아래로 내리는 정도(pt).
    static let deckOffset: CGFloat = 10
    /// 밑장을 줄이는 비율. 조금 작아야 뒤에 있는 것으로 읽힌다.
    static let deckScale = 0.98

    /// 가만히 있을 때 밑장이 아래로 삐져나오는 높이(pt).
    ///
    /// 줄인 만큼 아래 모서리가 올라오므로 내린 거리에서 그것을 빼야 한다. 이 값이 0 에
    /// 가까워지면 카드가 한 장인지 덱인지 구분되지 않는다 — 실제로 그렇게 보인다는 지적을
    /// 받고 고친 자리다.
    static func visibleDeckEdge(cardWidth: CGFloat, aspect: CGFloat = 0.717) -> CGFloat {
        let height = cardWidth / aspect
        return deckOffset - height * (1 - deckScale) / 2
    }
}

/// 카드 뒤에서 은은하게 퍼지는 등급 후광.
///
/// 등급 배지를 읽지 않아도 무엇이 나왔는지 알 수 있게 하는 장치다.
/// 낮은 등급은 거의 보이지 않고, 높을수록 넓고 진하게 퍼진다.
@MainActor
struct TierGlow: View {
    let tier: CardTier
    let width: CGFloat

    /// 카드가 나타난 뒤 빛이 퍼지도록 한 번만 부풀린다.
    @State private var bloomed = false

    var body: some View {
        let color = tierColor(tier)
        let strength = Self.strength(for: tier)
        ZStack {
            // 바깥 — 넓게 번지는 빛
            RoundedRectangle(cornerRadius: width * 0.09)
                .fill(color)
                .blur(radius: width * 0.20)
                .opacity(strength * 0.55)
                .scaleEffect(bloomed ? 1.16 : 0.97)
            // 안쪽 — 카드 가장자리에 붙는 빛
            RoundedRectangle(cornerRadius: width * 0.06)
                .fill(color)
                .blur(radius: width * 0.07)
                .opacity(strength * 0.85)
                .scaleEffect(bloomed ? 1.05 : 0.97)
        }
        .frame(width: width, height: (width / 0.717).rounded())
        // 후광은 장식이라 보조기술이 읽을 것이 없다. 등급은 배지와 이름이 따로 알린다.
        .accessibilityHidden(true)
        .onAppear {
            withAnimation(.easeOut(duration: 0.45)) { bloomed = true }
        }
    }

    /// 등급별 세기(0~1). 커먼과 에너지는 거의 보이지 않아야 한다 —
    /// 흔한 카드까지 빛나면 빛이 등급 신호로 작동하지 않는다.
    static func strength(for tier: CardTier) -> Double {
        switch tier {
        case .energy, .common: return 0.0
        case .uncommon:        return 0.18
        case .rare:            return 0.34
        case .doubleRare:      return 0.52
        case .tripleRare:      return 0.66
        case .artRare:         return 0.74
        case .superRare:       return 0.84
        case .specialArtRare:  return 0.92
        case .ultraRare:       return 1.0
        }
    }
}

@MainActor
private struct PulledCardCell: View {
    let wallet: WalletStore
    let card: PulledCard
    var preloaded: NSImage?

    var body: some View {
        VStack(spacing: 3) {
            ZStack(alignment: .topTrailing) {
                CardImageView(cardID: card.id, width: CardGrid.packSummary.width, preloaded: preloaded)
                if card.isNew {
                    // 카드 안쪽에 붙인다. 바깥으로 내밀면 격자 경계에서 위가 잘린다.
                    NewBadge(text: wallet.l.newCardBadge).padding(3)
                }
            }
            Text(wallet.l.tierBadge(card.tier))
                .font(.system(size: 14, weight: .heavy))
                .foregroundStyle(tierColor(card.tier))
        }
    }
}

/// 등급 색. 위로 갈수록 눈에 띄게 한다.
func tierColor(_ tier: CardTier) -> Color {
    switch tier {
    case .energy:         return .gray
    case .common:         return .secondary
    case .uncommon:       return .green
    case .rare:           return .blue
    case .doubleRare:     return .indigo
    case .tripleRare:     return .purple
    case .artRare:        return .teal
    case .superRare:      return .orange
    case .specialArtRare: return .pink
    case .ultraRare:      return .yellow
    }
}
