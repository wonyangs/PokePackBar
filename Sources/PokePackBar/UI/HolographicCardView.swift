import AppKit
import SwiftUI

// MARK: - Physical finish optics

/// Optical strength derived from a physical finish, never directly from rarity.
struct HoloProfile: Equatable {
    var tilt: Double
    var specular: Double
    var foil: Double
    var glare: Double
    var sparkle: Double
    var edge: Double

    static let minTilt = 5.5
    static let maxTilt = 7.2

    static func of(_ finish: CardFinish) -> HoloProfile {
        of(finish.foilSpec)
    }

    static func of(_ spec: FoilSpec) -> HoloProfile {
        let intensity = min(1, max(0, spec.intensity))
        let response = opticalResponse(for: spec.pattern)
        let sparkle: Double = switch spec.pattern {
        case .starlight, .cosmos, .fireworks, .pokeBallStars, .crackedIce,
             .refractor, .celebrationSheen, .starSheen, .starfield:
            0.16 + intensity * 0.24
        case .masterBall, .scarletVioletTiles, .futuristic:
            0.12 + intensity * 0.18
        case .specialIllustration:
            // Dense micro-grain belongs to the card-locked SIR texture below.
            // Reusing the generic large sparkle sprites reads as glitter dust.
            0
        case .none, .tinsel, .sheen, .waterWeb, .verticalLine, .mirage,
             .reverse, .mirror, .energySymbols, .energyTypeStamp,
             .energyPokeBallStamp, .energySetStamp, .pokeBallStamp, .rocketStamp,
             .pinwheel, .pokeBall3D, .stampedMirror, .cosmosStamp, .subjectStamp,
             .typeSymbols,
             .sunMoonSymbols, .swordShieldTiles, .splitTypeSymbols, .satin, .vmaxRays,
             .stone, .prime, .legend, .aceDiamond, .spectrum, .line, .rainbowSplash,
             .rainbow, .gold, .bwGold, .xyGold, .sunMoonGold, .swordShieldGold,
             .scarletVioletGold, .teraGold, .shinyGX, .shinyV, .shinyVMAX,
             .shinyEx, .teraShinyEx, .crosshatch,
             .magenta, .pokeBall, .breakGrid, .megaGold,
             .confetti, .monochrome, .blackEtched, .whiteEtched, .comicBurst,
             .doubleRareSheen, .teraSheen, .vstarSheen:
            0
        }

        // SIR has a high-energy pearlescent return, but it is confined to a
        // moving band. Give that dedicated material more local headroom while
        // retaining the conservative cap for broad generic overlays.
        let foilCap = spec.pattern == .specialIllustration ? 0.72 : 0.55
        let foil = min(foilCap, (0.24 + 0.24 * intensity) * response.patternGain)
        let specular = spec.isFoil
            ? 0.045 + 0.045 * intensity * response.specularGain
            : 0.055
        let glare = spec.isFoil
            ? min(0.12, (0.025 + 0.055 * intensity) * response.glareGain)
            : 0.020

        return HoloProfile(
            tilt: minTilt + (maxTilt - minTilt) * intensity,
            specular: specular,
            foil: spec.isFoil ? foil : 0,
            glare: glare,
            sparkle: sparkle,
            edge: spec.border == .paper ? 0.10 : 0.16 + 0.18 * intensity)
    }

    private struct OpticalResponse {
        let patternGain: Double
        let specularGain: Double
        let glareGain: Double
    }

    /// Different foil sheets share one light source, not one material. These
    /// gains keep their optical behavior distinct without raising white glare.
    private static func opticalResponse(for pattern: FoilPattern) -> OpticalResponse {
        switch pattern {
        case .none:
            return OpticalResponse(patternGain: 0, specularGain: 0.7, glareGain: 0.4)
        case .mirror, .stampedMirror, .cosmosStamp, .subjectStamp,
             .crackedIce, .refractor:
            return OpticalResponse(patternGain: 1.08, specularGain: 1.0, glareGain: 0.82)
        case .stone:
            return OpticalResponse(patternGain: 0.70, specularGain: 0.52, glareGain: 0.28)
        case .satin, .celebrationSheen:
            return OpticalResponse(patternGain: 0.82, specularGain: 0.66, glareGain: 0.42)
        case .specialIllustration:
            // High pattern gain and deliberately low white-light gains keep
            // the embossed SIR layer vivid without washing out its artwork.
            return OpticalResponse(patternGain: 1.28, specularGain: 0.60, glareGain: 0.24)
        case .gold, .bwGold, .xyGold, .sunMoonGold, .swordShieldGold,
             .scarletVioletGold, .teraGold, .megaGold, .monochrome,
             .blackEtched, .whiteEtched:
            return OpticalResponse(patternGain: 0.94, specularGain: 0.72, glareGain: 0.42)
        case .tinsel, .sheen, .waterWeb, .verticalLine, .mirage, .reverse,
             .energySymbols, .energyTypeStamp, .energyPokeBallStamp,
             .energySetStamp, .pokeBallStamp, .rocketStamp, .pinwheel,
             .pokeBall3D, .typeSymbols, .sunMoonSymbols, .swordShieldTiles,
             .scarletVioletTiles, .splitTypeSymbols, .prime, .legend,
             .aceDiamond, .starSheen, .doubleRareSheen, .teraSheen, .vstarSheen,
             .vmaxRays, .line, .crosshatch, .shinyGX, .shinyV, .shinyVMAX,
             .shinyEx, .teraShinyEx,
             .breakGrid, .futuristic:
            return OpticalResponse(patternGain: 1.04, specularGain: 0.78, glareGain: 0.56)
        case .starlight, .cosmos, .fireworks, .pokeBallStars, .starfield,
             .pokeBall, .masterBall, .confetti:
            return OpticalResponse(patternGain: 1.0, specularGain: 0.84, glareGain: 0.58)
        case .spectrum, .rainbowSplash, .rainbow, .magenta, .comicBurst:
            return OpticalResponse(patternGain: 0.94, specularGain: 0.70, glareGain: 0.44)
        }
    }

    /// Compatibility for callers that only have old metadata. In particular a
    /// plain `.rare` resolves to normal paper rather than becoming foil merely
    /// because it is rare.
    static func of(_ tier: CardTier) -> HoloProfile {
        let resolved = CardFinishResolver.resolve(
            setID: "", originalRarity: nil, tier: tier)
        return of(resolved.spec)
    }
}

// MARK: - Fixed-light optics

enum HoloOptics {
    static let restOffset = (x: -0.13, y: -0.18)
    static let bandAxis = (x: 0.964, y: 0.265)
    static let referenceTilt = 7.0
    static let highlightTravel = 0.36
    static let bandRest = 0.42
    // A narrow specular band must visibly cross the card even at the compact
    // in-app size. This range still keeps the band on-card at the pointer
    // extremes while preventing a tilted card from looking like a static tint.
    static let bandTravel = 0.42

    static func highlight(nx: Double, ny: Double, tilt: Double) -> CGPoint {
        let gain = highlightTravel * tilt / referenceTilt
        return CGPoint(x: 0.5 + restOffset.x - nx * gain,
                       y: 0.5 + restOffset.y - ny * gain)
    }

    static func bandPosition(nx: Double, ny: Double, tilt: Double) -> Double {
        let along = nx * bandAxis.x + ny * bandAxis.y
        let position = bandRest - along * bandTravel * tilt / referenceTilt
        return min(0.87, max(0.13, position))
    }
}

// MARK: - Pointer tilt

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

    var magnitude: Double { min(1, length) }

    private var length: Double { (nx * nx + ny * ny).squareRoot() }

    var axis: (x: CGFloat, y: CGFloat, z: CGFloat) {
        let l = length
        guard l > 0.0001 else { return (x: 0, y: 1, z: 0) }
        return (x: CGFloat(-ny / l), y: CGFloat(nx / l), z: 0)
    }
}

extension View {
    /// 마우스 기울기만큼 카드 몸체를 기울인다. 앞면과 그 뒤의 등급 빛이 같은 각도로 기울어야
    /// 둘이 어긋나지 않아, 한 곳에서 정한다.
    func holoTilt(_ tilt: TiltVector, spec: FoilSpec) -> some View {
        rotation3DEffect(.degrees(tilt.magnitude * HoloProfile.of(spec).tilt),
                         axis: tilt.axis, perspective: 0.55)
    }
}

/// Pure interaction policy so reduced-motion behavior can be verified without
/// mounting a SwiftUI view.
enum HoloInteraction {
    static func effectiveTilt(pointer: TiltVector, reduceMotion: Bool) -> TiltVector {
        reduceMotion ? .zero : pointer
    }
}

// MARK: - Card view

/// A single enlarged card with a finish-specific optical treatment.
///
/// This remains deliberately limited to the detail view: Canvas textures are
/// inappropriate for a scrolling card grid and are only useful at this size.
@MainActor
struct HolographicCardView: View {
    let cardID: String
    let tier: CardTier
    let explicitFinish: CardFinish?
    let explicitSetID: String?
    let explicitRarity: String?
    var width: CGFloat
    var dimmed: Bool
    var preloaded: NSImage?
    /// 끌어서 돌려 볼 수 있는지. 들여다보는 자리(카드 상세, 온라인 카드 창)에서만 켠다.
    /// 팩 개봉 화면은 밀어서 뜯기와 끌어서 엿보기가 이미 드래그를 쓴다.
    var spinnable: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.valueAwareGlow) private var valueAwareGlow
    @State private var pointerTilt = TiltVector.zero
    @State private var pendingPointerTilt: TiltVector?
    @State private var hoverUpdateScheduled = false
    @State private var spin = CardSpin.rest
    /// 끌기를 시작할 때의 자세. 끄는 중이 아니면 nil 이다.
    @State private var dragOrigin: CardSpin?
    @State private var clicks = CardClickClock()

    private var height: CGFloat { (width / 0.717).rounded() }

    /// Source-compatible initializer for existing callers. Finish metadata is
    /// recovered from the bundled card index when possible.
    init(cardID: String, tier: CardTier, width: CGFloat = 200,
         dimmed: Bool = false, preloaded: NSImage? = nil, spinnable: Bool = false) {
        self.cardID = cardID
        self.tier = tier
        self.explicitFinish = nil
        self.explicitSetID = nil
        self.explicitRarity = nil
        self.width = width
        self.dimmed = dimmed
        self.preloaded = preloaded
        self.spinnable = spinnable
    }

    /// Printing-aware initializer for pulled variants.
    init(cardID: String, tier: CardTier, finish: CardFinish,
         setID: String? = nil, originalRarity: String? = nil,
         width: CGFloat = 200, dimmed: Bool = false, preloaded: NSImage? = nil,
         spinnable: Bool = false) {
        self.cardID = cardID
        self.tier = tier
        self.explicitFinish = finish
        self.explicitSetID = setID
        self.explicitRarity = originalRarity
        self.width = width
        self.dimmed = dimmed
        self.preloaded = preloaded
        self.spinnable = spinnable
    }

    var body: some View {
        let resolved = resolvedFinish
        let tilt = HoloInteraction.effectiveTilt(
            pointer: pointerTilt, reduceMotion: reduceMotion)

        let visualKind = CardIndex.shared?.card(cardID)?.visualKind
        Group {
            if spinnable {
                // 등급 빛과 그림자는 무대가 그린다. 앞면 안에 두면 카드와 함께 눌려 옆으로 설 때
                // 두꺼운 띠처럼 보였다.
                CardSpinStage(spin: spin, pointerTilt: dragOrigin == nil ? tilt : .zero,
                              width: width, height: height,
                              glow: { pose in
                                  if !dimmed {
                                      TierGlow(tier: tier, width: width,
                                               valueCard: valueAwareGlow
                                                  ? PulledCard(id: cardID, tier: tier, isNew: false, finish: resolved.finish)
                                                  : nil)
                                          .holoTilt(pose, spec: resolved.spec)
                                  }
                              }) { light, pose in
                    HoloCardBody(cardID: cardID, tier: tier, finish: resolved.finish,
                                 spec: resolved.spec, width: width, height: height,
                                 dimmed: dimmed, preloaded: preloaded,
                                 visualKind: visualKind, tilt: light, pose: pose, onSlab: true)
                }
            } else {
                HoloCardBody(cardID: cardID, tier: tier, finish: resolved.finish,
                             spec: resolved.spec, width: width, height: height,
                             dimmed: dimmed, preloaded: preloaded,
                             visualKind: visualKind, tilt: tilt)
            }
        }
            .frame(width: width, height: height)
            .contentShape(Rectangle())
            .gesture(spinGesture, including: spinnable ? .all : .subviews)
            .onContinuousHover(coordinateSpace: .local) { phase in
                guard !reduceMotion else {
                    pointerTilt = .zero
                    return
                }

                switch phase {
                case .active(let point):
                    let next = TiltVector(point: point,
                                          in: CGSize(width: width, height: height))
                    schedulePointerTilt(next)
                case .ended:
                    pendingPointerTilt = nil
                    withAnimation(.easeOut(duration: 0.12)) { pointerTilt = .zero }
                }
            }
            .onChange(of: cardID) {
                pendingPointerTilt = nil
                pointerTilt = .zero
                dragOrigin = nil
                spin = .rest
            }
            .onChange(of: reduceMotion) {
                if reduceMotion {
                    pendingPointerTilt = nil
                    pointerTilt = .zero
                }
            }
    }

    /// 끄는 대로 돌고, 놓으면 던진 속도만큼 더 돌다가 가까운 앞면이나 뒷면에 멈춘다.
    /// 동작 줄이기를 켰으면 관성 없이 놓은 자리에서 가까운 면으로 바로 선다.
    ///
    /// 두 번 누르면 가장 가까운 앞면으로 돌아온다. 두 번 누르기를 따로 붙이면 macOS 가 그 판정을
    /// 기다리느라 끌기가 늦게 잡혀, 같은 제스처 안에서 「거의 움직이지 않고 뗀 것」을 클릭으로 센다.
    private var spinGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                let origin: CardSpin
                if let dragOrigin {
                    origin = dragOrigin
                } else {
                    // 3pt 넘게 움직여야 끌기로 본다. 그 전에는 클릭일 수 있다.
                    guard hypot(value.translation.width, value.translation.height) >= 3 else { return }
                    origin = spin
                }
                follow(from: origin, to: origin.turned(by: value.translation, width: width))
            }
            .onEnded { value in
                guard let origin = dragOrigin else {
                    let now = Date()
                    if let last = clicks.lastClick, now.timeIntervalSince(last) < NSEvent.doubleClickInterval {
                        clicks.lastClick = nil
                        settle(at: spin.front)
                    } else {
                        clicks.lastClick = now
                    }
                    return
                }
                let thrown = reduceMotion ? value.translation : value.predictedEndTranslation
                settle(at: origin.turned(by: thrown, width: width).settled)
            }
    }

    /// 끌기를 끝내는 것(`dragOrigin`)도 같은 애니메이션 안에서 바꾼다. 그래야 마우스 기울기가
    /// 카드가 정면으로 돌아오는 만큼 스며들고, 놓는 순간 튀지 않는다.
    private func settle(at target: CardSpin) {
        if reduceMotion {
            dragOrigin = nil
            spin = target
        } else {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.82)) {
                dragOrigin = nil
                spin = target
            }
        }
    }

    /// 끄는 동안은 짧은 스프링이 손을 따라간다. 마우스 이벤트는 화면 주사율과 어긋나게 들어와서,
    /// 받은 값을 그대로 넣거나 타이머로 모아 넣으면 어떤 프레임은 건너뛰고 어떤 프레임은 크게 뛴다.
    /// 스프링은 매 프레임 그 사이를 메우고, 새 값이 오면 속도를 이어 받아 목표만 바꾼다.
    /// 이벤트가 한 프레임에 여럿 와도 그리는 것은 프레임마다 한 번이다. 끌기 시작(`dragOrigin`)도
    /// 같은 스프링 안에서 바꿔, 마우스 기울기가 한 번에 빠지지 않고 스르르 풀린다.
    private func follow(from origin: CardSpin, to next: CardSpin) {
        if reduceMotion {
            dragOrigin = origin
            spin = next
        } else {
            withAnimation(.interactiveSpring(response: 0.14, dampingFraction: 0.86)) {
                dragOrigin = origin
                spin = next
            }
        }
    }

    /// 연속 hover 이벤트마다 0.12초 애니메이션을 새로 쌓으면 수십 개의 Canvas·mask가 같은 프레임에
    /// 반복 평가된다. 마지막 포인터 위치만 보관해 디스플레이 한 프레임당 최대 한 번 반영하고,
    /// 카드가 원위치로 돌아갈 때만 애니메이션을 쓴다.
    private func schedulePointerTilt(_ next: TiltVector) {
        pendingPointerTilt = next
        guard !hoverUpdateScheduled else { return }
        hoverUpdateScheduled = true
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(16))
            if let pendingPointerTilt {
                pointerTilt = pendingPointerTilt
                self.pendingPointerTilt = nil
            }
            hoverUpdateScheduled = false
        }
    }

    private var resolvedFinish: ResolvedCardFinish {
        let indexed = CardIndex.shared?.card(cardID)
        let inferredSetID = cardID.split(separator: "-", maxSplits: 1).first.map(String.init) ?? ""
        return CardFinishResolver.resolve(
            cardID: cardID,
            setID: explicitSetID ?? indexed?.setID ?? inferredSetID,
            originalRarity: explicitRarity ?? indexed?.rarity,
            tier: tier,
            visualKind: indexed?.visualKind,
            explicitFinish: explicitFinish)
    }
}

// MARK: - Deterministic visual diagnostics

/// 실제 상세 카드 렌더러를 고정 기울기로 출력한다. 포인터 위치와 캡처 타이밍에 따라 결과가
/// 달라지는 수동 스크린샷 대신, 같은 카드와 같은 빛 조건을 반복 비교하기 위한 내부 도구다.
@MainActor
enum HoloVisualDiagnostics {
    struct Request {
        let cardID: String
        let outputDirectory: URL
        let finish: CardFinish?
        let compact: Bool
        let actualSize: Bool
        let flatCard: Bool
        let sweep: Bool
        var geometry: Bool = false
        var visibility: Bool = false
        /// 끌어서 돌린 자세들(앞면, 옆으로 서기 직전과 직후, 뒷면, 위아래 기울기).
        var spin: Bool = false
    }

    enum Failure: LocalizedError {
        case malformedArguments
        case unknownCard(String)
        case missingImage(String)
        case renderingFailed(String)

        var errorDescription: String? {
            switch self {
            case .malformedArguments:
                "Usage: --render-holo-preview <card-id> <output-directory> [finish] [--compact] [--actual-size] [--flat-card] [--sweep] [--spin]"
            case .unknownCard(let cardID):
                "Not in the card index: \(cardID)"
            case .missingImage(let cardID):
                "Could not read the card image: \(cardID)"
            case .renderingFailed(let name):
                "PNG rendering failed: \(name)"
            }
        }
    }

    private struct Pose {
        let name: String
        let tilt: TiltVector
    }

    private static let poses = [
        Pose(name: "rest", tilt: .zero),
        Pose(name: "left", tilt: TiltVector(nx: -0.88, ny: 0.02)),
        Pose(name: "right", tilt: TiltVector(nx: 0.88, ny: -0.02)),
        Pose(name: "up", tilt: TiltVector(nx: 0.02, ny: -0.88)),
        Pose(name: "down", tilt: TiltVector(nx: -0.02, ny: 0.88)),
        Pose(name: "diagonal", tilt: TiltVector(nx: 0.68, ny: -0.68)),
    ]

    static func request(from arguments: [String]) -> Request? {
        guard let flag = arguments.firstIndex(of: "--render-holo-preview") else { return nil }
        guard arguments.indices.contains(flag + 2) else {
            return Request(cardID: "", outputDirectory: URL(fileURLWithPath: ""),
                           finish: nil, compact: false, actualSize: false,
                           flatCard: false, sweep: false)
        }
        let options = arguments.indices.contains(flag + 3)
            ? Array(arguments[(flag + 3)...])
            : []
        let finish = options.compactMap(CardFinish.init(rawValue:)).first
        return Request(cardID: arguments[flag + 1],
                       outputDirectory: URL(fileURLWithPath: arguments[flag + 2],
                                            isDirectory: true),
                       finish: finish,
                       compact: options.contains("--compact"),
                       actualSize: options.contains("--actual-size"),
                       flatCard: options.contains("--flat-card"),
                       sweep: options.contains("--sweep"),
                       geometry: options.contains("--geometry"),
                       visibility: options.contains("--visibility"),
                       spin: options.contains("--spin"))
    }

