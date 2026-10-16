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
    @State private var opening: OpeningRequest?
    /// 이번 개봉의 팩 뜯기 화면. 서버가 여는 동안(`opening`)과 그림을 받는 동안(`preparing`)
    /// 같은 화면이 이어져야 찢던 손이 끊기지 않는다. 새 개봉마다 바꾼다.
    @State private var tearSession = UUID()

    private struct OpeningRequest: Identifiable {
        let id = UUID()
        let set: CardSet
        let count: Int
    }

    struct PendingPack: Identifiable {
        let id = UUID()
        let setID: String
        let setName: String
        let packCount: Int
        let presentation: PackPresentation
        var cards: [PulledCard] { presentation.cards }
        /// 각 팩이 차지하는 카드 수. 대량 개봉에서도 특수팩의 첫 장을 정확히 찾는다.
        var packCardCounts: [Int] { presentation.packCardCounts }
        /// 팩별 특수 구성. 여러 팩 중 특수팩이 몇 개였는지도 결과에서 알려 준다.
        var variants: [PackVariant] { presentation.variants }
        var supplements: [PackSupplement] { presentation.supplements }
        /// 이 개봉으로 새로 완성된 도감. 요약 화면에서 알린다.
        let completions: [DexCompletion]
        let isPreview: Bool

        var specialVariants: [PackVariant] { presentation.specialVariants }
    }

    struct OpenedPack: Identifiable {
        let id: UUID
        let setName: String
        let packCount: Int
        let presentation: PackPresentation
        var cards: [PulledCard] { presentation.cards }
        var packCardCounts: [Int] { presentation.packCardCounts }
        /// 미리 받아 둔 그림. 표시 시점에 네트워크를 타지 않는다.
        let hires: [String: NSImage]
        let thumbs: [String: NSImage]
        var variants: [PackVariant] { presentation.variants }
        var supplements: [PackSupplement] { presentation.supplements }
        let completions: [DexCompletion]
        let isPreview: Bool

        var specialVariants: [PackVariant] { presentation.specialVariants }
    }

    /// Native diagnostics use the production reveal/summary, without spending live inventory.
    static func auditPresentation(wallet: WalletStore, index: CardIndex,
                                  presentation: PackPresentation, summary: Bool) -> some View {
        let opened = OpenedPack(id: UUID(), setName: "Black Bolt",
            packCount: presentation.packCardCounts.count, presentation: presentation,
            hires: [:], thumbs: [:], completions: [], isPreview: true)
        return RevealView(wallet: wallet, index: index, opened: opened,
                          initialPosition: summary ? presentation.cards.count : 0, onDone: {})
    }

    var body: some View {
        ZStack {
            if let opened {
                RevealView(wallet: wallet, index: index, opened: opened) { self.opened = nil }
            } else if let tearing {
                PackTearView(wallet: wallet, setID: tearing.setID, setName: tearing.setName,
                             packCount: tearing.packCount, pending: preparing,
                             onCancel: opening == nil ? nil : { self.opening = nil }) { loaded in
                    opened = loaded
                    self.preparing = nil
                }
                .id(tearSession)
            } else if owned.isEmpty {
                emptyState
            } else {
                packShelf
            }
        }
        .frame(height: PopoverMetrics.tabHeight)
        .task(id: opening?.id) {
            guard let request = opening, let index else { return }
            await open(request: request, index: index)
        }
        .onDisappear {
            opening = nil
            if preparing != nil { wallet.markAllRevealed() }
        }
        .onAppear(perform: focusHighlightedPack)
        .onChange(of: nav.packHighlight) { focusHighlightedPack() }
    }

    /// 뜯고 있는 팩. 서버가 돌려준 뒤에는 실제로 열린 팩 수를 쓴다 — 온라인 대량 개봉은
    /// 일부만 확정될 수 있다.
    private var tearing: (setID: String, setName: String, packCount: Int)? {
        if let preparing { return (preparing.setID, preparing.setName, preparing.packCount) }
        if let opening { return (opening.set.id, opening.set.name, opening.count) }
        return nil
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

    /// 가진 팩. **최신 세트가 앞이다** — 상점과 같은 순서다.
    ///
    /// 예전에는 세트 ID 순이었다. 사람 눈에는 아무 뜻이 없는 순서라, 방금 산 팩이 목록
    /// 한가운데에 끼어 찾을 수가 없었다("me1" 은 "base1" 과 "neo1" 사이에 낀다).
    /// 상점에서 최신 팩을 사고 넘어오면 그것이 맨 위에 있어야 한다.
    ///
    /// 인덱스에 없는 세트는 뺀다. 옛 세이브에 남은 세트가 그럴 수 있는데, 카드도 그림도
    /// 없어 열어 봐야 빈 팩이 된다.
    private var owned: [(set: CardSet, count: Int)] {
        guard let index else { return [] }
        return wallet.ownedPacks
            .compactMap { entry in index.set(entry.setID).map { (set: $0, count: entry.count) } }
            .sorted { $0.set.released > $1.set.released }
    }

    /// 팩 이름 검색어. 가진 팩 종류가 많을 때만 검색창을 띄운다.
    @State private var packQuery = ""
    /// 이만큼 종류가 쌓이면 검색창을 띄운다. 몇 줄뿐인 목록에 검색창은 자리만 차지한다.
    private static let searchThreshold = 6

    private var visibleOwned: [(set: CardSet, count: Int)] {
        packQuery.isEmpty ? owned : owned.filter { PackSearch.matches($0.set, query: packQuery) }
    }

    /// 가진 팩 목록과 그 위의 검색창.
    private var packShelf: some View {
        VStack(spacing: 8) {
            // 검색어가 남아 있으면 종류가 줄어도 검색창을 지킨다 — 지울 곳이 사라지면 안 된다.
            if owned.count >= Self.searchThreshold || !packQuery.isEmpty {
                SearchField(placeholder: wallet.l.packSearchPlaceholder, label: wallet.l.packSearchPlaceholder,
                            clearLabel: wallet.l.dexCardSearchClear, text: $packQuery)
            }
            if visibleOwned.isEmpty {
                VStack(spacing: 4) {
                    Text(wallet.l.packSearchEmpty(packQuery))
                        .font(Typography.body).foregroundStyle(.secondary)
                    if PackSearch.hasNonLatinLetters(packQuery) {
                        Text(wallet.l.packSearchEnglishHint)
                            .font(Typography.label).foregroundStyle(.secondary)
                    }
                }
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                packList
            }
        }
    }

    private var packList: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(visibleOwned, id: \.set.id) { entry in
                    if let index {
                        OwnedPackRow(wallet: wallet, index: index, set: entry.set,
                                     count: entry.count) { count in
                            guard !wallet.resourceActionsDisabled else { return }
                            tearSession = UUID()
                            opening = OpeningRequest(set: entry.set, count: count)
                        } onPreviewGodPack: {
                            previewGodPack(set: entry.set, index: index)
                        }
                    }
                }
            }
            .scrollTargetLayout()
        }
        .scrollPosition(id: $scrolledPack, anchor: .center)
    }

    @Environment(PopoverNavigation.self) private var nav
    /// 목록에서 보이게 할 팩 줄. 상점에서 「팩 탭에서 열기」 로 왔을 때 그 줄로 옮겨 간다.
    @State private var scrolledPack: String?

    /// 상점에서 방금 산 팩으로 옮겨 가 한 번 빛낸 뒤 빛을 거둔다.
    private func focusHighlightedPack() {
        guard let id = nav.packHighlight else { return }
        withAnimation(.snappy(duration: 0.3)) { scrolledPack = id }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.6))
            guard nav.packHighlight == id else { return }
            withAnimation(.easeOut(duration: 0.4)) { nav.packHighlight = nil }
        }
    }

    private func open(request: OpeningRequest, index: CardIndex) async {
        let set = request.set
        // Local batches are atomic; online batches commit in bounded chunks.
        // A partial online result contains every confirmed pack, never an invented rollback.
        guard let result = await wallet.openPacksAsync(setID: set.id, count: request.count, index: index) else {
            if opening?.id == request.id { opening = nil }
            return
        }
        let era = index.era(set.id)
        let presentation = await Task.detached(priority: .userInitiated) {
            PackPresentation(packs: result.packs, setID: set.id, era: era)
        }.value
        guard !Task.isCancelled, opening?.id == request.id else {
            wallet.markAllRevealed()
            return
        }
        // 카드는 이미 들어갔지만 머리글의 컬렉션 가치는 뒤집은 만큼만 올린다 —
        // 값이 먼저 오르면 무엇이 나왔는지 카드를 보기 전에 알게 된다.
        preparing = PendingPack(setID: set.id, setName: set.name,
                                packCount: result.packs.count, presentation: presentation,
                                completions: result.completions, isPreview: false)
        opening = nil
    }

    private func previewGodPack(set: CardSet, index: CardIndex) {
        var generator = SystemRandomNumberGenerator()
        guard let result = PackOpening.godPackPreview(
            setID: set.id, index: index, alreadyOwned: wallet.ownedCardIDs,
            using: &generator
        ) else { return }
        let expansionCards = PackOpening.revealOrder(result.cards).map {
            PulledCard(id: $0.id, tier: $0.tier, isNew: false, finish: $0.finish)
        }
        let preview = OpenedCards(slotResults: expansionCards.map {
            PackSlotResult(card: $0, finishHint: .defaultForCard)
        }, variant: result.variant)
        let presentation = PackPresentation(packs: [preview],
                                            setID: set.id, era: index.era(set.id))
        tearSession = UUID()
        preparing = PendingPack(
            setID: set.id, setName: set.name, packCount: 1, presentation: presentation,
            completions: [], isPreview: true
        )
    }
}

