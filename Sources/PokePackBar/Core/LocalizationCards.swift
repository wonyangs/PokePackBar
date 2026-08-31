import Foundation

/// 카드 게임 문구. 기존 문구 파일과 분리해 둔다 — 컴패니언을 걷어낸 뒤 남은 문구와
/// 새로 들어온 문구를 구분해서 보기 위한 것이다.
extension L {

    // MARK: 탭
    var packsTab: String { t("팩", "Packs", "パック", "Sobres", "Boosters", "Pacotes") }

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
    var walletBalance: String { t("쓸 수 있는 토큰", "Spendable tokens", "使えるトークン",
                                   "Tokens disponibles", "Tokens disponibles", "Tokens disponíveis") }
    var walletHint: String { t("코딩할 때 쓴 토큰으로 카드팩을 살 수 있어요.",
                                "Spend the tokens you burn while coding on card packs.",
                                "コーディングで使ったトークンでカードパックを買えます。",
                                "Gasta en sobres los tokens que consumes programando.",
                                "Dépense en boosters les tokens consommés en codant.",
                                "Compre pacotes com os tokens que você gasta programando.") }
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
    var shopCardHint: String { t("세트를 골라 팩을 사세요.", "Pick a set and buy a pack.",
                                  "セットを選んでパックを買いましょう。", "Elige un set y compra un sobre.",
                                  "Choisis un set et achète un booster.", "Escolha um set e compre um pacote.") }
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

    var packTotalCards: String { t("전체 카드", "Cards in set", "収録カード",
                                     "Cartas del set", "Cartes du set", "Cartas do set") }
    var packCollected: String { t("수집률", "Collected", "収集率", "Recolectadas", "Collectées", "Coletadas") }
    var packOdds: String { t("등급별 확률", "Odds by rarity", "レアリティ別確率",
                              "Probabilidad por rareza", "Probabilité par rareté", "Chance por raridade") }
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
    var collectionEmptyTitle: String { t("아직 카드가 없어요", "No cards yet", "カードがありません",
                                          "Sin cartas", "Aucune carte", "Nenhuma carta") }
    var collectionEmptyHint: String { t("팩을 뜯으면 여기에 모여요.", "Open a pack and they'll show up here.",
                                         "パックを開けるとここに集まります。", "Abre un sobre y aparecerán aquí.",
                                         "Ouvre un booster et elles apparaîtront ici.", "Abra um pacote e elas aparecerão aqui.") }
    var filterSet: String { t("세트", "Set", "セット", "Set", "Set", "Set") }
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

    // MARK: 카드 갈기

