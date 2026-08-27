import Foundation

/// 카드 게임 문구. 기존 문구 파일과 분리해 둔다 — 컴패니언을 걷어낸 뒤 남은 문구와
/// 새로 들어온 문구를 구분해서 보기 위한 것이다.
extension L {

    // MARK: 탭
    var packsTab: String { t2("팩", "Packs", "パック", "Sobres", "Boosters", "Pacotes") }

    // MARK: 지갑
    var walletBalance: String { t2("쓸 수 있는 토큰", "Spendable tokens", "使えるトークン",
                                   "Tokens disponibles", "Tokens disponibles", "Tokens disponíveis") }
    var walletHint: String { t2("코딩할 때 쓴 토큰으로 카드팩을 살 수 있어요.",
                                "Spend the tokens you burn while coding on card packs.",
                                "コーディングで使ったトークンでカードパックを買えます。",
                                "Gasta en sobres los tokens que consumes programando.",
                                "Dépense en boosters les tokens consommés en codant.",
                                "Compre pacotes com os tokens que você gasta programando.") }
    var awaitingUsage: String { t2("사용량을 아직 못 읽었어요. AI 코딩 도구를 한 번 써 보세요.",
                                   "No usage yet. Use an AI coding tool once to get started.",
                                   "使用量がまだありません。AI コーディングツールを一度使ってみてください。",
                                   "Aún no hay uso. Usa una herramienta de IA una vez para empezar.",
                                   "Aucun usage pour l'instant. Utilise un outil d'IA une fois pour démarrer.",
                                   "Ainda sem uso. Use uma ferramenta de IA uma vez para começar.") }

    func updateAvailableHelp(_ version: String) -> String {
        t2("새 버전 \(version) 으로 업데이트", "Update to \(version)", "\(version) に更新",
           "Actualizar a \(version)", "Mettre à jour vers \(version)", "Atualizar para \(version)")
    }

    // MARK: 상점
    var shopCardHint: String { t2("세트를 골라 팩을 사세요.", "Pick a set and buy a pack.",
                                  "セットを選んでパックを買いましょう。", "Elige un set y compra un sobre.",
                                  "Choisis un set et achète un booster.", "Escolha um set e compre um pacote.") }
    func packName(_ setName: String) -> String {
        t2("\(setName) 팩", "\(setName) Pack", "\(setName) パック",
           "Sobre de \(setName)", "Booster \(setName)", "Pacote \(setName)")
    }
    func packContents(_ count: Int) -> String {
        t2("카드 \(count)장", "\(count) cards", "カード \(count)枚",
           "\(count) cartas", "\(count) cartes", "\(count) cartas")
    }

