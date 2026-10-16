import AppKit
import SwiftUI

/// 온라인 창이 함께 쓰는 말투와 조각.
///
/// 서버 값(영문 상태, 판형 코드, 토큰 정수)을 화면에 그대로 내보내지 않는다. 사용자가 보는 돈은
/// 앱 머리글과 같은 원화이고, 서버로 보낼 때만 토큰으로 바꾼다.
@MainActor
enum OnlineText {
    /// 온라인 창과 계정 창이 여는 지갑. 메뉴바에서 고른 언어를 그대로 따른다.
    static weak var wallet: WalletStore?

    /// 화면에서 읽을 때마다 지갑의 언어를 본다. 언어를 바꾸면 열린 창도 바로 다시 그린다.
    static var language: AppLanguage {
        let language = wallet?.language ?? AppLanguage.current
        if AppLanguage.current != language { AppLanguage.current = language }
        return language
    }
    static var l: L { L(language) }

    static func cardName(_ cardID: String) -> String {
        CardIndex.shared?.card(cardID)?.displayName(language) ?? cardID
    }

    static func finish(_ raw: String) -> String {
        CardFinish(rawValue: raw).map(l.cardFinishName) ?? raw
    }

    static func printing(_ key: String) -> (name: String, finish: String) {
        let printing = CardPrintingKey(storageKey: key)
        return (cardName(printing.cardID), l.cardFinishName(printing.finish))
    }

    /// 토큰을 원화로. 시장 가격은 천 원 단위로 뭉개면 안 되므로 끊지 않은 표기를 쓴다.
    static func won(tokens: Int) -> String {
        WonFormatter.exact(MarketEconomy.won(tokens: tokens), language: language)
    }

    /// 원화 입력을 서버가 받는 토큰으로. 100원 칸 단위로 맞춘다.
    static let maximumListingTokens = 1_000_000_000_000
    static var maximumListingWon: Int {
        maximumListingTokens / MarketEconomy.stepTokens() * MarketEconomy.wonStep
    }
    static func tokens(won: Int) -> Int? {
        let step = MarketEconomy.stepTokens()
        let units = won / MarketEconomy.wonStep
        guard won >= MarketEconomy.wonStep, units <= maximumListingTokens / step else { return nil }
        return units * step
    }

    /// 참고 시세를 원화 100원 칸으로.
    /// 탭 이름. 답할 것이 있으면 그 개수를 붙인다(교환 제안, 친구 신청, 안 읽은 알림).
    static func tabTitle(_ tab: OnlineHubModel.Tab, summary: RemoteGameSession.NotificationSummary?) -> String {
        let waiting: Int
        switch tab {
        case .trades: waiting = summary?.incoming_trades ?? 0
        case .social: waiting = summary?.incoming_friends ?? 0
        case .alerts: waiting = summary?.unread ?? 0
        default: waiting = 0
        }
        return waiting > 0 ? "\(l.onlineTab(tab)) \(waiting)" : l.onlineTab(tab)
    }

    static func referenceWon(_ key: String) -> Int? {
        let printing = CardPrintingKey(storageKey: key)
        guard let prices = CardPrices.shared, let usd = prices.price(printing) else { return nil }
        return MarketEconomy.won(tokens: MarketEconomy.tokens(usd: usd, prices: prices), prices: prices)
    }

    /// 판형을 정하지 않은 카드의 대표 시세.
    static func cardReferenceWon(_ cardID: String) -> Int? {
        guard let prices = CardPrices.shared, let usd = prices.price(cardID) else { return nil }
        return MarketEconomy.won(tokens: MarketEconomy.tokens(usd: usd, prices: prices), prices: prices)
    }

    /// 마켓 검색 칸에 넣을 카드 이름. 서버는 영어 이름과 한국어 이름으로만 찾으므로 그 둘 중에서 고른다.
    static func searchName(_ printing: String) -> String? {
        guard let card = CardIndex.shared?.card(CardPrintingKey(storageKey: printing).cardID) else { return nil }
        return card.displayName(language == .ko ? .ko : .en)
    }

    static func wonText(_ won: Int) -> String { WonFormatter.exact(won, language: language) }

    /// 시세 높은 순. 시세 없는 인쇄본은 뒤로 가고, 같은 값이면 이름순으로 흔들리지 않게 한다.
    static func byReferencePrice(_ keys: [String]) -> [String] {
        let priced = keys.map { (key: $0, won: referenceWon($0) ?? -1) }
        return priced.sorted { ($0.won, $1.key) > ($1.won, $0.key) }.map(\.key)
    }

    /// 마우스를 올렸을 때의 한 줄: 이름, 판형, 장당 시세.
    static func printingSummary(_ key: String) -> String {
        let printing = printing(key)
        let price = referenceWon(key).map { l.marketQuote(wonText($0)) } ?? l.noMarketPrice
        return "\(printing.name) \(printing.finish), \(price)"
    }

    /// 교환 한쪽의 참고 시세 합계(원)와 시세가 없어 빠진 장수.
    static func referenceTotal(_ lines: [String: Int]) -> (won: Int, unpriced: Int) {
        lines.reduce(into: (won: 0, unpriced: 0)) { total, line in
            if let won = referenceWon(line.key) { total.won += won * line.value } else { total.unpriced += line.value }
        }
    }

    /// 담은 카드 줄 요약: 종수, 장수, 시세 합계.
    static func traySummary(_ lines: [String: Int]) -> String {
        let total = referenceTotal(lines)
        let priced = lines.values.reduce(0, +) > total.unpriced
        return l.traySummary(kinds: lines.count, cards: lines.values.reduce(0, +),
                             won: priced ? wonText(total.won) : nil, unpriced: total.unpriced)
    }

