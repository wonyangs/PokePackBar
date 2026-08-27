import AppKit
import SwiftUI

// MARK: - 등급별 세기

/// 확대한 카드에 얹는 홀로 효과의 등급별 세기.
///
/// 기울기(`tilt`)는 모든 등급이 갖는다 — 카드를 쥐고 기울여 보는 감각 자체가 확대 화면의
/// 목적이고, 커먼만 굳어 있으면 같은 화면이 카드마다 다르게 동작하는 것처럼 보인다.
/// 반면 무지개 포일과 반짝임은 등급이 올라갈 때만 붙는다 — 실제 카드도 커먼은 종이 광택뿐이고,
/// 전부 무지개면 광택이 등급 신호로 작동하지 않는다(후광 `TierGlow.strength` 와 같은 이유다).
struct HoloProfile: Equatable {
    /// 최대 기울기(도). 영상 구현의 ±20° 는 데모용이다 — 실물처럼 보이려면 이 범위여야 한다.
    var tilt: Double
    /// 넓게 퍼지는 흰 반사광. 종이 광택에 해당해 커먼에도 조금 있다.
    var specular: Double
    /// 좁은 무지개 포일(회절). 홀로 카드만 갖는다.
    var foil: Double
    /// 카드를 가로지르는 밝은 띠.
    var glare: Double
    /// 미세한 반짝임.
    var sparkle: Double
    /// 가장자리 반사.
    var edge: Double

    /// 기울기 하한·상한. 최고 등급도 8° 를 넘지 않는다.
    static let minTilt = 5.5
    static let maxTilt = 8.0

    /// 빛이 다시 훑기까지의 간격(초). **등급과 무관하게 같다.**
    ///
    /// 등급은 광택의 세기가 알린다 — 간격까지 등급별로 갈리면 카드를 연달아 볼 때
    /// 리듬이 들쭉날쭉해져 오히려 어색하다(개봉 유지 시간을 등급별로 줬다가
    /// `RevealTiming.hold` 로 되돌린 것과 같은 이유다).
    static let sweepInterval = 5.0

    static func of(_ tier: CardTier) -> HoloProfile {
        let t = intensity(for: tier)
        return HoloProfile(
            tilt: minTilt + (maxTilt - minTilt) * t,
            specular: 0.17 + 0.34 * t,
            foil: 0.95 * ramp(t, from: foilThreshold),
            glare: 0.09 + 0.53 * t,
            sparkle: ramp(t, from: sparkleThreshold),
            edge: 0.22 + 0.58 * t)
    }

    /// 등급을 0…1 로 옮긴 값. 후광 세기와 같은 곡선이지만 커먼이 0 이 아니다 —
    /// 커먼도 회전하고 종이 광택은 받는다.
    static func intensity(for tier: CardTier) -> Double {
        switch tier {
        case .energy:         return 0.00
        case .common:         return 0.06
        case .uncommon:       return 0.16
        case .rare:           return 0.34
        case .doubleRare:     return 0.52
        case .tripleRare:     return 0.64
        case .artRare:        return 0.74
        case .superRare:      return 0.84
        case .specialArtRare: return 0.92
        case .ultraRare:      return 1.00
        }
    }

    /// 커먼·언커먼에는 포일이 붙지 않는 경계. 홀로는 레어부터다.
    static let foilThreshold = 0.22
    /// 반짝임이 붙는 경계. 포일보다 늦게 시작해 상위 등급을 더 벌린다.
    static let sparkleThreshold = 0.45

    /// `from` 아래는 0, 그 위는 1 까지 선형으로 오른다.
    private static func ramp(_ t: Double, from: Double) -> Double {
        guard t > from else { return 0 }
        return (t - from) / (1 - from)
    }
}

// MARK: - 고정 광원 광학

/// 광원이 고정된 채 카드만 회전할 때 반사광이 어디로 가는지 계산한다.
///
/// 마우스를 따라다니는 스포트라이트로 만들면 조명이 손에 들려 함께 움직이는 것처럼 보여
/// 물체감이 사라진다. 그래서 반사점을 회전각에서 유도한다.
///
/// 유도: 실제 카드는 살짝 볼록해서 표면 법선이 중심에서 바깥으로 벌어진다(n = (ku, kw, 1)).
/// 회전으로 법선이 b 만큼 기울면 반사 조건을 만족하는 지점은 u = (h - b) / k 로 옮겨간다.
/// 즉 반사점은 **회전 방향과 반대로** 흐른다 — 마우스를 오른쪽으로 옮기면 광택은 왼쪽으로 간다.
/// 이 부호가 뒤집히면 그림에 스포트라이트를 비추는 것처럼 보인다.
enum HoloOptics {
    /// 정지 상태 반사점이 카드 중심에서 벗어난 정도(카드 비율). 광원은 왼쪽 위에 있다.
    static let restOffset = (x: -0.13, y: -0.18)

