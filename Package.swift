// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PokePackBar",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "PokePackBar",
            path: "Sources/PokePackBar",
            resources: [
                .process("Resources/card-index.json"),
                .process("Resources/dex.json"),
                // 판매 중인 세트의 팩 아트는 번들에 넣는다 — 상점과 개봉 대기 화면에서
                // 로딩을 기다리지 않게 한다. 나머지 세트는 필요할 때 받아서 캐시한다.
                .copy("Resources/packs"),
            ],
            linkerSettings: [.linkedLibrary("sqlite3")]
        ),
        .testTarget(
            name: "PokePackBarTests",
            dependencies: ["PokePackBar"],
            path: "Tests/PokePackBarTests",
            resources: [
                .copy("Fixtures/CodexFork"),
                .copy("Fixtures/CodexSubagent"),
            ]
        ),
    ]
)
