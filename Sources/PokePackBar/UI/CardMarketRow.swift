import AppKit
import SwiftUI

/// 카드 한 장의 온라인 마켓 판매 글 요약.
struct CardMarketSummary: Equatable {
    var count: Int
    /// 한 번에 받은 100건 뒤에도 더 있는가.
    var more: Bool
    var lowestTokens: Int?

    /// `v1/market/listings?q=<카드>#&sort=price` 응답에서 내가 살 수 있는 글만 센다.
    ///
    /// 서버 검색은 판형 키(`카드#판형`)의 일부로도 찾는다. `카드#` 로 찾으면 그 카드의 모든 판형만
    /// 나오지만, 응답을 한 번 더 걸러 다른 카드가 섞이지 않게 한다. 내 글과, 이미 한 장을 산
    /// 봇 매물(계정마다 한 장)은 뺀다.
    static func from(_ reply: [String: Any], cardID: String) -> CardMarketSummary {
        // 카드 번호는 마지막 「#」 앞이다. 앱이 모르는 판형 이름이 와도 카드는 맞게 가린다.
        let items = (reply["items"] as? [[String: Any]] ?? []).filter { item in
            let printing = item.string("printing")
            let card = printing.lastIndex(of: "#").map { String(printing[..<$0]) } ?? printing
            return card == cardID && !item.bool("mine") && !item.bool("bought")
        }
        return CardMarketSummary(count: items.count, more: reply["next_offset"] is NSNumber,
                                 lowestTokens: items.map { $0.int("unit_tokens") }.min())
    }

    static func query(cardID: String) -> String {
        let key = "\(cardID)#".addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? cardID
        return "v1/market/listings?q=\(key)&sort=price&limit=100"
    }
}

/// 위시리스트를 서버에 다시 보낼 형태로 다룬다. 서버는 목록 전체를 한 번에 바꾼다.
enum CardWishlist {
    static func wishes(fromProfile reply: [String: Any]) -> [[String: Any]] {
        let profile = reply["profile"] as? [String: Any] ?? [:]
        return (profile["wishlist"] as? [[String: Any]] ?? []).map { wish in
            ["card_id": wish.string("card_id"), "finish": wish["finish"] ?? NSNull(), "target": max(1, wish.int("target"))]
        }
    }

    /// 판형을 가리지 않고 이 카드가 들어 있는가.
    static func contains(_ wishes: [[String: Any]], cardID: String) -> Bool {
        wishes.contains { $0.string("card_id") == cardID }
    }

    /// 있으면 그 카드의 항목을 모두 빼고, 없으면 판형을 가리지 않는 한 장으로 넣는다.
    static func toggled(_ wishes: [[String: Any]], cardID: String) -> [[String: Any]] {
        contains(wishes, cardID: cardID)
            ? wishes.filter { $0.string("card_id") != cardID }
            : wishes + [["card_id": cardID, "finish": NSNull(), "target": 1]]
    }
}

/// 카드 상세의 마켓 줄. 판매 글 수와 최저가를 보여 주고, 누르면 온라인 마켓에서 그 카드를 찾아 둔다.
/// 하트는 위시리스트에 넣고 뺀다 — 넣어 두면 마켓에 올라올 때 서버가 알려 준다.
///
/// 온라인 계정일 때만 쓴다. 상세를 열 때마다 서버에 두 번 묻는다(판매 글, 프로필).
@MainActor
struct CardMarketRow: View {
    let wallet: WalletStore
    let cardID: String

    @State private var summary: CardMarketSummary?
    @State private var failed = false
    /// 불러오기 전에는 nil. 하트는 그때 누를 수 없다.
    @State private var wishes: [[String: Any]]?
    @State private var wishBusy = false

