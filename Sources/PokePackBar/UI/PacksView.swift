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
        var pity = wallet.pity(setID: set.id)
        let pulled = PackOpening.draw(setID: set.id, index: index, alreadyOwned: owned,
                                      perks: wallet.perks, pity: &pity, using: &generator)
        wallet.setPity(pity, setID: set.id)
        // 수집이 도감 완성까지 처리하고 그 목록을 돌려준다.
        let completions = wallet.collect(pulled.cards.map(\.id))
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
                        .font(.title2.weight(.heavy))
                        .foregroundStyle(Color.orange)
                    Text(l.godPackHint).font(.caption).foregroundStyle(.secondary)
                } else {
                    Text(l.packPreparing).font(.callout.weight(.semibold))
                    Text(pending.setName).font(.caption).foregroundStyle(.secondary)
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
                    .font(.callout.weight(.semibold))
                    .fixedSize(horizontal: false, vertical: true)
                Text("\(l.packContents(PackPricing.cardCount(setID: set.id, index: index, perks: wallet.perks)))  ·  ×\(count)")
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
    }

    private func advance() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) { position += 1 }
    }

    /// 한번에 열기 — 남은 카드를 한 장씩 넘기지 않고 결과 화면으로 바로 간다.
    ///
    /// 예전에는 1초에 한 장씩 자동으로 넘겼다. 그러면 열 장을 다 볼 때까지 10초를 기다려야
    /// 하고, 그동안 할 수 있는 것도 없다. 결과를 보고 싶다는 뜻이니 결과를 바로 준다.
    private func skipToSummary() {
        withAnimation(.easeOut(duration: 0.22)) { position = opened.cards.count }
    }

    // MARK: 한 장씩

    private var current: some View {
        let l = wallet.l
        let card = opened.cards[min(position, opened.cards.count - 1)]
        let isLast = position + 1 >= opened.cards.count
        return VStack(spacing: 8) {
            HStack {
                if opened.isGodPack {
                    Text(l.godPackBadge)
                        .font(.system(size: 9, weight: .heavy))
                        .padding(.horizontal, 5).padding(.vertical, 2)
                        .background(Color.orange, in: Capsule())
                        .foregroundStyle(.white)
                }
                Text(opened.setName).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                Spacer()
                Text("\(position + 1) / \(opened.cards.count)")
                    .font(.caption.weight(.semibold)).foregroundStyle(.secondary).monospacedDigit()
            }

            Spacer(minLength: 0)

            RevealStack(card: card,
                        next: position + 1 < opened.cards.count ? opened.cards[position + 1] : nil,
                        newBadge: l.newCardBadge,
                        preloaded: opened.hires[card.id],
                        onAdvance: advance)

            VStack(spacing: 2) {
                Text(l.tierBadge(card.tier))
                    .font(.system(size: 15, weight: .heavy))
                    .foregroundStyle(tierColor(card.tier))
                Text(l.tierName(card.tier)).font(.caption2).foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)

            // 마지막 장에는 누를 것이 없다 — 카드를 넘기면 결과로 간다.
            // 자리는 남겨 둔다. 버튼이 사라지면 카드가 아래로 내려앉아 흔들린다.
            Button(l.openAll, action: skipToSummary)
                .buttonStyle(.bordered).controlSize(.small)
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
                    .font(.callout.weight(opened.isGodPack ? .heavy : .semibold))
                    .foregroundStyle(opened.isGodPack ? Color.orange : Color.primary)
                Text("\(opened.setName)  ·  \(l.packOpenSummary(new: newCount, total: opened.cards.count))")
                    .font(.caption).foregroundStyle(.secondary)
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

/// 한 장씩 넘기는 자리. 카드를 누르거나 끌어서 넘긴다.
///
/// 끌면 카드가 손을 따라 들리고 그 아래에서 **다음 장의 등급 후광**이 배어 나온다.
/// 실물 카드깡에서 위 카드를 살짝 들춰 다음 장의 반사광을 훔쳐보는 동작을 옮긴 것이다.
/// 커먼·에너지의 후광 세기는 0 이므로 "아무것도 안 비친다" 도 그대로 정보가 된다 —
/// 빛이 없으면 다음 장은 기대할 것이 없다는 뜻이고, 그 실망까지가 카드깡이다.
@MainActor
private struct RevealStack: View {
    let card: PulledCard
    let next: PulledCard?
    let newBadge: String
    let preloaded: NSImage?
    let onAdvance: () -> Void

    @State private var drag: CGSize = .zero

    /// 얼마나 들췄는가(0~1). 다음 장 후광의 세기와 그림자에 함께 쓴다.
    private var peek: Double { RevealPeek.amount(drag) }

    var body: some View {
        ZStack {
            // 다음 장은 그림을 보여주지 않는다. 빛만 새어 나와야 다음 장이 기대된다.
            if let next {
                TierGlow(tier: next.tier, width: 196)
                    .opacity(peek)
                    .scaleEffect(0.94 + 0.06 * peek)
                    .allowsHitTesting(false)
            }
            SpotlightCard(card: card, newBadge: newBadge, preloaded: preloaded)
                // 카드가 바뀔 때마다 뷰를 새로 만든다 — 첫 장을 포함해 매번 등장 애니메이션이 돈다.
                .id(card.id)
                .offset(drag)
                .rotationEffect(.degrees(RevealPeek.tilt(drag)), anchor: .bottom)
                .shadow(color: .black.opacity(0.35 * peek), radius: 10 * peek, y: 5 * peek)
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
                .font(.system(size: 13)).foregroundStyle(Color.accentColor)
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 5) {
                    Text(completion.name.text(wallet.language))
                        .font(.caption.weight(.bold)).lineLimit(1)
                    DexStars(tier: completion.tier)
                }
                Text(l.dexCompletedBanner)
                    .font(.caption2).foregroundStyle(.secondary)
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
            .font(.system(size: 8, weight: .heavy))
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
