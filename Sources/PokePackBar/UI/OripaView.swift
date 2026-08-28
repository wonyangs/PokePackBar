import SwiftUI

/// 오리파 — 상위 등급만 담은 100슬롯 박스에서 한 장씩 뽑는다.
///
/// 박스 안 카드를 전부 보여 준다. 실물 오리파의 고질적인 문제가 "무엇이 들었는지 검증할 수
/// 없다" 는 것이고, 그걸 그대로 옮기면 재미가 아니라 불신이 된다. 남은 것이 눈에 보여야
/// "아직 UR 이 남았다" 가 뽑는 이유가 된다.
@MainActor
struct OripaView: View {
    let wallet: WalletStore
    let index: CardIndex

    /// 크게 보고 있는 카드. 방금 뽑은 것일 수도, 박스에서 눌러 본 것일 수도 있다.
    @State private var focused: String?
    /// 박스를 다 비웠는가. 새 박스가 들어왔다는 안내를 한 번 띄운다.
    @State private var refilled = false
    /// 교체를 누른 직후. 확인을 인라인으로 받는다(`.alert` 금지 — 팝오버가 닫히면 고아 시트가 남는다).
    @State private var confirmingReplace = false

    private var box: OripaBox { wallet.oripaBox(index: index) }

    var body: some View {
        if let focused, let entry = index.card(focused) {
            CardSpotlightView(wallet: wallet, cardID: entry.id, name: entry.name,
                              tier: entry.tier, setID: entry.setID,
                              setName: index.set(entry.setID)?.name ?? entry.setID,
                              ownedCount: wallet.cardCount(entry.id)) {
                self.focused = nil
            }
        } else {
            board
        }
    }

    private var board: some View {
        let l = wallet.l
        let current = box
        return VStack(spacing: 6) {
            header(l, current)
            remainingRow(current)
            ScrollView {
                contents(l, current)
            }
            Spacer(minLength: 0)
            pullBar(l, current)
        }
    }

    private func header(_ l: L, _ box: OripaBox) -> some View {
        let owned = box.slots.filter { wallet.cardCount($0) > 0 }.count
        return VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                Text(l.oripaBoxNumber(box.serial))
                    .font(.caption.weight(.semibold)).monospacedDigit()
                if owned > 0 {
                    Text(l.oripaOwnedCount(owned))
                        .font(.system(size: 9)).foregroundStyle(.tertiary).monospacedDigit()
                }
                Spacer(minLength: 0)
                replaceControl(l)
            }
            Text(refilled ? l.oripaRefilled : l.oripaHint)
                .font(.caption2)
                .foregroundStyle(refilled ? Color.accentColor : .secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// 마음에 안 드는 박스를 버린다. 값은 안 받지만 되돌릴 수 없어 확인을 한 번 받는다.
    @ViewBuilder
    private func replaceControl(_ l: L) -> some View {
        if confirmingReplace {
            HStack(spacing: 6) {
                Text(l.oripaReplaceConfirm)
                    .font(.system(size: 10)).foregroundStyle(.secondary)
                    .lineLimit(1).fixedSize()
                Button(l.oripaReplace) {
                    wallet.replaceOripaBox(index: index)
                    confirmingReplace = false
                    refilled = false
                }
                .buttonStyle(.borderedProminent).controlSize(.mini)
                Button(l.cancel) { confirmingReplace = false }
                    .buttonStyle(.borderless).controlSize(.mini)
            }
        } else {
            Button { confirmingReplace = true } label: {
                Label(l.oripaReplace, systemImage: "arrow.triangle.2.circlepath")
                    .font(.system(size: 10))
            }
            .buttonStyle(.borderless)
            .help(l.oripaReplaceHelp)
        }
    }

    /// 남은 등급별 개수. 이 줄이 오리파의 전부다 — 무엇이 얼마나 남았는지가 사는 이유다.
    private func remainingRow(_ box: OripaBox) -> some View {
        let counts = Oripa.remainingByTier(box, index: index)
        return HStack(spacing: 6) {
            ForEach(counts, id: \.tier) { entry in
                HStack(spacing: 2) {
                    Text(wallet.l.tierBadge(entry.tier))
                        .font(.system(size: 9, weight: .heavy))
                        .foregroundStyle(tierColor(entry.tier))
                    Text("\(entry.count)")
                        .font(.system(size: 9, weight: .semibold)).monospacedDigit()
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
            Text(wallet.l.oripaRemaining(box.remaining, OripaConfig.slotsPerBox))
                .font(.system(size: 9)).foregroundStyle(.tertiary).monospacedDigit()
        }
        .padding(.horizontal, 8).padding(.vertical, 5)
        .background(Color.secondary.opacity(0.07), in: RoundedRectangle(cornerRadius: 6))
    }

    /// 박스에 남은 카드 전부. 등급이 높은 것부터 늘어놓는다.
    private func contents(_ l: L, _ box: OripaBox) -> some View {
        let ordered = box.slots.sorted { a, b in
            let ra = index.card(a)?.tier.rank ?? 0, rb = index.card(b)?.tier.rank ?? 0
            return ra != rb ? ra > rb : a < b
        }
        // 5칸 × 56 + 여백이 팝오버 폭(332) 안에 들어와야 한다.
        // 넘치면 팝오버 전체가 옆으로 밀려 상단 탭까지 흔들린다.
        let columns = Array(repeating: GridItem(.fixed(56), spacing: 5), count: 5)
        return LazyVGrid(columns: columns, spacing: 6) {
            ForEach(ordered, id: \.self) { id in
                let owned = wallet.cardCount(id) > 0
                Button { focused = id } label: {
                    VStack(spacing: 1) {
                        CardImageView(cardID: id, width: 56)
                            .opacity(owned ? 0.45 : 1)
                            .overlay(alignment: .topTrailing) {
                                if owned {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 10))
                                        .foregroundStyle(.green)
                                        .padding(2)
                                }
                            }
                        if let entry = index.card(id) {
                            Text(l.tierBadge(entry.tier))
                                .font(.system(size: 8, weight: .heavy))
                                .foregroundStyle(tierColor(entry.tier))
                                .opacity(owned ? 0.5 : 1)
                        }
                    }
                }
                .buttonStyle(.plain)
                .help(index.card(id)?.name ?? id)
            }
        }
        .padding(.horizontal, 1)
    }

    private func pullBar(_ l: L, _ box: OripaBox) -> some View {
        let price = wallet.oripaPrice()
        let canPull = wallet.availableTokens >= price && !box.isEmpty
        return VStack(spacing: 4) {
            HStack(spacing: 6) {
                Text(l.oripaSubtitle).font(.caption2).foregroundStyle(.secondary)
                Spacer()
                Text(TokenFormatter.readable(price, language: wallet.language))
                    .font(.caption.weight(.semibold)).monospacedDigit()
                    .foregroundStyle(canPull ? .primary : .secondary)
                    .lineLimit(1).minimumScaleFactor(0.75)
            }
            Button(l.oripaPull) { pull() }
                .buttonStyle(.borderedProminent)
                .disabled(!canPull)
        }
        .padding(.bottom, 4)
    }

    private func pull() {
        confirmingReplace = false
        guard let result = wallet.pullOripa(index: index) else { return }
        refilled = wallet.oripaBox(index: index).remaining == OripaConfig.slotsPerBox
        focused = result.card.id
    }
}
