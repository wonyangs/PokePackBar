import SwiftUI

// MARK: - 마켓

/// 마켓 — 사기, 팔기, 내 판매.
///
/// 예전 화면은 등록 폼, 검색, 장부, 글 목록을 한 화면에 쌓고, 전체 카드 목록에서 고른 뒤에야
/// 「거래 가능 0장」을 알려 줬다. 지금은 할 일마다 화면을 나누고, 팔 수 있는 카드만 보여 준다.
/// 서버 경로와 보내는 값은 그대로다.
@MainActor
struct OnlineMarketView: View {
    @Bindable var model: OnlineHubModel
    @State private var mode: Mode = .buy
    @State private var buying: [String: Any]?
    @State private var selling: OnlineStock?
    @State private var sellQuery = ""
    @State private var preview: PrintingSelection?
    /// 수락하려는 받은 가격 제안. 되돌릴 수 없는 판매라 한 번 더 묻는다.
    @State private var acceptingOffer: [String: Any]?

    enum Mode: String, CaseIterable, Identifiable {
        case buy, sell, mine, offers
        var id: String { rawValue }
        @MainActor var title: String {
            switch self {
            case .buy: OnlineText.l.marketBuy
            case .sell: OnlineText.l.marketSell
            case .mine: OnlineText.l.mySales
            case .offers: OnlineText.l.sentOffers
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Picker("", selection: $mode) {
                ForEach(Mode.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented).labelsHidden().fixedSize()
            .onChange(of: mode) {
                model.offset = 0
                model.ownListings = mode == .mine
                model.sentOffers = mode == .offers
                if mode != .sell { Task { await model.refresh(full: false) } }
            }

            switch mode {
            case .buy: buyView
            case .sell: sellView
            case .mine: mineView
            case .offers: offersView
            }
        }
        .onAppear {
            enter()
            model.ownListings = mode == .mine
            model.sentOffers = mode == .offers
        }
        // 마켓 탭이 이미 열려 있을 때 알림을 누른 경우.
        .onChange(of: model.opensMyListings) { enter() }
        .onChange(of: model.opensMarketBuy) { enter() }
        .onChange(of: model.opensMarketSell) { enter() }
        .onChange(of: model.opensSentOffers) { enter() }
        .sheet(item: Binding(get: { acceptingOffer.map(ListingBox.init) }, set: { acceptingOffer = $0?.item })) { box in
            acceptOfferSheet(box.item)
        }
        .sheet(item: Binding(get: { buying.map(ListingBox.init) }, set: { buying = $0?.item })) { box in
            BuySheet(model: model, item: box.item)
        }
        .sheet(item: $selling) { stock in SellSheet(model: model, stock: stock) }
        .sheet(item: $preview) { OnlinePrintingDetail(printing: $0.id) }
    }

    /// 알림이 정해 준 화면으로 들어간다. 판매 알림은 「내 판매」, 위시리스트 알림은 「사기」.
    /// 카드 상세의 「마켓에 팔기」는 「팔기」에서 그 카드를 찾아 두고, 판형이 하나뿐이면 판매 창까지 연다.
    private func enter() {
        if model.opensMyListings {
            model.opensMyListings = false
            mode = .mine
        } else if model.opensMarketBuy {
            model.opensMarketBuy = false
            mode = .buy
        } else if model.opensSentOffers {
            model.opensSentOffers = false
            mode = .offers
        } else if let cardID = model.opensMarketSell {
            model.opensMarketSell = nil
            mode = .sell
            sellQuery = OnlineText.cardName(cardID)
            let stock = OnlineStock.sellable(wallet: model.wallet).filter { $0.cardID == cardID }
            if stock.count == 1 { selling = stock[0] }
        }
    }

    // MARK: 사기

    private var buyView: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 좁은 창이나 긴 언어에서는 검색창과 「내게 없는 카드만」을 윗줄로 올린다.
            // 한 줄에 다 넣으면 정렬 칸이 창 밖으로 밀리고 화면 전체가 옆으로 밀린다.
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 10) { searchField; filterPickers; missingToggle }
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 10) { searchField; missingToggle }
                    HStack(spacing: 10) { filterPickers }
                }
            }
            .onChange(of: model.marketSet) { reload() }
            .onChange(of: model.marketTier) { reload() }
            .onChange(of: model.marketSort) { reload() }
            .onChange(of: model.marketSeller) { reload() }
            .onChange(of: model.marketMissing) { reload() }
            .task(id: model.search) {
                // 치는 대로 찾는다. 글자마다 서버에 묻지 않도록 잠깐 멈춘 뒤에만.
                try? await Task.sleep(for: .milliseconds(450))
                guard !Task.isCancelled else { return }
                model.offset = 0
                await model.refresh(full: false)
            }

            let listings = model.items("listings")
            ScrollViewReader { scroller in
            ScrollView {
                Group {
                if listings.isEmpty {
                    OnlineEmptyState(icon: "bag",
                                     title: hasFilter ? OnlineText.l.noListingsMatch : OnlineText.l.noListingsYet,
                                     message: hasFilter ? OnlineText.l.narrowFilters : OnlineText.l.listingsAppearHere)
                } else {
                    // 표시가 붙은 칸과 없는 칸의 높이가 달라도 카드 윗선은 맞춘다.
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 128), spacing: 16, alignment: .top)], alignment: .leading, spacing: 18) {
                        ForEach(listings, id: \.onlineID) { item in
                            let printing = CardPrintingKey(storageKey: item.string("printing"))
                            // 내 판매도, 이미 한 장 산 봇 매물도 같은 판매 글 창을 연다. 할 수 있는 일만 다르다.
                            Button { buying = item } label: {
                                OnlineCardTile(cardID: printing.cardID, finish: printing.finish.rawValue,
                                               badge: Self.badge(item)) {
                                    Text(OnlineText.won(tokens: item.int("unit_tokens")))
                                        .font(Typography.bodySemibold).monospacedDigit()
                                    // 올린 값이 싼지 비싼지는 시세와 나란히 있어야 보인다. 예전에는 눌러서 열어야 알았다.
                                    Text(OnlineText.referenceWon(item.string("printing")).map { OnlineText.l.marketQuote(OnlineText.wonText($0)) }
                                         ?? OnlineText.l.noMarketPrice)
                                        .font(Typography.caption).foregroundStyle(.secondary).monospacedDigit().lineLimit(1)
                                    Text("\(Self.seller(item)), \(OnlineText.l.cardsCount(item.int("quantity")))")
                                        .font(Typography.caption).foregroundStyle(.secondary).lineLimit(1)
                                    if let offer = item["my_offer"] as? [String: Any] {
                                        Text(OnlineText.l.myOfferShort(OnlineText.won(tokens: offer.int("unit_tokens"))))
                                            .font(Typography.caption).foregroundStyle(Color.accentColor).lineLimit(1)
                                    }
                                    // 컬렉션에 한 장도 없는 카드. 판매자 표시(봇 매물 등)와 따로 한 줄을 쓴다.
                                    if !item.bool("mine"), model.wallet.cardCount(printing.cardID) == 0 {
                                        OnlineBadge(text: OnlineText.l.missingBadge, color: .accentColor)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                            .onlineFocusRing(model.focusID == item.string("id"), cornerRadius: 8, outset: 5)
                        }
                    }
                    .padding(.vertical, 4)
                    OnlinePagination(model: model, key: "listings")
                }
                }
                .padding(.horizontal, OnlineFocus.gutter)
            }
            .padding(.horizontal, -OnlineFocus.gutter)
            .revealsOnlineFocus(model, in: listings, with: scroller)
            }
        }
    }

    /// 판매 글 아래의 표시. 내 판매, 로테이션(서버가 올린 카드), 그중 이미 산 것.
    static func badge(_ item: [String: Any]) -> (text: String, color: Color)? {
        if item.bool("mine") { return (OnlineText.l.mySales, .accentColor) }
        guard item.bool("rotation") else { return nil }
        return item.bool("bought") ? (OnlineText.l.rotationBought, .secondary) : (OnlineText.l.rotationBadge, .orange)
    }

    /// 판매자 이름. 로테이션은 파는 사람이 없어 서버가 이름을 비워 보내고, 화면이 언어에 맞춰 적는다.
    static func seller(_ item: [String: Any]) -> String {
        item.bool("rotation") ? OnlineText.l.rotationSeller : item.string("nickname")
    }

    private var hasFilter: Bool {
        !model.search.isEmpty || !model.marketSet.isEmpty || !model.marketTier.isEmpty || !model.marketFinish.isEmpty
            || !model.marketSeller.isEmpty || model.marketMissing
    }

    private var searchField: some View {
        TextField(OnlineText.l.searchByCardName, text: $model.search)
            .textFieldStyle(.roundedBorder).frame(maxWidth: 260)
            .onSubmit { reload() }
    }

    /// 세트, 등급, 판매자, 정렬. 판매자는 트레이너가 올린 것과 봇 매물(서버가 매일 올리는 로테이션)을 가른다.
    @ViewBuilder
    private var filterPickers: some View {
        Picker(OnlineText.l.setLabel, selection: $model.marketSet) {
            Text(OnlineText.l.allSetsOption).tag("")
            ForEach(CardIndex.shared?.sets ?? [], id: \.id) { Text($0.name).tag($0.id) }
        }
        .labelsHidden().fixedSize()
        Picker(OnlineText.l.tierLabel, selection: $model.marketTier) {
            Text(OnlineText.l.allTiers).tag("")
            ForEach(CardIndex.shared?.presentTiers ?? [], id: \.self) { tier in
                Text("\(tier.rawValue) \(OnlineText.l.tierName(tier))").tag(tier.rawValue)
            }
        }
        .labelsHidden().fixedSize()
        Picker(OnlineText.l.sellerLabel, selection: $model.marketSeller) {
            Text(OnlineText.l.allSellers).tag("")
            Text(OnlineText.l.trainerListings).tag("players")
            Text(OnlineText.l.botListings).tag("bot")
        }
        .labelsHidden().fixedSize()
        Picker(OnlineText.l.sortLabel, selection: $model.marketSort) {
            Text(OnlineText.l.sortNewest).tag("newest")
            Text(OnlineText.l.sortPrice).tag("price")
        }
        .labelsHidden().fixedSize()
    }

    /// 서버가 거른다. 한 쪽씩 받아 앱에서 거르면 다음 쪽에 있는 카드가 빠진다.
    private var missingToggle: some View {
        Toggle(OnlineText.l.missingOnlyToggle, isOn: $model.marketMissing)
            .toggleStyle(.checkbox).fixedSize()
    }

    // MARK: 팔기

    private var sellView: some View {
        let all = OnlineStock.sellable(wallet: model.wallet)
        let needle = DexCardSearch.normalized(sellQuery)
        let stock = needle.isEmpty ? all : all.filter {
            DexCardSearch.names(cardID: $0.cardID).contains { $0.contains(needle) }
        }
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                TextField(OnlineText.l.searchMyCards, text: $sellQuery)
                    .textFieldStyle(.roundedBorder).frame(maxWidth: 260)
                Spacer()
                Text(OnlineText.l.sellHint)
                    .font(Typography.label).foregroundStyle(.secondary)
            }
            ScrollView {
                if stock.isEmpty {
                    OnlineEmptyState(icon: "square.stack",
                                     title: sellQuery.isEmpty ? OnlineText.l.noSellableCards : OnlineText.l.noMatchingCards,
                                     message: sellQuery.isEmpty ? OnlineText.l.spareCardsHint : nil)
                } else {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 128), spacing: 16)], alignment: .leading, spacing: 18) {
                        ForEach(stock) { item in
                            Button { selling = item } label: {
                                OnlineCardTile(cardID: item.cardID, finish: item.finish.rawValue) {
                                    Text(OnlineText.l.sellableCount(item.available))
                                        .font(Typography.caption).foregroundStyle(.secondary)
                                    if let won = item.referenceWon {
                                        Text(OnlineText.l.marketQuote(OnlineText.wonText(won)))
                                            .font(Typography.caption).foregroundStyle(.secondary).monospacedDigit()
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                            .disabled(!model.canWrite)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }

    // MARK: 내 판매

    private var mineView: some View {
        let listings = model.items("listings")
        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 18) {
                Label(OnlineText.l.earned(OnlineText.won(tokens: model.wallet.state.marketEarnedTokens)), systemImage: "arrow.down.circle")
                Label(OnlineText.l.spent(OnlineText.won(tokens: model.wallet.state.marketSpentTokens)), systemImage: "arrow.up.circle")
            }
            .font(Typography.label).foregroundStyle(.secondary).monospacedDigit()
            ScrollViewReader { scroller in
            ScrollView {
                if listings.isEmpty {
                    OnlineEmptyState(icon: "tag", title: OnlineText.l.noOwnListings,
                                     message: OnlineText.l.listFromSell)
                } else {
                    VStack(spacing: 10) {
                        ForEach(listings, id: \.onlineID) { item in
                            myListing(item)
                                .onlineFocusRing(model.focusID == item.string("id"))
                                .id(item.onlineID)
                        }
                    }
                    OnlinePagination(model: model, key: "listings")
                }
            }
            .revealsOnlineFocus(model, in: listings, with: scroller)
            }
        }
    }

    private func myListing(_ item: [String: Any]) -> some View {
        let printing = CardPrintingKey(storageKey: item.string("printing"))
        let status = OnlineText.listingStatus(item.string("status"))
        let offers = model.items("offersReceived").filter { $0.string("listing_id") == item.string("id") }
        return VStack(alignment: .leading, spacing: 10) {
        HStack(spacing: 14) {
            CardImageView(cardID: printing.cardID, width: 54)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Text(OnlineText.cardName(printing.cardID)).font(Typography.bodySemibold)
                    OnlineBadge(text: status.text, color: status.color)
                }
                Text(OnlineText.l.myListingLine(finish: OnlineText.l.cardFinishName(printing.finish), unit: OnlineText.won(tokens: item.int("unit_tokens")), left: item.int("quantity")))
                    .font(Typography.label).foregroundStyle(.secondary).monospacedDigit()
                if item.string("status") == "active" {
                    Text(OnlineText.remaining(until: item.int("expires_at")))
                        .font(Typography.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
            if item.string("status") == "active", item.bool("mine") {
                Button(OnlineText.l.takeDownListing) {
                    Task { await model.mutate("market/listings", ["action": "listing_cancel", "target_id": item.string("id"), "target_version": item.int("version")]) }
                }
                .disabled(!model.canWrite)
            }
        }
        // 이 판매 글에 온 가격 제안. 판매가 대비 몇 %인지 함께 보고 수락하거나 거절한다.
        if !offers.isEmpty {
            Divider()
            Text(OnlineText.l.offersReceived(offers.count)).font(Typography.labelSemibold)
            ForEach(offers, id: \.onlineID) { offer in
                HStack(spacing: 8) {
                    Text(OnlineText.l.offerRow(offer.string("nickname"), quantity: offer.int("quantity"),
                                               price: OnlineText.won(tokens: offer.int("unit_tokens")),
                                               percent: offer.int("unit_tokens") * 100 / max(1, item.int("unit_tokens"))))
                        .font(Typography.label).monospacedDigit()
                    Spacer()
                    Text(OnlineText.remaining(until: offer.int("expires_at")))
                        .font(Typography.caption).foregroundStyle(.secondary)
                    Button(OnlineText.l.declineAction) {
                        Task { await model.mutate("market/offers", ["action": "offer_reject", "target_id": offer.string("id"), "target_version": offer.int("version")]) }
                    }
                    Button(OnlineText.l.acceptAction) { acceptingOffer = offer }.buttonStyle(.borderedProminent)
                }
                .disabled(!model.canWrite)
                .onlineFocusRing(model.focusID == offer.string("id"), cornerRadius: 6, outset: 3)
            }
        }
        }
        .padding(10)
        .background(Color.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))
    }

    /// 받은 가격 제안을 수락하기 전에 한 번 더 묻는다. 수락하면 바로 팔려 되돌릴 수 없다.
    private func acceptOfferSheet(_ offer: [String: Any]) -> some View {
        let printing = CardPrintingKey(storageKey: offer.string("printing"))
        let unit = offer.int("unit_tokens"), quantity = offer.int("quantity")
        return OnlineSheet(title: OnlineText.l.acceptOfferTitle, actionTitle: OnlineText.l.acceptAction,
                           actionDisabled: !model.canWrite,
                           note: OnlineText.l.acceptOfferNote(quantity: quantity, price: OnlineText.won(tokens: unit),
                                                              total: OnlineText.won(tokens: unit * quantity)),
                           action: {
                               let values: [String: Any] = ["action": "offer_accept", "target_id": offer.string("id"), "target_version": offer.int("version")]
                               Task { await model.mutate("market/offers", values) }
                           }) {
            HStack(alignment: .top, spacing: 14) {
                CardImageView(cardID: printing.cardID, width: 90)
                VStack(alignment: .leading, spacing: 6) {
                    Text(OnlineText.cardName(printing.cardID)).font(Typography.title)
                    Text(OnlineText.l.offerRow(offer.string("nickname"), quantity: quantity, price: OnlineText.won(tokens: unit),
                                               percent: unit * 100 / max(1, offer.int("listing_unit_tokens"))))
                        .font(Typography.label).foregroundStyle(.secondary).monospacedDigit()
                }
            }
        }
    }

    // MARK: 보낸 제안

    private var offersView: some View {
        let offers = model.items("offersSent")
        return ScrollViewReader { scroller in
            ScrollView {
                if offers.isEmpty {
                    OnlineEmptyState(icon: "tag", title: OnlineText.l.noSentOffers, message: OnlineText.l.noSentOffersHint)
                } else {
                    VStack(spacing: 10) {
                        ForEach(offers, id: \.onlineID) { offer in
                            sentOffer(offer)
                                .onlineFocusRing(model.focusID == offer.string("id"))
                                .id(offer.onlineID)
                        }
                    }
                    OnlinePagination(model: model, key: "offersSent")
                }
            }
            .revealsOnlineFocus(model, in: offers, with: scroller)
        }
    }

    private func sentOffer(_ item: [String: Any]) -> some View {
        let printing = CardPrintingKey(storageKey: item.string("printing"))
        let status = OnlineText.offerStatus(item.string("status"))
        let pending = item.string("status") == "pending"
        return HStack(spacing: 14) {
            CardImageView(cardID: printing.cardID, width: 54)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Text(OnlineText.cardName(printing.cardID)).font(Typography.bodySemibold)
                    OnlineBadge(text: status.text, color: status.color)
                }
                Text(OnlineText.l.sentOfferLine(price: OnlineText.won(tokens: item.int("unit_tokens")),
                                                asking: OnlineText.won(tokens: item.int("listing_unit_tokens")),
                                                count: OnlineText.l.cardsCount(item.int("quantity"))))
                    .font(Typography.label).foregroundStyle(.secondary).monospacedDigit()
                Text(OnlineText.l.soldBy(finish: OnlineText.l.cardFinishName(printing.finish), seller: item.string("nickname")))
                    .font(Typography.caption).foregroundStyle(.secondary)
                if pending {
                    Text(OnlineText.remaining(until: item.int("expires_at")))
                        .font(Typography.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
            if pending {
                Button(OnlineText.l.cancelOffer) {
                    Task { await model.mutate("market/offers", ["action": "offer_cancel", "target_id": item.string("id")]) }
                }
                .disabled(!model.canWrite)
            }
        }
        .padding(10)
        .background(Color.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))
    }

    private func reload() { model.offset = 0; Task { await model.refresh(full: false) } }
}

/// `[String: Any]` 를 시트에 넘기기 위한 상자.
private struct ListingBox: Identifiable {
    let item: [String: Any]
    var id: String { item.onlineID }
}

@MainActor
struct BuySheet: View {
    @Bindable var model: OnlineHubModel
    let item: [String: Any]
    @State private var quantity = 1
    /// 가격 제안으로 보내는지. 봇 매물은 하루 동안 정해진 값에만 팔아 바로 사기만 있다.
    @State private var offering: Bool

    /// 이 판매 글로 할 수 있는 일. 남의 글은 사거나 제안하고, 내 글은 내리고,
    /// 이미 한 장 산 봇 매물은 보기만 한다. 창의 모양은 셋 다 같다.
    private enum Role { case buyer, seller, viewer }
    private var role: Role { item.bool("mine") ? .seller : item.bool("bought") ? .viewer : .buyer }
    @State private var offerWon = 0

    /// `startsOffering` 은 레이아웃 감사가 제안 화면을 찍을 때 쓴다.
    init(model: OnlineHubModel, item: [String: Any], startsOffering: Bool = false) {
        self.model = model
        self.item = item
        _offering = State(initialValue: startsOffering)
    }

    private var unit: Int { item.int("unit_tokens") }
    private var rotation: Bool { item.bool("rotation") }
    private var askingWon: Int { MarketEconomy.won(tokens: unit) }
    private var myOffer: [String: Any]? { item["my_offer"] as? [String: Any] }
    /// 보낼 제안의 장당 토큰. 서버와 같은 규칙으로 판매가보다 낮고 절반 이상일 때만 값이 있다.
    private var offerTokens: Int? {
        guard let tokens = OnlineText.tokens(won: offerWon), tokens < unit, tokens * 2 >= unit else { return nil }
        return tokens
    }
    /// 보낼 수 있는 범위(원): 판매가의 절반을 100원 칸으로 올린 값부터 판매가보다 한 칸 낮은 값까지.
    private var offerRange: (low: Int, high: Int) {
        let step = MarketEconomy.wonStep
        return (low: ((askingWon + 1) / 2 + step - 1) / step * step, high: askingWon - step)
    }
    /// 판매가의 몇 %로 맞추는 칩. 범위 밖이면 범위 끝으로 붙인다.
    private func chipWon(_ percent: Int) -> Int {
        let step = MarketEconomy.wonStep
        return min(max(askingWon * percent / 100 / step * step, offerRange.low), offerRange.high)
    }

    var body: some View {
        let printing = CardPrintingKey(storageKey: item.string("printing"))
        let affordable = unit > 0 ? model.wallet.availableTokens / unit : 0
        // 로테이션 카드는 계정마다 한 장이다. 수량을 고를 수 없다.
        let maximum = rotation ? 1 : max(1, min(item.int("quantity"), 1000, offering ? 1000 : affordable))
        let total = (offering ? offerTokens ?? 0 : unit) * quantity
        let canAfford = total <= model.wallet.availableTokens
        let blocked = offering ? offerTokens == nil || !canAfford : !canAfford || affordable < 1
        let role = self.role
        let buying = role == .buyer
        OnlineSheet(title: !buying ? OnlineText.l.listingDetailTitle
                           : offering ? OnlineText.l.makeOfferTitle : OnlineText.l.buyCardTitle,
                    actionTitle: role == .seller ? OnlineText.l.takeDownListing
                                 : offering ? OnlineText.l.sendOffer(OnlineText.won(tokens: offerTokens ?? 0))
                                 : OnlineText.l.buyFor(OnlineText.won(tokens: total)),
                    actionDisabled: !model.canWrite || (buying && blocked),
                    note: !buying ? nil : offering ? OnlineText.l.offerNote : rotation ? OnlineText.l.rotationBuyNote : OnlineText.l.buyNote,
                    showsAction: role != .viewer,
                    action: {
                        // 보낼 값은 누르는 순간 정한다. Task 본문은 시트가 닫힌 뒤에 돈다.
                        if role == .seller {
                            let values: [String: Any] = ["action": "listing_cancel", "target_id": item.string("id"), "target_version": item.int("version")]
                            Task { await model.mutate("market/listings", values) }
                        } else if offering, let offerTokens {
                            let values: [String: Any] = ["action": "offer_create", "target_id": item.string("id"), "quantity": quantity, "unit_tokens": offerTokens]
                            Task { await model.mutate("market/offers", values) }
                        } else {
                            let values: [String: Any] = ["action": "listing_buy", "target_id": item.string("id"), "target_version": item.int("version"), "quantity": quantity, "unit_tokens": unit]
                            Task { await model.mutate("market/listings", values) }
                        }
                    }) {
            VStack(alignment: .leading, spacing: 14) {
                if buying, !rotation {
                    Picker("", selection: $offering) {
                        Text(OnlineText.l.buyNow).tag(false)
                        Text(OnlineText.l.makeOffer).tag(true)
                    }
                    .pickerStyle(.segmented).labelsHidden().fixedSize()
                }
                HStack(alignment: .top, spacing: 18) {
                    // 마우스로 기울이고 좌우로 끌어 뒷면까지 돌려 본다. 내 글이든 남의 글이든 같다.
                    OnlinePrintingArt(printing: item.string("printing"), width: 180)
                    VStack(alignment: .leading, spacing: 10) {
                        Text(OnlineText.cardName(printing.cardID)).font(Typography.title)
                        // 어느 팩에서 나오고 얼마나 드문지. 사지 않고 팩을 열어 노릴지 정할 수 있다.
                        if let index = CardIndex.shared,
                           let source = CardSource.of(cardID: printing.cardID, index: index,
                                                      perks: model.wallet.openingPerks) {
                            CardSourceLine(source: source, l: OnlineText.l)
                        }
                        Text(OnlineText.l.soldBy(finish: OnlineText.l.cardFinishName(printing.finish), seller: OnlineMarketView.seller(item)))
                            .font(Typography.label).foregroundStyle(.secondary)
                        Text(OnlineText.l.perCard(OnlineText.won(tokens: unit))).font(Typography.bodySemibold).monospacedDigit()
                        // 이미 가진 카드인지 사기 전에 본다.
                        let owned = model.wallet.cardCount(printing.cardID)
                        Text(owned == 0 ? OnlineText.l.notOwnedYet : OnlineText.l.copiesOwned(owned))
                            .font(Typography.label).monospacedDigit()
                            .foregroundStyle(owned == 0 ? Color.accentColor : Color.secondary)
                        if let reference = OnlineText.referenceWon(item.string("printing")) {
                            Text(OnlineText.l.referencePrice(OnlineText.wonText(reference)))
                                .font(Typography.label).foregroundStyle(.secondary).monospacedDigit()
                        }
                        switch role {
                        case .seller:
                            Text(OnlineText.l.myListingLine(finish: OnlineText.l.cardFinishName(printing.finish),
                                                            unit: OnlineText.won(tokens: unit), left: item.int("quantity")))
                                .font(Typography.label).foregroundStyle(.secondary).monospacedDigit()
                            Text(OnlineText.remaining(until: item.int("expires_at")))
                                .font(Typography.label).foregroundStyle(.secondary)
                        case .viewer:
                            Text(OnlineText.l.rotationBought).font(Typography.labelSemibold)
                            Text(OnlineText.remaining(until: item.int("expires_at")))
                                .font(Typography.label).foregroundStyle(.secondary)
                        case .buyer:
                            if offering { offerFields }
                            if rotation {
                                Text(OnlineText.remaining(until: item.int("expires_at")))
                                    .font(Typography.label).foregroundStyle(.secondary)
                            } else {
                                OnlineQuantity(value: $quantity, range: 1...maximum)
                            }
                            Text(!canAfford || (!offering && affordable < 1) ? OnlineText.l.notEnoughBalance
                                 : OnlineText.l.balanceAfter(OnlineText.won(tokens: max(0, model.wallet.availableTokens - total))))
                                .font(Typography.label).foregroundStyle(!canAfford ? Color.orange : Color.secondary)
                                .monospacedDigit()
                        }
                    }
                }
            }
        }
        .onAppear {
            offerWon = myOffer.map { MarketEconomy.won(tokens: $0.int("unit_tokens")) } ?? chipWon(90)
        }
    }

    /// 제안할 장당 가격. 판매가의 몇 %인지 칩으로 고르거나 직접 적는다.
    @ViewBuilder
    private var offerFields: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let myOffer {
                Text(OnlineText.l.myOffer(OnlineText.won(tokens: myOffer.int("unit_tokens"))))
                    .font(Typography.label).foregroundStyle(Color.accentColor)
            }
            Text(OnlineText.l.pricePerCard).font(Typography.labelSemibold)
            HStack(spacing: 6) {
                TextField(OnlineText.l.priceLabel, value: $offerWon, format: .number)
                    .textFieldStyle(.roundedBorder).frame(width: 120).monospacedDigit()
                Text(OnlineText.l.wonUnit)
            }
            HStack(spacing: 6) {
                // 칩은 숫자만 적는다. 「판매가의」를 붙이면 좁은 창에서 잘린다. 뜻은 도움말에 둔다.
                ForEach([90, 80, 70], id: \.self) { percent in
                    Button("\(percent)%") { offerWon = chipWon(percent) }
                        .buttonStyle(.bordered).font(Typography.button).monospacedDigit()
                        .help(OnlineText.l.percentOfPrice(percent))
                }
            }
            Text(OnlineText.l.offerRange(min: OnlineText.wonText(offerRange.low), max: OnlineText.wonText(offerRange.high)))
                .font(Typography.caption).foregroundStyle(offerTokens == nil ? Color.red : Color.secondary)
        }
    }
}

