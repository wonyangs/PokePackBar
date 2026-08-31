import SwiftUI

/// 카드 격자 한 칸의 크기.
///
/// 화면마다 칸 폭을 따로 적어 두었더니 팝오버 폭을 바꿀 때마다 어느 격자가 어긋났는지
/// 눈으로 찾아야 했다. 여기 모아 두고 테스트가 폭을 검사한다.
///
/// **칸 폭은 손으로 적지 않는다.** 격자가 놓이는 *자리의 폭*을 적으면 칸은 거기서 나온다.
/// 도감 띠는 팝오버가 아니라 줄 카드의 여백 안에 들어가는데 그것을 잊어 목록이 깨졌다 —
/// 자리를 적게 하면 그 여백을 잊을 수가 없다.
struct CardGrid: Sendable {
    let columns: Int
    let spacing: CGFloat
    /// 이 격자가 실제로 놓이는 자리의 폭.
    let available: CGFloat
    let width: CGFloat

    /// 세로 스크롤 안에서 스크롤 막대가 먹는 폭.
    ///
    /// 「스크롤 막대 보기」를 '항상'으로 둔 기기에서만 나타난다. 기본값은 겹쳐 그리는
    /// 막대라 자리를 먹지 않으므로, 빼 두지 않으면 그 설정을 쓰는 사람에게서만 격자가
    /// 넘친다 — 내 기기에서는 영영 보이지 않는 종류의 어긋남이다.
    static let scroller: CGFloat = 15

    /// 도감 목록의 줄 카드가 좌우에 두는 여백. 도감 띠는 이 안쪽에 들어간다.
    static let dexRowPadding: CGFloat = 8

    /// 주어진 자리를 칸으로 나눈다. 남는 자투리는 버린다 — 칸을 키워 넘치게 하느니
    /// 1pt 를 남기는 편이 낫다.
    static func fitting(_ available: CGFloat, columns: Int, spacing: CGFloat) -> CardGrid {
        let width = ((available - CGFloat(columns - 1) * spacing) / CGFloat(columns))
            .rounded(.down)
        return CardGrid(columns: columns, spacing: spacing, available: available, width: width)
    }

    /// 이 격자가 실제로 차지하는 가로 길이.
    var totalWidth: CGFloat { CGFloat(columns) * width + CGFloat(columns - 1) * spacing }

    var items: [GridItem] {
        Array(repeating: GridItem(.fixed(width), spacing: spacing), count: columns)
    }

    /// 탭 안쪽 세로 스크롤에 든 격자가 쓸 수 있는 폭. `inset` 은 그 격자를 감싼 여백이다.
    private static func inScroll(inset: CGFloat) -> CGFloat {
        PopoverMetrics.contentWidth - scroller - inset
    }

    /// 스크롤 없이 한 화면에 들어가는 격자가 쓸 수 있는 폭. 스크롤 막대 자리가 필요 없다.
    private static func onScreen(inset: CGFloat) -> CGFloat {
        PopoverMetrics.contentWidth - inset
    }

    /// 컬렉션 탭의 카드 격자.
    static let collection = fitting(inScroll(inset: 2), columns: 5, spacing: 6)
    /// 오리파 박스 안의 카드.
    static let oripa = fitting(inScroll(inset: 2), columns: 5, spacing: 5)
    /// 도감 한 줄에 늘어놓는 카드 띠. 줄 카드의 좌우 여백 안쪽이라 그만큼 좁다.
    static let dexStrip = fitting(inScroll(inset: dexRowPadding * 2), columns: 5, spacing: 5)
    /// 개봉 결과 요약.
    ///
    /// 열을 넷에서 다섯으로 늘렸다. 팩은 열 장이라 넷씩이면 세 줄이 되고, 세 줄은 머리글과
    /// 「확인」 버튼까지 더해 탭 높이를 넘어 스크롤이 생긴다. 다섯씩이면 두 줄로 끝난다 —
    /// 개봉 결과는 한 화면에 다 보여야 무엇을 건졌는지 한눈에 읽힌다.
    static let packSummary = fitting(onScreen(inset: 4), columns: 5, spacing: 8)

    static let all: [(name: String, grid: CardGrid)] = [
        ("collection", collection), ("oripa", oripa),
        ("dexStrip", dexStrip), ("packSummary", packSummary),
    ]
}
