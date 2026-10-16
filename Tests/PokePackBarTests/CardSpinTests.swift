import Foundation
import XCTest
@testable import PokePackBar

/// 카드를 끌어 돌리는 규칙. 화면 없이 각도 계산만 본다.
final class CardSpinTests: XCTestCase {

    /// 카드 폭만큼 좌우로 끌면 반 바퀴. 위아래는 한계에서 멈춘다.
    func testDraggingTurnsHalfAWidthPerCardWidth() {
        let turned = CardSpin.rest.turned(by: CGSize(width: 200, height: 1_000), width: 200)
        XCTAssertEqual(abs(turned.yaw), 180, accuracy: 0.001)
        XCTAssertEqual(turned.pitch, CardSpin.pitchLimit, accuracy: 0.001)
        XCTAssertEqual(abs(CardSpin.rest.turned(by: CGSize(width: -50, height: -20), width: 200).yaw), 45, accuracy: 0.001)
    }

    /// 옆으로 서는 90도를 넘으면 뒷면이 보인다. 한 바퀴를 넘겨도 마찬가지다.
    func testFaceFlipsPastTheEdge() {
        XCTAssertTrue(CardSpin(yaw: 89, pitch: 0).showsFront)
        XCTAssertFalse(CardSpin(yaw: 91, pitch: 0).showsFront)
        XCTAssertFalse(CardSpin(yaw: -180, pitch: 20).showsFront)
        XCTAssertTrue(CardSpin(yaw: 350, pitch: 0).showsFront)
    }

    /// 놓으면 가장 가까운 앞면이나 뒷면에 기울기 없이 선다. 두 번 누르면 가장 가까운 앞면.
    func testReleaseSettlesOnTheNearestFace() {
        XCTAssertEqual(CardSpin(yaw: 100, pitch: 20).settled, CardSpin(yaw: 180, pitch: 0))
        XCTAssertEqual(CardSpin(yaw: 80, pitch: -10).settled, CardSpin(yaw: 0, pitch: 0))
        XCTAssertEqual(CardSpin(yaw: 500, pitch: 0).settled, CardSpin(yaw: 540, pitch: 0))
        XCTAssertEqual(CardSpin(yaw: 200, pitch: 5).front, CardSpin(yaw: 360, pitch: 0))
        XCTAssertTrue(CardSpin(yaw: 540, pitch: 0).isSettled)
        XCTAssertFalse(CardSpin(yaw: 30, pitch: 0).isSettled)
    }

    /// 뒷면 그림은 리소스에 들어 있고 카드와 같은 비율이다. 없으면 어두운 판으로 바뀌어
    /// 화면은 깨지지 않지만, 빠진 줄 모르고 지나가면 안 된다.
    func testCardBackShipsWithTheApp() throws {
        let image = try XCTUnwrap(CardBackImage.image, "Resources/card-back.webp 를 읽지 못했다")
        XCTAssertEqual(image.size.width / image.size.height, 0.717, accuracy: 0.01)
    }

    /// 도는 동안의 광택은 마우스로 기울일 때와 같은 쪽으로 흐른다. 마우스를 오른쪽에 두면
    /// 오른쪽이 멀어지며 nx 가 커지니, 오른쪽으로 끌어 오른쪽이 멀어질 때도 nx 가 커져야 한다.
    /// 한 방향으로 돌리는 동안 되돌아오지 않고, 35도쯤에서 끝에 닿아 옆으로 설 때까지 머문다.
    func testSpinLightFlowsLikeThePointerTiltAndNeverTurnsBack() {
        XCTAssertEqual(CardSpin.rest.lightTilt.nx, 0, accuracy: 0.001)
        let rightAway = CardSpin.rest.turned(by: CGSize(width: 20, height: 0), width: 200)
        XCTAssertGreaterThan(rightAway.lightTilt.nx, 0)
        var last = -1.0
        for yaw in stride(from: 0.0, through: -89, by: -1) {
            let nx = CardSpin(yaw: yaw, pitch: 0).lightTilt.nx
            XCTAssertGreaterThanOrEqual(nx, last - 0.0001, "\(yaw)")
            last = nx
        }
        XCTAssertEqual(CardSpin(yaw: -35, pitch: 0).lightTilt.nx, 0.9, accuracy: 0.001)
        XCTAssertEqual(CardSpin(yaw: -85, pitch: 0).lightTilt.nx, 0.9, accuracy: 0.001)
        XCTAssertEqual(CardSpin(yaw: 380, pitch: 0).lightTilt.nx, CardSpin(yaw: 20, pitch: 0).lightTilt.nx, accuracy: 0.001)
        // 아래로 끌면 아래쪽이 멀어지고, 마우스를 아래에 둘 때처럼 ny 가 커진다.
        XCTAssertEqual(CardSpin(yaw: 0, pitch: CardSpin.pitchLimit).lightTilt.ny, 0.9, accuracy: 0.001)
    }