    /// 주고받는 양쪽 시세를 한 문장으로 비교한다. 교환에 얹은 돈(원)도 그쪽 값에 더한다.
    static func valueBalance(give: [String: Int], get: [String: Int], giveWon: Int = 0, getWon: Int = 0) -> String {
        let gave = referenceTotal(give).won + giveWon, got = referenceTotal(get).won + getWon
        return l.valueBalance(give: wonText(gave), get: wonText(got), difference: got - gave, gap: wonText(abs(got - gave)))
    }

    static func listingStatus(_ raw: String) -> (text: String, color: Color) {
        switch raw {
        case "active": return (OnlineText.l.listingActive, .green)
        case "sold": return (OnlineText.l.listingSold, .blue)
        case "expired": return (OnlineText.l.expiredLabel, .secondary)
        case "cancelled": return (OnlineText.l.listingCancelled, .secondary)
        default: return (raw, .secondary)
        }
    }

    static func tradeStatus(_ raw: String) -> (text: String, color: Color) {
        switch raw {
        case "pending": return (OnlineText.l.tradePending, .orange)
        case "accepted": return (OnlineText.l.tradeAccepted, .green)
        case "rejected": return (OnlineText.l.tradeRejected, .secondary)
        case "cancelled": return (OnlineText.l.tradeCancelled, .secondary)
        case "countered": return (OnlineText.l.tradeCountered, .secondary)
        case "expired": return (OnlineText.l.expiredLabel, .secondary)
        default: return (raw, .secondary)
        }
    }

    /// 가격 제안의 상태. 교환과 같은 말을 쓰되, 수락은 「교환 완료」가 아니라 「수락됨」이다.
    static func offerStatus(_ raw: String) -> (text: String, color: Color) {
        raw == "accepted" ? (OnlineText.l.offerAccepted, .green) : tradeStatus(raw)
    }

    static func notification(_ kind: String) -> (text: String, icon: String) {
        switch kind {
        case "trade_request": return (OnlineText.l.noteTradeRequest, "arrow.left.arrow.right")
        case "trade_accepted": return (OnlineText.l.noteTradeAccepted, "checkmark.circle")
        case "trade_rejected": return (OnlineText.l.noteTradeRejected, "hand.raised")
        case "trade_cancelled": return (OnlineText.l.noteTradeCancelled, "arrow.uturn.backward.circle")
        case "trade_countered": return (OnlineText.l.noteTradeCountered, "arrow.triangle.2.circlepath")
        case "trade_expired": return (OnlineText.l.noteTradeExpired, "clock")
        case "listing_sold": return (OnlineText.l.noteListingSold, "wonsign.circle")
        case "listing_bought": return (OnlineText.l.noteListingBought, "bag")
        case "listing_expired": return (OnlineText.l.noteListingExpired, "clock")
        case "wishlist_listing": return (OnlineText.l.noteWishlistListing, "star")
        case "offer_received": return (OnlineText.l.noteOfferReceived, "tag")
        case "offer_accepted": return (OnlineText.l.noteOfferAccepted, "checkmark.circle")
        case "offer_rejected": return (OnlineText.l.noteOfferRejected, "hand.raised")
        case "offer_expired": return (OnlineText.l.noteOfferExpired, "clock")
        case "friend_request": return (OnlineText.l.noteFriendRequest, "person.badge.plus")
        case "friend_accept", "friend_accepted": return (OnlineText.l.noteFriendAccepted, "person.2")
        case "friend_reject", "friend_rejected": return (OnlineText.l.noteFriendRejected, "person.badge.minus")
        case "friend_expired": return (OnlineText.l.noteFriendExpired, "clock")
        case "friend_remove": return (OnlineText.l.noteFriendRemoved, "person.badge.minus")
        default: return (kind, "bell")
        }
    }

    /// 알림 한 줄의 문장. 서버가 상대 이름이나 카드를 함께 보냈으면 그것을 넣어 말한다.
    /// 예전 서버는 보내지 않으므로 그때는 `notification(_:)` 의 짧은 문장이 그대로 나온다.
    static func notificationText(kind: String, nickname: String? = nil, printing key: String? = nil,
                                 unitTokens: Int? = nil) -> String {
        let l = OnlineText.l
        if let name = nickname, !name.isEmpty {
            switch kind {
            case "trade_request": return l.noteTradeRequestFrom(name)
            case "trade_countered": return l.noteTradeCounteredBy(name)
            case "trade_accepted": return l.noteTradeAcceptedWith(name)
            case "trade_rejected": return l.noteTradeRejectedWith(name)
            case "trade_cancelled": return l.noteTradeCancelledWith(name)
            case "trade_expired": return l.noteTradeExpiredWith(name)
            case "friend_request": return l.noteFriendRequestFrom(name)
            case "friend_accept", "friend_accepted": return l.noteFriendAcceptedBy(name)
            case "friend_reject", "friend_rejected": return l.noteFriendRejectedBy(name)
            case "friend_remove": return l.noteFriendRemovedBy(name)
            case "friend_expired": return l.noteFriendExpiredWith(name)
            default: break
            }
        }
        if let key, !key.isEmpty, CardIndex.shared?.card(CardPrintingKey(storageKey: key).cardID) != nil {
            let printing = printing(key)
            let card = "\(printing.name) (\(printing.finish))"
            let price = unitTokens.map(won(tokens:)) ?? ""
            switch kind {
            case "listing_sold" where !price.isEmpty: return l.noteListingSoldCard(card, price: price)
            case "listing_bought": return l.noteListingBoughtCard(card)
            case "listing_expired": return l.noteListingExpiredCard(card)
            case "wishlist_listing" where !price.isEmpty: return l.noteWishlistListingCard(card, price: price)
            case "offer_expired": return l.noteOfferExpiredCard(card)
            default: break
            }
            // 가격 제안은 상대 이름과 카드가 함께 있어야 문장이 된다.
            if let name = nickname, !name.isEmpty {
                switch kind {
                case "offer_received" where !price.isEmpty: return l.noteOfferReceivedCard(name, card: card, price: price)
                case "offer_accepted" where !price.isEmpty: return l.noteOfferAcceptedCard(name, card: card, price: price)
                case "offer_rejected": return l.noteOfferRejectedCard(name, card: card)
                default: break
                }
            }
        }
        return notification(kind).text
    }