    /// 광택 띠의 축 방향(단위벡터). CSS 105deg 와 같다 — 거의 수직인 띠가 좌우로 흐른다.
    static let bandAxis = (x: 0.964, y: 0.265)

    /// 세기를 환산하는 기준 기울기. 같은 카드를 더 많이 기울이면 광택도 더 많이 흐른다.
    static let referenceTilt = 7.0

    /// 반사점이 기준 기울기에서 움직이는 거리(카드 비율).
    static let highlightTravel = 0.36

    /// 띠의 정지 위치(축 방향 0…1)와 이동량.
    ///
    /// 반사점보다 작게 준다. 반사점은 넓게 번지는 원형이라 카드를 조금 벗어나도 남은 부분이
    /// 카드를 밝히지만, 띠는 좁아서 벗어나는 순간 광택이 통째로 사라진다.
    static let bandRest = 0.42
    static let bandTravel = 0.17

    /// 반사점 위치(카드 비율 0…1). 0.5, 0.5 가 중심이다.
    static func highlight(nx: Double, ny: Double, tilt: Double) -> CGPoint {
        let gain = highlightTravel * tilt / referenceTilt
        return CGPoint(x: 0.5 + restOffset.x - nx * gain,
                       y: 0.5 + restOffset.y - ny * gain)
    }

    /// 광택 띠의 위치(축 방향 0…1). 축에 투사한 성분만 쓴다.
    static func bandPosition(nx: Double, ny: Double, tilt: Double) -> Double {
        let along = nx * bandAxis.x + ny * bandAxis.y
        return bandRest - along * bandTravel * tilt / referenceTilt
    }
}

// MARK: - 기울기

/// 카드 안 마우스 위치를 -1…+1 로 정규화한 값.
///
/// 정규화해 두면 카드 폭이 달라도 같은 위치에서 같은 각도가 나온다.
struct TiltVector: Equatable {
    var nx: Double
    var ny: Double

    static let zero = TiltVector(nx: 0, ny: 0)

    init(nx: Double, ny: Double) {
        self.nx = nx
        self.ny = ny
    }

    init(point: CGPoint, in size: CGSize) {
        let x = size.width > 0 ? (Double(point.x) / Double(size.width) - 0.5) * 2 : 0
        let y = size.height > 0 ? (Double(point.y) / Double(size.height) - 0.5) * 2 : 0
        self.init(nx: min(1, max(-1, x)), ny: min(1, max(-1, y)))
    }

    /// 중심에서 벗어난 정도(0…1). 모서리에서도 1 을 넘지 않아 최대 각도가 지켜진다.
    var magnitude: Double { min(1, length) }

    private var length: Double { (nx * nx + ny * ny).squareRoot() }

    /// 마우스 쪽 면이 밀려 들어가는 회전축.
    ///
    /// 세로축 회전 `nx * tilt` 와 가로축 회전 `-ny * tilt` 를 한 번의 회전으로 합친 것이다.
    /// 두 번 겹쳐 걸면 원근이 두 번 곱해진다.
    var axis: (x: CGFloat, y: CGFloat, z: CGFloat) {
        let l = length
        guard l > 0.0001 else { return (x: 0, y: 1, z: 0) }
        return (x: CGFloat(-ny / l), y: CGFloat(nx / l), z: 0)
    }
}

// MARK: - 뷰

/// 확대한 카드를 마우스로 기울여 보는 뷰.
///
/// 평면 이미지 한 장을 `rotation3DEffect` 로 기울이고 그 위에 광택을 겹쳐 홀로그램처럼 보이게
/// 한다. 실제 3D 렌더링은 쓰지 않는다.
///
/// 마우스 추적은 회전 밖에 둔다 — 회전한 뷰에 붙이면 좌표계가 함께 기울어 입력이 흔들린다.
@MainActor
struct HolographicCardView: View {
    let cardID: String
    let tier: CardTier
    var width: CGFloat = 200
    /// 아직 얻지 못한 카드. 실루엣이라 광택을 얹지 않는다.
    var dimmed = false
    var preloaded: NSImage?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var tilt = TiltVector.zero
    /// 등장할 때 한 번 훑고 지나가는 빛의 진행도(0…1).
    @State private var sweep = 0.0

    private var height: CGFloat { (width / 0.717).rounded() }