@MainActor
private struct SellSheet: View {
    @Bindable var model: OnlineHubModel
    let stock: OnlineStock
    @State private var quantity = 1
    @State private var priceWon = 0

    var body: some View {
        let suggested = stock.referenceWon ?? MarketEconomy.wonStep
        let price = max(MarketEconomy.wonStep, (priceWon / MarketEconomy.wonStep) * MarketEconomy.wonStep)
        let listingTokens = OnlineText.tokens(won: price)
        OnlineSheet(title: OnlineText.l.sellCardTitle, actionTitle: OnlineText.l.postListing,
                    actionDisabled: !model.canWrite || priceWon < MarketEconomy.wonStep || listingTokens == nil,
                    note: OnlineText.l.sellNote(quantity: quantity, price: OnlineText.wonText(price)),
                    action: {
                        guard let listingTokens else { return }
                        let values: [String: Any] = ["action": "listing_create", "printing": stock.key, "quantity": quantity, "unit_tokens": listingTokens]
                        Task { await model.mutate("market/listings", values) }
                    }) {
            HStack(alignment: .top, spacing: 18) {
                OnlinePrintingArt(printing: stock.key, width: 180)
                VStack(alignment: .leading, spacing: 12) {
                    Text(OnlineText.cardName(stock.cardID)).font(Typography.title)
                    Text(OnlineText.l.sellableLine(finish: OnlineText.l.cardFinishName(stock.finish), available: stock.available))
                        .font(Typography.label).foregroundStyle(.secondary)
                    OnlineQuantity(value: $quantity, range: 1...min(1000, stock.available))
                    VStack(alignment: .leading, spacing: 6) {
                        Text(OnlineText.l.pricePerCard).font(Typography.labelSemibold)
                        HStack(spacing: 6) {
                            TextField(OnlineText.l.priceLabel, value: $priceWon, format: .number)
                                .textFieldStyle(.roundedBorder).frame(width: 120).monospacedDigit()
                            Text(OnlineText.l.wonUnit)
                        }
                        HStack(spacing: 6) {
                            priceChip(OnlineText.l.atMarketPrice, suggested)
                            priceChip(OnlineText.l.tenPercentLower, suggested * 9 / 10)
                            priceChip(OnlineText.l.tenPercentHigher, suggested * 11 / 10)
                        }
                        Text(stock.referenceWon.map { OnlineText.l.referenceStep(OnlineText.wonText($0)) } ?? OnlineText.l.noReferenceStep)
                            .font(Typography.caption).foregroundStyle(.secondary)
                        if listingTokens == nil {
                            Text(OnlineText.l.maximumPrice(OnlineText.wonText(OnlineText.maximumListingWon)))
                                .font(Typography.caption).foregroundStyle(.red)
                        }
                    }
                }
            }
        }
        .onAppear { if priceWon == 0 { priceWon = suggested } }
    }

