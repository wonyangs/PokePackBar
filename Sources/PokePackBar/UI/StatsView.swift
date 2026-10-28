import SwiftUI

/// 지금까지의 기록. 저장된 값에서 읽기만 하고 새로 적는 것은 없다.
///
/// 저장 형식을 늘리지 않는다. 온라인 세이브는 서버 규칙과 같은 모양을 지켜야 하므로,
/// 여기 보이는 숫자는 모두 이미 세고 있던 값이나 그 값에서 바로 나오는 것이다.
struct CollectionStats: Equatable {
    /// Trades, market purchases and price refreshes can change stats without an opening.
    struct RefreshID: Equatable {
        let cards: [String: Int]
        let printings: [String: Int]
        let packsOpened: Int
        let cardsSold: Int
        let spent: Int
        let refunded: Int
        let historySeeds: [String]
        let priceDigest: String?

        init(state: GameState, prices: CardPrices?) {
            cards = state.cards
            printings = state.printingCards
            packsOpened = state.packsOpened
            cardsSold = state.cardsDisenchanted
            spent = state.spentTokens
            refunded = state.refundedTokens
            historySeeds = state.openingHistory.map(\.seed)
            priceDigest = prices?.snapshotDigest
        }
    }
    struct Highlight: Equatable {
        let cardID: String
        let finish: CardFinish
        let usd: Double
    }

    struct BestPack: Equatable {
        let setID: String
        let usd: Double
        let openedAt: Date
    }

    var packsOpened = 0
    /// 보유 장수에 판 장수를 더한 값. 교환으로 오간 카드는 따로 세지 않는다.
    var cardsPulled = 0
    var copiesHeld = 0
    var uniqueHeld = 0
    var catalogueSize = 0
    var cardsSold = 0
    var collectionUSD = 0.0
    var topCard: Highlight?
    var tokensSpent = 0
    var tokensRefunded = 0
    /// 아래 둘은 개봉 기록(최근 1,000팩)에서만 셀 수 있다.
    var historyPacks = 0
    var specialPacks = 0
    var bestPack: BestPack?

    static func make(state: GameState, catalogueSize: Int, prices: CardPrices?) -> CollectionStats {
        var stats = CollectionStats()
        stats.packsOpened = state.packsOpened
        stats.copiesHeld = state.cards.values.reduce(0, +)
        stats.uniqueHeld = state.cards.values.filter { $0 > 0 }.count
        stats.catalogueSize = catalogueSize
        stats.cardsSold = state.cardsDisenchanted
        stats.cardsPulled = stats.copiesHeld + state.cardsDisenchanted
        stats.tokensSpent = state.spentTokens
        stats.tokensRefunded = state.refundedTokens

        for (key, count) in state.printingCards where count > 0 {
            let printing = CardPrintingKey(storageKey: key)
            let usd = MarketEconomy.usd(printing, prices: prices)
            stats.collectionUSD += usd * Double(count)
            if usd > (stats.topCard?.usd ?? 0) {
                stats.topCard = Highlight(cardID: printing.cardID, finish: printing.finish, usd: usd)
            }
        }

        stats.historyPacks = state.openingHistory.count
        for record in state.openingHistory {
            if record.variant.isSpecialHit { stats.specialPacks += 1 }
            let usd = record.printings.reduce(0) { $0 + MarketEconomy.usd($1, prices: prices) }
            if usd > (stats.bestPack?.usd ?? 0) {
                stats.bestPack = BestPack(setID: record.setID, usd: usd, openedAt: record.openedAt)
            }
        }
        return stats
    }
}

@MainActor
struct StatsView: View {
    let wallet: WalletStore
    let index: CardIndex?

    /// 그릴 때마다 세지 않는다. 개봉 기록 1,000팩의 시세를 매번 다시 찾을 이유가 없다.
    @State private var stats: CollectionStats?
    /// 「오늘의 시세」에서 누른 카드. 있으면 기록 대신 카드 상세를 보인다.
    @State private var spotlight: Spotlight?
    private struct Spotlight { let cardID: String; let finish: CardFinish? }
    @Environment(PopoverNavigation.self) private var nav

