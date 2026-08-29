import AppKit
import SwiftUI

/// 기획에 필요한 탭만 둔다 — 팩을 사고, 팩을 열고, 카드를 본다.
/// 잔액과 사용량은 탭이 아니라 상단 고정 영역이 맡는다.
enum PopoverTab: CaseIterable { case shop, packs, collection, dex }

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
    var showReleaseNotes = false
    var tab: PopoverTab = .shop

    /// 상점에서 바로 열어야 할 팩. 도감의 「이 팩 사러 가기」가 채운다.
    /// 상점이 한 번 읽고 지운다 — 남겨 두면 다음에 상점을 열 때 또 그 팩이 뜬다.
    var shopSet: String?

    /// 도감 탭에서 바로 열어야 할 도감. 카드 상세의 도감 배지가 채운다.
    var dexID: String?

    func reset() {
        showSettings = false
        showReleaseNotes = false
        tab = .shop
        shopSet = nil
        dexID = nil
    }
}

@MainActor
struct PopoverView: View {
    @Environment(UsageStore.self) private var store
    @Environment(WalletStore.self) private var wallet
    @Environment(UpdateChecker.self) private var updater
    @Environment(PopoverNavigation.self) private var nav

    private static let index = CardIndex.shared

    private var l: L { wallet.l }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // 패치 노트를 먼저 본다 — 설정에서 열었을 때 닫으면 설정으로 돌아가게 하려는 것이다.
            if nav.showReleaseNotes {
                ReleaseNotesView(wallet: wallet, store: store,
                                 onClose: { nav.showReleaseNotes = false })
            } else if nav.showSettings {
                SettingsView(onClose: { nav.showSettings = false },
                             onOpenReleaseNotes: { nav.showReleaseNotes = true })
            } else {
                walletHeader
                bonusToast
                releaseNotesToast
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
                    // 앱 안에서는 실제 숫자를 쓴다. 요약 표기(95.2M)는 메뉴바 전용이다 —
                    // 팩 값과 잔액을 비교하려면 자리수가 그대로 보여야 한다.
                    Text(TokenFormatter.readable(wallet.availableTokens, language: wallet.language))
                        .font(.system(size: 22, weight: .bold)).monospacedDigit()
                        .lineLimit(1).minimumScaleFactor(0.6)
                }
                Spacer()
                // 새 버전이 있으면 설정 옆에 바로 띄운다. 설정 안에 숨겨 두면
                // 들어가 보지 않는 한 업데이트가 있는지도 모른다.
                if let update = updater.available {
                    Button {
                        updater.applyUpdate()
                    } label: {
                        HStack(spacing: 3) {
                            Image(systemName: "arrow.down.circle.fill")
                            Text(update.version).monospacedDigit()
                        }
                        .font(.system(size: 11, weight: .semibold))
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.mini)
                    .disabled(updater.isUpdating)
                    .help(l.updateAvailableHelp(update.version))
                }
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
                    Text("\(l.todayTokens) \(TokenFormatter.readable(store.todayTotalTokens, language: wallet.language))")
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
                    Text(l.bonusPackBody(window: grant.windowName, set: setName, count: grant.count))
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

    /// 판올림 안내. 새 버전으로 처음 열었을 때 한 줄만 띄우고, 보거나 닫으면 사라진다.
    @ViewBuilder
    private var releaseNotesToast: some View {
        if let version = ReleaseNotes.runningVersion,
           store.lastSeenReleaseVersion != version,
           l.releaseNotes.contains(where: { $0.version == version }) {
            HStack(spacing: 7) {
                Image(systemName: "sparkles").foregroundStyle(Color.accentColor)
                Text(l.releaseNotesWhatsNew(version))
                    .font(.caption.weight(.semibold))
                    .lineLimit(1).minimumScaleFactor(0.8)
                Spacer(minLength: 0)
                Button(l.releaseNotesOpen) { nav.showReleaseNotes = true }
                    .buttonStyle(.borderless).controlSize(.small)
                Button {
                    store.lastSeenReleaseVersion = version
                } label: {
                    Image(systemName: "xmark").font(.system(size: 9))
                }
                .buttonStyle(.borderless)
            }
            .padding(8)
            .background(Color.accentColor.opacity(0.12))
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
            Text(l.dexTab).tag(PopoverTab.dex)
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        // 폭을 명시한다. 안 적으면 세그먼트 컨트롤이 제 내용 크기로 줄어 왼쪽에 몰리는
        // macOS 가 있다(테스터 보고). 어느 쪽이 기본인지는 OS 판마다 다르고, 내 기기에서만
        // 꽉 차게 보이면 이 차이를 영영 못 본다.
        .frame(maxWidth: .infinity)
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
        case .dex:        DexView(wallet: wallet, index: Self.index)
        }
    }
}