    private func priceChip(_ title: String, _ won: Int) -> some View {
        let rounded = max(MarketEconomy.wonStep, (won / MarketEconomy.wonStep) * MarketEconomy.wonStep)
        return Button(title) { priceWon = rounded }
            .buttonStyle(.bordered).controlSize(.regular).font(Typography.button)
    }
}

// MARK: - 교환

/// 교환 — 친구를 고르고, 줄 카드와 받을 카드를 그림으로 담는다.
@MainActor
struct OnlineTradingView: View {
    @Bindable var model: OnlineHubModel
    @State private var friend = ""
    @State private var offered: [String: Int] = [:]
    @State private var requested: [String: Int] = [:]
    @State private var pickingOffer = false
    @State private var pickingRequest = false
    /// 친구 카드를 고르는 창을 「내게 없는 카드만」으로 열지.
    @State private var pickingMissingOnly = false
    @State private var confirming = false
    @State private var accepting: [String: Any]?
    @State private var preview: PrintingSelection?
    /// 역제안 중인 받은 제안. 있으면 위쪽 만들기 칸이 그 제안을 바꿔 되돌려 보낸다.
    @State private var countering: [String: Any]?
    /// 받고 싶은 카드는 고른 친구의 교환 바인더에서 담는다. 친구를 바꾸면 비우되, 초안이나
    /// 역제안이 친구와 카드를 함께 채울 때는 비우지 않는다.
    @State private var keepRequestOnFriendChange = false
    /// 교환에 얹는 돈(원). 카드 시세 차이를 돈으로 메운다. 한쪽에만 넣을 수 있다.
    @State private var giveWon = 0
    @State private var getWon = 0

