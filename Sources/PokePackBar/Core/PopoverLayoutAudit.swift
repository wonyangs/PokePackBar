import AppKit
import SwiftUI

/// Production-view diagnostics with an isolated wallet and no provider polling.
/// Screenshots establish layout, not correctness of the holographic materials.
@MainActor
enum PopoverLayoutAudit {
    static func run(output: URL) async throws {
        let files = FileManager.default
        try files.createDirectory(at: output, withIntermediateDirectories: true)
        let fixture = output.appendingPathComponent("fixture", isDirectory: true)
        try files.createDirectory(at: fixture, withIntermediateDirectories: true)
        let defaultsSuite = "ppb-layout-audit-\(UUID().uuidString)"
        guard let index = CardIndex.shared,
              let defaults = UserDefaults(suiteName: defaultsSuite) else {
            throw LocalAudit.Failure(description: "Layout fixtures unavailable")
        }
        defer { defaults.removePersistentDomain(forName: defaultsSuite) }
        defaults.set(0, forKey: "refreshInterval")
        defaults.set(true, forKey: "disableKeychainAccess")
        defaults.set(false, forKey: "statusChecksEnabled")
        defaults.set(ReleaseNotes.runningVersion ?? "", forKey: "lastSeenReleaseVersion")
        let usage = UsageStore(providers: [], autoRefresh: false, defaults: defaults)
        let wallet = WalletStore(fileURL: fixture.appendingPathComponent("game-state.json"))
        wallet.setLanguage(LayoutAuditOptions.language)
        LayoutAuditOptions.applyAppearance()
        wallet.collect(Array(index.cards.prefix(40)).map(\.id))
        wallet.collect(Array(index.cards.prefix(20)).map(\.id))
        wallet.addPack(setID: "cel30")
        let updater = UpdateChecker(currentVersion: "0.0.0")
        var measurements: [[String: Any]] = []

        for (name, grid) in CardGrid.all {
            try LocalAudit.require(grid.totalWidth <= grid.available && grid.available <= PopoverMetrics.contentWidth,
                                   "Overflowing compact grid: \(name)")
        }
        try LocalAudit.require(RevealPeek.cardWidth / 0.717 + 170 <= PopoverMetrics.tabHeight,
                               "Reveal card leaves no room for actions")
        try LocalAudit.require(PopoverMetrics.pulledCardWidth / 0.717 + 190 <= PopoverMetrics.tabHeight,
                               "Oripa reveal leaves no room for actions")

        func capture(_ name: String, view: AnyView, fixedHeight: CGFloat? = nil) async throws {
            let controller = NSHostingController(rootView: view.background(Color(NSColor.windowBackgroundColor)))
            let proposed = controller.sizeThatFits(in: CGSize(width: PopoverMetrics.width, height: 1000))
            let size = CGSize(width: PopoverMetrics.width, height: fixedHeight ?? proposed.height.rounded(.up))
            let window = NSWindow(contentRect: NSRect(origin: .zero, size: size),
                                  styleMask: [.borderless], backing: .buffered, defer: false)
            window.isReleasedWhenClosed = false
            window.contentViewController = controller
            controller.view.setFrameSize(size)
            controller.view.layoutSubtreeIfNeeded()
            try await Task.sleep(for: .milliseconds(250))
            controller.view.layoutSubtreeIfNeeded()
            controller.view.displayIfNeeded()
            guard let bitmap = controller.view.bitmapImageRepForCachingDisplay(in: controller.view.bounds) else {
                throw LocalAudit.Failure(description: "Cannot capture \(name)")
            }
            controller.view.cacheDisplay(in: controller.view.bounds, to: bitmap)
            guard let data = bitmap.representation(using: .png, properties: [:]) else {
                throw LocalAudit.Failure(description: "Cannot encode \(name)")
            }
            try data.write(to: output.appendingPathComponent(name+".png"), options: .atomic)
            measurements.append(["screen": name, "width": size.width, "height": size.height,
                                 "intrinsicWidth": controller.view.fittingSize.width,
                                 "intrinsicHeight": controller.view.fittingSize.height])
            window.close()
        }

        for tab in PopoverTab.allCases {
            let nav = PopoverNavigation(); nav.tab = tab
            try await capture("tab-\(tab)", view: AnyView(PopoverView()
                .environment(usage).environment(wallet).environment(updater).environment(nav)))
        }
        let rewardNav = PopoverNavigation()
        rewardNav.tab = .dex
        rewardNav.rewardNotice = RewardNotice(reward: DexReward(packs: 0, perks: [], tokens: 2_000_000), homeSet: "base1")
        try await capture("reward-banner", view: AnyView(PopoverView()
            .environment(usage).environment(wallet).environment(updater).environment(rewardNav)))
        // 처음 연 사람의 화면. 카드가 한 장도 없어야 안내 카드가 뜬다. 폴더를 따로 둔다 — 같은
        // 폴더에 두면 위 지갑의 백업을 찾아 복구해 버린다.
        let firstRunFolder = fixture.appendingPathComponent("first-run", isDirectory: true)
        try files.createDirectory(at: firstRunFolder, withIntermediateDirectories: true)
        let firstRun = WalletStore(fileURL: firstRunFolder.appendingPathComponent("game-state.json"))
        firstRun.setLanguage(LayoutAuditOptions.language)
        try await capture("first-run", view: AnyView(PopoverView()
            .defaultAppStorage(defaults)
            .environment(usage).environment(firstRun).environment(updater).environment(PopoverNavigation())))
        defaults.set(true, forKey: "bulkSaleAllPrices")
        try await capture("bulk-sale-all-prices", view: AnyView(
            BulkSaleView(wallet: wallet, pool: Array(index.cards.prefix(40)), onClose: {})
                .defaultAppStorage(defaults)
                .frame(width: PopoverMetrics.contentWidth, height: PopoverMetrics.tabHeight)
                .padding(PopoverMetrics.padding)),
            fixedHeight: PopoverMetrics.tabHeight + PopoverMetrics.padding * 2)
        try await capture("dex-tier-5", view: AnyView(
            DexView(wallet: wallet, index: index, initialTier: 5)
                .environment(PopoverNavigation())
                .frame(width: PopoverMetrics.contentWidth, height: PopoverMetrics.tabHeight)
                .padding(PopoverMetrics.padding)),
            fixedHeight: PopoverMetrics.tabHeight + PopoverMetrics.padding * 2)
        try await capture("dex-search", view: AnyView(
            DexView(wallet: wallet, index: index, initialSearchText: "피카츄")
                .environment(PopoverNavigation())
                .frame(width: PopoverMetrics.contentWidth, height: PopoverMetrics.tabHeight)
                .padding(PopoverMetrics.padding)),
            fixedHeight: PopoverMetrics.tabHeight + PopoverMetrics.padding * 2)
        for notes in [false, true] {
            let nav = PopoverNavigation(); nav.showSettings = !notes; nav.showReleaseNotes = notes
            try await capture(notes ? "release-notes" : "settings", view: AnyView(PopoverView()
                .environment(usage).environment(wallet).environment(updater).environment(nav)))
        }
        let nav = PopoverNavigation()
        for id in ["cel30c-29", "me2pt5-295", "base1-4"] {
            guard let card = index.card(id) else { continue }
            wallet.collect(id == "base1-4" ? [id, id, id] : [id])
            let view = CardSpotlightView(wallet: wallet, cardID: id, name: card.displayName(wallet.language),
                tier: card.tier, setID: card.setID, setName: index.set(card.setID)?.name ?? card.setID,
                rarity: card.rarity, ownedCount: wallet.cardCount(id),
                preloaded: CardImageLoader.cachedImage(cardID: id, hires: true), onClose: {})
                .environment(nav).frame(width: PopoverMetrics.contentWidth, height: PopoverMetrics.tabHeight)
                .padding(PopoverMetrics.padding)
            try await capture("detail-\(id)", view: AnyView(view), fixedHeight: PopoverMetrics.tabHeight + PopoverMetrics.padding*2)
        }
        if let card = index.card("me2pt5-295") {
            for opened in [false, true] {
                let pulled = PulledCardView(wallet: wallet,
                    card: PulledCard(id: card.id, tier: card.tier, isNew: true, finish: .gold),
                    startOpened: opened, onReveal: {}, onDetail: {}, onDone: {},
                    name: card.displayName(wallet.language))
                    .environment(nav)
                    .frame(width: PopoverMetrics.contentWidth, height: PopoverMetrics.tabHeight-36)
                    .padding(PopoverMetrics.padding)
                try await capture(opened ? "oripa-revealed" : "oripa-covered", view: AnyView(pulled),
                    fixedHeight: PopoverMetrics.tabHeight-36+PopoverMetrics.padding*2)
            }
        }
        // 팩 뜯기 화면과 그다음 첫 장 화면. 두 화면은 같은 골격이라 카드 자리가 겹쳐야 한다.
        let tearCards = index.cards(inSet: "cel30").prefix(3).compactMap(index.card).map {
            PulledCard(id: $0.id, tier: $0.tier, isNew: false, finish: .normal)
        }
        let tearPresentation = PackPresentation(packs: [OpenedCards(
            slotResults: tearCards.map { PackSlotResult(card: $0, finishHint: .defaultForCard) },
            variant: .standard)], setID: "cel30", era: index.era("cel30"))
        try await capture("pack-tear", view: AnyView(
            PackTearView(wallet: wallet, setID: "cel30", setName: index.set("cel30")?.name ?? "cel30",
                         packCount: 1, pending: nil, onCancel: {}, onReady: { _ in })
                .environment(nav)
                .frame(width: PopoverMetrics.contentWidth, height: PopoverMetrics.tabHeight)
                .padding(PopoverMetrics.padding)),
            fixedHeight: PopoverMetrics.tabHeight + PopoverMetrics.padding * 2)
        try await capture("pack-reveal-first", view: AnyView(
            PacksView.auditPresentation(wallet: wallet, index: index, presentation: tearPresentation,
                                        summary: false)
                .environment(nav)
                .frame(width: PopoverMetrics.contentWidth, height: PopoverMetrics.tabHeight)
                .padding(PopoverMetrics.padding)),
            fixedHeight: PopoverMetrics.tabHeight + PopoverMetrics.padding * 2)
        let picking = OripaPickingScreen(wallet: wallet, index: index, box: wallet.oripaBox(index: index),
                                        picked: .constant(3), onBack: {}, onPull: {})
            .frame(width: PopoverMetrics.contentWidth)
        let host = NSHostingController(rootView: picking)
        let minimum = host.sizeThatFits(in: CGSize(width: PopoverMetrics.contentWidth, height: 0))
        try LocalAudit.require(minimum.height <= PopoverMetrics.tabHeight - 36,
                               "Oripa grid/actions exceed compact tab: \(minimum.height)")
        try await capture("oripa-picking", view: AnyView(picking
            .frame(height: PopoverMetrics.tabHeight-36).padding(PopoverMetrics.padding)),
            fixedHeight: PopoverMetrics.tabHeight-36+PopoverMetrics.padding*2)
        // 팩 이름 검색: 결과, 결과 없음(영어 이름 안내), 종류가 많은 팩 탭.
        for (name, query) in [("shop-search", "evol"), ("shop-search-empty", "스칼렛")] {
            try await capture(name, view: AnyView(
                CardShopView(wallet: wallet, index: index, initialPackQuery: query)
                    .environment(nav)
                    .frame(width: PopoverMetrics.contentWidth, height: PopoverMetrics.tabHeight)
                    .padding(PopoverMetrics.padding)),
                fixedHeight: PopoverMetrics.tabHeight + PopoverMetrics.padding * 2)
        }
        // 맨 위 줄(cel30)은 두 개다. 여러 개 가진 줄에만 수량 칸과 「최대」 가 붙는다.
        for setID in ["cel30", "sv1", "sv2", "sv3", "sv3pt5", "sv4", "swsh1"] { wallet.addPack(setID: setID) }
        try await capture("packs-search", view: AnyView(
            PacksView(wallet: wallet, index: index)
                .environment(nav)
                .frame(width: PopoverMetrics.contentWidth, height: PopoverMetrics.tabHeight)
                .padding(PopoverMetrics.padding)),
            fixedHeight: PopoverMetrics.tabHeight + PopoverMetrics.padding * 2)
        let priceSeries = PriceSeries(kind: "printing", item: "base1-4#holo", latest_day: "2026-10-29", points: [
            .init(day: "2026-09-23", usd: 300), .init(day: "2026-10-15", usd: 330), .init(day: "2026-10-28", usd: 360)])
        for (name, series, failed) in [
            ("price-history", Optional(priceSeries), false),
            ("price-history-empty", Optional(PriceSeries(kind: "card", item: "fixture", latest_day: nil, points: [])), false),
            ("price-history-failed", Optional<PriceSeries>.none, true)
        ] {
            try await capture(name, view: AnyView(PriceHistoryPanel(wallet: wallet, title: index.card("base1-4")?.displayName(wallet.language) ?? "Charizard",
                subtitle: nil, range: .constant(.quarter), series: series, seriesRange: .quarter, failed: failed, retry: {})
                .padding(PopoverMetrics.padding)))
        }
        let priceMove = PriceMove(kind: "printing", item: "base1-4#holo", before: 300, after: 360, count: 2)
        let priceReport = PriceReport(day: "2026-10-29", since: "2026-10-28", changed: 2,
            risers: [priceMove], fallers: [.init(kind: "card", item: "base1-1", before: 12, after: 10)],
            packs: [.init(kind: "pack", item: "base1", before: 900, after: 880)], owned: [priceMove])
        try await capture("price-news", view: AnyView(PriceNewsSection(wallet: wallet, report: priceReport,
            failed: false, index: index, onCard: { _, _ in }, onPack: { _ in })
            .frame(width: PopoverMetrics.contentWidth).padding(PopoverMetrics.padding)))
        let report: [String: Any] = ["popoverWidth": PopoverMetrics.width, "tabHeight": PopoverMetrics.tabHeight,
                                    "oripaMinimumHeight": minimum.height, "screens": measurements,
                                    "usesLiveWallet": false, "pollsProviders": false]
        try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys])
            .write(to: output.appendingPathComponent("layout.json"), options: .atomic)
        print("PASS compact popover layout: \(measurements.count) native screens; isolated wallet; \(Int(PopoverMetrics.width))pt wide")
    }
}

/// 레이아웃 감사의 언어와 화면 모드. 기본은 한국어와 시스템 모드다.
///
/// `--audit-language en` 처럼 주면 다른 언어에서 글자가 넘치거나 잘리는지 볼 수 있고,
/// `--audit-appearance light` 로 라이트 모드 대비를 따로 확인한다.
@MainActor
enum LayoutAuditOptions {
    static var language: AppLanguage {
        value(after: "--audit-language").flatMap(AppLanguage.init(rawValue:)) ?? .ko
    }

    /// 감사 창이 모두 같은 모드로 그려지게 앱 전체 모드를 정한다.
    static func applyAppearance() {
        switch value(after: "--audit-appearance") {
        case "light": NSApp.appearance = NSAppearance(named: .aqua)
        case "dark": NSApp.appearance = NSAppearance(named: .darkAqua)
        default: break
        }
    }

    private static func value(after flag: String) -> String? {
        let arguments = CommandLine.arguments
        guard let at = arguments.firstIndex(of: flag), arguments.indices.contains(at + 1) else { return nil }
        return arguments[at + 1]
    }
}