    /// 팩 한 줄 소개. 그 세트가 왜 특별한지 실제 사실로 적는다 —
    /// 이름과 연도만으로는 어느 팩을 살지 정하기 어렵다.
    ///
    /// 한국어와 영어만 쓴다. 사실 서술이라 나머지 언어는 영어로 둔다.
    func packBlurb(_ setID: String) -> String? {
        switch setID {
        case "base1":
            return blurb("포켓몬 카드가 시작된 자리. 1999년 첫 세트로, 초판 리자몽이 여기서 나왔습니다.",
                         "Where it all began. The 1999 first set, home of the original Charizard.")
        case "neo1":
            return blurb("2세대의 문을 연 세트. 악·강철 타입과 베이비 포켓몬이 처음 등장했습니다.",
                         "Opens the Johto era — the debut of Darkness and Metal types, and Baby Pokémon.")
        case "xy12":
            return blurb("20주년 기념 복각. 1999년 초판의 그림과 구성을 현대 규칙으로 다시 냈습니다.",
                         "The 20th-anniversary throwback: 1999 artwork and lineup, rebuilt for modern rules.")
        case "sm115":
            return blurb("이로치 카드를 모으는 '샤이니 볼트'가 처음 붙은 세트. 75종이 넘습니다.",
                         "The set that introduced the Shiny Vault — over 75 Shiny cards to chase.")
        case "swsh45":
            return blurb("샤이니 볼트를 100종 넘게 키운 세트. 이로치를 노린다면 여기입니다.",
                         "Shiny Vault grown past 100 cards. The set to open if you are hunting Shinies.")
        case "cel25":
            return blurb("25주년 기념 세트. 역대 명장면 카드를 복각해 25장만 담은 작은 팩입니다.",
                         "The 25th-anniversary set: 25 reprinted classics in a deliberately tiny pack.")
        case "swsh12pt5":
            return blurb("소드·실드 시리즈를 마무리한 세트. 갈라르 갤러리 일러스트가 들어 있습니다.",
                         "The send-off for Sword & Shield, carrying the Galarian Gallery illustrations.")
        case "sv3pt5":
            return blurb("1세대 151마리를 빠짐없이 담은 세트. 관동 지방을 통째로 모을 수 있습니다.",
                         "All 151 originals in one set — the whole Kanto roster, collectible end to end.")
        case "sv8pt5":
            return blurb("이브이 진화형이 주인공인 세트. 몬스터볼·마스터볼 무늬 카드가 여기서 나옵니다.",
                         "Built around the Eeveelutions, with the Poké Ball and Master Ball patterned cards.")
        case "sv10":
            return blurb("로켓단이 전면에 선 세트. 트레이너가 소유한 포켓몬 카드가 돌아왔습니다.",
                         "Team Rocket takes the lead, and trainer-owned Pokémon cards return.")
        default:
            return nil
        }
    }

    private func blurb(_ ko: String, _ en: String) -> String {
        lang == .ko ? ko : en
    }

    var packTotalCards: String { t2("전체 카드", "Cards in set", "収録カード",
                                     "Cartas del set", "Cartes du set", "Cartas do set") }
    var packCollected: String { t2("수집률", "Collected", "収集率", "Recolectadas", "Collectées", "Coletadas") }
    var packOdds: String { t2("등급별 확률", "Odds by rarity", "レアリティ別確率",
                              "Probabilidad por rareza", "Probabilité par rareté", "Chance por raridade") }
    var packOddsColumns: String { t2("카드 한 장 기준", "Per card", "カード1枚あたり",
                                     "Por carta", "Par carte", "Por carta") }
    var packQuantity: String { t2("수량", "Quantity", "数量", "Cantidad", "Quantité", "Quantidade") }
    func buyCount(_ n: Int) -> String {
        t2("\(n)개 구매", "Buy \(n)", "\(n)個 購入", "Comprar \(n)", "Acheter \(n)", "Comprar \(n)")
    }

    // MARK: 팩
    var packsEmptyTitle: String { t2("가진 팩이 없어요", "No packs yet", "パックがありません",
                                     "Sin sobres", "Aucun booster", "Nenhum pacote") }
    var packsEmptyHint: String { t2("상점에서 팩을 사거나, 사용 한도를 다 채워 보너스 팩을 받으세요.",
                                     "Buy one in the shop, or fill a usage limit for a bonus pack.",
                                     "ショップで買うか、使用上限を使い切ってボーナスパックを受け取りましょう。",
                                     "Cómpralo en la tienda o alcanza un límite para un sobre extra.",
                                     "Achète-en un, ou atteins une limite pour un booster bonus.",
                                     "Compre na loja ou atinja um limite para um pacote bônus.") }
    var packPreparing: String { t2("카드를 꺼내는 중…", "Getting the cards ready…", "カードを準備中…",
                                    "Preparando las cartas…", "Préparation des cartes…", "Preparando as cartas…") }
    var openPack: String { t2("뜯기", "Open", "開ける", "Abrir", "Ouvrir", "Abrir") }
    var packOpened: String { t2("개봉 결과", "Pack results", "開封結果",
                                 "Resultado", "Résultat", "Resultado") }
    var newCardBadge: String { t2("NEW", "NEW", "NEW", "NUEVA", "NOUVEAU", "NOVA") }
    var openAll: String { t2("한번에 열기", "Open all", "まとめて開ける",
                             "Abrir todo", "Tout ouvrir", "Abrir tudo") }
    var stopAuto: String { t2("멈추기", "Stop", "とめる", "Detener", "Arrêter", "Parar") }
    var revealNext: String { t2("다음", "Next", "次へ", "Siguiente", "Suivant", "Próxima") }
    var done: String { t2("확인", "Done", "OK", "Listo", "OK", "OK") }
    func packOpenSummary(new: Int, total: Int) -> String {
        t2("\(total)장 중 새 카드 \(new)장", "\(new) new of \(total)", "\(total)枚のうち新規 \(new)枚",
           "\(new) nuevas de \(total)", "\(new) nouvelles sur \(total)", "\(new) novas de \(total)")
    }