    /// 목록의 한 줄(서버 응답 그대로)에서 문장을 만든다.
    static func notificationText(_ item: [String: Any]) -> String {
        let detail = item["detail"] as? [String: Any] ?? [:]
        let tokens = detail.int("unit_tokens")
        return notificationText(kind: item.string("kind"), nickname: detail["nickname"] as? String,
                                printing: detail["printing"] as? String, unitTokens: tokens > 0 ? tokens : nil)
    }

    /// 「3시간 전」 처럼 얼마나 지났는지만 말한다. 일주일이 넘으면 날짜로 적는다.
    static func timeAgo(_ timestamp: Int, now: Date = Date()) -> String {
        guard timestamp > 0 else { return "" }
        let seconds = max(0, now.timeIntervalSince1970 - Double(timestamp))
        if seconds < 60 { return l.justNow }
        if seconds < 3600 { return l.minutesAgo(Int(seconds / 60)) }
        if seconds < 86_400 { return l.hoursAgo(Int(seconds / 3600)) }
        if seconds < 7 * 86_400 { return l.daysAgo(Int(seconds / 86_400)) }
        return Date(timeIntervalSince1970: Double(timestamp)).formatted(date: .abbreviated, time: .omitted)
    }

    /// 알림을 눌렀을 때 열 탭. 알림은 「무엇이 있었다」 만 말해서, 예전에는 읽고 나서
    /// 그 일을 처리할 탭을 직접 찾아가야 했다.
    static func destination(_ kind: String) -> OnlineHubModel.Tab? {
        if kind.hasPrefix("trade_") { return .trades }
        if kind.hasPrefix("friend_") { return .social }
        if kind.hasPrefix("listing_") || kind.hasPrefix("offer_") || kind == "wishlist_listing" { return .market }
        return nil
    }

    /// 친구 코드를 서버가 받는 꼴로. 보기 좋게 끊어 쓴 띄어쓰기나 줄표를 빼고 대문자로 바꾼다.
    /// 공유 문장(「친구 코드: ABCD …」)을 통째로 붙여 넣어도 코드만 골라낸다.
    nonisolated static func normalizedFriendCode(_ text: String) -> String {
        let pattern = "[0-9A-Fa-f]{4}[ -]?[0-9A-Fa-f]{4}[ -]?[0-9A-Fa-f]{4}[ -]?[0-9A-Fa-f]{4}"
        if let match = text.range(of: pattern, options: .regularExpression) {
            return text[match].filter(\.isHexDigit).uppercased()
        }
        return text.filter { !$0.isWhitespace && $0 != "-" }.uppercased()
    }

    /// 네 자씩 끊어 보인다. 16자를 한 덩어리로 두면 불러 주거나 옮겨 적다 자리를 놓친다.
    nonisolated static func groupedFriendCode(_ code: String) -> String {
        let characters = Array(code)
        return stride(from: 0, to: characters.count, by: 4)
            .map { String(characters[$0..<min($0 + 4, characters.count)]) }
            .joined(separator: " ")
    }

    /// 실패를 화면에 띄울 한 줄로. 우리가 만든 실패는 이미 읽을 문장이다. 응답 해석 실패처럼
    /// 시스템이 만든 문장(「데이터가 올바른 형식이 아니므로…」)은 무엇을 하라는 말이 없어
    /// 짧은 안내로 바꾸고, 원문은 로그에 남긴다.
    nonisolated static func message(for error: any Error) -> String {
        ProblemText.message(for: error)
    }

    /// "6일 남음" 처럼 남은 시간만 말한다. 날짜와 시각을 통째로 보여 주면 계산을 떠넘긴다.
    static func remaining(until timestamp: Int) -> String {
        let seconds = Double(timestamp) - Date().timeIntervalSince1970
        guard seconds > 0 else { return OnlineText.l.expiredLabel }
        let hours = Int(seconds / 3600)
        if hours >= 48 { return OnlineText.l.daysLeft(hours / 24) }
        if hours >= 1 { return OnlineText.l.hoursLeft(hours) }
        return OnlineText.l.endingSoon
    }
}

/// 내가 팔거나 교환에 내놓을 수 있는 인쇄본. 한 장은 늘 남기고, 다른 거래에 묶인 장수는 뺀다.
struct OnlineStock: Identifiable, Sendable {
    let key: String
    let cardID: String
    let finish: CardFinish
    let available: Int
    let referenceWon: Int?
    var id: String { key }

    @MainActor
    static func sellable(wallet: WalletStore) -> [OnlineStock] {
        guard let index = CardIndex.shared else { return [] }
        let reserved = wallet.remote?.reservedPrintings ?? [:]
        return wallet.state.printingCards.compactMap { key, count -> OnlineStock? in
            let printing = CardPrintingKey(storageKey: key)
            guard index.card(printing.cardID) != nil else { return nil }
            let available = count - (reserved[key] ?? 0) - 1
            guard available > 0 else { return nil }
            return OnlineStock(key: key, cardID: printing.cardID, finish: printing.finish,
                               available: available, referenceWon: OnlineText.referenceWon(key))
        }
        .sorted { ($0.referenceWon ?? 0, $0.key) > ($1.referenceWon ?? 0, $1.key) }
    }
}

