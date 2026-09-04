import SwiftUI

/// 오리파 화면 갈래. 순서가 규칙이다 — **상세가 뽑기 결과보다 앞이다.**
///
/// 뽑기 결과를 지우고 상세로 넘어가면 상세를 닫을 때 박스 화면으로 튕긴다(실제 결함이었다).
/// 뽑은 카드를 그대로 들고 상세를 위에 겹치면 닫는 순간 방금 뽑은 화면이 그대로 나온다.
enum OripaScreen: Equatable {
    case detail(String)
    case draw
    /// 봉투를 고르는 창. **공지 보드에서 「뽑으러 가기」를 눌러 들어온다.**
    case picking
    case board

    static func resolve(focused: String?, hasDraw: Bool,
                        picking: Bool = false) -> OripaScreen {
        if let focused { return .detail(focused) }
        if hasDraw { return .draw }
        // 뽑기 창이 보드보다 앞이다 — 한 장 뽑고 확인을 누르면 봉투 격자로 돌아와야 한다.
        // 보드로 튕기면 연달아 뽑을 때마다 두 번씩 더 눌러야 한다.
        return picking ? .picking : .board
    }
}

/// 오리파 — 상위 등급만 담은 40봉투 박스에서 **봉투를 골라** 한 장씩 뽑는다.
///
/// 박스 안 카드를 전부 보여 준다. 실물 오리파의 고질적인 문제가 "무엇이 들었는지 검증할 수
/// 없다" 는 것이고, 그걸 그대로 옮기면 재미가 아니라 불신이 된다. 남은 것이 눈에 보여야
/// "아직 UR 이 남았다" 가 뽑는 이유가 된다.
///
/// **공지와 뽑기를 나눈다.** 들어오면 먼저 이 박스에 무엇이 들었는지 값순으로 늘어놓는다 —
/// 살지 말지는 그것을 보고 정한다. 「뽑으러 가기」를 누르면 봉투 격자로 들어가고, 거기서
/// 봉투를 골라 연다.
///
/// 봉투 격자를 보드에 바로 두면 안 된다. 덮인 봉투 40개는 아무 정보가 아니라서, 무엇이 걸려
/// 있는지 모르는 채로 값을 내라는 화면이 된다. 못 보는 봉투는 고를 수 없으므로 뽑기 창의
/// 격자에는 스크롤을 두지 않는다.
@MainActor
struct OripaView: View {
    let wallet: WalletStore
    let index: CardIndex

    /// 크게 보고 있는 카드. 방금 뽑은 것일 수도, 내용물에서 눌러 본 것일 수도 있다.
    @State private var focused: String?
    /// 방금 뽑은 카드. 연출이 끝날 때까지 이 화면이 덮는다.
    @State private var drawn: PulledCard?
    /// 박스를 다 비웠는가. 새 박스가 들어왔다는 안내를 한 번 띄운다.
    @State private var refilled = false
    /// 교체를 누른 직후. 확인을 인라인으로 받는다(`.alert` 금지 — 팝오버가 닫히면 고아 시트가 남는다).
    @State private var confirmingReplace = false
    /// 봉투를 고르는 창에 들어와 있는가.
    @State private var picking = false
    /// 고른 봉투 번호. **이것이 곧 확인 단계다** — 봉투를 누르고 뽑기를 누르는 두 동작이라
    /// 잘못 눌러서 값이 나가지 않는다. 예전의 별도 확인 줄을 대신한다.
    @State private var picked: Int?
    /// 방금 뽑은 카드의 가림막이 이미 걷혔는가. 상세를 보고 돌아왔을 때 연출을 다시 돌리지
    /// 않기 위한 것이다 — 화면이 새로 만들어지므로 뷰 안의 상태만으로는 알 수 없다.
    @State private var revealed = false

    private var box: OripaBox { wallet.oripaBox(index: index) }

