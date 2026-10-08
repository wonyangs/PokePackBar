// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PokePackBar",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "PokePackBar",
            path: "Sources/PokePackBar",
            exclude: ["Resources/packs", "Resources/supplement-energy"],
            resources: [
                .process("Resources/card-index.json"),
                .process("Resources/dex.json"),
                .process("Resources/card-names-ko.json"),
                .process("Resources/card-prices.json"),
                .process("Resources/pack-prices.json"),
                .process("Resources/card-art.json"),
                .process("Resources/foil-geometry.json"),
                .process("Resources/foil-artwork-balance.json"),
                .process("Resources/foil-subject-masks.json"),
                .process("Resources/physical-foil-marks.json"),
                .copy("Resources/foil-marks"),
                .process("Resources/expansion-foil.json"),
                .process("Resources/reviewed-foil.json"),
                .process("Resources/cracked-ice-facets.json"),
                .process("Resources/catalogue-sources.json"),
                .process("Resources/pack-odds.json"),
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
