import Charts
import SwiftUI

/// 시세 기록 그래프. 카드 상세의 시세 줄과 상점의 팩 상세에서 작은 창으로 띄운다.
///
/// 그 자리에 그래프를 펼치면 카드가 밀려 작아진다. 카드 크기와 자리를 지키려고 따로 띄운다.
/// 값이 바뀐 날만 점이 있으므로 계단 선으로 그린다. 두 점 사이를 비스듬히 이으면 그사이에
/// 없던 값이 있었던 것처럼 보인다. 온라인 계정에서만 쓴다. 기록은 서버에만 있다.
@MainActor
struct PriceHistoryView: View {
    let wallet: WalletStore
    let title: String
    let subtitle: String?
    let kind: String
    let item: String

    @State private var range: PriceHistoryRange = .quarter
    @State private var loaded: (range: PriceHistoryRange, series: PriceSeries)?
    @State private var failed = false

    var body: some View {
        PriceHistoryPanel(wallet: wallet, title: title, subtitle: subtitle, range: $range,
                          series: loaded?.series, seriesRange: loaded?.range, failed: failed) {
            Task { await load() }
        }
        .task(id: range) { await load() }
    }

    private func load() async {
        failed = false
        guard let remote = wallet.remote else { return }
        let requested = range
        do {
            let data = try await remote.api(PriceHistoryRequest.path(kind: kind, item: item, range: requested))
            let series = try JSONDecoder().decode(PriceSeries.self, from: data)
            guard requested == range else { return }
            loaded = (requested, series)
        } catch {
            if !Task.isCancelled && loaded == nil { failed = true }
        }
    }
}

/// 받아 온 기록을 그린다. 서버에 묻는 일은 `PriceHistoryView` 가 한다.
@MainActor
struct PriceHistoryPanel: View {
    let wallet: WalletStore
    let title: String
    let subtitle: String?
    @Binding var range: PriceHistoryRange
    let series: PriceSeries?
    /// `series` 가 어느 기간의 것인가. 기간을 바꾼 직전에는 앞 기간의 선이 남아 있다.
    let seriesRange: PriceHistoryRange?
    let failed: Bool
    let retry: () -> Void

    @State private var hovered: Date?

    private var prices: CardPrices? { CardPrices.shared }
    private var samples: [PriceSeries.Sample] { series?.samples() ?? [] }

    var body: some View {
        let l = wallet.l
        VStack(alignment: .leading, spacing: 10) {
            header(l)
            SegmentedTabs(items: PriceHistoryRange.allCases.map { .init(value: $0, label: l.priceRange($0)) },
                          selection: $range)
            content(l)
                .frame(height: 170)
        }
        .padding(14)
        .frame(width: 340)
        .onChange(of: series) { hovered = nil }
    }

    // MARK: 머리