    static func render(_ request: Request) async throws -> [URL] {
        guard !request.cardID.isEmpty, !request.outputDirectory.path.isEmpty else {
            throw Failure.malformedArguments
        }
        guard let card = CardIndex.shared?.card(request.cardID) else {
            throw Failure.unknownCard(request.cardID)
        }
        guard let image = await CardImageLoader.image(cardID: request.cardID, hires: true) else {
            throw Failure.missingImage(request.cardID)
        }

        let resolved = CardFinishResolver.resolve(
            cardID: card.id,
            setID: card.setID,
            originalRarity: card.rarity,
            tier: card.tier,
            visualKind: card.visualKind,
            explicitFinish: request.finish)
        let sheet = FoilSheetMaterial(pattern: resolved.spec.pattern, cardID: card.id)
        if [.artBackground, .artSubject, .artSubjectAndBorder].contains(resolved.spec.coverage)
            || sheet == .cosmos || sheet == .goldStar {
            let bounds = FoilCoverageMask(coverage: resolved.spec.coverage, cardID: card.id)
                .artRect(in: CGSize(width: 1, height: 1))
            _ = await ArtworkMaskCache.prepare(cardID: card.id, source: image, art: bounds)
        }
        try FileManager.default.createDirectory(at: request.outputDirectory,
                                                withIntermediateDirectories: true)

        // The app presents these cards at roughly 230–260 pt. Geometry in a
        // 420 pt preview can hide weak small-card light response, so keep an
        // option that renders the same optics at the real interaction size.
        let cardWidth: CGFloat = request.actualSize ? 240 : 420
        let cardHeight = (cardWidth / 0.717).rounded()
        var files: [URL] = []
        if request.spin {
            // 멈춘 카드에 마우스를 올린 자세도 함께 본다. 돌리는 카드의 등급 빛이 앞면과 따로
            // 놀면 이 자세에서 가장자리에 선이 드러난다.
            let spins: [(String, CardSpin, TiltVector)] = [
                ("spin-000", .rest, .zero), ("spin-030", CardSpin(yaw: 30, pitch: 0), .zero),
                ("spin-085", CardSpin(yaw: 85, pitch: 0), .zero), ("spin-095", CardSpin(yaw: 95, pitch: 0), .zero),
                ("spin-150", CardSpin(yaw: 150, pitch: 0), .zero), ("spin-180", CardSpin(yaw: 180, pitch: 0), .zero),
                ("spin-pitch-down", CardSpin(yaw: 0, pitch: 30), .zero),
                ("spin-pitch-back", CardSpin(yaw: 180, pitch: -30), .zero),
                ("spin-hover-right", .rest, TiltVector(nx: 0.88, ny: -0.02)),
                ("spin-hover-diagonal", .rest, TiltVector(nx: 0.68, ny: -0.68)),
            ]
            for (name, spin, pointer) in spins {
                let view = ZStack {
                    Color(red: 0.055, green: 0.06, blue: 0.075)
                    CardSpinStage(spin: spin, pointerTilt: pointer, width: cardWidth, height: cardHeight,
                                  glow: { pose in
                                      TierGlow(tier: card.tier, width: cardWidth, startBloomed: true)
                                          .holoTilt(pose, spec: resolved.spec)
                                  }) { light, pose in
                        HoloCardBody(cardID: card.id, tier: card.tier,
                                     finish: resolved.finish, spec: resolved.spec,
                                     width: cardWidth, height: cardHeight,
                                     dimmed: false, preloaded: image,
                                     visualKind: card.visualKind, tilt: light, pose: pose, onSlab: true)
                    }
                    .frame(width: cardWidth, height: cardHeight)
                }
                .frame(width: cardWidth + 120, height: cardHeight + 120)
                let renderer = ImageRenderer(content: view)
                renderer.scale = 2
                guard let rendered = renderer.nsImage, let tiff = rendered.tiffRepresentation,
                      let bitmap = NSBitmapImageRep(data: tiff),
                      let png = bitmap.representation(using: .png, properties: [:]) else {
                    throw Failure.renderingFailed(name)
                }
                let file = request.outputDirectory.appendingPathComponent("\(card.id)-\(name).png")
                try png.write(to: file, options: .atomic)
                files.append(file)
            }
            return files
        }
        let selectedPoses: [Pose]
        if request.visibility {
            selectedPoses = [poses[0],
                Pose(name: "near-left", tilt: TiltVector(nx: -0.28, ny: 0)),
                Pose(name: "near-right", tilt: TiltVector(nx: 0.28, ny: 0)),
                Pose(name: "near-up", tilt: TiltVector(nx: 0, ny: -0.28)),
                Pose(name: "near-down", tilt: TiltVector(nx: 0, ny: 0.28)),
            ] + Array(poses.dropFirst())
        } else if request.sweep {
            selectedPoses = (0..<36).map { frame in
                let phase = Double(frame) / 36 * .pi * 2
                return Pose(name: String(format: "sweep-%02d", frame),
                            tilt: TiltVector(nx: sin(phase) * 0.88,
                                             ny: cos(phase) * 0.55))
            }
        } else {
            selectedPoses = request.compact ? [poses[0], poses[5]] : poses
        }
        for pose in selectedPoses {
            let view = ZStack {
                Color(red: 0.055, green: 0.06, blue: 0.075)
                if request.geometry {
                    CardImageView(cardID: card.id, hires: true, width: cardWidth, preloaded: image,
                        imageOverlay: { source in
                            AnyView(Group {
                                if resolved.spec.treatment == .classic30 {
                                    Color.pink.opacity(0.60).mask { ClassicGoldMask(cardID: card.id) }
                                } else {
                                    Color.pink.opacity(0.52).mask {
                                        FoilCoverageMask(coverage: resolved.spec.coverage, cardID: card.id, preloaded: source)
                                    }
                                }
                            })
                        })
                } else {
                HoloCardBody(cardID: card.id, tier: card.tier,
                             finish: resolved.finish, spec: resolved.spec,
                             width: cardWidth, height: cardHeight,
                             dimmed: false, preloaded: image,
                             visualKind: card.visualKind, tilt: pose.tilt,
                             flatCard: request.flatCard)
                    .frame(width: cardWidth, height: cardHeight)
                }
            }
            .frame(width: cardWidth + 120, height: cardHeight + 120)

            let renderer = ImageRenderer(content: view)
            renderer.scale = 2
            guard let rendered = renderer.nsImage,
                  let tiff = rendered.tiffRepresentation,
                  let bitmap = NSBitmapImageRep(data: tiff),
                  let png = bitmap.representation(using: .png, properties: [:]) else {
                throw Failure.renderingFailed(pose.name)
            }
            let suffix = (request.finish.map { "-\($0.rawValue)" } ?? "") + (request.geometry ? "-geometry" : "")
            let file = request.outputDirectory
                .appendingPathComponent("\(card.id)\(suffix)-\(pose.name).png")
            try png.write(to: file, options: .atomic)
            files.append(file)
        }
        return files
    }
}

@MainActor
struct HoloCardBody: View, @MainActor Animatable {
    @Environment(\.valueAwareGlow) private var valueAwareGlow
    let cardID: String
    let tier: CardTier
    let finish: CardFinish
    let spec: FoilSpec
    let width: CGFloat
    let height: CGFloat
    let dimmed: Bool
    let preloaded: NSImage?
    let visualKind: CardVisualKind?
    var tilt: TiltVector
    var flatCard: Bool = false
    /// 몸체를 기울일 기울기. 없으면 `tilt` 를 쓴다. 돌리는 카드는 빛만 크게 옮기고 몸체는
    /// 두께 상자와 같은 판에 둬야 해서 따로 받는다.
    var pose: TiltVector? = nil
    /// 두께 있는 카드(`CardSpinStage`)의 앞면으로 그린다. 등급 빛과 그림자는 무대가 그린다.
    var onSlab: Bool = false

    nonisolated var animatableData: AnimatablePair<Double, Double> {
        get { AnimatablePair(tilt.nx, tilt.ny) }
        set { tilt = TiltVector(nx: newValue.first, ny: newValue.second) }
    }

    private var corner: CGFloat { width * 0.05 }

    var body: some View {
        let profile = HoloProfile.of(spec)
        let highlight = HoloOptics.highlight(
            nx: tilt.nx, ny: tilt.ny, tilt: profile.tilt)
        let band = HoloOptics.bandPosition(
            nx: tilt.nx, ny: tilt.ny, tilt: profile.tilt)
        let posed = pose ?? tilt

        ZStack {
            // 아직 없는 카드는 빛나지 않는다. 회색 카드 뒤에서 등급 빛만 켜져 있으면
            // 도감을 훑을 때 백라이트처럼 보이고, 빛이 「뽑았다」는 신호로 읽히지 않는다.
            if !dimmed && !onSlab {
                TierGlow(tier: tier, width: width,
                         valueCard: valueAwareGlow
                            ? PulledCard(id: cardID, tier: tier, isNew: false, finish: finish) : nil)
            }
            CardImageView(cardID: cardID, hires: true, width: width,
                          dimmed: dimmed, preloaded: preloaded,
                          imageOverlay: { displayedImage in
                    AnyView(Group {
                      if !dimmed {
                        finishLayers(profile: profile, highlight: highlight, band: band, source: displayedImage)
                            .clipShape(RoundedRectangle(cornerRadius: corner))
                            .allowsHitTesting(false)
                            .accessibilityHidden(true)
                      }
                    })
                })
                .compositingGroup()
                .shadow(color: onSlab ? .clear : .black.opacity(0.3), radius: width * 0.045,
                        x: flatCard ? 0 : -posed.nx * width * 0.018,
                        y: width * 0.022 - (flatCard ? 0 : posed.ny * width * 0.012))
        }
        .holoTilt(flatCard ? .zero : posed, spec: spec)
    }

    @ViewBuilder
    private func finishLayers(profile: HoloProfile, highlight: CGPoint,
                              band: Double, source: NSImage) -> some View {
        let center = UnitPoint(x: highlight.x, y: highlight.y)
        let sourcePosition = FoilAreaLighting.source(nx: tilt.nx, ny: tilt.ny)
        let surfaceSource = UnitPoint(x: sourcePosition.x, y: sourcePosition.y)
        let whiteLight = 0.60 + 0.14 * tilt.magnitude
        let patternLight = 0.68 + 0.32 * tilt.magnitude
        let glareLight = 0.54 + 0.14 * tilt.magnitude
        let sparkleLight = 0.60 + 0.40 * tilt.magnitude

        ZStack {
            // Coated paper reflection applies to every card, including normal rares.
            RadialGradient(stops: [
                .init(color: .white.opacity(0.34), location: 0),
                .init(color: .white.opacity(0.08), location: 0.42),
                .init(color: .clear, location: 1),
            ], center: surfaceSource, startRadius: 0, endRadius: width * 2.5)
            .blendMode(.screen)
            .opacity(ReviewedFoilProfiles.entry(cardID: cardID, finish: finish) == nil
                && !(spec.pattern == .crackedIce && RegisteredCrackedIce.entries[cardID] != nil)
                ? profile.specular * whiteLight * (spec.pattern == .doubleRareSheen ? 0.25 : 1) : 0)

            if spec.isFoil {
                if let reviewed = ReviewedFoilProfiles.entry(cardID: cardID, finish: finish) {
                    if !reviewed.baseInclude.isEmpty, let treatment = spec.treatment {
                        // Preserve unresolved areas, not the obsolete rim/logo.
                        // A missing photographic angle is not proof of no foil.
                        ExpansionFoilLayer(treatment: treatment, cardID: cardID, source: source,
                            visualKind: visualKind, tilt: tilt,
                            seed: Self.seed(for: "\(cardID)#\(finish.rawValue)"))
                            .mask(Canvas { context, size in
                                context.clip(to: ReviewedFoilProfiles.path(reviewed.baseInclude, size: size),
                                             style: FillStyle(eoFill: true))
                                var outside = Path(CGRect(origin: .zero, size: size))
                                outside.addPath(ReviewedFoilProfiles.path(reviewed.baseExclude, size: size))
                                context.clip(to: outside, style: FillStyle(eoFill: true))
                                context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(.white))
                            })
                    }
                    ReviewedFoilLayer(profile: reviewed, tilt: tilt,
                        seed: Self.seed(for: "\(cardID)#\(finish.rawValue)"))
                } else if spec.pattern == .crackedIce, let facets = RegisteredCrackedIce.entries[cardID] {
                    RegisteredCrackedIceLayer(entry: facets, tilt: tilt)
                } else if let treatment = spec.treatment {
                    ExpansionFoilLayer(treatment: treatment, cardID: cardID, source: source,
                        visualKind: visualKind, tilt: tilt,
                        seed: Self.seed(for: "\(cardID)#\(finish.rawValue)"))
                } else if spec.pattern == .comicBurst {
                    // Mega Attack is a compound material: the Pokémon relief
                    // and glossy attack-name foil must not share one union
                    // mask or one texture response.
                    MegaAttackMaterialLayer(
                        cardID: cardID,
                        source: source,
                        tilt: tilt,
                        seed: Self.seed(for: "\(cardID)#\(finish.rawValue)"),
                        highlight: highlight,
                        band: band)
                } else {
                    ZStack {
                        FinishPatternLayer(pattern: spec.pattern,
                                           texture: spec.texture,
                                           seed: Self.seed(for: "\(cardID)#\(finish.rawValue)"),
                                           cardID: cardID,
                                           finish: finish,
                                           highlight: highlight,
                                           width: width,
                                           visualKind: visualKind,
                                           preloaded: source,
                                           tilt: tilt)
                            .opacity(FoilSheetMaterial(pattern: spec.pattern, cardID: cardID) != nil || FoilReliefMaterial(pattern: spec.pattern, texture: spec.texture, cardID: cardID) != nil
                                ? 1 : min(0.86, profile.foil * patternLight
                                    * patternResponseBoost))
                        if spec.pattern == .crackedIce
                            && FoilMaterialCatalog.hasBakedCrackedIceScan(cardID) {
                            // The shards are already in the high-resolution
                            // scan. Move a small neutral reflection over them
                            // instead of printing another fake shard lattice.
                            RadialGradient(stops: [
                                .init(color: .white.opacity(0.94), location: 0),
                                .init(color: Color(red: 0.86, green: 0.96, blue: 1.0)
                                    .opacity(0.46), location: 0.38),
                                .init(color: .clear, location: 1),
                            ], center: center, startRadius: 0,
                               endRadius: width * 0.36)
                                .blendMode(.screen)
                                .opacity(0.44 + 0.14 * tilt.magnitude)
                        }
                        if localizedPatternFlash > 0 {
                            LocalizedPatternFlash(
                                pattern: spec.pattern,
                                seed: Self.seed(for: "\(cardID)#\(finish.rawValue)"),
                                cardID: cardID,
                                visualKind: visualKind,
                                coverage: spec.coverage,
                                highlight: highlight,
                                width: width)
                                .blendMode(.normal)
                                .opacity(localizedPatternFlash)
                        }
                        FinishTextureLayer(texture: FoilSheetMaterial(pattern: spec.pattern, cardID: cardID) != nil || FoilReliefMaterial(pattern: spec.pattern, texture: spec.texture, cardID: cardID) != nil
                                           || FoilMaterialCatalog.hasBakedCrackedIceScan(cardID)
                                           ? .none : spec.texture,
                                           seed: Self.seed(for: cardID),
                                           highlight: highlight,
                                           tiltMagnitude: tilt.magnitude,
                                           width: width,
                                           response: min(0.68, (0.28 + spec.intensity * 0.28)
                                               * patternLight * textureResponseBoost),
                                           flashGain: spec.pattern == .specialIllustration
                                               ? 1.0 : (finish == .gold ? 1.60 : 1.95))
                        if spec.pattern == .mirror || spec.pattern == .stampedMirror {
                            // A white scan has no headroom for additive glare.
                            // A narrow neutral return supplies contrast without
                            // inventing etching or brightening the entire face.
                            let returnCenter = min(0.8, max(0.2, 0.5 + tilt.nx * 0.34 - tilt.ny * 0.24))
                            LinearGradient(stops: [
                                .init(color: .clear, location: returnCenter - 0.18),
                                .init(color: Color(white: 0.10).opacity(0.48), location: returnCenter),
                                .init(color: .clear, location: returnCenter + 0.18),
                            ], startPoint: .topLeading, endPoint: .bottomTrailing)
                                .mask { Image(decorative: FoilScanGlintCache.sheetGrain, scale: 1).resizable() }
                        }
                        materialGlare(center: band, highlight: center)
                            .blendMode(.screen)
                            .opacity(spec.pattern == .doubleRareSheen ? 0 : spec.pattern == .mirror || spec.pattern == .stampedMirror || spec.pattern == .magenta
                                ? 0.32 : profile.glare * profile.foil * glareLight)

                        if profile.sparkle > 0 && FoilSheetMaterial(pattern: spec.pattern, cardID: cardID) == nil {
                            SparkleLayer(seed: Self.seed(for: "sparkle#\(cardID)#\(finish.rawValue)"),
                                         count: 28)
                                .mask {
                                    RadialGradient(colors: [.white, .white.opacity(0.25), .clear],
                                                   center: center,
                                                   startRadius: 0, endRadius: width * 0.72)
                                }
                                .blendMode(.screen)
                                .opacity(profile.sparkle * profile.foil * sparkleLight)
                        }
                    }
                    .mask { FoilCoverageMask(coverage: spec.coverage, cardID: cardID, preloaded: source) }

                    // Printed set ink is independent of the moving foil light.
                    EXPrintedStampLayer(cardID: cardID, finish: finish)

                    if showsEXReverseRareAccents {
                        EXReverseRareAccentLayer(
                            cardID: cardID,
                            highlight: highlight,
                            band: band)
                            .blendMode(.plusLighter)
                            .opacity(profile.foil * patternLight * 0.80)
                    }
                }
            }

            RoundedRectangle(cornerRadius: corner)
                .strokeBorder(borderGradient(spec.border, highlight: highlight),
                              lineWidth: max(1, width * borderWidth(spec.border)))
                .blendMode(.screen)
                .opacity(spec.treatment == .classic30 || usesRegisteredSubjectMask
                    || (spec.pattern == .crackedIce && RegisteredCrackedIce.entries[cardID] != nil)
                    || ReviewedFoilProfiles.entry(cardID: cardID, finish: finish) != nil
                    ? 0 : profile.edge * (0.45 + 0.55 * tilt.magnitude))
        }
    }

    private var usesRegisteredSubjectMask: Bool {
        [.artSubject, .artSubjectAndBorder].contains(spec.coverage)
            && FoilSubjectMasks.requiresRegisteredMask(cardID: cardID)
    }

    private var showsEXReverseRareAccents: Bool {
        let sourceSetID = cardID.split(separator: "-", maxSplits: 1)
            .first.map(String.init) ?? ""
        guard finish == .reverseHolo,
              sourceSetID.hasPrefix("ex"),
              let sourceNumber = Int(sourceSetID.dropFirst(2)) else {
            return false
        }
        guard (7...16).contains(sourceNumber) else { return false }

        // Delta Species, Dragon Frontiers, and Power Keepers reserve the
        // gold-name/HP treatment for Holo Rare parallels. Other late EX sets
        // apply it to ordinary Rare parallels as well.
        if [13, 15, 16].contains(sourceNumber) {
            return tier == .doubleRare
        }
        return tier == .rare || tier == .doubleRare
    }

    private var patternResponseBoost: Double {
        switch spec.pattern {
        case .refractor, .prime, .breakGrid, .starSheen:
            1.80
        case .specialIllustration:
            1.34
        case .megaGold:
            1.42
        case .crosshatch:
            1.62
        case .energySetStamp:
            // Team Rocket Returns uses a sparse energy/set-name carrier.
            // Raise only that fixed motif, not the art-window reflection.
            1.18
        case .typeSymbols, .swordShieldTiles, .splitTypeSymbols, .energySymbols, .pokeBallStars:
            1.35
        case .sunMoonSymbols:
            // Sun & Moon reverse symbols are sparse at compact card sizes.
            // The boost remains clipped to the registered outside-art mask.
            1.30
        case .teraGold, .shinyVMAX, .teraShinyEx:
            1.32
        case .monochrome, .blackEtched, .whiteEtched:
            1.34
        default:
            1
        }
    }

    /// A few illuminated ridges must read at real 230–260 pt card size. This
    /// is independent of the diffuse pattern opacity so we can raise only the
    /// geometry, never a flat reflection over the printed image.
    private var localizedPatternFlash: Double {
        if FoilSheetMaterial(pattern: spec.pattern, cardID: cardID) != nil { return 0 }
        if FoilReliefMaterial(pattern: spec.pattern, texture: spec.texture, cardID: cardID) != nil { return 0 }
        return switch spec.pattern {
        case .starlight, .cosmos, .cosmosStamp:
            0.98
        case .tinsel:
            0.84
        case .sheen, .waterWeb, .verticalLine, .mirage,
             .celebrationSheen:
            0.88
        case .satin, .line:
            0.76
        case .breakGrid, .teraSheen:
            0.98
        case .refractor, .prime, .legend:
            0.78
        case .stone:
            0.96
        case .energySymbols, .energyTypeStamp, .energyPokeBallStamp,
             .pokeBallStamp, .rocketStamp, .pinwheel,
             .pokeBallStars, .pokeBall3D, .stampedMirror, .subjectStamp:
            0.92
        case .energySetStamp:
            0.98
        case .typeSymbols, .swordShieldTiles,
             .scarletVioletTiles, .splitTypeSymbols:
            0.96
        case .sunMoonSymbols:
            1.0
        case .bwGold, .xyGold, .sunMoonGold, .swordShieldGold,
             .scarletVioletGold, .teraGold:
            0.83
        case .starfield, .shinyGX, .shinyV, .shinyVMAX,
             .shinyEx:
            0.72
        case .teraShinyEx:
            0.90
        case .pokeBall:
            0.82
        case .masterBall:
            0.96
        case .confetti:
            0.76
        case .aceDiamond:
            0.96
        case .whiteEtched:
            0.72
        case .monochrome, .blackEtched:
            0.64
        case .starSheen, .doubleRareSheen, .vstarSheen, .crosshatch:
            0.85
        case .none:
            0
        default:
            0
        }
    }

    private var textureResponseBoost: Double {
        switch spec.texture {
        case .bwEtched, .xyEtched:
            1.42
        case .sunMoonEtched:
            1.45
        case .swordShieldEtched:
            1.32
        case .scarletVioletEtched:
            1.48
        default:
            1
        }
    }

    @ViewBuilder
    private func materialGlare(center: Double, highlight: UnitPoint) -> some View {
        let source = FoilAreaLighting.source(nx: tilt.nx, ny: tilt.ny)
        let surfaceSource = UnitPoint(x: source.x, y: source.y)
        switch spec.pattern {
        case _ where FoilSheetMaterial(pattern: spec.pattern, cardID: cardID) != nil:
            Color.clear
        case .refractor where FoilReliefMaterial(pattern: spec.pattern, texture: spec.texture, cardID: cardID) == .neoShining:
            Color.clear
        case .none, .specialIllustration, .spectrum, .line:
            Color.clear
        case .starlight, .cosmos, .cosmosStamp, .celebrationSheen, .fireworks,
             .starSheen, .doubleRareSheen, .vstarSheen, .starfield,
             .shinyGX, .shinyV, .shinyVMAX, .shinyEx, .teraShinyEx, .confetti:
            RadialGradient(colors: [
                .white.opacity(0.54), Color.cyan.opacity(0.13),
                .white.opacity(0.12), .clear,
            ], center: surfaceSource, startRadius: 0, endRadius: width * 2.0)
        case .tinsel, .mirage:
            silverBand(center: highlight.y, width: 0.15,
                       start: .top, end: .bottom)
        case .verticalLine:
            silverBand(center: highlight.x, width: 0.12,
                       start: .leading, end: .trailing)
        case .sheen:
            silverBand(center: center, width: 0.105,
                       start: .bottomTrailing, end: .topLeading)
        case .waterWeb, .pinwheel:
            RadialGradient(colors: [
                .white.opacity(0.46), Color.cyan.opacity(0.18),
                Color.purple.opacity(0.10), .clear,
            ], center: surfaceSource, startRadius: 0, endRadius: width * 2.0)
        case .mirror, .stampedMirror, .subjectStamp, .reverse, .energySymbols,
             .energyTypeStamp, .energyPokeBallStamp, .energySetStamp,
             .pokeBallStamp, .rocketStamp, .pokeBallStars, .pokeBall3D,
             .typeSymbols, .sunMoonSymbols, .swordShieldTiles,
             .scarletVioletTiles, .splitTypeSymbols:
            silverBand(center: center, width: spec.pattern == .mirror ? 0.18 : 0.115,
                       start: UnitPoint(x: -0.1, y: 0.335),
                       end: UnitPoint(x: 1.1, y: 0.665))
        case .gold, .bwGold, .xyGold, .sunMoonGold, .swordShieldGold,
             .scarletVioletGold, .teraGold, .megaGold, .prime:
            goldBand(center: center, width: 0.11)
        case .rainbow, .rainbowSplash, .vmaxRays:
            pearlBand(center: center, width: 0.105)
        case .monochrome, .blackEtched, .whiteEtched:
            monochromeBand(center: center, width: 0.10)
        case .crackedIce, .refractor, .breakGrid, .teraSheen, .futuristic:
            AngularGradient(colors: [
                .clear, .white.opacity(0.34), Color.cyan.opacity(0.15),
                .clear, Color.pink.opacity(0.12), .white.opacity(0.28), .clear,
            ], center: surfaceSource)
        case .stone:
            RadialGradient(colors: [
                Color(red: 0.94, green: 0.90, blue: 0.80).opacity(0.30),
                Color(white: 0.62).opacity(0.12), .clear,
            ], center: surfaceSource, startRadius: 0, endRadius: width * 2.0)
        case .legend, .satin:
            silverBand(center: center, width: 0.13,
                       start: .topTrailing, end: .bottomLeading)
        case .aceDiamond, .magenta:
            magentaBand(center: center, width: 0.11)
        case .crosshatch, .pokeBall, .masterBall:
            pearlBand(center: center, width: 0.10)
        case .comicBurst:
            silverBand(center: center, width: 0.085,
                       start: UnitPoint(x: -0.1, y: 0.335),
                       end: UnitPoint(x: 1.1, y: 0.665))
        }
    }

    private func silverBand(center: Double, width: Double,
                            start: UnitPoint, end: UnitPoint) -> LinearGradient {
        LinearGradient(stops: [
            .init(color: .clear, location: Self.clamped(center - width)),
            .init(color: .white.opacity(0.13), location: Self.clamped(center - width * 0.38)),
            .init(color: .white.opacity(0.40), location: Self.clamped(center)),
            .init(color: Color.cyan.opacity(0.10), location: Self.clamped(center + width * 0.34)),
            .init(color: .clear, location: Self.clamped(center + width)),
        ], startPoint: start, endPoint: end)
    }

    private func monochromeBand(center: Double, width: Double) -> LinearGradient {
        LinearGradient(stops: [
            .init(color: .clear, location: Self.clamped(center - width)),
            .init(color: Color(white: 0.78).opacity(0.12),
                  location: Self.clamped(center - width * 0.38)),
            .init(color: .white.opacity(0.38), location: Self.clamped(center)),
            .init(color: Color(white: 0.70).opacity(0.10),
                  location: Self.clamped(center + width * 0.34)),
            .init(color: .clear, location: Self.clamped(center + width)),
        ], startPoint: UnitPoint(x: -0.1, y: 0.335),
           endPoint: UnitPoint(x: 1.1, y: 0.665))
    }

    private func goldBand(center: Double, width: Double) -> LinearGradient {
        LinearGradient(stops: [
            .init(color: .clear, location: Self.clamped(center - width)),
            .init(color: Color(red: 0.90, green: 0.62, blue: 0.10).opacity(0.24),
                  location: Self.clamped(center - width * 0.42)),
            .init(color: Color(red: 1.0, green: 0.92, blue: 0.56).opacity(0.52),
                  location: Self.clamped(center)),
            .init(color: Color(red: 0.70, green: 0.40, blue: 0.05).opacity(0.22),
                  location: Self.clamped(center + width * 0.40)),
            .init(color: .clear, location: Self.clamped(center + width)),
        ], startPoint: UnitPoint(x: -0.1, y: 0.335),
           endPoint: UnitPoint(x: 1.1, y: 0.665))
    }

    private func pearlBand(center: Double, width: Double) -> LinearGradient {
        LinearGradient(stops: [
            .init(color: .clear, location: Self.clamped(center - width)),
            .init(color: Color.cyan.opacity(0.16),
                  location: Self.clamped(center - width * 0.48)),
            .init(color: .white.opacity(0.46), location: Self.clamped(center)),
            .init(color: Color(red: 1, green: 0.86, blue: 0.52).opacity(0.17),
                  location: Self.clamped(center + width * 0.42)),
            .init(color: .clear, location: Self.clamped(center + width)),
        ], startPoint: UnitPoint(x: -0.1, y: 0.335),
           endPoint: UnitPoint(x: 1.1, y: 0.665))
    }

    private func magentaBand(center: Double, width: Double) -> LinearGradient {
        LinearGradient(stops: [
            .init(color: .clear, location: Self.clamped(center - width)),
            .init(color: Color.pink.opacity(0.26),
                  location: Self.clamped(center - width * 0.45)),
            .init(color: .white.opacity(0.42), location: Self.clamped(center)),
            .init(color: Color.purple.opacity(0.22),
                  location: Self.clamped(center + width * 0.42)),
            .init(color: .clear, location: Self.clamped(center + width)),
        ], startPoint: UnitPoint(x: -0.1, y: 0.335),
           endPoint: UnitPoint(x: 1.1, y: 0.665))
    }

    private func borderGradient(_ border: FoilBorder,
                                highlight: CGPoint) -> LinearGradient {
        let colors: [Color] = switch border {
        case .paper: [.white.opacity(0.45), .clear, .white.opacity(0.12)]
        case .silver: [.white, Color(white: 0.54), .white.opacity(0.7)]
        case .holo: [.cyan, .white, .pink, .yellow]
        case .rainbow: [.red, .yellow, .green, .cyan, .blue, .pink]
        case .gold: [Color(red: 1, green: 0.88, blue: 0.36), .white,
                     Color(red: 0.58, green: 0.32, blue: 0.04)]
        case .magenta: [Color(red: 1, green: 0.35, blue: 0.75), .white,
                        Color(red: 0.38, green: 0.04, blue: 0.34)]
        case .blackWhite: [.white, Color(white: 0.18), Color(white: 0.8)]
        }

        var dx = highlight.x - 0.5
        var dy = highlight.y - 0.5
        let length = (dx * dx + dy * dy).squareRoot()
        if length > 0.0001 {
            dx /= length
            dy /= length
        } else {
            dx = -0.6
            dy = -0.8
        }
        return LinearGradient(
            colors: colors,
            startPoint: UnitPoint(x: 0.5 + dx * 0.55, y: 0.5 + dy * 0.55),
            endPoint: UnitPoint(x: 0.5 - dx * 0.55, y: 0.5 - dy * 0.55))
    }

    private func borderWidth(_ border: FoilBorder) -> CGFloat {
        switch border {
        case .paper: 0.006
        case .silver, .holo: 0.009
        case .rainbow, .gold, .magenta, .blackWhite: 0.012
        }
    }

    private static func clamped(_ value: Double) -> CGFloat {
        CGFloat(min(1, max(0, value)))
    }

    static func seed(for value: String) -> UInt64 {
        var hash: UInt64 = 0xCBF29CE484222325
        for byte in value.utf8 {
            hash = (hash ^ UInt64(byte)) &* 0x100000001B3
        }
        return hash
    }
}

