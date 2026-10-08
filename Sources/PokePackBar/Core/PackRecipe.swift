import Foundation

/// A physical booster contains more than the cards shown in the opening UI.
///
/// `gameCardCount` is the number of cards drawn from the expansion. A separately
/// packed Basic Energy and a code card are still physical cards, but neither is
/// part of the expansion pool, collection progress, or pull-rate denominator.
struct PackContents: Equatable, Sendable {
    let gameCardCount: Int
    let energyCardCount: Int
    let codeCardCount: Int

    var physicalCardCount: Int {
        gameCardCount + energyCardCount + codeCardCount
    }
}

/// The role of a card position in a booster.
///
/// Scarlet & Violet deliberately has two separate reverse positions. Keeping
/// them distinct lets only the second position carry the measured illustration
/// rare table instead of accidentally doubling those pull rates.
enum PackSlotKind: String, Hashable, Sendable {
    /// A Basic Energy printed as one of the expansion's collectible cards.
    /// This is distinct from the separately packed modern Energy card in
    /// `PackContents.energyCardCount`.
    case energy
    case common
    case uncommon
    case reverseHolo
    case reverseHoloHit
    /// Legendary Treasures position: a reverse parallel or a base-set Holo Rare.
    case legendaryTreasuresReverse
    case rare
    case allFoil
    /// One of the 30 Pikachu Rare illustrations, not Pikachu ex or a Classic reprint.
    case anniversaryPikachu
    /// Celebrations positions 1–2: regular-set holo cards only.
    case celebrationsHolo
    /// Celebrations' third position: either a base-set holo or one Classic Collection card.
    /// 30th Celebration's third position works the same way: a Common, an Illustration
    /// Rare or a Classic Collection card.
    case classicCollection
    /// Celebrations position 4: the regular set's rare/hit position. 30th Celebration's
    /// fourth position is the same kind of Rare-or-better position.
    case celebrationsRare
    /// A guaranteed Common from an English Radiant Collection subset.
    case radiantCollectionCommon
    /// A guaranteed Uncommon or Ultra Rare from a separate Radiant Collection sheet.
    case radiantCollectionHigh
}

struct PackRecipeSlot: Equatable, Sendable {
    let kind: PackSlotKind
    let count: Int
}

/// A non-standard booster that can replace some or all standard positions.
enum PackVariant: String, Codable, Equatable, Sendable {
    case standard
    case celebrations
    case scarletViolet151Demigod
    case prismaticEvolutionsGod
    case prismaticEvolutionsDemigod
    case blackBoltWhiteFlareGod
    case ascendedHeroesGod

    var isSpecialHit: Bool {
        switch self {
        case .scarletViolet151Demigod, .prismaticEvolutionsGod, .prismaticEvolutionsDemigod,
             .blackBoltWhiteFlareGod, .ascendedHeroesGod:
            return true
        case .standard, .celebrations:
            return false
        }
    }

    var isGodPack: Bool {
        self == .prismaticEvolutionsGod || self == .blackBoltWhiteFlareGod
            || self == .ascendedHeroesGod
    }
}

/// Rendering hint carried by a slot until the printing-level `CardFinish`
/// model is attached to `PulledCard`.
///
/// In particular, the first card in a Prismatic Evolutions God Pack is the
/// Master Ball parallel of Eevee. Its rarity is still Common, so rarity alone
/// can never recover that finish.
enum PackFinishHint: String, Codable, Equatable, Sendable {
    case normal
    case reverseHolo
    case ascendedParallel
    case holoRare
    case allFoil
    case defaultForCard
    case pokeBallParallel
    case masterBallParallel
}

struct PackCardRequest: Equatable, Sendable {
    let tier: CardTier
    let exactCardID: String?
    /// Restricts a tier request to one physical subset/sheet. `nil` keeps the
    /// ordinary whole-tier pool; an empty array deliberately leaves the slot empty.
    let candidateCardIDs: [String]?
    let finishHint: PackFinishHint

    init(tier: CardTier, exactCardID: String? = nil,
         candidateCardIDs: [String]? = nil,
         finishHint: PackFinishHint = .defaultForCard) {
        self.tier = tier
        self.exactCardID = exactCardID
        self.candidateCardIDs = candidateCardIDs
        self.finishHint = finishHint
    }
}

