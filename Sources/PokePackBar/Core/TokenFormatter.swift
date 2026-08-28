import Foundation

enum TokenFormatter {
    /// 987 → "987", 12_345 → "12.3K", 190_612_940 → "190.6M", 1_240_000_000 → "1.24B"
    static func compact(_ value: Int) -> String {
        let v = Double(abs(value))
        let sign = value < 0 ? "-" : ""
        switch v {
        case ..<1_000:
            return "\(value)"
        case ..<1_000_000:
            return sign + trim(v / 1_000, decimals: 1) + "K"
        case ..<1_000_000_000:
            return sign + trim(v / 1_000_000, decimals: 1) + "M"
        default:
            return sign + trim(v / 1_000_000_000, decimals: 2) + "B"
        }
    }

    /// 팝오버 상세용 천 단위 구분 (190,612,940)
    ///
    /// 구분기호는 macOS 관례대로 *시스템 지역 설정*(`Locale.current`)을 따른다 — 앱 언어가 아니다.
    /// (en/ko/ja `253,412,890` · es/de `253.412.890` · fr/ru `253 412 890`)
    /// `locale` 파라미터는 그 관례를 바꾸려는 게 아니라 테스트가 러너의 지역 설정에 좌우되지 않게
    /// 하려고 있다 — 기본값을 쓰면 프로덕션 동작은 그대로다.
    static func grouped(_ value: Int, locale: Locale = .current) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.locale = locale
        return f.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    /// 만 단위로 끊어 읽는 표기. 122_331_111 → "1억 2233만 1111"
    ///
    /// 세 자리 쉼표는 thousand·million 에 맞춰 끊는 방식이라, 억·만으로 읽는 사람은
    /// 자릿수를 하나씩 세어야 한다. 잔액과 팩 값이 억 단위로 상시 떠 있는 화면이라
    /// 이 차이가 크다. 한국어·일본어만 이 표기를 쓰고, 나머지 언어는 쉼표를 그대로 둔다.
    ///
    /// 0 인 자리는 건너뛴다 — 100_000_000 은 "1억" 이지 "1억 0000만 0000" 이 아니다.
    static func readable(_ value: Int, language: AppLanguage, locale: Locale = .current) -> String {
        let units: [String]
        switch language {
        case .ko: units = ["조", "억", "만"]
        case .ja: units = ["兆", "億", "万"]
        default: return grouped(value, locale: locale)
        }
        guard value != 0 else { return "0" }

        // Int.min 은 부호를 뒤집을 수 없다. magnitude 로 다뤄 그 한 값만 예외가 되지 않게 한다.
        var remaining = value.magnitude
        var parts: [String] = []
        for (scale, unit) in zip(myriadScales, units) {
            let chunk = remaining / scale
            guard chunk > 0 else { continue }
            parts.append("\(chunk)\(unit)")
            remaining %= scale
        }
        if remaining > 0 { parts.append("\(remaining)") }
        return (value < 0 ? "-" : "") + parts.joined(separator: " ")
    }

    private static let myriadScales: [UInt] = [1_000_000_000_000, 100_000_000, 10_000]

    static func cost(_ usd: Double) -> String {
        String(format: "$%.2f", usd)
    }

    /// 메뉴바용 짧은 비용 표기: $9.5 / $311 / $1.2K
    static func costCompact(_ usd: Double) -> String {
        if usd < 100 { return String(format: "$%.1f", usd) }
        if usd < 10_000 { return String(format: "$%.0f", usd) }
        return String(format: "$%.1fK", usd / 1_000)
    }

    static func percent(_ value: Double) -> String {
        value == value.rounded() ? String(format: "%.0f%%", value) : String(format: "%.1f%%", value)
    }

    private static func trim(_ value: Double, decimals: Int) -> String {
        var s = String(format: "%.\(decimals)f", value)
        while s.hasSuffix("0") { s.removeLast() }
        if s.hasSuffix(".") { s.removeLast() }
        return s
    }
}
