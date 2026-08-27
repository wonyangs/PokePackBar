// PokePackBar 앱 아이콘 생성기 — 부스터 팩 모티프.
// 사용: swift scripts/generate-icon.swift <출력.png> [size=1024]
//
// 상표가 걸린 요소(몬스터볼 등)는 쓰지 않는다. 팩과 카드라는 이 앱의 소재만으로 그린다.
// 좌표는 100x100 기준(위가 원점)으로 정의하고 NSImage(아래가 원점)로 변환한다.
// 16px 에서도 읽혀야 하므로 형태는 셋(배경·카드·팩)으로만 유지하고 대비를 크게 준다.
import AppKit

let args = CommandLine.arguments
let outPath = args.count > 1 ? args[1] : "build/icon_1024.png"
let size = args.count > 2 ? (Int(args[2]) ?? 1024) : 1024

let S = CGFloat(size)
let f = S / 100.0

// 작은 크기에서는 요소를 덜어낸다. 각 크기를 직접 렌더하므로 가능한 조정이고,
// 32px 이하에서 포일 하이라이트와 잔 톱니는 형태를 흐리기만 한다.
let isSmall = size <= 32

func P(_ x: CGFloat, _ y: CGFloat) -> NSPoint { NSPoint(x: x * f, y: S - y * f) }
func R(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> NSRect {
    NSRect(x: x * f, y: S - (y + h) * f, width: w * f, height: h * f)
}
func col(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat) -> NSColor {
    NSColor(srgbRed: r/255, green: g/255, blue: b/255, alpha: 1)
}

// 팔레트 — 보라 바탕에 금색 팩. 메뉴바 축소에서도 두 색이 뭉치지 않는다.
let bgTop   = col(124, 58, 237)    // #7c3aed
let bgBot   = col(67, 20, 130)     // #431482
let packTop = col(253, 224, 71)    // #fde047
let packBot = col(234, 145, 8)     // #ea9108
let strip   = col(180, 83, 9)      // #b45309
let cardFill = NSColor.white
let cardEdge = col(226, 232, 240)  // #e2e8f0

let image = NSImage(size: NSSize(width: S, height: S))
image.lockFocus()
let ctx = NSGraphicsContext.current!
ctx.imageInterpolation = .high

// ── 배경 스퀘어클 ─────────────────────────────────────────────────────
let bg = NSBezierPath(roundedRect: NSRect(x: 0, y: 0, width: S, height: S),
                      xRadius: 22 * f, yRadius: 22 * f)
NSGradient(starting: bgTop, ending: bgBot)!.draw(in: bg, angle: -90)

// ── 팩에서 나오는 카드 ───────────────────────────────────────────────
// 팩만 그리면 무엇을 담았는지 안 보이고, 카드를 옆에 두면 그냥 나란히 놓인 두 물건이 된다.
// 팩 위로 솟게 겹쳐야 "뜯어서 꺼내는 것" 으로 읽힌다.
ctx.saveGraphicsState()
let cardTransform = NSAffineTransform()
cardTransform.translateX(by: (isSmall ? 61 : 58) * f, yBy: S - (isSmall ? 36 : 38) * f)
cardTransform.rotate(byDegrees: -17)
cardTransform.concat()
let cardW: CGFloat = isSmall ? 32 : 28
let cardH: CGFloat = isSmall ? 42 : 38
let cardRect = NSRect(x: -cardW / 2 * f, y: -cardH / 2 * f, width: cardW * f, height: cardH * f)
let card = NSBezierPath(roundedRect: cardRect, xRadius: 3.2 * f, yRadius: 3.2 * f)
cardFill.setFill(); card.fill()
cardEdge.setStroke(); card.lineWidth = 1.2 * f; card.stroke()
// 카드 안 그림 자리 — 한 칸만 둬도 빈 종이가 아니라 카드로 읽힌다.
if !isSmall {
    cardEdge.setFill()
    NSBezierPath(roundedRect: NSRect(x: -9.5 * f, y: 1 * f, width: 19 * f, height: 13 * f),
                 xRadius: 1.8 * f, yRadius: 1.8 * f).fill()
}
ctx.restoreGraphicsState()

// ── 부스터 팩 ────────────────────────────────────────────────────────
let packRect = R(24, 36, 35, 50)
let pack = NSBezierPath(roundedRect: packRect, xRadius: 4.5 * f, yRadius: 4.5 * f)
NSGradient(starting: packTop, ending: packBot)!.draw(in: pack, angle: -90)

ctx.saveGraphicsState()
pack.addClip()

// 개봉띠 — 얇게. 두꺼우면 뚜껑처럼 보여 팩으로 안 읽힌다.
strip.setFill()
NSBezierPath(rect: R(24, 36, 35, 5)).fill()

// 톱니 — 뜯긴 자리. 16px 에서 뭉개지지 않게 개수를 줄인다.
// 작은 크기에서는 톱니를 크고 성기게 — 잘게 두면 한 픽셀 안에서 뭉개진다.
let teeth = isSmall ? 3 : 5
let toothDepth: CGFloat = isSmall ? 5.5 : 3.5
let toothW = 35.0 / CGFloat(teeth)
let saw = NSBezierPath()
saw.move(to: P(24, 41))
for i in 0..<teeth {
    let x0 = 24 + CGFloat(i) * toothW
    saw.line(to: P(x0 + toothW / 2, 41 + toothDepth))
    saw.line(to: P(x0 + toothW, 41))
}
saw.line(to: P(59, 41))
saw.close()
strip.setFill(); saw.fill()

// 포일 하이라이트 — 존재만 느껴질 정도로. 작은 크기에서는 생략한다.
if !isSmall {
NSColor(white: 1, alpha: 0.16).setFill()
let sheen = NSBezierPath()
sheen.move(to: P(28, 86))
sheen.line(to: P(41, 41))
sheen.line(to: P(47, 41))
sheen.line(to: P(34, 86))
sheen.close()
sheen.fill()
}
ctx.restoreGraphicsState()

// 팩 테두리 — 배경·카드와 경계를 세운다.
col(120, 53, 15).setStroke()
pack.lineWidth = 1.5 * f
pack.stroke()

image.unlockFocus()

guard let tiff = image.tiffRepresentation,
      let rep = NSBitmapImageRep(data: tiff),
      let png = rep.representation(using: .png, properties: [:]) else {
    FileHandle.standardError.write("아이콘 렌더 실패\n".data(using: .utf8)!)
    exit(1)
}
let url = URL(fileURLWithPath: outPath)
try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                         withIntermediateDirectories: true)
do { try png.write(to: url) } catch {
    FileHandle.standardError.write("쓰기 실패: \(error)\n".data(using: .utf8)!)
    exit(1)
}
print("wrote \(outPath) (\(size)px)")