struct PackSpecialVariantRule: Equatable, Sendable {
    let variant: PackVariant
    /// Simulator setting, not an officially published pull rate.
    let estimatedSimulatorOneIn: Int
    let replacedSlots: Set<PackSlotKind>

    var replacesWholePack: Bool {
        replacedSlots == Set(PackSlotKind.allCasesUsedByStandardRecipes)
    }
}

private extension PackSlotKind {
    static let allCasesUsedByStandardRecipes: [PackSlotKind] = [
        .common, .uncommon, .reverseHolo, .reverseHoloHit, .rare,
    ]
}

/// Physical composition for one expansion booster.
struct PackRecipe: Equatable, Sendable {
    let slots: [PackRecipeSlot]
    let contents: PackContents
    let baseVariant: PackVariant
    let specialVariant: PackSpecialVariantRule?

    /// Mutually exclusive outcomes of one roll, not independent overlapping rolls.
    var specialRules: [PackSpecialVariantRule] {
        guard let specialVariant else { return [] }
        guard specialVariant.variant == .prismaticEvolutionsGod else { return [specialVariant] }
        return [specialVariant, PackSpecialVariantRule(variant: .prismaticEvolutionsDemigod,
            estimatedSimulatorOneIn: Self.estimatedPrismaticGodOneIn,
            replacedSlots: [.reverseHolo, .reverseHoloHit, .rare])]
    }

    func standardShare(for slot: PackSlotKind) -> Double {
        1 - specialRules.filter { $0.replacedSlots.contains(slot) }
            .reduce(0.0) { $0 + 1 / Double($1.estimatedSimulatorOneIn) }
    }

    /// 151 English "demigod" packs have no officially published rate. 1/1300
    /// is an explicitly labelled simulator estimate from weak community data.
    static let estimated151DemigodOneIn = 1_300

    /// Prismatic Evolutions English God Packs have no officially published
    /// rate. Community estimates span roughly 1/1500–1/4000; the simulator uses
    /// the midpoint-like 1/2500 setting and does not present it as a real rate.
    static let estimatedPrismaticGodOneIn = 2_500

    /// Black Bolt and White Flare English God Packs are confirmed to contain
    /// nine Illustration Rares and one Special Illustration Rare, but no
    /// manufacturer rate has been published. PokeBeach likewise reports the
    /// rate as unknown and comparable to prior English God Packs, so the
    /// simulator deliberately reuses the conservative 1/2500 setting instead
    /// of presenting false precision as observed data.
    static let estimatedBlackBoltWhiteFlareGodOneIn = 2_500

    /// Ascended Heroes God Packs are confirmed as 3 Mega Attack Rares + 7 SIRs.
    /// TPCi has not published an insertion rate. Large community openings cluster
    /// around one per thousand packs, so this remains an explicitly labelled
    /// simulator setting rather than an official or guaranteed rate.
    static let estimatedAscendedHeroesGodOneIn = 1_000

    /// TCGplayer가 대량 개봉으로 관측한 영문판 병렬판형 출현율.
    /// 제조사가 공시한 확률이 아니므로 UI에서도 "관측치"로 구분한다.
    /// 정수 분모를 쓰면 추첨과 표시가 같은 숫자를 공유한다.
    static let prismaticParallelRolls = 10_000
    static let observedPrismaticPokeBallHits = 3_310   // 33.10%, 약 1/3팩
    static let observedPrismaticMasterBallHits = 492  // 4.92%, 약 1/20팩
    static let observedBlackWhitePokeBallHits = 3_056  // 30.56%
    static let observedBlackWhiteMasterBallHits = 514 // 5.14%

    static func observedParallelHits(setID: String, slot: PackSlotKind) -> Int? {
        switch (setID, slot) {
        case ("sv8pt5", .reverseHolo):
            return observedPrismaticPokeBallHits
        case ("sv8pt5", .reverseHoloHit):
            return observedPrismaticMasterBallHits
        case ("rsv10pt5", .reverseHolo), ("zsv10pt5", .reverseHolo):
            return observedBlackWhitePokeBallHits
        case ("rsv10pt5", .reverseHoloHit), ("zsv10pt5", .reverseHoloHit):
            return observedBlackWhiteMasterBallHits
        default:
            return nil
        }
    }

