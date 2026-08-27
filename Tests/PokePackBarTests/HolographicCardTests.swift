import XCTest
@testable import PokePackBar

/// 확대 화면의 기울기·광택은 눈으로만 확인하면 부호 하나가 뒤집혀도 모른다.
/// 순수 계산부만 여기서 잠근다 — 렌더링은 실제 앱에서 본다.
final class HoloProfileTests: XCTestCase {

    private let ordered = CardTier.allCases.sorted { $0.rank < $1.rank }

    /// 커먼도 회전한다. 확대 화면의 목적은 카드를 쥐고 기울여 보는 감각이라
    /// 등급으로 이 동작을 막으면 같은 화면이 카드마다 다르게 동작하는 것처럼 보인다.
    func testEveryTierCanRotate() {
        for tier in CardTier.allCases {
            XCTAssertGreaterThan(HoloProfile.of(tier).tilt, 0, "\(tier) 가 회전하지 않는다")
        }
    }

    /// 기울기는 5~8° 안에 머문다. 20° 쯤 돌리면 효과는 잘 보이지만
    /// 종이 한 장이 아니라 판자가 움직이는 것처럼 보인다.
    func testTiltStaysInPhysicalRange() {
        for tier in CardTier.allCases {
            let tilt = HoloProfile.of(tier).tilt
            XCTAssertGreaterThanOrEqual(tilt, 5.0, "\(tier) 기울기가 너무 작다")
            XCTAssertLessThanOrEqual(tilt, 8.0, "\(tier) 기울기가 너무 크다")
        }
    }

    /// 모서리까지 끌고 가도 최대 각도를 넘지 않아야 한다.
    /// 대각선 길이는 1 이 아니라 √2 라 정규화를 빼먹으면 11° 까지 벌어진다.
    func testCornerTiltNeverExceedsMaximum() {
        let corners = [TiltVector(nx: 1, ny: 1), TiltVector(nx: -1, ny: 1),
                       TiltVector(nx: 1, ny: -1), TiltVector(nx: -1, ny: -1)]
        for corner in corners {
            XCTAssertEqual(corner.magnitude, 1.0, accuracy: 0.0001)
            XCTAssertLessThanOrEqual(corner.magnitude * HoloProfile.maxTilt, 8.0)
        }
    }

    /// 등급이 오를수록 효과가 약해지는 층이 있으면 안 된다.
    func testEveryLayerRisesWithRarity() {
        let layers: [(String, (HoloProfile) -> Double)] = [
            ("tilt", \.tilt), ("specular", \.specular), ("foil", \.foil),
            ("glare", \.glare), ("sparkle", \.sparkle), ("edge", \.edge),
        ]
        for (name, value) in layers {
            let series = ordered.map { value(HoloProfile.of($0)) }
            for (a, b) in zip(series, series.dropFirst()) {
                XCTAssertLessThanOrEqual(a, b, "\(name) 세기가 뒤집혔다: \(series)")
            }
        }
    }

    /// 최고 등급은 커먼보다 모든 층에서 더 극적이어야 한다.
    func testTopTierIsMoreDramaticThanCommon() {
        let top = HoloProfile.of(.ultraRare)
        let common = HoloProfile.of(.common)
        XCTAssertGreaterThan(top.tilt, common.tilt)
        XCTAssertGreaterThan(top.specular, common.specular)
        XCTAssertGreaterThan(top.foil, common.foil)
        XCTAssertGreaterThan(top.glare, common.glare)
        XCTAssertGreaterThan(top.sparkle, common.sparkle)
        XCTAssertGreaterThan(top.edge, common.edge)
    }

    /// 훑기 간격은 등급과 무관하게 5초다.
    /// 등급 신호는 광택 세기가 맡는다 — 간격까지 갈리면 카드를 연달아 볼 때 리듬이 어긋난다.
    func testSweepIntervalIsUniform() {
        XCTAssertEqual(HoloProfile.sweepInterval, 5.0, accuracy: 0.001)
        XCTAssertGreaterThanOrEqual(HoloProfile.sweepInterval, 3.0,
                                    "이보다 잦으면 훑기가 상시 애니메이션에 가까워진다")
    }

    /// 커먼·언커먼에는 무지개가 붙지 않는다. 실제 카드도 홀로는 레어부터이고,
    /// 전부 무지개면 광택이 등급 신호로 작동하지 않는다.
    func testOnlyHoloTiersGetFoilAndSparkle() {
        for tier in [CardTier.energy, .common, .uncommon] {
            XCTAssertEqual(HoloProfile.of(tier).foil, 0, "\(tier) 에 포일이 붙었다")
            XCTAssertEqual(HoloProfile.of(tier).sparkle, 0, "\(tier) 에 반짝임이 붙었다")
        }
        XCTAssertGreaterThan(HoloProfile.of(.rare).foil, 0)
        XCTAssertGreaterThan(HoloProfile.of(.ultraRare).sparkle, 0)
    }
}