    var disenchant: String { t("중복 갈기", "Recycle spares", "重複を分解",
                                "Reciclar repetidas", "Recycler les doubles", "Reciclar repetidas") }
    func disenchantConfirm(_ count: Int, _ tokens: String) -> String {
        t("\(count)장을 갈아 \(tokens) 토큰을 받습니다. 한 장은 남습니다.",
           "Recycle \(count) for \(tokens) tokens. One copy stays.",
           "\(count)枚を分解して \(tokens) トークン。1枚は残ります。",
           "Recicla \(count) por \(tokens) tokens. Se conserva una.",
           "Recycle \(count) pour \(tokens) tokens. Un exemplaire reste.",
           "Recicle \(count) por \(tokens) tokens. Uma cópia fica.")
    }
    func disenchantDone(_ tokens: String) -> String {
        t("+\(tokens) 토큰", "+\(tokens) tokens", "+\(tokens) トークン",
           "+\(tokens) tokens", "+\(tokens) tokens", "+\(tokens) tokens")
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

    var shopPacksSection: String { t("일반 팩", "Packs", "通常パック",
                                      "Sobres", "Boosters", "Pacotes") }

    // MARK: 오리파
    var oripaTitle: String { t("오리파", "Oripa", "オリパ", "Oripa", "Oripa", "Oripa") }
    var oripaSubtitle: String { t("상위 등급만 담은 뽑기", "A draw of high rarities only",
                                   "上位レアだけの一発勝負", "Solo cartas de alta rareza",
                                   "Uniquement des hautes raretés", "Só cartas de alta raridade") }
    var oripaHint: String { t("여러 세트에서 골라 담은 100장짜리 박스예요. 한 장씩 뽑으면 그 카드는 박스에서 빠집니다.",
                               "A 100-card box drawn from every set. Each pull removes that card from the box.",
                               "全セットから選んだ100枚の箱です。引いたカードは箱から抜けます。",
                               "Una caja de 100 cartas de todos los sets. Cada tirada retira esa carta.",
                               "Une boîte de 100 cartes tirées de tous les sets. Chaque tirage retire la carte.",
                               "Uma caixa de 100 cartas de todos os sets. Cada tiragem remove a carta.") }
    var oripaPull: String { t("뽑기", "Pull", "引く", "Tirar", "Tirer", "Tirar") }
    var oripaDrawHint: String { t("밀어서 확인", "Slide to reveal", "スライドして確認",
                                  "Desliza para ver", "Fais glisser pour voir",
                                  "Deslize para ver") }
    var oripaPullConfirm: String { t("뽑을까요?", "Draw?", "引きますか？",
                                     "¿Tirar?", "Tirer ?", "Tirar?") }
    var oripaSeeDetail: String { t("자세히 보기", "See details", "詳しく見る",
                                    "Ver detalles", "Voir la carte", "Ver detalhes") }
    var oripaContents: String { t("박스에 남은 카드", "Left in the box", "箱の残り",
                                   "Quedan en la caja", "Reste dans la boîte", "Resta na caixa") }
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
    var dexHint: String { t("카드를 묶어 도감을 완성하면 팩과 영구 혜택을 받아요.",
                             "Complete a dex to earn packs and a permanent perk.",
                             "図鑑を完成させるとパックと永続ボーナスがもらえます。",
                             "Completa un dex para ganar sobres y una ventaja permanente.",
                             "Complète un dex pour gagner des boosters et un bonus permanent.",
                             "Complete um dex para ganhar pacotes e um bônus permanente.") }
    var dexComplete: String { t("완성", "Complete", "コンプリート", "Completo", "Complet", "Completo") }
    var dexClaim: String { t("보상 수령", "Claim reward", "報酬を受け取る",
                              "Reclamar", "Récupérer", "Resgatar") }
    var dexClaimed: String { t("수령 완료", "Claimed", "受取済み", "Reclamado", "Récupéré", "Resgatado") }
    var dexPerksNone: String { t("아직 없음", "None yet", "まだなし", "Ninguna", "Aucun", "Nenhum") }
    var dexBlurbHeader: String { t("이 조합은", "About this dex", "この図鑑は",
                                    "Sobre este dex", "À propos", "Sobre este dex") }
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
        case .bonusPacks:   return "\(dexPerkBonusPacks) +\(Int(perk.value.rounded()))"
        case .extraHitSlot: return "\(dexPerkExtraHit) +\(Int(perk.value.rounded()))"
        case .duplicateGuard: return dexPerkDuplicateGuard
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
        case .bonusPacks:
            return perks.bonusPacks > 0 ? "\(dexPerkBonusPacks) +\(perks.bonusPacks)" : nil
        case .extraHitSlot:
            return perks.extraHitSlot > 0 ? "\(dexPerkExtraHit) +\(perks.extraHitSlot)" : nil
        case .duplicateGuard:
            return perks.duplicateGuard ? dexPerkDuplicateGuard : nil
        }
    }

    /// 지금까지 모은 혜택 요약. 0 인 항목은 적지 않는다.
    func dexPerksSummary(_ perks: DexPerks) -> String {
        var parts: [String] = []
        if perks.tokenGain > 0 { parts.append("\(dexPerkTokenGain) +\(Self.percent(perks.tokenGain))") }
        if perks.packDiscount > 0 { parts.append("\(dexPerkPackDiscount) −\(Self.percent(perks.packDiscount))") }
        if perks.dustBonus > 0 { parts.append("\(dexPerkDustBonus) +\(Self.percent(perks.dustBonus))") }
        if perks.hitOdds > 0 { parts.append("\(dexPerkHitOdds) +\(Self.percent(perks.hitOdds))") }
        if perks.bonusPacks > 0 { parts.append("\(dexPerkBonusPacks) +\(perks.bonusPacks)") }
        if perks.extraHitSlot > 0 { parts.append("\(dexPerkExtraHit) +\(perks.extraHitSlot)") }
        if perks.duplicateGuard { parts.append(dexPerkDuplicateGuard) }
        return parts.joined(separator: "  ·  ")
    }

    var dexPerkTokenGain: String { t("적립 토큰", "Token earning", "獲得トークン",
                                      "Tokens ganados", "Tokens gagnés", "Tokens ganhos") }
    var dexPerkPackDiscount: String { t("팩 가격", "Pack price", "パック価格", "Precio", "Prix", "Preço") }
    var dexPerkDustBonus: String { t("갈갈 환급", "Recycle", "分解還元", "Reciclaje", "Recyclage", "Reciclagem") }
    var dexPerkHitOdds: String { t("상위 등급 확률", "Higher rarity odds", "上位レア確率",
                                    "Prob. de rareza alta", "Chance de haute rareté",
                                    "Chance de raridade alta") }
    var dexPerkBonusPacks: String { t("보너스 팩", "Bonus packs", "ボーナスパック",
                                       "Sobres extra", "Boosters bonus", "Pacotes bônus") }
    var dexPerkExtraHit: String { t("레어 이상 확정", "Guaranteed rare+", "レア以上確定",
                                     "Rara garantizada", "Rare garantie", "Rara garantida") }
    var dexPerkDuplicateGuard: String { t("중복 회피", "Duplicate guard", "重複回避",
                                            "Evita duplicados", "Anti-doublon", "Evita duplicadas") }

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
            return t("중복 카드를 갈 때 돌려받는 토큰이 늘어요.",
                      "Recycling duplicates gives back more tokens.",
                      "重複カードを分解したときの還元が増えます。",
                      "Reciclar duplicados devuelve más tokens.",
                      "Recycler les doublons rapporte plus de tokens.",
                      "Reciclar duplicatas devolve mais tokens.")
        case .hitOdds:
            return t("팩마다 하나씩 들어오는 레어 이상 자리에서 더 높은 등급이 나올 확률이 올라가요.",
                      "The guaranteed rare slot rolls higher rarities more often.",
                      "パックごとの確定レア枠で上位レアが出やすくなります。",
                      "La carta rara garantizada sale con más rareza.",
                      "La carte rare garantie monte plus souvent en rareté.",
                      "A carta rara garantida sobe de raridade com mais frequência.")
        case .bonusPacks:
            return t("사용 한도를 다 채웠을 때 받는 보너스 팩이 늘어요.",
                      "You get more bonus packs when you max a usage limit.",
                      "使用上限を使い切ったときのボーナスパックが増えます。",
                      "Recibes más sobres extra al alcanzar el límite de uso.",
                      "Tu reçois plus de boosters bonus en atteignant la limite.",
                      "Você recebe mais pacotes bônus ao atingir o limite de uso.")
        case .extraHitSlot:
            return t("팩마다 레어 이상 확정 칸이 하나 늘어요. 10장 팩이 11장이 됩니다.",
                      "Every pack holds one more rare-or-better card.",
                      "パックごとにレア以上のカードが1枚増えます。",
                      "Cada sobre trae una carta rara adicional.",
                      "Chaque booster contient une carte rare de plus.",
                      "Cada pacote traz mais uma carta rara.")
        case .duplicateGuard:
            return t("레어 이상 자리에서 이미 가진 카드가 나오면 한 번 다시 뽑아요.",
                      "The rare-or-better slot rerolls once when it hits a card you own.",
                      "レア以上の枠で所持済みが出たら一度引き直します。",
                      "La carta rara se vuelve a tirar si ya la tienes.",
                      "La carte rare est retirée une fois si tu l'as déjà.",
                      "A carta rara é sorteada de novo se você já a tem.")
        }
    }

    /// 0.005 → "0.5%". 소수점은 필요할 때만 쓴다.
    private static func percent(_ value: Double) -> String {
        let scaled = value * 100
        return scaled == scaled.rounded() ? "\(Int(scaled))%" : String(format: "%.1f%%", scaled)
    }
}