/// EX Team Rocket Returns through Power Keepers rare reverse cards add a
/// metallic-gold name/HP line and rarity mark on top of the set-specific art
/// stamp. The artwork sheet remains independently masked above, so this accent
/// cannot turn the complete card face into one generic gold wash.
@MainActor
private struct EXReverseRareAccentLayer: View {
    let cardID: String
    let highlight: CGPoint
    let band: Double

    var body: some View {
        LinearGradient(stops: [
            .init(color: .clear, location: clamped(band - 0.16)),
            .init(color: Color(red: 0.70, green: 0.42, blue: 0.04).opacity(0.48),
                  location: clamped(band - 0.08)),
            .init(color: Color(red: 1.0, green: 0.88, blue: 0.34).opacity(0.92),
                  location: clamped(band)),
            .init(color: .white.opacity(0.72), location: clamped(band + 0.035)),
            .init(color: .clear, location: clamped(band + 0.16)),
        ], startPoint: UnitPoint(x: -0.1, y: 0.335),
           endPoint: UnitPoint(x: 1.1, y: 0.665))
        .overlay {
            RadialGradient(colors: [
                .white.opacity(0.34), Color.yellow.opacity(0.14), .clear,
            ], center: UnitPoint(x: highlight.x, y: highlight.y),
               startRadius: 0, endRadius: 180)
        }
        .mask { accentMask }
    }

    private var accentMask: some View {
        Canvas { context, size in
            context.fill(FoilGeometry.nameAccentPath(cardID: cardID, in: size),
                         with: .color(.white), style: FillStyle(eoFill: true))
        }
    }

    private func clamped(_ value: Double) -> CGFloat {
        CGFloat(min(1, max(0, value)))
    }
}

// MARK: - Coverage

@MainActor
struct FoilCoverageMask: View {
    let coverage: FoilCoverage
    let cardID: String
    var preloaded: NSImage? = nil

    @ViewBuilder
    var body: some View {
        if coverage == .artBackground || coverage == .artSubject || coverage == .artSubjectAndBorder {
            ArtworkFoilMask(cardID: cardID, preloaded: preloaded, coverage: coverage,
                            art: artRect(in: CGSize(width: 1, height: 1)))
        } else {
        Canvas { context, size in
            let full = CGRect(origin: .zero, size: size)
            let art = artRect(in: size)
            let artwork = FoilGeometry.illustrationPath(cardID: cardID, in: size) ?? Path(art)

            switch coverage {
            case .none:
                break
            case .artWindow:
                context.fill(artwork,
                             with: .color(.white))
            case .artWindowAndMark:
                context.fill(artwork,
                             with: .color(.white))
                context.fill(Path(ellipseIn: FoilGeometry.parallelMarkRect(cardID: cardID, in: size)),
                    with: .color(.white))
            case .artWindowAndPrismStar:
                context.fill(artwork,
                             with: .color(.white))
                context.fill(FoilGeometry.prismStarPath(cardID: cardID, in: size),
                             with: .color(.white))
            case .artAndBorder:
                context.fill(artwork,
                             with: .color(.white))
                context.stroke(Path(roundedRect: full.insetBy(dx: size.width * 0.018,
                                                               dy: size.width * 0.018),
                                    cornerRadius: size.width * 0.045),
                               with: .color(.white), lineWidth: size.width * 0.055)
            case .artBackground, .artSubject, .artSubjectAndBorder:
                break // Image-derived mask above.
            case .artNameAndBorder:
                context.fill(artwork,
                             with: .color(.white))
                context.fill(FoilGeometry.nameAccentPath(cardID: cardID, in: size),
                             with: .color(.white), style: FillStyle(eoFill: true))
                context.stroke(Path(roundedRect: full.insetBy(dx: size.width * 0.018,
                                                               dy: size.width * 0.018),
                                    cornerRadius: size.width * 0.045),
                               with: .color(.white), lineWidth: size.width * 0.055)
            case .outsideArt:
                var path = Path()
                path.addRect(full)
                // Energy/full-bleed printings have no illustration window to
                // punch out. A guessed window used to leave a matte rectangle.
                if let illustration = FoilGeometry.illustrationPath(cardID: cardID, in: size) {
                    path.addPath(illustration)
                }
                context.fill(path, with: .color(.white), style: FillStyle(eoFill: true))
            case .fullCard:
                context.fill(Path(full), with: .color(.white))
            case .splash:
                let blobs = [
                    CGRect(x: size.width * 0.02, y: size.height * 0.09,
                           width: size.width * 0.92, height: size.height * 0.52),
                    CGRect(x: size.width * 0.17, y: size.height * 0.02,
                           width: size.width * 0.72, height: size.height * 0.64),
                    CGRect(x: size.width * 0.04, y: size.height * 0.31,
                           width: size.width * 0.72, height: size.height * 0.37),
                ]
                for blob in blobs {
                    context.fill(Path(ellipseIn: blob), with: .color(.white.opacity(0.88)))
                }
            case .stoneSurface:
                context.fill(Path(roundedRect: full, cornerRadius: size.width * 0.05),
                             with: .color(.white.opacity(0.82)))
            case .traitBands:
                let inner = full.insetBy(dx: size.width * 0.045, dy: size.height * 0.03)
                context.fill(Path(CGRect(x: inner.minX, y: inner.minY, width: inner.width,
                                         height: max(0, art.minY - inner.minY))), with: .color(.white))
                context.fill(Path(CGRect(x: inner.minX, y: art.maxY, width: inner.width,
                                         height: max(0, inner.maxY - art.maxY))), with: .color(.white))
            case .subjectAndAttack:
                // The actual compound material uses an image-guided etch plus
                // these exact ink contours, not an invented subject ellipse.
                context.fill(FoilGeometry.letteringPath(cardID: cardID, in: size),
                             with: .color(.white), style: FillStyle(eoFill: true))
            }
        }
    }

    }

    fileprivate func artRect(in size: CGSize) -> CGRect {
        FoilGeometry.artRect(cardID: cardID, in: size)
    }
}

// MARK: - Finish pattern

/// A localized, material-colored return from fixed foil geometry. Kept above
/// the diffuse pattern layer so a small bright glint can be seen at the real
/// card size without raising the broad white reflection over the illustration.
@MainActor
private struct LocalizedPatternFlash: View {
    let pattern: FoilPattern
    let seed: UInt64
    let cardID: String
    let visualKind: CardVisualKind?
    let coverage: FoilCoverage
    let highlight: CGPoint
    let width: CGFloat

    var body: some View {
        let motif = FinishPatternCanvas(pattern: pattern, seed: seed,
                                        cardID: cardID, visualKind: visualKind,
                                        alphaGain: motifAlphaGain)
        let goldBandCenter = CGFloat(min(0.85, max(0.15,
            (highlight.x + highlight.y) * 0.5)))
        ZStack {
            if [.sunMoonSymbols, .energySetStamp, .breakGrid, .typeSymbols,
                .swordShieldTiles, .splitTypeSymbols, .energySymbols, .pokeBallStars,
                .pokeBall, .teraSheen, .starlight].contains(pattern) {
                // Sparse impressions need their own angular contrast. Screen
                // blending alone cannot reveal a silver motif over white ink.
                // This never extends the motif or its outer coverage mask.
                let phase = (highlight.x - 0.37) * 12 + (highlight.y - 0.32) * 9
                let energy = 0.5 + 0.5 * sin(phase)
                let contrast: Double = switch pattern {
                case .breakGrid: 0.38
                case .starlight: 0.50
                case .energySetStamp: 0.78
                case .teraSheen: 0.65
                case .pokeBall, .pokeBallStars: 0.70
                case .typeSymbols, .swordShieldTiles, .splitTypeSymbols, .energySymbols: 0.86
                default: 1.0
                }
                LinearGradient(colors: [
                    Color(white: 0.10).opacity((1 - energy) * contrast),
                    Color(white: 0.12).opacity(energy * contrast * 0.86),
                    Color(white: 0.10).opacity((1 - energy) * contrast),
                ], startPoint: .topLeading, endPoint: .bottomTrailing)
                    .mask { motif }
            }
            // Dark-to-light contrast lets the same impressed motif read on
            // white and yellow printing, where additive light has no headroom.
            RadialGradient(stops: [
                .init(color: Color(red: 0.08, green: 0.10, blue: 0.16)
                    .opacity(shadowOpacity), location: 0),
                .init(color: Color(white: 0.12).opacity(shadowOpacity * 0.54), location: 0.55),
                .init(color: .clear, location: 1),
            ], center: UnitPoint(x: 1 - highlight.x,
                                 y: shadowFollowsArt ? highlight.y : 1 - highlight.y),
               startRadius: 0, endRadius: width * 0.88)
                .mask { motif }

            if isGoldPattern {
                LinearGradient(stops: [
                    .init(color: .clear, location: goldBandCenter - 0.10),
                    .init(color: Color(red: 0.88, green: 0.56, blue: 0.12)
                        .opacity(0.28), location: goldBandCenter - 0.045),
                    .init(color: Color(red: 1.0, green: 0.94, blue: 0.66)
                        .opacity(0.92), location: goldBandCenter),
                    .init(color: Color(red: 0.92, green: 0.66, blue: 0.20)
                        .opacity(0.24), location: goldBandCenter + 0.04),
                    .init(color: .clear, location: goldBandCenter + 0.10),
                ], startPoint: .topLeading, endPoint: .bottomTrailing)
                    .mask { motif }
            } else if pattern == .stone {
                RadialGradient(stops: [
                    .init(color: .white.opacity(0.88), location: 0),
                    .init(color: Color(red: 0.96, green: 0.86, blue: 0.62)
                        .opacity(0.52), location: 0.45),
                    .init(color: .clear, location: 1),
                ], center: UnitPoint(x: highlight.x, y: highlight.y),
                   startRadius: 0, endRadius: width * 0.42)
                    .mask { StoneGlintMask(seed: seed) }
            } else {
                RadialGradient(stops: [
                    .init(color: peakColor.opacity(0.98), location: 0),
                    .init(color: reflectedColor.opacity(0.74), location: 0.34),
                    .init(color: reflectedColor.opacity(0.20), location: 0.66),
                    .init(color: .clear, location: 1),
                ], center: UnitPoint(x: highlight.x, y: highlight.y),
                   startRadius: 0, endRadius: width * radiusScale)
                    .mask { motif }
            }

            if pattern == .energyTypeStamp || pattern == .energyPokeBallStamp {
                // The EX rare stamp sits below the art window. A light centered
                // in the illustration cannot reach it on a compact card.
                RadialGradient(stops: [
                    .init(color: .white, location: 0),
                    .init(color: .white.opacity(0.68), location: 0.40),
                    .init(color: .clear, location: 1),
                ], center: UnitPoint(
                    x: 0.50 + (highlight.x - 0.37) * 0.22,
                    y: 0.64 + (highlight.y - 0.32) * 0.16),
                   startRadius: 0, endRadius: width * 0.25)
                    .mask { motif }
            }
            if coverage == .outsideArt {
                // Reverse sheets occupy the text half as well. The original
                // art-centered light never reached most of this valid mask.
                RadialGradient(stops: [
                    .init(color: peakColor.opacity(0.96), location: 0),
                    .init(color: reflectedColor.opacity(0.76), location: 0.38),
                    .init(color: .clear, location: 1),
                ], center: UnitPoint(x: 0.5 + (highlight.x - 0.37) * 1.1,
                                     y: 0.80 + (highlight.y - 0.32) * 0.52),
                   startRadius: 0, endRadius: width * 0.55)
                    .mask { motif }
            }
        }
    }

    private var motifAlphaGain: Float {
        switch pattern {
        case .sunMoonSymbols: 7.0
        case .typeSymbols, .swordShieldTiles, .splitTypeSymbols, .energySymbols,
             .pokeBallStars, .pokeBall, .teraSheen: 6.5
        case .energySetStamp: 6.4
        default: 5.0
        }
    }

    private var shadowFollowsArt: Bool {
        switch coverage {
        case .artWindow, .artAndBorder, .artNameAndBorder: true
        default: false
        }
    }

    private var shadowOpacity: Double {
        switch pattern {
        case .mirage: 0.78
        case .tinsel, .verticalLine, .sheen, .waterWeb, .satin, .line,
             .vmaxRays, .vstarSheen, .doubleRareSheen: 0.20
        case .starSheen: 0.42
        case .breakGrid: 0.16
        case .crosshatch, .shinyEx, .teraShinyEx, .prime: 0.10
        case .pokeBall, .masterBall: 0.24
        case .stone: 0.08
        default: 0.46
        }
    }

    private var isGoldPattern: Bool {
        switch pattern {
        case .gold, .bwGold, .xyGold, .sunMoonGold, .swordShieldGold,
             .scarletVioletGold, .teraGold, .megaGold:
            true
        default:
            false
        }
    }

    private var reflectedColor: Color {
        switch pattern {
        case .starlight, .cosmos, .cosmosStamp:
            Color(red: 0.76, green: 0.91, blue: 1.0)
        case .mirage, .verticalLine, .tinsel:
            Color(red: 0.56, green: 0.80, blue: 0.98)
        case .sheen, .waterWeb,
             .celebrationSheen:
            Color(red: 0.88, green: 0.94, blue: 0.98)
        case .satin, .line:
            Color(red: 0.91, green: 0.97, blue: 1.0)
        case .starfield, .shinyGX, .shinyV, .shinyVMAX,
             .shinyEx, .teraShinyEx, .pokeBall,
             .refractor, .legend, .confetti:
            Color(red: 0.82, green: 0.94, blue: 1.0)
        case .masterBall:
            Color(red: 0.90, green: 0.80, blue: 1.0)
        case .stone:
            Color(red: 0.94, green: 0.88, blue: 0.71)
        case .prime:
            Color(red: 1.0, green: 0.87, blue: 0.54)
        case .breakGrid:
            Color(red: 1.0, green: 0.88, blue: 0.51)
        case .aceDiamond:
            Color(red: 1.0, green: 0.60, blue: 0.88)
        case .monochrome, .blackEtched, .whiteEtched:
            Color(white: 0.95)
        case .bwGold, .xyGold, .sunMoonGold, .swordShieldGold,
             .scarletVioletGold, .teraGold:
            Color(red: 1.0, green: 0.78, blue: 0.28)
        case .energySymbols, .energyTypeStamp, .energyPokeBallStamp,
             .energySetStamp, .pokeBallStamp, .rocketStamp, .pinwheel,
             .pokeBallStars, .pokeBall3D, .stampedMirror, .subjectStamp,
             .typeSymbols, .sunMoonSymbols, .swordShieldTiles,
             .scarletVioletTiles, .splitTypeSymbols:
            Color(red: 0.92, green: 0.96, blue: 1.0)
        default:
            .white
        }
    }

    private var peakColor: Color {
        switch pattern {
        case .bwGold, .xyGold, .sunMoonGold, .swordShieldGold,
             .scarletVioletGold, .teraGold:
            Color(red: 1.0, green: 0.94, blue: 0.66)
        default:
            .white
        }
    }

    private var radiusScale: CGFloat {
        switch pattern {
        case .starlight, .cosmos, .cosmosStamp:
            0.56
        case .satin, .line:
            0.52
        case .starfield, .shinyGX, .shinyV, .shinyVMAX,
             .shinyEx, .pokeBall, .confetti, .monochrome,
             .blackEtched:
            0.54
        case .teraShinyEx, .masterBall, .whiteEtched:
            0.62
        case .aceDiamond:
            0.68
        case .refractor, .prime, .legend:
            0.58
        case .stone:
            0.50
        case .waterWeb:
            0.48
        case .energySymbols, .energyTypeStamp, .energyPokeBallStamp,
             .energySetStamp, .pokeBallStamp, .rocketStamp, .pinwheel,
             .pokeBallStars, .pokeBall3D, .stampedMirror, .subjectStamp:
            0.60
        case .typeSymbols, .sunMoonSymbols, .swordShieldTiles,
             .scarletVioletTiles, .splitTypeSymbols:
            0.56
        case .bwGold, .xyGold, .sunMoonGold, .swordShieldGold,
             .scarletVioletGold, .teraGold:
            0.52
        default:
            0.64
        }
    }
}

@MainActor
private struct StoneGlintMask: View {
    let seed: UInt64

