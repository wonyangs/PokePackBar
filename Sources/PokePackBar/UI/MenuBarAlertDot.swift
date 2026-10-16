import AppKit

/// 메뉴바 아이콘 오른쪽 위의 빨간 점. 온라인 계정에 안 읽은 알림이 있으면 보인다.
///
/// 아이콘 그림에 그려 넣지 않고 버튼 위에 작은 뷰로 얹는다. 기본 아이콘은 템플릿 이미지라 메뉴바
/// 명암에 맞춰 색이 바뀌는데, 색 있는 점을 함께 그리면 템플릿으로 둘 수 없다.
@MainActor
final class MenuBarAlertDot {
    static let diameter: CGFloat = 6
    /// 점 중심을 아이콘 모서리에서 안쪽으로 들이는 거리. 카드 아이콘은 메뉴바 위끝에서 2pt 아래라,
    /// 모서리에 바로 두면 점 윗부분이 메뉴바 밖으로 잘린다.
    static let inset: CGFloat = 2

    private let view: NSView = {
        let view = NSView(frame: .zero)
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.systemRed.cgColor
        view.layer?.cornerRadius = MenuBarAlertDot.diameter / 2
        view.isHidden = true
        view.setAccessibilityElement(false)
        return view
    }()

    func update(visible: Bool, on button: NSStatusBarButton) {
        if view.superview !== button { button.addSubview(view) }
        guard visible, let image = button.image,
              let imageRect = (button.cell as? NSButtonCell)?.imageRect(forBounds: button.bounds) else {
            view.isHidden = true
            return
        }
        view.frame = Self.frame(imageRect: imageRect, alignment: image.alignmentRect,
                                content: Self.content(of: image), flipped: button.isFlipped)
        view.isHidden = false
    }

    /// 그림 안에서 점을 붙일 몸통(그림 좌표, 아래가 0).
    ///
    /// 기본 아이콘(SF 심볼)은 정렬 영역이 몸통이다. 「rectangle.stack.fill」은 그림이 17x18 인데
    /// 정렬 영역은 위의 겹친 줄을 뺀 큰 사각형(16.5x9)이고, 버튼도 이 영역을 이미지 자리로 잡는다.
    /// 카드 아이콘은 위아래와 좌우에 여백을 두고 그리므로, 그림 모서리에 두면 점이 카드에서 떨어져 뜬다.
    static func content(of image: NSImage) -> NSRect {
        guard !image.isTemplate else { return image.alignmentRect }
        return NSRect(origin: .zero, size: image.size)
            .insetBy(dx: MenuBarCardImage.horizontalPadding, dy: MenuBarCardImage.verticalInset / 2)
    }

    /// 점의 자리(버튼 좌표). `imageRect` 는 버튼이 그림의 정렬 영역(`alignment`)을 놓은 자리다.
    /// 몸통의 오른쪽 위 모서리에서 `inset` 만큼 안쪽에 점 중심을 둔다.
    static func frame(imageRect: NSRect, alignment: NSRect, content: NSRect, flipped: Bool) -> NSRect {
        let scaleX = alignment.width > 0 ? imageRect.width / alignment.width : 1
        let scaleY = alignment.height > 0 ? imageRect.height / alignment.height : 1
        let right = imageRect.minX + (content.maxX - alignment.minX) * scaleX
        let top = flipped
            ? imageRect.minY + (alignment.maxY - content.maxY) * scaleY
            : imageRect.minY + (content.maxY - alignment.minY) * scaleY
        let center = NSPoint(x: right - inset, y: flipped ? top + inset : top - inset)
        return NSRect(x: (center.x - diameter / 2).rounded(), y: (center.y - diameter / 2).rounded(),
                      width: diameter, height: diameter)
    }
}
