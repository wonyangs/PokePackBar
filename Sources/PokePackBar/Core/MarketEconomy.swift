import Foundation

/// 게임의 토큰과 실제 시세를 잇는 단 하나의 지점.
///
/// 예전에는 카드값을 등급표로 매겼다. 실제 시장은 등급 순서를 따르지 않는다 — 우리가 최상위로
/// 두던 UR 의 중앙값이 SAR 의 6분의 1이고, 같은 세트·같은 등급 안에서도 40배가 벌어진다.
/// 그래서 값은 전부 시세에서 나오고, 여기 있는 두 상수만이 그것을 게임 안의 숫자로 옮긴다.
///
/// ```
/// 분해값(카드) = 시세 × tokensPerUSD
/// 팩값(세트)   = 팩 기대 시세 × tokensPerUSD × packMargin
/// ```
///
/// 두 식이 같은 환율을 쓰므로 **어느 세트를 사도 기대 수익률이 같다**(`1/packMargin`).
/// 무엇이 이득인지 고르는 게임이 아니라, 바닥이 높은 옛날 팩과 천장이 높은 최신 팩 중
/// 성향을 고르는 게임이 된다.
enum MarketEconomy {

    /// 1달러가 몇 토큰인가.
    ///
    /// 세트별 팩 기대값의 중앙값이 $11 남짓이라, 이 값이면 중간 세트 팩이 예전과 같은
    /// 1,000만 언저리에 남는다. 이 상수 하나가 팩값·분해값·오리파값에 동시에 걸린다.
    static let tokensPerUSD: Double = 292_000

    /// 팩값이 그 안에 든 것의 기대 시세보다 몇 배 비싼가.
    ///
    /// 곧 "사서 갈기만 할 때 돌려받는 비율" 의 역수다. 3 이면 3분의 1이 돌아온다 —
    /// 등급표를 쓰던 시절의 회수율과 같아 체감이 유지된다.
    static let packMargin: Double = 3

    /// 시세를 모르는 카드에 쓸 값. 0 으로 두면 갈 수도 없는 카드가 된다.
    static let unknownUSD: Double = 0.05

    /// 값의 최소 단위(원). 이보다 잘게 매기지 않는다.
    ///
    /// 예전에는 토큰으로 값을 매기고 화면에서만 천 단위로 반올림했다. 그러면 **적힌 값과
    /// 실제로 빠지는 값이 달라진다** — 3,006,432원짜리 팩이 3,006,000원으로 보여서 살 수
    /// 있을 것 같은데 못 사고, 사고 나면 남은 돈이 계산과 맞지 않는다. 이제 값 자체가
    /// 100원 칸에만 존재하고, 화면은 그것을 그대로 적는다.
    static let wonStep = 100

    /// 100원 한 칸이 몇 토큰인가. 스냅샷 환율에서 나오므로 배포 안에서는 고정이다.
    static func stepTokens(_ prices: CardPrices? = CardPrices.shared) -> Int {
        guard let prices, prices.krwPerUSD > 0 else { return 1 }
        return max(1, Int((Double(wonStep) * tokensPerUSD / prices.krwPerUSD).rounded()))
    }

    /// 토큰 값을 100원 칸에 맞춰 끊는다. **모든 가격은 이 함수를 지나야 한다.**
    ///
    /// 할인이나 추가금을 곱하면 칸에서 벗어나므로, 곱한 **뒤에** 다시 끊는다.
    static func quantized(_ tokens: Int, prices: CardPrices? = CardPrices.shared) -> Int {
        let step = stepTokens(prices)
        guard step > 1 else { return max(1, tokens) }
        return max(step, ((tokens + step / 2) / step) * step)
    }

    /// 달러를 토큰으로. 100원 칸에 맞춰 끊는다.
    static func tokens(usd: Double, prices: CardPrices? = CardPrices.shared) -> Int {
        quantized(max(1, Int((usd * tokensPerUSD).rounded())), prices: prices)
    }

    /// 토큰을 원으로.
    ///
    /// 칸의 배수는 **정확히** 100원의 배수로 돌아와야 한다. 실수로 나누면 1,000칸쯤에서
    /// 1원이 어긋나 화면의 값이 가격과 달라진다. 칸 단위는 정수로 세고 나머지만 환산한다.
    static func won(tokens: Int, prices: CardPrices? = CardPrices.shared) -> Int {
        guard let prices else { return 0 }
        let step = stepTokens(prices)
        guard step > 1 else {
            return Int((Double(tokens) / tokensPerUSD * prices.krwPerUSD).rounded())
        }
        // 남는 토큰은 **버린다.** 반올림하면 한 칸에서 1토큰 모자란 잔액이 그 칸을 채운 것으로
        // 보여, 살 수 있다고 나오는데 실제로는 못 사는 경우가 다시 생긴다.
        let steps = tokens / step
        let rest = tokens % step
        return steps * wonStep + Int(Double(rest) / Double(step) * Double(wonStep))
    }

    /// 토큰 금액을 화면에 쓸 원화 문자열로.
    static func money(tokens: Int, language: AppLanguage,
                      prices: CardPrices? = CardPrices.shared) -> String {
        WonFormatter.money(won(tokens: tokens, prices: prices), language: language)
    }

    static func usd(cardID: String, prices: CardPrices?) -> Double {
        prices?.price(cardID) ?? unknownUSD
    }

    /// 한 세트에서 그 등급 카드의 평균 시세.
    ///
    /// 팩 기대값은 "이 칸에서 이 등급이 나올 확률" 까지만 아는데, 같은 등급 안에서도 값이
    /// 크게 갈리므로 평균을 써야 한다.
    static func meanUSD(setID: String, tier: CardTier,
                        index: CardIndex, prices: CardPrices?) -> Double {
        let ids = index.pools[setID]?[tier] ?? []
        guard !ids.isEmpty else { return 0 }
        return ids.reduce(0.0) { $0 + usd(cardID: $1, prices: prices) } / Double(ids.count)
    }

    /// 팩 하나에 들어 있는 것의 기대 시세(달러).
    ///
    /// 확률은 `PackOpening.packOdds` 를 그대로 쓴다. 갓팩과 천장이 이미 반영된 값이라
    /// 여기서 다시 계산하면 화면에 보이는 확률과 값이 갈라진다.
    ///
    /// **혜택은 넣지 않는다.** 카드를 한 장 더 받는 혜택까지 반영하면 혜택을 얻은 사람의
    /// 팩값이 올라간다 — 혜택이 벌이 되어서는 안 된다.
    static func packValueUSD(setID: String, index: CardIndex, prices: CardPrices?) -> Double {
        let odds = PackOpening.packOdds(setID: setID, index: index)   // 혜택 제외 — 아래 주석
        guard !odds.isEmpty else { return 0 }
        let cards = Double(PackPricing.cardCount(setID: setID, index: index))   // 혜택 제외
        return odds.reduce(0.0) {
            $0 + $1.probability * cards * meanUSD(setID: setID, tier: $1.tier,
                                                  index: index, prices: prices)
        }
    }
}