    var body: some View {
        switch OripaScreen.resolve(focused: focused, hasDraw: drawn != nil,
                                   picking: picking) {
        case .detail(let cardID):
            if let entry = index.card(cardID) {
                CardSpotlightView(wallet: wallet, cardID: entry.id,
                                  name: entry.displayName(wallet.language),
                                  tier: entry.tier, setID: entry.setID,
                                  setName: index.set(entry.setID)?.name ?? entry.setID,
                                  rarity: entry.rarity,
                                  ownedCount: wallet.cardCount(entry.id)) {
                    self.focused = nil
                }
            }
        case .draw:
            if let drawn {
                PulledCardView(wallet: wallet, card: drawn, startOpened: revealed,
                              onReveal: { revealed = true; wallet.markAllRevealed() },
                              onDetail: { focused = drawn.id },
                              onDone: { self.drawn = nil },
                              name: index.card(drawn.id)?.displayName(wallet.language) ?? drawn.id)
            }
        case .picking:
            OripaPickingScreen(wallet: wallet, index: index, box: box, picked: $picked,
                               onBack: { picking = false; picked = nil },
                               onPull: pull)
        case .board:
            // 뽑기 화면을 벗어나면 감춰 둔 값을 되돌린다. 남겨 두면 가진 것보다 적게 보인다.
            board.onAppear { wallet.markAllRevealed() }
        }
    }

    private var board: some View {
        let l = wallet.l
        let current = box
        return VStack(spacing: 6) {
            header(l, current)
            ScrollView { contents(l, current) }
            enterBar(l, current)
        }
    }