    var body: some View {
        Canvas { context, size in
            var random = SeededValues(seed: seed)
            for index in 0..<54 {
                let center = CGPoint(x: random.next() * size.width,
                                     y: random.next() * size.height)
                let radius = 1 + random.next() * 3.2
                guard index.isMultiple(of: 2) else { continue }
                let glintRadius = radius * 1.24
                context.fill(Path(ellipseIn: CGRect(x: center.x - glintRadius,
                                                    y: center.y - glintRadius * 0.55,
                                                    width: glintRadius * 2,
                                                    height: glintRadius * 1.1)),
                             with: .color(.white))
            }
        }
    }
}

@MainActor
private struct FinishPatternLayer: View {
    let pattern: FoilPattern
    let texture: FoilTexture
    let seed: UInt64
    let cardID: String
    let finish: CardFinish
    let highlight: CGPoint
    let width: CGFloat
    let visualKind: CardVisualKind?
    let preloaded: NSImage?
    let tilt: TiltVector

    @ViewBuilder
    var body: some View {
        if let sheet = FoilSheetMaterial(pattern: pattern, cardID: cardID) {
            if let preloaded {
                FoilSheetLayer(material: sheet, source: preloaded, cardID: cardID, tilt: tilt)
            }
        } else if pattern == .whiteEtched || pattern == .blackEtched || pattern == .monochrome {
            ScannedFoilReliefLayer(cardID: cardID, preloaded: preloaded,
                                  isWhite: pattern == .whiteEtched,
                                  isMonochrome: pattern == .monochrome,
                                  tilt: tilt)
        } else if let material = FoilReliefMaterial(pattern: pattern, texture: texture, cardID: cardID) {
            ImageGuidedFoilRelief(cardID: cardID, preloaded: preloaded,
                                 material: material, seed: seed, tilt: tilt)
        } else {
            let motif = FinishPatternCanvas(pattern: pattern, seed: seed,
                                            cardID: cardID, visualKind: visualKind)
            ZStack {
                ZStack {
                    if !isGoldPattern {
                        // The source scan already contains the continuous
                        // gold ink. A second full-face color sheet makes UR
                        // look like one reflective plate; the moving response
                        // belongs on its fixed emboss geometry instead.
                        baseGradient
                    }
                    motif
                        // The stamped/embossed geometry is part of the card. A real
                        // sheet does not slide over the printed image as the card is
                        // tilted; only the illumination travelling across it changes.
                        .mask { motifIllumination }
                }
                .blendMode(blendMode)
                if pattern == .mirror || pattern == .stampedMirror || pattern == .subjectStamp {
                    // Bulbapedia "Holofoil" calls these reverses a flat/plain
                    // holographic finish: no motif, but the smooth sheet still
                    // splits light into a rainbow that slides with the tilt.
                    // Only the SWSH/SV tile reverses are colourless mirror foil.
                    // Normal blending: a screen tint vanishes on white card bodies.
                    // Faint everywhere, vivid where the light lands.
                    ZStack {
                        plainHolographicSpectrum
                            .opacity(0.22)
                        plainHolographicSpectrum
                            .mask { plainHolographicLightBand }
                    }
                    .opacity(0.55 + 0.45 * tilt.magnitude)
                }
                if pattern == .crosshatch {
                    RadialGradient(stops: [
                        .init(color: Color(red: 0.70, green: 0.98, blue: 1.0)
                            .opacity(0.72), location: 0),
                        .init(color: Color.cyan.opacity(0.32), location: 0.42),
                        .init(color: .clear, location: 1),
                    ], center: UnitPoint(x: highlight.x, y: highlight.y),
                       startRadius: 0, endRadius: width * 0.46)
                        .mask { motif }
                        .mask {
                            Canvas { context, size in
                                let art = FoilGeometry.artRect(cardID: cardID, in: size)
                                var field = Path(CGRect(origin: .zero, size: size)
                                    .insetBy(dx: size.width * 0.055, dy: size.height * 0.03))
                                field.addRect(art)
                                context.fill(field, with: .color(.white), style: FillStyle(eoFill: true))
                            }
                        }
                }
                if pattern == .megaGold {
                    RadialGradient(stops: [
                        .init(color: Color(red: 1.0, green: 0.94, blue: 0.58)
                            .opacity(0.96), location: 0),
                        .init(color: Color(red: 0.82, green: 0.53, blue: 0.10)
                            .opacity(0.24), location: 0.46),
                        .init(color: .clear, location: 1),
                    ], center: UnitPoint(x: highlight.x, y: highlight.y),
                       startRadius: 0, endRadius: width * 0.40)
                        .mask { motif }
                        .blendMode(.plusLighter)
                }
            }
            .hueRotation(.degrees(hueRotation))
        }
    }

    private var isGoldPattern: Bool {
        switch pattern {
        case .gold, .bwGold, .xyGold, .sunMoonGold, .swordShieldGold,
             .scarletVioletGold, .teraGold, .megaGold:
            true
        default:
            false
        }
    }

    @ViewBuilder
    private var motifIllumination: some View {
        let center = UnitPoint(x: highlight.x, y: highlight.y)
        if pattern == .crosshatch {
            RadialGradient(colors: [
                .white,
                .white.opacity(0.46),
                .white.opacity(0.02),
            ], center: center, startRadius: 0, endRadius: width * 0.64)
        } else if finish == .reverseHolo && isEXSeriesCard {
            RadialGradient(colors: [
                .white,
                .white.opacity(0.50),
                .white.opacity(0.04),
            ], center: center, startRadius: 0, endRadius: width * 0.72)
        } else {
            RadialGradient(colors: [
                .white,
                .white.opacity(0.62),
                .white.opacity(0.05),
            ], center: center, startRadius: 0, endRadius: width * 0.76)
        }
    }

    private var isEXSeriesCard: Bool {
        guard let prefix = cardID.split(separator: "-", maxSplits: 1).first,
              prefix.hasPrefix("ex"),
              let number = Int(prefix.dropFirst(2)) else { return false }
        return (5...16).contains(number)
    }

    /// Two smooth rainbow cycles across the sheet. The highlight position
    /// moves them, so the colours travel instead of being printed in place.
    private var plainHolographicSpectrum: some View {
        let shift = (Double(highlight.x) - 0.5) * 1.1 + (Double(highlight.y) - 0.5) * 0.7
        let hues: [Double] = [0.0, 0.09, 0.17, 0.33, 0.50, 0.60, 0.75, 0.88]
        return LinearGradient(
            colors: (hues + hues).map {
                Color(hue: $0, saturation: 0.72, brightness: 1)
            },
            startPoint: UnitPoint(x: -0.9 - shift, y: -0.3 - shift * 0.4),
            endPoint: UnitPoint(x: 1.9 - shift, y: 1.3 - shift * 0.4))
    }

