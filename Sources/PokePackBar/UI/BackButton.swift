import SwiftUI

/// 뒤로 가기. **어느 화면에서든 왼쪽 위, 같은 모양으로 둔다.**
///
/// 예전에는 화면마다 달랐다 — 목록에서는 왼쪽 갈매기였고 상세에서는 오른쪽 X 였다. 상점에서
/// 시대 → 팩 목록 → 팩 상세로 들어가면 버튼이 왼쪽에 있다 오른쪽으로 건너뛰어서, 한 단계
/// 옮길 때마다 누를 곳을 눈으로 다시 찾아야 했다.
///
/// **누를 수 있는 넓이를 따로 잡는다.** 그림만 두면 실제로 눌리는 곳이 글리프 넓이(대략
/// 10×14pt)뿐이라 조금만 빗나가도 반응하지 않는다. 여백까지 눌리게 해 손이 닿는 크기로 만든다.
@MainActor
struct BackButton: View {
    let action: () -> Void
    /// 옆에 적을 글자. 설정·패치 노트처럼 자리가 있는 화면에서만 쓴다.
    var label: String?
    /// 마우스를 올렸을 때 뜨는 설명.
    var hint: String?

    var body: some View {
        Button(action: action) {
            HStack(spacing: 2) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 15, weight: .semibold))
                if let label {
                    Text(label).font(Typography.label)
                }
            }
            .foregroundStyle(.secondary)
            // 최소 28×24. 이보다 작으면 「눌러도 안 눌리는」 버튼이 된다.
            .frame(minWidth: 28, minHeight: 24, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(hint ?? label ?? "")
    }
}
