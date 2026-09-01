import Foundation

/// 카드의 실제 시세. 배포에 담긴 스냅샷이다.
///
/// **일부러 실시간이 아니다.** 시세는 날마다 움직이는데, 그것을 그대로 물리면 자던 사이에
/// 팩값이 오르고 갖고 있던 카드의 값이 떨어진다. 버전마다 값을 고정해 두면 무엇이 언제
/// 바뀌었는지가 분명하고, 업데이트 자체가 「시세 갱신」이 된다.
///
/// 출처는 카드 데이터를 받는 그 API 다(TCGplayer 시장가, 달러). 한 카드에 여러 판이 있으면
/// 가장 비싼 판을 그 카드 값으로 본다 — 게임에서 카드는 한 종류라 판을 나눌 수 없다.
struct CardPrices: Sendable {

    /// 스냅샷 기준일(`yyyy-MM-dd`). 비어 있으면 표시하지 않는다.
    let asOf: String
    /// 값의 통화. 지금은 USD 하나뿐이지만, 화면이 이 값을 보고 기호를 고른다.
    let currency: String
    /// 1달러가 몇 원인가. 표기용이라 시세와 함께 스냅샷에 고정한다 —
    /// 환율만 실시간이면 카드값이 저 혼자 움직인다.
    let krwPerUSD: Double

    private let byID: [String: Double]

    /// 카드 한 장의 시세. 모르는 카드는 nil — 0 을 돌려주면 "공짜 카드" 로 보인다.
    func price(_ cardID: String) -> Double? { byID[cardID] }

    /// 갖고 있는 만큼의 값. 장수가 0 이면 nil.
    func total(_ cardID: String, count: Int) -> Double? {
        guard count > 0, let one = price(cardID) else { return nil }
        return one * Double(count)
    }

    /// 원화로 환산한 값. **100원 칸에 맞춘다.**
    ///
    /// 카드에 적히는 값은 그 카드를 팔 때 받는 값과 **같은 숫자**여야 한다. 표기와 판매가가
    /// 각자 반올림하면 757원이라 적어 두고 800원을 주는 일이 생긴다. 그래서 표기도 판매가와
    /// 같은 길(토큰으로 옮겼다가 되돌리기)을 지난다.
    func krw(_ usd: Double) -> Int {
        MarketEconomy.won(tokens: MarketEconomy.tokens(usd: usd, prices: self), prices: self)
    }

    // MARK: 표시

    /// 원화를 앞에, 달러를 괄호에. "120만원 ($869)" 처럼 읽힌다.
    ///
    /// 주 단위가 원이다 — 값을 가늠하는 것은 원 쪽이고, 달러는 출처가 미국 시세라는
    /// 근거로 남긴다. 끝자리를 끊는 규칙은 `WonFormatter` 가 갖고 있다.
    func formattedWithKRW(_ value: Double, language: AppLanguage) -> String {
        "\(WonFormatter.money(krw(value), language: language)) (\(formatted(value)))"
    }

    /// 화면에 쓸 문자열. 값의 크기에 따라 소수점을 줄인다 —
    /// $868.56 은 두 자리가 의미 있지만 $1,466.00 에서는 소수점이 잡음이다.
    func formatted(_ value: Double) -> String {
        let symbol = currency == "USD" ? "$" : ""
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = value >= 100 ? 0 : 2
        formatter.minimumFractionDigits = value >= 100 ? 0 : 2
        let number = formatter.string(from: NSNumber(value: value)) ?? "\(value)"
        return symbol.isEmpty ? "\(number) \(currency)" : symbol + number
    }

    // MARK: 읽기

    /// 번들 스냅샷. 하나만 읽어 공유한다 — 카드 격자가 장마다 파싱하면 안 된다.
    static let shared: CardPrices? = loadBundled()

    static func loadBundled() -> CardPrices? {
        guard let url = AppResources.bundle?.url(forResource: "card-prices", withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            AppLog.write("card prices missing from bundle")
            return nil
        }
        return decode(data)
    }

    static func decode(_ data: Data) -> CardPrices? {
        guard let payload = try? JSONDecoder().decode(Payload.self, from: data) else {
            AppLog.write("card prices decode failed")
            return nil
        }
        return CardPrices(asOf: payload.asOf, currency: payload.currency,
                          krwPerUSD: payload.krwPerUsd, byID: payload.prices)
    }

    private struct Payload: Decodable {
        let version: Int
        let asOf: String
        let currency: String
        let krwPerUsd: Double
        let prices: [String: Double]
    }
}