    var body: some View {
        if let spotlight, let entry = index?.card(spotlight.cardID) {
            CardSpotlightView(wallet: wallet, cardID: entry.id,
                              name: entry.displayName(wallet.language),
                              tier: entry.tier, setID: entry.setID,
                              setName: index?.set(entry.setID)?.name ?? entry.setID,
                              rarity: entry.rarity,
                              finish: spotlight.finish,
                              ownedCount: wallet.cardCount(entry.id)) {
                self.spotlight = nil
            }
        } else {
            records
        }
    }

    private var records: some View {
        let l = wallet.l
        return ScrollView {
            if let stats {
                VStack(alignment: .leading, spacing: 12) {
                    // 레벨은 연 팩 수에서 나오므로 기록의 맨 앞에 둔다.
                    VStack(alignment: .leading, spacing: 5) {
                        Text(l.levelHeader).font(Typography.labelSemibold).foregroundStyle(.secondary)
                        LevelCard(wallet: wallet)
                    }
                    // 레벨 다음, 날마다 바뀌는 소식을 둔다. 기록은 서버에만 있어 온라인에서만 보인다.
                    if let remote = wallet.remote, wallet.showsPriceHistory {
                        PriceNewsSection(wallet: wallet, report: remote.priceNews.report,
                                         failed: remote.priceNews.failed, index: index,
                                         onCard: { cardID, finish in
                                             spotlight = Spotlight(cardID: cardID, finish: finish)
                                         },
                                         onPack: { setID in
                                             nav.shopSet = setID
                                             nav.tab = .shop
                                         })
                    }
                    section(l.statsOpening) {
                        row(l.statsPacksOpened, count(stats.packsOpened))
                        row(l.statsCardsPulled, count(stats.cardsPulled))
                        if stats.historyPacks > 0 {
                            row(l.statsSpecialPacks(count(stats.historyPacks)), count(stats.specialPacks))
                            if let best = stats.bestPack {
                                row(l.statsBestPack(count(stats.historyPacks)),
                                    "\(setName(best.setID))  \(money(best.usd))")
                            }
                        }
                    }
                    section(l.collection) {
                        row(l.statsUnique, "\(count(stats.uniqueHeld)) / \(count(stats.catalogueSize))")
                        row(l.statsCopies, count(stats.copiesHeld))
                        row(l.collectionValue, money(stats.collectionUSD))
                        if let top = stats.topCard {
                            row(l.statsTopCard, "\(cardName(top.cardID))  \(money(top.usd))")
                        }
                    }
                    section(l.statsTokens) {
                        row(l.statsTokensSpent, TokenFormatter.readable(stats.tokensSpent, language: wallet.language))
                        row(l.statsTokensRefunded, TokenFormatter.readable(stats.tokensRefunded, language: wallet.language))
                        row(l.statsCardsSold, count(stats.cardsSold))
                    }
                    Text(l.statsHistoryNote)
                        .font(Typography.label).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 2)
            } else {
                ProgressView().frame(maxWidth: .infinity, minHeight: 120)
            }
        }
        .frame(height: PopoverMetrics.tabHeight)
        .task(id: CollectionStats.RefreshID(state: wallet.state, prices: CardPrices.shared)) {
            stats = CollectionStats.make(state: wallet.state,
                                         catalogueSize: index?.cards.count ?? 0,
                                         prices: CardPrices.shared)
        }
        // 탭을 열 때는 조금 전 것이라도 다시 읽는다. 방금 뽑은 카드도 내 카드 변동에 들어가야 한다.
        .task { await wallet.remote?.refreshPriceNews(maxAge: 120) }
    }

    private func section(_ title: String, @ViewBuilder rows: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title).font(Typography.labelSemibold).foregroundStyle(.secondary)
            VStack(spacing: 5) { rows() }
                .padding(8)
                .background(Color.secondary.opacity(0.07), in: RoundedRectangle(cornerRadius: 6))
        }
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(label).font(Typography.body).lineLimit(1)
            Spacer(minLength: 6)
            Text(value).font(Typography.bodySemibold).monospacedDigit()
                .lineLimit(1).minimumScaleFactor(0.75)
        }
    }

    private func count(_ value: Int) -> String { TokenFormatter.grouped(value) }

    private func money(_ usd: Double) -> String {
        CardPrices.shared?.formattedWithKRW(usd, language: wallet.language) ?? TokenFormatter.cost(usd)
    }

    private func setName(_ setID: String) -> String { index?.set(setID)?.name ?? setID }

    private func cardName(_ cardID: String) -> String {
        index?.card(cardID)?.displayName(wallet.language) ?? cardID
    }
}