/// 보유 팩 1줄.
@MainActor
private struct OwnedPackRow: View {
    @Environment(PopoverNavigation.self) private var nav
    private var highlightedRow: Bool { nav.packHighlight == set.id }

    let wallet: WalletStore
    let index: CardIndex
    let set: CardSet
    let count: Int
    let onOpen: (Int) -> Void
    let onPreviewGodPack: () -> Void

    @State private var quantity = 1

    /// 가진 팩 수가 상한이다. 처음 시작한 사람은 레벨에 따라 한 번에 여는 수가 정해져 있다.
    private var openLimit: Int? { LevelRules.openLimit(level: wallet.level) }
    private var maximumQuantity: Int { max(1, min(count, openLimit ?? .max)) }

    var body: some View {
        let l = wallet.l
        HStack(spacing: 10) {
            PackImageView(setID: set.id, width: 34)
            VStack(alignment: .leading, spacing: 2) {
                Text(l.packName(set.name))
                    .font(Typography.title)
                    .fixedSize(horizontal: false, vertical: true)
                let contents = PackRecipe.forSet(set.id, era: index.era(set.id)).contents
                Text("\(l.packContents(contents))  ·  ×\(count)")
                    .font(Typography.body).foregroundStyle(.secondary).monospacedDigit()
            }
            Spacer(minLength: 0)
            VStack(alignment: .trailing, spacing: 5) {
                if count > 1 {
                    HStack(spacing: 6) {
                        // 가진 팩을 다 열 때 수량 칸에 숫자를 쳐 넣지 않아도 되게 한다.
                        Button(l.maxQuantity) { quantity = maximumQuantity }
                            .buttonStyle(.borderless)
                            .font(Typography.labelSemibold)
                            .disabled(quantity == maximumQuantity)
                        PackQuantityStepper(quantity: $quantity, maximum: maximumQuantity,
                                            showsMultiplier: true,
                                            accessibilityLabel: l.packOpenQuantity(quantity), l: l)
                        .font(Typography.bodySemibold)
                        .fixedSize()
                    }
                    if let limit = openLimit, count > limit,
                       let next = LevelRules.nextUnlock(after: wallet.level) {
                        Text(l.levelOpenLimit(limit, nextLevel: next))
                            .font(Typography.caption).foregroundStyle(.secondary)
                    }
                }
                Button(l.openPackCount(quantity)) { onOpen(quantity) }
                    .buttonStyle(.borderedProminent).font(Typography.button)
                if PackRecipe.forSet(set.id, era: index.era(set.id))
                    .specialRules.contains(where: { $0.variant.isGodPack }) {
                    Button(l.godPackPreviewButton, action: onPreviewGodPack)
                        .buttonStyle(.borderless)
                        .font(Typography.labelSemibold)
                        .foregroundStyle(Color.orange)
                        .help(l.godPackPreviewHelp)
                        .accessibilityHint(l.godPackPreviewHelp)
                }
            }
        }
        .padding(10)
        .background(Color.secondary.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .hoverHighlight(cornerRadius: 10)
        // 상점에서 「팩 탭에서 열기」 로 온 팩이면 테두리가 한 번 빛난다.
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(Color.accentColor, lineWidth: 2)
                .shadow(color: Color.accentColor.opacity(0.5), radius: 6)
                .opacity(highlightedRow ? 1 : 0)
                .allowsHitTesting(false)
        }
        .onChange(of: count) { quantity = min(quantity, maximumQuantity) }
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
    /// 결과 카드를 연 자리. 상세가 그 칸에서 커져 열린다.
    @State private var zoomOrigin = ZoomOrigin()
    private static let space = "reveal"
    @State private var isAdvancing = false
    @State private var advanceTask: Task<Void, Never>?
    @State private var upcomingImages: [String: NSImage] = [:]
    /// 키보드로 넘긴 횟수. 올라갈 때마다 카드 자리가 누른 것처럼 넘긴다.
    @State private var keyAdvance = 0
    @FocusState private var focused: Bool
    /// 결과 화면 정렬. 다음 개봉에도 같은 기준으로 보이게 기억한다.
    @AppStorage("packSummarySort") private var summarySort = SummarySort.price
    /// 결과 화면이 뜬 때. 좋은 카드의 빛은 이때부터 차례로 스친다(`PulledCardCell.Shine`).
    @State private var summaryShownAt = Date.distantPast
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    enum SummarySort: String { case price, rarity }

    init(wallet: WalletStore, index: CardIndex?, opened: PacksView.OpenedPack,
         initialPosition: Int = 0, onDone: @escaping () -> Void) {
        self.wallet = wallet
        self.index = index
        self.opened = opened
        self.onDone = onDone
        _position = State(initialValue: initialPosition)
        if initialPosition >= opened.cards.count { _summaryShownAt = State(initialValue: Date()) }
    }

    private var isSummary: Bool { position >= opened.cards.count }
    private var newCount: Int { opened.presentation.newCount }

    private func revealImage(_ id: String) -> NSImage? {
        upcomingImages[id] ?? opened.hires[id] ?? CardImageLoader.preparedImage(cardID: id, hires: true)
    }

    var body: some View {
        ZStack {
            VStack(spacing: 8) {
                if isSummary {
                    // 상세를 열어도 결과 격자는 뒤에 둔다. 여러 팩 결과를 내려 보다 연 카드를
                    // 닫았을 때 처음으로 튕겨 올라가지 않는다.
                    ZStack {
                        summary
                            .opacity(spotlight == nil ? 1 : 0)
                            .allowsHitTesting(spotlight == nil)
                            .accessibilityHidden(spotlight != nil)
                        if let focused = spotlight {
                            CardSpotlightView(wallet: wallet, cardID: focused.id,
                                              name: index?.card(focused.id)?.displayName(wallet.language) ?? focused.id,
                                              tier: focused.tier,
                                              setID: index?.card(focused.id)?.setID ?? "",
                                              setName: opened.setName,
                                              rarity: index?.card(focused.id)?.rarity,
                                              finish: focused.finish,
                                              ownedCount: wallet.cardCount(focused.id),
                                              preloaded: revealImage(focused.id)) {
                                withAnimation(.snappy(duration: 0.26)) { spotlight = nil }
                            }
                            .transition(.zoom(from: zoomOrigin.anchor, reduceMotion: reduceMotion))
                        }
                    }
                } else {
                    current
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .coordinateSpace(.named(Self.space))
        // 스페이스와 오른쪽 화살표로도 넘긴다. 열 장, 백 장을 넘길 때 같은 자리를 계속
        // 클릭하는 것보다 손이 덜 간다. 결과 화면에서는 키를 버튼들에 넘긴다.
        .focusable()
        .focusEffectDisabled()
        .focused($focused)
        .onKeyPress(keys: [.space, .rightArrow]) { _ in
            guard !isSummary, !isAdvancing else { return .ignored }
            keyAdvance += 1
            return .handled
        }
        .onAppear { focused = true }
        // Esc 는 한 장씩 보는 중이면 결과로 건너뛰고, 결과 화면이면 팩 목록으로 돌아간다.
        // 결과에서 연 카드 상세는 제 뒤로 버튼이 먼저 받는다.
        .popoverEscape { if isSummary { onDone() } else { skipToSummary() } }
        .onChange(of: opened.id) {
            advanceTask?.cancel()
            advanceTask = nil
            position = 0
            isAdvancing = false
        }
        .task(id: "\(opened.id)-\(position / 8)-\(isSummary)") {
            guard !isSummary else { upcomingImages = [:]; return }
            let images = await CardImageLoader.prefetch(
                cardIDs: opened.presentation.imageIDs(at: position), hires: true)
            guard !Task.isCancelled else { return }
            upcomingImages = images
        }
        // 연출을 끝까지 보지 않고 화면을 벗어나도 값은 제자리로 돌아와야 한다 —
        // 감춘 채로 남으면 가진 것보다 적게 표시된다.
        .onDisappear {
            advanceTask?.cancel()
            advanceTask = nil
            if !opened.isPreview { wallet.markAllRevealed() }
        }
    }

    /// 다음 장으로. **카드끼리 넘어갈 때는 애니메이션 트랜잭션을 열지 않는다.**
    ///
    /// `SpotlightCard` 는 `.id(card.id)` 로 매번 새로 만들어진다. 그 교체를 애니메이션 안에서
    /// 하면 SwiftUI 가 기본 전환(페이드)을 걸어, 나가는 카드와 들어오는 카드가 동시에 반투명해
    /// 지면서 밑장이 비쳐 보인다 — 카드가 커질 때 깜빡이는 것처럼 보이던 것이 이것이다.
    /// 올라오는 움직임은 카드 자신의 `onAppear` 스프링이 맡으므로 여기서 열 이유가 없다.
    ///
    /// 마지막 장에서 요약으로 넘어갈 때만 화면이 통째로 바뀌므로 그때는 애니메이션을 준다.
    private func advance(_ kind: RevealAdvanceKind = .tap) {
        guard !isAdvancing, !opened.cards.isEmpty else { return }
        // 방금 본 장을 컬렉션 가치에 얹는다. 넘긴 뒤에 올려야 머리글이 카드보다 앞서지 않는다.
        let card = opened.cards[min(position, opened.cards.count - 1)]
        if !opened.isPreview {
            if !card.isSupplementalEnergy {
                wallet.markRevealed(CardPrintingKey(cardID: card.id, finish: card.finish))
            }
        }
        if position + 1 >= opened.cards.count {
            if !opened.isPreview { wallet.markAllRevealed() }
            summaryShownAt = Date()
            withAnimation(.easeOut(duration: 0.22)) { position += 1 }
        } else {
            // 넘기는 것은 즉시. 등급 신호는 카드를 누르는 순간 RevealStack 이 터뜨린다 —
            // 신호가 끝날 때까지 다음 카드를 붙잡아 두면 입력이 늦게 먹는 것처럼 보였다.
            position += 1
        }
    }

    // 갓팩과 특수팩은 개봉 도중에 알리지 않는다. 화면 한가운데 "갓팩!" 배너가 카드를 가리고
    // 흐름을 끊었다. 무엇이 나왔는지는 카드가 말해 주고, 특수팩이었다는 것은 결과 화면 제목이 알린다.

    /// 한번에 열기 — 남은 카드를 한 장씩 넘기지 않고 결과 화면으로 바로 간다.
    ///
    /// 예전에는 1초에 한 장씩 자동으로 넘겼다. 그러면 열 장을 다 볼 때까지 10초를 기다려야
    /// 하고, 그동안 할 수 있는 것도 없다. 결과를 보고 싶다는 뜻이니 결과를 바로 준다.
    private func skipToSummary() {
        guard !isAdvancing else { return }
        // 요약이 열 장을 한꺼번에 보여 주므로 값도 한꺼번에 올린다.
        if !opened.isPreview { wallet.markAllRevealed() }
        summaryShownAt = Date()
        withAnimation(.easeOut(duration: 0.22)) { position = opened.cards.count }
    }

    // MARK: 한 장씩

    /// 카드 아래 정보. 등급만 있으면 무엇을 뽑았는지가 배지 한 글자에 달린다 —
    /// 이름과 값까지 있어야 이 카드가 무엇인지, 얼마짜리인지 그 자리에서 읽힌다.
    @ViewBuilder
    private func revealInfo(_ l: L, card: PulledCard) -> some View {
        VStack(spacing: 3) {
            Text(SupplementalEnergyCard.displayName(cardID: card.id, language: wallet.language)
                 ?? index?.card(card.id)?.displayName(wallet.language) ?? card.id)
                .font(Typography.title)
                .lineLimit(1).minimumScaleFactor(0.7)
            HStack(spacing: 5) {
                Text(l.tierBadge(card.tier))
                    .font(Typography.badge)
                    .foregroundStyle(tierColor(card.tier))
                Text(l.tierName(card.tier)).font(Typography.label).foregroundStyle(.secondary)
                Text("·").font(Typography.label).foregroundStyle(.tertiary)
                Text(l.cardFinishName(card.finish))
                    .font(Typography.label).foregroundStyle(.secondary)
                if !card.isSupplementalEnergy, let prices = CardPrices.shared,
                   let usd = prices.price(cardID: card.id, finish: card.finish) {
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
                Text(opened.setName).font(Typography.body).foregroundStyle(.secondary).lineLimit(1)
                Spacer()
                Text(opened.packCount == 1
                     ? "\(position + 1) / \(opened.cards.count)"
                     : "×\(opened.packCount) · \(position + 1) / \(opened.cards.count)")
                    .font(Typography.bodySemibold).foregroundStyle(.secondary).monospacedDigit()
            }

            Spacer(minLength: 0)

            RevealStack(card: card,
                        next: nextCard,
                        newBadge: l.newCardBadge,
                        preloaded: revealImage(card.id),
                        nextPreloaded: nextCard.flatMap { revealImage($0.id) },
                        interactionEnabled: !isAdvancing,
                        keyAdvance: keyAdvance,
                        onAdvance: advance)
                .help(l.revealKeyboardHint)

            revealInfo(l, card: card)

            Spacer(minLength: 0)

            // 마지막 장에서는 「결과 보기」로 바뀐다. 예전에는 버튼을 투명하게 지웠는데,
            // 다 넘긴 순간 누를 것이 사라져 무엇을 해야 결과를 보는지 알 수 없었다.
            // 자리는 어느 쪽이든 같은 크기라 카드가 흔들리지 않는다.
            Group {
                if isLast {
                    Button(l.packSeeResult) { advance(.tap) }
                        .buttonStyle(.borderedProminent)
                } else {
                    Button(l.openAll, action: skipToSummary)
                        .buttonStyle(.bordered)
                }
            }
            .font(Typography.button)
            .disabled(isAdvancing)
        }
        .padding(.vertical, 2)
    }

    // MARK: 요약

    /// 이번 개봉에서 가장 비싼 카드. 평범한 카드뿐이면 없다.
    private var bestPull: PulledCard? {
        guard let best = opened.presentation.summaryByPrice.first,
              RevealMotionProfile.forCard(best).emphasis != .none else { return nil }
        return best
    }

    /// 결과 칸마다 스칠 빛. **좋은 카드는 모두** 놓인 순서대로 한 번씩, 최고 카드는 더 밝게.
    ///
    /// 처음에는 최고 카드 한 장에만 빛을 줬다. 그 한 장이 왜 빛나는지 알 수 없어 어색했고,
    /// 다른 좋은 카드가 몇 장 나왔는지는 배지를 하나씩 읽어야 알 수 있었다. 커먼과 언커먼에는
    /// 주지 않는다 — 다 빛나면 무엇이 좋은 것인지 오히려 흐려진다.
    private func shines(in order: [PulledCard]) -> [PulledCardCell.Shine?] {
        let best = bestPull
        var next = 0
        return order.map { card in
            guard !card.isSupplementalEnergy,
                  RevealMotionProfile.forCard(card).emphasis != .none else { return nil }
            defer { next += 1 }
            return PulledCardCell.Shine(best: card.id == best?.id && card.finish == best?.finish,
                                        at: PulledCardCell.Shine.start(order: next, after: summaryShownAt))
        }
    }

    /// 이 팩에 맞춘 요약 격자. 1999년 팩은 11장이라 열이 하나 더 필요하다.
    private var summaryGrid: CardGrid {
        opened.packCount == 1 ? CardGrid.packSummary(opened.cards.count) : .collection
    }

    private var summaryCardOrder: [PulledCard] {
        // 공개는 실물 팩 순서 그대로, 결과는 무엇을 건졌는지 바로 보이게 가격순이나
        // 레어도순으로 다시 놓는다. 별도 에너지는 첫 칸을 차지하지 않게 맨 뒤에 둔다.
        // 시세가 없으면 가격이 모두 0이라 레어도순과 같아진다.
        switch summarySort {
        case .price: opened.presentation.summaryByPrice
        case .rarity: opened.presentation.summaryByRarity
        }
    }

    @ViewBuilder
    private var summaryCards: some View {
        let order = summaryCardOrder
        let shineByOffset = shines(in: order)
        let cards = LazyVGrid(columns: summaryGrid.items, spacing: summaryGrid.spacing) {
            // 요약은 희귀한 것부터 — 무엇을 건졌는지 먼저 보인다.
            ForEach(order.indices, id: \.self) { offset in
                let card = order[offset]
                if card.isSupplementalEnergy {
                    PulledCardCell(wallet: wallet, card: card,
                                   width: summaryGrid.width,
                                   preloaded: opened.thumbs[card.id],
                                   appearanceIndex: offset)
                } else {
                    Button {
                        Task { @MainActor in
                            zoomOrigin.consume(in: CGSize(width: PopoverMetrics.contentWidth,
                                                          height: PopoverMetrics.tabHeight))
                            withAnimation(.snappy(duration: 0.32)) { spotlight = card }
                        }
                    } label: {
                        PulledCardCell(wallet: wallet, card: card,
                                       width: summaryGrid.width,
                                       preloaded: opened.thumbs[card.id],
                                       appearanceIndex: offset,
                                       shine: shineByOffset[offset])
                            .hoverLift(scale: 1.05)
                    }
                    .recordsClick(in: Self.space, into: $zoomOrigin)
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, 2)

        if opened.packCount == 1 { cards }
        else { ScrollView { cards } }
    }

    private var summary: some View {
        let l = wallet.l
        return VStack(spacing: 8) {
            VStack(spacing: 2) {
                // 특수팩이어도 따로 외치지 않는다. 무엇이 나왔는지는 카드와 총 가치가 말해 준다.
                Text(opened.packCount > 1 ? l.packBatchOpened(opened.packCount) : l.packOpened)
                    .font(Typography.title)
                    .foregroundStyle(Color.primary)
                Text(opened.isPreview
                     ? "\(opened.setName)  ·  \(l.godPackPreviewNotice)"
                     : "\(opened.setName)  ·  \(l.packOpenSummary(new: newCount, total: opened.cards.count))")
                    .font(Typography.body).foregroundStyle(.secondary)
                // 무엇이 나왔는지는 카드 그림이 말해 주지만, 얼마어치가 나왔는지는 숫자로만
                // 알 수 있다. 팩값과 나란히 놓고 보라고 여기 둔다.
                if let prices = CardPrices.shared {
                    let worth = opened.presentation.worthUSD
                    // 정렬 전환은 총 가치와 같은 줄에 둔다. 한 팩 요약은 두 줄 격자가
                    // 꽉 차게 맞춰져 있어 줄을 하나 더 쓰면 카드가 밀린다.
                    HStack(spacing: 8) {
                        Text(l.packTotalValue(prices.formattedWithKRW(worth,
                                                                      language: wallet.language)))
                            .font(Typography.amount).monospacedDigit()
                            .foregroundStyle(Color.accentColor)
                            .lineLimit(1).minimumScaleFactor(0.8)
                        if opened.cards.count > 1 {
                            Picker("", selection: $summarySort) {
                                Text(l.sortByValue).tag(SummarySort.price)
                                Text(l.sortByTier).tag(SummarySort.rarity)
                            }
                            .pickerStyle(.segmented)
                            .labelsHidden()
                            .controlSize(.regular)
                            .font(Typography.button)
                            .fixedSize()
                        }
                    }
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

            // 한 팩은 두 줄로 전부 보이고, 여러 팩은 같은 크기를 유지한 채 결과만 스크롤한다.
            summaryCards

            Spacer(minLength: 0)

            Button(l.done, action: onDone)
                .buttonStyle(.borderedProminent).font(Typography.button)
                .keyboardShortcut(.defaultAction)
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
    let interactionEnabled: Bool
    /// 키보드로 넘긴 횟수. 바뀌면 눌러서 넘긴 것과 같게 불꽃을 터뜨리고 넘긴다.
    var keyAdvance = 0
    let onAdvance: (RevealAdvanceKind) -> Void

    @State private var drag: CGSize = .zero
    /// 지금 누르고 있는가. 누르는 동안 밑에 깔린 다음 장의 기운이 올라온다.
    @State private var pressing = false
    /// 누르는 순간 다음 장이 희귀하면 터뜨린 불꽃. 누를 때마다 새로 터진다.
    @State private var pop: PulledCard?
    @State private var popID = UUID()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// 얼마나 들췄는가(0~1). 밑장의 밝기와 후광, 위 카드의 그림자에 함께 쓴다.
    private var peek: Double { RevealPeek.amount(drag) }

    var body: some View {
        ZStack {
            if let next {
                ZStack {
                    TierGlow(tier: next.tier, width: RevealPeek.cardWidth, valueCard: next).opacity(peek)
                    // 다음 장은 가려진 채 부모 drag/brightness가 매 프레임 바뀐다. 여기서 완전한
                    // 홀로 Canvas까지 함께 돌리면 현재 카드와 합쳐 두 장을 매 프레임 합성한다.
                    // 원본 스캔만 깔아 두고, 다음 장이 현재 장이 되는 순간 SpotlightCard가 실제
                    // 홀로 재질을 붙인다. 훔쳐보는 동안 카드 정체와 색은 그대로 보존된다.
                    CardImageView(cardID: next.id, hires: true,
                                  width: RevealPeek.cardWidth, preloaded: nextPreloaded)
                }
                .scaleEffect(RevealPeek.deckScale)
                .offset(y: RevealPeek.deckOffset)
                // 덮여 있는 동안은 그늘에 있다. 들어 올릴수록 제 색을 찾는다.
                .brightness(-0.16 * (1 - peek))
                // 밑장의 기운은 밑장 자리에서 올라온다. 누르는 순간 보이고, 들출수록 진해진다.
                .background { nextAura }
                .allowsHitTesting(false)
            }
            SpotlightCard(card: card, newBadge: newBadge, preloaded: preloaded)
                // 카드가 바뀔 때마다 뷰를 새로 만든다 — 첫 장을 포함해 매번 등장 애니메이션이 돈다.
                .id(card.id)
                // 교체는 즉시. 기본 전환(페이드)이 걸리면 두 장이 겹쳐 반투명해진다.
                .transition(.identity)
                // 기운은 그 카드에서 나온다. 끌어내면 카드와 함께 움직이고 기울며 빼낸 만큼 옅어진다.
                .background { currentAura }
                .offset(drag)
                .rotationEffect(.degrees(RevealPeek.tilt(drag)), anchor: .bottom)
                // 가만히 있어도 옅은 그림자를 남긴다 — 밑장과 겹쳐 보이지 않게 하는 층 표시다.
                .shadow(color: .black.opacity(0.18 + 0.24 * peek),
                        radius: 4 + 9 * peek, y: 2 + 5 * peek)
        }
        // 불꽃은 카드 위로 튄다. 겹쳐 그리기만 하고 배치에는 끼어들지 않는다.
        .overlay {
            if let pop {
                RevealPop(card: pop, width: RevealPeek.cardWidth).id(popID)
            }
        }
        .allowsHitTesting(interactionEnabled)
        .contentShape(Rectangle())
        // 누르는 순간을 잡으려고 탭과 끌기를 거리 0 의 끌기 하나로 받는다. 누르면 다음 장의
        // 기운이 바로 올라오고, 거의 움직이지 않고 떼면 탭으로 바로 넘어가며, 더 끌면
        // 들추기가 된다. 희귀한 장이면 누르는 순간 알고 천천히 들출 수 있다.
        .gesture(
            // 화면 좌표로 잰다. 카드가 움직이는 동안 지역 좌표의 기준이 바뀌어도 이동량이 튀지 않는다.
            DragGesture(minimumDistance: 0, coordinateSpace: .global)
                .onChanged { value in
                    if !pressing {
                        pressing = true
                        firePop()
                    }
                    if RevealPeek.distance(value.translation) >= Self.tapSlop {
                        drag = value.translation
                    }
                }
                .onEnded { value in
                    // 움직임 없는 클릭은 누르는 순간 onChanged 가 오지 않을 수 있다. 그때는 떼는 순간 터뜨린다.
                    if !pressing { firePop() }
                    pressing = false
                    if RevealPeek.distance(value.translation) < Self.tapSlop {
                        advance(.tap)
                    } else if RevealPeek.advances(value.translation) {
                        advance(.drag)
                    } else {
                        // 덜 들췄으면 제자리로. 다음 장 빛도 함께 사그라든다.
                        withAnimation(.spring(response: 0.32, dampingFraction: 0.7)) {
                            drag = .zero
                        }
                    }
                }
        )
        .onChange(of: keyAdvance) {
            guard interactionEnabled else { return }
            firePop()
            advance(.tap)
        }
    }

    /// 희귀한 장은 보이는 동안 계속 기운이 뿜어져 나온다. 기운은 카드보다 크게 퍼지므로
    /// 배경으로만 붙인다 — 스택 안에 두면 나타나고 사라질 때마다 스택 크기가 바뀌어 카드가
    /// 밀리고 끌기 좌표가 튀었다.
    private var nextIsRare: Bool {
        next.map { RevealMotionProfile.forCard($0).emphasis != .none } ?? false
    }

    @ViewBuilder
    private var currentAura: some View {
        if RevealMotionProfile.forCard(card).emphasis != .none {
            // 희귀한 밑장을 누르고 있으면 그쪽 기운에 자리를 내준다.
            RevealAura(card: card, width: RevealPeek.cardWidth)
                .opacity((pressing && nextIsRare ? 0.3 : 1) * (1 - peek))
                .id("aura-\(card.id)-\(card.finish.rawValue)")
                .allowsHitTesting(false)
        }
    }

    /// 누르는 동안에는 밑에 깔린 다음 장의 기운이 먼저 올라와, 무엇이 오는지 느끼며
    /// 천천히 들출 수 있다. 밑장 크기와 자리에 맞춰 그린다.
    @ViewBuilder
    private var nextAura: some View {
        if let next, pressing, nextIsRare {
            RevealAura(card: next, width: RevealPeek.cardWidth)
                .opacity(0.65 + 0.35 * peek)
                .scaleEffect(RevealPeek.deckScale)
                .offset(y: RevealPeek.deckOffset)
                .id("aura-next-\(next.id)-\(next.finish.rawValue)")
                .allowsHitTesting(false)
        }
    }

    /// 다음 장이 희귀하면 불꽃을 새로 터뜨린다.
    private func firePop() {
        guard let next, nextIsRare, !reduceMotion else { return }
        pop = next
        popID = UUID()
    }

    /// 이보다 덜 움직이고 떼면 탭이다. 예전 끌기의 최소 거리와 같다.
    private static let tapSlop: CGFloat = 6

    private func advance(_ kind: RevealAdvanceKind) {
        drag = .zero
        onAdvance(kind)
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
    @State private var showNewBadge = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack(alignment: .topTrailing) {
            // HolographicCardView 자체가 등급 후광을 포함한다. 바깥에 한 겹 더 두면 같은 크기의
            // 대형 blur 네 장이 겹쳐 등장 애니메이션 때 불필요한 오프스크린 합성이 생긴다.
            HolographicCardView(cardID: card.id, tier: card.tier,
                                finish: card.finish, width: RevealPeek.cardWidth,
                                preloaded: preloaded)
                .environment(\.valueAwareGlow, true)
            if card.isNew {
                if showNewBadge {
                    NewBadge(text: newBadge)
                        .padding(5)
                        .transition(.scale(scale: 1.45).combined(with: .opacity))
                }
            }
        }
        .scaleEffect(landed ? 1 : RevealPeek.deckScale)
        .offset(y: landed ? 0 : RevealPeek.deckOffset)
        .onAppear {
            if reduceMotion {
                landed = true
                showNewBadge = card.isNew
                return
            }
            withAnimation(.spring(response: 0.34, dampingFraction: 0.7)) { landed = true }
            if let sound = RevealMotionProfile.forCard(card).emphasis.sound {
                SoundEffects.play(sound)
            }
            guard card.isNew else { return }
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(190))
                withAnimation(.spring(response: 0.28, dampingFraction: 0.62)) {
                    showNewBadge = true
                }
            }
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
    static let cardWidth: CGFloat = PopoverMetrics.revealCardWidth

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

/// 후광 세기 배율. 개봉 연출은 1 그대로, 카드를 가만히 들여다보는 상세 화면은 낮춘다 —
/// 230pt 카드 뒤에서 최대 세기로 번지면 카드보다 빛이 먼저 보인다.
private struct TierGlowScaleKey: EnvironmentKey {
    static let defaultValue: Double = 1
}

/// 공개 연출(팩, 오리파)에서만 켠다. 켜지면 후광도 아우라와 같은 기준 — 등급과 시세 중
/// 높은 쪽 — 으로 세기와 색을 정한다. 도감과 컬렉션은 등급 그대로 둔다.
private struct ValueAwareGlowKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var tierGlowScale: Double {
        get { self[TierGlowScaleKey.self] }
        set { self[TierGlowScaleKey.self] = newValue }
    }
    var valueAwareGlow: Bool {
        get { self[ValueAwareGlowKey.self] }
        set { self[ValueAwareGlowKey.self] = newValue }
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
    /// 주면 아우라와 같은 기준을 쓴다. 세기는 그 팩에서 얼마나 드문가(와 시세)로 정해서,
    /// 거의 매 팩 나오는 등급은 빛나지 않는다. 시세 덕에 드묾보다 높게 뜬 카드는 금빛이고,
    /// 가장 높은 단계는 무지개로 빛난다.
    var valueCard: PulledCard? = nil
    @Environment(\.tierGlowScale) private var scale

    /// 카드가 나타난 뒤 빛이 퍼지도록 한 번만 부풀린다.
    @State private var bloomed = false
    /// 진단 렌더러가 다 퍼진 모습을 바로 그릴 때만 켠다.
    var startBloomed = false

    var body: some View {
        let base = valueCard.map(RevealMotionProfile.rarityEmphasis(_:))
        let emphasis = valueCard.map { RevealMotionProfile.forCard($0).emphasis }
        let raised: Bool = {
            guard let base, let emphasis else { return false }
            return emphasis > base
        }()
        let color = raised ? RevealValueEmphasis.color : tierColor(tier)
        let strength = (emphasis.map(Self.strength(for:)) ?? Self.strength(for: tier)) * scale
        let prismatic = emphasis?.isPrismatic == true
        ZStack {
            // 바깥 — 넓게 번지는 빛. 가장 높은 단계는 무지개로 번진다.
            RoundedRectangle(cornerRadius: width * 0.09)
                .fill(prismatic
                      ? AnyShapeStyle(AngularGradient(colors: (0...6).map { RevealEmphasis.prismColor(Double($0) / 6) },
                                                      center: .center))
                      : AnyShapeStyle(color))
                .blur(radius: width * 0.20)
                .opacity(strength * 0.55)
                .scaleEffect(bloomed ? 1.16 : 0.97)
            // 안쪽 — 카드 가장자리에 붙는 빛
            RoundedRectangle(cornerRadius: width * 0.06)
                .fill(color)
                .blur(radius: width * 0.07)
                .opacity(strength * 0.85)
                .scaleEffect(bloomed ? 1.05 : 0.97)
            // 카드 가장자리에 붙는 테두리 선은 두지 않는다. 선은 카드 틀에 맞춰 그려지는데 스캔 속
            // 카드는 틀보다 조금 안쪽에 있는 경우가 많아, 카드 밖으로 살짝 튀어나온 테두리로 보였다.
        }
        .frame(width: width, height: (width / 0.717).rounded())
        // 후광은 장식이라 보조기술이 읽을 것이 없다. 등급은 배지와 이름이 따로 알린다.
        .accessibilityHidden(true)
        .onAppear {
            if startBloomed { bloomed = true; return }
            withAnimation(.easeOut(duration: 0.45)) { bloomed = true }
        }
    }

    /// 시세로 올라간 단계의 세기. 등급표의 같은 단계 대표값과 맞춘다(RR, AR, UR 근처).
    static func strength(for emphasis: RevealEmphasis) -> Double {
        switch emphasis {
        case .none: return 0
        case .rare: return 0.52
        case .premium: return 0.76
        case .apex: return 0.98
        case .mythic: return 1.0
        }
    }

    /// 등급별 세기(0~1). 커먼과 에너지는 거의 보이지 않아야 한다 —
    /// 흔한 카드까지 빛나면 빛이 등급 신호로 작동하지 않는다.
    static func strength(for tier: CardTier) -> Double {
        switch tier {
        case .energy, .common: return 0.0
        case .uncommon:        return 0.18
        case .rare:            return 0.34
        case .promo:           return 0.38
        case .doubleRare:      return 0.52
        case .tripleRare:      return 0.65
        case .prismStar:       return 0.68
        case .amazing:         return 0.70
        case .radiant:         return 0.72
        case .characterRare:   return 0.75
        case .artRare:         return 0.76
        case .aceSpec:         return 0.79
        case .superRare:       return 0.83
        case .shiny:           return 0.86
        case .shinyUltra:      return 0.88
        case .specialArtRare:  return 0.89
        case .shining:         return 0.92
        case .hyperRare:       return 0.96
        case .ultraRare:       return 0.98
        case .blackWhiteRare:  return 0.99
        case .megaAttack:      return 0.995
        case .megaUltraRare:   return 0.998
        case .futureUltra:     return 1.0
        }
    }
}

@MainActor
private struct PulledCardCell: View {
    let wallet: WalletStore
    let card: PulledCard
    /// 요약 격자의 칸 폭. 팩 장수에 따라 달라지므로 밖에서 받는다.
    let width: CGFloat
    var preloaded: NSImage?
    let appearanceIndex: Int
    /// 나타난 뒤 한 번 스치는 빛. 좋은 카드에만 있다.
    var shine: Shine?

    struct Shine: Equatable {
        /// 이번 개봉의 최고 카드. 더 밝고 넓은 빛이 조금 더 천천히 지나간다.
        let best: Bool
        /// 이 칸에 빛이 스치기 시작할 때.
        let at: Date

        /// 결과가 뜬 뒤 칸이 다 자리 잡을 때까지 기다렸다가, 첫 칸부터 일정한 간격으로 이어
        /// 스친다. 장수가 많아도 몰아서 끝내지 않는다 — 빛이 한 줄로 미끄러져 가야 순서가 읽힌다.
        static func start(order: Int, after shown: Date) -> Date {
            shown.addingTimeInterval(0.46 + Double(order) * 0.14)
        }
    }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false
    /// 스치는 빛의 위치(카드 폭 기준, -1 에서 들어와 2 에서 나간다).
    @State private var glint: CGFloat = -1

    var body: some View {
        VStack(spacing: 3) {
            ZStack(alignment: .topTrailing) {
                CardImageView(cardID: card.id, width: width, preloaded: preloaded)
                    .overlay {
                        if let shine {
                            LinearGradient(stops: [
                                .init(color: .clear, location: 0),
                                .init(color: .white.opacity(shine.best ? 0.85 : 0.45), location: 0.5),
                                .init(color: .clear, location: 1),
                            ], startPoint: .leading, endPoint: .trailing)
                            .frame(width: width * (shine.best ? 0.5 : 0.36))
                            .rotationEffect(.degrees(20))
                            .offset(x: glint * width)
                            .blendMode(.plusLighter)
                            .clipShape(RoundedRectangle(cornerRadius: width * 0.05))
                            .allowsHitTesting(false)
                        }
                    }
                if card.isNew {
                    // 카드 안쪽에 붙인다. 바깥으로 내밀면 격자 경계에서 위가 잘린다.
                    NewBadge(text: wallet.l.newCardBadge).padding(3)
                }
                if card.finish != .normal {
                    Image(systemName: "sparkles")
                        .font(Typography.caption.weight(.bold)).imageScale(.small)
                        .padding(3)
                        .background(.black.opacity(0.62), in: Circle())
                        .foregroundStyle(.white)
                        .padding(3)
                        .frame(maxWidth: .infinity, maxHeight: .infinity,
                               alignment: .bottomLeading)
                        .help(wallet.l.cardFinishName(card.finish))
                        .accessibilityLabel(wallet.l.cardFinishName(card.finish))
                }
            }
            Text(wallet.l.tierBadge(card.tier))
                .font(.system(size: 14, weight: .heavy))
                .foregroundStyle(tierColor(card.tier))
        }
        .scaleEffect(appeared ? 1 : (reduceMotion ? 1 : 0.94))
        .opacity(appeared ? 1 : 0)
        .task(id: appearanceIndex) {
            if !reduceMotion {
                let delay = min(appearanceIndex, 10) * 38
                try? await Task.sleep(for: .milliseconds(delay))
            }
            guard !Task.isCancelled else { return }
            if reduceMotion {
                appeared = true
            } else {
                withAnimation(.spring(response: 0.32, dampingFraction: 0.76)) { appeared = true }
            }
            // 좋은 카드마다 제 차례에 빛이 한 번 스친다. 여러 팩 결과를 내려 볼 때 새로
            // 나타난 칸은 차례가 이미 지났으면 빛을 주지 않는다 — 내릴 때마다 다시 반짝이면 어수선하다.
            guard let shine, !reduceMotion else { return }
            let wait = shine.at.timeIntervalSinceNow
            guard wait > -0.1 else { return }
            try? await Task.sleep(for: .seconds(max(0, wait)))
            guard !Task.isCancelled else { return }
            withAnimation(.easeInOut(duration: shine.best ? 0.8 : 0.6)) { glint = 2 }
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
    case .promo:          return tierInk(0.55, 0.60, 0.70)   // 프로모
    case .doubleRare:     return .indigo
    case .tripleRare:     return .purple
    case .prismStar:      return tierInk(0.60, 0.55, 0.90)   // 프리즘스타
    case .amazing:        return tierInk(0.35, 0.80, 0.75)   // 어메이징
    case .radiant:        return tierInk(0.98, 0.78, 0.30)   // 찬란한 — 금빛
    case .characterRare:  return tierInk(0.30, 0.65, 0.85)   // 캐릭터레어
    case .artRare:        return .teal
    case .aceSpec:        return tierInk(0.90, 0.25, 0.35)   // ACE — 붉은 테두리
    case .superRare:      return .orange
    case .shiny:          return tierInk(0.55, 0.80, 0.95)   // 샤이니 — 은빛
    case .shinyUltra:     return tierInk(0.40, 0.70, 0.92)   // 샤이니 풀아트
    case .specialArtRare: return .pink
    case .shining:        return tierInk(0.95, 0.85, 0.55)   // 빛나는 포켓몬
    case .hyperRare:      return tierInk(0.75, 0.45, 0.95)   // 레인보우
    case .ultraRare:      return tierInk(1.00, 0.84, 0.04)   // 시스템 노랑의 다크 모드 값
    case .blackWhiteRare: return Color(white: 0.42)                          // 블랙볼트·화이트플레어
    case .megaAttack:     return tierInk(0.95, 0.40, 0.55)   // 메가어택레어
    case .megaUltraRare:  return tierInk(1.00, 0.55, 0.10)   // 메가 울트라레어
    case .futureUltra:    return tierInk(0.20, 0.85, 0.80)   // 퓨처울트라레어
    }
}

/// 등급 색을 바탕에 맞춘다. 다크 모드에서는 고른 색 그대로, 라이트 모드에서는 흰 바탕에서도
/// 읽히도록(굵은 글자 기준 3:1) 밝기만 낮춘다. 연노랑, 하늘색 등급 이름이 흰 바탕에서
/// 거의 보이지 않았다.
private func tierInk(_ red: Double, _ green: Double, _ blue: Double) -> Color {
    Color(nsColor: NSColor(name: nil) { appearance in
        let dark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
        let scale = dark ? 1 : min(1, tierInkScale(red, green, blue))
        return NSColor(srgbRed: red * scale, green: green * scale, blue: blue * scale, alpha: 1)
    })
}

/// 상대 휘도가 0.3 이하가 되는 배율. 흰 바탕과 3:1 이상이 된다.
private func tierInkScale(_ red: Double, _ green: Double, _ blue: Double) -> Double {
    func linear(_ value: Double) -> Double {
        value <= 0.04045 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
    }
    func luminance(_ scale: Double) -> Double {
        0.2126 * linear(red * scale) + 0.7152 * linear(green * scale) + 0.0722 * linear(blue * scale)
    }
    var scale = 1.0
    while luminance(scale) > 0.3 && scale > 0.3 { scale -= 0.02 }
    return scale
}