    private var giveTokens: Int { giveWon > 0 ? OnlineText.tokens(won: giveWon) ?? 0 : 0 }
    private var getTokens: Int { getWon > 0 ? OnlineText.tokens(won: getWon) ?? 0 : 0 }

    private var friends: [[String: Any]] { model.items("friends").filter { $0.string("status") == "accepted" } }

    /// 왜 보낼 수 없는지를 한 문장으로. 버튼만 꺼 두면 무엇을 고쳐야 하는지 모른다.
    private var blocker: String? {
        if friend.isEmpty { return OnlineText.l.tradePickFriend }
        if giveWon > 0, getWon > 0 { return OnlineText.l.tradeMoneyOneSide }
        if (giveWon > 0 && giveTokens == 0) || (getWon > 0 && getTokens == 0) { return OnlineText.l.tradeMoneyInvalid }
        if offered.isEmpty, requested.isEmpty { return OnlineText.l.tradeNeedsCard }
        if offered.isEmpty, giveTokens == 0 { return OnlineText.l.tradeAddOffer }
        if requested.isEmpty, getTokens == 0 { return OnlineText.l.tradeAddRequest }
        // 돈은 묶어 두지 않는다. 보낼 때와 상대가 수락할 때 잔액을 확인한다.
        if giveTokens > model.wallet.availableTokens { return OnlineText.l.notEnoughBalance }
        if offered.count > 20 || requested.count > 20 { return OnlineText.l.tradeKindLimit }
        if offered.values.reduce(0, +) > 1000 || requested.values.reduce(0, +) > 1000 { return OnlineText.l.tradeCountLimit }
        if !Set(offered.keys).isDisjoint(with: requested.keys) { return OnlineText.l.tradeSameCard }
        return nil
    }