    var body: some View {
        HoloCardBody(cardID: cardID, tier: tier, width: width, height: height,
                     dimmed: dimmed, preloaded: preloaded, tilt: tilt, sweep: sweep)
            .frame(width: width, height: height)
            .contentShape(Rectangle())
            .onContinuousHover(coordinateSpace: .local) { phase in
                switch phase {
                case .active(let point):
                    // 짧은 스프링으로 살짝 늦게 따라오게 한다. 즉시 붙으면 종이가 아니라
                    // 커서에 고정된 판처럼 느껴진다.
                    withAnimation(.interactiveSpring(response: 0.15, dampingFraction: 0.86)) {
                        tilt = TiltVector(point: point,
                                          in: CGSize(width: width, height: height))
                    }
                case .ended:
                    withAnimation(.spring(response: 0.55, dampingFraction: 0.7)) {
                        tilt = .zero
                    }
                }
            }
            .onChange(of: cardID) { tilt = .zero }
            .task(id: cardID) { await runSweeps() }
    }

    /// 빛이 카드를 훑고 지나간다 — 꺼낸 직후 한 번, 그 뒤에는 같은 간격으로 다시.
    ///
    /// 쉬지 않고 도는 애니메이션은 아니다. 훑는 0.8초 말고는 아무것도 돌지 않고, 팝오버가
    /// 닫히면 `.task` 가 취소돼 완전히 멈춘다 — 메뉴바 앱의 idle 규율
    /// (`docs/reference/defect-log.md` 에너지)을 지키려면 이 두 성질이 필요하다.
    /// 대기는 tolerance 를 줘 다른 타이머와 묶이게 한다(wakeup 코얼레싱).
    ///
    /// 포일이 있는 등급만 훑는다. 커먼이 번쩍이면 광택이 등급 신호로 작동하지 않는다.
    private func runSweeps() async {
        let p = HoloProfile.of(tier)
        guard !reduceMotion, !dimmed, p.foil > 0 else { return }
        var wait = 0.3   // 첫 훑기는 카드가 자리를 잡은 직후
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(wait), tolerance: .seconds(0.5))
            if Task.isCancelled { return }
            withAnimation(.easeOut(duration: 0.8)) { sweep = 1 }
            try? await Task.sleep(for: .seconds(0.9), tolerance: .seconds(0.1))
            sweep = 0   // 띠가 카드 밖에 있는 시점이라 되돌리는 것이 보이지 않는다
            wait = HoloProfile.sweepInterval
        }
    }
}

/// 기울기·광택을 한 프레임 안에서 함께 계산하는 본체.
///
/// `Animatable` 이 필요한 이유: `withAnimation` 은 애니메이션 가능한 수정자만 보간하고 body 를
/// 다시 계산하지 않는다. 그대로 두면 마우스를 뗄 때 회전만 천천히 돌아오고 광택은 첫 프레임에
/// 제자리로 튄다. `animatableData` 로 기울기와 훑기를 노출하면 중간값마다 body 가 다시 돌아
/// 회전과 광택이 같이 움직인다.
@MainActor
private struct HoloCardBody: View, @MainActor Animatable {
    let cardID: String
    let tier: CardTier
    let width: CGFloat
    let height: CGFloat
    let dimmed: Bool
    let preloaded: NSImage?
    var tilt: TiltVector
    var sweep: Double

    nonisolated var animatableData: AnimatablePair<AnimatablePair<Double, Double>, Double> {
        get { AnimatablePair(AnimatablePair(tilt.nx, tilt.ny), sweep) }
        set {
            tilt = TiltVector(nx: newValue.first.first, ny: newValue.first.second)
            sweep = newValue.second
        }
    }

    private var corner: CGFloat { width * 0.05 }

    /// 광택 띠의 축. `HoloOptics.bandAxis` 와 같은 방향이다.
    private static let bandStart = UnitPoint(x: -0.1, y: 0.335)
    private static let bandEnd = UnitPoint(x: 1.1, y: 0.665)

