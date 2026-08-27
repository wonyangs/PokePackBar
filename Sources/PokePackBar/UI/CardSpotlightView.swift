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
    /// 보유 장수. 0 이면 아직 얻지 못한 카드로 표시한다.
    let ownedCount: Int
    /// 미리 받아 둔 큰 그림이 있으면 기다리지 않는다.
    var preloaded: NSImage?
    let onClose: () -> Void

    @State private var landed = false

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

                HStack(spacing: 6) {
                    Text(cardID).font(.caption2).foregroundStyle(.tertiary).monospaced()
                    Text("·").font(.caption2).foregroundStyle(.tertiary)
                    Text(ownedCount > 0 ? l.copiesOwned(ownedCount) : l.notOwnedYet)
                        .font(.caption2.weight(ownedCount > 0 ? .semibold : .regular))
                        .foregroundStyle(ownedCount > 0 ? .secondary : .tertiary)
                        .monospacedDigit()
                }
            }
            .padding(.bottom, 6)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            withAnimation(.spring(response: 0.34, dampingFraction: 0.75)) { landed = true }
        }
    }
}