/// 카드 그림이 먼저 보이는 칸. 이름과 판형 아래에 각 화면이 필요한 한두 줄을 붙인다.
@MainActor
struct OnlineCardTile<Footer: View>: View {
    let cardID: String
    let finish: String
    var width: CGFloat = 112
    var badge: (text: String, color: Color)? = nil
    @ViewBuilder var footer: Footer

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            // 상태(내 판매, 다 모았어요)는 카드 그림 위에 얹지 않는다. 옅은 바탕의 글자가 그림 위에
            // 떠서 카드에 인쇄된 이름과 HP 위에 글자만 쓰인 것처럼 보였다. 맨 아래에 두면 같은 줄의
            // 다른 카드와 이름, 가격 줄도 어긋나지 않는다.
            CardImageView(cardID: cardID, width: width)
            Text(OnlineText.cardName(cardID))
                .font(Typography.labelSemibold).lineLimit(1)
            Text(OnlineText.finish(finish))
                .font(Typography.caption).foregroundStyle(.secondary).lineLimit(1)
            footer
            if let badge {
                OnlineBadge(text: badge.text, color: badge.color)
            }
        }
        .frame(width: width, alignment: .leading)
        .contentShape(Rectangle())
    }
}

@MainActor
struct OnlineBadge: View {
    let text: String
    var color: Color = .accentColor

    var body: some View {
        Text(text)
            .font(Typography.captionMedium)
            .foregroundStyle(color == .secondary ? Color.secondary : color)
            .padding(.horizontal, 7).padding(.vertical, 2)
            .background((color == .secondary ? Color.secondary : color).opacity(0.14), in: Capsule())
    }
}

/// 비어 있을 때 무엇을 하면 채워지는지까지 말한다.
@MainActor
struct OnlineEmptyState: View {
    let icon: String
    let title: String
    var message: String? = nil

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon).font(.system(size: 26)).foregroundStyle(.secondary)
            Text(title).font(Typography.bodySemibold)
            if let message {
                Text(message).font(Typography.label).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center).frame(maxWidth: 380)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 36)
    }
}

/// 한 덩어리의 내용. 모든 것을 상자에 넣지 않고, 제목과 여백으로 나눈다.
@MainActor
struct OnlineSection<Content: View, Accessory: View>: View {
    let title: String
    var subtitle: String? = nil
    @ViewBuilder var accessory: Accessory
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(Typography.title)
                    if let subtitle {
                        Text(subtitle).font(Typography.label).foregroundStyle(.secondary)
                    }
                }
                Spacer()
                accessory
            }
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

extension OnlineSection where Accessory == EmptyView {
    init(title: String, subtitle: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.subtitle = subtitle
        self.accessory = EmptyView()
        self.content = content()
    }
}

/// 수량 고르기. 숫자 칸 대신 −/+ 로만 바꾼다 — 고를 수 없는 수는 아예 못 만든다.
@MainActor
struct OnlineQuantity: View {
    @Binding var value: Int
    let range: ClosedRange<Int>

    var body: some View {
        HStack(spacing: 10) {
            Button { value = max(range.lowerBound, value - 1) } label: { Image(systemName: "minus") }
                .disabled(value <= range.lowerBound)
            Text(OnlineText.l.cardsCount(value)).font(Typography.bodySemibold).monospacedDigit().frame(minWidth: 52)
            Button { value = min(range.upperBound, value + 1) } label: { Image(systemName: "plus") }
                .disabled(value >= range.upperBound)
            if range.upperBound > 1 {
                Button(OnlineText.l.maxQuantity) { value = range.upperBound }
                    .buttonStyle(.borderless).font(Typography.label)
                    .disabled(value == range.upperBound)
            }
        }
        .onAppear { value = min(max(value, range.lowerBound), range.upperBound) }
    }
}

/// 시트 공통 틀: 제목, 내용, 아래쪽 취소와 실행 버튼.
@MainActor
struct OnlineSheet<Content: View>: View {
    let title: String
    let actionTitle: String
    var actionDisabled = false
    var note: String? = nil
    /// 보기만 하는 창은 실행 버튼 없이 닫기만 둔다.
    var showsAction = true
    let action: () -> Void
    @ViewBuilder var content: Content
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(title).font(Typography.heading)
            content
            if let note {
                Text(note).font(Typography.label).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            HStack {
                Button(showsAction ? OnlineText.l.cancel : OnlineText.l.close) { dismiss() }.keyboardShortcut(.cancelAction)
                Spacer()
                if showsAction {
                    Button(actionTitle) { dismiss(); action() }
                        .buttonStyle(.borderedProminent)
                        .keyboardShortcut(.defaultAction)
                        .disabled(actionDisabled)
                }
            }
        }
        .padding(24)
        .frame(width: 520)
    }
}

/// 이전/다음. 넘길 곳이 없으면 아예 보이지 않는다.
@MainActor
struct OnlinePagination: View {
    @Bindable var model: OnlineHubModel
    let key: String
    var step = 50

    var body: some View {
        let hasNext = model.documents[key]?["next_offset"] as? Int != nil
        if model.offset > 0 || hasNext {
            HStack {
                Button(OnlineText.l.previousPage) { model.offset = max(0, model.offset - step); Task { await model.refresh(full: false) } }
                    .disabled(model.offset == 0 || model.loading)
                Button(OnlineText.l.nextPage) { model.offset += step; Task { await model.refresh(full: false) } }
                    .disabled(!hasNext || model.loading)
            }
            .frame(maxWidth: .infinity)
        }
    }
}

