import AppKit
import QuartzCore
import SwiftUI

// MARK: - 드래그로 돌리기

/// 카드를 끌어 돌린 자세.
///
/// 좌우로 끌면 세로축으로 끝까지 돈다(`yaw`, 0 이 앞면, 180 이 뒷면). 위아래로 끌면
/// 가로축으로 조금만 기울었다가 놓으면 돌아온다(`pitch`). 두 축을 다 끝까지 돌리면 앞면이
/// 거꾸로 멈추거나, 뒷면일 때 위아래 방향이 손과 반대로 도는 자세가 생긴다. 실물 카드를
/// 손가락으로 돌려 보는 것처럼 한 축만 끝까지 돌린다.
struct CardSpin: Equatable {
    /// 세로축으로 돌린 각도(도). 끝없이 늘어날 수 있다.
    var yaw: Double
    /// 가로축으로 기운 각도(도). 아래로 끌수록 아래쪽이 멀어진다.
    var pitch: Double

    static let rest = CardSpin(yaw: 0, pitch: 0)

    /// 위아래로 기울일 수 있는 한계. 이보다 더 끌어도 그 자리에 머문다.
    static let pitchLimit = 35.0

    /// 앞면이 보는 사람 쪽인지. 앞면의 법선은 cos(yaw) * cos(pitch) 만큼 화면을 향하고,
    /// `pitch` 는 90도에 못 미치므로 `yaw` 만 보면 된다.
    var showsFront: Bool { cos(yaw * .pi / 180) >= 0 }

    /// 앞면이나 뒷면을 똑바로 보고 멈춘 자세인지. 이때만 마우스 위치로 기울인다.
    var isSettled: Bool {
        abs(yaw - (yaw / 180).rounded() * 180) < 0.01 && abs(pitch) < 0.01
    }

    /// 끈 거리만큼 돌린 자세. 카드 폭만큼 끌면 반 바퀴다.
    ///
    /// 잡은 자리가 손을 따라간다. 오른쪽으로 끌면 오른쪽 가장자리가 멀어지고(yaw 가 줄고),
    /// 아래로 끌면 아래쪽이 멀어진다.
    func turned(by translation: CGSize, width: CGFloat) -> CardSpin {
        let degreesPerPoint = 180 / Double(max(width, 1))
        let pitch = Double(translation.height) * degreesPerPoint
        return CardSpin(yaw: yaw - Double(translation.width) * degreesPerPoint,
                        pitch: min(Self.pitchLimit, max(-Self.pitchLimit, pitch)))
    }

    /// 놓았을 때 멈출 자세: 가장 가까운 앞면이나 뒷면, 기울기는 0.
    var settled: CardSpin { CardSpin(yaw: (yaw / 180).rounded() * 180, pitch: 0) }

    /// 가장 가까운 앞면.
    var front: CardSpin { CardSpin(yaw: (yaw / 360).rounded() * 360, pitch: 0) }

    /// 도는 동안 광택이 따라 흐르게 카드 본체에 넘길 기울기. 마우스로 기울일 때와 같은 뜻이라,
    /// 오른쪽 가장자리가 멀어지면 nx 가, 아래쪽이 멀어지면 ny 가 커진다.
    ///
    /// 돌린 방향으로만 흐르다가 35도쯤에서 끝에 닿고, 옆으로 설 때까지 그대로 둔다. 처음에는
    /// sin(2 * yaw) 여서 한 방향으로 돌리는데 빛이 갔다가 되돌아왔고, 좌우도 마우스와 반대였다.
    var lightTilt: TiltVector {
        func share(_ degrees: Double) -> Double {
            min(1, max(-1, sin(degrees * .pi / 180) / sin(Self.pitchLimit * .pi / 180)))
        }
        return TiltVector(nx: -share(yaw) * 0.9, ny: share(pitch) * 0.9)
    }

    /// 앞면을 얼마나 똑바로 보는지. 정면에서 1, 정면에서 10도 벗어나면 0 이다. 마우스 기울이기는
    /// 이만큼만 섞어, 도는 동안에는 앞면이 두께 상자 안에서 따로 기울지 않고, 정면으로 돌아오며
    /// 마우스 기울기가 스며든다. 10도 안쪽에서는 옆면이 0.2pt 도 안 보여 어긋남이 드러나지 않는다.
    var faceOn: Double {
        let off = ((yaw - front.yaw) * (yaw - front.yaw) + pitch * pitch).squareRoot()
        return max(0, 1 - off / 10)
    }
}