    var body: some View {
        ScrollViewReader { scroller in
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                OnlineSection(title: OnlineText.l.newTradeOffer, subtitle: OnlineText.l.newTradeOfferNote) {
                    if friends.isEmpty {
                        OnlineEmptyState(icon: "person.2", title: OnlineText.l.noFriendsYet,
                                         message: OnlineText.l.addFriendHint)
                    } else {
                        VStack(alignment: .leading, spacing: 16) {
                            if let countering {
                                HStack(spacing: 10) {
                                    Image(systemName: "arrow.triangle.2.circlepath").foregroundStyle(Color.accentColor)
                                    Text(OnlineText.l.counteringBanner(countering.string("nickname")))
                                        .font(Typography.label)
                                    Spacer()
                                    Button(OnlineText.l.stopCountering) { stopCountering() }
                                }
                                .padding(10)
                                .background(Color.accentColor.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
                            }
                            Picker(OnlineText.l.withWhom, selection: $friend) {
                                Text(OnlineText.l.chooseFriend).tag("")
                                ForEach(friends, id: \.onlineID) { Text($0.string("nickname")).tag($0.string("public_id")) }
                            }
                            .fixedSize()
                            .disabled(countering != nil)
                            tray(OnlineText.l.cardsIGive, lines: $offered, money: $giveWon,
                                 moneyTitle: OnlineText.l.moneyToGive) { pickingOffer = true }
                            // 바로 아래에 담을 카드가 놓이면 빈 칸을 높게 비워 둘 까닭이 없다.
                            tray(OnlineText.l.cardsIWant, lines: $requested, money: $getWon,
                                 moneyTitle: OnlineText.l.moneyToGet, canAdd: !friend.isEmpty,
                                 emptyHeight: missingFromFriend.isEmpty ? 60 : 0,
                                 add: { pickingMissingOnly = false; pickingRequest = true }) { missingCards }
                            if !offered.isEmpty || giveWon > 0, !requested.isEmpty || getWon > 0 {
                                Text(OnlineText.valueBalance(give: offered, get: requested, giveWon: giveWon, getWon: getWon))
                                    .font(Typography.label).foregroundStyle(.secondary)
                            }
                            HStack {
                                if let blocker {
                                    Text(blocker).font(Typography.label).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Button(countering == nil ? OnlineText.l.sendOffer : OnlineText.l.sendCounter) { confirming = true }
                                    .buttonStyle(.borderedProminent)
                                    .disabled(!model.canWrite || blocker != nil)
                            }
                        }
                    }
                }
                .id("composer")

                let matches = model.items("matches")
                if !matches.isEmpty {
                    OnlineSection(title: OnlineText.l.mutualMatches, subtitle: OnlineText.l.mutualMatchesNote) {
                        VStack(spacing: 8) {
                            ForEach(matches, id: \.onlineID) { item in
                                HStack {
                                    Text(item.string("nickname")).font(Typography.bodySemibold)
                                    Text(OnlineText.l.matchSummary(give: (item["offered"] as? [Any])?.count ?? 0, get: (item["requested"] as? [Any])?.count ?? 0))
                                        .font(Typography.label).foregroundStyle(.secondary)
                                    Spacer()
                                    Button(OnlineText.l.draftFromMatch) { loadDraft(item) }.disabled(!model.canWrite)
                                }
                            }
                        }
                    }
                }

                let trades = model.items("trades")
                let waiting = trades.filter { $0.string("status") == "pending" && $0.bool("incoming") }
                if !waiting.isEmpty {
                    OnlineSection(title: OnlineText.l.offersToAnswer) {
                        VStack(spacing: 10) {
                            ForEach(waiting, id: \.onlineID) { item in
                                trade(item) {
                                    startCounter(item)
                                    withAnimation { scroller.scrollTo("composer", anchor: .top) }
                                }
                            }
                        }
                    }
                }
                OnlineSection(title: OnlineText.l.tradeHistory) {
                    let rest = trades.filter { !($0.string("status") == "pending" && $0.bool("incoming")) }
                    if rest.isEmpty {
                        Text(OnlineText.l.noTradesYet).font(Typography.label).foregroundStyle(.secondary)
                    } else {
                        VStack(spacing: 10) { ForEach(rest, id: \.onlineID) { trade($0) } }
                        OnlinePagination(model: model, key: "trades")
                    }
                }
            }
            .padding(.bottom, 12)
        }
        .revealsOnlineFocus(model, in: model.items("trades"), with: scroller)
        }
        .onAppear { if let draft = model.tradeDraft { loadDraft(draft); model.tradeDraft = nil } }
        .onChange(of: friend) {
            if keepRequestOnFriendChange { keepRequestOnFriendChange = false } else { requested = [:] }
        }
        .sheet(isPresented: $pickingOffer) {
            OnlineStockPicker(wallet: model.wallet, title: OnlineText.l.addCardsToGive, actionTitle: OnlineText.l.addAction,
                              alreadyPicked: offered) { key, quantity in offered[key, default: 0] += quantity }
        }
        // 친구를 고르면 그 친구에게 남는 카드를 받아 둔다. 「내게 없는 카드」를 창을 열지 않고 보여 준다.
        .task(id: friend) { await model.loadFriendBinder(friend) }
        .sheet(isPresented: $pickingRequest) {
            FriendTradeBinderPicker(model: model, friendID: friend, alreadyPicked: requested,
                                    startsMissingOnly: pickingMissingOnly) { key, quantity in
                requested[key, default: 0] += quantity
            }
        }
        .sheet(isPresented: $confirming) {
            OnlineSheet(title: countering == nil ? OnlineText.l.confirmOffer : OnlineText.l.confirmCounter,
                        actionTitle: countering == nil ? OnlineText.l.sendOffer : OnlineText.l.sendCounter,
                        actionDisabled: !model.canWrite || blocker != nil,
                        note: countering == nil ? OnlineText.l.confirmOfferNote : OnlineText.l.confirmCounterNote,
                        action: {
                            // 보낼 카드는 누르는 순간 정한다. Task 본문은 이 블록이 끝난 뒤에 돌아서,
                            // 그 안에서 바구니를 읽으면 이미 비운 빈 바구니가 나가 서버가
                            // both_sides_required 로 거절했다. 바구니는 성공했을 때만 비운다.
                            var values: [String: Any] = ["action": "trade_create", "target_id": friend, "offered": lines(offered), "requested": lines(requested)]
                            // 돈은 넣었을 때만 보낸다. 돈을 모르는 서버는 모르는 값이 있으면 요청을
                            // 통째로 거절해서, 0 을 보내면 돈 없는 교환까지 막힌다.
                            if giveTokens > 0 { values["offered_tokens"] = giveTokens }
                            if getTokens > 0 { values["requested_tokens"] = getTokens }
                            if let countering {
                                values.merge(["action": "trade_counter", "target_id": countering.string("id"),
                                              "target_version": countering.int("version")]) { _, new in new }
                            }
                            Task {
                                if await model.mutate("trades", values) { offered = [:]; requested = [:]; giveWon = 0; getWon = 0; countering = nil }
                            }
                        }) {
                VStack(alignment: .leading, spacing: 10) {
                    Text(OnlineText.l.toFriend(friendName(friend))).font(Typography.bodySemibold)
                    Text(OnlineText.l.cardsIGive).font(Typography.labelSemibold)
                    OnlineCardStrip(lines: offered)
                    moneyLine(giveTokens)
                    Text(OnlineText.l.cardsIGet).font(Typography.labelSemibold)
                    OnlineCardStrip(lines: requested)
                    moneyLine(getTokens)
                    Text(OnlineText.valueBalance(give: offered, get: requested, giveWon: giveWon, getWon: getWon))
                        .font(Typography.label).foregroundStyle(.secondary)
                }
            }
        }
        .sheet(item: Binding(get: { accepting.map(ListingBox.init) }, set: { accepting = $0?.item })) { box in
            let item = box.item
            OnlineSheet(title: OnlineText.l.acceptTradeQuestion, actionTitle: OnlineText.l.acceptAction,
                        actionDisabled: !model.canWrite,
                        note: OnlineText.l.acceptTradeNote,
                        action: { act("trade_accept", item) }) {
                VStack(alignment: .leading, spacing: 10) {
                    Text(OnlineText.l.tradeWith(item.string("nickname"))).font(Typography.bodySemibold)
                    Text(OnlineText.l.cardsIGive).font(Typography.labelSemibold)
                    OnlineCardStrip(lines: item["requested"] as? [String: Int] ?? [:])
                    moneyLine(item.int("requested_tokens"))
                    Text(OnlineText.l.cardsIGet).font(Typography.labelSemibold)
                    OnlineCardStrip(lines: item["offered"] as? [String: Int] ?? [:])
                    moneyLine(item.int("offered_tokens"))
                    Text(OnlineText.valueBalance(give: item["requested"] as? [String: Int] ?? [:],
                                                 get: item["offered"] as? [String: Int] ?? [:],
                                                 giveWon: MarketEconomy.won(tokens: item.int("requested_tokens")),
                                                 getWon: MarketEconomy.won(tokens: item.int("offered_tokens"))))
                        .font(Typography.label).foregroundStyle(.secondary)
                }
            }
        }
        .sheet(item: $preview) { OnlinePrintingDetail(printing: $0.id) }
    }