/// 카드 그림 줄. 교환처럼 여러 장을 한눈에 보여 줄 때 쓴다.
@MainActor
struct OnlineCardStrip: View {
    let lines: [String: Int]
    var width: CGFloat = 64
    var onRemove: ((String) -> Void)? = nil
    var onOpen: ((String) -> Void)? = nil

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: 10) {
                // 비싼 카드가 앞에 온다. 교환에서 먼저 보고 싶은 것은 값이 큰 카드다.
                ForEach(OnlineText.byReferencePrice(Array(lines.keys)), id: \.self) { key in
                    let printing = CardPrintingKey(storageKey: key)
                    let price = OnlineText.referenceWon(key)
                    VStack(spacing: 3) {
                        ZStack(alignment: .topTrailing) {
                            CardImageView(cardID: printing.cardID, width: width)
                                .onTapGesture { onOpen?(key) }
                            if let onRemove {
                                Button { onRemove(key) } label: {
                                    Image(systemName: "minus.circle.fill").font(.system(size: 16))
                                        .symbolRenderingMode(.palette)
                                        .foregroundStyle(.white, .black.opacity(0.6))
                                }
                                .buttonStyle(.plain).offset(x: 5, y: -5)
                                .help(OnlineText.l.removeCard)
                            }
                        }
                        Text("×\(lines[key] ?? 0)").font(Typography.captionMedium).monospacedDigit()
                        // 장당 시세. 눌러서 크게 봐야만 알 수 있으면 주고받는 값을 견주기 어렵다.
                        Text(price.map(OnlineText.wonText) ?? OnlineText.l.noMarketPrice)
                            .font(Typography.caption).monospacedDigit()
                            .foregroundStyle(.secondary)
                            .lineLimit(1).minimumScaleFactor(0.7)
                            .frame(width: max(width, 60))
                    }
                    .help(OnlineText.printingSummary(key))
                }
            }
            .padding(.top, 6)
        }
    }
}

/// 전체 카드에서 원하는 카드를 찾아 고르는 시트. 위시리스트와 교환의 「받고 싶은 카드」에 쓴다.
/// 판형은 그 카드에 실제로 있는 것만 고를 수 있다.
@MainActor
struct OnlineCatalogueSearch: View {
    let title: String
    let actionTitle: String
    var allowsAnyFinish = false
    var maxQuantity = 1000
    let onPick: (_ cardID: String, _ finish: CardFinish?, _ quantity: Int) -> Void

    @State private var query = ""
    /// 입력이 멈춘 뒤 실제로 거르는 검색어.
    @State private var appliedQuery = ""
    @State private var picked: CardEntry?
    @State private var finish: CardFinish?
    @State private var quantity = 1
    @Environment(\.dismiss) private var dismiss

    /// 이름이 똑같은 카드, 그 말로 시작하는 카드, 포함하는 카드 순. 같은 묶음 안에서는 시세 높은 순.
    ///
    /// 예전에는 카드 목록 순서대로 앞 60장만 보여 줬다. 「뮤」로 찾으면 뮤츠까지 108장이 걸리는데
    /// 목록 뒤쪽인 30주년 RGB 뮤(105~107번째)가 잘려 위시리스트에 넣을 수 없었다. 이제 개수를
    /// 자르지 않는다. 격자가 보이는 칸만 그리므로 수천 장이 걸려도 스크롤로 전부 볼 수 있다.
    private var matches: [CardEntry] {
        let needle = DexCardSearch.normalized(appliedQuery)
        guard !needle.isEmpty, let index = CardIndex.shared else { return [] }
        var exact: [CardEntry] = [], prefix: [CardEntry] = [], partial: [CardEntry] = []
        for entry in index.currentCardsByValue {
            let names = DexCardSearch.names(entry)
            if names.contains(needle) { exact.append(entry) }
            else if names.contains(where: { $0.hasPrefix(needle) }) { prefix.append(entry) }
            else if names.contains(where: { $0.contains(needle) }) { partial.append(entry) }
        }
        return exact + prefix + partial
    }

    /// 카드 대표 시세(원). 판형을 고르기 전 목록에 쓴다.
    private func cardPrice(_ card: CardEntry) -> Int? { OnlineText.cardReferenceWon(card.id) }

    /// 고른 판형의 시세. 「아무 판형」이면 대표 시세다.
    private func pickedPrice(_ card: CardEntry) -> Int? {
        guard let finish else { return cardPrice(card) }
        return OnlineText.referenceWon(CardPrintingKey(cardID: card.id, finish: finish).storageKey)
    }