    var body: some View {
        let p = HoloProfile.of(tier)
        let highlight = HoloOptics.highlight(nx: tilt.nx, ny: tilt.ny, tilt: p.tilt)
        let band = HoloOptics.bandPosition(nx: tilt.nx, ny: tilt.ny, tilt: p.tilt)

        ZStack {
            TierGlow(tier: tier, width: width)
            CardImageView(cardID: cardID, hires: true, width: width,
                          dimmed: dimmed, preloaded: preloaded)
                .overlay {
                    if !dimmed {
                        gloss(p, highlight: highlight, band: band)
                            .clipShape(RoundedRectangle(cornerRadius: corner))
                            .allowsHitTesting(false)
                            .accessibilityHidden(true)
                    }
                }
                // 블렌드가 카드 밖(후광·팝오버 배경)까지 번지지 않게 여기서 한 겹으로 합친다.
                .compositingGroup()
                .shadow(color: .black.opacity(0.3), radius: width * 0.045,
                        x: -tilt.nx * width * 0.018,
                        y: width * 0.022 - tilt.ny * width * 0.012)
        }
        .rotation3DEffect(.degrees(tilt.magnitude * p.tilt),
                          axis: tilt.axis, perspective: 0.55)
    }

    /// 광택 네 겹. 하나의 그라디언트로는 종이에 셀로판을 덮은 것처럼 보인다.
    ///
    /// 가만히 있을 때의 광량은 눌러 둔다. 카드를 기울일 때 살아나는 것이 광택이고,
    /// 정지 상태에서 세게 깔면 카드 그림 위에 흰 막을 덮은 것처럼 보인다.
    @ViewBuilder
    private func gloss(_ p: HoloProfile, highlight: CGPoint, band: Double) -> some View {
        let center = UnitPoint(x: highlight.x, y: highlight.y)
        let lit = 0.82 + 0.22 * tilt.magnitude
        ZStack {
            // 1. 넓은 흰 반사광. 여기에 color-dodge 를 쓰면 넓은 면적이 통째로 타서 그림이
            //    사라진다 — screen 으로 밝히는 정도가 종이 광택에 가깝다.
            RadialGradient(stops: [
                .init(color: .white.opacity(0.9), location: 0),
                .init(color: .white.opacity(0.28), location: 0.42),
                .init(color: .clear, location: 1),
            ], center: center, startRadius: 0, endRadius: width * 0.95)
            .blendMode(.screen)
            .opacity(p.specular * lit)

            // 2. 무지개 포일. 카드 전체 무지개를 띠 모양으로 잘라 쓴다. 각도가 바뀌면 색이
            //    도는 것(회절)까지 흉내 내야 금속처럼 보인다.
            if p.foil > 0 {
                rainbow
                    .hueRotation(.degrees(tilt.nx * 38 + tilt.ny * 16))
                    .mask { bandMask(center: band, halfWidth: 0.34) }
                    .blendMode(.colorDodge)
                    .opacity(p.foil * 0.42 * lit)
            }

            // 3. 좁은 광택 띠. 영상의 그 띠다 — color-dodge 가 아래 밝은 부분을 태워
            //    금속이 빛을 반사하는 것처럼 보이게 만든다.
            glareBand(center: band, strength: 1)
                .blendMode(.colorDodge)
                .opacity(p.glare * lit)

            // 3-b. 등장할 때 한 번 훑고 지나가는 빛. 카드 밖에서 시작해 밖으로 나간다.
            if sweep > 0, sweep < 1 {
                glareBand(center: -0.3 + 1.6 * sweep, strength: 1)
                    .blendMode(.colorDodge)
                    .opacity(sin(sweep * .pi) * (0.3 + 0.5 * p.glare))
            }

            // 4. 미세한 반짝임. 반사광이 닿는 쪽만 살아난다.
            if p.sparkle > 0 {
                SparkleLayer(seed: Self.seed(for: cardID), count: 140)
                    .mask {
                        RadialGradient(colors: [.white, .white.opacity(0.2), .clear],
                                       center: center,
                                       startRadius: 0, endRadius: width * 0.7)
                    }
                    .blendMode(.plusLighter)
                    .opacity(p.sparkle * 0.75)
            }

            // 5. 가장자리 반사. 비스듬히 볼수록 테두리가 먼저 빛난다.
            RoundedRectangle(cornerRadius: corner)
                .strokeBorder(edgeGradient(highlight: highlight),
                              lineWidth: max(1, width * 0.009))
                .blendMode(.plusLighter)
                .opacity(p.edge * (0.4 + 0.6 * tilt.magnitude))
        }
    }

    /// 카드 전면 무지개. 띠 마스크로 잘라 쓴다.
    private var rainbow: LinearGradient {
        LinearGradient(colors: [
            Color(hue: 0.02, saturation: 0.80, brightness: 0.78),
            Color(hue: 0.11, saturation: 0.78, brightness: 0.80),
            Color(hue: 0.22, saturation: 0.72, brightness: 0.80),
            Color(hue: 0.40, saturation: 0.74, brightness: 0.78),
            Color(hue: 0.52, saturation: 0.78, brightness: 0.80),
            Color(hue: 0.66, saturation: 0.80, brightness: 0.80),
            Color(hue: 0.80, saturation: 0.78, brightness: 0.78),
            Color(hue: 0.94, saturation: 0.78, brightness: 0.78),
        ], startPoint: Self.bandStart, endPoint: Self.bandEnd)
    }