    private func tray(_ title: String, lines: Binding<[String: Int]>, money: Binding<Int>, moneyTitle: String,
                      canAdd: Bool = true, add: @escaping () -> Void) -> some View {
        tray(title, lines: lines, money: money, moneyTitle: moneyTitle, canAdd: canAdd, add: add) { EmptyView() }
    }

    /// `footer` 는 칸 아래에 붙는 것. 받고 싶은 카드 칸이 「내게 없는 카드」를 여기에 둔다.
    private func tray<Footer: View>(_ title: String, lines: Binding<[String: Int]>, money: Binding<Int>,
                                    moneyTitle: String, canAdd: Bool = true,
                                    emptyHeight: CGFloat = 60, add: @escaping () -> Void,
                                    @ViewBuilder footer: () -> Footer) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title).font(Typography.labelSemibold)
                Text(OnlineText.traySummary(lines.wrappedValue))
                    .font(Typography.caption).foregroundStyle(.secondary).monospacedDigit()
                Spacer()
                Button { add() } label: { Label(OnlineText.l.addCards, systemImage: "plus") }
                    .disabled(lines.wrappedValue.count >= 20 || !canAdd)
            }
            if lines.wrappedValue.isEmpty {
                Text(OnlineText.l.trayEmpty).font(Typography.label).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: emptyHeight, alignment: .leading)
            } else {
                OnlineCardStrip(lines: lines.wrappedValue,
                                onRemove: { lines.wrappedValue[$0] = nil },
                                onOpen: { preview = PrintingSelection(id: $0) })
            }
            // 카드 시세 차이를 돈으로 메운다. 0 이면 돈은 오가지 않는다.
            HStack(spacing: 6) {
                Image(systemName: "wonsign.circle").foregroundStyle(.secondary)
                Text(moneyTitle).font(Typography.label)
                TextField("0", value: money, format: .number)
                    .textFieldStyle(.roundedBorder).frame(width: 120).monospacedDigit()
                Text(OnlineText.l.wonUnit).font(Typography.label)
            }
            footer()
        }
        .padding(12)
        .background(Color.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))
    }

    /// 한 줄에 그리는 「내게 없는 카드」의 수. 나머지는 고르는 창에서 본다.
    private static let missingShown = 24

    /// 받고 싶은 카드 칸 아래: 고른 친구에게 남는 카드 가운데 내 컬렉션에 한 장도 없는 것.
    ///
    /// 교환에서 가장 먼저 찾는 것이 「나는 없고 친구는 남는 카드」인데, 예전에는 친구의 교환 바인더를
    /// 열어 카드를 하나씩 내 컬렉션과 견줘야 알 수 있었다. 누르면 바로 받고 싶은 카드에 담긴다.
    private var missingFromFriend: [OnlineStock] {
        guard !friend.isEmpty, case .ready(let stock)? = model.friendBinders[friend] else { return [] }
        return FriendTradeBinder.missing(stock, owned: { model.wallet.cardCount($0) })
    }

    @ViewBuilder
    private var missingCards: some View {
        switch friend.isEmpty ? nil : model.friendBinders[friend] {
        case .ready(let stock)?:
            let missing = missingFromFriend
            Divider()
            if missing.isEmpty {
                Text(stock.isEmpty ? OnlineText.l.friendBinderEmpty
                                   : OnlineText.l.nothingMissingFromFriend(friendName(friend)))
                    .font(Typography.caption).foregroundStyle(.secondary)
            } else {
                HStack(spacing: 8) {
                    Text(OnlineText.l.missingFromFriendTitle).font(Typography.labelSemibold)
                    Text(OnlineText.l.missingFromFriendCount(friendName(friend), missing.count))
                        .font(Typography.caption).foregroundStyle(.secondary).monospacedDigit().lineLimit(1)
                    Spacer()
                    if missing.count > Self.missingShown {
                        Button(OnlineText.l.seeAllCards(missing.count)) {
                            pickingMissingOnly = true
                            pickingRequest = true
                        }
                        .buttonStyle(.link).font(Typography.label)
                    }
                }
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: 10) {
                        ForEach(missing.prefix(Self.missingShown)) { missingTile($0) }
                    }
                    .padding(.top, 6)
                }
            }
        case .hidden?:
            Divider()
            Text(OnlineText.l.friendBinderPrivate).font(Typography.caption).foregroundStyle(.secondary)
        case .loading?:
            Divider()
            HStack(spacing: 6) {
                ProgressView().controlSize(.small)
                Text(OnlineText.l.checkingFriendSpares).font(Typography.caption).foregroundStyle(.secondary)
            }
        default:
            // 지원하지 않는 서버나 실패는 고르는 창이 알린다. 여기서는 자리를 차지하지 않는다.
            EmptyView()
        }
    }

    private func missingTile(_ item: OnlineStock) -> some View {
        let picked = requested[item.key] != nil
        return Button {
            guard requested[item.key] == nil, requested.count < 20 else { return }
            requested[item.key] = 1
        } label: {
            VStack(spacing: 3) {
                ZStack(alignment: .topTrailing) {
                    CardImageView(cardID: item.cardID, width: 52)
                    // 담은 카드 줄의 빼기 표시와 짝이 되는 담기 표시. 담은 뒤에는 체크로 바뀐다.
                    Image(systemName: picked ? "checkmark.circle.fill" : "plus.circle.fill").font(.system(size: 16))
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.white, picked ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(.black.opacity(0.6)))
                        .offset(x: 5, y: -5)
                }
                Text(item.referenceWon.map(OnlineText.wonText) ?? OnlineText.l.noMarketPrice)
                    .font(Typography.caption).monospacedDigit().foregroundStyle(.secondary)
                    .lineLimit(1).minimumScaleFactor(0.7).frame(width: 60)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(picked || requested.count >= 20)
        .help(OnlineText.printingSummary(item.key))
        .accessibilityLabel(OnlineText.printingSummary(item.key))
        .accessibilityHint(OnlineText.l.addToWantedHint)
    }

    private func trade(_ item: [String: Any], counter: (() -> Void)? = nil) -> some View {
        let status = OnlineText.tradeStatus(item.string("status"))
        let incoming = item.bool("incoming")
        let theyGive = item["offered"] as? [String: Int] ?? [:]
        let iGive = item["requested"] as? [String: Int] ?? [:]
        let name = item.string("nickname")
        let isCounter = !item.string("counter_of").isEmpty
        let title = isCounter ? (incoming ? OnlineText.l.counterFrom(name) : OnlineText.l.counterTo(name))
            : (incoming ? OnlineText.l.offerFrom(name) : OnlineText.l.offerTo(name))
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text(title)
                    .font(Typography.bodySemibold)
                OnlineBadge(text: status.text, color: status.color)
                Spacer()
                if item.string("status") == "pending" {
                    Text(OnlineText.remaining(until: item.int("expires_at")))
                        .font(Typography.caption).foregroundStyle(.secondary)
                }
            }
            HStack(alignment: .top, spacing: 24) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(sideCaption(OnlineText.l.cardsIGive, incoming ? iGive : theyGive))
                        .font(Typography.caption).foregroundStyle(.secondary)
                    OnlineCardStrip(lines: incoming ? iGive : theyGive, width: 52, onOpen: { preview = PrintingSelection(id: $0) })
                    moneyLine(incoming ? item.int("requested_tokens") : item.int("offered_tokens"))
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(sideCaption(OnlineText.l.cardsIGet, incoming ? theyGive : iGive))
                        .font(Typography.caption).foregroundStyle(.secondary)
                    OnlineCardStrip(lines: incoming ? theyGive : iGive, width: 52, onOpen: { preview = PrintingSelection(id: $0) })
                    moneyLine(incoming ? item.int("offered_tokens") : item.int("requested_tokens"))
                }
            }
            if item.string("status") == "pending" {
                HStack {
                    Spacer()
                    if incoming {
                        Button(OnlineText.l.declineAction) { act("trade_reject", item) }
                        if let counter { Button(OnlineText.l.counterAction, action: counter) }
                        Button(OnlineText.l.acceptAction) { accepting = item }.buttonStyle(.borderedProminent)
                    } else {
                        Button(OnlineText.l.cancelOffer) { act("trade_cancel", item) }
                    }
                }
                .disabled(!model.canWrite)
            }
        }
        .padding(12)
        .background(Color.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))
        .onlineFocusRing(model.focusID == item.string("id"))
        .id(item.onlineID)
    }

    private func friendName(_ id: String) -> String {
        friends.first { $0.string("public_id") == id }?.string("nickname") ?? OnlineText.l.friendFallback
    }
    private func lines(_ values: [String: Int]) -> [[String: Any]] { values.keys.sorted().map { ["printing": $0, "quantity": values[$0] ?? 0] } }
    private func command(_ action: String, _ item: [String: Any]) -> [String: Any] { ["action": action, "target_id": item.string("id"), "target_version": item.int("version")] }
    private func act(_ action: String, _ item: [String: Any]) { Task { await model.mutate("trades", command(action, item)) } }
    /// 교환에 얹은 돈 한 줄. 없으면 아무것도 그리지 않는다.
    @ViewBuilder
    private func moneyLine(_ tokens: Int) -> some View {
        if tokens > 0 {
            Label(OnlineText.l.moneyLine(OnlineText.won(tokens: tokens)), systemImage: "wonsign.circle")
                .font(Typography.label).monospacedDigit()
        }
    }

    /// 한쪽 카드 줄의 제목에 시세 합계를 붙인다.
    private func sideCaption(_ title: String, _ lines: [String: Int]) -> String {
        let total = OnlineText.referenceTotal(lines)
        return total.won > 0 ? "\(title), \(OnlineText.l.marketQuote(OnlineText.wonText(total.won)))" : title
    }

    /// 받은 제안을 뒤집어 만들기 칸에 채운다. 상대가 원한 카드가 내가 줄 카드, 상대가 주려던
    /// 카드가 받을 카드다. 거기서 바꿔 보내면 원래 제안은 닫힌다.
    private func startCounter(_ item: [String: Any]) {
        let other = item.string("public_id")
        keepRequestOnFriendChange = friend != other
        friend = other
        offered = item["requested"] as? [String: Int] ?? [:]
        requested = item["offered"] as? [String: Int] ?? [:]
        // 상대가 달라던 돈은 내가 줄 돈, 상대가 얹어 준 돈은 내가 받을 돈이다.
        giveWon = MarketEconomy.won(tokens: item.int("requested_tokens"))
        getWon = MarketEconomy.won(tokens: item.int("offered_tokens"))
        countering = item
    }

    private func stopCountering() {
        countering = nil
        offered = [:]
        requested = [:]
        giveWon = 0
        getWon = 0
    }

    private func loadDraft(_ item: [String: Any]) {
        countering = nil
        keepRequestOnFriendChange = friend != item.string("public_id")
        friend = item.string("public_id")
        func basket(_ key: String) -> [String: Int] {
            var result: [String: Int] = [:]
            for line in (item[key] as? [[String: Any]] ?? []).prefix(20) {
                let remaining = 1000 - result.values.reduce(0, +)
                if remaining > 0 { result[line.string("printing")] = min(remaining, line.int("quantity")) }
            }
            return result
        }
        offered = basket("offered"); requested = basket("requested").filter { offered[$0.key] == nil }
        giveWon = 0; getWon = 0
    }
}