    /// 박스 번호·남은 수·남은 등급을 한 덩어리로 묶는다. **이 줄이 공지의 요약이다** —
    /// 아래 카드 격자를 훑기 전에 「아직 UR 이 남았나」에 먼저 답한다.
    private func header(_ l: L, _ box: OripaBox) -> some View {
        let counts = Oripa.remainingByTier(box, index: index)
        let owned = box.slots.filter { wallet.cardCount($0) > 0 }.count
        return VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text(l.oripaBoxNumber(box.serial))
                    .font(Typography.bodySemibold).monospacedDigit()
                Text(l.oripaRemaining(box.remaining, OripaConfig.slotsPerBox))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.secondary).monospacedDigit()
                Spacer(minLength: 0)
                replaceControl(l)
            }
            WrapLayout(spacing: 8, lineSpacing: 3) {
                ForEach(counts, id: \.tier) { entry in
                    HStack(spacing: 2) {
                        Text(l.tierBadge(entry.tier))
                            .font(.system(size: 14, weight: .heavy))
                            .foregroundStyle(tierColor(entry.tier))
                        Text("\(entry.count)")
                            .font(.system(size: 14, weight: .semibold)).monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                    .fixedSize()
                }
            }
            // 할 말이 있을 때만 한 줄 붙인다. 늘 자리를 잡아 두면 빈 줄이 남는다.
            if refilled || owned > 0 {
                Text(refilled ? l.oripaRefilled : l.oripaOwnedCount(owned))
                    .font(Typography.label)
                    .foregroundStyle(refilled ? AnyShapeStyle(Color.accentColor)
                                              : AnyShapeStyle(.tertiary))
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 8).padding(.vertical, 5)
        .background(Color.secondary.opacity(0.07), in: RoundedRectangle(cornerRadius: 6))
    }

    /// 마음에 안 드는 박스를 버린다. 값은 안 받지만 되돌릴 수 없어 확인을 한 번 받는다.
    @ViewBuilder
    private func replaceControl(_ l: L) -> some View {
        if confirmingReplace {
            HStack(spacing: 6) {
                Text(l.oripaReplaceConfirm)
                    .font(.system(size: 14)).foregroundStyle(.secondary)
                    .lineLimit(1).fixedSize()
                Button(l.oripaReplace) {
                    wallet.replaceOripaBox(index: index)
                    confirmingReplace = false
                    // 새 박스에서는 같은 번호가 다른 카드다. 고른 것을 들고 넘어가면 안 된다.
                    picked = nil
                    refilled = false
                }
                .buttonStyle(.borderedProminent).font(Typography.button)
                Button(l.cancel) { confirmingReplace = false }
                    .buttonStyle(.borderless).font(Typography.button)
            }
        } else {
            Button { confirmingReplace = true; picked = nil } label: {
                Label(l.oripaReplace, systemImage: "arrow.triangle.2.circlepath")
                    .font(.system(size: 14))
            }
            .buttonStyle(.borderless)
            .help(l.oripaReplaceHelp)
        }
    }

    /// **박스에 든 카드 전부.** 값이 비싼 것부터 늘어놓고, 뽑아 나간 것은 자리를 지킨 채
    /// 표시만 바꾼다.
    ///
    /// 남은 것만 보여 주면 안 된다. 1등이 빠진 박스와 아직 있는 박스가 **둘 다 "위에 뭔가
    /// 있는" 격자**로 보여서, 무엇이 빠졌는지 알 수가 없다. 자리를 지키면 나갔다는 것이
    /// 그 자리에서 읽힌다.
    ///
    /// 등급 순으로 세우면 순서가 시장과 어긋난다 — 같은 등급 안에서도 값이 수십 배 갈리고,
    /// 박스를 살지 말지는 결국 위쪽에 무엇이 남았는지로 정해진다. 컬렉션·도감과 같은 기준이다.
    ///
    /// 40장이 5열이면 여덟 줄이라 세로로 넘긴다. 훑어보는 자리는 넘겨도 되고, 한 화면에
    /// 들어가야 하는 것은 **고르는 자리**(봉투 격자)다.
    private func contents(_ l: L, _ box: OripaBox) -> some View {
        let ordered = Oripa.sortedByValue(box.cards, index: index)
        let columns = CardGrid.oripa.items
        return LazyVGrid(columns: columns, spacing: CardGrid.oripa.spacing) {
            ForEach(ordered, id: \.self) { id in
                // **안 연 봉투의 번호는 손에 넣지 않는다.** 이 한 곳에서만 물어보므로
                // 여기 없는 번호는 화면 어디에도 새지 않는다.
                let envelope = Oripa.revealedEnvelope(of: id, in: box)
                let drawn = envelope != nil
                // 뽑은 카드는 이제 가진 카드이기도 하다. 두 표시가 겹치면 무엇을 뜻하는지
                // 알 수 없으므로 「뽑음」이 이긴다.
                let owned = !drawn && wallet.cardCount(id) > 0
                Button { focused = id } label: {
                    VStack(spacing: 1) {
                        CardImageView(cardID: id, width: CardGrid.oripa.width)
                            .grayscale(drawn ? 1 : 0)
                            .opacity(drawn ? 0.3 : owned ? 0.45 : 1)
                            .overlay {
                                // 흑백에 옅게만 두면 「미보유」로 읽힌다(컬렉션이 그렇게
                                // 그린다). 나갔다는 것은 글자로 적어야 헷갈리지 않는다.
                                if drawn {
                                    Text(l.oripaDrawnMark)
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(.secondary)
                                        .padding(.horizontal, 5).padding(.vertical, 1)
                                        .background(.regularMaterial, in: Capsule())
                                }
                            }
                            .overlay(alignment: .topTrailing) {
                                if owned {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 14))
                                        .foregroundStyle(.green)
                                        .padding(2)
                                }
                            }
                        if let entry = index.card(id) {
                            Text(l.tierBadge(entry.tier))
                                .font(.system(size: 13, weight: .heavy))
                                .foregroundStyle(tierColor(entry.tier))
                                .opacity(drawn ? 0.35 : owned ? 0.5 : 1)
                        }
                    }
                }
                .buttonStyle(.plain)
                // 이미 연 봉투만 번호를 적는다 — 대응이 미리 굳어 있었다는 흔적이다.
                // 안 연 것에 적으면 목록에서 1등을 찾아 그 번호를 누르면 끝이다.
                .help(envelope.map { l.oripaCardInEnvelope($0 + 1, name(id)) } ?? name(id))
            }
        }
        .padding(.horizontal, 1)
    }

    private func name(_ cardID: String) -> String {
        index.card(cardID)?.displayName(wallet.language) ?? cardID
    }

    /// 공지 보드의 아래 줄. 값을 적고 뽑기 창으로 들여보낸다.
    ///
    /// **여기서 바로 뽑지 않는다.** 무엇이 걸려 있는지 본 다음 봉투를 고르는 것이 순서이고,
    /// 값이 나가는 버튼과 값을 확정하는 버튼이 같은 자리에 있으면 한 번 눌러서 돈이 나간다.
    private func enterBar(_ l: L, _ box: OripaBox) -> some View {
        let price = wallet.oripaPrice()
        let affordable = wallet.availableTokens >= price && !box.isEmpty
        return VStack(spacing: 4) {
            HStack(spacing: 6) {
                Spacer()
                Text(MarketEconomy.money(tokens: price, language: wallet.language))
                    .font(Typography.amount).monospacedDigit()
                    .foregroundStyle(affordable ? .primary : .secondary)
                    .lineLimit(1).minimumScaleFactor(0.75)
            }
            Button(l.oripaGoPull) { picking = true; picked = nil; confirmingReplace = false }
                .buttonStyle(.borderedProminent)
                .font(Typography.button)
                .disabled(!affordable)
        }
        .padding(.bottom, 4)
    }

    private func pull() {
        guard let envelope = picked else { return }
        confirmingReplace = false
        guard let result = wallet.pullOripa(index: index, envelope: envelope) else { return }
        picked = nil
        refilled = wallet.oripaBox(index: index).remaining == OripaConfig.slotsPerBox
        focused = nil
        revealed = false
        drawn = result.card
    }
}

