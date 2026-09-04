import SwiftUI

/// 한 장을 얻은 순간. **가림막을 직접 밀어서 연다.**
///
/// 예전에는 0.65초 기다리면 카드가 저절로 튀어나왔다. 기다리는 동안 할 것이 없고, 뽑았다는
/// 감각도 카드가 튀어나오는 순간에 몰려 있었다. 실물 오리파는 봉투에서 카드를 천천히 빼내며
/// 조금씩 확인하는 재미가 있고, 그 속도를 뽑는 사람이 정한다.
///
/// 그래서 팩 개봉과 같은 장치(`RevealPeek`)를 쓴다 — 가림막이 손을 따라 밀리고 그만큼
/// 카드가 드러난다. 끝까지 밀면 열리고, 덜 밀면 도로 덮인다. 누르면 한 번에 열린다.
///
/// **오리파와 도감이 함께 쓴다.** 도감의 확정 카드도 「무엇이 나왔는지」를 보여 줘야 하고,
/// 두 곳에 같은 연출을 따로 두면 한쪽만 고쳐진다.
@MainActor
struct PulledCardView: View {
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
