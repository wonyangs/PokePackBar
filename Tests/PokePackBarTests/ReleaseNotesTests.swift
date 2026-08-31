import XCTest
@testable import PokePackBar

/// 패치 노트는 배포 절차의 일부다. 버전을 올리기 전에 여기에 먼저 적기로 했고,
/// 그 약속을 사람 기억이 아니라 테스트가 지킨다.
final class ReleaseNotesTests: XCTestCase {

    /// 배포 버전의 단일 출처는 `scripts/build-app.sh` 의 VERSION 이다.
    private static func shippingVersion() throws -> String {
        let script = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()    // PokePackBarTests
            .deletingLastPathComponent()    // Tests
            .deletingLastPathComponent()    // repo root
            .appendingPathComponent("scripts/build-app.sh")
        let text = try String(contentsOf: script, encoding: .utf8)
        let match = text.split(separator: "\n").compactMap { line -> String? in
            guard line.hasPrefix("VERSION=") else { return nil }
            return line.dropFirst("VERSION=".count).trimmingCharacters(in: CharacterSet(charactersIn: "\""))
        }.first
        return try XCTUnwrap(match, "build-app.sh 에서 VERSION 을 찾지 못했다")
    }

    /// 지금 배포되는 버전의 패치 노트가 없으면 실패한다 — 이게 이 파일의 존재 이유다.
    func testShippingVersionHasNotes() throws {
        let version = try Self.shippingVersion()
        let notes = L(.ko).releaseNotes
        XCTAssertTrue(notes.contains { $0.version == version },
                      "v\(version) 패치 노트가 없다. ReleaseNotes.swift 에 먼저 적는다. "
                      + "현재 적힌 버전: \(notes.map(\.version).joined(separator: ", "))")
    }

    /// 최신이 맨 위. 화면이 목록 순서를 그대로 쓴다.
    func testNewestFirst() {
        XCTAssertTrue(ReleaseNotes.isDescending(L(.ko).releaseNotes),
                      "패치 노트는 최신 버전이 앞이어야 한다")
    }

    /// 문자열 비교로 정렬하면 0.3.10 이 0.3.2 뒤로 간다. 숫자로 비교하는지 본다.
    func testOrderingComparesNumbers() {
        XCTAssertTrue(ReleaseNotes.ordering("0.3.2")
            .lexicographicallyPrecedes(ReleaseNotes.ordering("0.3.10")))
        XCTAssertEqual(ReleaseNotes.ordering("1.2.3"), [1, 2, 3])
    }

    func testVersionsAreUnique() {
        let versions = L(.ko).releaseNotes.map(\.version)
        XCTAssertEqual(Set(versions).count, versions.count, "같은 버전을 두 번 적었다")
    }

    /// 어느 언어로 열어도 같은 줄 수가 나오고, 빈 줄이 없어야 한다.
    /// 번역을 한 줄 빠뜨리면 그 언어 사용자만 항목이 사라진 화면을 본다.
    func testEveryLanguageHasEveryLine() {
        let reference = L(.ko).releaseNotes
        for language in AppLanguage.allCases {
            let notes = L(language).releaseNotes
            XCTAssertEqual(notes.map(\.version), reference.map(\.version),
                           "\(language) 의 버전 목록이 다르다")
            for (note, expected) in zip(notes, reference) {
                XCTAssertEqual(note.items.count, expected.items.count,
                               "\(language) v\(note.version) 의 항목 수가 다르다")
                // 세부 줄까지 센다. 세부 하나를 빠뜨리면 그 언어에서만 항목이 사라진다.
                XCTAssertEqual(note.items.map(\.details.count),
                               expected.items.map(\.details.count),
                               "\(language) v\(note.version) 의 세부 줄 수가 다르다")
                for line in note.items.flatMap(\.lines) {
                    XCTAssertFalse(line.trimmingCharacters(in: .whitespaces).isEmpty,
                                   "\(language) v\(note.version) 에 빈 항목이 있다")
                }
            }
        }
    }

    /// 한국어 문구를 그대로 둔 채 번역을 잊으면 다른 언어에서 한글이 나온다.
    func testNonKoreanLanguagesCarryNoHangul() {
        for language in AppLanguage.allCases where language != .ko {
            for note in L(language).releaseNotes {
                for line in note.items.flatMap(\.lines) {
                    XCTAssertFalse(line.unicodeScalars.contains { (0xAC00...0xD7A3).contains($0.value) },
                                   "\(language) v\(note.version): 번역이 빠졌다 — \(line)")
                }
            }
        }
    }
}