/// 봉투를 고르는 창. 공지 보드에서 「뽑으러 가기」로 들어온다.
///
/// 보드와 따로 두는 이유는 두 가지다. 덮인 봉투 40개는 아무 정보가 아니라서 보드에 그것만
/// 두면 무엇이 걸렸는지 모르는 채 값을 내라는 화면이 되고, 값이 나가는 버튼이 보드에 있으면
/// 한 번 눌러서 돈이 나간다. 여기서는 봉투를 고르는 것이 그 확인 단계다.
///
/// 등급 요약은 두지 않는다 — 무엇이 남았는지는 보드에서 보고 왔고, 그 줄이 박스마다 한두 줄씩
/// 늘었다 줄어들면 **스크롤이 없는** 봉투 격자가 눌릴 여지가 생긴다.
@MainActor
struct OripaPickingScreen: View {
    let wallet: WalletStore
    let index: CardIndex
    let box: OripaBox
    @Binding var picked: Int?
    let onBack: () -> Void
    let onPull: () -> Void

    var body: some View {
        let l = wallet.l
        return VStack(spacing: 6) {
            HStack(spacing: 6) {
                BackButton(action: onBack)
                Text(l.oripaBoxNumber(box.serial))
                    .font(Typography.bodySemibold).monospacedDigit()
                Spacer(minLength: 0)
                Text(l.oripaRemaining(box.remaining, OripaConfig.slotsPerBox))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.secondary).monospacedDigit()
            }
            // 격자를 남는 세로의 가운데에 둔다. 아래로만 밀면 빈자리가 뽑기 줄 위에 모여
            // 화면이 위로 쏠린 것처럼 보인다.
            Spacer(minLength: 0)
            envelopes
            Spacer(minLength: 0)
            pullBar(l)
        }
    }

    /// 봉투 격자. **스크롤이 없다** — 못 보는 봉투는 고를 수 없다.
    ///
    /// 첨자가 곧 봉투 번호라 자리가 고정이다. 연 봉투를 목록에서 빼면 뒤 번호가 밀려서
    /// 「17번을 열었다」가 다음 순간 다른 봉투를 가리키게 된다.
    private var envelopes: some View {
        let grid = CardGrid.oripaEnvelope
        return LazyVGrid(columns: grid.items, spacing: grid.spacing) {
            ForEach(box.cards.indices, id: \.self) { number in
                EnvelopeCell(number: number + 1,
                             width: grid.width,
                             // 연 봉투는 무엇이 들었는지 이미 아는 자리다. 등급을 남겨
                             // 두면 박스의 모양이 뽑을수록 드러난다.
                             openedTier: box.card(at: number).flatMap { index.card($0)?.tier },
                             picked: picked == number,
                             label: wallet.l.oripaPicked(number + 1)) {
                    picked = picked == number ? nil : number
                }
            }
        }
        .padding(.horizontal, 1)
    }

    /// 뽑기 창의 아래 줄 — 고른 봉투와 값, 확정 버튼.
    ///
    /// **값은 남은 봉투에 따라 바뀐다.** 1등이 빠지면 내려가고, 싼 것만 빠지면 올라간다.
    /// 올라갈 때는 박스를 버리면 되므로 실제로는 새 박스 값을 넘지 않는다.
    private func pullBar(_ l: L) -> some View {
        let price = wallet.oripaPrice()
        let canPull = picked != nil && wallet.availableTokens >= price && !box.isEmpty
        return VStack(spacing: 4) {
            HStack(spacing: 6) {
                Text(picked.map { l.oripaPicked($0 + 1) } ?? l.oripaPickHint)
                    .font(Typography.label)
                    .foregroundStyle(picked == nil ? AnyShapeStyle(.secondary)
                                                   : AnyShapeStyle(.primary))
                    .lineLimit(1)
                Spacer()
                Text(MarketEconomy.money(tokens: price, language: wallet.language))
                    .font(Typography.amount).monospacedDigit()
                    .foregroundStyle(canPull ? .primary : .secondary)
                    .lineLimit(1).minimumScaleFactor(0.75)
            }
            Button(l.oripaPull, action: onPull)
                .buttonStyle(.borderedProminent)
                .font(Typography.button)
                .disabled(!canPull)
        }
        .padding(.bottom, 4)
    }

}