/// 광원은 고정돼 있고 카드만 회전한다는 모델의 부호를 잠근다.
///
/// 반사점이 마우스와 같은 방향으로 흐르면 조명이 커서에 붙어 따라오는 것처럼 보여
/// 물체감이 사라진다. 눈으로는 두 방향이 모두 그럴듯해 보여 구별이 어렵다.
final class HoloOpticsTests: XCTestCase {

    private let tilt = HoloProfile.of(.ultraRare).tilt

    /// 정지 상태에서는 광원 쪽(왼쪽 위)에 반사점이 있다.
    func testRestHighlightSitsTowardTheLight() {
        let rest = HoloOptics.highlight(nx: 0, ny: 0, tilt: tilt)
        XCTAssertLessThan(rest.x, 0.5, "왼쪽에 있어야 한다")
        XCTAssertLessThan(rest.y, 0.5, "위쪽에 있어야 한다")
    }

    func testHighlightMovesAgainstThePointer() {
        let rest = HoloOptics.highlight(nx: 0, ny: 0, tilt: tilt)
        let right = HoloOptics.highlight(nx: 1, ny: 0, tilt: tilt)
        let down = HoloOptics.highlight(nx: 0, ny: 1, tilt: tilt)
        XCTAssertLessThan(right.x, rest.x, "마우스를 오른쪽으로 옮기면 광택은 왼쪽으로 간다")
        XCTAssertEqual(right.y, rest.y, accuracy: 0.0001, "세로는 움직이지 않는다")
        XCTAssertLessThan(down.y, rest.y, "마우스를 아래로 옮기면 광택은 위로 간다")
        XCTAssertEqual(down.x, rest.x, accuracy: 0.0001, "가로는 움직이지 않는다")
    }

    /// 광택 이동량은 회전각에서 나온다. 더 많이 기울이는 등급이 더 많이 흘러야
    /// 회전과 광택이 따로 도는 것처럼 보이지 않는다.
    func testHighlightTravelScalesWithTilt() {
        let gentle = HoloOptics.highlight(nx: 1, ny: 0, tilt: HoloProfile.minTilt)
        let steep = HoloOptics.highlight(nx: 1, ny: 0, tilt: HoloProfile.maxTilt)
        let rest = HoloOptics.highlight(nx: 0, ny: 0, tilt: HoloProfile.minTilt)
        XCTAssertGreaterThan(abs(steep.x - rest.x), abs(gentle.x - rest.x))
    }

    /// 띠도 같은 규칙을 따른다.
    func testBandMovesAgainstThePointer() {
        let rest = HoloOptics.bandPosition(nx: 0, ny: 0, tilt: tilt)
        XCTAssertLessThan(rest, 0.5, "정지 상태에서 띠는 광원 쪽에 있다")
        XCTAssertLessThan(HoloOptics.bandPosition(nx: 1, ny: 0, tilt: tilt), rest)
        XCTAssertGreaterThan(HoloOptics.bandPosition(nx: -1, ny: 0, tilt: tilt), rest)
    }

    /// 띠는 어느 각도에서도 카드 안에 머물러야 한다. 좁은 띠라 한 번 벗어나면
    /// 그 각도에서 광택이 통째로 사라진다 — 기울였더니 오히려 무광이 되는 셈이다.
    func testBandStaysOnTheCardAtEveryAngle() {
        for nx in [-1.0, -0.5, 0, 0.5, 1.0] {
            for ny in [-1.0, -0.5, 0, 0.5, 1.0] {
                let pos = HoloOptics.bandPosition(nx: nx, ny: ny, tilt: HoloProfile.maxTilt)
                XCTAssertGreaterThan(pos, 0.12, "띠가 왼쪽으로 빠졌다 (\(nx), \(ny))")
                XCTAssertLessThan(pos, 0.88, "띠가 오른쪽으로 빠졌다 (\(nx), \(ny))")
            }
        }
    }

    /// 반사점도 카드에서 멀리 날아가면 안 된다. 조금 벗어나는 것은 정상이다 —
    /// 실제로도 많이 기울이면 반사광이 카드 밖으로 빠진다.
    func testHighlightStaysNearTheCard() {
        for nx in [-1.0, 0.0, 1.0] {
            for ny in [-1.0, 0.0, 1.0] {
                let h = HoloOptics.highlight(nx: nx, ny: ny, tilt: HoloProfile.maxTilt)
                XCTAssertGreaterThan(h.x, -0.1, "반사점이 왼쪽으로 날아갔다 (\(nx), \(ny))")
                XCTAssertLessThan(h.x, 1.1, "반사점이 오른쪽으로 날아갔다 (\(nx), \(ny))")
                XCTAssertGreaterThan(h.y, -0.1, "반사점이 위로 날아갔다 (\(nx), \(ny))")
                XCTAssertLessThan(h.y, 1.1, "반사점이 아래로 날아갔다 (\(nx), \(ny))")
            }
        }
    }
}

