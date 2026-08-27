import AppKit
import SwiftUI

/// 카드 한 장을 크게 보는 화면.
///
/// 카드 뒤에 등급 후광을 깔고 정보는 아래에 붙인다. 컬렉션과 개봉 결과가 같이 쓴다 —
/// 두 곳에서 따로 만들면 한쪽만 손보게 되고 같은 카드가 화면마다 달라 보인다.
///
/// 팝오버라 모달을 쓸 수 없어 탭 안에서 화면만 바꾼다. 닫기는 X 버튼이 맡는다.
@MainActor
struct CardSpotlightView: View {
    let wallet: WalletStore
    let cardID: String
    let name: String
    let tier: CardTier
    /// 이 카드가 나오는 세트. 카드 번호보다 이게 필요하다 —
    /// 갖고 싶은 카드를 보고 어느 팩을 사야 하는지 알 수 있어야 한다.
    let setID: String
    let setName: String
    /// 보유 장수. 0 이면 아직 얻지 못한 카드로 표시한다.
    let ownedCount: Int
    /// 미리 받아 둔 큰 그림이 있으면 기다리지 않는다.
    var preloaded: NSImage?
    let onClose: () -> Void

    @State private var landed = false
    @State private var confirmingDisenchant = false
    /// 방금 돌려받은 액수. 잠깐 보여주고 지운다.
    @State private var lastRefund: Int?

    var body: some View {
        let l = wallet.l
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 17))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help(l.close)
            }

            Spacer(minLength: 0)

            ZStack {
                TierGlow(tier: tier, width: 200)
                CardImageView(cardID: cardID, hires: true, width: 200,
                              dimmed: ownedCount == 0, preloaded: preloaded)
            }
            .scaleEffect(landed ? 1 : 0.9)
            .opacity(landed ? 1 : 0)

            Spacer(minLength: 0)

            VStack(spacing: 5) {
                Text(name)
                    .font(.title3.weight(.semibold))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 6) {
                    Text(l.tierBadge(tier))
                        .font(.system(size: 13, weight: .heavy))
                        .foregroundStyle(tierColor(tier))
                    Text(l.tierName(tier)).font(.caption).foregroundStyle(.secondary)
                }

                // 출처 팩 — 그림까지 함께 둔다. 이름만으로는 상점에서 어느 것인지 바로 못 찾는다.
                HStack(spacing: 5) {
                    PackImageView(setID: setID, width: 15)
                    Text(setName)
                        .font(.caption.weight(.medium))
                        .lineLimit(1).truncationMode(.tail)
                    Text("·").font(.caption2).foregroundStyle(.tertiary)
                    Text(ownedCount > 0 ? l.copiesOwned(ownedCount) : l.notOwnedYet)
                        .font(.caption2.weight(ownedCount > 0 ? .semibold : .regular))
                        .foregroundStyle(ownedCount > 0 ? .secondary : .tertiary)
                        .monospacedDigit()
                }
            }

            disenchantControls(l)
                .padding(.top, 8)
                .padding(.bottom, 6)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            withAnimation(.spring(response: 0.34, dampingFraction: 0.75)) { landed = true }
        }
        .onChange(of: cardID) {
            confirmingDisenchant = false
            lastRefund = nil
        }
    }

    /// 중복분을 갈아 토큰으로 돌려받는다.
    ///
    /// 마지막 한 장은 남긴다 — 수집한 카드가 컬렉션에서 사라지는 것은 되돌릴 수 없다.
    /// 한 장뿐이면 아무것도 뜨지 않는다.
    /// 확인은 인라인이다(`.alert` 금지 — 팝오버가 닫히면 고아 시트가 남는다).
    @ViewBuilder
    private func disenchantControls(_ l: L) -> some View {
        let spare = wallet.spareCount(cardID)
        let refund = CardDust.value(for: tier) * spare

        if let lastRefund {
            Label(l.disenchantDone(TokenFormatter.grouped(lastRefund)), systemImage: "checkmark.circle.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.green)
        } else if spare <= 0 {
            // 갈 것이 없으면 아무것도 보여주지 않는다. 못 하는 이유를 적어 두면
            // 대부분의 카드에서 쓸모없는 줄만 남는다.
            EmptyView()
        } else if confirmingDisenchant {
            VStack(spacing: 5) {
                Text(l.disenchantConfirm(spare, TokenFormatter.grouped(refund)))
                    .font(.caption2).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 8) {
                    Button(l.disenchant) {
                        let got = wallet.disenchant(cardID: cardID, tier: tier, count: spare)
                        confirmingDisenchant = false
                        lastRefund = got > 0 ? got : nil
                    }
                    .buttonStyle(.borderedProminent).controlSize(.small)
                    Button(l.cancel) { confirmingDisenchant = false }
                        .buttonStyle(.borderless).controlSize(.small)
                }
            }
        } else {
            Button {
                confirmingDisenchant = true
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.3.trianglepath")
                    Text("\(l.disenchant) ×\(spare)")
                    Text("+\(TokenFormatter.grouped(refund))").monospacedDigit().foregroundStyle(.secondary)
                }
                .font(.caption)
            }
            .buttonStyle(.bordered).controlSize(.small)
        }
    }
}