    /// The broad diagonal band where the light currently lands.
    private var plainHolographicLightBand: some View {
        let center = min(0.95, max(0.05, Double(highlight.x + highlight.y) / 2))
        return LinearGradient(stops: [
            .init(color: .clear, location: max(0, center - 0.34)),
            .init(color: .white.opacity(0.72), location: center),
            .init(color: .clear, location: min(1, center + 0.34)),
        ], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    @ViewBuilder
    private var baseGradient: some View {
        let center = UnitPoint(x: highlight.x, y: highlight.y)
        switch pattern {
        case .none:
            Color.clear
        case .starlight:
            RadialGradient(colors: [
                .white.opacity(0.42), Color.cyan.opacity(0.18),
                Color.indigo.opacity(0.12), .clear,
            ], center: center, startRadius: 0, endRadius: 250)
        case .cosmos, .cosmosStamp:
            RadialGradient(colors: [
                .white.opacity(0.44), Color.cyan.opacity(0.20),
                Color.purple.opacity(0.14), .clear,
            ], center: center, startRadius: 0, endRadius: 260)
        case .tinsel:
            LinearGradient(colors: [
                Color(white: 0.88).opacity(0.30), Color.cyan.opacity(0.15),
                Color(white: 0.95).opacity(0.36), Color.pink.opacity(0.12),
            ], startPoint: .top, endPoint: .bottom)
        case .sheen:
            LinearGradient(colors: [
                Color(white: 0.88).opacity(0.28), Color.cyan.opacity(0.15),
                Color.purple.opacity(0.12), Color(white: 0.92).opacity(0.30),
            ], startPoint: .bottomTrailing, endPoint: .topLeading)
        case .waterWeb:
            LinearGradient(colors: [
                Color.cyan.opacity(0.18), Color(white: 0.94).opacity(0.34),
                Color.blue.opacity(0.14), Color.pink.opacity(0.10),
            ], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .verticalLine:
            LinearGradient(colors: [
                Color(white: 0.9).opacity(0.30), Color.cyan.opacity(0.13),
                Color(white: 0.96).opacity(0.34), Color.purple.opacity(0.10),
            ], startPoint: .leading, endPoint: .trailing)
        case .mirage:
            LinearGradient(colors: [
                Color.cyan.opacity(0.14), Color(white: 0.96).opacity(0.32),
                Color.pink.opacity(0.12), Color.yellow.opacity(0.09),
                Color(white: 0.9).opacity(0.28),
            ], startPoint: .top, endPoint: .bottom)
        case .reverse, .mirror, .stampedMirror, .subjectStamp:
            LinearGradient(colors: [
                Color(white: 0.78).opacity(0.24), Color(white: 0.98).opacity(0.38),
                Color.cyan.opacity(0.11), Color(white: 0.82).opacity(0.26),
            ], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .fireworks:
            RadialGradient(colors: [
                .white.opacity(0.38), Color.cyan.opacity(0.17),
                Color.purple.opacity(0.12), .clear,
            ], center: center, startRadius: 0, endRadius: 280)
        case .energySymbols, .energyTypeStamp, .energyPokeBallStamp,
             .energySetStamp, .typeSymbols:
            LinearGradient(colors: [
                Color(white: 0.95).opacity(0.32), Color.yellow.opacity(0.11),
                Color.cyan.opacity(0.12), Color(white: 0.82).opacity(0.26),
            ], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .pokeBallStamp, .pokeBallStars, .pokeBall3D:
            LinearGradient(colors: [
                Color(white: 0.9).opacity(0.31), Color.cyan.opacity(0.14),
                Color.pink.opacity(0.11), Color(white: 0.82).opacity(0.27),
            ], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .rocketStamp:
            LinearGradient(colors: [
                Color(white: 0.84).opacity(0.28), Color.red.opacity(0.12),
                Color.yellow.opacity(0.10), Color(white: 0.95).opacity(0.34),
            ], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .pinwheel:
            AngularGradient(colors: [
                Color.cyan.opacity(0.18), .white.opacity(0.34),
                Color.pink.opacity(0.14), .white.opacity(0.28),
                Color.cyan.opacity(0.18),
            ], center: center)
        case .sunMoonSymbols:
            LinearGradient(colors: [
                Color.cyan.opacity(0.13), Color(white: 0.94).opacity(0.34),
                Color.purple.opacity(0.13), Color(white: 0.82).opacity(0.27),
            ], startPoint: .leading, endPoint: .trailing)
        case .swordShieldTiles:
            LinearGradient(colors: [
                Color(white: 0.9).opacity(0.30), Color.blue.opacity(0.12),
                Color.red.opacity(0.09), Color(white: 0.96).opacity(0.34),
            ], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .scarletVioletTiles:
            LinearGradient(colors: [
                Color(white: 0.92).opacity(0.31), Color.cyan.opacity(0.11),
                Color.pink.opacity(0.10), Color.yellow.opacity(0.08),
                Color(white: 0.86).opacity(0.28),
            ], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .splitTypeSymbols:
            LinearGradient(colors: [
                Color.red.opacity(0.17), Color.yellow.opacity(0.11),
                Color(white: 0.96).opacity(0.32), Color.cyan.opacity(0.15),
                Color.purple.opacity(0.13),
            ], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .crackedIce:
            LinearGradient(colors: [
                Color(white: 0.97).opacity(0.36), Color.cyan.opacity(0.18),
                Color.blue.opacity(0.13), Color.pink.opacity(0.09),
                Color(white: 0.86).opacity(0.28),
            ], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .refractor:
            LinearGradient(colors: [
                Color.cyan.opacity(0.15), Color(white: 0.97).opacity(0.34),
                Color.pink.opacity(0.13), Color.yellow.opacity(0.09),
                Color.blue.opacity(0.12),
            ], startPoint: .bottomLeading, endPoint: .topTrailing)
        case .stone:
            LinearGradient(colors: [
                Color(red: 0.75, green: 0.70, blue: 0.60).opacity(0.24),
                Color(white: 0.92).opacity(0.27),
                Color(red: 0.47, green: 0.45, blue: 0.40).opacity(0.18),
                Color(red: 0.83, green: 0.78, blue: 0.67).opacity(0.24),
            ], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .prime:
            LinearGradient(colors: [
                Color(red: 0.88, green: 0.68, blue: 0.22).opacity(0.20),
                Color(white: 0.97).opacity(0.35), Color.cyan.opacity(0.11),
                Color(red: 0.70, green: 0.47, blue: 0.08).opacity(0.18),
            ], startPoint: .leading, endPoint: .trailing)
        case .legend:
            LinearGradient(colors: [
                Color.cyan.opacity(0.14), Color.purple.opacity(0.12),
                Color(white: 0.98).opacity(0.36), Color.yellow.opacity(0.09),
                Color.pink.opacity(0.12),
            ], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .celebrationSheen:
            LinearGradient(colors: [
                Color(white: 0.96).opacity(0.35), Color.cyan.opacity(0.12),
                Color(white: 0.82).opacity(0.25), Color.pink.opacity(0.08),
            ], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .aceDiamond:
            LinearGradient(colors: [
                Color(red: 0.34, green: 0.02, blue: 0.24).opacity(0.45),
                Color(red: 0.98, green: 0.22, blue: 0.67).opacity(0.48),
                Color(white: 0.95).opacity(0.31),
                Color(red: 0.55, green: 0.04, blue: 0.48).opacity(0.42),
            ], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .starSheen:
            RadialGradient(colors: [
                .white.opacity(0.38), Color.cyan.opacity(0.16),
                Color.pink.opacity(0.11), .clear,
            ], center: center, startRadius: 0, endRadius: 290)
        case .doubleRareSheen:
            RadialGradient(colors: [
                .white.opacity(0.42), Color(white: 0.82).opacity(0.22),
                Color.cyan.opacity(0.10), .clear,
            ], center: center, startRadius: 0, endRadius: 280)
        case .teraSheen:
            AngularGradient(colors: [
                Color.cyan.opacity(0.18), .white.opacity(0.40),
                Color.purple.opacity(0.13), Color.yellow.opacity(0.12),
                .white.opacity(0.32), Color.cyan.opacity(0.18),
            ], center: center)
        case .vstarSheen:
            LinearGradient(colors: [
                Color(white: 0.88).opacity(0.25), Color.cyan.opacity(0.12),
                .white.opacity(0.36), Color.pink.opacity(0.10),
                Color(white: 0.84).opacity(0.22),
            ], startPoint: .topTrailing, endPoint: .bottomLeading)
        case .satin:
            LinearGradient(colors: [
                Color(white: 0.9).opacity(0.27), Color.cyan.opacity(0.10),
                Color.pink.opacity(0.09), Color(white: 0.96).opacity(0.31),
            ], startPoint: .topTrailing, endPoint: .bottomLeading)
        case .specialIllustration:
            Color.clear
        case .vmaxRays:
            AngularGradient(colors: [
                Color.cyan.opacity(0.20), Color.purple.opacity(0.15),
                .white.opacity(0.34), Color.pink.opacity(0.14),
                Color.cyan.opacity(0.20),
            ], center: UnitPoint(x: 0.5, y: 0.36))
        case .spectrum, .line:
            Color.clear
        case .crosshatch:
            Color.clear
        case .rainbowSplash:
            LinearGradient(colors: [
                Color(white: 0.88).opacity(0.18), .white.opacity(0.44),
                Color.cyan.opacity(0.08), Color(white: 0.82).opacity(0.20),
                Color(red: 1.0, green: 0.90, blue: 0.66).opacity(0.08),
            ], startPoint: UnitPoint(x: -0.1, y: 0.335),
               endPoint: UnitPoint(x: 1.1, y: 0.665))
        case .rainbow:
            pearlyRainbow
        case .gold, .scarletVioletGold:
            LinearGradient(colors: [
                Color(red: 0.38, green: 0.18, blue: 0.02).opacity(0.54),
                Color(red: 1.0, green: 0.82, blue: 0.24).opacity(0.72),
                .white.opacity(0.68),
                Color(red: 0.68, green: 0.36, blue: 0.04).opacity(0.56),
                Color(red: 1.0, green: 0.9, blue: 0.38).opacity(0.72),
            ], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .teraGold:
            AngularGradient(colors: [
                Color(red: 0.34, green: 0.16, blue: 0.01).opacity(0.58),
                Color(red: 1.0, green: 0.84, blue: 0.25).opacity(0.76),
                .white.opacity(0.62),
                Color(red: 0.70, green: 0.38, blue: 0.03).opacity(0.60),
                Color(red: 1.0, green: 0.91, blue: 0.42).opacity(0.74),
                Color(red: 0.34, green: 0.16, blue: 0.01).opacity(0.58),
            ], center: center)
        case .bwGold:
            LinearGradient(colors: [
                Color(red: 0.27, green: 0.12, blue: 0.01).opacity(0.56),
                Color(red: 0.92, green: 0.66, blue: 0.12).opacity(0.72),
                .white.opacity(0.62),
                Color(red: 0.55, green: 0.28, blue: 0.025).opacity(0.60),
            ], startPoint: .top, endPoint: .bottom)
        case .xyGold:
            LinearGradient(colors: [
                Color(red: 0.46, green: 0.22, blue: 0.02).opacity(0.55),
                Color(red: 1.0, green: 0.80, blue: 0.22).opacity(0.70),
                .white.opacity(0.64),
                Color(red: 0.72, green: 0.41, blue: 0.05).opacity(0.58),
            ], startPoint: .bottomTrailing, endPoint: .topLeading)
        case .sunMoonGold:
            RadialGradient(colors: [
                Color(red: 1.0, green: 0.88, blue: 0.40).opacity(0.70),
                .white.opacity(0.57),
                Color(red: 0.54, green: 0.26, blue: 0.02).opacity(0.58),
                .clear,
            ], center: center, startRadius: 0, endRadius: 300)
        case .swordShieldGold:
            LinearGradient(colors: [
                Color(red: 0.22, green: 0.12, blue: 0.015).opacity(0.60),
                Color(red: 0.96, green: 0.72, blue: 0.16).opacity(0.73),
                .white.opacity(0.60),
                Color(red: 0.36, green: 0.19, blue: 0.02).opacity(0.62),
            ], startPoint: .leading, endPoint: .trailing)
        case .starfield, .shinyV:
            LinearGradient(colors: [
                Color(white: 0.9).opacity(0.36), Color.cyan.opacity(0.16),
                Color.purple.opacity(0.14), Color(white: 0.88).opacity(0.32),
            ], startPoint: .top, endPoint: .bottomTrailing)
        case .shinyGX:
            AngularGradient(colors: [
                Color.cyan.opacity(0.16), .white.opacity(0.37),
                Color.pink.opacity(0.13), Color.purple.opacity(0.12),
                .white.opacity(0.33), Color.cyan.opacity(0.16),
            ], center: center)
        case .shinyVMAX:
            AngularGradient(colors: [
                Color(white: 0.18).opacity(0.46), Color.cyan.opacity(0.18),
                .white.opacity(0.43),
                Color(red: 1.0, green: 0.78, blue: 0.20).opacity(0.24),
                Color.purple.opacity(0.13), .white.opacity(0.36),
                Color(white: 0.18).opacity(0.46),
            ], center: UnitPoint(x: 0.5, y: 0.36))
        case .shinyEx:
            LinearGradient(colors: [
                Color(white: 0.94).opacity(0.34), Color.cyan.opacity(0.11),
                Color(white: 0.78).opacity(0.27), Color.pink.opacity(0.09),
                .white.opacity(0.38),
            ], startPoint: .topTrailing, endPoint: .bottomLeading)
        case .teraShinyEx:
            AngularGradient(colors: [
                Color(white: 0.86).opacity(0.30), Color.green.opacity(0.15),
                .white.opacity(0.42), Color.cyan.opacity(0.13),
                Color(red: 0.96, green: 0.84, blue: 0.28).opacity(0.13),
                .white.opacity(0.34), Color(white: 0.86).opacity(0.30),
            ], center: center)
        case .magenta:
            LinearGradient(colors: [
                Color(red: 0.32, green: 0.02, blue: 0.25),
                Color(red: 1, green: 0.22, blue: 0.68), .white,
                Color(red: 0.58, green: 0.04, blue: 0.52),
            ], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .pokeBall, .masterBall:
            LinearGradient(colors: [
                Color(white: 0.76).opacity(0.29), Color.cyan.opacity(0.13),
                Color.pink.opacity(0.10), Color(white: 0.92).opacity(0.32),
            ], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .confetti:
            Color.clear
        case .breakGrid:
            LinearGradient(colors: [
                Color(red: 0.98, green: 0.76, blue: 0.18).opacity(0.40),
                Color(white: 0.98).opacity(0.32), Color.cyan.opacity(0.18),
                Color.pink.opacity(0.14),
                Color(red: 0.82, green: 0.54, blue: 0.08).opacity(0.34),
            ], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .megaGold:
            Color.clear
        case .monochrome:
            LinearGradient(colors: [
                Color.black.opacity(0.46), Color(white: 0.78).opacity(0.62),
                .white.opacity(0.68), Color(white: 0.12).opacity(0.48),
            ], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .blackEtched:
            LinearGradient(colors: [
                Color.black.opacity(0.54), Color(white: 0.72).opacity(0.48),
                .white.opacity(0.58), Color.black.opacity(0.50),
            ], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .whiteEtched:
            LinearGradient(colors: [
                Color(white: 0.66).opacity(0.20), .white.opacity(0.58),
                Color(white: 0.82).opacity(0.28),
                Color(white: 0.96).opacity(0.48),
            ], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .comicBurst:
            LinearGradient(colors: [
                Color(white: 0.74).opacity(0.18), .white.opacity(0.48),
                Color(white: 0.90).opacity(0.24), .white.opacity(0.40),
            ], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .futuristic:
            AngularGradient(colors: [
                Color(white: 0.12).opacity(0.62), Color.cyan.opacity(0.44),
                .white.opacity(0.70), Color.purple.opacity(0.36),
                Color.yellow.opacity(0.26), .white.opacity(0.58),
            ], center: center)
        }
    }

    private var pearlyRainbow: LinearGradient {
        LinearGradient(colors: [
            Color(white: 0.78).opacity(0.20), .white.opacity(0.56),
            Color.cyan.opacity(0.09), Color(white: 0.88).opacity(0.28),
            Color(red: 1.0, green: 0.88, blue: 0.64).opacity(0.08),
            .white.opacity(0.48), Color.pink.opacity(0.07),
        ], startPoint: UnitPoint(x: -0.1, y: 0.335),
           endPoint: UnitPoint(x: 1.1, y: 0.665))
    }

    private var hueRotation: Double {
        switch pattern {
        case .starSheen:
            (highlight.x - 0.5) * 150 + (highlight.y - 0.5) * 90
        case .spectrum, .line, .futuristic:
            (highlight.x - 0.5) * 34 + (highlight.y - 0.5) * 16
        case .specialIllustration:
            0
        case .refractor, .legend, .celebrationSheen, .breakGrid:
            (highlight.x - 0.5) * 26 + (highlight.y - 0.5) * 14
        case .mirage:
            (highlight.y - 0.5) * 18
        case .none, .starlight, .cosmos, .tinsel, .sheen, .waterWeb,
             .verticalLine, .reverse, .fireworks, .mirror, .energySymbols,
             .energyTypeStamp, .energyPokeBallStamp, .energySetStamp,
             .pokeBallStamp, .rocketStamp, .pinwheel, .pokeBallStars,
             .pokeBall3D, .stampedMirror, .cosmosStamp, .subjectStamp,
             .typeSymbols, .sunMoonSymbols,
             .swordShieldTiles, .scarletVioletTiles, .splitTypeSymbols,
             .crackedIce, .stone,
             .prime, .aceDiamond, .doubleRareSheen, .vstarSheen,
             .satin, .vmaxRays, .crosshatch, .gold, .bwGold, .xyGold,
             .sunMoonGold, .swordShieldGold, .scarletVioletGold, .teraGold,
             .starfield, .shinyGX, .shinyV, .shinyVMAX, .shinyEx, .teraShinyEx,
             .magenta, .pokeBall, .masterBall, .confetti,
             .megaGold, .monochrome, .blackEtched, .whiteEtched,
             .rainbowSplash, .rainbow, .comicBurst:
            0
        case .teraSheen:
            (highlight.x - 0.5) * 14 + (highlight.y - 0.5) * 8
        }
    }

    private var blendMode: BlendMode {
        switch pattern {
        case .refractor, .prime, .breakGrid, .starSheen:
            .normal
        // Reverse-holo stamps are specular impressions in the foil sheet. They
        // need a screen response to remain legible over both dark artwork and
        // saturated card-type backgrounds; softLight made the real motif
        // geometry effectively disappear at normal viewing angles.
        case .mirror, .stampedMirror, .cosmosStamp, .subjectStamp,
             .energySymbols, .energyTypeStamp, .energyPokeBallStamp,
             .energySetStamp, .pokeBallStamp,
             .rocketStamp, .pinwheel, .pokeBallStars, .pokeBall3D,
             .typeSymbols, .sunMoonSymbols, .swordShieldTiles,
             .scarletVioletTiles, .splitTypeSymbols, .confetti:
            .screen
        case .specialIllustration: .softLight
        case .none: .normal
        case .megaGold:
            .normal
        case .crosshatch:
            .screen
        case .starlight, .cosmos, .tinsel, .sheen, .waterWeb, .verticalLine,
             .mirage, .reverse, .fireworks, .crackedIce,
             .stone,
             .legend, .celebrationSheen, .aceDiamond,
             .doubleRareSheen, .teraSheen, .vstarSheen, .satin, .vmaxRays,
             .spectrum, .line, .rainbowSplash, .rainbow,
             .gold, .bwGold, .xyGold, .sunMoonGold, .swordShieldGold,
             .scarletVioletGold, .teraGold, .starfield, .shinyGX, .shinyV,
             .shinyVMAX, .shinyEx, .teraShinyEx,
             .magenta, .pokeBall, .masterBall,
             .monochrome, .blackEtched,
             .whiteEtched, .comicBurst, .futuristic:
            .softLight
        }
    }
}


private enum SpecialIllustrationRelief {
    static let rowCount = 64

    struct Geometry {
        let phase: CGFloat
        let slope: CGFloat
    }

    static func parameters(seed: UInt64, size: CGSize) -> Geometry {
        var random = SeededValues(seed: seed ^ 0xA57A_11E7_C01D_F011)
        return Geometry(phase: CGFloat(random.next() * Double.pi * 2),
                        slope: CGFloat(random.next() - 0.5) * size.height * 0.065)
    }

    static func point(row: Int, progress: CGFloat, size: CGSize,
                      geometry: Geometry) -> CGPoint {
        let rowProgress = CGFloat(row) / CGFloat(rowCount - 1)
        let primaryWave = sin(progress * .pi * 3.4 + geometry.phase
            + CGFloat(row) * 0.105) * size.height * 0.0075
        let fineWave = sin(progress * .pi * 9.8 - geometry.phase * 0.42
            + CGFloat(row) * 0.19) * size.height * 0.0024
        return CGPoint(x: progress * size.width,
                       y: rowProgress * size.height + primaryWave + fineWave
                        + (progress - 0.5) * geometry.slope)
    }
}

/// Mega Attack uses two physically different foils on one card. The Pokémon
/// area has fine etched relief while the printed attack names have a glossier,
/// directional pattern. Keeping separate masks here avoids collapsing both
/// surfaces into the same generic texture.
@MainActor
private struct MegaAttackMaterialLayer: View {
    let cardID: String
    let source: NSImage
    let tilt: TiltVector
    let seed: UInt64
    let highlight: CGPoint
    let band: Double

    var body: some View {
        ZStack {
            ImageGuidedFoilRelief(cardID: cardID, preloaded: source,
                                 material: .engraved(.mirage, .scarletVioletEtched), seed: seed, tilt: tilt)
                .mask { subjectMask }
                // The etched material already computes illumination. A second
                // mask plus softLight plus parent opacity erased the response.

            attackStripes
                .mask { attackMask }
                .blendMode(.normal)
                .opacity(0.88)

            attackGlare
                .mask { attackMask }
                .blendMode(.screen)
        }
    }

    private var attackStripes: some View {
        Canvas { context, size in
            for bandRect in attackRects(in: size) {
                var x = bandRect.minX - bandRect.height
                while x < bandRect.maxX + bandRect.height {
                    var stripe = Path()
                    stripe.move(to: CGPoint(x: x, y: bandRect.maxY))
                    stripe.addLine(to: CGPoint(x: x + bandRect.height,
                                               y: bandRect.minY))
                    let energy = 0.15 + 0.85 * pow(max(0, cos(tilt.nx * 3.4 + tilt.ny * 2.6 + x * 0.08)), 2)
                    context.stroke(stripe, with: .color(Color(white: energy).opacity(0.86)),
                                   lineWidth: 0.92)
                    x += max(4, size.width * 0.018)
                }
            }
        }
    }

    private var subjectMask: some View {
        Canvas { context, size in
            context.fill(Path(CGRect(origin: .zero, size: size)
                .insetBy(dx: size.width * 0.04, dy: size.height * 0.03)), with: .color(.white))
            context.blendMode = .destinationOut
            context.fill(FoilGeometry.letteringPath(cardID: cardID, in: size),
                         with: .color(.white), style: FillStyle(eoFill: true))
        }
    }

    private var attackMask: some View {
        Canvas { context, size in
            context.fill(FoilGeometry.letteringPath(cardID: cardID, in: size),
                         with: .color(.white), style: FillStyle(eoFill: true))
        }
    }

    private var attackGlare: some View {
        LinearGradient(stops: [
            .init(color: .clear, location: clamped(band - 0.075)),
            .init(color: Color(white: 0.84).opacity(0.30),
                  location: clamped(band - 0.035)),
            .init(color: .white.opacity(0.78), location: clamped(band)),
            .init(color: Color(white: 0.76).opacity(0.26),
                  location: clamped(band + 0.035)),
            .init(color: .clear, location: clamped(band + 0.075)),
        ], startPoint: UnitPoint(x: -0.1, y: 0.335),
           endPoint: UnitPoint(x: 1.1, y: 0.665))
    }

    private func attackRects(in size: CGSize) -> [CGRect] {
        [FoilGeometry.letteringPath(cardID: cardID, in: size).boundingRect]
    }

    private func clamped(_ value: Double) -> CGFloat {
        CGFloat(min(1, max(0, value)))
    }
}

@MainActor
struct FinishPatternCanvas: View {
    let pattern: FoilPattern
    let seed: UInt64
    let cardID: String
    let visualKind: CardVisualKind?
    var alphaGain: Float = 1

    var body: some View {
        Canvas { context, size in
            if alphaGain != 1 {
                var matrix = ColorMatrix()
                matrix.a4 = alphaGain
                context.addFilter(.colorMatrix(matrix))
            }
            switch pattern {
            case .none, .mirror, .magenta:
                break
            case .gold:
                drawEtchedWaves(context: &context, size: size)
            case .spectrum:
                drawSpectrumGrain(context: &context, size: size)
            case .starlight:
                drawStarlight(context: &context, size: size)
            case .cosmos:
                drawCosmos(context: &context, size: size)
            case .cosmosStamp:
                drawCosmos(context: &context, size: size)
            case .tinsel:
                drawTinsel(context: &context, size: size)
            case .sheen:
                drawSheen(context: &context, size: size)
            case .waterWeb:
                drawWaterWeb(context: &context, size: size)
            case .verticalLine:
                drawVerticalLines(context: &context, size: size)
            case .mirage:
                drawMirage(context: &context, size: size)
            case .reverse:
                drawDiagonalLines(context: &context, size: size, spacing: 13, crossing: false)
            case .fireworks:
                drawFireworks(context: &context, size: size)
            case .energySymbols:
                drawEnergySymbols(context: &context, size: size)
            case .energyTypeStamp:
                drawEnergySymbols(context: &context, size: size)
                drawLowerTypeStamp(context: &context, size: size)
            case .energyPokeBallStamp:
                drawEnergySymbols(context: &context, size: size)
                drawLowerPokeBallStamp(context: &context, size: size)
            case .energySetStamp:
                drawEnergySymbols(context: &context, size: size)
            case .pokeBallStamp:
                drawStampedBalls(context: &context, size: size)
            case .rocketStamp:
                drawRocketStamps(context: &context, size: size)
            case .pinwheel:
                drawPinwheels(context: &context, size: size)
            case .pokeBallStars:
                drawStampedBalls(context: &context, size: size)
                drawStars(context: &context, size: size, count: 34)
            case .pokeBall3D:
                drawDimensionalBalls(context: &context, size: size)
            case .stampedMirror:
                break // Printed stamp is composited outside the foil light mask.
            case .subjectStamp:
                drawRefractor(context: &context, size: size)
            case .typeSymbols:
                drawTypeSymbols(context: &context, size: size)
            case .sunMoonSymbols:
                drawSunMoonSymbols(context: &context, size: size)
            case .swordShieldTiles:
                drawSwordShieldTiles(context: &context, size: size)
            case .scarletVioletTiles:
                drawScarletVioletTiles(context: &context, size: size)
            case .splitTypeSymbols:
                drawSplitTypeSymbols(context: &context, size: size)
            case .crackedIce:
                if !FoilMaterialCatalog.hasBakedCrackedIceScan(cardID) {
                    drawCrackedIce(context: &context, size: size)
                }
            case .refractor:
                drawRefractor(context: &context, size: size)
            case .stone:
                drawStone(context: &context, size: size)
            case .prime:
                drawPrime(context: &context, size: size)
            case .legend:
                drawLegend(context: &context, size: size)
            case .celebrationSheen:
                drawCelebrationSheen(context: &context, size: size)
            case .aceDiamond:
                drawAceDiamonds(context: &context, size: size)
            case .starSheen:
                drawStarSheen(context: &context, size: size)
            case .doubleRareSheen:
                drawDoubleRareSheen(context: &context, size: size)
            case .teraSheen:
                drawTeraSheen(context: &context, size: size)
            case .vstarSheen:
                drawVSTARSheen(context: &context, size: size)
            case .satin:
                drawSatin(context: &context, size: size)
            case .specialIllustration:
                drawSpecialIllustration(context: &context, size: size)
            case .vmaxRays:
                drawVMAXRays(context: &context, size: size)
            case .line:
                drawEtchedWaves(context: &context, size: size)
            case .crosshatch:
                drawRadiantCrosshatch(context: &context, size: size)
            case .rainbowSplash:
                drawSplash(context: &context, size: size)
            case .rainbow:
                drawRainbowGlitter(context: &context, size: size)
            case .bwGold:
                drawCrackedIce(context: &context, size: size)
            case .xyGold:
                drawDiagonalLines(context: &context, size: size,
                                  spacing: 9, crossing: true)
            case .sunMoonGold:
                drawWaterWeb(context: &context, size: size)
            case .swordShieldGold:
                drawVerticalLines(context: &context, size: size)
                drawStars(context: &context, size: size, count: 18)
            case .scarletVioletGold:
                drawEtchedWaves(context: &context, size: size,
                                opacity: 0.42, lineWidth: 0.78)
            case .teraGold:
                drawEtchedWaves(context: &context, size: size,
                                opacity: 0.42, lineWidth: 0.78)
                drawTeraSheen(context: &context, size: size)
                drawStars(context: &context, size: size, count: 11)
            case .starfield:
                drawStars(context: &context, size: size, count: 42)
            case .shinyGX:
                drawRefractor(context: &context, size: size)
                drawStars(context: &context, size: size, count: 18)
            case .shinyV:
                drawVerticalLines(context: &context, size: size)
                drawStars(context: &context, size: size, count: 24)
            case .shinyVMAX:
                drawVMAXRays(context: &context, size: size)
                drawShinyBurst(context: &context, size: size)
            case .shinyEx:
                drawDoubleRareSheen(context: &context, size: size)
                drawStars(context: &context, size: size, count: 16)
            case .teraShinyEx:
                drawDoubleRareSheen(context: &context, size: size)
                drawTeraSheen(context: &context, size: size, strength: 1.8)
                drawStars(context: &context, size: size, count: 14)
            case .pokeBall:
                drawBallPattern(context: &context, size: size, master: false)
            case .masterBall:
                drawBallPattern(context: &context, size: size, master: true)
            case .confetti:
                drawConfetti(context: &context, size: size)
            case .breakGrid:
                drawBreakGrid(context: &context, size: size)
            case .megaGold:
                drawMegaGold(context: &context, size: size)
            case .monochrome:
                drawMonochromeEtch(context: &context, size: size, polarity: 0)
            case .blackEtched:
                drawMonochromeEtch(context: &context, size: size, polarity: -1)
            case .whiteEtched:
                drawMonochromeEtch(context: &context, size: size, polarity: 1)
            case .comicBurst:
                // Rendered by `MegaAttackMaterialLayer`, which owns separate
                // subject-relief and attack-name-gloss masks.
                break
            case .futuristic:
                drawFuturistic(context: &context, size: size)
            }
        }
    }

    private func drawStarlight(context: inout GraphicsContext, size: CGSize) {
        var random = SeededValues(seed: seed)
        for index in 0..<18 {
            let center = CGPoint(x: (0.13 + random.next() * 0.74) * size.width,
                                 y: (0.16 + random.next() * 0.37) * size.height)
            let radius = 3.5 + random.next() * 11

            // Base/Jungle/Fossil stars are soft silver blooms with an
            // occasional cross flare, not a field of sharp white asterisks.
            let halo = CGRect(x: center.x - radius, y: center.y - radius,
                              width: radius * 2, height: radius * 2)
            context.fill(Path(ellipseIn: halo),
                         with: .radialGradient(
                            Gradient(colors: [
                                .white.opacity(0.34 + random.next() * 0.18),
                                .white.opacity(0.10),
                                .clear,
                            ]), center: center,
                            startRadius: 0, endRadius: radius))

            guard index.isMultiple(of: 3) else { continue }
            var rays = Path()
            for ray in 0..<4 {
                let angle = Double(ray) / 4 * Double.pi * 2
                let inner = radius * 0.18
                rays.move(to: CGPoint(x: center.x + cos(angle) * inner,
                                      y: center.y + sin(angle) * inner))
                rays.addLine(to: CGPoint(x: center.x + cos(angle) * radius * 1.35,
                                         y: center.y + sin(angle) * radius * 1.35))
            }
            context.stroke(rays,
                           with: .color(.white.opacity(index.isMultiple(of: 6)
                            ? 0.43 : 0.29)),
                           lineWidth: index.isMultiple(of: 6) ? 0.84 : 0.64)
        }
    }

    private func drawTinsel(context: inout GraphicsContext, size: CGSize) {
        var random = SeededValues(seed: seed)
        var y: CGFloat = 2
        var row = 0
        while y < size.height {
            var x: CGFloat = -8 + random.next() * 10
            while x < size.width {
                let length = 9 + random.next() * 28
                var strand = Path()
                strand.move(to: CGPoint(x: x, y: y))
                strand.addLine(to: CGPoint(x: min(size.width, x + length), y: y))
                context.stroke(
                    strand,
                    with: .color(.white.opacity(row.isMultiple(of: 3) ? 0.51 : 0.31)),
                    lineWidth: row.isMultiple(of: 4) ? 1.18 : 0.62)
                x += length + 4 + random.next() * 12
            }
            row += 1
            y += row.isMultiple(of: 3) ? 8 : 5
        }
    }

    private func drawSheen(context: inout GraphicsContext, size: CGSize) {
        // XY's sheen is a smooth diagonal diffraction sheet. A handful of
        // wide, low-contrast bands reads closer than an etched line grid.
        for index in 0..<7 {
            let progress = CGFloat(index) / 6
            let offset = -size.height * 0.72
                + progress * (size.width + size.height * 1.45)
            var path = Path()
            path.move(to: CGPoint(x: offset, y: size.height))
            path.addLine(to: CGPoint(x: offset + size.height * 0.78, y: 0))
            context.stroke(path,
                           with: .color(.white.opacity(index.isMultiple(of: 3)
                                ? 0.23 : 0.12)),
                           lineWidth: index.isMultiple(of: 3) ? 9.2 : 4.6)
        }
    }

    private func drawWaterWeb(context: inout GraphicsContext, size: CGSize) {
        // Sun & Moon water-web foil is deliberately irregular. Offset the
        // strands and vary both frequencies so it cannot read as graph paper.
        for row in 0..<15 {
            let baseline = CGFloat(row) / 14 * size.height
            var path = Path()
            path.move(to: CGPoint(x: 0, y: baseline))
            for column in 1...36 {
                let x = CGFloat(column) / 36 * size.width
                let wave = sin(CGFloat(column) * (0.43 + CGFloat(row % 3) * 0.08)
                    + CGFloat(row) * 1.17) * (3.2 + CGFloat(row % 4))
                    + sin(CGFloat(column) * 0.17 + CGFloat(row)) * 2.1
                path.addLine(to: CGPoint(x: x, y: baseline + wave))
            }
            let primaryStrand = row.isMultiple(of: 3)
            context.stroke(path,
                           with: .color(.white.opacity(primaryStrand ? 0.44 : 0.30)),
                           lineWidth: primaryStrand ? 0.85 : 0.68)
        }

        for column in 0..<6 {
            let baseline = CGFloat(column) / 5 * size.width
            var path = Path()
            path.move(to: CGPoint(x: baseline, y: 0))
            for row in 1...34 {
                let y = CGFloat(row) / 34 * size.height
                let wave = sin(CGFloat(row) * 0.39 + CGFloat(column) * 1.31) * 7.0
                path.addLine(to: CGPoint(x: baseline + wave, y: y))
            }
            context.stroke(path, with: .color(.white.opacity(0.16)), lineWidth: 0.56)
        }
    }

    private func drawVerticalLines(context: inout GraphicsContext, size: CGSize) {
        var x: CGFloat = 2
        var column = 0
        while x < size.width {
            var line = Path()
            line.move(to: CGPoint(x: x, y: 0))
            line.addLine(to: CGPoint(x: x, y: size.height))
            context.stroke(line,
                           with: .color(.white.opacity(column.isMultiple(of: 5) ? 0.49 : 0.27)),
                           lineWidth: column.isMultiple(of: 5) ? 1.10 : 0.54)
            column += 1
            x += column.isMultiple(of: 3) ? 7 : 5
        }
    }

    private func drawMirage(context: inout GraphicsContext, size: CGSize) {
        // Modern SV holo uses broad horizontal mirage returns. Keep the sheet
        // neutral; the moving illumination supplies the brief spectrum color.
        for row in 0..<9 {
            let y = (CGFloat(row) + 0.5) / 9 * size.height
            var line = Path()
            line.move(to: CGPoint(x: 0, y: y))
            for column in 1...24 {
                let x = CGFloat(column) / 24 * size.width
                let refraction = sin(CGFloat(column) * 0.48 + CGFloat(row) * 0.71) * 2.4
                line.addLine(to: CGPoint(x: x, y: y + refraction))
            }
            context.stroke(line,
                           with: .color(.white.opacity(row.isMultiple(of: 3)
                                ? 0.24 : 0.135)),
                           lineWidth: row.isMultiple(of: 3) ? 6.0 : 2.9)
        }
    }

    private func drawFireworks(context: inout GraphicsContext, size: CGSize) {
        var random = SeededValues(seed: seed)
        for burst in 0..<11 {
            let center = CGPoint(x: random.next() * size.width,
                                 y: random.next() * size.height)
            let rayCount = 8 + Int(random.next() * 7)
            let radius = 7 + random.next() * 20
            for ray in 0..<rayCount {
                let angle = Double(ray) / Double(rayCount) * Double.pi * 2
                    + random.next() * 0.16
                let start = radius * (0.18 + random.next() * 0.20)
                let end = radius * (0.72 + random.next() * 0.30)
                var path = Path()
                path.move(to: CGPoint(x: center.x + cos(angle) * start,
                                      y: center.y + sin(angle) * start))
                path.addLine(to: CGPoint(x: center.x + cos(angle) * end,
                                         y: center.y + sin(angle) * end))
                context.stroke(path,
                               with: .color(.white.opacity(burst.isMultiple(of: 3) ? 0.48 : 0.31)),
                               lineWidth: 0.65)
            }
        }
    }

    private func drawEnergySymbols(context: inout GraphicsContext, size: CGSize) {
        drawRepeatingCardMotifs(context: &context, size: size,
                                step: max(29, size.width * 0.19),
                                opacity: 0.46)
    }

    private func drawStampedBalls(context: inout GraphicsContext, size: CGSize) {
        let step = max(44, size.width * 0.29)
        let radius = step * 0.26
        var row = 0
        var y = step * 0.52
        while y < size.height + step {
            var x = step * (row.isMultiple(of: 2) ? 0.45 : 0.95)
            while x < size.width + step {
                let circle = CGRect(x: x - radius, y: y - radius,
                                    width: radius * 2, height: radius * 2)
                context.stroke(Path(ellipseIn: circle),
                               with: .color(.white.opacity(0.42)), lineWidth: 0.9)
                var seam = Path()
                seam.move(to: CGPoint(x: x - radius, y: y))
                seam.addLine(to: CGPoint(x: x + radius, y: y))
                context.stroke(seam, with: .color(.white.opacity(0.36)), lineWidth: 0.8)
                context.stroke(Path(ellipseIn: CGRect(x: x - radius * 0.20,
                                                      y: y - radius * 0.20,
                                                      width: radius * 0.40,
                                                      height: radius * 0.40)),
                               with: .color(.white.opacity(0.52)), lineWidth: 0.8)
                x += step
            }
            row += 1
            y += step
        }
    }

    private func drawRocketStamps(context: inout GraphicsContext, size: CGSize) {
        let step = max(42, size.width * 0.27)
        var row = 0
        var y = step * 0.55
        while y < size.height + step {
            var x = step * (row.isMultiple(of: 2) ? 0.45 : 0.95)
            while x < size.width + step {
                let height = step * 0.48
                let width = height * 0.54
                var mark = Path()
                mark.move(to: CGPoint(x: x - width * 0.42, y: y + height * 0.48))
                mark.addLine(to: CGPoint(x: x - width * 0.42, y: y - height * 0.48))
                mark.addLine(to: CGPoint(x: x + width * 0.14, y: y - height * 0.48))
                mark.addQuadCurve(to: CGPoint(x: x + width * 0.14, y: y),
                                  control: CGPoint(x: x + width * 0.62, y: y - height * 0.25))
                mark.addLine(to: CGPoint(x: x - width * 0.38, y: y))
                mark.move(to: CGPoint(x: x, y: y))
                mark.addLine(to: CGPoint(x: x + width * 0.52, y: y + height * 0.48))
                context.stroke(mark, with: .color(.white.opacity(0.46)), lineWidth: 1.0)
                x += step
            }
            row += 1
            y += step
        }
    }

    private func drawPinwheels(context: inout GraphicsContext, size: CGSize) {
        let step = max(34, size.width * 0.22)
        var row = 0
        var y = step * 0.45
        while y < size.height + step {
            var x = step * (row.isMultiple(of: 2) ? 0.45 : 0.95)
            while x < size.width + step {
                let radius = step * 0.29
                for blade in 0..<5 {
                    let angle = Double(blade) / 5 * Double.pi * 2
                    let next = angle + Double.pi * 0.33
                    var path = Path()
                    path.move(to: CGPoint(x: x, y: y))
                    path.addQuadCurve(
                        to: CGPoint(x: x + cos(next) * radius, y: y + sin(next) * radius),
                        control: CGPoint(x: x + cos(angle) * radius, y: y + sin(angle) * radius))
                    context.stroke(path, with: .color(.white.opacity(0.38)), lineWidth: 0.8)
                }
                x += step
            }
            row += 1
            y += step
        }
    }

    private func drawDimensionalBalls(context: inout GraphicsContext, size: CGSize) {
        let step = max(39, size.width * 0.25)
        let radius = step * 0.28
        var row = 0
        var y = step * 0.5
        while y < size.height + step {
            var x = step * (row.isMultiple(of: 2) ? 0.48 : 0.98)
            while x < size.width + step {
                let circle = CGRect(x: x - radius, y: y - radius,
                                    width: radius * 2, height: radius * 2)
                context.stroke(Path(ellipseIn: circle),
                               with: .color(.white.opacity(0.43)), lineWidth: 1.0)
                var equator = Path()
                equator.move(to: CGPoint(x: x - radius, y: y))
                equator.addQuadCurve(to: CGPoint(x: x + radius, y: y),
                                     control: CGPoint(x: x, y: y + radius * 0.34))
                context.stroke(equator, with: .color(.white.opacity(0.37)), lineWidth: 0.8)
                context.fill(Path(ellipseIn: CGRect(x: x - radius * 0.50,
                                                    y: y - radius * 0.58,
                                                    width: radius * 0.43,
                                                    height: radius * 0.27)),
                             with: .color(.white.opacity(0.24)))
                context.stroke(Path(ellipseIn: CGRect(x: x - radius * 0.20,
                                                      y: y - radius * 0.10,
                                                      width: radius * 0.40,
                                                      height: radius * 0.40)),
                               with: .color(.white.opacity(0.51)), lineWidth: 0.8)
                x += step
            }
            row += 1
            y += step
        }
    }

    private func drawLowerTypeStamp(context: inout GraphicsContext, size: CGSize) {
        let elements = motifElements
        let stamp = FoilGeometry.parallelMarkRect(cardID: cardID, in: size)
        let radius = size.width * 0.055
        let gap = radius * 1.25
        for (index, element) in elements.prefix(2).enumerated() {
            let offset = (CGFloat(index) - CGFloat(elements.prefix(2).count - 1) * 0.5) * gap
            drawCardMotif(context: &context,
                          center: CGPoint(x: stamp.midX + offset, y: stamp.midY),
                          radius: radius, element: element,
                          trainer: false, opacity: 0.48)
        }
    }

    private func drawLowerPokeBallStamp(context: inout GraphicsContext, size: CGSize) {
        let stamp = FoilGeometry.parallelMarkRect(cardID: cardID, in: size)
        drawCardMotif(context: &context,
                      center: CGPoint(x: stamp.midX, y: stamp.midY),
                      radius: size.width * 0.075, element: .colorless,
                      trainer: true, opacity: 0.42)
    }

    private var sourceSetID: String {
        cardID.split(separator: "-", maxSplits: 1).first.map(String.init) ?? ""
    }

    private func drawTypeSymbols(context: inout GraphicsContext, size: CGSize) {
        drawRepeatingCardMotifs(context: &context, size: size,
                                step: max(30, size.width * 0.19),
                                opacity: 0.40)
    }

    private func drawSplitTypeSymbols(context: inout GraphicsContext, size: CGSize) {
        var divider = Path()
        divider.move(to: CGPoint(x: -size.width * 0.10, y: size.height * 0.18))
        divider.addLine(to: CGPoint(x: size.width * 1.10, y: size.height * 0.82))
        context.stroke(divider, with: .color(.white.opacity(0.34)), lineWidth: 1.0)

        let step = max(31, size.width * 0.20)
        let elements = motifElements
        var row = 0
        var y = step * 0.45
        while y < size.height + step {
            var column = 0
            var x = step * (row.isMultiple(of: 2) ? 0.42 : 0.92)
            while x < size.width + step {
                let radius = step * 0.22
                let isFirstType = y < size.height * 0.18 + x * 0.64
                let elementIndex = isFirstType ? 0 : min(1, elements.count - 1)
                drawCardMotif(context: &context, center: CGPoint(x: x, y: y),
                              radius: radius, element: elements[elementIndex],
                              trainer: isTrainerMotif, opacity: 0.40)
                column += 1
                x += step
            }
            row += 1
            y += step
        }
    }

    private func drawSunMoonSymbols(context: inout GraphicsContext, size: CGSize) {
        drawRepeatingCardMotifs(context: &context, size: size,
                                step: max(37, size.width * 0.235), opacity: 0.36)
        let largeElement = motifElements[0]
        drawCardMotif(context: &context,
                      center: CGPoint(x: size.width * 0.13, y: size.height * 0.57),
                      radius: size.width * 0.075, element: largeElement,
                      trainer: isTrainerMotif, opacity: 0.30)
    }

    private func drawSwordShieldTiles(context: inout GraphicsContext, size: CGSize) {
        let step = max(25, size.width * 0.16)
        var row = 0
        var y: CGFloat = 0
        while y < size.height + step {
            var column = 0
            var x: CGFloat = row.isMultiple(of: 2) ? 0 : step * 0.5
            while x < size.width + step {
                let radius = step * 0.31
                var chevron = Path()
                chevron.move(to: CGPoint(x: x - radius, y: y + radius * 0.48))
                chevron.addLine(to: CGPoint(x: x, y: y - radius * 0.62))
                chevron.addLine(to: CGPoint(x: x + radius, y: y + radius * 0.48))
                chevron.move(to: CGPoint(x: x - radius * 0.72, y: y + radius))
                chevron.addLine(to: CGPoint(x: x, y: y - radius * 0.03))
                chevron.addLine(to: CGPoint(x: x + radius * 0.72, y: y + radius))
                context.stroke(chevron,
                               with: .color(.white.opacity((row + column).isMultiple(of: 2)
                                    ? 0.33 : 0.20)), lineWidth: 0.62)
                if (row + column).isMultiple(of: 2) {
                    let elements = motifElements
                    drawCardMotif(context: &context, center: CGPoint(x: x, y: y),
                                  radius: radius * 0.42,
                                  element: elements[(row + column) % elements.count],
                                  trainer: isTrainerMotif, opacity: 0.29)
                }
                column += 1
                x += step
            }
            row += 1
            y += step * 0.82
        }
    }

    private func drawScarletVioletTiles(context: inout GraphicsContext, size: CGSize) {
        let step = max(23, size.width * 0.145)
        var row = 0
        var y: CGFloat = 0
        while y < size.height + step {
            var column = 0
            var x: CGFloat = row.isMultiple(of: 2) ? 0 : step * 0.5
            while x < size.width + step {
                let radius = step * 0.42
                let wobble = (row + column).isMultiple(of: 2) ? 0.82 : 1.08
                let pebble = CGRect(x: x - radius * wobble,
                                    y: y - radius / wobble,
                                    width: radius * wobble * 2,
                                    height: radius / wobble * 2)
                context.stroke(Path(ellipseIn: pebble),
                               with: .color(.white.opacity(0.24)), lineWidth: 0.58)
                if (row + column).isMultiple(of: 3) {
                    let elements = motifElements
                    drawCardMotif(context: &context, center: CGPoint(x: x, y: y),
                                  radius: radius * 0.48,
                                  element: elements[(row + column) % elements.count],
                                  trainer: isTrainerMotif, opacity: 0.31)
                }
                column += 1
                x += step
            }
            row += 1
            y += step * 0.72
        }

        drawCardMotif(context: &context,
                      center: CGPoint(x: size.width * 0.12, y: size.height * 0.60),
                      radius: size.width * 0.07, element: motifElements[0],
                      trainer: isTrainerMotif, opacity: 0.26)
    }

    private var isTrainerMotif: Bool {
        visualKind?.supertype == .trainer
    }

    private var motifElements: [CardVisualKind.Element] {
        let types = visualKind?.types ?? []
        return types.isEmpty ? [.colorless] : types
    }

    private func drawRepeatingCardMotifs(
        context: inout GraphicsContext,
        size: CGSize,
        step: CGFloat,
        opacity: Double,
        elements overrideElements: [CardVisualKind.Element]? = nil,
        trainer overrideTrainer: Bool? = nil
    ) {
        let elements = overrideElements ?? motifElements
        let trainer = overrideTrainer ?? isTrainerMotif
        var row = 0
        var y = step * 0.45
        while y < size.height + step {
            var column = 0
            var x = step * (row.isMultiple(of: 2) ? 0.45 : 0.95)
            while x < size.width + step {
                drawCardMotif(
                    context: &context,
                    center: CGPoint(x: x, y: y),
                    radius: step * 0.23,
                    element: elements[(row + column) % elements.count],
                    trainer: trainer,
                    opacity: opacity)
                column += 1
                x += step
            }
            row += 1
            y += step
        }
    }

    private func drawCardMotif(
        context: inout GraphicsContext,
        center: CGPoint,
        radius: CGFloat,
        element: CardVisualKind.Element,
        trainer: Bool,
        opacity: Double
    ) {
        let x = center.x
        let y = center.y
        let stroke = Color.white.opacity(opacity)

        context.stroke(Path(ellipseIn: CGRect(x: x - radius, y: y - radius,
                                              width: radius * 2, height: radius * 2)),
                       with: .color(Color.white.opacity(opacity * 0.68)),
                       lineWidth: 0.66)

        if trainer {
            var ball = Path()
            ball.move(to: CGPoint(x: x - radius, y: y))
            ball.addLine(to: CGPoint(x: x + radius, y: y))
            ball.addEllipse(in: CGRect(x: x - radius * 0.22,
                                       y: y - radius * 0.22,
                                       width: radius * 0.44,
                                       height: radius * 0.44))
            context.stroke(ball, with: .color(stroke), lineWidth: 0.78)
            return
        }

        var glyph = Path()
        switch element {
        case .grass:
            glyph.move(to: CGPoint(x: x - radius * 0.58, y: y + radius * 0.55))
            glyph.addQuadCurve(to: CGPoint(x: x + radius * 0.52, y: y - radius * 0.62),
                               control: CGPoint(x: x + radius * 0.62, y: y + radius * 0.34))
            glyph.addQuadCurve(to: CGPoint(x: x - radius * 0.58, y: y + radius * 0.55),
                               control: CGPoint(x: x - radius * 0.42, y: y - radius * 0.54))
            glyph.move(to: CGPoint(x: x - radius * 0.45, y: y + radius * 0.42))
            glyph.addLine(to: CGPoint(x: x + radius * 0.40, y: y - radius * 0.45))
        case .fire:
            glyph.move(to: CGPoint(x: x - radius * 0.42, y: y + radius * 0.58))
            glyph.addQuadCurve(to: CGPoint(x: x, y: y - radius * 0.72),
                               control: CGPoint(x: x - radius * 0.54, y: y - radius * 0.16))
            glyph.addQuadCurve(to: CGPoint(x: x + radius * 0.50, y: y + radius * 0.54),
                               control: CGPoint(x: x + radius * 0.78, y: y - radius * 0.20))
            glyph.addQuadCurve(to: CGPoint(x: x - radius * 0.42, y: y + radius * 0.58),
                               control: CGPoint(x: x, y: y + radius * 0.26))
        case .water:
            glyph.move(to: CGPoint(x: x, y: y - radius * 0.76))
            glyph.addQuadCurve(to: CGPoint(x: x, y: y + radius * 0.72),
                               control: CGPoint(x: x + radius * 0.90, y: y + radius * 0.12))
            glyph.addQuadCurve(to: CGPoint(x: x, y: y - radius * 0.76),
                               control: CGPoint(x: x - radius * 0.74, y: y + radius * 0.10))
        case .lightning:
            glyph.move(to: CGPoint(x: x + radius * 0.12, y: y - radius * 0.78))
            glyph.addLine(to: CGPoint(x: x - radius * 0.48, y: y + radius * 0.05))
            glyph.addLine(to: CGPoint(x: x - radius * 0.02, y: y - radius * 0.02))
            glyph.addLine(to: CGPoint(x: x - radius * 0.18, y: y + radius * 0.76))
            glyph.addLine(to: CGPoint(x: x + radius * 0.52, y: y - radius * 0.13))
            glyph.addLine(to: CGPoint(x: x + radius * 0.08, y: y - radius * 0.04))
        case .psychic:
            for turn in 0..<3 {
                let r = radius * (0.28 + CGFloat(turn) * 0.18)
                glyph.addArc(center: center, radius: r,
                             startAngle: .degrees(Double(35 + turn * 24)),
                             endAngle: .degrees(Double(305 - turn * 12)),
                             clockwise: false)
            }
        case .fighting:
            glyph.move(to: CGPoint(x: x - radius * 0.62, y: y + radius * 0.46))
            glyph.addLine(to: CGPoint(x: x - radius * 0.48, y: y - radius * 0.20))
            glyph.addLine(to: CGPoint(x: x - radius * 0.12, y: y - radius * 0.52))
            glyph.addLine(to: CGPoint(x: x + radius * 0.52, y: y - radius * 0.20))
            glyph.addLine(to: CGPoint(x: x + radius * 0.62, y: y + radius * 0.42))
            glyph.closeSubpath()
        case .darkness:
            glyph.addArc(center: center, radius: radius * 0.68,
                         startAngle: .degrees(62), endAngle: .degrees(298),
                         clockwise: false)
            glyph.addArc(center: CGPoint(x: x + radius * 0.27, y: y),
                         radius: radius * 0.50,
                         startAngle: .degrees(292), endAngle: .degrees(68),
                         clockwise: true)
        case .metal:
            for point in 0..<6 {
                let angle = Double(point) / 6 * Double.pi * 2 - Double.pi / 2
                let next = Double(point + 1) / 6 * Double.pi * 2 - Double.pi / 2
                glyph.move(to: CGPoint(x: x + cos(angle) * radius * 0.72,
                                       y: y + sin(angle) * radius * 0.72))
                glyph.addLine(to: CGPoint(x: x + cos(next) * radius * 0.72,
                                          y: y + sin(next) * radius * 0.72))
            }
            glyph.addEllipse(in: CGRect(x: x - radius * 0.26, y: y - radius * 0.26,
                                        width: radius * 0.52, height: radius * 0.52))
        case .dragon:
            glyph.move(to: CGPoint(x: x - radius * 0.64, y: y + radius * 0.52))
            glyph.addQuadCurve(to: CGPoint(x: x + radius * 0.56, y: y - radius * 0.52),
                               control: CGPoint(x: x - radius * 0.12, y: y - radius * 0.62))
            glyph.move(to: CGPoint(x: x - radius * 0.46, y: y - radius * 0.48))
            glyph.addQuadCurve(to: CGPoint(x: x + radius * 0.62, y: y + radius * 0.42),
                               control: CGPoint(x: x + radius * 0.08, y: y + radius * 0.58))
        case .fairy:
            glyph.move(to: CGPoint(x: x, y: y - radius * 0.78))
            glyph.addLine(to: CGPoint(x: x + radius * 0.20, y: y - radius * 0.18))
            glyph.addLine(to: CGPoint(x: x + radius * 0.72, y: y))
            glyph.addLine(to: CGPoint(x: x + radius * 0.20, y: y + radius * 0.18))
            glyph.addLine(to: CGPoint(x: x, y: y + radius * 0.78))
            glyph.addLine(to: CGPoint(x: x - radius * 0.20, y: y + radius * 0.18))
            glyph.addLine(to: CGPoint(x: x - radius * 0.72, y: y))
            glyph.addLine(to: CGPoint(x: x - radius * 0.20, y: y - radius * 0.18))
            glyph.closeSubpath()
        case .colorless:
            for ray in 0..<6 {
                let angle = Double(ray) / 6 * Double.pi * 2
                glyph.move(to: CGPoint(x: x + cos(angle) * radius * 0.22,
                                       y: y + sin(angle) * radius * 0.22))
                glyph.addLine(to: CGPoint(x: x + cos(angle) * radius * 0.72,
                                          y: y + sin(angle) * radius * 0.72))
            }
        }
        context.stroke(glyph, with: .color(stroke), lineWidth: 0.74)
    }

    private func drawCrackedIce(context: inout GraphicsContext, size: CGSize) {
        var random = SeededValues(seed: seed)
        let columns = 6
        let rows = 10
        var points: [[CGPoint]] = []
        for row in 0...rows {
            var rowPoints: [CGPoint] = []
            for column in 0...columns {
                let x = CGFloat(column) / CGFloat(columns) * size.width
                    + CGFloat(random.next() - 0.5) * size.width * 0.08
                let y = CGFloat(row) / CGFloat(rows) * size.height
                    + CGFloat(random.next() - 0.5) * size.height * 0.05
                rowPoints.append(CGPoint(x: x, y: y))
            }
            points.append(rowPoints)
        }

        for row in 0..<rows {
            for column in 0..<columns {
                let topLeft = points[row][column]
                let topRight = points[row][column + 1]
                let bottomLeft = points[row + 1][column]
                let bottomRight = points[row + 1][column + 1]
                var shard = Path()
                if (row + column).isMultiple(of: 2) {
                    shard.move(to: topLeft)
                    shard.addLine(to: topRight)
                    shard.addLine(to: bottomLeft)
                    shard.closeSubpath()
                    shard.move(to: topRight)
                    shard.addLine(to: bottomRight)
                    shard.addLine(to: bottomLeft)
                } else {
                    shard.move(to: topLeft)
                    shard.addLine(to: topRight)
                    shard.addLine(to: bottomRight)
                    shard.closeSubpath()
                    shard.move(to: topLeft)
                    shard.addLine(to: bottomRight)
                    shard.addLine(to: bottomLeft)
                }
                context.stroke(shard, with: .color(.white.opacity(0.31)), lineWidth: 0.7)
            }
        }
    }

    private func drawRefractor(context: inout GraphicsContext, size: CGSize) {
        let colors: [Color] = [.cyan, .white, .pink, .yellow, .blue]
        var offset: CGFloat = -size.height
        var stripe = 0
        while offset < size.width + size.height {
            var path = Path()
            path.move(to: CGPoint(x: offset, y: size.height))
            path.addLine(to: CGPoint(x: offset + size.height * 0.68, y: 0))
            context.stroke(path,
                           with: .color(colors[stripe % colors.count].opacity(0.23)),
                           lineWidth: stripe.isMultiple(of: 4) ? 1.5 : 0.65)
            offset += stripe.isMultiple(of: 4) ? 11 : 6
            stripe += 1
        }
    }

    private func drawStone(context: inout GraphicsContext, size: CGSize) {
        var random = SeededValues(seed: seed)
        for index in 0..<54 {
            let center = CGPoint(x: random.next() * size.width,
                                 y: random.next() * size.height)
            let radius = 1 + random.next() * 3.2
            context.fill(Path(ellipseIn: CGRect(x: center.x - radius,
                                                y: center.y - radius * 0.55,
                                                width: radius * 2,
                                                height: radius * 1.1)),
                         with: .color((index.isMultiple(of: 3) ? Color.white : Color.black)
                            .opacity(index.isMultiple(of: 3) ? 0.20 : 0.07)))
        }
        for vein in 0..<10 {
            let startY = CGFloat(vein) / 9 * size.height
            var path = Path()
            path.move(to: CGPoint(x: 0, y: startY))
            for segment in 1...8 {
                let x = CGFloat(segment) / 8 * size.width
                let y = startY + CGFloat(sin(Double(segment) * 1.37 + Double(vein))) * 4.5
                path.addLine(to: CGPoint(x: x, y: y))
            }
            context.stroke(path, with: .color(.black.opacity(0.09)), lineWidth: 0.6)
        }
    }

    private func drawPrime(context: inout GraphicsContext, size: CGSize) {
        let center = CGPoint(x: size.width * 0.52, y: size.height * 0.36)
        let maxRadius = max(size.width, size.height) * 0.82
        for ray in 0..<18 {
            let angle = Double(ray) / 18 * Double.pi * 2
            var path = Path()
            path.move(to: CGPoint(x: center.x + cos(angle) * maxRadius * 0.06,
                                  y: center.y + sin(angle) * maxRadius * 0.06))
            path.addLine(to: CGPoint(x: center.x + cos(angle) * maxRadius,
                                     y: center.y + sin(angle) * maxRadius))
            context.stroke(path,
                           with: .color(.white.opacity(ray.isMultiple(of: 3) ? 0.40 : 0.22)),
                           lineWidth: ray.isMultiple(of: 3) ? 1.10 : 0.58)
        }
        for ring in 1...3 {
            let radius = CGFloat(ring) * min(size.width, size.height) * 0.18
            context.stroke(Path(ellipseIn: CGRect(x: center.x - radius,
                                                  y: center.y - radius,
                                                  width: radius * 2,
                                                  height: radius * 2)),
                           with: .color(.white.opacity(0.19)), lineWidth: 0.6)
        }
    }

    private func drawLegend(context: inout GraphicsContext, size: CGSize) {
        for index in 0..<13 {
            let inset = CGFloat(index) * max(5, size.width * 0.026)
            var sweep = Path()
            sweep.move(to: CGPoint(x: -size.width * 0.12,
                                   y: size.height * 0.10 + inset * 0.18))
            sweep.addQuadCurve(
                to: CGPoint(x: size.width * 1.12,
                            y: size.height * 0.82 - inset * 0.12),
                control: CGPoint(x: size.width * 0.52,
                                 y: size.height * 0.16 + inset))
            context.stroke(sweep,
                           with: .color(.white.opacity(index.isMultiple(of: 3) ? 0.40 : 0.23)),
                           lineWidth: index.isMultiple(of: 3) ? 1.32 : 0.64)
        }
    }

    private func drawCelebrationSheen(context: inout GraphicsContext, size: CGSize) {
        var random = SeededValues(seed: seed)
        for index in 0..<18 {
            let center = CGPoint(x: random.next() * size.width,
                                 y: random.next() * size.height)
            let radius = 1.2 + random.next() * 3.5
            var glint = Path()
            glint.move(to: CGPoint(x: center.x - radius, y: center.y))
            glint.addLine(to: CGPoint(x: center.x + radius, y: center.y))
            if index.isMultiple(of: 3) {
                glint.move(to: CGPoint(x: center.x, y: center.y - radius))
                glint.addLine(to: CGPoint(x: center.x, y: center.y + radius))
            }
            context.stroke(glint, with: .color(.white.opacity(0.38)), lineWidth: 0.70)
        }
    }

    private func drawAceDiamonds(context: inout GraphicsContext, size: CGSize) {
        let step = max(22, size.width * 0.14)
        var row = 0
        var y: CGFloat = 0
        while y < size.height + step {
            var x: CGFloat = row.isMultiple(of: 2) ? 0 : step * 0.5
            while x < size.width + step {
                let radius = step * 0.42
                var diamond = Path()
                diamond.move(to: CGPoint(x: x, y: y - radius))
                diamond.addLine(to: CGPoint(x: x + radius, y: y))
                diamond.addLine(to: CGPoint(x: x, y: y + radius))
                diamond.addLine(to: CGPoint(x: x - radius, y: y))
                diamond.closeSubpath()
                context.stroke(diamond, with: .color(.white.opacity(0.68)), lineWidth: 1.08)
                context.fill(Path(ellipseIn: CGRect(x: x - 1.2, y: y - radius - 1.2,
                                                   width: 2.4, height: 2.4)),
                             with: .color(.white.opacity(0.52)))
                x += step
            }
            row += 1
            y += step * 0.72
        }
    }

    private func drawStarSheen(context: inout GraphicsContext, size: CGSize) {
        // A diffractive star sheet is not an etched diagonal-line sheet.
        // Gold Stars use their source-registered sheet renderer instead.
        drawStars(context: &context, size: size, count: 27)
    }

    private func drawDoubleRareSheen(context: inout GraphicsContext, size: CGSize) {
        var random = SeededValues(seed: seed ^ 0x646F_7562_6C65_7261)
        for index in 0..<18 {
            let center = CGPoint(x: random.next() * size.width,
                                 y: random.next() * size.height)
            let radius = 0.8 + random.next() * 2.7
            var glint = Path()
            glint.move(to: CGPoint(x: center.x - radius, y: center.y))
            glint.addLine(to: CGPoint(x: center.x + radius, y: center.y))
            glint.move(to: CGPoint(x: center.x, y: center.y - radius))
            glint.addLine(to: CGPoint(x: center.x, y: center.y + radius))
            context.stroke(glint,
                           with: .color(.white.opacity(index.isMultiple(of: 5)
                                ? 0.46 : 0.28)), lineWidth: 0.55)
        }
    }

    private func drawTeraSheen(context: inout GraphicsContext, size: CGSize,
                               strength: Double = 1) {
        var random = SeededValues(seed: seed ^ 0x7465_7261_666F_696C)
        let columns = 7
        let rows = 11
        var points: [[CGPoint]] = []
        for row in 0...rows {
            var rowPoints: [CGPoint] = []
            for column in 0...columns {
                let x = CGFloat(column) / CGFloat(columns) * size.width
                    + CGFloat(random.next() - 0.5) * size.width * 0.035
                let y = CGFloat(row) / CGFloat(rows) * size.height
                    + CGFloat(random.next() - 0.5) * size.height * 0.025
                rowPoints.append(CGPoint(x: x, y: y))
            }
            points.append(rowPoints)
        }
        for row in 0..<rows {
            for column in 0..<columns {
                var facet = Path()
                let bottomColumn = column + ((row + column).isMultiple(of: 2) ? 0 : 1)
                facet.move(to: points[row][column])
                facet.addLine(to: points[row][column + 1])
                facet.addLine(to: points[row + 1][bottomColumn])
                context.stroke(facet,
                               with: .color(.white.opacity(0.20 * strength)),
                               lineWidth: 0.45 + 0.20 * strength)
            }
        }
    }

    private func drawVSTARSheen(context: inout GraphicsContext, size: CGSize) {
        var random = SeededValues(seed: seed ^ 0x5653_5441_522D_666F)
        let phase = CGFloat(random.next() * Double.pi * 2)
        for row in 0..<42 {
            let rowProgress = CGFloat(row) / 41
            var flow = Path()
            for column in 0...36 {
                let xProgress = CGFloat(column) / 36
                let x = xProgress * size.width
                let y = rowProgress * size.height
                    + xProgress * size.height * 0.11
                    + sin(xProgress * .pi * 3.1 + phase + CGFloat(row) * 0.11)
                        * size.height * 0.0048
                if column == 0 { flow.move(to: CGPoint(x: x, y: y)) }
                else { flow.addLine(to: CGPoint(x: x, y: y)) }
            }
            context.stroke(flow,
                           with: .color(.white.opacity(row.isMultiple(of: 6)
                                ? 0.32 : 0.17)),
                           lineWidth: row.isMultiple(of: 6) ? 0.58 : 0.30)
        }
    }

    private func drawBreakGrid(context: inout GraphicsContext, size: CGSize) {
        let spacing = max(14, size.width * 0.085)
        var x: CGFloat = 0
        while x < size.width + spacing {
            var line = Path()
            line.move(to: CGPoint(x: x, y: 0))
            line.addLine(to: CGPoint(x: x, y: size.height))
            context.stroke(line, with: .color(.white.opacity(0.24)), lineWidth: 0.55)
            x += spacing
        }
        var y: CGFloat = 0
        while y < size.height + spacing {
            var line = Path()
            line.move(to: CGPoint(x: 0, y: y))
            line.addLine(to: CGPoint(x: size.width, y: y))
            context.stroke(line, with: .color(.white.opacity(0.24)), lineWidth: 0.55)
            y += spacing
        }

        var random = SeededValues(seed: seed)
        for _ in 0..<9 {
            let start = CGPoint(x: random.next() * size.width,
                                y: random.next() * size.height)
            var bolt = Path()
            bolt.move(to: start)
            var point = start
            for _ in 0..<5 {
                point.x += CGFloat(random.next() - 0.28) * size.width * 0.10
                point.y += size.height * 0.035
                bolt.addLine(to: point)
            }
            context.stroke(bolt, with: .color(.white.opacity(0.43)), lineWidth: 1.0)
        }
    }

    private func drawMegaGold(context: inout GraphicsContext, size: CGSize) {
        // MUR uses metallic gold throughout. The circular background relief
        // catches brass shadow on one edge and champagne light on the other;
        // bright RGB foil belongs neither here nor on the silhouette.
        var random = SeededValues(seed: seed ^ 0x6D65_6761_676F_6C64)
        var reliefContext = context
        var illustrationClip = Path()
        illustrationClip.addRect(CGRect(x: size.width * 0.08,
                                       y: size.height * 0.12,
                                       width: size.width * 0.84,
                                       height: size.height * 0.51))
        reliefContext.clip(to: illustrationClip)
        for ring in 0..<12 {
            let radius = size.width * (0.23 + CGFloat(ring) * 0.060
                + CGFloat(random.next() * 0.024))
            let center = CGPoint(
                x: size.width * (0.45 + random.next() * 0.10),
                y: size.height * (0.30 + random.next() * 0.08))
            let ringPhase = random.next() * Double.pi * 2
            let isMajor = ring.isMultiple(of: 5)

            for sector in 0..<7 {
                guard random.next() > 0.58 else { continue }
                let start = ringPhase + Double(sector) * Double.pi * 2 / 7
                    + random.next() * 0.10
                let sweep = (0.34 + random.next() * 0.52) * Double.pi * 2 / 7
                var contour = Path()
                for step in 0...12 {
                    let angle = start + sweep * Double(step) / 12
                    let wave = sin(angle * 3.1 + ringPhase) * Double(size.width) * 0.004
                    let localRadius = Double(radius) + wave
                    let point = CGPoint(
                        x: center.x + cos(angle) * localRadius,
                        y: center.y + sin(angle) * localRadius * 0.88)
                    if step == 0 { contour.move(to: point) }
                    else { contour.addLine(to: point) }
                }

                let shadow = contour.applying(CGAffineTransform(
                    translationX: 0, y: 0.72))
                reliefContext.stroke(shadow,
                    with: .color(Color(red: 0.40, green: 0.20, blue: 0.015)
                        .opacity(isMajor ? 0.51 : 0.28)),
                    lineWidth: isMajor ? 0.96 : 0.55)
                reliefContext.stroke(contour,
                    with: .color(Color(red: 1.0, green: 0.93, blue: 0.58)
                        .opacity(isMajor ? 0.86 : 0.48)),
                    lineWidth: isMajor ? 1.0 : 0.55)
            }
        }

        // Dense, directional metal grain breaks up the featureless yellow
        // scan without placing a moving color film over it. Small angled
        // strokes merge into a brushed surface at the actual detail size.
        var brassGrain = Path()
        var champagneGrain = Path()
        for _ in 0..<3_200 {
            let x = random.next() * size.width
            let y = random.next() * size.height
            let onSubject = x > size.width * 0.29 && x < size.width * 0.71
                && y > size.height * 0.17 && y < size.height * 0.49
            if onSubject && random.next() < 0.55 { continue }
            if y > size.height * 0.62 && random.next() < 0.26 { continue }

            let normalizedX = Double(x / size.width)
            let normalizedY = Double(y / size.height)
            let wavePhase = normalizedX * Double.pi * 3.0 + normalizedY * Double.pi * 2.0
            let waveAngle = sin(wavePhase) * 0.18
            let jitter = (random.next() - 0.5) * 0.42
            let angle: Double = -0.40 + waveAngle + jitter
            let length = 2.4 + random.next() * 7.6
            let dx = CGFloat(cos(angle) * length * 0.5)
            let dy = CGFloat(sin(angle) * length * 0.5)
            brassGrain.move(to: CGPoint(x: x - dx, y: y - dy + 0.55))
            brassGrain.addLine(to: CGPoint(x: x + dx, y: y + dy + 0.55))
            champagneGrain.move(to: CGPoint(x: x - dx, y: y - dy))
            champagneGrain.addLine(to: CGPoint(x: x + dx, y: y + dy))
        }
        context.stroke(brassGrain,
                       with: .color(Color(red: 0.43, green: 0.24, blue: 0.025)
                        .opacity(0.48)), lineWidth: 0.82)
        context.stroke(champagneGrain,
                       with: .color(Color(red: 1.0, green: 0.92, blue: 0.55)
                        .opacity(0.60)), lineWidth: 0.76)

        for index in 0..<360 {
            let point = CGPoint(x: random.next() * size.width,
                                y: random.next() * size.height)
            let nx = point.x / size.width
            let ny = point.y / size.height
            guard !(nx > 0.29 && nx < 0.71 && ny > 0.17 && ny < 0.49) else {
                continue
            }
            let radius = 0.55 + random.next() * 1.25
            context.fill(Path(ellipseIn: CGRect(x: point.x - radius,
                                                y: point.y - radius,
                                                width: radius * 2,
                                                height: radius * 2)),
                         with: .color(Color(red: 1.0, green: 0.95, blue: 0.65)
                            .opacity(index.isMultiple(of: 8) ? 0.72 : 0.42)))
        }
    }

    private func drawMonochromeEtch(context: inout GraphicsContext, size: CGSize,
                                    polarity: Int) {
        var random = SeededValues(seed: seed ^ 0x4257_522D_4554_4348)
        let phase = CGFloat(random.next() * Double.pi * 2)
        let rowCount = polarity > 0 ? 26 : 54
        for row in 0..<rowCount {
            let progress = CGFloat(row) / CGFloat(rowCount - 1)
            var path = Path()
            var reliefShadow = Path()
            for column in 0...42 {
                let xProgress = CGFloat(column) / 42
                let x = (polarity > 0 ? 0.08 + xProgress * 0.84 : xProgress)
                    * size.width
                let wave = sin(xProgress * .pi * 3.6 + phase
                    + CGFloat(row) * 0.145) * size.height
                        * (polarity > 0 ? 0.017 : 0.007)
                    + sin(xProgress * .pi * 11 + CGFloat(row) * 0.09)
                        * size.height * (polarity > 0 ? 0.0038 : 0.0018)
                let y = (polarity > 0 ? 0.13 + progress * 0.69 : progress)
                    * size.height + wave
                if column == 0 {
                    path.move(to: CGPoint(x: x, y: y))
                    reliefShadow.move(to: CGPoint(x: x, y: y + 0.45))
                } else {
                    path.addLine(to: CGPoint(x: x, y: y))
                    reliefShadow.addLine(to: CGPoint(x: x, y: y + 0.45))
                }
            }
            if polarity > 0 && row.isMultiple(of: 5) {
                // A pale embossed card needs a dark lower edge to reveal its
                // relief. Interrupt the shadow so it cannot read as uniform
                // screen scanlines on the white printing.
                context.stroke(reliefShadow,
                               with: .color(Color(white: 0.35).opacity(0.23)),
                               style: StrokeStyle(lineWidth: 0.70,
                                                  dash: [12, 7],
                                                  dashPhase: CGFloat(row % 5) * 2))
            }
            let base = polarity > 0 ? 0.36 : (polarity < 0 ? 0.34 : 0.28)
            context.stroke(path,
                           with: .color(.white.opacity(row.isMultiple(of: 7)
                                ? base + 0.17 : base)),
                           lineWidth: row.isMultiple(of: 7)
                                ? (polarity > 0 ? 0.84 : 0.62)
                                : (polarity > 0 ? 0.50 : 0.33))
        }
    }

    private func drawFuturistic(context: inout GraphicsContext, size: CGSize) {
        // Future Rare combines a metallic subject with the ten Energy emblems
        // around a faint Poké Ball field. Keep all geometry card-locked.
        let center = CGPoint(x: size.width * 0.50, y: size.height * 0.42)
        let radius = min(size.width, size.height) * 0.30
        context.stroke(Path(ellipseIn: CGRect(x: center.x - radius,
                                              y: center.y - radius,
                                              width: radius * 2,
                                              height: radius * 2)),
                       with: .color(.white.opacity(0.20)), lineWidth: 1.1)
        var seam = Path()
        seam.move(to: CGPoint(x: center.x - radius, y: center.y))
        seam.addLine(to: CGPoint(x: center.x + radius, y: center.y))
        context.stroke(seam, with: .color(.white.opacity(0.22)), lineWidth: 1.0)
        context.stroke(Path(ellipseIn: CGRect(x: center.x - radius * 0.18,
                                              y: center.y - radius * 0.18,
                                              width: radius * 0.36,
                                              height: radius * 0.36)),
                       with: .color(.white.opacity(0.28)), lineWidth: 0.9)
        drawRepeatingCardMotifs(context: &context, size: size,
                                step: max(31, size.width * 0.20),
                                opacity: 0.34,
                                elements: CardVisualKind.Element.allCases,
                                trainer: false)
    }

    private func drawSatin(context: inout GraphicsContext, size: CGSize) {
        var offset: CGFloat = -size.height
        var index = 0
        while offset < size.width + size.height {
            var thread = Path()
            thread.move(to: CGPoint(x: offset, y: 0))
            thread.addLine(to: CGPoint(x: offset + size.height * 0.44, y: size.height))
            context.stroke(thread,
                           with: .color(.white.opacity(index.isMultiple(of: 7) ? 0.31 : 0.16)),
                           lineWidth: index.isMultiple(of: 7) ? 0.75 : 0.35)
            offset += 4.5
            index += 1
        }
    }

    /// Fine, card-seeded flow etching for Special Illustration Rares. Geometry
    /// stays fixed to the card; only light in `SpecialIllustrationPatternLayer`
    /// moves across these ridges.
    private func drawSpecialIllustration(context: inout GraphicsContext,
                                         size: CGSize) {
        var random = SeededValues(seed: seed ^ 0xA57A_11E7_C01D_F011)
        let geometry = SpecialIllustrationRelief.Geometry(
            phase: CGFloat(random.next() * Double.pi * 2),
            slope: CGFloat(random.next() - 0.5) * size.height * 0.065)

        for row in 0..<SpecialIllustrationRelief.rowCount {
            var contour = Path()

            for column in 0...56 {
                let progress = CGFloat(column) / 56
                let point = SpecialIllustrationRelief.point(
                    row: row, progress: progress, size: size, geometry: geometry)

                if column == 0 {
                    contour.move(to: point)
                } else {
                    contour.addLine(to: point)
                }
            }

            let shadow = contour.applying(CGAffineTransform(translationX: 0, y: 0.48))
            context.stroke(shadow, with: .color(.black.opacity(0.18)), lineWidth: 0.34)

            let isHighlightThread = row.isMultiple(of: 7)
            context.stroke(
                contour,
                with: .color(isHighlightThread
                    ? .white.opacity(0.52)
                    : .white.opacity(0.30)),
                lineWidth: isHighlightThread ? 0.58 : 0.31)
        }

        // The physical SIR foil reads as dense pearlescent grain, not isolated
        // star sprites. Tiny points become visible only when the moving band
        // lights this fixed mask.
        for index in 0..<150 {
            let center = CGPoint(x: random.next() * size.width,
                                 y: random.next() * size.height)
            let radius = 0.28 + random.next() * 0.72
            let grain = CGRect(x: center.x - radius, y: center.y - radius,
                               width: radius * 2, height: radius * 2)
            context.fill(Path(ellipseIn: grain),
                         with: .color(.white.opacity(index.isMultiple(of: 11)
                             ? 0.62 : 0.31)))
        }
    }

    private func drawVMAXRays(context: inout GraphicsContext, size: CGSize) {
        // VMAX texture follows the illustration rather than emitting a common
        // starburst. Seeded, slow contour sweeps avoid assigning every card the
        // same invented focal point while retaining its strong full-face flow.
        var random = SeededValues(seed: seed ^ 0x564D_4158_666C_6F77)
        let phase = CGFloat(random.next() * Double.pi * 2)
        for row in 0..<34 {
            let rowProgress = CGFloat(row) / 33
            var sweep = Path()
            for column in 0...38 {
                let xProgress = CGFloat(column) / 38
                let x = xProgress * size.width
                let y = rowProgress * size.height
                    + sin(xProgress * .pi * 2.7 + phase + CGFloat(row) * 0.15)
                        * size.height * 0.010
                    + sin(xProgress * .pi * 7.5 - phase) * size.height * 0.0025
                if column == 0 { sweep.move(to: CGPoint(x: x, y: y)) }
                else { sweep.addLine(to: CGPoint(x: x, y: y)) }
            }
            context.stroke(sweep,
                           with: .color(.white.opacity(row.isMultiple(of: 5)
                                ? 0.34 : 0.17)),
                           lineWidth: row.isMultiple(of: 5) ? 0.70 : 0.34)
        }
    }

    private func drawShinyBurst(context: inout GraphicsContext, size: CGSize) {
        var random = SeededValues(seed: seed ^ 0x5348_494E_5956_4D58)
        let center = CGPoint(x: size.width * (0.42 + random.next() * 0.16),
                             y: size.height * (0.26 + random.next() * 0.18))
        let radius = max(size.width, size.height) * 0.82
        for ray in 0..<22 {
            let angle = Double(ray) / 22 * Double.pi * 2
                + (random.next() - 0.5) * 0.08
            let inset = radius * (0.04 + random.next() * 0.08)
            var path = Path()
            path.move(to: CGPoint(x: center.x + cos(angle) * inset,
                                  y: center.y + sin(angle) * inset))
            path.addLine(to: CGPoint(x: center.x + cos(angle) * radius,
                                     y: center.y + sin(angle) * radius))
            context.stroke(path,
                           with: .color(.white.opacity(ray.isMultiple(of: 4)
                                ? 0.39 : 0.18)),
                           lineWidth: ray.isMultiple(of: 4) ? 0.82 : 0.38)
        }
        drawStars(context: &context, size: size, count: 20)
    }

    private func drawCosmos(context: inout GraphicsContext, size: CGSize) {
        var random = SeededValues(seed: seed)
        for index in 0..<32 {
            let radius = 0.9 + random.next() * 5.6
            let center = CGPoint(x: (0.13 + random.next() * 0.74) * size.width,
                                 y: (0.16 + random.next() * 0.37) * size.height)
            let rect = CGRect(x: center.x - radius, y: center.y - radius,
                              width: radius * 2, height: radius * 2)
            if index.isMultiple(of: 3) {
                context.stroke(Path(ellipseIn: rect),
                               with: .color(.white.opacity(0.49)),
                               lineWidth: max(0.45, radius * 0.18))
            } else {
                context.fill(Path(ellipseIn: rect),
                             with: .color(.white.opacity(0.27 + random.next() * 0.31)))
            }
            if index.isMultiple(of: 7) {
                var star = Path()
                star.move(to: CGPoint(x: center.x - radius * 1.8, y: center.y))
                star.addLine(to: CGPoint(x: center.x + radius * 1.8, y: center.y))
                star.move(to: CGPoint(x: center.x, y: center.y - radius * 1.8))
                star.addLine(to: CGPoint(x: center.x, y: center.y + radius * 1.8))
                context.stroke(star, with: .color(.white.opacity(0.62)), lineWidth: 0.72)
            }
        }

        // Cosmos sheets are identifiable by a few sparse spiral swirls.
        for swirl in 0..<3 {
            let center = CGPoint(x: (0.18 + random.next() * 0.64) * size.width,
                                 y: (0.20 + random.next() * 0.28) * size.height)
            var spiral = Path()
            for step in 0...48 {
                let progress = CGFloat(step) / 48
                let angle = progress * .pi * 4.4 + CGFloat(swirl) * 0.8
                let radius = progress * (8 + CGFloat(swirl) * 2.2)
                let point = CGPoint(x: center.x + cos(angle) * radius,
                                    y: center.y + sin(angle) * radius)
                if step == 0 { spiral.move(to: point) } else { spiral.addLine(to: point) }
            }
            context.stroke(spiral, with: .color(.white.opacity(0.40)), lineWidth: 0.72)
        }
    }

    private func drawDiagonalLines(context: inout GraphicsContext, size: CGSize,
                                   spacing: CGFloat, crossing: Bool) {
        let limit = size.width + size.height
        var offset: CGFloat = -size.height
        while offset < limit {
            var path = Path()
            path.move(to: CGPoint(x: offset, y: 0))
            path.addLine(to: CGPoint(x: offset - size.height, y: size.height))
            context.stroke(path, with: .color(.white.opacity(0.38)), lineWidth: 0.7)
            if crossing {
                var cross = Path()
                cross.move(to: CGPoint(x: offset, y: 0))
                cross.addLine(to: CGPoint(x: offset + size.height, y: size.height))
                context.stroke(cross, with: .color(.white.opacity(0.28)), lineWidth: 0.7)
            }
            offset += spacing
        }
    }

    private func drawRadiantCrosshatch(context: inout GraphicsContext, size: CGSize) {
        // Radiant's criss-cross sheet needs two-sided etched relief to survive
        // the 200pt detail view. Its blue rule/text field catches much more
        // foil than the printed artwork; the yellow border remains paper.
        let spacing: CGFloat = 11
        var rising = Path()
        var falling = Path()
        var offset = -size.height
        while offset < size.width + size.height {
            rising.move(to: CGPoint(x: offset, y: 0))
            rising.addLine(to: CGPoint(x: offset + size.height, y: size.height))
            falling.move(to: CGPoint(x: offset, y: 0))
            falling.addLine(to: CGPoint(x: offset - size.height, y: size.height))
            offset += spacing
        }

        let artwork = FoilGeometry.artRect(cardID: cardID, in: size)
        var illustrationContext = context
        var artworkClip = Path()
        artworkClip.addRect(artwork)
        illustrationContext.clip(to: artworkClip)
        illustrationContext.stroke(rising,
                                   with: .color(.white.opacity(0.23)), lineWidth: 0.70)
        illustrationContext.stroke(falling,
                                   with: .color(.white.opacity(0.19)), lineWidth: 0.70)

        let inner = CGRect(origin: .zero, size: size).insetBy(dx: size.width * 0.055, dy: size.height * 0.03)
        let brightRegions = [
            CGRect(x: inner.minX, y: inner.minY, width: inner.width, height: max(0, artwork.minY - inner.minY)),
            CGRect(x: inner.minX, y: artwork.maxY, width: inner.width, height: max(0, inner.maxY - artwork.maxY)),
            CGRect(x: inner.minX, y: artwork.minY, width: max(0, artwork.minX - inner.minX), height: artwork.height),
            CGRect(x: artwork.maxX, y: artwork.minY, width: max(0, inner.maxX - artwork.maxX), height: artwork.height),
        ]
        for region in brightRegions {
            var frameContext = context
            var clip = Path()
            clip.addRect(region)
            frameContext.clip(to: clip)
            frameContext.stroke(rising.applying(CGAffineTransform(
                translationX: 0, y: 0.65)),
                with: .color(.black.opacity(0.25)), lineWidth: 1.05)
            frameContext.stroke(falling.applying(CGAffineTransform(
                translationX: 0, y: 0.65)),
                with: .color(.black.opacity(0.25)), lineWidth: 1.05)
            frameContext.stroke(rising,
                                with: .color(.white.opacity(0.64)), lineWidth: 0.95)
            frameContext.stroke(falling,
                                with: .color(.white.opacity(0.54)), lineWidth: 0.95)
        }
    }

    private func drawEtchedWaves(context: inout GraphicsContext, size: CGSize,
                                 opacity: Double = 0.34,
                                 lineWidth: CGFloat = 0.65) {
        for row in 0..<26 {
            let y = CGFloat(row) / 25 * size.height
            var path = Path()
            path.move(to: CGPoint(x: 0, y: y))
            for column in 1...20 {
                let x = CGFloat(column) / 20 * size.width
                let wave = sin(CGFloat(column) * 0.9 + CGFloat(row) * 0.55) * 4
                path.addLine(to: CGPoint(x: x, y: y + wave))
            }
            context.stroke(path, with: .color(.white.opacity(opacity)),
                           lineWidth: lineWidth)
        }
    }

    private func drawSplash(context: inout GraphicsContext, size: CGSize) {
        var random = SeededValues(seed: seed ^ 0x414D_415A_494E_4721)
        // The unique rainbow splash is printed into every Amazing Rare scan.
        // A generated blob mask would assign the same fake splash to all nine
        // cards, so the optical layer is only quiet full-face pearly grain.
        for index in 0..<120 {
            let radius = 0.35 + random.next() * 1.25
            let x = random.next() * size.width
            let y = random.next() * size.height
            context.fill(Path(ellipseIn: CGRect(x: x - radius, y: y - radius,
                                                width: radius * 2, height: radius * 2)),
                         with: .color(.white.opacity(index.isMultiple(of: 9)
                            ? 0.34 : 0.14)))
        }

        // Energy-cost and rarity symbols also catch the textured sheet. Keep
        // these as tiny fixed glints rather than another coloured illustration.
        let symbolCenters = [
            CGPoint(x: size.width * 0.17, y: size.height * 0.73),
            CGPoint(x: size.width * 0.23, y: size.height * 0.73),
            CGPoint(x: size.width * 0.83, y: size.height * 0.94),
        ]
        for center in symbolCenters {
            for radius in [CGFloat(2.8), CGFloat(1.2)] {
                var glint = Path()
                glint.move(to: CGPoint(x: center.x - radius, y: center.y))
                glint.addLine(to: CGPoint(x: center.x + radius, y: center.y))
                glint.move(to: CGPoint(x: center.x, y: center.y - radius))
                glint.addLine(to: CGPoint(x: center.x, y: center.y + radius))
                context.stroke(glint,
                               with: .color(.white.opacity(radius > 2 ? 0.44 : 0.30)),
                               lineWidth: radius > 2 ? 0.62 : 0.38)
            }
        }
    }

    private func drawRainbowGlitter(context: inout GraphicsContext, size: CGSize) {
        var random = SeededValues(seed: seed ^ 0x5241_494E_424F_5721)
        // Rainbow Rare colour already belongs to the scan. The physical sheet
        // contributes fine neutral glitter above the embossed flow, not a
        // second full-card RGB gradient.
        for index in 0..<190 {
            let center = CGPoint(x: random.next() * size.width,
                                 y: random.next() * size.height)
            let radius = 0.22 + random.next() * 0.70
            context.fill(Path(ellipseIn: CGRect(x: center.x - radius,
                                                y: center.y - radius,
                                                width: radius * 2,
                                                height: radius * 2)),
                         with: .color(.white.opacity(index.isMultiple(of: 13)
                            ? 0.46 : 0.20)))
        }
    }

    private func drawSpectrumGrain(context: inout GraphicsContext, size: CGSize) {
        // Generic silver full-art foil has pearly micro-facets, not a broad
        // moving rainbow panel. The card image supplies its printed color.
        var random = SeededValues(seed: seed ^ 0x5350_4543_5452_554D)
        var facets = Path()
        for _ in 0..<520 {
            let x = random.next() * size.width
            let y = random.next() * size.height
            let radius = 0.28 + random.next() * 0.85
            facets.addEllipse(in: CGRect(x: x - radius, y: y - radius,
                                         width: radius * 2, height: radius * 2))
        }
        context.fill(facets, with: .color(.white.opacity(0.48)))
    }

    private func drawStars(context: inout GraphicsContext, size: CGSize, count: Int) {
        var random = SeededValues(seed: seed)
        for _ in 0..<count {
            let center = CGPoint(x: random.next() * size.width,
                                 y: random.next() * size.height)
            let radius = 1 + random.next() * 3.5
            var path = Path()
            path.move(to: CGPoint(x: center.x - radius, y: center.y))
            path.addLine(to: CGPoint(x: center.x + radius, y: center.y))
            path.move(to: CGPoint(x: center.x, y: center.y - radius))
            path.addLine(to: CGPoint(x: center.x, y: center.y + radius))
            context.stroke(path, with: .color(.white.opacity(0.45 + random.next() * 0.45)),
                           lineWidth: 0.8)
        }
    }

    private func drawBallPattern(context: inout GraphicsContext, size: CGSize, master: Bool) {
        let step = max(34, size.width * 0.22)
        let radius = step * 0.29
        var row = 0
        var y = radius
        while y < size.height + radius {
            var x = radius + (row.isMultiple(of: 2) ? 0 : step * 0.5)
            while x < size.width + radius {
                let circle = CGRect(x: x - radius, y: y - radius,
                                    width: radius * 2, height: radius * 2)
                context.stroke(Path(ellipseIn: circle),
                               with: .color(.white.opacity(master ? 0.70 : 0.50)), lineWidth: 1.20)
                var seam = Path()
                seam.move(to: CGPoint(x: x - radius, y: y))
                seam.addLine(to: CGPoint(x: x + radius, y: y))
                context.stroke(seam, with: .color(.white.opacity(0.52)), lineWidth: 0.95)
                context.stroke(Path(ellipseIn: CGRect(x: x - radius * 0.22,
                                                      y: y - radius * 0.22,
                                                      width: radius * 0.44,
                                                      height: radius * 0.44)),
                               with: .color(.white.opacity(0.69)), lineWidth: 0.95)
                if master {
                    let labelY = y - radius * 0.46
                    var monogram = Path()
                    monogram.move(to: CGPoint(x: x - radius * 0.48, y: labelY + radius * 0.20))
                    monogram.addLine(to: CGPoint(x: x - radius * 0.48, y: labelY - radius * 0.20))
                    monogram.addLine(to: CGPoint(x: x, y: labelY + radius * 0.10))
                    monogram.addLine(to: CGPoint(x: x + radius * 0.48,
                                                 y: labelY - radius * 0.20))
                    monogram.addLine(to: CGPoint(x: x + radius * 0.48,
                                                 y: labelY + radius * 0.20))
                    context.stroke(monogram,
                                   with: .color(Color(red: 0.88, green: 0.78, blue: 1.0)
                                    .opacity(0.96)),
                                   style: StrokeStyle(lineWidth: 1.75,
                                                      lineCap: .round, lineJoin: .round))
                }
                x += step
            }
            row += 1
            y += step
        }
    }

    private func drawConfetti(context: inout GraphicsContext, size: CGSize) {
        var random = SeededValues(seed: seed)
        let colors: [Color] = [.white, .cyan, .yellow, .pink]
        let artwork = FoilGeometry.artRect(cardID: cardID, in: size)
        // Classic Collection's block confetti reads strongest in the artwork;
        // keep the rules text low-contrast rather than blanketing it uniformly.
        for index in 0..<72 {
            let side = 2.4 + random.next() * 4.6
            let rect = CGRect(x: artwork.minX + random.next() * max(0, artwork.width - side),
                              y: artwork.minY + random.next() * max(0, artwork.height - side),
                              width: side, height: side)
            context.fill(Path(rect.offsetBy(dx: 0.65, dy: 0.75)),
                         with: .color(.black.opacity(0.22)))
            context.fill(Path(rect),
                         with: .color(colors[index % colors.count].opacity(0.58)))
            var ridge = Path()
            ridge.move(to: CGPoint(x: rect.minX, y: rect.minY))
            ridge.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
            ridge.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            context.stroke(ridge, with: .color(.white.opacity(0.38)), lineWidth: 0.45)
        }
        for _ in 0..<32 {
            let side = 0.7 + random.next() * 1.3
            let rect = CGRect(x: random.next() * size.width,
                              y: random.next() * size.height,
                              width: side, height: side)
            context.fill(Path(rect), with: .color(.white.opacity(0.18)))
        }
    }

}

// MARK: - Finish texture

@MainActor
private struct FinishTextureLayer: View {
    let texture: FoilTexture
    let seed: UInt64
    let highlight: CGPoint
    let tiltMagnitude: Double
    let width: CGFloat
    let response: Double
    let flashGain: Double

    var body: some View {
        ZStack {
            textureCanvas
                .blendMode(.softLight)
                .opacity(0.42 * response)

            RadialGradient(stops: [
                .init(color: reflectedThreadColor.opacity(0.92), location: 0),
                .init(color: .white.opacity(0.70), location: 0.24),
                .init(color: reflectedThreadColor.opacity(0.26), location: 0.58),
                .init(color: .clear, location: 1),
            ], center: UnitPoint(x: highlight.x, y: highlight.y),
               startRadius: 0, endRadius: width * 0.49)
                .mask { textureCanvas }
                .blendMode(.plusLighter)
                .opacity(min(0.96, response * flashGain)
                    * (0.88 + 0.12 * tiltMagnitude))
        }
    }

    private var textureCanvas: some View {
        Canvas { context, size in
            switch texture {
            case .none, .paper:
                break
            case .fineLines:
                drawLines(context: &context, size: size, spacing: 8, crossing: false)
            case .etched:
                drawFlowEtch(context: &context, size: size)
            case .bwEtched:
                drawEraFlowEtch(context: &context, size: size, rows: 40,
                                cycles: 3.1, amplitude: 0.0080,
                                slopeScale: 0.025, majorEvery: 5,
                                salt: 0x4257_2D45_5443_4801)
            case .xyEtched:
                drawEraFlowEtch(context: &context, size: size, rows: 44,
                                cycles: 4.7, amplitude: 0.0072,
                                slopeScale: 0.085, majorEvery: 5,
                                salt: 0x5859_2D45_5443_4802)
            case .sunMoonEtched:
                drawSunMoonEtch(context: &context, size: size)
            case .swordShieldEtched:
                drawEraFlowEtch(context: &context, size: size, rows: 58,
                                cycles: 5.6, amplitude: 0.0048,
                                slopeScale: 0.055, majorEvery: 7,
                                salt: 0x5357_5348_4554_4304)
            case .scarletVioletEtched:
                drawEraFlowEtch(context: &context, size: size, rows: 72,
                                cycles: 7.2, amplitude: 0.0030,
                                slopeScale: 0.028, majorEvery: 9,
                                salt: 0x5356_2D45_5443_4805)
            case .crosshatch:
                drawLines(context: &context, size: size, spacing: 10, crossing: true)
            case .embossed:
                drawEmbossed(context: &context, size: size)
            case .shatteredGlass:
                drawShards(context: &context, size: size)
            }
        }
    }

    private var reflectedThreadColor: Color {
        switch texture {
        case .bwEtched, .xyEtched:
            Color(red: 1.0, green: 0.88, blue: 0.66)
        case .sunMoonEtched:
            Color(red: 0.89, green: 0.82, blue: 0.97)
        case .swordShieldEtched:
            Color(red: 0.78, green: 0.91, blue: 0.98)
        case .scarletVioletEtched:
            Color(red: 0.78, green: 0.96, blue: 0.91)
        default:
            Color(white: 0.96)
        }
    }

    private func drawLines(context: inout GraphicsContext, size: CGSize,
                           spacing: CGFloat, crossing: Bool) {
        var offset: CGFloat = -size.height
        while offset < size.width + size.height {
            var path = Path()
            path.move(to: CGPoint(x: offset, y: 0))
            path.addLine(to: CGPoint(x: offset + size.height * 0.58, y: size.height))
            context.stroke(path, with: .color(.white.opacity(0.42)), lineWidth: 0.45)
            if crossing {
                var cross = Path()
                cross.move(to: CGPoint(x: offset, y: 0))
                cross.addLine(to: CGPoint(x: offset - size.height * 0.58, y: size.height))
                context.stroke(cross, with: .color(.black.opacity(0.22)), lineWidth: 0.4)
            }
            offset += spacing
        }
    }

    private func drawFlowEtch(context: inout GraphicsContext, size: CGSize) {
        var random = SeededValues(seed: seed ^ 0x6574_6368_666C_6F77)
        let phase = CGFloat(random.next() * Double.pi * 2)
        let slope = CGFloat(random.next() - 0.5) * size.height * 0.05
        for row in 0..<48 {
            let progress = CGFloat(row) / 47
            var contour = Path()
            for column in 0...40 {
                let xProgress = CGFloat(column) / 40
                let x = xProgress * size.width
                let y = progress * size.height
                    + sin(xProgress * .pi * 4 + phase + CGFloat(row) * 0.13)
                        * size.height * 0.006
                    + (xProgress - 0.5) * slope
                if column == 0 { contour.move(to: CGPoint(x: x, y: y)) }
                else { contour.addLine(to: CGPoint(x: x, y: y)) }
            }
            let shadow = contour.applying(CGAffineTransform(translationX: 0, y: 0.42))
            context.stroke(shadow, with: .color(.black.opacity(0.18)), lineWidth: 0.30)
            context.stroke(contour,
                           with: .color(.white.opacity(row.isMultiple(of: 7)
                                ? 0.48 : 0.31)),
                           lineWidth: row.isMultiple(of: 7) ? 0.54 : 0.30)
        }
    }

    private func drawEraFlowEtch(
        context: inout GraphicsContext,
        size: CGSize,
        rows: Int,
        cycles: CGFloat,
        amplitude: CGFloat,
        slopeScale: CGFloat,
        majorEvery: Int,
        salt: UInt64
    ) {
        var random = SeededValues(seed: seed ^ salt)
        let phase = CGFloat(random.next() * Double.pi * 2)
        let slope = CGFloat(random.next() - 0.5) * size.height * slopeScale
        let rowDenominator = CGFloat(max(1, rows - 1))

        for row in 0..<rows {
            let progress = CGFloat(row) / rowDenominator
            var contour = Path()
            for column in 0...44 {
                let xProgress = CGFloat(column) / 44
                let x = xProgress * size.width
                let primary = sin(xProgress * .pi * cycles + phase
                    + CGFloat(row) * 0.12) * size.height * amplitude
                let secondary = sin(xProgress * .pi * (cycles * 2.35) - phase * 0.4
                    + CGFloat(row) * 0.19) * size.height * amplitude * 0.26
                let y = progress * size.height + primary + secondary
                    + (xProgress - 0.5) * slope
                if column == 0 { contour.move(to: CGPoint(x: x, y: y)) }
                else { contour.addLine(to: CGPoint(x: x, y: y)) }
            }

            let isMajor = row.isMultiple(of: majorEvery)
            let shadow = contour.applying(CGAffineTransform(
                translationX: 0, y: isMajor ? 0.52 : 0.34))
            context.stroke(shadow, with: .color(.black.opacity(isMajor ? 0.21 : 0.13)),
                           lineWidth: isMajor ? 0.38 : 0.24)
            context.stroke(contour,
                           with: .color(.white.opacity(isMajor ? 0.52 : 0.27)),
                           lineWidth: isMajor ? 0.62 : 0.27)
        }
    }

    private func drawSunMoonEtch(context: inout GraphicsContext, size: CGSize) {
        var random = SeededValues(seed: seed ^ 0x534D_2D45_5443_4803)
        let centers = [
            CGPoint(x: size.width * (0.30 + random.next() * 0.08),
                    y: size.height * (0.32 + random.next() * 0.08)),
            CGPoint(x: size.width * (0.66 + random.next() * 0.08),
                    y: size.height * (0.62 + random.next() * 0.08)),
        ]
        for center in centers {
            for ring in 1...19 {
                let progress = CGFloat(ring) / 19
                let width = size.width * progress * 0.78
                let height = size.height * progress * 0.55
                var diamond = Path()
                diamond.move(to: CGPoint(x: center.x, y: center.y - height * 0.5))
                diamond.addQuadCurve(
                    to: CGPoint(x: center.x + width * 0.5, y: center.y),
                    control: CGPoint(x: center.x + width * 0.38,
                                     y: center.y - height * 0.42))
                diamond.addQuadCurve(
                    to: CGPoint(x: center.x, y: center.y + height * 0.5),
                    control: CGPoint(x: center.x + width * 0.38,
                                     y: center.y + height * 0.42))
                diamond.addQuadCurve(
                    to: CGPoint(x: center.x - width * 0.5, y: center.y),
                    control: CGPoint(x: center.x - width * 0.38,
                                     y: center.y + height * 0.42))
                diamond.addQuadCurve(
                    to: CGPoint(x: center.x, y: center.y - height * 0.5),
                    control: CGPoint(x: center.x - width * 0.38,
                                     y: center.y - height * 0.42))
                let isMajor = ring.isMultiple(of: 4)
                context.stroke(diamond,
                               with: .color(.white.opacity(isMajor ? 0.48 : 0.24)),
                               lineWidth: isMajor ? 0.58 : 0.27)
            }
        }
    }

    private func drawEmbossed(context: inout GraphicsContext, size: CGSize) {
        var random = SeededValues(seed: seed)
        for _ in 0..<90 {
            let radius = 0.6 + random.next() * 1.6
            let center = CGPoint(x: random.next() * size.width,
                                 y: random.next() * size.height)
            context.fill(Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius,
                                                width: radius * 2, height: radius * 2)),
                         with: .color(.white.opacity(0.34)))
        }
    }

    private func drawShards(context: inout GraphicsContext, size: CGSize) {
        var random = SeededValues(seed: seed)
        for _ in 0..<38 {
            let start = CGPoint(x: random.next() * size.width,
                                y: random.next() * size.height)
            let length = 8 + random.next() * 32
            let angle = random.next() * Double.pi * 2
            var path = Path()
            path.move(to: start)
            path.addLine(to: CGPoint(x: start.x + cos(angle) * length,
                                     y: start.y + sin(angle) * length))
            context.stroke(path, with: .color(.white.opacity(0.45)), lineWidth: 0.7)
        }
    }
}

// MARK: - Stable particles

private struct SeededValues {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed == 0 ? 0x9E3779B97F4A7C15 : seed
    }

    mutating func next() -> Double {
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        return Double(state % 100_000) / 100_000
    }
}

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
                let radius = dot.radius
                let rect = CGRect(x: dot.x * size.width - radius,
                                  y: dot.y * size.height - radius,
                                  width: radius * 2, height: radius * 2)
                context.fill(Path(ellipseIn: rect),
                             with: .color(.white.opacity(dot.alpha)))
            }
        }
    }

    private static var cache: [UInt64: [Dot]] = [:]

    static func dots(seed: UInt64, count: Int) -> [Dot] {
        if let cached = cache[seed], cached.count == count { return cached }
        var random = SeededValues(seed: seed)
        let made = (0..<count).map { _ in
            Dot(x: random.next(), y: random.next(),
                radius: 0.5 + random.next() * 1.4,
                alpha: 0.25 + random.next() * 0.62)
        }
        cache[seed] = made
        return made
    }
}
