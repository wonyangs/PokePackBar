import Foundation

/// 화면에 쓰는 원화 표기.
///
/// 게임은 토큰으로 모으지만 사람이 읽는 자리에는 원을 쓴다. 토큰은 자릿수가 커서 값을
/// 가늠하기 어렵고, 카드 시세가 실제 시장에서 온 값이라 원으로 읽는 편이 훨씬 와닿는다.
///
/// **100원 단위로 버린다.** 올림하지 않는다.
///
/// 예전에는 천 단위에서 반올림했다. 그러면 화면의 값과 실제로 빠지는 값이 달라져, 살 수 있다고
/// 적힌 팩을 못 사거나 산 뒤에 남은 돈이 계산과 맞지 않는다. 지금은 가격 자체가 100원 칸에만
/// 있으므로 가격은 이 함수를 지나도 그대로고, 칸에 맞지 않는 것은 잔액뿐이다.
///
/// 버리는 쪽이라 **「보이는 잔액 ≥ 보이는 가격」이면 실제로도 살 수 있다.** 올림하면 그
/// 보장이 깨진다.
enum WonFormatter {

    /// 표기 전에 끊어 내는 자리.
    static func rounded(_ won: Int) -> Int {
        guard won > 0 else { return 0 }
        return (won / MarketEconomy.wonStep) * MarketEconomy.wonStep
    }

    /// 세 자리 쉼표 표기. "1,196,000", "36,000", "400".
    ///
    /// 토큰은 억·만으로 끊어 읽지만(`TokenFormatter.readable`) 원은 쉼표를 쓴다.
    /// 끝자리를 이미 끊어 두었으므로 자릿수가 길지 않고, "119만 6천원" 보다 한눈에 들어온다.
    static func text(_ won: Int, locale: Locale = .current) -> String {
        TokenFormatter.grouped(rounded(won), locale: locale)
    }

    /// 단위를 붙인 완성 문자열.
    static func money(_ won: Int, language: AppLanguage, locale: Locale = .current) -> String {
        unit(text(won, locale: locale), language: language)
    }

    /// 끝자리를 끊지 않은 표기. 환율처럼 값 자체가 작고 정확해야 하는 자리에 쓴다 —
    /// 1,350원을 `money` 로 적으면 천 단위 반올림에 걸려 1,000원이 된다.
    static func exact(_ won: Int, language: AppLanguage, locale: Locale = .current) -> String {
        unit(TokenFormatter.grouped(won, locale: locale), language: language)
    }

    private static func unit(_ body: String, language: AppLanguage) -> String {
        switch language {
        case .ko: return body + "원"
        case .ja: return body + "円"
        default: return "₩" + body
        }
    }
}
