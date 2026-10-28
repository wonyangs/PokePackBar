import Foundation

/// 「오늘의 시세」와 시세 기록 그래프의 문구.

extension L {
    var priceNewsHeader: String { t("오늘의 시세", "Today's prices", "今日の相場", "Precios de hoy", "Prix du jour", "Preços de hoje") }
    func priceNewsAsOf(_ date: String) -> String {
        t("\(date) 기준", "As of \(date)", "\(date)時点", "Al \(date)", "Au \(date)", "Em \(date)")
    }
    var priceNewsMine: String { t("내 카드", "My cards", "自分のカード", "Mis cartas", "Mes cartes", "Minhas cartas") }
    var priceNewsRisers: String { t("급등", "Top risers", "急騰", "Mayores subidas", "Plus fortes hausses", "Maiores altas") }
    var priceNewsFallers: String { t("급락", "Top fallers", "急落", "Mayores bajadas", "Plus fortes baisses", "Maiores quedas") }
    var priceNewsPacks: String { t("팩 시세", "Pack prices", "パック相場", "Precio de sobres", "Prix des boosters", "Preço dos pacotes") }
    var priceNewsGathering: String {
        t("시세 기록을 모으는 중이에요. 다음 시세 갱신부터 변동을 보여 드려요.",
          "Collecting price history. Moves show up after the next price update.",
          "相場の記録を集めています。次の相場更新から変動を表示します。",
          "Recopilando el historial de precios. Los cambios aparecerán tras la próxima actualización.",
          "Collecte de l’historique des prix. Les variations apparaîtront après la prochaine mise à jour.",
          "Coletando o histórico de preços. As variações aparecem após a próxima atualização.")
    }
    var priceNewsQuiet: String {
        t("크게 움직인 카드가 없었어요.", "No big moves this time.", "大きく動いたカードはありませんでした。",
          "Esta vez no hubo grandes cambios.", "Pas de grosse variation cette fois.", "Nenhuma grande variação desta vez.")
    }
    var priceNewsUnavailable: String {
        t("시세 소식을 불러오지 못했어요.", "Couldn't load price news.", "相場ニュースを読み込めませんでした。",
          "No se pudieron cargar las noticias de precios.", "Impossible de charger les nouvelles des prix.",
          "Não foi possível carregar as notícias de preços.")
    }
    var priceNewsShowLess: String { t("접기", "Show less", "閉じる", "Ver menos", "Voir moins", "Ver menos") }
    var priceNewsRowHelp: String {
        t("눌러서 카드 자세히 보기", "Click to see the card", "クリックでカードを表示", "Haz clic para ver la carta",
          "Cliquez pour voir la carte", "Clique para ver a carta")
    }
    var priceNewsPackHelp: String {
        t("눌러서 상점에서 이 팩 보기", "Click to see this pack in the shop", "クリックでショップのパックを表示",
          "Haz clic para ver este sobre en la tienda", "Cliquez pour voir ce booster dans la boutique",
          "Clique para ver este pacote na loja")
    }

    var priceRiseTitle: String {
        t("내 카드 시세가 올랐어요", "Your cards went up", "持っているカードが値上がりしました",
          "Tus cartas subieron de precio", "Vos cartes ont pris de la valeur", "Suas cartas valorizaram")
    }
    func priceRiseBody(_ card: String, _ change: String, more: Int) -> String {
        guard more > 0 else { return "\(card) \(change)" }
        return t("\(card) \(change), 외 \(more)장", "\(card) \(change), and \(more) more",
                 "\(card) \(change) ほか\(more)枚", "\(card) \(change) y \(more) más",
                 "\(card) \(change) et \(more) de plus", "\(card) \(change) e mais \(more)")
    }

    var priceHistory: String { t("시세 기록", "Price history", "相場の推移", "Historial de precios", "Historique des prix", "Histórico de preços") }
    var priceHistoryHelp: String {
        t("시세 기록 그래프 보기", "Show the price history chart", "相場の推移グラフを表示",
          "Ver el gráfico del historial de precios", "Afficher le graphique de l’historique", "Ver o gráfico do histórico de preços")
    }
    func priceRange(_ range: PriceHistoryRange) -> String {
        switch range {
        case .month: return t("30일", "30D", "30日", "30 d", "30 j", "30 d")
        case .quarter: return t("90일", "90D", "90日", "90 d", "90 j", "90 d")
        case .all: return t("전체", "All", "全期間", "Todo", "Tout", "Tudo")
        }
    }
    func priceChangeOver(_ change: String, _ range: PriceHistoryRange) -> String {
        switch range {
        case .all:
            return t("기록 시작부터 \(change)", "\(change) since tracking began", "記録開始から\(change)",
                     "\(change) desde el inicio", "\(change) depuis le début", "\(change) desde o início")
        case .month, .quarter:
            let days = range.rawValue
            return t("\(days)일 동안 \(change)", "\(change) over \(days) days", "\(days)日間で\(change)",
                     "\(change) en \(days) días", "\(change) sur \(days) jours", "\(change) em \(days) dias")
        }
    }
    var priceHistoryOneDay: String {
        t("아직 기록이 하루치라 그릴 선이 없어요. 시세가 바뀌면 선이 이어져요.",
          "Only one day recorded so far. The line grows as the price changes.",
          "まだ1日分の記録しかありません。相場が変わると線が伸びます。",
          "Solo hay un día registrado. La línea crecerá cuando cambie el precio.",
          "Un seul jour enregistré pour l’instant. La courbe s’allongera quand le prix changera.",
          "Só há um dia registrado. A linha cresce quando o preço mudar.")
    }
    var priceHistoryFailed: String {
        t("시세 기록을 불러오지 못했어요.", "Couldn't load the price history.", "相場の記録を読み込めませんでした。",
          "No se pudo cargar el historial de precios.", "Impossible de charger l’historique des prix.",
          "Não foi possível carregar o histórico de preços.")
    }
    var priceHistoryEmpty: String {
        t("이 시세는 아직 기록이 없어요.", "No history for this price yet.", "この相場にはまだ記録がありません。",
          "Todavía no hay historial para este precio.", "Pas encore d’historique pour ce prix.",
          "Ainda não há histórico para este preço.")
    }
}

/// 변동 표기. 부호를 늘 붙인다 — 「12%」만으로는 오른 건지 내린 건지 알 수 없다.
enum PriceChangeFormat {
    static func percent(_ rate: Double) -> String {
        let value = abs(rate * 100)
        let digits = value >= 10 ? "%.0f%%" : "%.1f%%"
        let body = String(format: digits, value)
        if body == "0%" || body == "0.0%" { return "0%" }
        return (rate > 0 ? "+" : "\u{2212}") + body
    }

    /// 원화 변동. 0 이면 부호를 붙이지 않는다.
    static func won(_ won: Int, language: AppLanguage) -> String {
        let body = WonFormatter.money(abs(won), language: language)
        guard won != 0 else { return body }
        return (won > 0 ? "+" : "\u{2212}") + body
    }
}