    /// 마우스 기울기는 앞면을 거의 똑바로 볼 때만 섞는다. 도는 동안 앞면이 두께 상자 안에서
    /// 따로 기울면 옆면과 어긋나 틈이 보였다.
    func testPointerTiltOnlyBlendsInNearTheFront() {
        XCTAssertEqual(CardSpin.rest.faceOn, 1, accuracy: 0.001)
        XCTAssertEqual(CardSpin(yaw: 360, pitch: 0).faceOn, 1, accuracy: 0.001)
        XCTAssertEqual(CardSpin(yaw: 5, pitch: 0).faceOn, 0.5, accuracy: 0.001)
        XCTAssertEqual(CardSpin(yaw: 30, pitch: 0).faceOn, 0)
        XCTAssertEqual(CardSpin(yaw: 0, pitch: 12).faceOn, 0)
        XCTAssertEqual(CardSpin(yaw: 180, pitch: 0).faceOn, 0)
    }

    /// 두께 있는 카드: 멈춘 앞면은 보는 쪽, 뒷면은 반대쪽이고 옆면은 옆을 본다.
    func testSlabFacesPointOutward() {
        let rest = CardSlab(spin: .rest, width: 200, height: 279)
        XCTAssertEqual(rest.facing(.front), 1, accuracy: 0.001)
        XCTAssertEqual(rest.facing(.back), -1, accuracy: 0.001)
        for face in [CardSlab.Face.left, .right, .top, .bottom] {
            XCTAssertEqual(rest.facing(face), 0, accuracy: 0.001, "\(face)")
        }
        let back = CardSlab(spin: CardSpin(yaw: 180, pitch: 0), width: 200, height: 279)
        XCTAssertEqual(back.facing(.back), 1, accuracy: 0.001)
        // 실물 비율: 63mm 폭에 0.3mm 남짓. 1.2% 도 0.7% 도 두꺼워 보였다.
        XCTAssertEqual(rest.thickness / rest.width, 0.005, accuracy: 0.0005)
    }

    /// 잡은 자리가 손을 따라간다: 오른쪽으로 끌면 오른쪽 가장자리가 멀어지며 왼쪽 옆면이 보이고,
    /// 아래로 끌면 아래쪽이 멀어지며 윗면이 보인다. 처음에는 오른쪽이 다가와서 거꾸로 느껴졌다.
    func testSlabTurnsTheWayTheDragGoes() {
        let dragged = CardSpin.rest.turned(by: CGSize(width: 34, height: 0), width: 200)
        let right = CardSlab(spin: dragged, width: 200, height: 279)
        XCTAssertLessThan(right.rotated((x: 100, y: 0, z: 0)).z, 0)
        XCTAssertGreaterThan(right.facing(.left), 0)
        XCTAssertLessThan(right.facing(.right), 0)
        let down = CardSlab(spin: CardSpin.rest.turned(by: CGSize(width: 0, height: 34), width: 200),
                            width: 200, height: 279)
        XCTAssertLessThan(down.rotated((x: 0, y: 140, z: 0)).z, 0)
        XCTAssertGreaterThan(down.facing(.top), 0)
        XCTAssertLessThan(down.facing(.bottom), 0)
    }
}