    var body: some View {
        let l = wallet.l
        HStack(spacing: 6) {
            if let summary, summary.count > 0, let lowest = summary.lowestTokens {
                Button { OnlineWindow.shared.showBuying(wallet: wallet, cardID: cardID) } label: {
                    Text(l.cardListings(summary.count, more: summary.more,
                                        lowest: MarketEconomy.money(tokens: lowest, language: wallet.language)))
                        .font(Typography.bodySemibold).monospacedDigit()
                        .foregroundStyle(Color.accentColor)
                }
                .buttonStyle(.plain)
                .help(l.cardSeeListingsHelp)
            } else {
                Text(summary != nil ? l.cardNoListings : failed ? l.cardListingsUnavailable : l.cardListingsLoading)
                    .font(Typography.label).foregroundStyle(.secondary)
            }
            wishButton(l)
        }
        .lineLimit(1).minimumScaleFactor(0.75)
        .task(id: cardID) { await load() }
    }

    @ViewBuilder
    private func wishButton(_ l: L) -> some View {
        let wished = wishes.map { CardWishlist.contains($0, cardID: cardID) } ?? false
        Button { Task { await toggleWish() } } label: {
            Image(systemName: wished ? "heart.fill" : "heart")
                .font(.system(size: 14))
                .foregroundStyle(wished ? Color.pink : Color.secondary)
        }
        .buttonStyle(.plain)
        .disabled(wishes == nil || wishBusy)
        .help(wished ? l.wishlistRemoveHelp : l.wishlistAddHelp)
        .accessibilityLabel(wished ? l.wishlistRemoveHelp : l.addToWishlist)
    }

    private func load() async {
        summary = nil; failed = false; wishes = nil
        guard let remote = wallet.remote else { return }
        async let listings = remote.api(CardMarketSummary.query(cardID: cardID))
        async let profile = remote.api("v1/profile")
        if let data = try? await listings,
           let reply = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            summary = .from(reply, cardID: cardID)
        } else if !Task.isCancelled {
            failed = true
        }
        if let data = try? await profile,
           let reply = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            wishes = CardWishlist.wishes(fromProfile: reply)
        }
    }

    /// 서버는 목록 전체를 받는다. 다른 기기에서 바꾼 것을 덮지 않게 보내기 직전에 다시 읽는다.
    private func toggleWish() async {
        guard let remote = wallet.remote, !wishBusy else { return }
        wishBusy = true
        defer { wishBusy = false }
        do {
            let fresh = try JSONSerialization.jsonObject(with: try await remote.api("v1/profile")) as? [String: Any] ?? [:]
            let next = CardWishlist.toggled(CardWishlist.wishes(fromProfile: fresh), cardID: cardID)
            // 10초마다 도는 동기화와 겹치면 명령이 거절된다. 잠깐 기다렸다 보낸다.
            for _ in 0..<30 where remote.busy { try await Task.sleep(for: .milliseconds(100)) }
            let body: [String: Any] = ["action": "wishlist", "wishes": next,
                                       "request_id": UUID().uuidString, "expected_revision": remote.revision]
            _ = try await remote.onlineMutation(path: "v1/wishlist",
                                                body: JSONSerialization.data(withJSONObject: body, options: [.sortedKeys]))
            wishes = next
        } catch {
            AppLog.write("[online] wishlist toggle failed: \(error.localizedDescription)")
        }
    }
}

/// 출처 팩과 뽑힐 확률 두 줄. 마켓 판매 글처럼 카드 상세 밖에서 쓴다.
///
/// 확률을 카드 번호 바로 뒤에 붙였더니 「1/102 약 48팩에 1장」이 한 덩어리로 읽혔다.
/// 카드 상세와 같은 이름을 달아 줄을 나눈다.
@MainActor
struct CardSourceLine: View {
    let source: CardSource
    let l: L

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 5) {
                PackImageView(setID: source.setID, width: 14)
                Text(source.setName).lineLimit(1).truncationMode(.tail)
                if let number = source.number {
                    Text(number).monospacedDigit().foregroundStyle(.tertiary).fixedSize()
                }
            }
            .accessibilityElement(children: .combine)
            if let chance = source.chanceText(l) {
                Text("\(l.pullChanceLabel) \(chance)").monospacedDigit()
                    .help(source.perPack < 1 ? l.dexPullChance(DexFormat.percent(source.perPack)) : "")
            }
        }
        .font(Typography.label)
        .foregroundStyle(.secondary)
    }
}