    /// 띠 모양 마스크. `center` 는 축 방향 위치다.
    private func bandMask(center: Double, halfWidth: Double) -> LinearGradient {
        LinearGradient(stops: [
            .init(color: .clear, location: Self.clamped(center - halfWidth)),
            .init(color: .white, location: Self.clamped(center)),
            .init(color: .clear, location: Self.clamped(center + halfWidth)),
        ], startPoint: Self.bandStart, endPoint: Self.bandEnd)
    }

    /// 좁은 광택 띠. 흰 중심 앞뒤로 따뜻한 색과 찬 색을 둬 단색 번짐과 구별되게 한다.
    private func glareBand(center: Double, strength: Double) -> LinearGradient {
        LinearGradient(stops: [
            .init(color: .clear, location: Self.clamped(center - 0.17)),
            .init(color: Color(red: 1, green: 0.86, blue: 0.44).opacity(0.55 * strength),
                  location: Self.clamped(center - 0.05)),
            .init(color: .white.opacity(0.85 * strength), location: Self.clamped(center)),
            .init(color: Color(red: 0.42, green: 0.52, blue: 1).opacity(0.5 * strength),
                  location: Self.clamped(center + 0.05)),
            .init(color: .clear, location: Self.clamped(center + 0.17)),
        ], startPoint: Self.bandStart, endPoint: Self.bandEnd)
    }

    /// 가장자리 반사의 방향. 반사점이 있는 쪽 테두리가 밝다.
    private func edgeGradient(highlight: CGPoint) -> LinearGradient {
        var dx = highlight.x - 0.5
        var dy = highlight.y - 0.5
        let len = (dx * dx + dy * dy).squareRoot()
        if len > 0.0001 {
            dx /= len
            dy /= len
        } else {
            dx = -0.6
            dy = -0.8
        }
        return LinearGradient(stops: [
            .init(color: .white.opacity(0.95), location: 0),
            .init(color: .white.opacity(0.2), location: 0.45),
            .init(color: .clear, location: 1),
        ], startPoint: UnitPoint(x: 0.5 + dx * 0.55, y: 0.5 + dy * 0.55),
           endPoint: UnitPoint(x: 0.5 - dx * 0.55, y: 0.5 - dy * 0.55))
    }

    private static func clamped(_ v: Double) -> CGFloat { CGFloat(min(1, max(0, v))) }

    /// 카드마다 고정된 반짝임 배치를 위한 씨앗.
    private static func seed(for cardID: String) -> UInt64 {
        var h: UInt64 = 0xCBF29CE484222325
        for byte in cardID.utf8 {
            h = (h ^ UInt64(byte)) &* 0x100000001B3
        }
        return h
    }
}

/// 미세한 반짝임 점들.
///
/// 배치는 카드마다 고정한다 — 매 프레임 새로 뽑으면 반짝임이 아니라 노이즈처럼 지글거린다.
@MainActor
private struct SparkleLayer: View {
    let seed: UInt64
    let count: Int

    struct Dot {
        var x: Double
        var y: Double
        var radius: Double
        var alpha: Double
    }

    var body: some View {
        let dots = Self.dots(seed: seed, count: count)
        Canvas { context, size in
            for dot in dots {
                let r = dot.radius
                let rect = CGRect(x: dot.x * size.width - r, y: dot.y * size.height - r,
                                  width: r * 2, height: r * 2)
                context.fill(Path(ellipseIn: rect), with: .color(.white.opacity(dot.alpha)))
            }
        }
    }

    /// 같은 카드를 다시 열 때 배치가 바뀌지 않도록 한 번 만든 것을 들고 있는다.
    private static var cache: [UInt64: [Dot]] = [:]

    static func dots(seed: UInt64, count: Int) -> [Dot] {
        if let hit = cache[seed], hit.count == count { return hit }
        var state = seed == 0 ? 0x9E3779B97F4A7C15 : seed
        func next() -> Double {
            state ^= state << 13
            state ^= state >> 7
            state ^= state << 17
            return Double(state % 100_000) / 100_000
        }
        let made = (0..<count).map { _ in
            Dot(x: next(), y: next(), radius: 0.5 + next() * 1.5, alpha: 0.25 + next() * 0.7)
        }
        cache[seed] = made
        return made
    }
}
