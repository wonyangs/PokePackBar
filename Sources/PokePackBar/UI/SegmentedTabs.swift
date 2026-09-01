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

    /// 칸 하나의 세로 여백. 기본 세그먼트 컨트롤과 비슷한 높이가 되도록 잡았다.
    private let verticalPadding: CGFloat = 5
    private let radius: CGFloat = 7

    var body: some View {
        HStack(spacing: 2) {
            ForEach(items) { item in
                let picked = item.value == selection
                Button {
                    selection = item.value
                } label: {
                    Text(item.label)
                        .font(picked ? Typography.labelSemibold : Typography.label)
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
    }
}