    // MARK: 컬렉션
    var collectionEmptyTitle: String { t2("아직 카드가 없어요", "No cards yet", "カードがありません",
                                          "Sin cartas", "Aucune carte", "Nenhuma carta") }
    var collectionEmptyHint: String { t2("팩을 뜯으면 여기에 모여요.", "Open a pack and they'll show up here.",
                                         "パックを開けるとここに集まります。", "Abre un sobre y aparecerán aquí.",
                                         "Ouvre un booster et elles apparaîtront ici.", "Abra um pacote e elas aparecerão aqui.") }
    var filterSet: String { t2("세트", "Set", "セット", "Set", "Set", "Set") }
    var filterTier: String { t2("등급", "Rarity", "レアリティ", "Rareza", "Rareté", "Raridade") }
    var notOwnedYet: String { t2("아직 없음", "Not owned yet", "未所持",
                                 "Aún no obtenida", "Pas encore obtenue", "Ainda não obtida") }
    var allSets: String { t2("전체", "All", "すべて", "Todos", "Tous", "Todos") }
    func collectedOf(_ owned: Int, _ total: Int) -> String { "\(owned) / \(total)" }
    func copiesOwned(_ count: Int) -> String {
        t2("\(count)장 보유", "\(count) copies", "\(count)枚所持",
           "\(count) copias", "\(count) exemplaires", "\(count) cópias")
    }

    // MARK: 설정

    var bonusPackNotificationsLabel: String {
        t2("보너스 팩 알림", "Bonus pack alerts", "ボーナスパック通知",
           "Avisos de sobre extra", "Alertes de booster bonus", "Avisos de pacote bônus")
    }
    var bonusPackNotificationsHint: String {
        t2("사용 한도를 다 채워 팩을 받으면 알려줘요.",
           "Tells you when filling a usage limit earns a pack.",
           "使用上限を使い切ってパックを得たときに知らせます。",
           "Avisa cuando alcanzar un límite te da un sobre.",
           "Prévient quand atteindre une limite donne un booster.",
           "Avisa quando atingir um limite rende um pacote.")
    }
    func bonusPackNotificationBody(window: String, set: String, count: Int) -> String {
        t2("\(window) 한도를 다 채웠어요 — \(set) 팩 \(count)개가 기다립니다.",
           "You maxed the \(window) limit — \(count) \(set) packs are waiting.",
           "\(window) の上限を使い切りました — \(set) パック\(count)つが待っています。",
           "Alcanzaste el límite de \(window): \(count) sobres de \(set) te esperan.",
           "Tu as atteint la limite \(window) : \(count) boosters \(set) t'attendent.",
           "Você atingiu o limite de \(window): \(count) pacotes de \(set) esperam.")
    }

    // MARK: 카드 갈기

