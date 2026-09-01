import Foundation

/// 카드 게임 문구. 기존 문구 파일과 분리해 둔다 — 컴패니언을 걷어낸 뒤 남은 문구와
/// 새로 들어온 문구를 구분해서 보기 위한 것이다.
extension L {

    // MARK: 탭
    var packsTab: String { t("팩", "Packs", "パック", "Sobres", "Boosters", "Pacotes") }

    // MARK: 시세
    var marketPrice: String { t("시세", "Market", "相場", "Mercado", "Marché", "Mercado") }
    func dexTotalValue(_ amount: String) -> String {
        t("총 가치 \(amount)", "Total value \(amount)", "総価値 \(amount)",
          "Valor total \(amount)", "Valeur totale \(amount)", "Valor total \(amount)")
    }
    /// 개봉한 팩에서 나온 카드값의 합.
    func packTotalValue(_ amount: String) -> String {
        t("총 가치 \(amount)", "Total value \(amount)", "総価値 \(amount)",
          "Valor total \(amount)", "Valeur totale \(amount)", "Valor total \(amount)")
    }
    var collectionValue: String { t("컬렉션 가치", "Collection value", "コレクション価値",
                                    "Valor de la colección", "Valeur de la collection",
                                    "Valor da coleção") }
    var marketHoldings: String { t("보유", "Holdings", "保有", "En posesión", "En stock", "Em posse") }
    func marketPriceSource(_ date: String) -> String {
        t("TCGplayer 시장가 · \(date) 기준",
          "TCGplayer market price, as of \(date)",
          "TCGplayer 市場価格・\(date) 時点",
          "Precio de mercado de TCGplayer, a \(date)",
          "Prix du marché TCGplayer, au \(date)",
          "Preço de mercado da TCGplayer, em \(date)")
    }

    // MARK: 메뉴바 카드
    var menuBarCardLabel: String { t("메뉴바에 카드 표시", "Show a card in the menu bar", "メニューバーにカードを表示",
                                     "Mostrar una carta en la barra de menús", "Afficher une carte dans la barre de menus",
                                     "Mostrar uma carta na barra de menus") }
    var favoriteCardSet: String { t("메뉴바에 올리기", "Put in the menu bar", "メニューバーに置く",
                                    "Poner en la barra de menús", "Mettre dans la barre de menus",
                                    "Colocar na barra de menus") }
    var favoriteCardClear: String { t("메뉴바에서 내리기", "Take out of the menu bar", "メニューバーから外す",
                                      "Quitar de la barra de menús", "Retirer de la barre de menus",
                                      "Remover da barra de menus") }
    var favoriteCardAuto: String { t("가장 높은 등급 (자동)", "Highest rarity (automatic)", "最高レアリティ（自動）",
                                     "Mayor rareza (automático)", "Rareté la plus élevée (auto)",
                                     "Maior raridade (automático)") }
    var favoriteCardNone: String { t("올릴 카드가 없어요", "No card to show yet", "表示できるカードがありません",
                                     "Todavía no hay carta", "Aucune carte à afficher",
                                     "Nenhuma carta para mostrar") }

    // MARK: 지갑
    var walletBalance: String { t("쓸 수 있는 금액", "Spendable", "使える金額",
                                   "Disponible", "Disponible", "Disponível") }
    var walletRateTitle: String { t("토큰은 얼마인가요?", "What is a token worth?",
                                     "トークンはいくら？", "¿Cuánto vale un token?",
                                     "Combien vaut un token ?", "Quanto vale um token?") }
    /// 토큰 한 개는 5원도 안 되어 그대로 적으면 감이 오지 않는다. 100만 개를 기준으로 적는다.
    /// 한 줄이다 — 환산이 어디서 왔는지까지 늘어놓으면 읽기 전에 닫는다.
    func walletRateBody(_ tokens: String, _ money: String) -> String {
        t("토큰 \(tokens)개 = \(money)", "\(tokens) tokens = \(money)",
           "トークン \(tokens)個 = \(money)", "\(tokens) tokens = \(money)",
           "\(tokens) tokens = \(money)", "\(tokens) tokens = \(money)")
    }
    var awaitingUsage: String { t("사용량을 아직 못 읽었어요. AI 코딩 도구를 한 번 써 보세요.",
                                   "No usage yet. Use an AI coding tool once to get started.",
                                   "使用量がまだありません。AI コーディングツールを一度使ってみてください。",
                                   "Aún no hay uso. Usa una herramienta de IA una vez para empezar.",
                                   "Aucun usage pour l'instant. Utilise un outil d'IA une fois pour démarrer.",
                                   "Ainda sem uso. Use uma ferramenta de IA uma vez para começar.") }