    private func finishes(_ card: CardEntry) -> [CardFinish] {
        guard let index = CardIndex.shared else { return [] }
        var seen: [CardFinish] = []
        for option in FoilAuditPrintings.finishes(for: card, index: index) {
            let resolved = option ?? CardFinishResolver.resolve(
                cardID: card.id, setID: card.setID, originalRarity: card.rarity,
                tier: card.tier, visualKind: card.visualKind, explicitFinish: nil).finish
            if !seen.contains(resolved) { seen.append(resolved) }
        }
        return seen
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title).font(Typography.heading)
            if let picked {
                HStack(alignment: .top, spacing: 16) {
                    CardImageView(cardID: picked.id, hires: true, width: 150)
                    VStack(alignment: .leading, spacing: 12) {
                        Text(picked.displayName(OnlineText.language)).font(Typography.title)
                        Text(CardIndex.shared?.set(picked.setID)?.name ?? picked.setID)
                            .font(Typography.label).foregroundStyle(.secondary)
                        // 고른 판형의 시세. 판형을 바꾸면 값도 따라 바뀐다.
                        Text(pickedPrice(picked).map { OnlineText.l.priceEach(OnlineText.wonText($0)) }
                             ?? OnlineText.l.noMarketPrice)
                            .font(Typography.bodySemibold).monospacedDigit()
                        Picker(OnlineText.l.finishLabel, selection: $finish) {
                            if allowsAnyFinish { Text(OnlineText.l.anyFinish).tag(CardFinish?.none) }
                            ForEach(finishes(picked), id: \.self) { option in
                                Text(OnlineText.l.cardFinishName(option)).tag(Optional(option))
                            }
                        }
                        .fixedSize()
                        OnlineQuantity(value: $quantity, range: 1...maxQuantity)
                        Button(OnlineText.l.pickAnotherCard) { self.picked = nil }.buttonStyle(.borderless)
                    }
                }
            } else {
                TextField(OnlineText.l.searchCardNameKoEn, text: $query)
                    .textFieldStyle(.roundedBorder)
                    .debouncedSearch(query, into: $appliedQuery)
                ScrollView {
                    // 1만 9천 장을 훑으므로 그리기 한 번에 한 번만 계산한다.
                    let found = matches
                    if query.isEmpty {
                        OnlineEmptyState(icon: "magnifyingglass", title: OnlineText.l.typeCardName)
                    } else if found.isEmpty {
                        OnlineEmptyState(icon: "questionmark.square",
                                         title: appliedQuery == query ? OnlineText.l.noMatchingCards : OnlineText.l.searching)
                    } else {
                        Text(OnlineText.l.catalogueResultCount(found.count))
                            .font(Typography.caption).foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: 12)], spacing: 14) {
                            ForEach(found) { card in
                                Button {
                                    picked = card
                                    finish = allowsAnyFinish ? nil : finishes(card).first
                                    quantity = 1
                                } label: {
                                    VStack(alignment: .leading, spacing: 3) {
                                        CardImageView(cardID: card.id, width: 92)
                                        Text(card.displayName(OnlineText.language)).font(Typography.caption).lineLimit(1)
                                        Text(CardIndex.shared?.set(card.setID)?.name ?? card.setID)
                                            .font(Typography.caption).foregroundStyle(.secondary).lineLimit(1)
                                        Text(cardPrice(card).map(OnlineText.wonText) ?? OnlineText.l.noMarketPrice)
                                            .font(Typography.captionMedium).monospacedDigit()
                                            .lineLimit(1).minimumScaleFactor(0.75)
                                    }
                                    .frame(width: 92)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                .frame(height: 360)
            }
            HStack {
                Button(OnlineText.l.close) { dismiss() }.keyboardShortcut(.cancelAction)
                Spacer()
                Button(actionTitle) {
                    if let picked { onPick(picked.id, finish, quantity) }
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(picked == nil || (!allowsAnyFinish && finish == nil))
            }
        }
        .padding(24)
        .frame(width: 560)
    }
}

/// 내 카드 중 거래할 수 있는 것만 보여 주고 골라 담는 시트.
@MainActor
struct OnlineStockPicker: View {
    let wallet: WalletStore
    let title: String
    let actionTitle: String
    /// 이미 담은 장수. 남은 수량을 넘겨 담지 않게 한다.
    var alreadyPicked: [String: Int] = [:]
    /// 고를 카드. 없으면 내 남는 카드다. 친구의 교환 바인더를 넘길 때 쓴다.
    var source: [OnlineStock]? = nil
    var searchPlaceholder: String? = nil
    var emptyTitle: String? = nil
    var emptyMessage: String? = nil
    /// 내 컬렉션에 없는 카드를 표시하고 그것만 가려 볼 수 있게 한다. 친구의 교환 바인더에서 켠다.
    var marksMissing = false
    var startsMissingOnly = false
    let onPick: (_ key: String, _ quantity: Int) -> Void

    @State private var query = ""
    @State private var appliedQuery = ""
    @State private var picked: OnlineStock?
    @State private var quantity = 1
    @State private var order = Order.priceHigh
    @State private var missingOnly = false
    @Environment(\.dismiss) private var dismiss

    enum Order: CaseIterable { case priceHigh, priceLow, name }

    private var stock: [OnlineStock] {
        var all = Self.sorted(source ?? OnlineStock.sellable(wallet: wallet), by: order)
        if marksMissing, missingOnly { all = all.filter(isMissing) }
        let needle = DexCardSearch.normalized(appliedQuery)
        guard !needle.isEmpty else { return all }
        return all.filter { DexCardSearch.names(cardID: $0.cardID).contains { $0.contains(needle) } }
    }

    private func isMissing(_ item: OnlineStock) -> Bool { wallet.cardCount(item.cardID) == 0 }

    /// 시세 없는 카드는 어느 가격순에서도 뒤에 둔다. 낮은 순 맨 앞에 값 모르는 카드가 몰리면
    /// 싼 카드를 찾는 사람에게 쓸모가 없다.
    static func sorted(_ stock: [OnlineStock], by order: Order) -> [OnlineStock] {
        switch order {
        case .priceHigh:
            return stock.sorted { ($0.referenceWon ?? -1, $1.key) > ($1.referenceWon ?? -1, $0.key) }
        case .priceLow:
            return stock.sorted { ($0.referenceWon ?? .max, $0.key) < ($1.referenceWon ?? .max, $1.key) }
        case .name:
            return stock.sorted {
                (OnlineText.cardName($0.cardID), $0.key) < (OnlineText.cardName($1.cardID), $1.key)
            }
        }
    }

