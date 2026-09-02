import SwiftUI

/// 탭 줄. macOS 기본 세그먼트 컨트롤을 쓰지 않고 직접 그린다.
///
/// `.pickerStyle(.segmented)` 는 OS 판에 따라 제 내용 크기로 줄어든다. `maxWidth: .infinity`
/// 를 줘도 채우지 않는 판이 있고, macOS 26 에서 네 탭이 창 한가운데로 몰렸다. 어느 쪽이
/// 기본인지가 OS 마다 다르고 내 기기에서만 꽉 차게 보이면 이 차이를 영영 못 본다.
///
/// 칸을 직접 그리면 OS 판과 무관하게 늘 같은 폭이 된다. 칸마다 `maxWidth: .infinity` 를
/// 주므로 **몇 개를 넣든 폭을 똑같이 나눠 가진다.**
@MainActor
struct SegmentedTabs<Value: Hashable>: View {
    struct Item: Identifiable {
        let value: Value
        let label: String
        var id: Value { value }
    }

    let items: [Item]
    @Binding var selection: Value

    /// 칸 하나의 세로 여백. 줄 전체가 28pt 가 되도록 잡았다 —
    /// 바깥 여백 2×2 + 이 값 2×4 + 13pt 글자 높이 16 = 28.
    private let verticalPadding: CGFloat = 4
    private let radius: CGFloat = 7

    /// 탭 글자. 본문(14pt)보다 한 단계 작다 — 탭은 읽는 글이 아니라 자리를 가리키는 표라
    /// 줄 높이를 낮게 잡는 편이 화면을 넓게 쓴다.
    private var font: Font { .system(size: 13) }
    private var pickedFont: Font { .system(size: 13, weight: .semibold) }

    var body: some View {
        HStack(spacing: 2) {
            ForEach(items) { item in
                let picked = item.value == selection
                Button {
                    selection = item.value
                } label: {
                    Text(item.label)
                        .font(picked ? pickedFont : font)
                        .foregroundStyle(picked ? Color.white : Color.primary)
                        .lineLimit(1).minimumScaleFactor(0.8)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, verticalPadding)
                        .background(picked ? AnyShapeStyle(Color.accentColor)
                                           : AnyShapeStyle(Color.clear),
                                    in: RoundedRectangle(cornerRadius: radius - 2))
                        .contentShape(RoundedRectangle(cornerRadius: radius - 2))
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(picked ? [.isSelected, .isButton] : .isButton)
            }
        }
        .padding(2)
        .background(Color.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: radius))
        .frame(maxWidth: .infinity)
        // **세로로 눌리지 않게 못 박는다.**
        //
        // 팝오버 안에서 세로 자리가 모자라면 SwiftUI 가 줄일 수 있는 자식부터 줄인다.
        // 상단 탭 줄은 탭 내용(높이가 고정된 540pt)과 같은 VStack 에 있어 눌리는 쪽이 되고,
        // 탭 안의 갈래 선택은 그 540pt 안에 여유가 있어 안 눌린다. 그래서 같은 부품인데
        // 위는 28pt, 아래는 31pt 로 그려졌다. 글자까지 함께 줄어 크기가 달라 보인 원인이다.
        .fixedSize(horizontal: false, vertical: true)
    }
}