/// 친구의 교환 바인더에서 받고 싶은 카드를 고른다.
///
/// 예전에는 전체 카드 목록에서 아무거나 골라서, 친구에게 없는 카드를 요청하면 친구가 수락하려는
/// 순간에야 실패했고 그동안 내 카드는 72시간 묶였다. 행사장에서 교환 바인더를 넘겨 보듯
/// 친구가 실제로 내놓을 수 있는 카드(한 장은 남긴 장수)에서 고른다. 친구가 공개하지 않았거나
/// 서버가 아직 지원하지 않으면, 알 수 없다는 안내와 함께 전체 카드에서 고를 수 있게 둔다.
@MainActor
private struct FriendTradeBinderPicker: View {
    @Bindable var model: OnlineHubModel
    let friendID: String
    var alreadyPicked: [String: Int] = [:]
    /// 「내게 없는 카드만」을 켠 채로 연다. 교환 칸의 「모두 보기」 에서 들어올 때다.
    var startsMissingOnly = false
    let onPick: (_ key: String, _ quantity: Int) -> Void

    private var load: FriendTradeBinder { model.friendBinders[friendID] ?? .loading }
    @State private var searchingAll = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Group {
            if searchingAll {
                OnlineCatalogueSearch(title: OnlineText.l.addCardsWanted, actionTitle: OnlineText.l.addAction) { cardID, finish, quantity in
                    guard let finish else { return }
                    onPick(CardPrintingKey(cardID: cardID, finish: finish).storageKey, quantity)
                }
            } else if case .ready(let stock) = load {
                OnlineStockPicker(wallet: model.wallet, title: OnlineText.l.friendBinderTitle,
                                  actionTitle: OnlineText.l.addAction, alreadyPicked: alreadyPicked,
                                  source: stock, searchPlaceholder: OnlineText.l.searchFriendCards,
                                  emptyTitle: OnlineText.l.friendBinderEmpty,
                                  emptyMessage: OnlineText.l.friendBinderEmptyHint,
                                  marksMissing: true, startsMissingOnly: startsMissingOnly, onPick: onPick)
            } else {
                status
            }
        }
        // 열 때마다 새로 받는다. 교환 칸이 받아 둔 목록이 있으면 받는 동안 그것을 보여 준다.
        .task(id: friendID) { await model.loadFriendBinder(friendID) }
    }

    private var status: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(OnlineText.l.friendBinderTitle).font(Typography.heading)
            Group {
                switch load {
                case .loading:
                    ProgressView().frame(maxWidth: .infinity, minHeight: 200)
                case .hidden:
                    OnlineEmptyState(icon: "lock", title: OnlineText.l.friendBinderPrivate,
                                     message: OnlineText.l.friendBinderFallbackHint)
                case .unsupported:
                    OnlineEmptyState(icon: "rectangle.stack", title: OnlineText.l.friendBinderUnsupported,
                                     message: OnlineText.l.friendBinderFallbackHint)
                case .failed(let message):
                    OnlineEmptyState(icon: "exclamationmark.triangle", title: message)
                case .ready:
                    EmptyView()
                }
            }
            .frame(minHeight: 240)
            HStack {
                Button(OnlineText.l.close) { dismiss() }.keyboardShortcut(.cancelAction)
                Spacer()
                switch load {
                case .hidden, .unsupported:
                    Button(OnlineText.l.searchAllCards) { searchingAll = true }.buttonStyle(.borderedProminent)
                default:
                    EmptyView()
                }
            }
        }
        .padding(24)
        .frame(width: 560)
    }
}

