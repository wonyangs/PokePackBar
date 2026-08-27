import AppKit
import SwiftUI

/// 기획에 필요한 탭만 둔다 — 팩을 사고, 팩을 열고, 카드를 본다.
/// 잔액과 사용량은 탭이 아니라 상단 고정 영역이 맡는다.
enum PopoverTab: CaseIterable { case shop, packs, collection }

/// 팝오버 치수의 단일 소스. 자식이 쓸 수 있는 폭을 알아야 할 때 이 값을 쓴다 — 넘치는 자식이
/// 부모 폭을 부풀리므로 GeometryReader 로 재면 순환한다.
enum PopoverMetrics {
    static let width: CGFloat = 360
    static let padding: CGFloat = 14
    /// 이 폭을 넘는 자식은 팝오버 창에 좌우로 잘린다.
    static let contentWidth: CGFloat = width - padding * 2
}

/// 팝오버 내부 내비게이션 상태.
/// NSHostingController 는 팝오버를 닫아도 재사용되어 @State 가 유지되므로, 화면 상태를 이
/// Observable 로 분리해 팝오버를 열 때마다 reset() 한다.
@MainActor
@Observable
final class PopoverNavigation {
    var showSettings = false
    var tab: PopoverTab = .shop

    func reset() {
        showSettings = false
        tab = .shop
    }
}

@MainActor
struct PopoverView: View {
    @Environment(UsageStore.self) private var store
    @Environment(WalletStore.self) private var wallet
    @Environment(PopoverNavigation.self) private var nav

    /// 카드 목록은 번들 리소스라 한 번만 읽는다.
    private static let index = CardIndex.loadBundled()

    private var l: L { wallet.l }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if nav.showSettings {
                SettingsView(onClose: { nav.showSettings = false })
            } else {
                walletHeader
                bonusToast
                tabPicker
                tabContent
            }
        }
        .padding(PopoverMetrics.padding)
        .frame(width: PopoverMetrics.width)
    }

    // MARK: 상단 — 재화와 사용량

    private var walletHeader: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(l.walletBalance).font(.caption).foregroundStyle(.secondary)
                    Text(TokenFormatter.compact(wallet.availableTokens))
                        .font(.system(size: 26, weight: .bold)).monospacedDigit()
                }
                Spacer()
                Button {
                    nav.showSettings = true
                } label: {
                    Image(systemName: "gearshape").font(.system(size: 13))
                }
                .buttonStyle(.borderless)
                .help(l.settings)
            }

            if wallet.awaitingFirstUsage {
                Text(l.awaitingUsage)
                    .font(.caption2).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                HStack(spacing: 5) {
                    Text("\(l.todayTokens) \(TokenFormatter.compact(store.todayTotalTokens))")
                        .monospacedDigit()
                    if let top = topWindow {
                        Text("·")
                        Text("\(top.name) \(Int(top.utilization.rounded()))%").monospacedDigit()
                    }
                }
                .font(.caption2).foregroundStyle(.secondary)
                .lineLimit(1)

                if let top = topWindow {
                    ProgressView(value: min(top.utilization, 100), total: 100)
                        .progressViewStyle(.linear)
                        .tint(top.utilization >= 100 ? .green : .accentColor)
                }
            }
        }
        .padding(10)
        .background(Color.secondary.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    /// 가장 많이 찬 한도 창. 보너스 팩이 여기서 나오므로 진행률을 보여 준다.
    private var topWindow: BonusWindow? {
        store.bonusEligibleWindows.max { $0.utilization < $1.utilization }
    }

    /// 보너스 팩 지급 알림. 팝오버 안에서 한 번 보여주고 지운다.
    @ViewBuilder
    private var bonusToast: some View {
        if let grant = wallet.lastGrant {
            let setName = Self.index?.set(grant.setID)?.name ?? grant.setID
            HStack(spacing: 7) {
                Image(systemName: "gift.fill").foregroundStyle(.green)
                VStack(alignment: .leading, spacing: 1) {
                    Text(l.bonusPackTitle).font(.caption.weight(.semibold))
                    Text(l.bonusPackBody(window: grant.windowName, set: setName))
                        .font(.caption2).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                Button {
                    wallet.consumeGrant()
                } label: {
                    Image(systemName: "xmark").font(.system(size: 9))
                }
                .buttonStyle(.borderless)
            }
            .padding(8)
            .background(Color.green.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    // MARK: 탭

    private var tabPicker: some View {
        @Bindable var nav = nav
        return Picker("", selection: $nav.tab) {
            Text(l.shop).tag(PopoverTab.shop)
            Text(packsLabel).tag(PopoverTab.packs)
            Text(l.collection).tag(PopoverTab.collection)
        }
        .pickerStyle(.segmented)
        .labelsHidden()
    }

    /// 미개봉 팩이 있으면 개수를 붙인다 — 뜯을 것이 있는지 탭을 열지 않고 알 수 있어야 한다.
    private var packsLabel: String {
        let count = wallet.totalPackCount
        return count > 0 ? "\(l.packsTab) \(count)" : l.packsTab
    }

    @ViewBuilder
    private var tabContent: some View {
        switch nav.tab {
        case .shop:       CardShopView(wallet: wallet, index: Self.index)
        case .packs:      PacksView(wallet: wallet, index: Self.index)
        case .collection: CardCollectionView(wallet: wallet, index: Self.index)
        }
    }
}