    /// 값이 먼저, 설명이 뒤. 가리키는 날이 있으면 그날의 값을, 없으면 지금 값과 기간 변동을 보인다.
    private func header(_ l: L) -> some View {
        let samples = samples
        let focus = hovered.flatMap { PriceSeries.value(at: $0, in: samples) }
        let shown = focus ?? samples.last
        return VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(title).font(Typography.title).lineLimit(1)
                if let subtitle {
                    Text(subtitle).font(Typography.label).foregroundStyle(.secondary).lineLimit(1)
                }
            }
            Text(shown.map { money($0.usd) } ?? " ")
                .font(Typography.amount).monospacedDigit()
                .lineLimit(1).minimumScaleFactor(0.8)
            Text(caption(l, samples: samples, hovered: hovered))
                .font(Typography.label).monospacedDigit()
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }

    private func caption(_ l: L, samples: [PriceSeries.Sample], hovered: Date?) -> String {
        if let hovered { return dayText(hovered) }
        guard seriesRange == range, let first = samples.first, let last = samples.last,
              first.usd > 0, samples.count > 1 else { return " " }
        return l.priceChangeOver(PriceChangeFormat.percent((last.usd - first.usd) / first.usd), range)
    }

    // MARK: 그래프

    @ViewBuilder
    private func content(_ l: L) -> some View {
        let samples = samples
        if series == nil {
            if failed {
                VStack(spacing: 8) {
                    Text(l.priceHistoryFailed).font(Typography.label).foregroundStyle(.secondary)
                    Button(l.retry, action: retry).font(Typography.button)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ProgressView().controlSize(.small).frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        } else if samples.isEmpty {
            note(l.priceHistoryEmpty)
        } else if samples.count == 1 {
            note(l.priceHistoryOneDay)
        } else {
            chart(samples)
        }
    }

    private func note(_ text: String) -> some View {
        Text(text)
            .font(Typography.label).foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func chart(_ samples: [PriceSeries.Sample]) -> some View {
        let values = samples.map { won($0.usd) }
        let low = values.min() ?? 0, high = values.max() ?? 1
        // 값이 그대로면 위아래로 여유를 둬 선이 축에 붙지 않게 한다.
        let pad = max((high - low) * 0.12, high * 0.02, 1)
        let floor = max(0, low - pad), ceiling = high + pad
        let focus = hovered.flatMap { PriceSeries.value(at: $0, in: samples) }

        return Chart {
            ForEach(samples) { sample in
                AreaMark(x: .value("day", sample.date),
                         yStart: .value("won", floor),
                         yEnd: .value("won", won(sample.usd)))
                    .interpolationMethod(.stepEnd)
                    .foregroundStyle(LinearGradient(colors: [Color.accentColor.opacity(0.14), Color.accentColor.opacity(0)],
                                                    startPoint: .top, endPoint: .bottom))
                LineMark(x: .value("day", sample.date), y: .value("won", won(sample.usd)))
                    .interpolationMethod(.stepEnd)
                    .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                    .foregroundStyle(Color.accentColor)
            }
            if let hovered, let focus {
                RuleMark(x: .value("day", hovered))
                    .lineStyle(StrokeStyle(lineWidth: 1))
                    .foregroundStyle(Color.secondary.opacity(0.45))
                // 배경색 고리를 먼저 깔아 선 위에서도 점이 떨어져 보이게 한다.
                PointMark(x: .value("day", hovered), y: .value("won", won(focus.usd)))
                    .symbolSize(150)
                    .foregroundStyle(Color(nsColor: .windowBackgroundColor))
                PointMark(x: .value("day", hovered), y: .value("won", won(focus.usd)))
                    .symbolSize(64)
                    .foregroundStyle(Color.accentColor)
            }
        }
        .chartXScale(domain: samples.first!.date...samples.last!.date)
        .chartYScale(domain: floor...ceiling)
        .chartYAxis {
            AxisMarks(position: .trailing, values: .automatic(desiredCount: 3)) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                    .foregroundStyle(Color.secondary.opacity(0.25))
                AxisValueLabel {
                    if let won = value.as(Double.self) {
                        Text(WonFormatter.money(Int(won.rounded()), language: wallet.language))
                            .font(Typography.caption)
                    }
                }
            }
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { value in
                AxisValueLabel {
                    if let date = value.as(Date.self) {
                        Text(date.formatted(.dateTime.month(.abbreviated).day().locale(wallet.language.displayLocale)))
                            .font(Typography.caption)
                    }
                }
            }
        }
        .chartOverlay { proxy in
            GeometryReader { geometry in
                Rectangle().fill(.clear).contentShape(Rectangle())
                    .onContinuousHover { phase in
                        switch phase {
                        case .active(let location):
                            guard let frame = proxy.plotFrame else { return }
                            let x = location.x - geometry[frame].origin.x
                            guard let date: Date = proxy.value(atX: x) else { return }
                            let day = Calendar.current.startOfDay(for: date)
                            hovered = min(max(day, samples.first!.date), samples.last!.date)
                        case .ended:
                            hovered = nil
                        }
                    }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(accessibilitySummary(samples)))
    }

    private func accessibilitySummary(_ samples: [PriceSeries.Sample]) -> String {
        guard let first = samples.first, let last = samples.last else { return wallet.l.priceHistory }
        let low = samples.map(\.usd).min() ?? first.usd, high = samples.map(\.usd).max() ?? last.usd
        return [wallet.l.priceHistory, wallet.l.priceRange(range),
                "\(dayText(first.date)) \(money(first.usd))", "\(dayText(last.date)) \(money(last.usd))",
                "\(money(low)) / \(money(high))"].joined(separator: ", ")
    }

    // MARK: 값

    private func won(_ usd: Double) -> Double { usd * (prices?.krwPerUSD ?? 1350) }

    private func money(_ usd: Double) -> String {
        prices?.formattedWithKRW(usd, language: wallet.language) ?? TokenFormatter.cost(usd)
    }

    private func dayText(_ date: Date) -> String {
        date.formatted(.dateTime.year().month().day().locale(wallet.language.displayLocale))
    }
}

/// 시세 옆에 붙는 작은 그래프 버튼. 누르면 기록을 작은 창으로 띄운다.
@MainActor
struct PriceHistoryButton: View {
    let wallet: WalletStore
    let title: String
    let subtitle: String?
    let kind: String
    let item: String

    @State private var showing = false

    var body: some View {
        Button { showing.toggle() } label: {
            Image(systemName: "chart.xyaxis.line")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                // 시세 줄보다 높지 않게 둔다. 높으면 카드 상세의 줄 간격이 바뀐다. 누를 자리는 넓힌다.
                .frame(width: 20, height: 17)
                .contentShape(Rectangle().inset(by: -4))
        }
        .buttonStyle(.plain)
        .help(wallet.l.priceHistoryHelp)
        .accessibilityLabel(wallet.l.priceHistoryHelp)
        .popover(isPresented: $showing, arrowEdge: .bottom) {
            PriceHistoryView(wallet: wallet, title: title, subtitle: subtitle, kind: kind, item: item)
        }
    }
}