    private func title(_ order: Order) -> String {
        switch order {
        case .priceHigh: OnlineText.l.sortPriceHigh
        case .priceLow: OnlineText.l.sortPriceLow
        case .name: OnlineText.l.sortName
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title).font(Typography.heading)
            if let picked {
                let remaining = max(1, picked.available)
                HStack(alignment: .top, spacing: 16) {
                    CardImageView(cardID: picked.cardID, hires: true, width: 150)
                    VStack(alignment: .leading, spacing: 10) {
                        Text(OnlineText.cardName(picked.cardID)).font(Typography.title)
                        Text(OnlineText.l.cardFinishName(picked.finish))
                            .font(Typography.label).foregroundStyle(.secondary)
                        Text(OnlineText.l.offerableCount(picked.available))
                            .font(Typography.label)
                        if let won = picked.referenceWon {
                            Text(OnlineText.l.priceEach(OnlineText.wonText(won)))
                                .font(Typography.bodySemibold).monospacedDigit()
                            if quantity > 1 {
                                Text(OnlineText.l.priceTotal(quantity, OnlineText.wonText(won * quantity)))
                                    .font(Typography.label).foregroundStyle(.secondary).monospacedDigit()
                            }
                        } else {
                            Text(OnlineText.l.noMarketPrice).font(Typography.label).foregroundStyle(.secondary)
                        }
                        OnlineQuantity(value: $quantity, range: 1...min(1000, remaining))
                        Button(OnlineText.l.pickAnotherCard) { self.picked = nil }.buttonStyle(.borderless)
                    }
                }
            } else {
                HStack(spacing: 10) {
                    TextField(searchPlaceholder ?? OnlineText.l.searchMyCards, text: $query).textFieldStyle(.roundedBorder)
                        .debouncedSearch(query, into: $appliedQuery)
                    Picker(OnlineText.l.sortBy, selection: $order) {
                        ForEach(Order.allCases, id: \.self) { Text(title($0)).tag($0) }
                    }
                    .labelsHidden().fixedSize()
                    .help(OnlineText.l.sortBy)
                    if marksMissing {
                        Toggle(OnlineText.l.missingOnlyToggle, isOn: $missingOnly).toggleStyle(.checkbox).fixedSize()
                    }
                }
                ScrollView {
                    if stock.isEmpty {
                        if marksMissing, missingOnly, query.isEmpty, !(source ?? []).isEmpty {
                            // 친구에게 남는 카드는 있는데 내게 없는 것이 없다. 바인더가 빈 것과는 다르다.
                            OnlineEmptyState(icon: "checkmark.circle", title: OnlineText.l.noMissingCardsTitle,
                                             message: OnlineText.l.noMissingCardsHint)
                        } else {
                            OnlineEmptyState(icon: "square.stack",
                                             title: query.isEmpty ? emptyTitle ?? OnlineText.l.noOfferableCards : OnlineText.l.noMatchingCards,
                                             message: query.isEmpty ? emptyMessage ?? OnlineText.l.spareCardsHint : nil)
                        }
                    } else {
                        // 「아직 없음」 표시가 붙은 칸과 없는 칸의 높이가 달라도 카드 윗선은 맞춘다.
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: 12, alignment: .top)], spacing: 14) {
                            ForEach(stock) { item in
                                Button {
                                    picked = OnlineStock(key: item.key, cardID: item.cardID, finish: item.finish,
                                                         available: item.available - (alreadyPicked[item.key] ?? 0),
                                                         referenceWon: item.referenceWon)
                                    quantity = 1
                                } label: {
                                    OnlineCardTile(cardID: item.cardID, finish: item.finish.rawValue, width: 92,
                                                   badge: marksMissing && isMissing(item)
                                                       ? (OnlineText.l.missingBadge, .accentColor) : nil) {
                                        // 고르기 전에 값이 보여야 한다. 눌러 들어가야만 시세가 나오면
                                        // 카드마다 들어갔다 나오며 견줘야 한다.
                                        Text(item.referenceWon.map(OnlineText.wonText) ?? OnlineText.l.noMarketPrice)
                                            .font(Typography.captionMedium).monospacedDigit()
                                            .foregroundStyle(item.referenceWon == nil ? .secondary : .primary)
                                            .lineLimit(1).minimumScaleFactor(0.75)
                                        Text(OnlineText.l.availableCount(item.available)).font(Typography.caption).foregroundStyle(.secondary)
                                    }
                                    .help(OnlineText.printingSummary(item.key))
                                }
                                .buttonStyle(.plain)
                                .disabled(item.available - (alreadyPicked[item.key] ?? 0) <= 0)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                .frame(height: 360)
            }
            HStack {
                Button(OnlineText.l.close) { dismiss() }.keyboardShortcut(.cancelAction)
                Spacer()
                Button(actionTitle) {
                    if let picked { onPick(picked.key, quantity) }
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(picked == nil || (picked?.available ?? 0) < 1)
            }
        }
        .padding(24)
        .frame(width: 560)
        .onAppear { missingOnly = startsMissingOnly }
    }
}

// MARK: 실패 안내

/// 로컬 모드라 온라인 세션이 없다. 서버에 보낸 요청이 아니라 요청 번호가 없다.
struct OnlineSignedOut: LocalizedError {
    var errorDescription: String? { L(AppLanguage.current).notSignedInOnline }
}

/// 실패를 사용자가 구분할 수 있는 종류로. 연결 실패와 서버 오류를 같은 말로 뭉뚱그리면
/// 인터넷을 고칠지 기다릴지 알 수 없다.
@MainActor
struct OnlineProblem {
    enum Kind { case signedOut, unreachable, server, rejected, other }
    let kind: Kind
    let requestID: String?

    init(_ error: (any Error)?) {
        let traced = error as? any ServerTraceable
        requestID = traced?.requestID
        if error is OnlineSignedOut || traced?.status == 401
            || (error as? RemoteGameSession.Failure)?.message == ServerAuthentication.loginRequired {
            kind = .signedOut
            return
        }
        switch traced?.status {
        case .none where error is ServerUnreachable: kind = .unreachable
        case .some(let status) where status >= 500: kind = .server
        case .some(let status) where status >= 400: kind = .rejected
        default: kind = .other
        }
    }