    static func forSet(_ setID: String, era: PackEra) -> PackRecipe {
        // 30th Celebration: two foil Commons, a Common that an Illustration Rare or a
        // Classic Collection card can replace, the Rare position (Double Rare, SIR and
        // Futuristic Rare replace it), and the guaranteed Pikachu Rare. Four
        // interchangeable foil positions let one pack hold several Double Rares or
        // no Rare at all, which a real pack never does.
        if setID == "cel30" {
            return PackRecipe(slots: [PackRecipeSlot(kind: .allFoil, count: 2),
                                      PackRecipeSlot(kind: .classicCollection, count: 1),
                                      PackRecipeSlot(kind: .celebrationsRare, count: 1),
                                      PackRecipeSlot(kind: .anniversaryPikachu, count: 1)],
                contents: PackContents(gameCardCount: 5, energyCardCount: 1, codeCardCount: 1),
                baseVariant: .standard, specialVariant: nil)
        }
        // Early Wizards sets used fixed Energy positions rather than randomly
        // mixing Energy into every Common position. Base/Base Set 2 carried two;
        // Gym Heroes, Gym Challenge, and Neo Genesis carried one. The other
        // 11-card Wizards expansions used seven ordinary Commons.
        if let energyCount = wotcEnergyCardsPerPack[setID] {
            let slots = [
                PackRecipeSlot(kind: .common, count: 7 - energyCount),
                PackRecipeSlot(kind: .energy, count: energyCount),
                PackRecipeSlot(kind: .uncommon, count: 3),
                PackRecipeSlot(kind: .rare, count: 1),
            ]
            return PackRecipe(
                slots: slots,
                contents: PackContents(gameCardCount: 11, energyCardCount: 0, codeCardCount: 0),
                baseVariant: .standard,
                specialVariant: nil
            )
        }

        // Double Crisis was a seven-card mini-set pack: three Commons, two
        // Uncommons, one reverse parallel, and one guaranteed Holo or full art.
        if setID == "dc1" {
            let slots = [
                PackRecipeSlot(kind: .common, count: 3),
                PackRecipeSlot(kind: .uncommon, count: 2),
                PackRecipeSlot(kind: .reverseHolo, count: 1),
                PackRecipeSlot(kind: .rare, count: 1),
            ]
            return PackRecipe(
                slots: slots,
                contents: PackContents(gameCardCount: 7, energyCardCount: 0, codeCardCount: 1),
                baseVariant: .standard,
                specialVariant: nil
            )
        }

        if setID == "cel25" {
            let slots = [
                PackRecipeSlot(kind: .celebrationsHolo, count: 2),
                PackRecipeSlot(kind: .classicCollection, count: 1),
                PackRecipeSlot(kind: .celebrationsRare, count: 1),
            ]
            return PackRecipe(
                slots: slots,
                contents: PackContents(gameCardCount: 4, energyCardCount: 0, codeCardCount: 1),
                baseVariant: .celebrations,
                specialVariant: nil
            )
        }

        // Both English Radiant Collection releases replace two ordinary cards
        // with cards from two independently printed subset sheets. Keeping
        // these as real positions also prevents RC-numbered cards from leaking
        // into the core Common, Uncommon, reverse, and rare positions.
        if setID == "g1" || setID == "bw11" {
            let slots = [
                PackRecipeSlot(kind: .common, count: 4),
                PackRecipeSlot(kind: .uncommon, count: 2),
                PackRecipeSlot(
                    kind: setID == "bw11" ? .legendaryTreasuresReverse : .reverseHolo,
                    count: 1
                ),
                PackRecipeSlot(kind: .radiantCollectionCommon, count: 1),
                PackRecipeSlot(kind: .radiantCollectionHigh, count: 1),
                PackRecipeSlot(kind: .rare, count: 1),
            ]
            return PackRecipe(
                slots: slots,
                contents: PackContents(gameCardCount: 10, energyCardCount: 0, codeCardCount: 1),
                baseVariant: .standard,
                specialVariant: nil
            )
        }

        var recipe = standard(for: era)
        switch setID {
        case "sv3pt5":
            recipe = PackRecipe(
                slots: recipe.slots,
                contents: recipe.contents,
                baseVariant: recipe.baseVariant,
                specialVariant: PackSpecialVariantRule(
                    variant: .scarletViolet151Demigod,
                    estimatedSimulatorOneIn: estimated151DemigodOneIn,
                    replacedSlots: [.reverseHolo, .reverseHoloHit, .rare]
                )
            )
        case "sv8pt5":
            recipe = PackRecipe(
                slots: recipe.slots,
                contents: recipe.contents,
                baseVariant: recipe.baseVariant,
                specialVariant: PackSpecialVariantRule(
                    variant: .prismaticEvolutionsGod,
                    estimatedSimulatorOneIn: estimatedPrismaticGodOneIn,
                    replacedSlots: Set(PackSlotKind.allCasesUsedByStandardRecipes)
                )
            )
        case "zsv10pt5", "rsv10pt5":
            recipe = PackRecipe(
                slots: recipe.slots,
                contents: recipe.contents,
                baseVariant: recipe.baseVariant,
                specialVariant: PackSpecialVariantRule(
                    variant: .blackBoltWhiteFlareGod,
                    estimatedSimulatorOneIn: estimatedBlackBoltWhiteFlareGodOneIn,
                    replacedSlots: Set(PackSlotKind.allCasesUsedByStandardRecipes)
                )
            )
        case "me2pt5":
            recipe = PackRecipe(
                slots: recipe.slots,
                contents: recipe.contents,
                baseVariant: recipe.baseVariant,
                specialVariant: PackSpecialVariantRule(
                    variant: .ascendedHeroesGod,
                    estimatedSimulatorOneIn: estimatedAscendedHeroesGodOneIn,
                    replacedSlots: Set(PackSlotKind.allCasesUsedByStandardRecipes)
                )
            )
        default:
            break
        }
        return recipe
    }