/// 봉투 한 칸. **덮여 있는 봉투는 서로 완전히 같아야 한다.**
///
/// 번호 말고 아무것도 다르지 않다 — 크기도, 색도, 기울기도 같다. 조금이라도 다르면 그 차이가
/// 무슨 뜻인지 없는 규칙을 찾게 되고, 고르는 일이 추측 게임이 된다. 고르는 것은 감으로 하는
/// 일이고, 그 감이 진짜 결과를 정한다는 것이 이 화면의 전부다.
@MainActor
private struct EnvelopeCell: View {
    let number: Int
    let width: CGFloat
    /// 이미 연 봉투에 들어 있던 카드의 등급. 안 열었으면 nil 이다.
    let openedTier: CardTier?
    let picked: Bool
    let label: String
    let onTap: () -> Void

    private var height: CGFloat { (width / 0.717).rounded() }

    var body: some View {
        Button(action: onTap) {
            ZStack {
                if let openedTier {
                    // 연 자리는 빈 칸으로 남긴다. 몇 개를 열었는지가 격자로 읽힌다.
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(Color.secondary.opacity(0.25),
                                      style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                    Text(openedTier.rawValue)
                        .font(.system(size: 13, weight: .heavy))
                        .foregroundStyle(tierColor(openedTier).opacity(0.55))
                        .lineLimit(1).minimumScaleFactor(0.6)
                } else {
                    RoundedRectangle(cornerRadius: 6).fill(OripaCover.back)
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(OripaCover.rim, lineWidth: 1.5)
                    Text("\(number)")
                        .font(.system(size: 14, weight: .bold)).monospacedDigit()
                        .foregroundStyle(OripaCover.mark)
                }
            }
            .frame(width: width, height: height)
            // 고른 봉투만 테두리로 표시하고 자리는 그대로 둔다. 키우면 이웃을 밀어내
            // 격자가 통째로 흔들린다.
            .overlay {
                if picked {
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(Color.accentColor, lineWidth: 2.5)
                }
            }
            .shadow(color: .orange.opacity(picked ? 0.55 : 0), radius: picked ? 7 : 0)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(openedTier != nil)
        .help(label)
    }
}

/// 오리파 가림막의 색.
///
/// 뷰 밖에 둔 이유는 **불투명해야 한다**는 것이 눈으로만 확인되는 성질이기 때문이다.
/// 밑에 카드를 깔아 두고 반투명한 막을 덮으면 그대로 비쳐 보인다(실제로 그렇게 나갔다).
/// 여기 있으면 테스트가 알파값을 직접 확인할 수 있다.
enum OripaCover {
    /// 막의 바탕. 카드 뒷면 역할이라 빈틈이 없어야 한다.
    static let back = Color(red: 0.92, green: 0.45, blue: 0.09)
    /// 가장자리 테두리.
    static let rim = Color(red: 0.99, green: 0.76, blue: 0.42)
    /// 가운데 표식.
    static let mark = Color(red: 1.0, green: 0.93, blue: 0.82)

    /// 숨쉬는 애니메이션의 크기 범위. **작은 쪽이 1 아래로 내려가면 안 된다** —
    /// 줄어든 만큼 밑에 깔린 카드의 가장자리가 사방으로 드러난다.
    static let restScale = 1.0
    static let pulseScale = 1.04

    /// 완전히 불투명한가. 하나라도 아니면 카드가 비친다.
    static func isOpaque(_ color: Color) -> Bool {
        NSColor(color).usingColorSpace(.sRGB)?.alphaComponent == 1
    }
}