    func updateAvailableHelp(_ version: String) -> String {
        t("새 버전 \(version) 으로 업데이트", "Update to \(version)", "\(version) に更新",
           "Actualizar a \(version)", "Mettre à jour vers \(version)", "Atualizar para \(version)")
    }

    // MARK: 상점
    func packName(_ setName: String) -> String {
        t("\(setName) 팩", "\(setName) Pack", "\(setName) パック",
           "Sobre de \(setName)", "Booster \(setName)", "Pacote \(setName)")
    }
    func packContents(_ count: Int) -> String {
        t("카드 \(count)장", "\(count) cards", "カード \(count)枚",
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

    var packOdds: String { t("등급별 확률", "Odds by rarity", "レアリティ別確率",
                              "Probabilidad por rareza", "Probabilité par rareté", "Chance por raridade") }
    /// 이 팩에서 나올 수 있는 카드를 다 보여 주는 화면으로 들어가는 말.
    var packSeeCards: String { t("나올 수 있는 카드", "Cards in this pack", "出るカード一覧",
                                  "Cartas de este sobre", "Cartes de ce booster",
                                  "Cartas deste pacote") }
    /// 카드 상세에서 그 팩을 사러 가는 말.
    var packGoBuy: String { t("이 팩 사러 가기", "Buy this pack", "このパックを買う",
                               "Comprar este sobre", "Acheter ce booster", "Comprar este pacote") }
    /// 확정 한 장과 천장을 한 줄로. 표를 칸별로 쪼개는 대신 이 줄로 보장을 알린다.
    func packGuaranteeNote(_ guaranteed: Int, pity: Int) -> String {
        t("팩마다 레어 이상 \(guaranteed)장 확정 · 레어만 \(pity)팩 연속이면 다음은 RR 이상 보장",
           "\(guaranteed) rare or better guaranteed per pack · RR+ guaranteed after \(pity) plain-rare packs",
           "パックごとにレア以上\(guaranteed)枚確定・レアのみ\(pity)パック連続で次はRR以上保証",
           "\(guaranteed) rara o mejor por sobre · RR+ garantizado tras \(pity) sobres",
           "\(guaranteed) rare ou mieux par booster · RR+ garanti après \(pity) boosters",
           "\(guaranteed) rara ou melhor por pacote · RR+ garantido após \(pity) pacotes")
    }

    var packOddsColumns: String { t("카드 한 장 기준", "Per card", "カード1枚あたり",
                                     "Por carta", "Par carte", "Por carta") }
    var packQuantity: String { t("수량", "Quantity", "数量", "Cantidad", "Quantité", "Quantidade") }
    func buyCount(_ n: Int) -> String {
        t("\(n)개 구매", "Buy \(n)", "\(n)個 購入", "Comprar \(n)", "Acheter \(n)", "Comprar \(n)")
    }

    // MARK: 팩
    var packsEmptyTitle: String { t("가진 팩이 없어요", "No packs yet", "パックがありません",
                                     "Sin sobres", "Aucun booster", "Nenhum pacote") }
    var packsEmptyHint: String { t("상점에서 팩을 사거나, 사용 한도를 다 채워 보너스 팩을 받으세요.",
                                     "Buy one in the shop, or fill a usage limit for a bonus pack.",
                                     "ショップで買うか、使用上限を使い切ってボーナスパックを受け取りましょう。",
                                     "Cómpralo en la tienda o alcanza un límite para un sobre extra.",
                                     "Achète-en un, ou atteins une limite pour un booster bonus.",
                                     "Compre na loja ou atinja um limite para um pacote bônus.") }
    var packPreparing: String { t("카드를 꺼내는 중…", "Getting the cards ready…", "カードを準備中…",
                                    "Preparando las cartas…", "Préparation des cartes…", "Preparando as cartas…") }
    var openPack: String { t("뜯기", "Open", "開ける", "Abrir", "Ouvrir", "Abrir") }
    var packOpened: String { t("개봉 결과", "Pack results", "開封結果",
                                 "Resultado", "Résultat", "Resultado") }
    var newCardBadge: String { t("NEW", "NEW", "NEW", "NUEVA", "NOUVEAU", "NOVA") }
    var openAll: String { t("한번에 열기", "Open all", "まとめて開ける",
                             "Abrir todo", "Tout ouvrir", "Abrir tudo") }
    var done: String { t("확인", "Done", "OK", "Listo", "OK", "OK") }
    func packOpenSummary(new: Int, total: Int) -> String {
        t("\(total)장 중 새 카드 \(new)장", "\(new) new of \(total)", "\(total)枚のうち新規 \(new)枚",
           "\(new) nuevas de \(total)", "\(new) nouvelles sur \(total)", "\(new) novas de \(total)")
    }

    // MARK: 컬렉션
    var collectionEmptyHint: String { t("팩을 뜯으면 여기에 모여요.", "Open a pack and they'll show up here.",
                                         "パックを開けるとここに集まります。", "Abre un sobre y aparecerán aquí.",
                                         "Ouvre un booster et elles apparaîtront ici.", "Abra um pacote e elas aparecerão aqui.") }
    var filterSet: String { t("세트", "Set", "セット", "Set", "Set", "Set") }
    var ownedOnly: String { t("보유한 카드만", "Owned only", "所持カードのみ",
                               "Solo en posesión", "Possédées seulement", "Somente possuídas") }
    var tierSummaryToggle: String { t("등급별 수집 현황", "By rarity", "レアリティ別",
                                       "Por rareza", "Par rareté", "Por raridade") }
    var filterTier: String { t("등급", "Rarity", "レアリティ", "Rareza", "Rareté", "Raridade") }
    var notOwnedYet: String { t("아직 없음", "Not owned yet", "未所持",
                                 "Aún no obtenida", "Pas encore obtenue", "Ainda não obtida") }
    var allSets: String { t("전체", "All", "すべて", "Todos", "Tous", "Todos") }
    func collectedOf(_ owned: Int, _ total: Int) -> String { "\(owned) / \(total)" }
    func copiesOwned(_ count: Int) -> String {
        t("\(count)장 보유", "\(count) copies", "\(count)枚所持",
           "\(count) copias", "\(count) exemplaires", "\(count) cópias")
    }

    // MARK: 설정

    var bonusPackNotificationsLabel: String {
        t("보너스 팩 알림", "Bonus pack alerts", "ボーナスパック通知",
           "Avisos de sobre extra", "Alertes de booster bonus", "Avisos de pacote bônus")
    }
    var bonusPackNotificationsHint: String {
        t("사용 한도를 다 채워 팩을 받으면 알려줘요.",
           "Tells you when filling a usage limit earns a pack.",
           "使用上限を使い切ってパックを得たときに知らせます。",
           "Avisa cuando alcanzar un límite te da un sobre.",
           "Prévient quand atteindre une limite donne un booster.",
           "Avisa quando atingir um limite rende um pacote.")
    }
    func bonusPackNotificationBody(window: String, set: String, count: Int) -> String {
        t("\(window) 한도를 다 채웠어요 — \(set) 팩 \(count)개가 기다립니다.",
           "You maxed the \(window) limit — \(count) \(set) packs are waiting.",
           "\(window) の上限を使い切りました — \(set) パック\(count)つが待っています。",
           "Alcanzaste el límite de \(window): \(count) sobres de \(set) te esperan.",
           "Tu as atteint la limite \(window) : \(count) boosters \(set) t'attendent.",
           "Você atingiu o limite de \(window): \(count) pacotes de \(set) esperam.")
    }

    // MARK: 카드 판매

    var sellSpares: String { t("중복 판매", "Sell spares", "重複を売る",
                                "Vender repetidas", "Vendre les doubles", "Vender repetidas") }
    /// 값은 원화로 적는다. 모으는 것은 토큰이지만 카드값이 실제 시세에서 온 값이라,
    /// 파는 자리에서 토큰 자릿수를 보여 주면 얼마를 받는 것인지 가늠이 되지 않는다.
    func sellConfirm(_ count: Int, _ money: String) -> String {
        t("\(count)장을 팔아 \(money)을 받습니다. 한 장은 남습니다.",
           "Sell \(count) for \(money). One copy stays.",
           "\(count)枚を売って \(money)。1枚は残ります。",
           "Vende \(count) por \(money). Se conserva una.",
           "Vends \(count) pour \(money). Un exemplaire reste.",
           "Venda \(count) por \(money). Uma cópia fica.")
    }
    /// 판매가에 도감 추가금이 얹혀 있을 때 그 사실을 적는다.
    func sellBonusIncluded(_ value: Double) -> String {
        let percent = Self.percent(value)
        return t("판매 추가금 +\(percent) 포함", "includes +\(percent) sale bonus",
                  "販売ボーナス +\(percent) 込み", "incluye +\(percent) de bonificación",
                  "bonus de vente +\(percent) inclus", "inclui bônus de venda +\(percent)")
    }
    func sellDone(_ money: String) -> String {
        t("+\(money)", "+\(money)", "+\(money)", "+\(money)", "+\(money)", "+\(money)")
    }

    // MARK: 사죄의 사료

    var giftTitle: String { t("사죄의 사료", "An apology treat", "おわびのごはん",
                               "Un obsequio de disculpa", "Un cadeau d'excuse",
                               "Um agrado de desculpas") }
    /// 무엇이 들어왔는지 숫자로 적는다. 「보상을 드렸습니다」만 있으면 확인하러 탭을 뒤져야 한다.
    func giftBody(_ packs: Int, _ money: String) -> String {
        t("값이 잘못 보이던 문제로 불편을 드렸어요. 팩 \(packs)개와 \(money)을 넣어 뒀습니다.",
           "Sorry about the prices showing wrong. \(packs) packs and \(money) are in your wallet.",
           "価格の表示が誤っていた件、失礼しました。パック \(packs)個と \(money) を入れておきました。",
           "Perdón por los precios mal mostrados. Te dejamos \(packs) sobres y \(money).",
           "Désolé pour les prix mal affichés. \(packs) boosters et \(money) t'attendent.",
           "Desculpe pelos preços exibidos errado. \(packs) pacotes e \(money) estão na carteira.")
    }

    // MARK: 한번에 판매

    var bulkSell: String { t("한번에 판매", "Sell in bulk", "まとめて売る",
                              "Vender en lote", "Vendre en lot", "Vender em lote") }
    /// 무엇을 고르는 화면인지 한 줄로. 「중복분만」이 규칙의 핵심이라 여기 적는다.
    var bulkSellPrompt: String { t("얼마 이하인 카드의 중복분을 팔까요?",
                                    "Sell spare copies of cards worth up to…",
                                    "いくら以下のカードの重複を売りますか？",
                                    "¿Vender repetidas de cartas hasta…?",
                                    "Vendre les doubles des cartes jusqu'à…",
                                    "Vender repetidas de cartas até…?") }
    /// 임계값 칩. "1,000원 이하" 처럼 읽힌다.
    func bulkSellUpTo(_ money: String) -> String {
        t("\(money) 이하", "up to \(money)", "\(money) 以下",
           "hasta \(money)", "jusqu'à \(money)", "até \(money)")
    }
    /// 팔릴 것의 요약.
    func bulkSellSummary(_ kinds: Int, _ copies: Int, _ money: String) -> String {
        t("\(kinds)종 · \(copies)장 · +\(money)",
           "\(kinds) kinds · \(copies) cards · +\(money)",
           "\(kinds)種 · \(copies)枚 · +\(money)",
           "\(kinds) tipos · \(copies) cartas · +\(money)",
           "\(kinds) types · \(copies) cartes · +\(money)",
           "\(kinds) tipos · \(copies) cartas · +\(money)")
    }
    var bulkSellNothing: String { t("팔 중복이 없어요", "No spares to sell", "売る重複がありません",
                                     "No hay repetidas", "Aucun double", "Nenhuma repetida") }
    /// 되돌릴 수 없다는 것을 확인 앞에 적는다.
    var bulkSellConfirm: String { t("한 종류에 한 장씩은 남습니다. 되돌릴 수 없어요.",
                                     "One copy of each stays. This can't be undone.",
                                     "各1枚は残ります。取り消せません。",
                                     "Se conserva una de cada. No se puede deshacer.",
                                     "Un exemplaire de chaque reste. Irréversible.",
                                     "Uma cópia de cada fica. Não pode ser desfeito.") }
    func bulkSellDone(_ copies: Int, _ money: String) -> String {
        t("\(copies)장을 팔아 \(money)을 받았어요",
           "Sold \(copies) cards for \(money)",
           "\(copies)枚を売って \(money)",
           "Vendiste \(copies) cartas por \(money)",
           "\(copies) cartes vendues pour \(money)",
           "Vendeu \(copies) cartas por \(money)")
    }

    // MARK: 등급

    /// 등급 배지 — 국내 커뮤니티가 쓰는 약칭을 그대로 쓴다. 카드에 인쇄된 표기라 언어와 무관하다.
    func tierBadge(_ tier: CardTier) -> String { tier.rawValue }

    /// 등급 전체 이름. 배지만으로는 처음 보는 사용자가 뜻을 모르므로 상세에서 함께 보여준다.
    func tierName(_ tier: CardTier) -> String {
        switch tier {
        case .energy:         return t("에너지", "Energy", "エネルギー", "Energía", "Énergie", "Energia")
        case .common:         return t("커먼", "Common", "コモン", "Común", "Commune", "Comum")
        case .uncommon:       return t("언커먼", "Uncommon", "アンコモン", "Poco común", "Peu commune", "Incomum")
        case .rare:           return t("레어", "Rare", "レア", "Rara", "Rare", "Rara")
        case .doubleRare:     return t("더블레어", "Double Rare", "ダブルレア", "Doble rara", "Double rare", "Dupla rara")
        case .tripleRare:     return t("트리플레어", "Triple Rare", "トリプルレア", "Triple rara", "Triple rare", "Tripla rara")
        case .artRare:        return t("아트레어", "Art Rare", "アートレア", "Arte rara", "Art rare", "Arte rara")
        case .superRare:      return t("슈퍼레어", "Super Rare", "スーパーレア", "Súper rara", "Super rare", "Super rara")
        case .specialArtRare: return t("스페셜아트레어", "Special Art Rare", "スペシャルアートレア",
                                        "Arte especial rara", "Art spécial rare", "Arte especial rara")
        case .ultraRare:      return t("울트라레어", "Ultra Rare", "ウルトラレア", "Ultra rara", "Ultra rare", "Ultra rara")
        }
    }

    // MARK: 보너스 팩 알림
    var bonusPackTitle: String { t("보너스 팩 도착!", "Bonus pack!", "ボーナスパック！",
                                    "¡Sobre extra!", "Booster bonus !", "Pacote bônus!") }
    func bonusPackBody(window: String, set: String, count: Int) -> String {
        t("\(window) 한도를 다 채웠어요 — \(set) 팩 \(count)개를 받았어요.",
           "You maxed the \(window) limit — \(count) \(set) packs.",
           "\(window) の上限を使い切りました — \(set) パックを\(count)つ獲得。",
           "Alcanzaste el límite de \(window): \(count) sobres de \(set).",
           "Tu as atteint la limite \(window) : \(count) boosters \(set).",
           "Você atingiu o limite de \(window): \(count) pacotes de \(set).")
    }

    // MARK: 오류
    var cardIndexMissing: String { t("카드 목록을 불러올 수 없어요.", "Couldn't load the card list.",
                                      "カードリストを読み込めません。", "No se pudo cargar la lista de cartas.",
                                      "Impossible de charger la liste des cartes.", "Não foi possível carregar a lista de cartas.") }

    /// 시대에 든 세트 수. 「18개」처럼 읽힌다.
    func shopPackCount(_ count: Int) -> String {
        t("\(count)개", "\(count)", "\(count)個", "\(count)", "\(count)", "\(count)")
    }
    var shopPacksSection: String { t("일반 팩", "Packs", "通常パック",
                                      "Sobres", "Boosters", "Pacotes") }

    // MARK: 오리파
    var oripaTitle: String { t("오리파", "Oripa", "オリパ", "Oripa", "Oripa", "Oripa") }
    var oripaSubtitle: String { t("상위 등급만 담은 뽑기", "A draw of high rarities only",
                                   "上位レアだけの一発勝負", "Solo cartas de alta rareza",
                                   "Uniquement des hautes raretés", "Só cartas de alta raridade") }
    /// 두 문장을 각각 한 줄에 둔다. 이어 붙이면 줄바꿈이 문장 가운데서 일어나 읽기 나쁘다.
    var oripaHint: String { t("여러 세트에서 골라 담은 100장짜리 박스예요.\n한 장씩 뽑으면 그 카드는 박스에서 빠집니다.",
                               "A 100-card box drawn from every set.\nEach pull removes that card from the box.",
                               "全セットから選んだ100枚の箱です。\n引いたカードは箱から抜けます。",
                               "Una caja de 100 cartas de todos los sets.\nCada tirada retira esa carta.",
                               "Une boîte de 100 cartes tirées de tous les sets.\nChaque tirage retire la carte.",
                               "Uma caixa de 100 cartas de todos os sets.\nCada tiragem remove a carta.") }
    var oripaPull: String { t("뽑기", "Pull", "引く", "Tirar", "Tirer", "Tirar") }
    var oripaDrawHint: String { t("밀어서 확인", "Slide to reveal", "スライドして確認",
                                  "Desliza para ver", "Fais glisser pour voir",
                                  "Deslize para ver") }
    var oripaPullConfirm: String { t("뽑을까요?", "Draw?", "引きますか？",
                                     "¿Tirar?", "Tirer ?", "Tirar?") }
    /// 마지막 장에서 요약으로 넘어가는 버튼.
    var packSeeResult: String { t("결과 보기", "See results", "結果を見る",
                                   "Ver resultados", "Voir les résultats", "Ver resultados") }
    var oripaSeeDetail: String { t("자세히 보기", "See details", "詳しく見る",
                                    "Ver detalles", "Voir la carte", "Ver detalhes") }
    func oripaRemaining(_ left: Int, _ total: Int) -> String {
        t("남은 슬롯 \(left) / \(total)", "\(left) of \(total) slots left", "残り \(left) / \(total)",
           "\(left) de \(total) ranuras", "\(left) sur \(total) restantes", "\(left) de \(total) restantes")
    }
    func oripaBoxNumber(_ serial: Int) -> String {
        t("\(serial)번 박스", "Box #\(serial)", "\(serial)番の箱",
           "Caja n.º \(serial)", "Boîte n° \(serial)", "Caixa nº \(serial)")
    }
    var oripaReplace: String { t("새 박스로", "New box", "新しい箱に",
                                  "Caja nueva", "Nouvelle boîte", "Caixa nova") }
    /// 확인 문구는 한 줄을 넘기지 않는다. 버튼이 「새 박스로 / 취소」라 질문은 짧아도 통하고,
    /// 길면 줄바꿈이 생겨 확인을 누를 때마다 화면이 덜컹거린다. 자세한 설명은 툴팁에 둔다.
    var oripaReplaceConfirm: String { t("버릴까요?", "Discard?", "捨てますか？",
                                         "¿Descartar?", "Jeter ?", "Descartar?") }
    var oripaReplaceHelp: String { t("지금 박스를 버리고 새 박스를 받아요. 값은 들지 않아요.",
                                      "Discard this box for a fresh one. It costs nothing.",
                                      "今の箱を捨てて新しい箱を受け取ります。無料です。",
                                      "Descarta esta caja por una nueva. Es gratis.",
                                      "Remplace cette boîte par une neuve. C'est gratuit.",
                                      "Troca esta caixa por uma nova. É grátis.") }
    func oripaOwnedCount(_ count: Int) -> String {
        t("이미 가진 카드 \(count)장", "\(count) you already own", "所持済み \(count)枚",
           "\(count) que ya tienes", "\(count) déjà possédées", "\(count) que você já tem")
    }
    var oripaRefilled: String { t("박스를 다 비웠어요. 새 박스가 들어왔습니다.",
                                   "You cleared the box. A fresh one is in.",
                                   "箱を空にしました。新しい箱が入りました。",
                                   "Vaciaste la caja. Ha llegado una nueva.",
                                   "Tu as vidé la boîte. Une nouvelle est arrivée.",
                                   "Você esvaziou a caixa. Chegou uma nova.") }

    // MARK: 갓팩
    var godPackTitle: String { t("갓팩!", "God Pack!", "神引き！", "¡Sobre dorado!",
                                  "Booster divin !", "Pacote divino!") }
    var godPackHint: String { t("이 팩은 전부 레어 이상이에요.", "Every card in this pack is rare or better.",
                                 "このパックは全てレア以上です。", "Todas las cartas son raras o mejores.",
                                 "Toutes les cartes sont rares ou mieux.", "Todas as cartas são raras ou melhores.") }
    var godPackBadge: String { t("갓팩", "God Pack", "神引き", "Dorado", "Divin", "Divino") }

    /// 갓팩 확률 공시. 숨기면 지금까지 맞춰 온 원칙과 어긋난다.
    func godPackNote(_ oneIn: Int) -> String {
        t("\(oneIn)팩에 한 번꼴로 전 칸이 레어 이상인 갓팩이 나와요.",
           "About one pack in \(oneIn) is a God Pack — every card rare or better.",
           "約\(oneIn)パックに1回、全てレア以上の神引きが出ます。",
           "Uno de cada \(oneIn) sobres es dorado: todas las cartas raras o mejores.",
           "Environ 1 booster sur \(oneIn) est divin — toutes les cartes rares ou mieux.",
           "Cerca de 1 em \(oneIn) pacotes é divino — todas as cartas raras ou melhores.")
    }

    // MARK: 조합 도감
    var dexTab: String { t("도감", "Dex", "図鑑", "Dex", "Dex", "Dex") }
    var dexComplete: String { t("완성", "Complete", "コンプリート", "Completo", "Complet", "Completo") }
    var dexClaim: String { t("보상 수령", "Claim reward", "報酬を受け取る",
                              "Reclamar", "Récupérer", "Resgatar") }
    var dexClaimed: String { t("수령 완료", "Claimed", "受取済み", "Reclamado", "Récupéré", "Resgatado") }
    var dexPerksNone: String { t("아직 없음", "None yet", "まだなし", "Ninguna", "Aucun", "Nenhum") }
    var dexGoBuyPack: String { t("이 팩 사러 가기", "Buy this pack", "このパックを買う",
                                  "Comprar este sobre", "Acheter ce booster", "Comprar este pacote") }
    var dexReward: String { t("완성 보상", "Reward", "完成報酬", "Recompensa", "Récompense", "Recompensa") }
    var dexPerksHeader: String { t("누적 혜택", "Perks", "累積ボーナス", "Ventajas", "Bonus", "Bônus") }
    var dexCompletedBanner: String { t("도감 완성!", "Dex complete!", "図鑑コンプリート！",
                                        "¡Dex completo!", "Dex complété !", "Dex completo!") }
    var dexCardBelongsTo: String { t("이 카드가 들어가는 도감", "Dexes using this card",
                                      "このカードが入る図鑑", "Dexes con esta carta",
                                      "Dex avec cette carte", "Dexes com esta carta") }
    var dexEmpty: String { t("도감 목록을 불러올 수 없어요.", "Couldn't load the dex list.",
                              "図鑑リストを読み込めません。", "No se pudo cargar la lista de dex.",
                              "Impossible de charger la liste des dex.", "Não foi possível carregar a lista.") }

    func dexProgress(_ owned: Int, _ total: Int) -> String { "\(owned) / \(total)" }

    func dexCountSummary(_ done: Int, _ total: Int) -> String {
        t("완성 \(done) / \(total)", "\(done) of \(total) complete", "\(total) 中 \(done) 完成",
           "\(done) de \(total) completos", "\(done) sur \(total) complétés", "\(done) de \(total) completos")
    }

    func dexRewardPacks(_ count: Int) -> String {
        t("팩 \(count)개", "\(count) packs", "パック \(count)個",
           "\(count) sobres", "\(count) boosters", "\(count) pacotes")
    }
    /// 어느 세트 팩을 받는지는 개수만으로는 알 수 없다.
    func dexRewardPacksHelp(_ count: Int, _ setName: String) -> String {
        t("\(setName) 팩 \(count)개를 받아요.",
           "You get \(count) \(setName) packs.",
           "\(setName) パックを \(count)個もらえます。",
           "Recibes \(count) sobres de \(setName).",
           "Tu reçois \(count) boosters \(setName).",
           "Você recebe \(count) pacotes de \(setName).")
    }

    /// 한 팩에서 이 카드가 나올 확률. 없는 카드를 눌렀을 때 보여준다 —
    /// 얼마나 먼 카드인지 알아야 계속 살지 판단할 수 있다.
    func dexPullChance(_ percent: String) -> String {
        t("한 팩에서 \(percent)", "\(percent) per pack", "1パックあたり \(percent)",
           "\(percent) por sobre", "\(percent) par booster", "\(percent) por pacote")
    }

    /// 혜택 한 줄. 종류 이름과 부호 붙은 값을 함께 적는다.
    func dexPerkText(_ perk: DexPerk) -> String {
        switch perk.kind {
        case .tokenGain:    return "\(dexPerkTokenGain) +\(Self.percent(perk.value))"
        case .packDiscount: return "\(dexPerkPackDiscount) −\(Self.percent(perk.value))"
        case .dustBonus:    return "\(dexPerkDustBonus) +\(Self.percent(perk.value))"
        case .hitOdds:      return "\(dexPerkHitOdds) +\(Self.percent(perk.value))"
        }
    }

    /// 누적 혜택 한 항목. 0 이면 nil — 화면이 그 칸을 아예 만들지 않게 한다.
    func dexPerkSummaryItem(_ kind: DexPerkKind, _ perks: DexPerks) -> String? {
        switch kind {
        case .tokenGain:
            return perks.tokenGain > 0 ? "\(dexPerkTokenGain) +\(Self.percent(perks.tokenGain))" : nil
        case .packDiscount:
            return perks.packDiscount > 0 ? "\(dexPerkPackDiscount) −\(Self.percent(perks.packDiscount))" : nil
        case .dustBonus:
            return perks.dustBonus > 0 ? "\(dexPerkDustBonus) +\(Self.percent(perks.dustBonus))" : nil
        case .hitOdds:
            return perks.hitOdds > 0 ? "\(dexPerkHitOdds) +\(Self.percent(perks.hitOdds))" : nil
        }
    }

    var dexPerkTokenGain: String { t("적립 토큰", "Token earning", "獲得トークン",
                                      "Tokens ganados", "Tokens gagnés", "Tokens ganhos") }
    var dexPerkPackDiscount: String { t("팩 가격", "Pack price", "パック価格", "Precio", "Prix", "Preço") }
    var dexPerkDustBonus: String { t("판매 추가금", "Sale bonus", "販売ボーナス",
                                      "Bonificación de venta", "Bonus de vente", "Bônus de venda") }
    var dexPerkHitOdds: String { t("상위 등급 확률", "Higher rarity odds", "上位レア確率",
                                    "Prob. de rareza alta", "Chance de haute rareté",
                                    "Chance de raridade alta") }

    /// 혜택이 실제로 무엇을 바꾸는지 한 줄로. 이름 위에 마우스를 올리면 뜬다.
    func dexPerkHelp(_ kind: DexPerkKind) -> String {
        switch kind {
        case .tokenGain:
            return t("코딩으로 쌓이는 토큰을 그만큼 더 받아요.",
                      "You earn that much more from the tokens you burn while coding.",
                      "コーディングで貯まるトークンをその分多く受け取れます。",
                      "Ganas ese porcentaje extra de tokens al programar.",
                      "Tu gagnes ce pourcentage de tokens en plus en codant.",
                      "Você ganha essa porcentagem extra de tokens ao programar.")
        case .packDiscount:
            return t("모든 팩을 그만큼 싸게 살 수 있어요.",
                      "Every pack costs that much less.",
                      "すべてのパックがその分安くなります。",
                      "Todos los sobres cuestan menos.",
                      "Tous les boosters coûtent moins cher.",
                      "Todos os pacotes ficam mais baratos.")
        case .dustBonus:
            return t("중복 카드를 팔 때 시세보다 그만큼 더 받아요.",
                      "Selling duplicates pays that much above market price.",
                      "重複カードを売るとき相場よりその分多くもらえます。",
                      "Vender duplicados paga ese porcentaje por encima del precio.",
                      "Vendre les doublons rapporte ce pourcentage au-dessus du marché.",
                      "Vender duplicatas paga essa porcentagem acima do mercado.")
        case .hitOdds:
            return t("팩마다 하나씩 들어오는 레어 이상 자리에서 더 높은 등급이 나올 확률이 올라가요.",
                      "The guaranteed rare slot rolls higher rarities more often.",
                      "パックごとの確定レア枠で上位レアが出やすくなります。",
                      "La carta rara garantizada sale con más rareza.",
                      "La carte rare garantie monte plus souvent en rareté.",
                      "A carta rara garantida sobe de raridade com mais frequência.")
        }
    }

    /// 0.005 → "0.5%". 소수점은 필요할 때만 쓴다.
    private static func percent(_ value: Double) -> String {
        let scaled = value * 100
        return scaled == scaled.rounded() ? "\(Int(scaled))%" : String(format: "%.1f%%", scaled)
    }
}
