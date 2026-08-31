import SwiftUI

/// 한 줄에 놓다가 넘치면 다음 줄로 넘기는 배치.
///
/// `HStack` 은 폭이 모자라면 자식을 눌러 줄이려 든다. 자식이 글자면 그 글자가 항목 **가운데**
/// 에서 꺾인다 — 누적 혜택 줄이 「판매 추가금 / +2.5%」 처럼 두 동으로 갈라져 다른 항목과
/// 뒤섞여 보인 것이 이것이다. 항목은 통째로 두고 줄 수를 늘리는 것이 맞다.
///
/// 자식에게는 각자 원하는 크기를 그대로 준다. 그래서 자식 쪽에 `fixedSize()` 를 붙여
/// 「이 항목은 쪼개지 않는다」를 분명히 해 두는 편이 좋다.
struct WrapLayout: Layout {
    /// 같은 줄에서 항목 사이 간격.
    var spacing: CGFloat = 6
    /// 줄 사이 간격.
    var lineSpacing: CGFloat = 4

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let limit = proposal.width ?? .infinity
        let rows = arrange(subviews, limit: limit)
        let width = rows.map(\.width).max() ?? 0
        let height = rows.reduce(0) { $0 + $1.height }
            + lineSpacing * CGFloat(max(0, rows.count - 1))
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize,
                       subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in arrange(subviews, limit: bounds.width) {
            var x = bounds.minX
            for index in row.items {
                let size = subviews[index].sizeThatFits(.unspecified)
                // 줄 안에서는 세로 가운데로 맞춘다. 높이가 다른 항목이 섞여도 밑선이 튀지 않는다.
                subviews[index].place(at: CGPoint(x: x, y: y + (row.height - size.height) / 2),
                                      proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
            y += row.height + lineSpacing
        }
    }

    private struct Row {
        var items: [Int] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    /// 어느 항목이 어느 줄에 가는가. 크기 계산과 배치가 같은 답을 써야 하므로 한 곳에 둔다.
    private func arrange(_ subviews: Subviews, limit: CGFloat) -> [Row] {
        var rows: [Row] = []
        var row = Row()
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            let grown = row.items.isEmpty ? size.width : row.width + spacing + size.width
            // 한 줄에 하나도 못 넣는 경우에는 넘치더라도 그 줄에 둔다 — 빈 줄을 만들지 않는다.
            if !row.items.isEmpty, grown > limit {
                rows.append(row)
                row = Row()
            }
            row.width = row.items.isEmpty ? size.width : row.width + spacing + size.width
            row.height = max(row.height, size.height)
            row.items.append(index)
        }
        if !row.items.isEmpty { rows.append(row) }
        return rows
    }
}