final class TiltVectorTests: XCTestCase {

    private let size = CGSize(width: 200, height: 279)

    func testCenterIsFlat() {
        let center = TiltVector(point: CGPoint(x: 100, y: 139.5), in: size)
        XCTAssertEqual(center.nx, 0, accuracy: 0.0001)
        XCTAssertEqual(center.ny, 0, accuracy: 0.0001)
        XCTAssertEqual(center.magnitude, 0, accuracy: 0.0001)
    }

    func testEdgesReachFullDeflection() {
        XCTAssertEqual(TiltVector(point: CGPoint(x: 200, y: 139.5), in: size).nx, 1, accuracy: 0.0001)
        XCTAssertEqual(TiltVector(point: CGPoint(x: 0, y: 139.5), in: size).nx, -1, accuracy: 0.0001)
        XCTAssertEqual(TiltVector(point: CGPoint(x: 100, y: 279), in: size).ny, 1, accuracy: 0.0001)
        XCTAssertEqual(TiltVector(point: CGPoint(x: 100, y: 0), in: size).ny, -1, accuracy: 0.0001)
    }

    /// 트래킹 영역이 프레임보다 조금 넓게 잡히는 경우가 있어 범위를 넘는 좌표가 들어온다.
    func testOutOfBoundsPointsClamp() {
        let far = TiltVector(point: CGPoint(x: 400, y: -120), in: size)
        XCTAssertEqual(far.nx, 1, accuracy: 0.0001)
        XCTAssertEqual(far.ny, -1, accuracy: 0.0001)
    }

    func testZeroSizeDoesNotProduceNaN() {
        let v = TiltVector(point: CGPoint(x: 10, y: 10), in: .zero)
        XCTAssertEqual(v.nx, 0)
        XCTAssertEqual(v.ny, 0)
    }

    /// 한 번의 회전으로 합친 축이 가로·세로 회전 두 개를 걸었을 때와 같아야 한다.
    /// (세로축 `nx * tilt`, 가로축 `-ny * tilt` — 참고한 구현과 같은 부호다.)
    /// 원 안(길이 <= 1)에서는 정확히 같다.
    func testCombinedAxisMatchesSeparateRotations() {
        let tilt = 7.0
        for (nx, ny) in [(0.0, 0.0), (0.6, 0.0), (0.0, -0.8), (-0.5, 0.5),
                         (0.3, -0.9), (-0.7, -0.2), (0.0, 1.0), (-1.0, 0.0)] {
            let v = TiltVector(nx: nx, ny: ny)
            let angle = v.magnitude * tilt
            let axis = v.axis
            XCTAssertEqual(Double(axis.y) * angle, nx * tilt, accuracy: 0.0001,
                           "세로축 회전이 어긋났다 (\(nx), \(ny))")
            XCTAssertEqual(Double(axis.x) * angle, -ny * tilt, accuracy: 0.0001,
                           "가로축 회전이 어긋났다 (\(nx), \(ny))")
        }
    }

    /// 모서리(길이 √2)에서는 각도만 최대값으로 잘리고 방향은 유지된다.
    /// 잘리지 않으면 대각선에서만 1.4배 더 기울어 보인다.
    func testCornerKeepsDirectionAndClampsAngle() {
        for (nx, ny) in [(1.0, 1.0), (-1.0, 1.0), (1.0, -1.0), (-1.0, -1.0)] {
            let v = TiltVector(nx: nx, ny: ny)
            XCTAssertEqual(v.magnitude, 1.0, accuracy: 0.0001)
            let axis = v.axis
            let length = (Double(axis.x) * Double(axis.x) + Double(axis.y) * Double(axis.y)).squareRoot()
            XCTAssertEqual(length, 1.0, accuracy: 0.0001, "회전축은 단위벡터여야 한다")
            // 방향은 (-ny, nx) 를 정규화한 값이다.
            let unit = 2.0.squareRoot()
            XCTAssertEqual(Double(axis.x), -ny / unit, accuracy: 0.0001)
            XCTAssertEqual(Double(axis.y), nx / unit, accuracy: 0.0001)
        }
    }

    func testFlatCardHasStableAxis() {
        let axis = TiltVector.zero.axis
        XCTAssertEqual(Double(axis.x), 0)
        XCTAssertEqual(Double(axis.y), 1)
        XCTAssertEqual(Double(axis.z), 0)
    }
}