/// 친구가 교환에 내놓을 수 있는 카드(한 장은 남긴 장수)를 받아 온 결과.
enum FriendTradeBinder {
    case loading, ready([OnlineStock]), hidden, unsupported, failed(String)

    @MainActor
    static func load(_ model: OnlineHubModel, friendID: String) async -> FriendTradeBinder {
        do {
            let reply = try await model.read("v1/friends/\(friendID)/tradeable")
            return .ready(stock(reply["items"] as? [String: Any] ?? [:]))
        } catch let failure as RemoteGameSession.Failure {
            switch failure.status {
            case 403: return .hidden
            // 친구가 아니게 된 경우의 404 는 그대로 알리고, 경로가 없는 옛 서버만 지원 안 함으로 본다.
            case 404 where failure.code != "friend_not_found": return .unsupported
            default: return .failed(failure.localizedDescription)
            }
        } catch {
            return .failed(OnlineText.message(for: error))
        }
    }

    /// 서버가 준 「인쇄본: 남는 장수」 를 시세 높은 순의 목록으로.
    @MainActor
    static func stock(_ spares: [String: Any]) -> [OnlineStock] {
        spares.compactMap { key, value -> OnlineStock? in
            let count = (value as? NSNumber)?.intValue ?? 0
            let printing = CardPrintingKey(storageKey: key)
            guard count > 0, CardIndex.shared?.card(printing.cardID) != nil else { return nil }
            return OnlineStock(key: key, cardID: printing.cardID, finish: printing.finish,
                               available: count, referenceWon: OnlineText.referenceWon(key))
        }
        .sorted { ($0.referenceWon ?? 0, $0.key) > ($1.referenceWon ?? 0, $1.key) }
    }

    /// 그 가운데 내 컬렉션에 한 장도 없는 카드. 판형이 달라도 같은 카드를 갖고 있으면 뺀다.
    /// 들어온 순서(시세 높은 순)를 지킨다.
    static func missing(_ stock: [OnlineStock], owned: (String) -> Int) -> [OnlineStock] {
        stock.filter { owned($0.cardID) == 0 }
    }
}
