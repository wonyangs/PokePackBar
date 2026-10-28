import SwiftUI

/// 통계 탭의 「오늘의 시세」. 가장 최근 시세 갱신에서 크게 움직인 카드와 팩, 그리고 내 카드.
///
/// 처음에는 세 묶음을 세 줄씩만 보인다. 기록 화면의 다른 묶음과 높이를 맞추려는 것이고,
/// 더 보고 싶으면 펼친다. 줄을 누르면 카드 상세나 상점의 그 팩으로 간다.
/// 온라인 계정에서만 보인다. 기록은 서버가 날마다 남긴다.
@MainActor
struct PriceNewsSection: View {
    let wallet: WalletStore
    let report: PriceReport?
    /// 한 번도 읽지 못했다.
    let failed: Bool
    let index: CardIndex?
    let onCard: (String, CardFinish?) -> Void
    let onPack: (String) -> Void

    @State private var expanded = false

    private struct Group: Identifiable {
        let title: String
        let moves: [PriceMove]
        /// 내 카드 묶음이면 장수까지 곱한 값의 변화를 보인다.
        let mine: Bool
        var id: String { title }
    }

    private static let collapsed = 3
    private static let expandedLimit = 10

    var body: some View {
        let l = wallet.l
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(l.priceNewsHeader).font(Typography.labelSemibold).foregroundStyle(.secondary)
                Spacer(minLength: 6)
                if let day = report?.day, let date = PriceHistoryRequest.day(day) {
                    Text(l.priceNewsAsOf(date.formatted(.dateTime.month().day()
                        .locale(wallet.language.displayLocale))))
                        .font(Typography.label).foregroundStyle(.tertiary)
                }
            }
            VStack(alignment: .leading, spacing: 7) { content(l) }
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.secondary.opacity(0.07), in: RoundedRectangle(cornerRadius: 6))
        }
    }

    @ViewBuilder
    private func content(_ l: L) -> some View {
        if let report {
            if report.day == nil {
                note(l.priceNewsGathering)
            } else {
                let packs = report.packs.sorted { abs($0.rate) > abs($1.rate) }
                let groups = [
                    Group(title: l.priceNewsMine, moves: report.owned, mine: true),
                    Group(title: l.priceNewsRisers, moves: report.risers, mine: false),
                    Group(title: l.priceNewsFallers, moves: report.fallers, mine: false),
                ]
                let limit = expanded ? Self.expandedLimit : Self.collapsed
                if groups.allSatisfy({ $0.moves.isEmpty }) && packs.isEmpty {
                    note(l.priceNewsQuiet)
                }
                ForEach(groups.filter { !$0.moves.isEmpty }) { entry in
                    group(entry.title) {
                        ForEach(entry.moves.prefix(limit)) { move in cardRow(l, move, mine: entry.mine) }
                    }
                }
                if !packs.isEmpty {
                    group(l.priceNewsPacks) {
                        ForEach(packs.prefix(expanded ? Self.expandedLimit : 2)) { move in packRow(l, move) }
                    }
                }
                if groups.contains(where: { $0.moves.count > Self.collapsed }) || packs.count > 2 {
                    Button(expanded ? l.priceNewsShowLess : l.showMore) { expanded.toggle() }
                        .buttonStyle(.plain)
                        .font(Typography.label)
                        .foregroundStyle(Color.accentColor)
                }
            }
        } else if failed {
            note(l.priceNewsUnavailable)
        } else {
            note(l.loading)
        }
    }

    private func group(_ title: String, @ViewBuilder rows: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(Typography.label).foregroundStyle(.secondary)
            rows()
        }
    }

    private func note(_ text: String) -> some View {
        Text(text).font(Typography.label).foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    /// 내 카드는 장수까지 곱한 값의 변화를, 나머지는 지금 값을 보인다.
    private func cardRow(_ l: L, _ move: PriceMove, mine: Bool) -> some View {
        let name = index?.card(move.cardID)?.displayName(wallet.language) ?? move.cardID
        return Button { onCard(move.cardID, move.finish) } label: {
            HStack(spacing: 6) {
                Text(name).font(Typography.body).lineLimit(1)
                if let finish = move.finish {
                    Text(l.cardFinishName(finish, cardID: move.cardID))
                        .font(Typography.label).foregroundStyle(.tertiary).lineLimit(1)
                }
                if mine, let count = move.count, count > 1 {
                    Text("×\(count)").font(Typography.label).foregroundStyle(.tertiary).fixedSize()
                }
                Spacer(minLength: 6)
                change(move)
                Text(mine ? valueChange(move) : money(move.after))
                    .font(Typography.label).monospacedDigit().foregroundStyle(.secondary)
                    .lineLimit(1).fixedSize()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(l.priceNewsRowHelp)
    }

    private func packRow(_ l: L, _ move: PriceMove) -> some View {
        Button { onPack(move.item) } label: {
            HStack(spacing: 6) {
                Text(index?.set(move.item)?.name ?? move.item).font(Typography.body).lineLimit(1)
                Spacer(minLength: 6)
                change(move)
                Text(money(move.after))
                    .font(Typography.label).monospacedDigit().foregroundStyle(.secondary)
                    .lineLimit(1).fixedSize()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(l.priceNewsPackHelp)
    }

    /// 부호가 방향을 말하고, 색은 거든다. 한국어에서는 증시처럼 오르면 빨강, 내리면 파랑이다.
    private func change(_ move: PriceMove) -> some View {
        let up: Color = wallet.language == .ko ? .red : .green
        let down: Color = wallet.language == .ko ? .blue : .red
        return Text(PriceChangeFormat.percent(move.rate))
            .font(Typography.bodySemibold).monospacedDigit()
            .foregroundStyle(move.rose ? up : down)
            .lineLimit(1).fixedSize()
    }

    private func money(_ usd: Double) -> String {
        guard let prices = CardPrices.shared else { return TokenFormatter.cost(usd) }
        return WonFormatter.money(prices.krw(usd), language: wallet.language)
    }

    private func valueChange(_ move: PriceMove) -> String {
        guard let prices = CardPrices.shared else { return TokenFormatter.cost(move.valueChange) }
        let count = move.count ?? 1
        return PriceChangeFormat.won((prices.krw(move.after) - prices.krw(move.before)) * count,
                                     language: wallet.language)
    }
}
