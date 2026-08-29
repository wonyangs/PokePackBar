import AppKit

/// 카드 그림을 메뉴바 아이콘 크기로 합성한다.
///
/// 카드를 자르지 않고 통째로 줄인다. 그림 창만 잘라 내면 포켓몬은 크게 보이지만 자르는
/// 위치가 판형마다 달라(1999년 세트와 풀아트 카드가 서로 다르다) 어떤 카드는 이름줄이
/// 딸려 들어온다. 통째로 줄이면 작아도 늘 카드로 보인다.
///
/// 세로는 메뉴바 두께에 맞춰 고정하고 가로만 원본 비율대로 둔다. 세로가 프레임마다 흔들리면
/// 옆의 사용량 숫자와 밑선이 어긋난다.
enum MenuBarCardImage {

    /// 카드 위아래로 남기는 여백(합계). 메뉴바 두께를 꽉 채우면 답답하게 보인다.
    static let verticalInset: CGFloat = 4
    /// 카드 좌우로 남기는 여백(한쪽). 사용량 숫자와 붙어 보이지 않게 한다.
    static let horizontalPadding: CGFloat = 1

    /// 합성 기하 — 순수 함수라 테스트가 쉽다.
    ///
    /// - Parameters:
    ///   - pixelSize: 원본 카드 그림의 크기. 비율만 쓴다.
    ///   - thickness: 메뉴바 두께.
    static func layout(for pixelSize: CGSize,
                       thickness: CGFloat = 22) -> (canvas: NSSize, rect: NSRect) {
        let height = max(1, thickness - verticalInset)
        let aspect = pixelSize.height > 0 ? pixelSize.width / pixelSize.height : 0.717
        let width = (height * aspect).rounded()
        return (NSSize(width: width + horizontalPadding * 2, height: thickness),
                NSRect(x: horizontalPadding, y: ((thickness - height) / 2).rounded(),
                       width: width, height: height))
    }

    /// 메뉴바에 붙일 이미지. 템플릿으로 두지 않는다 — 카드는 색이 살아 있어야 한다.
    static func image(from card: NSImage, thickness: CGFloat = 22) -> NSImage {
        let layout = layout(for: card.size, thickness: thickness)
        let image = NSImage(size: layout.canvas)
        image.lockFocus()
        NSGraphicsContext.current?.imageInterpolation = .high
        // 모서리를 살짝 깎아 준다. 작아도 카드로 읽히게 하는 최소한의 단서다.
        let clip = NSBezierPath(roundedRect: layout.rect,
                                xRadius: layout.rect.width * 0.08,
                                yRadius: layout.rect.width * 0.08)
        clip.addClip()
        card.draw(in: layout.rect, from: .zero, operation: .sourceOver, fraction: 1)
        image.unlockFocus()
        image.isTemplate = false
        return image
    }
}