    /// Fixed Energy positions observed in English Wizards-era packs.
    static let wotcEnergyCardsPerPack: [String: Int] = [
        "base1": 2,
        "base4": 2,
        "gym1": 1,
        "gym2": 1,
        "neo1": 1,
    ]

    /// 번호 없는 기본 에너지가 일반 에너지 한 장과 별개로 reverse 슬롯에도 들어갈 수 있는
    /// 영문 스페셜 세트. 제조사 봉입률은 공개되지 않아 추첨은 1/9 시뮬레이터 값이다.
    static let reverseSlotEnergyFinish: [String: CardFinish] = [
        "sm35": .reverseHolo,
        "sm75": .reverseHolo,
        "sm115": .reverseHolo,
        "swsh35": .reverseHolo,
        "swsh12pt5": .reverseHolo,
        "sv3pt5": .holo,          // 151 Cosmos Holo
        "sv6pt5": .reverseHolo,   // Shrouded Fable patterned reverse
    ]

    static func estimatedReverseSlotEnergyOneIn(setID: String) -> Int {
        setID == "sv3pt5" ? 3 : 9
    }

    // MARK: English Radiant Collection sheets

    /// Bulbapedia confirms 8 core + 2 RC cards in every Generations pack.
    /// Sheet reconstruction from an uncut sheet gives 72 Uncommon positions
    /// and 28 Ultra Rare positions on the second RC sheet.
    static let generationsRadiantCommonIDs: [String] = [
        "g1-RC1", "g1-RC2", "g1-RC3", "g1-RC4", "g1-RC7", "g1-RC9",
        "g1-RC11", "g1-RC12", "g1-RC14", "g1-RC17", "g1-RC23",
        "g1-RC25", "g1-RC26",
    ]

    static let generationsRadiantUncommonIDs: [String] = [
        "g1-RC5", "g1-RC8", "g1-RC10", "g1-RC13", "g1-RC15", "g1-RC16",
        "g1-RC18", "g1-RC19", "g1-RC20", "g1-RC22", "g1-RC24", "g1-RC27",
    ]

    static let generationsRadiantUltraIDs: [String] = [
        "g1-RC6", "g1-RC21", "g1-RC28", "g1-RC29", "g1-RC30", "g1-RC31",
        "g1-RC32",
    ]

    /// Legendary Treasures uses the same guaranteed two-sheet arrangement:
    /// one RC Common plus one RC Uncommon/Ultra Rare. The high-sheet model is
    /// 70% Uncommon and 30% Ultra Rare.
    static let legendaryTreasuresRadiantCommonIDs: [String] = [
        "bw11-RC1", "bw11-RC2", "bw11-RC5", "bw11-RC8", "bw11-RC9",
        "bw11-RC15", "bw11-RC16", "bw11-RC17", "bw11-RC18", "bw11-RC20",
    ]