/// 두께 있는 카드. 앞면, 뒷면, 네 옆면을 각자 3D 자리에 놓고 같은 회전과 원근을 준다.
///
/// `rotation3DEffect` 는 한 번 돌릴 때마다 결과를 평면으로 눌러 버려서, 옆면을 직각으로 세워
/// 붙여도 두께가 생기지 않는다. 면마다 변환 행렬을 직접 만들어 `projectionEffect` 로 준다.
/// 볼록한 상자라 보는 쪽을 향한 면만 그리면 서로 겹치지 않는다.
struct CardSlab {
    enum Face: CaseIterable { case front, back, left, right, top, bottom }

    let spin: CardSpin
    let width: CGFloat
    let height: CGFloat

    /// 두께. 실물 비율(63mm 폭에 0.3mm 남짓, 폭의 0.5%)을 그대로 쓴다. 1.2% 와 0.7% 는
    /// 두꺼워 보였다. 반올림하지 않아야 작은 카드에서도 비율이 그대로다.
    var thickness: CGFloat { width * 0.005 }
    /// 옆면이 둥근 모서리 밖으로 튀어나오지 않게 모서리만큼 짧게 둔다.
    private var corner: CGFloat { width * 0.05 }
    /// 원근을 주는 눈의 거리. 예전 `rotation3DEffect(perspective: 0.45)` 와 비슷한 깊이로 맞췄다.
    private var eyeDistance: CGFloat { max(width, height) * 2.6 }

    func size(_ face: Face) -> CGSize {
        switch face {
        case .front, .back: CGSize(width: width, height: height)
        case .left, .right: CGSize(width: thickness, height: height - 2 * corner)
        case .top, .bottom: CGSize(width: width - 2 * corner, height: thickness)
        }
    }

    /// 면을 카드 중심 기준 자리에 놓는다. 화면 좌표라 y 는 아래, z 는 보는 사람 쪽이다.
    private func placement(_ face: Face) -> CATransform3D {
        let half = thickness / 2
        switch face {
        case .front:
            return CATransform3DMakeTranslation(0, 0, half)
        case .back:
            // 뒷면은 앞면의 반대쪽에 붙어 있다. 반 바퀴 돌려 두어야 카드를 반 바퀴 돌렸을 때
            // 글자가 바로 읽힌다.
            return CATransform3DConcat(CATransform3DMakeRotation(.pi, 0, 1, 0),
                                       CATransform3DMakeTranslation(0, 0, -half))
        case .right:
            return CATransform3DConcat(CATransform3DMakeRotation(.pi / 2, 0, 1, 0),
                                       CATransform3DMakeTranslation(width / 2, 0, 0))
        case .left:
            return CATransform3DConcat(CATransform3DMakeRotation(-.pi / 2, 0, 1, 0),
                                       CATransform3DMakeTranslation(-width / 2, 0, 0))
        case .top:
            return CATransform3DConcat(CATransform3DMakeRotation(.pi / 2, 1, 0, 0),
                                       CATransform3DMakeTranslation(0, -height / 2, 0))
        case .bottom:
            return CATransform3DConcat(CATransform3DMakeRotation(-.pi / 2, 1, 0, 0),
                                       CATransform3DMakeTranslation(0, height / 2, 0))
        }
    }

    /// 끌어 돌린 자세: 세로축으로 `yaw`, 그다음 가로축으로 `pitch`.
    var rotation: CATransform3D {
        CATransform3DConcat(CATransform3DMakeRotation(CGFloat(-spin.yaw * .pi / 180), 0, 1, 0),
                            CATransform3DMakeRotation(CGFloat(-spin.pitch * .pi / 180), 1, 0, 0))
    }

    /// 면이 보는 사람 쪽을 얼마나 향하는지(-1...1). 0 보다 크면 보인다.
    func facing(_ face: Face) -> CGFloat {
        Self.apply(CATransform3DConcat(placement(face), rotation), to: (0, 0, 1, 0)).z
    }