    var disenchant: String { t2("중복 갈기", "Recycle spares", "重複を分解",
                                "Reciclar repetidas", "Recycler les doubles", "Reciclar repetidas") }
    func disenchantConfirm(_ count: Int, _ tokens: String) -> String {
        t2("\(count)장을 갈아 \(tokens) 토큰을 받습니다. 한 장은 남습니다.",
           "Recycle \(count) for \(tokens) tokens. One copy stays.",
           "\(count)枚を分解して \(tokens) トークン。1枚は残ります。",
           "Recicla \(count) por \(tokens) tokens. Se conserva una.",
           "Recycle \(count) pour \(tokens) tokens. Un exemplaire reste.",
           "Recicle \(count) por \(tokens) tokens. Uma cópia fica.")
    }
    func disenchantDone(_ tokens: String) -> String {
        t2("+\(tokens) 토큰", "+\(tokens) tokens", "+\(tokens) トークン",
           "+\(tokens) tokens", "+\(tokens) tokens", "+\(tokens) tokens")
    }

    // MARK: 등급

    /// 등급 배지 — 국내 커뮤니티가 쓰는 약칭을 그대로 쓴다. 카드에 인쇄된 표기라 언어와 무관하다.
    func tierBadge(_ tier: CardTier) -> String { tier.rawValue }

    /// 등급 전체 이름. 배지만으로는 처음 보는 사용자가 뜻을 모르므로 상세에서 함께 보여준다.
    func tierName(_ tier: CardTier) -> String {
        switch tier {
        case .energy:         return t2("에너지", "Energy", "エネルギー", "Energía", "Énergie", "Energia")
        case .common:         return t2("커먼", "Common", "コモン", "Común", "Commune", "Comum")
        case .uncommon:       return t2("언커먼", "Uncommon", "アンコモン", "Poco común", "Peu commune", "Incomum")
        case .rare:           return t2("레어", "Rare", "レア", "Rara", "Rare", "Rara")
        case .doubleRare:     return t2("더블레어", "Double Rare", "ダブルレア", "Doble rara", "Double rare", "Dupla rara")
        case .tripleRare:     return t2("트리플레어", "Triple Rare", "トリプルレア", "Triple rara", "Triple rare", "Tripla rara")
        case .artRare:        return t2("아트레어", "Art Rare", "アートレア", "Arte rara", "Art rare", "Arte rara")
        case .superRare:      return t2("슈퍼레어", "Super Rare", "スーパーレア", "Súper rara", "Super rare", "Super rara")
        case .specialArtRare: return t2("스페셜아트레어", "Special Art Rare", "スペシャルアートレア",
                                        "Arte especial rara", "Art spécial rare", "Arte especial rara")
        case .ultraRare:      return t2("울트라레어", "Ultra Rare", "ウルトラレア", "Ultra rara", "Ultra rare", "Ultra rara")
        }
    }

    // MARK: 보너스 팩 알림
    var bonusPackTitle: String { t2("보너스 팩 도착!", "Bonus pack!", "ボーナスパック！",
                                    "¡Sobre extra!", "Booster bonus !", "Pacote bônus!") }
    func bonusPackBody(window: String, set: String, count: Int) -> String {
        t2("\(window) 한도를 다 채웠어요 — \(set) 팩 \(count)개를 받았어요.",
           "You maxed the \(window) limit — \(count) \(set) packs.",
           "\(window) の上限を使い切りました — \(set) パックを\(count)つ獲得。",
           "Alcanzaste el límite de \(window): \(count) sobres de \(set).",
           "Tu as atteint la limite \(window) : \(count) boosters \(set).",
           "Você atingiu o limite de \(window): \(count) pacotes de \(set).")
    }

    // MARK: 오류
    var cardIndexMissing: String { t2("카드 목록을 불러올 수 없어요.", "Couldn't load the card list.",
                                      "カードリストを読み込めません。", "No se pudo cargar la lista de cartas.",
                                      "Impossible de charger la liste des cartes.", "Não foi possível carregar a lista de cartas.") }

    /// 기존 파일의 `t` 가 private 이라 확장에서 쓸 수 없다. 같은 형태로 하나 더 둔다.
    private func t2(_ ko: String, _ en: String, _ ja: String, _ es: String, _ fr: String, _ pt: String) -> String {
        switch lang {
        case .ko: return ko
        case .en: return en
        case .ja: return ja
        case .es: return es
        case .fr: return fr
        case .pt: return pt
        }
    }
}