    static let legendaryTreasuresRadiantUncommonIDs: [String] = [
        "bw11-RC3", "bw11-RC4", "bw11-RC6", "bw11-RC7", "bw11-RC10",
        "bw11-RC12", "bw11-RC13", "bw11-RC14", "bw11-RC19",
    ]

    static let legendaryTreasuresRadiantUltraIDs: [String] = [
        "bw11-RC11", "bw11-RC21", "bw11-RC22", "bw11-RC23", "bw11-RC24",
        "bw11-RC25",
    ]

    /// Only these base-set Holo Rares share Legendary Treasures' special
    /// reverse-or-holo position. Pokémon-EX stay in the independent rare slot.
    static let legendaryTreasuresHoloIDs: [String] = [
        "bw11-8", "bw11-12", "bw11-15", "bw11-16", "bw11-19", "bw11-22",
        "bw11-23", "bw11-27", "bw11-28", "bw11-32", "bw11-39", "bw11-43",
        "bw11-46", "bw11-50", "bw11-51", "bw11-53", "bw11-66", "bw11-68",
        "bw11-72", "bw11-78", "bw11-80", "bw11-84", "bw11-85", "bw11-90",
        "bw11-91", "bw11-93", "bw11-96", "bw11-99", "bw11-105", "bw11-108",
    ]

    static func isRadiantCollectionSet(_ setID: String) -> Bool {
        setID == "g1" || setID == "bw11"
    }

    static func radiantCollectionIDs(setID: String, slot: PackSlotKind,
                                     tier: CardTier) -> [String] {
        switch (setID, slot, tier) {
        case ("g1", .radiantCollectionCommon, .common):
            return generationsRadiantCommonIDs
        case ("g1", .radiantCollectionHigh, .uncommon):
            return generationsRadiantUncommonIDs
        case ("g1", .radiantCollectionHigh, .doubleRare):
            return generationsRadiantUltraIDs.filter { $0 == "g1-RC6" || $0 == "g1-RC21" }
        case ("g1", .radiantCollectionHigh, .superRare):
            return generationsRadiantUltraIDs.filter { $0 != "g1-RC6" && $0 != "g1-RC21" }
        case ("bw11", .radiantCollectionCommon, .common):
            return legendaryTreasuresRadiantCommonIDs
        case ("bw11", .radiantCollectionHigh, .uncommon):
            return legendaryTreasuresRadiantUncommonIDs
        case ("bw11", .radiantCollectionHigh, .rare):
            return ["bw11-RC11"]
        case ("bw11", .radiantCollectionHigh, .superRare):
            return legendaryTreasuresRadiantUltraIDs.filter { $0 != "bw11-RC11" }
        default:
            return []
        }
    }

    static func standard(for era: PackEra) -> PackRecipe {
        let slots: [PackRecipeSlot]
        let energyCards: Int
        let codeCards: Int

        switch era {
        case .wotc:
            slots = [
                PackRecipeSlot(kind: .common, count: 7),
                PackRecipeSlot(kind: .uncommon, count: 3),
                PackRecipeSlot(kind: .rare, count: 1),
            ]
            energyCards = 0
            codeCards = 0
        case .ex:
            slots = [
                PackRecipeSlot(kind: .common, count: 5),
                PackRecipeSlot(kind: .uncommon, count: 2),
                PackRecipeSlot(kind: .reverseHolo, count: 1),
                PackRecipeSlot(kind: .rare, count: 1),
            ]
            energyCards = 0
            codeCards = 0
        case .diamondPearl:
            slots = [
                PackRecipeSlot(kind: .common, count: 5),
                PackRecipeSlot(kind: .uncommon, count: 3),
                PackRecipeSlot(kind: .reverseHolo, count: 1),
                PackRecipeSlot(kind: .rare, count: 1),
            ]
            energyCards = 0
            codeCards = 0
        case .blackWhite:
            slots = [
                PackRecipeSlot(kind: .common, count: 5),
                PackRecipeSlot(kind: .uncommon, count: 3),
                PackRecipeSlot(kind: .reverseHolo, count: 1),
                PackRecipeSlot(kind: .rare, count: 1),
            ]
            energyCards = 0
            codeCards = 1
        case .sunMoon, .swordShield:
            slots = [
                PackRecipeSlot(kind: .common, count: 5),
                PackRecipeSlot(kind: .uncommon, count: 3),
                PackRecipeSlot(kind: .reverseHolo, count: 1),
                PackRecipeSlot(kind: .rare, count: 1),
            ]
            energyCards = 1
            codeCards = 1
        case .scarletViolet:
            slots = [
                PackRecipeSlot(kind: .common, count: 4),
                PackRecipeSlot(kind: .uncommon, count: 3),
                PackRecipeSlot(kind: .reverseHolo, count: 1),
                PackRecipeSlot(kind: .reverseHoloHit, count: 1),
                PackRecipeSlot(kind: .rare, count: 1),
            ]
            energyCards = 1
            codeCards = 1
        }

        let gameCards = slots.reduce(0) { $0 + $1.count }
        return PackRecipe(
            slots: slots,
            contents: PackContents(
                gameCardCount: gameCards,
                energyCardCount: energyCards,
                codeCardCount: codeCards
            ),
            baseVariant: .standard,
            specialVariant: nil
        )
    }

