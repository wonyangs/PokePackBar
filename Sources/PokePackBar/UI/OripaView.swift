import SwiftUI

/// 오리파 화면 갈래. 순서가 규칙이다 — **상세가 뽑기 결과보다 앞이다.**
///
/// 뽑기 결과를 지우고 상세로 넘어가면 상세를 닫을 때 박스 화면으로 튕긴다(실제 결함이었다).
/// 뽑은 카드를 그대로 들고 상세를 위에 겹치면 닫는 순간 방금 뽑은 화면이 그대로 나온다.
enum OripaScreen: Equatable {
    case detail(String)
    case draw
    case board

    static func resolve(focused: String?, hasDraw: Bool) -> OripaScreen {
        if let focused { return .detail(focused) }
        return hasDraw ? .draw : .board
    }
}

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
    /// 방금 뽑은 카드. 연출이 끝날 때까지 이 화면이 덮는다.
    @State private var drawn: PulledCard?
    /// 박스를 다 비웠는가. 새 박스가 들어왔다는 안내를 한 번 띄운다.
    @State private var refilled = false
    /// 교체를 누른 직후. 확인을 인라인으로 받는다(`.alert` 금지 — 팝오버가 닫히면 고아 시트가 남는다).
    @State private var confirmingReplace = false
    /// 뽑기를 누른 직후. 한 번에 3000만 토큰이 나가므로 확인을 받는다.
    @State private var confirmingPull = false
    /// 방금 뽑은 카드의 가림막이 이미 걷혔는가. 상세를 보고 돌아왔을 때 연출을 다시 돌리지
    /// 않기 위한 것이다 — 화면이 새로 만들어지므로 뷰 안의 상태만으로는 알 수 없다.
    @State private var revealed = false

    private var box: OripaBox { wallet.oripaBox(index: index) }

    var body: some View {
        switch OripaScreen.resolve(focused: focused, hasDraw: drawn != nil) {
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
                OripaDrawView(wallet: wallet, card: drawn, startOpened: revealed,
                              onReveal: { revealed = true; wallet.markAllRevealed() },
                              onDetail: { focused = drawn.id },
                              onDone: { self.drawn = nil },
                              name: index.card(drawn.id)?.displayName(wallet.language) ?? drawn.id)
            }
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
                    .font(Typography.bodySemibold).monospacedDigit()
                if owned > 0 {
                    Text(l.oripaOwnedCount(owned))
                        .font(.system(size: 14)).foregroundStyle(.tertiary).monospacedDigit()
                }
                Spacer(minLength: 0)
                replaceControl(l)
            }
            Text(refilled ? l.oripaRefilled : l.oripaHint)
                .font(Typography.label)
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
                    .font(.system(size: 14)).foregroundStyle(.secondary)
                    .lineLimit(1).fixedSize()
                Button(l.oripaReplace) {
                    wallet.replaceOripaBox(index: index)
                    confirmingReplace = false
                    confirmingPull = false
                    refilled = false
                }
                .buttonStyle(.borderedProminent).font(Typography.button)
                Button(l.cancel) { confirmingReplace = false }
                    .buttonStyle(.borderless).font(Typography.button)
            }
        } else {
            Button { confirmingReplace = true; confirmingPull = false } label: {
                Label(l.oripaReplace, systemImage: "arrow.triangle.2.circlepath")
                    .font(.system(size: 14))
            }
            .buttonStyle(.borderless)
            .help(l.oripaReplaceHelp)
        }
    }

    /// 남은 등급별 개수. 이 줄이 오리파의 전부다 — 무엇이 얼마나 남았는지가 사는 이유다.
    ///
    /// **넘치면 줄을 바꾼다.** 등급이 열 칸이던 시절에는 한 줄에 다 들어갔는데, 등급을
    /// 나무위키 기준으로 가르면서 박스 하나에 열댓 종이 들어가게 됐다. `HStack` 은 폭이
    /// 모자라면 자식을 눌러 줄이므로 배지와 숫자가 붙어 뭉개졌다.
    private func remainingRow(_ box: OripaBox) -> some View {
        let counts = Oripa.remainingByTier(box, index: index)
        return VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text(wallet.l.oripaRemaining(box.remaining, OripaConfig.slotsPerBox))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.secondary).monospacedDigit()
                Spacer(minLength: 0)
            }
            WrapLayout(spacing: 8, lineSpacing: 3) {
                ForEach(counts, id: \.tier) { entry in
                    HStack(spacing: 2) {
                        Text(wallet.l.tierBadge(entry.tier))
                            .font(.system(size: 14, weight: .heavy))
                            .foregroundStyle(tierColor(entry.tier))
                        Text("\(entry.count)")
                            .font(.system(size: 14, weight: .semibold)).monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                    .fixedSize()
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 8).padding(.vertical, 5)
        .background(Color.secondary.opacity(0.07), in: RoundedRectangle(cornerRadius: 6))
    }

    /// 박스에 남은 카드 전부. **값이 비싼 것부터** 늘어놓는다.
    ///
    /// 등급 순으로 세우면 순서가 시장과 어긋난다 — 같은 등급 안에서도 값이 수십 배 갈리고,
    /// 박스를 살지 말지는 결국 위쪽에 무엇이 남았는지로 정해진다. 컬렉션·도감과 같은 기준이다.
    private func contents(_ l: L, _ box: OripaBox) -> some View {
        let ordered = Oripa.sortedByValue(box.slots, index: index)
        let columns = CardGrid.oripa.items
        return LazyVGrid(columns: columns, spacing: CardGrid.oripa.spacing) {
            ForEach(ordered, id: \.self) { id in
                let owned = wallet.cardCount(id) > 0
                Button { focused = id } label: {
                    VStack(spacing: 1) {
                        CardImageView(cardID: id, width: CardGrid.oripa.width)
                            .opacity(owned ? 0.45 : 1)
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
                                .opacity(owned ? 0.5 : 1)
                        }
                    }
                }
                .buttonStyle(.plain)
                .help(index.card(id)?.displayName(wallet.language) ?? id)
            }
        }
        .padding(.horizontal, 1)
    }

    private func pullBar(_ l: L, _ box: OripaBox) -> some View {
        let price = wallet.oripaPrice()
        let canPull = wallet.availableTokens >= price && !box.isEmpty
        return VStack(spacing: 4) {
            HStack(spacing: 6) {
                // 확인 중에는 여기서 묻는다. 값이 바로 옆에 있어야 무엇에 얼마를 쓰는지
                // 보면서 결정할 수 있고, 아래 버튼 줄은 버튼만 남아 폭에 여유가 생긴다.
                Text(confirmingPull ? l.oripaPullConfirm : l.oripaSubtitle)
                    .font(Typography.label)
                    .foregroundStyle(confirmingPull ? AnyShapeStyle(.primary)
                                                    : AnyShapeStyle(.secondary))
                    .lineLimit(1)
                Spacer()
                Text(MarketEconomy.money(tokens: price, language: wallet.language))
                    .font(Typography.amount).monospacedDigit()
                    .foregroundStyle(canPull ? .primary : .secondary)
                    .lineLimit(1).minimumScaleFactor(0.75)
            }
            // 두 상태 모두 기본 크기 버튼이라 높이가 같다 — 바꿔 끼워도 덜컹거리지 않는다.
            //
            // 겹쳐 두는 방식(ZStack)으로도 높이는 잡히지만 쓰지 않는다. 겹치면 좁은 쪽 폭이
            // 제안되어 확인 줄이 눌리고, 버튼 이름이 "..." 로 잘렸다.
            if confirmingPull {
                HStack(spacing: 8) {
                    Button(l.oripaPull) { pull() }
                        .buttonStyle(.borderedProminent)
                    Button(l.cancel) { confirmingPull = false }
                        .buttonStyle(.bordered)
                }
                .font(Typography.button)
            } else {
                Button(l.oripaPull) { confirmingPull = true }
                    .buttonStyle(.borderedProminent)
                    .font(Typography.button)
                    .disabled(!canPull)
            }
        }
        .padding(.bottom, 4)
    }

    private func pull() {
        confirmingReplace = false
        confirmingPull = false
        guard let result = wallet.pullOripa(index: index) else { return }
        refilled = wallet.oripaBox(index: index).remaining == OripaConfig.slotsPerBox
        focused = nil
        revealed = false
        drawn = result.card
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

/// 뽑는 순간. **가림막을 직접 밀어서 연다.**
///
/// 예전에는 0.65초 기다리면 카드가 저절로 튀어나왔다. 기다리는 동안 할 것이 없고, 뽑았다는
/// 감각도 카드가 튀어나오는 순간에 몰려 있었다. 실물 오리파는 봉투에서 카드를 천천히 빼내며
/// 조금씩 확인하는 재미가 있고, 그 속도를 뽑는 사람이 정한다.
///
/// 그래서 팩 개봉과 같은 장치(`RevealPeek`)를 쓴다 — 가림막이 손을 따라 밀리고 그만큼
/// 카드가 드러난다. 끝까지 밀면 열리고, 덜 밀면 도로 덮인다. 누르면 한 번에 열린다.
@MainActor
private struct OripaDrawView: View {
    let wallet: WalletStore
    let card: PulledCard
    /// 이미 걷힌 상태로 시작한다. 상세를 보고 돌아온 경우다.
    let startOpened: Bool
    let onReveal: () -> Void
    let onDetail: () -> Void
    let onDone: () -> Void
    /// 화면에 쓸 카드 이름. 뽑기 화면은 인덱스를 들고 있지 않아 밖에서 받는다.
    let name: String

    /// 가림막이 걷혔는가. 걷히기 전까지는 카드가 보이지 않는다.
    @State private var opened = false
    @State private var pulse = false
    /// 가림막을 민 거리.
    @State private var drag: CGSize = .zero
    /// 지금 잡고 있는가. 잡고 있는 동안에는 숨쉬는 움직임을 멈춘다 —
    /// 손으로 미는 것과 저 혼자 움직이는 것이 겹치면 어디까지 밀었는지 가늠이 안 된다.
    @State private var holding = false

    /// 팝오버가 보이는가. 닫혀도 화면 트리가 남으므로 이 값을 봐야 한다 —
    /// 끝없이 도는 숨쉬기가 닫힌 채로도 계속 다시 그리면 그만큼 그냥 태우는 것이다.
    @Environment(PopoverNavigation.self) private var nav

    /// 뽑기 화면에서 카드를 그리는 폭(pt).
    ///
    /// 개봉 화면(`RevealPeek.cardWidth`)보다 조금 작다. 상점 탭에는 「일반 팩 / 오리파」
    /// 갈래 선택이 한 줄 더 있어 세로가 그만큼 좁고, 새 카드일 때 NEW 배지가 한 줄 더 붙는다.
    private static let cardWidth: CGFloat = 240

    /// 이 거리 안에서 끝나면 민 것이 아니라 누른 것으로 본다(pt).
    /// 손을 떼는 순간 몇 px 흔들리는 것까지 밀기로 치면 눌러도 안 열린다.
    private static let tapSlop: CGFloat = 4

    /// 얼마나 밀었는가(0~1). 아래 카드의 후광 세기에 쓴다.
    private var peek: Double { RevealPeek.amount(drag) }

    /// 등급을 알 수 없게 덮어 두는 가림막. 밀면 손을 따라가고, 놓으면 밀린 만큼에 따라
    /// 열리거나 도로 덮인다.
    ///
    /// **밑에 카드가 이미 그려져 있으므로 이 막은 빈틈이 없어야 한다.** 두 가지로 새기 쉽다.
    /// 색이 반투명하면 그대로 비치고, 숨쉬는 애니메이션이 1 보다 작게 줄어들면 카드 가장자리가
    /// 사방으로 삐져나온다. 둘 다 실제로 스포일러가 됐다. 그래서 색은 불투명한 것만 쓰고,
    /// 크기는 1 아래로 내려가지 않는다.
    private var cover: some View {
        RoundedRectangle(cornerRadius: 10)
            .fill(OripaCover.back)
            .overlay {
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(OripaCover.rim, lineWidth: 3)
            }
            .overlay {
                Image(systemName: "sparkles")
                    .font(.system(size: 40, weight: .medium))
                    .foregroundStyle(OripaCover.mark)
            }
            .frame(width: Self.cardWidth, height: (Self.cardWidth / 0.717).rounded())
            .scaleEffect(pulse ? OripaCover.pulseScale : OripaCover.restScale)
            .shadow(color: .orange.opacity(0.5), radius: pulse ? 22 : 8)
            .offset(drag)
            .rotationEffect(.degrees(RevealPeek.tilt(drag)), anchor: .bottom)
            // 걷힐 때는 스르르 사라진다. 카드는 이미 밑에 그려져 있어 갈아 끼울 것이 없다.
            .transition(.opacity)
            .contentShape(Rectangle())
            // 누르기와 밀기를 한 제스처로 받는다. 따로 두면 최소 이동 거리를 넘기 전까지는
            // 잡은 줄을 몰라서, 잡고 가만히 있는 동안에도 가림막이 계속 숨을 쉰다.
            // 움직임이 거의 없이 끝나면 누른 것으로 보고 한 번에 연다.
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged {
                        drag = $0.translation
                        holding = true
                    }
                    .onEnded { value in
                        holding = false
                        let moved = RevealPeek.distance(value.translation)
                        if moved < Self.tapSlop || RevealPeek.advances(value.translation) {
                            reveal()
                        } else {
                            withAnimation(.spring(response: 0.32, dampingFraction: 0.7)) {
                                drag = .zero
                            }
                        }
                    }
            )
    }

    /// 숨쉬기를 건다. **팝오버가 보일 때만** 건다.
    private func startBreathing() {
        guard nav.isShown, !opened, !holding else { return }
        withAnimation(.easeInOut(duration: 0.32).repeatForever(autoreverses: true)) {
            pulse = true
        }
    }

    /// 숨쉬기를 멈춘다.
    ///
    /// `repeatForever` 는 값이 그대로면 계속 돈다. 표시만 가리면 반복이 남으므로 짧은
    /// 애니메이션으로 값을 되돌려 그 반복을 갈아 치운다.
    private func stopBreathing() {
        withAnimation(.easeOut(duration: 0.12)) { pulse = false }
    }

    private func reveal() {
        guard !opened else { return }
        withAnimation(.spring(response: 0.42, dampingFraction: 0.62)) {
            drag = .zero
            opened = true
        }
        onReveal()
    }

    var body: some View {
        let l = wallet.l
        VStack(spacing: 10) {
            Spacer(minLength: 0)

            ZStack {
                // 카드는 처음부터 여기 있다. 가림막이 밀린 만큼 그대로 드러난다 —
                // 나중에 그리면 밀어도 아무것도 없는 자리가 보인다.
                TierGlow(tier: card.tier, width: Self.cardWidth)
                    .opacity(opened ? 1 : peek)
                CardImageView(cardID: card.id, hires: true, width: Self.cardWidth)
                    .shadow(radius: opened ? 10 : 0, y: opened ? 4 : 0)

                if !opened { cover }
            }
            // 열린 뒤에는 카드를 눌러 상세로 간다. 덮여 있는 동안은 가림막이 먼저 받는다.
            .contentShape(Rectangle())
            .onTapGesture { if opened { onDetail() } }
            .help(opened ? l.oripaSeeDetail : l.oripaDrawHint)

            if opened {
                VStack(spacing: 3) {
                    Text(name).font(Typography.title)
                        .lineLimit(1).minimumScaleFactor(0.7)
                    HStack(spacing: 5) {
                        Text(l.tierBadge(card.tier))
                            .font(Typography.badge)
                            .foregroundStyle(tierColor(card.tier))
                        Text(l.tierName(card.tier)).font(Typography.label).foregroundStyle(.secondary)
                        if let prices = CardPrices.shared, let usd = prices.price(card.id) {
                            Text("·").font(Typography.label).foregroundStyle(.tertiary)
                            Text(prices.formattedWithKRW(usd, language: wallet.language))
                                .font(Typography.labelSemibold).monospacedDigit()
                                .foregroundStyle(Color.accentColor)
                        }
                    }
                    .lineLimit(1).minimumScaleFactor(0.8)
                    if card.isNew { NewBadge(text: l.newCardBadge).padding(.top, 1) }
                }
                .transition(.opacity)
            } else {
                Text(l.oripaDrawHint).font(Typography.body).foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)

            if opened {
                Button(l.done, action: onDone)
                    .buttonStyle(.borderedProminent).font(Typography.button)
                    .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // 잡으면 숨을 멈추고, 놓으면 다시 쉰다.
        //
        // `repeatForever` 는 값이 그대로면 계속 돈다. 그래서 멈출 때는 짧은 애니메이션으로
        // 값을 되돌려 그 반복을 갈아 치운다 — 표시만 가리면 반복이 남아 언제 다시 튀어나올지
        // 알 수 없다.
        .onChange(of: holding) {
            holding ? stopBreathing() : startBreathing()
        }
        // 팝오버를 닫으면 숨쉬기를 멈추고, 다시 열면 이어서 쉰다.
        .onChange(of: nav.isShown) {
            nav.isShown ? startBreathing() : stopBreathing()
        }
        .task(id: card.id) {
            drag = .zero
            holding = false
            if startOpened { opened = true; return }
            opened = false
            startBreathing()
        }
    }
}
