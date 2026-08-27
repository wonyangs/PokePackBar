import Foundation

/// 앱 언어. 포켓몬 이름은 PokéAPI 다국어 names 에서 가져온다.
enum AppLanguage: String, Codable, Sendable, CaseIterable {
    case ko, en, ja, es, fr, pt
    /// PokéAPI language.name 후보(첫 매칭 사용)
    var apiCodes: [String] {
        switch self {
        case .ko: return ["ko"]
        case .en: return ["en"]
        case .ja: return ["ja-Hrkt", "ja"]
        case .es: return ["es"]
        case .fr: return ["fr"]
        // PokéAPI has no `pt` in its language list, so this falls through to
        // resolveName's English fallback. That fallback IS the expected result:
        // the core series was never localised into Portuguese, so Brazilian
        // players use the English species names anyway. The code is listed
        // regardless, so the day PokéAPI adds it, it works with no edit here.
        // PokéAPI 의 language 목록에 pt 는 없다 → resolveName 의 영어 폴백으로 내려간다.
        // 본가 시리즈가 포르투갈어로 나온 적이 없어 브라질에서도 종 이름은 영어를 쓰므로 폴백이 곧 기대값이다.
        // 그래도 코드를 적어두는 건 PokéAPI 가 pt 를 추가하는 순간 분기 수정 없이 반영되게 하기 위해서다.
        case .pt: return ["pt"]
        }
    }
    var label: String {
        switch self { case .ko: return "한국어"; case .en: return "English"; case .ja: return "日本語"; case .es: return "Español"; case .fr: return "Français"; case .pt: return "Português" }
    }

    var displayLocale: Locale { Locale(identifier: rawValue) }

    /// byLang(langCode→name) 에서 이 언어의 이름을 고른다(apiCodes 첫 매칭 → 영어 폴백).
    func resolveName(_ byLang: [String: String]) -> String? {
        for code in apiCodes { if let n = byLang[code] { return n } }
        return byLang["en"]
    }

    /// 신규 설치 기본 언어 — 시스템 선호 언어에서 유추(글로벌 출시: 한국어 강제 금지).
    /// ko/ja/es/fr/pt 만 매칭, 그 외 전부 영어(fallback-of-fallback). 기존 사용자는 저장된 언어를 그대로 쓴다.
    static var systemDefault: AppLanguage {
        switch Locale.preferredLanguages.first?.prefix(2).lowercased() {
        case "ko": return .ko
        case "ja": return .ja
        case "es": return .es
        case "fr": return .fr
        case "pt": return .pt
        default:   return .en
        }
    }
}

/// 희귀도 — PokéAPI capture_rate / is_legendary 로 판정.

/// 사용 한도 창의 종류. 보너스 팩 판정이 이 구분을 쓴다.
enum WindowClass: Sendable { case session, weekly }