    /// Exact English 151 evolution lines that atomically replace the two
    /// reverse positions and the rare position.
    static let scarletViolet151Lines: [[PackCardRequest]] = [
        [
            PackCardRequest(tier: .artRare, exactCardID: "sv3pt5-166"),
            PackCardRequest(tier: .artRare, exactCardID: "sv3pt5-167"),
            PackCardRequest(tier: .specialArtRare, exactCardID: "sv3pt5-198"),
        ],
        [
            PackCardRequest(tier: .artRare, exactCardID: "sv3pt5-168"),
            PackCardRequest(tier: .artRare, exactCardID: "sv3pt5-169"),
            PackCardRequest(tier: .specialArtRare, exactCardID: "sv3pt5-199"),
        ],
        [
            PackCardRequest(tier: .artRare, exactCardID: "sv3pt5-170"),
            PackCardRequest(tier: .artRare, exactCardID: "sv3pt5-171"),
            PackCardRequest(tier: .specialArtRare, exactCardID: "sv3pt5-200"),
        ],
    ]

    /// Exact ten-card Prismatic Evolutions English God Pack. The Common Eevee
    /// is specifically its Master Ball parallel; the other nine are SIRs.
    static let prismaticEvolutionsGodPack: [PackCardRequest] = [
        PackCardRequest(tier: .common, exactCardID: "sv8pt5-74", finishHint: .masterBallParallel),
        PackCardRequest(tier: .specialArtRare, exactCardID: "sv8pt5-167"),
        PackCardRequest(tier: .specialArtRare, exactCardID: "sv8pt5-144"),
        PackCardRequest(tier: .specialArtRare, exactCardID: "sv8pt5-146"),
        PackCardRequest(tier: .specialArtRare, exactCardID: "sv8pt5-149"),
        PackCardRequest(tier: .specialArtRare, exactCardID: "sv8pt5-150"),
        PackCardRequest(tier: .specialArtRare, exactCardID: "sv8pt5-153"),
        PackCardRequest(tier: .specialArtRare, exactCardID: "sv8pt5-155"),
        PackCardRequest(tier: .specialArtRare, exactCardID: "sv8pt5-156"),
        PackCardRequest(tier: .specialArtRare, exactCardID: "sv8pt5-161"),
    ]

    /// Black Bolt and White Flare share the same English God Pack shape. These
    /// requests stay set-relative: drawing resolves nine different IRs and one
    /// SIR from whichever set pool was opened, so the split sets never mix.
    static let blackBoltWhiteFlareGodPack: [PackCardRequest] =
        Array(repeating: PackCardRequest(tier: .artRare), count: 9)
        + [PackCardRequest(tier: .specialArtRare)]

    /// Confirmed English Ascended Heroes God Pack shape. Cards are selected
    /// without replacement from this expansion's own pools.
    static let ascendedHeroesGodPack: [PackCardRequest] =
        Array(repeating: PackCardRequest(tier: .megaAttack), count: 3)
        + Array(repeating: PackCardRequest(tier: .specialArtRare), count: 7)
}