    var title: String {
        switch kind {
        case .signedOut: OnlineText.l.problemSignedOut
        case .unreachable: OnlineText.l.problemUnreachable
        case .server: OnlineText.l.problemServer
        case .rejected: OnlineText.l.problemRejected
        case .other: OnlineText.l.problemOther
        }
    }

    var icon: String {
        switch kind {
        case .signedOut: "person.crop.circle.badge.exclamationmark"
        case .unreachable: "wifi.exclamationmark"
        case .server: "exclamationmark.icloud"
        case .rejected, .other: "exclamationmark.circle"
        }
    }

    var hint: String {
        switch kind {
        case .signedOut: OnlineText.l.problemSignedOutHint
        case .unreachable: OnlineText.l.problemUnreachableHint
        case .server: OnlineText.l.problemServerHint
        case .rejected, .other: OnlineText.l.showingLastLoaded
        }
    }
}

/// 온라인 창 위쪽의 실패 안내. 요청 번호는 서버 로그의 request_id 와 같아서, 복사해 두면
/// 서버에서 그 요청의 오류 기록을 바로 찾을 수 있다.
@MainActor
struct OnlineFailureBanner: View {
    let problem: OnlineProblem
    let message: String
    let loading: Bool
    /// 자동 재연결 시각. 지났거나 없으면 표시하지 않는다.
    var retryAt: Date? = nil
    /// 로그인이 필요할 때 계정 창을 연다.
    var signIn: (() -> Void)? = nil
    let retry: () -> Void
    @State private var copied = false

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: problem.icon).foregroundStyle(.orange).padding(.top, 2)
            VStack(alignment: .leading, spacing: 3) {
                Text(problem.title).font(Typography.bodySemibold)
                Text(problem.hint).font(Typography.label).foregroundStyle(.secondary)
                Text(message).font(Typography.label).foregroundStyle(.secondary).lineLimit(2).textSelection(.enabled)
                HStack(spacing: 10) {
                    if let id = problem.requestID {
                        Text(OnlineText.l.requestNumber(String(id.prefix(8)))).monospaced().textSelection(.enabled)
                        Button(copied ? OnlineText.l.copiedAction : OnlineText.l.copyAction) {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(id, forType: .string)
                            copied = true
                        }
                        .buttonStyle(.link)
                    }
                    if problem.kind != .signedOut {
                        Button(OnlineText.l.showLogs) { NSWorkspace.shared.activateFileViewerSelecting([AppLog.logFileURL]) }
                            .buttonStyle(.link)
                    }
                    if let retryAt, problem.kind == .unreachable || problem.kind == .server {
                        TimelineView(.periodic(from: .now, by: 1)) { context in
                            let seconds = Int(retryAt.timeIntervalSince(context.date).rounded(.up))
                            if seconds > 0 { Text(OnlineText.l.reconnectIn(seconds)).monospacedDigit() }
                        }
                    }
                }
                .font(Typography.label).foregroundStyle(.secondary)
            }
            Spacer()
            if problem.kind == .signedOut, let signIn {
                Button(OnlineText.l.signIn, action: signIn).buttonStyle(.borderedProminent)
            } else {
                Button(OnlineText.l.retry, action: retry).disabled(loading)
            }
        }
        .padding(12)
        .background(Color.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
        .onChange(of: problem.requestID) { copied = false }
    }
}

// MARK: - 알림이 가리킨 항목

/// 알림에서 넘어온 항목을 테두리로 잠깐 짚어 준다. 글자는 그대로 두고 상자만 나타났다 사라진다.
@MainActor
private struct OnlineFocusRing: ViewModifier {
    let active: Bool
    let cornerRadius: CGFloat
    let outset: CGFloat

    func body(content: Content) -> some View {
        content.overlay {
            RoundedRectangle(cornerRadius: cornerRadius)
                .strokeBorder(Color.accentColor, lineWidth: 2)
                .padding(-outset)
                .opacity(active ? 1 : 0)
                .allowsHitTesting(false)
                .animation(.easeOut(duration: 0.3), value: active)
        }
    }
}

enum OnlineFocus {
    /// 테두리를 바깥으로 내는 목록은 스크롤 영역을 양옆으로 이만큼 넓히고 내용은 그만큼 들여
    /// 제자리에 둔다. 그러지 않으면 가장자리에 붙은 항목의 테두리가 스크롤 영역에 잘린다.
    static let gutter: CGFloat = 8
}

extension View {
    /// `outset` 은 배경 없이 글자만 있는 줄에서 테두리가 글자에 붙지 않게 바깥으로 내는 폭이다.
    func onlineFocusRing(_ active: Bool, cornerRadius: CGFloat = 10, outset: CGFloat = 0) -> some View {
        modifier(OnlineFocusRing(active: active, cornerRadius: cornerRadius, outset: outset))
    }

    /// 이 목록에 알림이 가리킨 항목이 있으면 그쪽으로 스크롤한다. 목록을 새로 받았을 때와
    /// 다른 알림을 눌렀을 때 다시 살핀다.
    @MainActor
    func revealsOnlineFocus(_ model: OnlineHubModel, in items: [[String: Any]],
                            with scroller: ScrollViewProxy) -> some View {
        onChange(of: model.generation, initial: true) { model.revealFocus(in: items, with: scroller) }
            .onChange(of: model.focusID) { model.revealFocus(in: items, with: scroller) }
    }
}

extension OnlineHubModel {
    func revealFocus(in items: [[String: Any]], with scroller: ScrollViewProxy) {
        guard let id = takeFocus(among: items.map { $0.string("id") }),
              let row = items.first(where: { $0.string("id") == id }) else { return }
        let anchor = row.onlineID
        // 방금 받은 줄이 화면에 놓인 다음에 움직인다.
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(80))
            withAnimation(.easeOut(duration: 0.25)) { scroller.scrollTo(anchor, anchor: .center) }
        }
    }
}
