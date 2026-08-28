import XCTest
@testable import PokePackBar

final class UpdateCheckerTests: XCTestCase {
    func testNewerPatch() {
        XCTAssertTrue(UpdateChecker.isNewer("2.0.2", than: "2.0.1"))
    }
    func testSameIsNotNewer() {
        XCTAssertFalse(UpdateChecker.isNewer("2.0.1", than: "2.0.1"))
    }
    func testOlderIsNotNewer() {
        XCTAssertFalse(UpdateChecker.isNewer("2.0.0", than: "2.0.1"))
        XCTAssertFalse(UpdateChecker.isNewer("2.0.9", than: "2.1.0"))
    }
    func testNumericNotLexical() {
        // "2.0.10" 은 "2.0.9" 보다 높다 (문자열 비교면 반대로 틀림)
        XCTAssertTrue(UpdateChecker.isNewer("2.0.10", than: "2.0.9"))
    }
    func testMinorAndMajor() {
        XCTAssertTrue(UpdateChecker.isNewer("2.1.0", than: "2.0.9"))
        XCTAssertTrue(UpdateChecker.isNewer("3.0.0", than: "2.9.9"))
    }
    func testDifferentComponentCounts() {
        XCTAssertTrue(UpdateChecker.isNewer("2.0.1", than: "2.0"))   // 2.0.1 > 2.0.0
        XCTAssertFalse(UpdateChecker.isNewer("2.0", than: "2.0.0"))  // 동일
    }

    // MARK: - Detached upgrade script wait loop (#175)

    func testDetachedUpgradeScriptWaitsOnPidNotProcessName() {
        let script = UpdateChecker.detachedUpgradeScript
        XCTAssertFalse(
            script.contains("pgrep -x"),
            "pgrep -x matches any instance by name and always times out when a duplicate runs"
        )
        XCTAssertTrue(
            script.contains("kill -0 \"$3\""),
            "the wait loop must wait on the specific terminating PID via $3"
        )
    }

    func testDetachedUpgradeScriptUsesPositionalParameters() {
        let script = UpdateChecker.detachedUpgradeScript
        XCTAssertTrue(script.contains("\"$1\" update"), "must execute brew via $1 positional arg")
        XCTAssertTrue(script.contains("\"$1\" upgrade"), "must execute brew upgrade via $1 positional arg")
        XCTAssertTrue(script.contains("open \"$2\""), "must open bundlePath via $2 positional arg")
    }
}

/// 확인이 실패했을 때 다음 확인이 막히면 안 된다.
///
/// 기동 직후 네트워크가 아직 안 올라온 한 번의 실패로 30분이 잠기면, 그 사이 팝오버를
/// 열어도 업데이트가 뜨지 않는다. 실제로 테스터가 "메인 화면에 안 뜨고 설정에서만 됐다" 고
/// 보고했고, 설정의 수동 확인은 minInterval 0 이라 잠금을 지나쳐 그때만 보인 것이다.
@MainActor
final class UpdateCheckThrottleTests: XCTestCase {

    private func response(_ tag: String) -> (Data, URLResponse) {
        let json = """
        {"tag_name":"\(tag)","html_url":"https://github.com/wonyangs/PokePackBar/releases/tag/\(tag)"}
        """
        let http = HTTPURLResponse(url: URL(string: "https://api.github.com")!, statusCode: 200,
                                   httpVersion: nil, headerFields: nil)!
        return (Data(json.utf8), http)
    }

    func testFailedCheckDoesNotBlockTheNextOne() async {
        var calls = 0
        let checker = UpdateChecker(currentVersion: "0.1.0", clock: { Date() }) { _ in
            calls += 1
            return nil          // 네트워크 실패
        }
        await checker.check()
        await checker.check()
        XCTAssertEqual(calls, 2, "실패한 확인이 다음 확인을 막았다")
        XCTAssertNil(checker.available)
    }

    /// 성공한 뒤에는 잠금이 걸려야 한다 — 레이트리밋 보호는 그대로 살아 있어야 한다.
    func testSuccessfulCheckThrottlesTheNextOne() async {
        var calls = 0
        let checker = UpdateChecker(currentVersion: "0.1.0", clock: { Date() }) { [self] _ in
            calls += 1
            return response("v9.9.9")
        }
        await checker.check()
        await checker.check()
        XCTAssertEqual(calls, 1, "성공 뒤에도 매번 조회하면 레이트리밋에 걸린다")
        XCTAssertEqual(checker.available?.version, "9.9.9")
    }

    /// 잠금 시간이 지나면 다시 조회한다.
    func testCheckResumesAfterTheInterval() async {
        var now = Date()
        var calls = 0
        let checker = UpdateChecker(currentVersion: "0.1.0", clock: { now }) { [self] _ in
            calls += 1
            return response("v9.9.9")
        }
        await checker.check()
        now = now.addingTimeInterval(3600)
        await checker.check()
        XCTAssertEqual(calls, 2)
    }
}

/// 조회 간격의 하한은 GitHub 한도가 정한다.
///
/// 무인증 REST API 가 IP 당 시간당 60회라 1분이 절대 바닥이고, 실제로는 여유를 두고 잡는다.
/// 같은 IP 를 쓰는 다른 것들이 있어서 한 사람이 60회를 다 쓸 수 있다고 가정하면 안 된다.
/// 한도를 넘기면 403 이 돌아오고 그 시간 동안 확인이 통째로 죽는다.
final class UpdateCheckIntervalTests: XCTestCase {
    func testIntervalStaysWellAboveTheRateLimitFloor() {
        XCTAssertGreaterThanOrEqual(UpdateChecker.minimumCheckInterval,
                                    UpdateChecker.rateLimitFloor * 2,
                                    "한도에 붙여 놓으면 다른 요청 하나에 403 을 맞는다")
        let perHour = 3600 / UpdateChecker.minimumCheckInterval
        XCTAssertLessThanOrEqual(perHour, 30, "시간당 \(Int(perHour))회는 한도의 절반을 넘는다")
    }
}
