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
    }

    struct OpenedPack: Identifiable {
        let id: UUID
        let setName: String
        let cards: [PulledCard]
        /// 미리 받아 둔 그림. 표시 시점에 네트워크를 타지 않는다.
        let hires: [String: NSImage]
        let thumbs: [String: NSImage]
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
        .frame(height: 470)
    }

    private var emptyState: some View {
        let l = wallet.l
        return VStack(spacing: 8) {
            Image(systemName: "shippingbox")
                .font(.system(size: 40)).foregroundStyle(.tertiary)
            Text(l.packsEmptyTitle).font(.callout.weight(.semibold))
            Text(l.packsEmptyHint)
                .font(.caption).foregroundStyle(.secondary)
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
        let pulled = PackOpening.draw(setID: set.id, index: index,
                                      alreadyOwned: owned, using: &generator)
        wallet.collect(pulled.map(\.id))
        preparing = PendingPack(setID: set.id, setName: set.name,
                                cards: PackOpening.revealOrder(pulled))
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

    var body: some View {
        VStack(spacing: 12) {
            Spacer(minLength: 0)
            // 기다리는 동안 무엇을 뜯고 있는지 보여준다. 팩 아트는 상점에서 이미 받아 둔
            // 경우가 많아 여기서는 대개 즉시 뜬다.
            PackImageView(setID: pending.setID, width: 150)
                .shadow(radius: 8, y: 3)
            VStack(spacing: 3) {
                Text(wallet.l.packPreparing).font(.callout.weight(.semibold))
                Text(pending.setName).font(.caption).foregroundStyle(.secondary)
            }
            ProgressView().controlSize(.small)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task(id: pending.id) {
            let ids = pending.cards.map(\.id)
            // 큰 그림과 요약용 작은 그림을 함께 받는다. 요약에서 또 기다리지 않게 한다.
            async let hires = CardImageLoader.prefetch(cardIDs: ids, hires: true)
            async let thumbs = CardImageLoader.prefetch(cardIDs: ids, hires: false)
            async let floor: Void = { try? await Task.sleep(for: Self.minimumDisplay) }()

            let (big, small, _) = await (hires, thumbs, floor)
            guard !Task.isCancelled else { return }
            onReady(PacksView.OpenedPack(id: pending.id, setName: pending.setName,
                                         cards: pending.cards, hires: big, thumbs: small))
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
                    .font(.callout.weight(.semibold))
                    .fixedSize(horizontal: false, vertical: true)
                Text("\(l.packContents(PackPricing.cardCount(setID: set.id, index: index)))  ·  ×\(count)")
                    .font(.caption).foregroundStyle(.secondary).monospacedDigit()
            }
            Spacer(minLength: 0)
            Button(l.openPack, action: onOpen)
                .buttonStyle(.borderedProminent).controlSize(.small)
        }
        .padding(10)
        .background(Color.secondary.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

/// 개봉 결과 — 한 장씩 크게 보여준다.
///
/// 넘기는 것은 사용자가 한다. 자동으로 흘러가면 카드를 보기도 전에 지나가고,
/// 뜯는 맛도 없다. 카드를 누르거나 아래 버튼을 누르면 다음 장이 나온다.
@MainActor
private struct RevealView: View {
    let wallet: WalletStore
    let index: CardIndex?
    let opened: PacksView.OpenedPack
    let onDone: () -> Void

    /// 지금 보고 있는 장 번호. 카드 수와 같아지면 요약으로 넘어간다.
    @State private var position = 0
    /// 한번에 열기로 도는 작업. 사용자가 직접 넘기면 취소한다.
    @State private var autoPlay: Task<Void, Never>?
    /// 결과 화면에서 크게 보고 있는 카드.
    @State private var spotlight: PulledCard?

    private var isSummary: Bool { position >= opened.cards.count }
    private var newCount: Int { opened.cards.filter(\.isNew).count }

    var body: some View {
        VStack(spacing: 8) {
            if let focused = spotlight {
                CardSpotlightView(wallet: wallet, cardID: focused.id,
                                  name: index?.card(focused.id)?.name ?? focused.id,
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
        .onChange(of: opened.id) {
            autoPlay?.cancel()
            autoPlay = nil
            position = 0
        }
        .onDisappear { autoPlay?.cancel() }
    }

    /// 직접 넘긴다. 자동 재생 중이었다면 멈춘다 — 둘이 함께 위치를 밀면 카드를 건너뛴다.
    private func advance() {
        autoPlay?.cancel()
        autoPlay = nil
        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) { position += 1 }
    }

    /// 남은 카드를 끝까지 자동으로 넘긴다. 등급이 높을수록 오래 머문다.
    private func openAll() {
        autoPlay?.cancel()
        autoPlay = Task { @MainActor in
            while position < opened.cards.count {
                try? await Task.sleep(for: RevealTiming.hold)
                if Task.isCancelled { return }
                withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) { position += 1 }
            }
            autoPlay = nil
        }
    }

    // MARK: 한 장씩

    private var current: some View {
        let l = wallet.l
        let card = opened.cards[min(position, opened.cards.count - 1)]
        let isLast = position + 1 >= opened.cards.count
        return VStack(spacing: 8) {
            HStack {
                Text(opened.setName).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                Spacer()
                Text("\(position + 1) / \(opened.cards.count)")
                    .font(.caption.weight(.semibold)).foregroundStyle(.secondary).monospacedDigit()
            }

            Spacer(minLength: 0)

            // 카드 자체가 넘기는 버튼이다. 아래 버튼까지 내려가지 않아도 되게 한다.
            Button(action: advance) {
                SpotlightCard(card: card, newBadge: l.newCardBadge,
                              preloaded: opened.hires[card.id])
            }
            .buttonStyle(.plain)
            // 카드가 바뀔 때마다 뷰를 새로 만든다 — 첫 장을 포함해 매번 등장 애니메이션이 돈다.
            .id(card.id)

            VStack(spacing: 2) {
                Text(l.tierBadge(card.tier))
                    .font(.system(size: 15, weight: .heavy))
                    .foregroundStyle(tierColor(card.tier))
                Text(l.tierName(card.tier)).font(.caption2).foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)

            HStack(spacing: 6) {
                Button(isLast ? l.done : l.revealNext, action: advance)
                    .buttonStyle(.borderedProminent).controlSize(.small)
                if !isLast {
                    Button(autoPlay == nil ? l.openAll : l.stopAuto) {
                        if autoPlay == nil { openAll() } else { autoPlay?.cancel(); autoPlay = nil }
                    }
                    .buttonStyle(.bordered).controlSize(.small)
                }
            }
        }
        .padding(.vertical, 2)
    }

    // MARK: 요약

    private var summary: some View {
        let l = wallet.l
        return VStack(spacing: 8) {
            VStack(spacing: 2) {
                Text(l.packOpened).font(.callout.weight(.semibold))
                Text("\(opened.setName)  ·  \(l.packOpenSummary(new: newCount, total: opened.cards.count))")
                    .font(.caption).foregroundStyle(.secondary)
            }
            .padding(.top, 2)

            ScrollView {
                LazyVGrid(columns: Array(repeating: GridItem(spacing: 8), count: 4), spacing: 8) {
                    // 요약은 희귀한 것부터 — 무엇을 건졌는지 먼저 보인다.
                    ForEach(Array(opened.cards.reversed().enumerated()), id: \.offset) { _, card in
                        Button { spotlight = card } label: {
                            PulledCardCell(wallet: wallet, card: card, preloaded: opened.thumbs[card.id])
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 2)
            }

            Button(l.done, action: onDone)
                .buttonStyle(.borderedProminent).controlSize(.small)
                .padding(.bottom, 2)
        }
    }
}

/// 한 장씩 보여줄 때의 카드. 나타날 때마다 부풀어 오른다.
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
            TierGlow(tier: card.tier, width: 196)
            CardImageView(cardID: card.id, hires: true, width: 196, preloaded: preloaded)
            if card.isNew {
                NewBadge(text: newBadge)
                    .padding(5)
            }
        }
        .scaleEffect(landed ? 1 : 0.86)
        .opacity(landed ? 1 : 0)
        .onAppear {
            withAnimation(.spring(response: 0.34, dampingFraction: 0.7)) { landed = true }
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
            .font(.system(size: 8, weight: .heavy))
            .padding(.horizontal, 4).padding(.vertical, 1.5)
            .background(Color.accentColor, in: Capsule())
            .foregroundStyle(.white)
    }
}

/// 한번에 열기의 장당 유지 시간.
///
/// 등급별로 다르게 줬더니 리듬이 들쭉날쭉해 오히려 어색했다. 일정한 간격이
/// 넘어가는 흐름을 읽기 쉽다.
enum RevealTiming {
    static let hold = Duration.seconds(1)
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
                CardImageView(cardID: card.id, width: 68, preloaded: preloaded)
                if card.isNew {
                    // 카드 안쪽에 붙인다. 바깥으로 내밀면 격자 경계에서 위가 잘린다.
                    NewBadge(text: wallet.l.newCardBadge).padding(3)
                }
            }
            Text(wallet.l.tierBadge(card.tier))
                .font(.system(size: 9, weight: .heavy))
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