    /// 카드 중심 기준의 점이 돌린 뒤 어디에 오는지. 테스트가 방향을 고정하는 데 쓴다.
    func rotated(_ point: (x: CGFloat, y: CGFloat, z: CGFloat)) -> (x: CGFloat, y: CGFloat, z: CGFloat) {
        Self.apply(rotation, to: (point.x, point.y, point.z, 1))
    }

    /// 면 뷰에 줄 변환. 면 뷰는 카드 중심에 놓이므로, 면의 가운데를 원점으로 옮겨 자리에 놓고
    /// 돌리고 원근을 준 뒤 다시 가운데로 되돌린다.
    func projection(_ face: Face) -> ProjectionTransform {
        let size = size(face)
        var perspective = CATransform3DIdentity
        perspective.m34 = -1 / eyeDistance
        var m = CATransform3DMakeTranslation(-size.width / 2, -size.height / 2, 0)
        m = CATransform3DConcat(m, placement(face))
        m = CATransform3DConcat(m, rotation)
        m = CATransform3DConcat(m, perspective)
        m = CATransform3DConcat(m, CATransform3DMakeTranslation(size.width / 2, size.height / 2, 0))
        return ProjectionTransform(m)
    }

    /// 행 벡터 × 행렬. Core Animation 은 점을 행 벡터로 곱한다.
    private static func apply(_ m: CATransform3D,
                              to v: (CGFloat, CGFloat, CGFloat, CGFloat)) -> (x: CGFloat, y: CGFloat, z: CGFloat) {
        (x: v.0 * m.m11 + v.1 * m.m21 + v.2 * m.m31 + v.3 * m.m41,
         y: v.0 * m.m12 + v.1 * m.m22 + v.2 * m.m32 + v.3 * m.m42,
         z: v.0 * m.m13 + v.1 * m.m23 + v.2 * m.m33 + v.3 * m.m43)
    }
}

/// 돌리는 카드의 무대. 애니메이션 중간 각도마다 다시 그려, 옆으로 서는 순간 앞면과 뒷면을
/// 바꿔 끼고 옆면을 보이거나 감춘다. 상태 값만 보고 고르면 놓는 순간 끝 각도의 면이 먼저 보인다.
///
/// 그림자는 무대가 돌린 뒤의 모양에 한 번만 드리운다. 면마다 그림자를 붙이면 그림자도 카드와
/// 함께 3D 로 돌아 옆으로 설 때 눌린 띠가 되고, 그 띠가 두께처럼 보였다. 등급 빛은 카드에
/// 붙어 함께 돌되, 옆으로 설수록 흐려져 띠로 남지 않는다.
@MainActor
struct CardSpinStage<Glow: View, Front: View>: View, @MainActor Animatable {
    var spin: CardSpin
    /// 마우스 기울기. 끄는 동안에는 0 이다. 앞면을 거의 똑바로 볼 때만 섞는다(`CardSpin.faceOn`).
    var pointerTilt: TiltVector
    let width: CGFloat
    let height: CGFloat
    /// 카드 뒤의 등급 빛. 카드와 같은 크기로 그리고, 받은 몸체 기울기만큼 앞면과 함께 기운다.
    /// 따로 두면 마우스로 기울일 때 빛의 테두리 선이 제자리에 남아 가장자리 밖으로 드러났다.
    @ViewBuilder let glow: (_ pose: TiltVector) -> Glow
    /// 앞면. 광택에 쓸 기울기와 몸체를 기울일 기울기를 따로 받고, 그림자와 등급 빛은 그리지 않는다.
    @ViewBuilder let front: (_ light: TiltVector, _ pose: TiltVector) -> Front

    nonisolated var animatableData: AnimatablePair<AnimatablePair<Double, Double>, AnimatablePair<Double, Double>> {
        get { AnimatablePair(AnimatablePair(spin.yaw, spin.pitch), AnimatablePair(pointerTilt.nx, pointerTilt.ny)) }
        set {
            spin = CardSpin(yaw: newValue.first.first, pitch: newValue.first.second)
            pointerTilt = TiltVector(nx: newValue.second.first, ny: newValue.second.second)
        }
    }

