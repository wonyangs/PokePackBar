import SwiftUI

/// 이 앱의 글자 크기 정책.
///
/// 화면마다 `.caption2`·`.system(size: 9)` 를 손으로 골라 쓰다 보니 같은 성격의 글자가
/// 화면마다 다른 크기로 나왔고, 좁은 팝오버에 맞추느라 전체가 계속 작아졌다. 크기를 여기
/// 모아 두고 **역할로만 고르게** 한다.
///
/// **13pt 아래로 내려가지 않는다.** 메뉴바에서 잠깐 열어 보는 창이라 작은 글자는 읽히지
/// 않는다. 공간이 모자라면 글자를 줄이는 대신 줄 수를 줄이거나 창을 넓힌다.
enum Typography {

    /// 이 앱에서 허용하는 가장 작은 크기.
    static let minimumSize: CGFloat = 13

    /// 곁다리 표시 — 단위, 보조 설명, 배지 안의 잔글씨.
    static let caption = Font.system(size: 13)
    /// 항목 이름과 설명 — 목록 한 줄의 부제, 도움말.
    static let label = Font.system(size: 14)
    /// 본문 — 읽으라고 있는 글.
    static let body = Font.system(size: 15)
    /// 항목의 제목 — 팩 이름, 카드 이름, 도감 이름.
    static let title = Font.system(size: 17, weight: .semibold)
    /// 화면의 제목.
    static let heading = Font.system(size: 20, weight: .semibold)
    /// 연출용 큰 제목 — 갓팩 안내처럼 화면을 덮는 순간에만.
    static let display = Font.system(size: 24, weight: .heavy)

    /// 금액. 머리글의 잔액·컬렉션 가치도, 목록 안의 값도 모두 이것 하나를 쓴다.
    ///
    /// 머리글용 큰 치수를 따로 두었다가 도로 없앴다. 잔액과 컬렉션 가치는 같은 성격의
    /// 값이라 크기로 서열을 매기면 이름줄과 숫자줄의 밑선이 어긋나 나란히 읽히지 않고,
    /// 20pt 두 덩이는 메뉴바에서 잠깐 여는 창을 혼자 다 먹는다. 무엇이 무엇인지는 크기가
    /// 아니라 이름과 색이 알려 준다.
    static let amount = Font.system(size: 17, weight: .semibold)

    /// 버튼 글자.
    ///
    /// macOS 의 `.controlSize(.small)` 은 11pt, `.mini` 는 9pt 로 그린다 — 이 정책을
    /// 통째로 무시하는 값이라, 화면 곳곳의 버튼만 유독 작아 보였다. 버튼에는 크기를
    /// 직접 지정하고 컨트롤 크기는 기본(`.regular`)을 쓴다.
    static let button = Font.system(size: 15, weight: .medium)

    /// 등급 배지처럼 굵게 두는 짧은 글자.
    static let badge = Font.system(size: 14, weight: .heavy)
    static let badgeLarge = Font.system(size: 17, weight: .heavy)

    /// 강조가 필요한 변형.
    static var captionMedium: Font { .system(size: 13, weight: .medium) }
    static var labelSemibold: Font { .system(size: 14, weight: .semibold) }
    static var bodySemibold: Font { .system(size: 15, weight: .semibold) }
}