    var body: some View {
        let slab = CardSlab(spin: spin, width: width, height: height)
        // 앞면을 똑바로 보고 멈춰 있으면 변환 없이 돌리기 전과 똑같이 그린다. 마우스 기울이기도 그대로다.
        // 멈춘 앞면과 도는 앞면을 같은 자리의 같은 뷰로 그린다. 따로 그리면 끌기 시작하고 멈출
        // 때마다 카드 그림을 다시 불러와 한 박자 비었다.
        let resting = spin.isSettled && spin.showsFront
        let faceOn = spin.faceOn
        let pose = TiltVector(nx: pointerTilt.nx * faceOn, ny: pointerTilt.ny * faceOn)
        let turn = spin.lightTilt
        let light = TiltVector(nx: min(1, max(-1, pose.nx + turn.nx)),
                               ny: min(1, max(-1, pose.ny + turn.ny)))
        let shown: CardSlab.Face = slab.facing(.front) > 0 ? .front : .back
        let glowShare = slab.facing(shown)
        ZStack {
            glow(pose)
                .projectionEffect(resting ? ProjectionTransform() : slab.projection(shown))
                .opacity(Double(glowShare * glowShare))
            ZStack {
                if shown == .front {
                    front(light, pose)
                        .projectionEffect(resting ? ProjectionTransform() : slab.projection(.front))
                } else {
                    CardBackFace(width: width, height: height).projectionEffect(slab.projection(.back))
                }
                // 옆면은 앞면, 뒷면 다음에 그린다.
                ForEach([CardSlab.Face.left, .right, .top, .bottom], id: \.self) { face in
                    let facing = slab.facing(face)
                    if facing > 0.001 {
                        CardEdgeFace(size: slab.size(face), vertical: face == .left || face == .right, light: facing)
                            .projectionEffect(slab.projection(face))
                    }
                }
            }
            .compositingGroup()
            .shadow(color: .black.opacity(0.3), radius: width * 0.045,
                    x: -pose.nx * width * 0.018, y: width * 0.022 - pose.ny * width * 0.012)
        }
    }
}

/// 직전 클릭 시각. 두 번 누르기를 드래그와 같은 제스처 안에서 가린다. 화면 상태가 아니라
/// 참조로 두어, 클릭할 때마다 카드를 다시 그리지 않는다.
@MainActor
final class CardClickClock {
    var lastClick: Date?
}

/// 카드 옆면. 실물처럼 겉은 흰 종이, 가운데는 어두운 심이 보인다. 보는 쪽으로 돌수록 밝다.
@MainActor
struct CardEdgeFace: View {
    let size: CGSize
    let vertical: Bool
    let light: CGFloat

    var body: some View {
        let paper = Color(red: 0.93, green: 0.93, blue: 0.91)
        let core = Color(red: 0.16, green: 0.16, blue: 0.18)
        LinearGradient(stops: [.init(color: paper, location: 0), .init(color: paper, location: 0.32),
                               .init(color: core, location: 0.42), .init(color: core, location: 0.58),
                               .init(color: paper, location: 0.68), .init(color: paper, location: 1)],
                       startPoint: vertical ? .leading : .top, endPoint: vertical ? .trailing : .bottom)
            .brightness(-0.35 * (1 - Double(light)))
            .frame(width: size.width, height: size.height)
            .accessibilityHidden(true)
    }
}

/// 카드 뒷면. 리소스의 `card-back` 그림을 쓰고, 없으면 같은 비율의 어두운 판으로 대신한다.
@MainActor
struct CardBackFace: View {
    let width: CGFloat
    let height: CGFloat

    var body: some View {
        let corner = width * 0.05
        Group {
            if let image = CardBackImage.image {
                Image(nsImage: image).resizable().interpolation(.high)
                    .aspectRatio(contentMode: .fill)
            } else {
                LinearGradient(colors: [Color(red: 0.12, green: 0.2, blue: 0.45),
                                        Color(red: 0.05, green: 0.08, blue: 0.22)],
                               startPoint: .top, endPoint: .bottom)
            }
        }
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: corner))
        .overlay(RoundedRectangle(cornerRadius: corner).strokeBorder(.black.opacity(0.15), lineWidth: 0.5))
        .accessibilityHidden(true)
    }
}

/// 뒷면 그림은 한 장뿐이라 처음 한 번만 읽는다.
enum CardBackImage {
    static let image: NSImage? = AppResources.bundle?
        .url(forResource: "card-back", withExtension: "webp")
        .flatMap(NSImage.init(contentsOf:))
}
