import Foundation

/// 온라인 창, 계정 창, 메뉴바의 온라인 줄에서 쓰는 문구.
///
/// 예전에는 이 화면들만 한국어로 고정돼 있었다. 다른 언어를 고른 사람도 마켓과 교환을
/// 읽을 수 있게 여기로 모았다.

// MARK: 공통 조각

extension L {
    /// 카드 장수. 영어권은 한 장일 때 단수로 쓴다.
    func cardsCount(_ n: Int) -> String {
        let s = n.formatted()
        return t("\(s)장", n == 1 ? "1 card" : "\(s) cards", "\(s)枚", n == 1 ? "1 carta" : "\(s) cartas",
                 n == 1 ? "1 carte" : "\(s) cartes", n == 1 ? "1 carta" : "\(s) cartas")
    }
    func packsCount(_ n: Int) -> String {
        let s = n.formatted()
        return t("\(s)팩", n == 1 ? "1 pack" : "\(s) packs", "\(s)パック", n == 1 ? "1 sobre" : "\(s) sobres",
                 n == 1 ? "1 booster" : "\(s) boosters", n == 1 ? "1 pacote" : "\(s) pacotes")
    }
    /// 종류 수(서로 다른 카드).
    func kindsCount(_ n: Int) -> String {
        let s = n.formatted()
        return t("\(s)종", n == 1 ? "1 kind" : "\(s) kinds", "\(s)種", n == 1 ? "1 tipo" : "\(s) tipos",
                 n == 1 ? "1 type" : "\(s) types", n == 1 ? "1 tipo" : "\(s) tipos")
    }
    var previousPage: String { t("이전", "Previous", "前へ", "Anterior", "Précédent", "Anterior") }
    var nextPage: String { t("다음", "Next", "次へ", "Siguiente", "Suivant", "Próxima") }
    var maxQuantity: String { t("최대", "Max", "最大", "Máx.", "Max", "Máx.") }
    var removeCard: String { t("빼기", "Remove", "外す", "Quitar", "Retirer", "Remover") }
    var signIn: String { t("로그인하기", "Sign in", "ログインする", "Iniciar sesión", "Se connecter", "Entrar") }
    var searching: String { t("찾는 중…", "Searching…", "検索中…", "Buscando…", "Recherche…", "Buscando…") }
    var noMatchingCards: String { t("맞는 카드가 없어요", "No matching cards", "一致するカードがありません", "No hay cartas que coincidan", "Aucune carte correspondante", "Nenhuma carta encontrada") }
    var searchMyCards: String { t("내 카드에서 찾기", "Search my cards", "自分のカードから探す", "Buscar en mis cartas", "Chercher dans mes cartes", "Buscar nas minhas cartas") }
    /// 카드 고르는 창에서 아무것도 고르지 않았을 때. 여러 장을 한 번에 담을 수 있다는 것을 알린다.
    var pickCardsHint: String {
        t("카드를 눌러 여러 장 고르세요", "Tap cards to pick several", "カードを押して複数選べます",
          "Toca cartas para elegir varias", "Touchez des cartes pour en choisir plusieurs",
          "Toque nas cartas para escolher várias")
    }
    func pickedKinds(_ n: Int) -> String {
        t("\(n)종 선택", "\(n) picked", "\(n)種を選択", "\(n) elegidas", "\(n) choisies", "\(n) escolhidas")
    }
    var pickAnotherCard: String { t("다른 카드 고르기", "Choose another card", "別のカードを選ぶ", "Elegir otra carta", "Choisir une autre carte", "Escolher outra carta") }
    var spareCardsHint: String {
        t("같은 카드를 2장 이상 가지고 있으면 여기에 나타나요. 한 장은 늘 남겨 둬요.",
          "Cards you own two or more of appear here. You always keep one.",
          "同じカードを2枚以上持っているとここに表示されます。1枚は必ず手元に残ります。",
          "Aquí aparecen las cartas que tienes repetidas. Siempre te quedas una.",
          "Les cartes que vous avez en double apparaissent ici. Vous en gardez toujours une.",
          "Cartas que você tem repetidas aparecem aqui. Você sempre fica com uma.")
    }
    var expiredLabel: String { t("기간 끝남", "Expired", "期限切れ", "Caducado", "Expiré", "Expirado") }
    var gameMode: String { t("게임 모드", "Game mode", "ゲームモード", "Modo juego", "Mode jeu", "Modo jogo") }
    var physicalMode: String { t("실물 모드", "Physical mode", "実物モード", "Modo físico", "Mode physique", "Modo físico") }
    var allSetsOption: String { t("모든 세트", "All sets", "すべてのセット", "Todos los sets", "Toutes les extensions", "Todas as coleções") }
    var setLabel: String { t("세트", "Set", "セット", "Set", "Extension", "Coleção") }
    var noneLabel: String { t("없음", "None", "なし", "Ninguno", "Aucun", "Nenhum") }
    var online: String { t("온라인", "Online", "オンライン", "En línea", "En ligne", "Online") }
    var copyAction: String { t("복사", "Copy", "コピー", "Copiar", "Copier", "Copiar") }
    var copiedAction: String { t("복사했어요", "Copied", "コピーしました", "Copiado", "Copié", "Copiado") }
}

// MARK: 온라인 창 공통 (OnlineKit)

extension L {
    var listingActive: String { t("판매 중", "On sale", "販売中", "En venta", "En vente", "À venda") }
    var listingSold: String { t("다 팔림", "Sold out", "完売", "Agotado", "Épuisé", "Esgotado") }
    var listingCancelled: String { t("내림", "Taken down", "取り下げ", "Retirado", "Retiré", "Retirado") }
    var tradePending: String { t("답 기다리는 중", "Awaiting reply", "返事待ち", "Esperando respuesta", "En attente de réponse", "Aguardando resposta") }
    var tradeAccepted: String { t("교환 완료", "Traded", "交換完了", "Intercambiado", "Échangé", "Trocado") }
    var tradeRejected: String { t("거절됨", "Declined", "断られました", "Rechazado", "Refusé", "Recusado") }
    var tradeCancelled: String { t("취소됨", "Cancelled", "取り消し", "Cancelado", "Annulé", "Cancelado") }

    var noteTradeRequest: String { t("새 교환 제안이 왔어요", "New trade offer", "新しい交換の提案が届きました", "Nueva oferta de intercambio", "Nouvelle offre d’échange", "Nova proposta de troca") }
    var noteTradeAccepted: String { t("교환이 성사됐어요", "Trade completed", "交換が成立しました", "Intercambio completado", "Échange conclu", "Troca concluída") }
    var noteTradeRejected: String { t("교환 제안이 거절됐어요", "Trade offer declined", "交換の提案が断られました", "Oferta rechazada", "Offre refusée", "Proposta recusada") }
    var noteTradeCancelled: String { t("교환 제안이 취소됐어요", "Trade offer cancelled", "交換の提案が取り消されました", "Oferta cancelada", "Offre annulée", "Proposta cancelada") }
    var noteTradeExpired: String { t("교환 제안 기간이 끝났어요", "Trade offer expired", "交換の提案が期限切れになりました", "La oferta caducó", "L’offre a expiré", "A proposta expirou") }
    var noteListingSold: String { t("올린 카드가 팔렸어요", "Your listing sold", "出品したカードが売れました", "Se vendió tu carta", "Votre carte s’est vendue", "Sua carta foi vendida") }
    var noteListingBought: String { t("마켓에서 카드를 샀어요", "You bought a card on the market", "マーケットでカードを買いました", "Compraste una carta en el mercado", "Vous avez acheté une carte au marché", "Você comprou uma carta no mercado") }
    var noteListingExpired: String { t("판매 기간이 끝나 카드가 돌아왔어요", "Listing expired, the card is back", "出品期限が切れてカードが戻りました", "La venta caducó y la carta volvió", "Vente expirée, la carte est revenue", "A venda expirou e a carta voltou") }
    var noteWishlistListing: String { t("위시리스트 카드가 마켓에 올라왔어요", "A wishlist card is on the market", "ウィッシュリストのカードが出品されました", "Una carta de tu lista de deseos está en venta", "Une carte de votre liste d’envies est en vente", "Uma carta da sua lista de desejos está à venda") }
    var noteFriendRequest: String { t("친구 신청이 왔어요", "New friend request", "フレンド申請が届きました", "Nueva solicitud de amistad", "Nouvelle demande d’ami", "Novo pedido de amizade") }
    var noteFriendAccepted: String { t("친구 신청이 수락됐어요", "Friend request accepted", "フレンド申請が承認されました", "Solicitud de amistad aceptada", "Demande d’ami acceptée", "Pedido de amizade aceito") }
    var noteFriendRejected: String { t("친구 신청이 거절됐어요", "Friend request declined", "フレンド申請が断られました", "Solicitud de amistad rechazada", "Demande d’ami refusée", "Pedido de amizade recusado") }
    var noteFriendExpired: String { t("친구 신청 기간이 끝났어요", "Friend request expired", "フレンド申請が期限切れになりました", "La solicitud de amistad caducó", "La demande d’ami a expiré", "O pedido de amizade expirou") }

    func daysLeft(_ n: Int) -> String { t("\(n)일 남음", "\(n)d left", "残り\(n)日", "Quedan \(n) d", "\(n) j restants", "Faltam \(n) d") }
    func hoursLeft(_ n: Int) -> String { t("\(n)시간 남음", "\(n)h left", "残り\(n)時間", "Quedan \(n) h", "\(n) h restantes", "Faltam \(n) h") }
    var endingSoon: String { t("곧 끝나요", "Ending soon", "まもなく終了", "Termina pronto", "Bientôt terminé", "Termina em breve") }

    var finishLabel: String { t("판형", "Finish", "仕様", "Acabado", "Finition", "Acabamento") }
    var anyFinish: String { t("어떤 판형이든", "Any finish", "どの仕様でも", "Cualquier acabado", "Toute finition", "Qualquer acabamento") }
    var searchCardNameKoEn: String { t("카드 이름으로 찾기 (한국어, 영어)", "Search by card name (English or Korean)", "カード名で検索（韓国語、英語）", "Buscar por nombre (inglés o coreano)", "Rechercher par nom (anglais ou coréen)", "Buscar por nome (inglês ou coreano)") }
    var typeCardName: String { t("찾을 카드 이름을 입력하세요", "Type a card name", "カード名を入力してください", "Escribe el nombre de una carta", "Saisissez un nom de carte", "Digite o nome de uma carta") }
    func catalogueResultCount(_ n: Int) -> String {
        let s = n.formatted()
        return t("\(s)장, 이름이 같은 카드부터 시세 높은 순이에요.", "\(s) cards. Exact name matches first, then by price.",
                 "\(s)枚。名前が一致するカードから、相場の高い順です。", "\(s) cartas. Primero el nombre exacto, luego por precio.",
                 "\(s) cartes. Nom exact d’abord, puis par prix.", "\(s) cartas. Nome exato primeiro, depois por preço.")
    }
    func offerableCount(_ n: Int) -> String { t("내놓을 수 있는 카드 \(n)장", "\(n) available to offer", "出せるカード\(n)枚", "\(n) disponibles para ofrecer", "\(n) disponibles à proposer", "\(n) disponíveis para oferecer") }
    var noOfferableCards: String { t("내놓을 수 있는 카드가 없어요", "No cards to offer", "出せるカードがありません", "No tienes cartas para ofrecer", "Aucune carte à proposer", "Nenhuma carta para oferecer") }
    func availableCount(_ n: Int) -> String { t("\(n)장 가능", "\(n) available", "\(n)枚可", "\(n) disp.", "\(n) dispo.", "\(n) disp.") }

    var notSignedInOnline: String { t("온라인 계정에 로그인하지 않았어요.", "You’re not signed in to an online account.", "オンラインアカウントにログインしていません。", "No has iniciado sesión en una cuenta en línea.", "Vous n’êtes pas connecté à un compte en ligne.", "Você não entrou em uma conta online.") }
    var problemSignedOut: String { t("로그인이 필요해요", "Sign-in required", "ログインが必要です", "Debes iniciar sesión", "Connexion requise", "É preciso entrar") }
    var problemUnreachable: String { t("서버에 연결하지 못했어요", "Couldn’t reach the server", "サーバーに接続できませんでした", "No se pudo conectar con el servidor", "Impossible de joindre le serveur", "Não foi possível conectar ao servidor") }
    var problemServer: String { t("서버에서 오류가 났어요", "The server ran into an error", "サーバーでエラーが発生しました", "El servidor tuvo un error", "Le serveur a rencontré une erreur", "O servidor teve um erro") }
    var problemRejected: String { t("요청이 처리되지 않았어요", "The request wasn’t processed", "リクエストは処理されませんでした", "La solicitud no se procesó", "La requête n’a pas été traitée", "A solicitação não foi processada") }
    var problemOther: String { t("온라인 기능을 잠시 쓸 수 없어요", "Online features are unavailable for now", "オンライン機能を一時的に使えません", "Las funciones en línea no están disponibles ahora", "Fonctions en ligne indisponibles pour le moment", "Recursos online indisponíveis no momento") }
    var problemSignedOutHint: String { t("계정 창에서 로그인하면 바로 이어서 쓸 수 있어요.", "Sign in from the account window to pick up where you left off.", "アカウント画面でログインすると、すぐに続きから使えます。", "Inicia sesión en la ventana de cuenta para continuar.", "Connectez-vous dans la fenêtre du compte pour reprendre.", "Entre pela janela da conta para continuar.") }
    var showingLastLoaded: String { t("마지막으로 불러온 내용을 보여 주는 중이에요.", "Showing what was last loaded.", "最後に読み込んだ内容を表示しています。", "Mostrando lo último que se cargó.", "Affichage des dernières données chargées.", "Mostrando o último conteúdo carregado.") }
    var problemUnreachableHint: String { t("마지막으로 불러온 내용을 보여 주는 중이에요. 연결되면 다시 거래할 수 있어요.", "Showing what was last loaded. You can trade again once connected.", "最後に読み込んだ内容を表示しています。接続すると再び取引できます。", "Mostrando lo último que se cargó. Podrás comerciar al reconectar.", "Affichage des dernières données chargées. Vous pourrez échanger une fois reconnecté.", "Mostrando o último conteúdo carregado. Você poderá negociar ao reconectar.") }
    var problemServerHint: String { t("내 카드와 금액은 바뀌지 않았어요. 계속되면 아래 요청 번호를 알려 주세요.", "Your cards and balance didn’t change. If this keeps happening, share the request number below.", "カードと残高は変わっていません。続く場合は下のリクエスト番号をお知らせください。", "Tus cartas y tu saldo no cambiaron. Si sigue pasando, comparte el número de solicitud de abajo.", "Vos cartes et votre solde n’ont pas changé. Si cela persiste, communiquez le numéro de requête ci-dessous.", "Suas cartas e seu saldo não mudaram. Se continuar, informe o número da solicitação abaixo.") }
    func requestNumber(_ id: String) -> String { t("요청 번호 \(id)", "Request \(id)", "リクエスト番号 \(id)", "Solicitud \(id)", "Requête \(id)", "Solicitação \(id)") }
    var showLogs: String { t("로그 보기", "Show logs", "ログを見る", "Ver registros", "Voir les journaux", "Ver registros") }
    func reconnectIn(_ seconds: Int) -> String { t("\(seconds)초 뒤에 다시 연결해요", "Reconnecting in \(seconds)s", "\(seconds)秒後に再接続します", "Reconectando en \(seconds) s", "Reconnexion dans \(seconds) s", "Reconectando em \(seconds) s") }
}

// MARK: 온라인 창 (OnlineWindow)

extension L {
    func onlineTab(_ tab: OnlineHubModel.Tab) -> String {
        switch tab {
        case .market: t("마켓", "Market", "マーケット", "Mercado", "Marché", "Mercado")
        case .trades: t("교환", "Trades", "交換", "Intercambios", "Échanges", "Trocas")
        case .social: t("친구", "Friends", "フレンド", "Amigos", "Amis", "Amigos")
        case .stats: t("개봉 분석", "Opening stats", "開封分析", "Análisis de aperturas", "Analyse des ouvertures", "Análise de aberturas")
        case .jobs: t("대량 개봉", "Bulk opening", "大量開封", "Apertura masiva", "Ouverture en masse", "Abertura em massa")
        case .alerts: t("알림", "Alerts", "通知", "Avisos", "Alertes", "Alertas")
        }
    }
    var onlineWindowTitle: String { t("PokePackBar 온라인", "PokePackBar Online", "PokePackBar オンライン", "PokePackBar en línea", "PokePackBar en ligne", "PokePackBar online") }
    var localModeNotice: String {
        t("이 Mac은 아직 로컬 모드예요. 로그인하고 온라인 모드를 켜면 마켓, 교환, 친구를 쓸 수 있어요.",
          "This Mac is still in local mode. Sign in and turn on online mode to use the market, trades and friends.",
          "このMacはまだローカルモードです。ログインしてオンラインモードをオンにすると、マーケット、交換、フレンドを使えます。",
          "Este Mac sigue en modo local. Inicia sesión y activa el modo en línea para usar el mercado, los intercambios y los amigos.",
          "Ce Mac est encore en mode local. Connectez-vous et activez le mode en ligne pour utiliser le marché, les échanges et les amis.",
          "Este Mac ainda está no modo local. Entre e ative o modo online para usar o mercado, as trocas e os amigos.")
    }
    var onlineLoginRequired: String { t("온라인 로그인이 필요합니다.", "Online sign-in required.", "オンラインログインが必要です。", "Debes iniciar sesión en línea.", "Connexion en ligne requise.", "É preciso entrar online.") }
    var actionDone: String { t("완료했어요.", "Done.", "完了しました。", "Hecho.", "Terminé.", "Concluído.") }
    func marketBought(_ n: Int) -> String {
        t("\(n)장 샀어요", n == 1 ? "Bought 1 card" : "Bought \(n) cards", "\(n)枚購入しました",
          n == 1 ? "Compraste 1 carta" : "Compraste \(n) cartas",
          n == 1 ? "1 carte achetée" : "\(n) cartes achetées",
          n == 1 ? "1 carta comprada" : "\(n) cartas compradas")
    }
    var marketListed: String { t("판매 등록했어요", "Listed for sale", "出品しました",
                                 "Publicada en venta", "Mise en vente", "Anunciada para venda") }
    var tradeCompleted: String { t("교환했어요", "Trade complete", "交換しました",
                                   "Intercambio hecho", "Échange conclu", "Troca concluída") }
    func jobProgress(total: Int, completed: Int) -> String {
        let total = total.formatted(), done = completed.formatted()
        return t("\(total)팩 중 \(done)팩 열었어요", "Opened \(done) of \(total) packs", "\(total)パック中\(done)パック開封しました",
                 "Abiertos \(done) de \(total) sobres", "\(done) boosters ouverts sur \(total)", "\(done) de \(total) pacotes abertos")
    }
    func jobFinished(total: Int, completed: Int) -> String {
        let total = total.formatted(), done = completed.formatted()
        return t("\(total)팩 중 \(done)팩을 열었어요. 나온 카드는 컬렉션에서 볼 수 있어요.",
                 "Opened \(done) of \(total) packs. The cards are in your collection.",
                 "\(total)パック中\(done)パックを開封しました。出たカードはコレクションで見られます。",
                 "Abiertos \(done) de \(total) sobres. Las cartas están en tu colección.",
                 "\(done) boosters ouverts sur \(total). Les cartes sont dans votre collection.",
                 "\(done) de \(total) pacotes abertos. As cartas estão na sua coleção.")
    }
    var jobCancelled: String { t("남은 팩은 열지 않기로 했어요. 이미 연 카드는 그대로 있어요.", "The remaining packs won’t be opened. Cards already opened stay.", "残りのパックは開封しないことにしました。開封済みのカードはそのままです。", "No se abrirán los sobres restantes. Las cartas ya abiertas se quedan.", "Les boosters restants ne seront pas ouverts. Les cartes déjà obtenues restent.", "Os pacotes restantes não serão abertos. As cartas já abertas ficam.") }
    var serverJobsProblem: String { t("서버 자동 작업에 문제가 있어요. 「계정」에서 확인해 주세요.", "Server background jobs have a problem. Check the account window.", "サーバーの自動処理に問題があります。「アカウント」で確認してください。", "Hay un problema con las tareas automáticas del servidor. Revísalo en la ventana de cuenta.", "Les tâches automatiques du serveur ont un problème. Vérifiez dans la fenêtre du compte.", "Há um problema nas tarefas automáticas do servidor. Confira na janela da conta.") }
    var signInAgain: String { t("다시 로그인해 주세요", "Please sign in again", "もう一度ログインしてください", "Vuelve a iniciar sesión", "Reconnectez-vous", "Entre novamente") }
    var sessionExpiredMessage: String {
        t("로그인이 만료돼서 이 화면을 비웠어요. 같은 계정으로 다시 로그인하면 처리 중이던 요청도 이어서 확인해요.",
          "Your sign-in expired, so this screen was cleared. Sign in again with the same account and pending requests will be checked too.",
          "ログインの有効期限が切れたため、この画面を空にしました。同じアカウントで再ログインすると、処理中のリクエストも続けて確認します。",
          "Tu sesión caducó y se vació esta pantalla. Vuelve a entrar con la misma cuenta y también se revisarán las solicitudes pendientes.",
          "Votre session a expiré, cet écran a donc été vidé. Reconnectez-vous avec le même compte pour reprendre les requêtes en cours.",
          "Sua sessão expirou e esta tela foi limpa. Entre de novo com a mesma conta para conferir também as solicitações pendentes.")
    }
    func priceAsOf(_ date: String) -> String { t("시세 \(date) 기준", "Prices as of \(date)", "\(date)時点の相場", "Precios al \(date)", "Prix au \(date)", "Preços de \(date)") }
    func availableFunds(_ amount: String) -> String { t("쓸 수 있는 금액 \(amount)", "Available \(amount)", "使える金額 \(amount)", "Disponible \(amount)", "Disponible \(amount)", "Disponível \(amount)") }
    var accountAndServer: String { t("계정과 서버", "Account and server", "アカウントとサーバー", "Cuenta y servidor", "Compte et serveur", "Conta e servidor") }
    var connectedStatus: String { t("연결됨", "Connected", "接続済み", "Conectado", "Connecté", "Conectado") }
    var checkingConnection: String { t("연결 확인 중", "Checking connection", "接続を確認中", "Comprobando la conexión", "Vérification de la connexion", "Verificando a conexão") }
    var notConnected: String { t("연결 안 됨", "Not connected", "未接続", "Sin conexión", "Non connecté", "Sem conexão") }
    var serverErrorStatus: String { t("서버 오류", "Server error", "サーバーエラー", "Error del servidor", "Erreur du serveur", "Erro do servidor") }
    var signInNeeded: String { t("로그인 필요", "Sign-in needed", "ログインが必要", "Falta iniciar sesión", "Connexion requise", "Falta entrar") }
    var noNewAlerts: String { t("새 알림이 없어요", "No new notifications", "新しい通知はありません", "No hay avisos nuevos", "Aucune nouvelle alerte", "Nenhum alerta novo") }
    var alertsEmptyHint: String { t("친구 신청, 교환 제안, 마켓 판매 소식이 여기에 와요.", "Friend requests, trade offers and market sales show up here.", "フレンド申請、交換の提案、マーケットの販売のお知らせがここに届きます。", "Aquí llegan solicitudes de amistad, ofertas de intercambio y ventas del mercado.", "Les demandes d’ami, les offres d’échange et les ventes du marché arrivent ici.", "Pedidos de amizade, propostas de troca e vendas no mercado aparecem aqui.") }
    var backToStart: String { t("처음으로", "Back to start", "最初へ", "Al inicio", "Au début", "Voltar ao início") }
    var showMore: String { t("더 보기", "Show more", "もっと見る", "Ver más", "Voir plus", "Ver mais") }
    var bulkOpeningIntro: String {
        t("1,000팩이 넘는 개봉은 여기서 나눠서 이어 열어요. 창을 닫거나 멈추면 지금 묶음까지만 열고 멈춰요. 다른 기기에서 팩을 쓰면 이어 열기가 멈출 수 있어요.",
          "Openings over 1,000 packs continue here in batches. Closing the window or stopping finishes the current batch, then stops. Using packs on another device may pause it.",
          "1,000パックを超える開封は、ここで分けて続けて開けます。ウィンドウを閉じるか止めると、今のまとまりまで開けて止まります。別のデバイスでパックを使うと止まることがあります。",
          "Las aperturas de más de 1.000 sobres siguen aquí por tandas. Al cerrar la ventana o detener, se termina la tanda actual. Usar sobres en otro dispositivo puede pausarlo.",
          "Les ouvertures de plus de 1 000 boosters se poursuivent ici par lots. Fermer la fenêtre ou arrêter termine le lot en cours. Utiliser des boosters sur un autre appareil peut l’interrompre.",
          "Aberturas de mais de 1.000 pacotes continuam aqui em lotes. Fechar a janela ou parar conclui o lote atual. Usar pacotes em outro dispositivo pode pausar.")
    }
    var stopAfterBatch: String { t("이번 묶음까지만 열기", "Stop after this batch", "このまとまりで止める", "Parar tras esta tanda", "Arrêter après ce lot", "Parar após este lote") }
    var noJobs: String { t("이어서 열 팩이 없어요", "No packs to resume", "続けて開けるパックはありません", "No hay sobres pendientes", "Aucun booster à reprendre", "Nenhum pacote para retomar") }
    var noJobsHint: String { t("한 번에 1,000팩 넘게 열면 여기서 이어 열 수 있어요.", "Open more than 1,000 packs at once to continue them here.", "一度に1,000パックを超えて開けると、ここで続けられます。", "Si abres más de 1.000 sobres de una vez, podrás seguir aquí.", "Ouvrez plus de 1 000 boosters d’un coup pour les reprendre ici.", "Abra mais de 1.000 pacotes de uma vez para continuar aqui.") }
    var jobCompleted: String { t("다 열었어요", "All opened", "開封完了", "Todo abierto", "Tout ouvert", "Tudo aberto") }
    var jobStopped: String { t("그만둠", "Stopped", "中止", "Detenido", "Arrêté", "Parado") }
    var jobResumable: String { t("이어 열 수 있어요", "Can resume", "続きを開けます", "Se puede seguir", "Reprise possible", "Pode retomar") }
    var stopRemainingPacks: String { t("남은 팩 그만 열기", "Stop remaining packs", "残りのパックをやめる", "Detener los sobres restantes", "Arrêter les boosters restants", "Parar os pacotes restantes") }
    var resumeOpening: String { t("이어서 열기", "Resume opening", "続けて開ける", "Seguir abriendo", "Reprendre l’ouverture", "Continuar abrindo") }
    var statsIntro: String {
        t("서버에 기록된 개봉 결과를 기간, 모드, 세트별로 나눠 봐요. 보유 카드와 컬렉션 전체 요약은 메뉴바의 「통계」 탭에 있어요.",
          "Opening results recorded on the server, by period, mode and set. Your owned cards and collection summary are in the menu bar’s Stats tab.",
          "サーバーに記録された開封結果を期間、モード、セット別に見られます。所持カードとコレクション全体の概要はメニューバーの「統計」タブにあります。",
          "Resultados de apertura registrados en el servidor por periodo, modo y set. El resumen de tus cartas y tu colección está en la pestaña Stats de la barra de menús.",
          "Résultats d’ouverture enregistrés sur le serveur, par période, mode et extension. Le résumé de vos cartes et de votre collection est dans l’onglet Stats de la barre des menus.",
          "Resultados de abertura registrados no servidor por período, modo e coleção. O resumo das suas cartas e da coleção está na aba Stats da barra de menus.")
    }
    var periodLabel: String { t("기간", "Period", "期間", "Periodo", "Période", "Período") }
    var allTime: String { t("전체 기간", "All time", "全期間", "Todo", "Depuis le début", "Todo o período") }
    var last7Days: String { t("최근 7일", "Last 7 days", "直近7日", "Últimos 7 días", "7 derniers jours", "Últimos 7 dias") }
    var last30Days: String { t("최근 30일", "Last 30 days", "直近30日", "Últimos 30 días", "30 derniers jours", "Últimos 30 dias") }
    var modeLabel: String { t("모드", "Mode", "モード", "Modo", "Mode", "Modo") }
    var allModes: String { t("모든 모드", "All modes", "すべてのモード", "Todos los modos", "Tous les modes", "Todos os modos") }
    var statOpened: String { t("연 팩", "Packs opened", "開封したパック", "Sobres abiertos", "Boosters ouverts", "Pacotes abertos") }
    var statPurchased: String { t("산 팩", "Packs bought", "買ったパック", "Sobres comprados", "Boosters achetés", "Pacotes comprados") }
    var statNew: String { t("새로 얻은 카드", "New cards", "新しく手に入れたカード", "Cartas nuevas", "Nouvelles cartes", "Cartas novas") }
    var statDuplicates: String { t("겹친 카드", "Duplicates", "ダブったカード", "Repetidas", "Doublons", "Repetidas") }
    var statSpent: String { t("팩 사는 데 쓴 돈", "Spent on packs", "パック購入に使った金額", "Gastado en sobres", "Dépensé en boosters", "Gasto em pacotes") }
    var statIncome: String { t("카드 팔아 번 돈", "Earned from card sales", "カード売却で得た金額", "Ganado vendiendo cartas", "Gagné en vendant des cartes", "Ganho vendendo cartas") }
    func collectionWorth(_ amount: String) -> String { t("지금 컬렉션을 시세로 치면 \(amount)예요.", "Your collection is worth \(amount) at current prices.", "今のコレクションを相場で換算すると\(amount)です。", "Tu colección vale \(amount) a precios actuales.", "Votre collection vaut \(amount) aux prix actuels.", "Sua coleção vale \(amount) a preços atuais.") }
    func newCardRate(_ percent: Int) -> String { t("새 카드가 나온 비율 \(percent)%", "New card rate \(percent)%", "新しいカードが出た割合 \(percent)%", "Tasa de cartas nuevas \(percent) %", "Taux de nouvelles cartes \(percent) %", "Taxa de cartas novas \(percent)%") }
    var cardsByTier: String { t("등급별로 나온 카드", "Cards by rarity", "レアリティ別のカード", "Cartas por rareza", "Cartes par rareté", "Cartas por raridade") }
    var cardsByFinish: String { t("판형별로 나온 카드", "Cards by finish", "仕様別のカード", "Cartas por acabado", "Cartes par finition", "Cartas por acabamento") }
    var packKinds: String { t("팩 종류", "Pack types", "パックの種類", "Tipos de sobre", "Types de booster", "Tipos de pacote") }
    var regularPack: String { t("일반 팩", "Regular pack", "通常パック", "Sobre normal", "Booster normal", "Pacote normal") }
    var godPackName: String { t("갓팩", "God pack", "ゴッドパック", "God pack", "God pack", "God pack") }
    var demigodPackName: String { t("준갓팩", "Demi-god pack", "準ゴッドパック", "Semi god pack", "Demi god pack", "Semi god pack") }
    var statsDisclaimer: String { t("실제로 나온 결과예요. 앞으로의 확률을 보장하지는 않아요.", "These are actual results. They don’t guarantee future odds.", "実際に出た結果です。今後の確率を保証するものではありません。", "Son resultados reales. No garantizan probabilidades futuras.", "Ce sont des résultats réels. Ils ne garantissent pas les probabilités futures.", "São resultados reais. Não garantem probabilidades futuras.") }
    func recordedSince(_ date: String) -> String { t("\(date)부터 기록했어요.", "Recorded since \(date).", "\(date)から記録しています。", "Registrado desde \(date).", "Enregistré depuis le \(date).", "Registrado desde \(date).") }
    var noRecordsYet: String { t("아직 기록이 없어요", "No records yet", "まだ記録がありません", "Aún no hay registros", "Aucun enregistrement pour l’instant", "Ainda não há registros") }
    var noRecordsHint: String { t("온라인 계정으로 팩을 사거나 열면 여기에 쌓여요.", "Buy or open packs with your online account and they’ll show up here.", "オンラインアカウントでパックを買ったり開けたりすると、ここに記録されます。", "Compra o abre sobres con tu cuenta en línea y aparecerán aquí.", "Achetez ou ouvrez des boosters avec votre compte en ligne pour les voir ici.", "Compre ou abra pacotes com sua conta online e eles aparecerão aqui.") }
}

// MARK: 메뉴바 온라인 줄과 계정 창

extension L {
    var onlineEntryFeatures: String { t("마켓, 교환, 친구", "Market, trades, friends", "マーケット、交換、フレンド", "Mercado, intercambios, amigos", "Marché, échanges, amis", "Mercado, trocas, amigos") }
    var openOnlineWindow: String { t("온라인 창 열기", "Open the online window", "オンライン画面を開く", "Abrir la ventana en línea", "Ouvrir la fenêtre en ligne", "Abrir a janela online") }
    var openOnlineWindowHint: String { t("마켓, 교환, 친구, 통계를 새 창에서 봐요.", "See the market, trades, friends and stats in a new window.", "マーケット、交換、フレンド、統計を新しいウィンドウで見ます。", "Mira el mercado, los intercambios, los amigos y las estadísticas en una ventana nueva.", "Voir le marché, les échanges, les amis et les statistiques dans une nouvelle fenêtre.", "Veja o mercado, as trocas, os amigos e as estatísticas em uma nova janela.") }
    func pendingTrades(_ n: Int) -> String { t("교환 제안 \(n)", "Trade offers \(n)", "交換の提案 \(n)", "Ofertas \(n)", "Offres \(n)", "Propostas \(n)") }
    func pendingFriends(_ n: Int) -> String { t("친구 신청 \(n)", "Friend requests \(n)", "フレンド申請 \(n)", "Solicitudes \(n)", "Demandes \(n)", "Pedidos \(n)") }
    func pendingAlerts(_ n: Int) -> String { t("알림 \(n)", "Alerts \(n)", "通知 \(n)", "Avisos \(n)", "Alertes \(n)", "Alertas \(n)") }
    var connectingToServer: String { t("서버 연결 중…", "Connecting to the server…", "サーバーに接続中…", "Conectando con el servidor…", "Connexion au serveur…", "Conectando ao servidor…") }
    /// 앱이 꺼진 사이 결과를 받지 못한 요청을 다시 맞춘 뒤의 안내.
    func recoveredRequest(_ packs: Int?) -> String {
        guard let packs else {
            return t("확인하지 못한 요청을 복구했어요. 도감과 개봉 이력에 반영했어요.",
                     "Recovered an unconfirmed request. Your dex and opening history are updated.",
                     "未確認のリクエストを復旧しました。図鑑と開封履歴に反映しました。",
                     "Se recuperó una solicitud sin confirmar. Se actualizaron la Dex y el historial.",
                     "Requête non confirmée récupérée. Le Dex et l’historique sont à jour.",
                     "Solicitação não confirmada recuperada. A Dex e o histórico foram atualizados.")
        }
        return t("확인하지 못한 요청을 복구했어요(\(packs)팩 개봉). 도감과 개봉 이력에 반영했어요.",
                 "Recovered an unconfirmed request (\(packs) packs opened). Your dex and opening history are updated.",
                 "未確認のリクエストを復旧しました（\(packs)パック開封）。図鑑と開封履歴に反映しました。",
                 "Se recuperó una solicitud sin confirmar (\(packs) sobres abiertos). Se actualizaron la Dex y el historial.",
                 "Requête non confirmée récupérée (\(packs) boosters ouverts). Le Dex et l’historique sont à jour.",
                 "Solicitação não confirmada recuperada (\(packs) pacotes abertos). A Dex e o histórico foram atualizados.")
    }
    var accountWindowTitle: String { t("PPB 계정 및 서버", "PPB Account and Server", "PPB アカウントとサーバー", "PPB: cuenta y servidor", "PPB : compte et serveur", "PPB: conta e servidor") }
}

// MARK: 마켓과 교환 (OnlineCommerceView)

extension L {
    var marketBuy: String { t("사기", "Buy", "買う", "Comprar", "Acheter", "Comprar") }
    var marketSell: String { t("팔기", "Sell", "売る", "Vender", "Vendre", "Vender") }
    var mySales: String { t("내 판매", "My listings", "自分の出品", "Mis ventas", "Mes ventes", "Minhas vendas") }
    var searchByCardName: String { t("카드 이름으로 찾기", "Search by card name", "カード名で検索", "Buscar por nombre", "Rechercher par nom", "Buscar por nome") }
    var tierLabel: String { t("등급", "Rarity", "レアリティ", "Rareza", "Rareté", "Raridade") }
    var allTiers: String { t("모든 등급", "All rarities", "すべてのレアリティ", "Todas las rarezas", "Toutes les raretés", "Todas as raridades") }
    var sortLabel: String { t("정렬", "Sort", "並べ替え", "Ordenar", "Trier", "Ordenar") }
    var sortNewest: String { t("새로 올라온 순", "Newest", "新着順", "Más recientes", "Plus récents", "Mais recentes") }
    var sortPrice: String { t("가격순", "Price", "価格順", "Precio", "Prix", "Preço") }
    var noListingsMatch: String { t("조건에 맞는 카드가 없어요", "No cards match", "条件に合うカードがありません", "Ninguna carta coincide", "Aucune carte ne correspond", "Nenhuma carta corresponde") }
    var noListingsYet: String { t("아직 올라온 카드가 없어요", "Nothing listed yet", "まだ出品されたカードがありません", "Aún no hay cartas a la venta", "Rien en vente pour l’instant", "Ainda não há cartas à venda") }
    var narrowFilters: String { t("찾는 조건을 줄여 보세요.", "Try fewer filters.", "条件を減らしてみてください。", "Prueba con menos filtros.", "Essayez avec moins de filtres.", "Tente usar menos filtros.") }
    var listingsAppearHere: String { t("다른 사람이 카드를 올리면 여기에 나타나요.", "Cards others list will appear here.", "ほかの人がカードを出品するとここに表示されます。", "Las cartas que otros pongan a la venta aparecerán aquí.", "Les cartes mises en vente par d’autres apparaîtront ici.", "As cartas que outras pessoas venderem aparecerão aqui.") }
    var sellHint: String { t("같은 카드가 2장 이상일 때 남는 만큼 팔 수 있어요. 수수료는 없어요.", "You can sell spares of any card you own two or more of. No fees.", "同じカードが2枚以上あるとき、余った分を売れます。手数料はかかりません。", "Puedes vender las repetidas de cualquier carta. Sin comisiones.", "Vous pouvez vendre vos doubles. Sans frais.", "Você pode vender as repetidas de qualquer carta. Sem taxas.") }
    var noSellableCards: String { t("팔 수 있는 카드가 없어요", "No cards to sell", "売れるカードがありません", "No tienes cartas para vender", "Aucune carte à vendre", "Nenhuma carta para vender") }
    func sellableCount(_ n: Int) -> String { t("\(n)장 팔 수 있어요", "\(n) to sell", "\(n)枚売れます", "\(n) para vender", "\(n) à vendre", "\(n) para vender") }
    func marketQuote(_ amount: String) -> String { t("시세 \(amount)", "Market \(amount)", "相場 \(amount)", "Mercado \(amount)", "Cote \(amount)", "Mercado \(amount)") }
    func earned(_ amount: String) -> String { t("번 돈 \(amount)", "Earned \(amount)", "得た金額 \(amount)", "Ganado \(amount)", "Gagné \(amount)", "Ganho \(amount)") }
    func spent(_ amount: String) -> String { t("쓴 돈 \(amount)", "Spent \(amount)", "使った金額 \(amount)", "Gastado \(amount)", "Dépensé \(amount)", "Gasto \(amount)") }
    var noOwnListings: String { t("올린 카드가 없어요", "You haven’t listed anything", "出品したカードはありません", "No has puesto nada a la venta", "Vous n’avez rien mis en vente", "Você não colocou nada à venda") }
    var listFromSell: String { t("「팔기」에서 남는 카드를 올려 보세요.", "List your spares from Sell.", "「売る」から余ったカードを出品してみましょう。", "Pon tus repetidas a la venta desde Vender.", "Mettez vos doubles en vente depuis Vendre.", "Coloque suas repetidas à venda em Vender.") }
    func myListingLine(finish: String, unit: String, left: Int) -> String {
        t("\(finish), 장당 \(unit), \(left)장 남음", "\(finish), \(unit) each, \(left) left", "\(finish)、1枚 \(unit)、残り\(left)枚",
          "\(finish), \(unit) c/u, quedan \(left)", "\(finish), \(unit) l’unité, \(left) restantes", "\(finish), \(unit) cada, restam \(left)")
    }
    var takeDownListing: String { t("판매 내리기", "Take down", "出品を取り下げる", "Retirar de la venta", "Retirer de la vente", "Retirar da venda") }
    var buyCardTitle: String { t("카드 사기", "Buy card", "カードを買う", "Comprar carta", "Acheter la carte", "Comprar carta") }
    func buyFor(_ amount: String) -> String { t("\(amount)에 사기", "Buy for \(amount)", "\(amount)で買う", "Comprar por \(amount)", "Acheter pour \(amount)", "Comprar por \(amount)") }
    var buyNote: String { t("판매자가 그새 수량을 바꾸면 결제하지 않고 다시 확인해 달라고 알려 드려요.", "If the seller changes the quantity in the meantime, you won’t be charged and we’ll ask you to check again.", "その間に出品者が数量を変えた場合は、支払わずにもう一度確認するようお知らせします。", "Si el vendedor cambia la cantidad mientras tanto, no se cobrará y te pediremos que lo revises.", "Si le vendeur modifie la quantité entre-temps, vous ne serez pas débité et devrez vérifier à nouveau.", "Se o vendedor mudar a quantidade nesse meio-tempo, você não será cobrado e pediremos para conferir de novo.") }
    func soldBy(finish: String, seller: String) -> String { t("\(finish), 판매자 \(seller)", "\(finish), sold by \(seller)", "\(finish)、出品者 \(seller)", "\(finish), vende \(seller)", "\(finish), vendu par \(seller)", "\(finish), vendido por \(seller)") }
    func perCard(_ amount: String) -> String { t("장당 \(amount)", "\(amount) each", "1枚 \(amount)", "\(amount) c/u", "\(amount) l’unité", "\(amount) cada") }
    func referencePrice(_ amount: String) -> String { t("참고 시세 \(amount)", "Reference \(amount)", "参考相場 \(amount)", "Referencia \(amount)", "Référence \(amount)", "Referência \(amount)") }
    var notEnoughBalance: String { t("잔액이 부족해요", "Not enough balance", "残高が足りません", "Saldo insuficiente", "Solde insuffisant", "Saldo insuficiente") }
    func balanceAfter(_ amount: String) -> String { t("사고 나면 \(amount) 남아요", "\(amount) left after buying", "購入後の残り \(amount)", "Te quedarán \(amount)", "Il vous restera \(amount)", "Restarão \(amount)") }
    var sellCardTitle: String { t("카드 팔기", "Sell card", "カードを売る", "Vender carta", "Vendre la carte", "Vender carta") }
    var postListing: String { t("판매 올리기", "List for sale", "出品する", "Poner a la venta", "Mettre en vente", "Colocar à venda") }
    func sellNote(quantity: Int, price: String) -> String {
        t("\(quantity)장을 장당 \(price)에 올려요. 7일 동안 안 팔린 카드는 자동으로 돌아와요. 시세가 바뀌어도 가격은 그대로예요.",
          "Lists \(quantity) at \(price) each. Unsold cards come back after 7 days. The price stays fixed even if the market moves.",
          "\(quantity)枚を1枚 \(price)で出品します。7日間売れなかったカードは自動で戻ります。相場が変わっても価格はそのままです。",
          "Pones \(quantity) a \(price) c/u. Las que no se vendan en 7 días vuelven solas. El precio no cambia aunque cambie el mercado.",
          "Met en vente \(quantity) à \(price) l’unité. Les cartes invendues reviennent après 7 jours. Le prix reste fixe même si la cote change.",
          "Coloca \(quantity) a \(price) cada. As não vendidas voltam após 7 dias. O preço fica fixo mesmo se o mercado mudar.")
    }
    func sellableLine(finish: String, available: Int) -> String { "\(finish), \(sellableCount(available))" }
    var pricePerCard: String { t("장당 가격", "Price per card", "1枚あたりの価格", "Precio por carta", "Prix à l’unité", "Preço por carta") }
    var priceLabel: String { t("가격", "Price", "価格", "Precio", "Prix", "Preço") }
    /// 원화 입력 칸 옆의 단위. `WonFormatter` 와 같은 표기를 쓴다.
    var wonUnit: String { t("원", "₩", "円", "₩", "₩", "₩") }
    var atMarketPrice: String { t("시세대로", "At market", "相場どおり", "A precio de mercado", "Au prix du marché", "Preço de mercado") }
    var tenPercentLower: String { t("10% 싸게", "10% lower", "10%安く", "10 % menos", "10 % moins cher", "10% mais barato") }
    var tenPercentHigher: String { t("10% 비싸게", "10% higher", "10%高く", "10 % más", "10 % plus cher", "10% mais caro") }
    func referenceStep(_ amount: String) -> String { t("참고 시세 \(amount), 100원 단위로 올라가요", "Reference \(amount), in steps of ₩100", "参考相場 \(amount)、100円単位で設定します", "Referencia \(amount), en pasos de ₩100", "Référence \(amount), par paliers de 100 ₩", "Referência \(amount), em passos de ₩100") }
    var noReferenceStep: String { t("참고 시세가 없어요. 100원 단위로 올라가요", "No reference price. Set in steps of ₩100", "参考相場はありません。100円単位で設定します", "Sin precio de referencia. En pasos de ₩100", "Pas de prix de référence. Par paliers de 100 ₩", "Sem preço de referência. Em passos de ₩100") }
    func maximumPrice(_ amount: String) -> String { t("장당 가격은 \(amount)까지 입력할 수 있어요.", "The price per card can be up to \(amount).", "1枚あたりの価格は\(amount)まで入力できます。", "El precio por carta puede llegar a \(amount).", "Le prix à l’unité peut aller jusqu’à \(amount).", "O preço por carta pode ir até \(amount).") }

    var tradePickFriend: String { t("교환할 친구를 고르세요.", "Choose a friend to trade with.", "交換するフレンドを選んでください。", "Elige un amigo para intercambiar.", "Choisissez un ami avec qui échanger.", "Escolha um amigo para trocar.") }
    var tradeAddOffer: String { t("내가 줄 카드나 돈을 넣으세요.", "Add cards or money to give.", "渡すカードかお金を入れてください。", "Añade cartas o dinero para dar.", "Ajoutez des cartes ou de l’argent à donner.", "Adicione cartas ou dinheiro para dar.") }
    var tradeAddRequest: String { t("받고 싶은 카드나 돈을 넣으세요.", "Add cards or money you want.", "欲しいカードかお金を入れてください。", "Añade cartas o dinero que quieras.", "Ajoutez des cartes ou de l’argent souhaités.", "Adicione cartas ou dinheiro que você quer.") }
    var tradeKindLimit: String { t("한쪽에 담을 수 있는 카드는 20종까지예요.", "Each side can hold up to 20 different cards.", "片側に入れられるカードは20種類までです。", "Cada lado admite hasta 20 cartas distintas.", "Chaque côté peut contenir jusqu’à 20 cartes différentes.", "Cada lado pode ter até 20 cartas diferentes.") }
    var tradeCountLimit: String { t("한쪽에 담을 수 있는 카드는 1,000장까지예요.", "Each side can hold up to 1,000 cards.", "片側に入れられるカードは1,000枚までです。", "Cada lado admite hasta 1.000 cartas.", "Chaque côté peut contenir jusqu’à 1 000 cartes.", "Cada lado pode ter até 1.000 cartas.") }
    var tradeSameCard: String { t("같은 카드를 주고받을 수는 없어요.", "You can’t give and receive the same card.", "同じカードをやり取りすることはできません。", "No puedes dar y recibir la misma carta.", "Impossible de donner et recevoir la même carte.", "Não é possível dar e receber a mesma carta.") }
    var newTradeOffer: String { t("새 교환 제안", "New trade offer", "新しい交換の提案", "Nueva oferta", "Nouvelle offre", "Nova proposta") }
    var newTradeOfferNote: String { t("친구가 72시간 안에 수락하면 바로 바뀌어요. 그동안 내가 줄 카드는 묶여 있어요. 얹은 돈은 묶지 않고 수락할 때 다시 확인해요.", "If your friend accepts within 72 hours, the cards swap right away. Until then, the cards you give are held. Money isn’t held; it’s checked again on acceptance.", "フレンドが72時間以内に承認するとすぐに交換されます。それまで渡すカードは確保されます。お金は確保されず、承認時にもう一度確認します。", "Si tu amigo acepta en 72 horas, las cartas se cambian al instante. Mientras tanto, las cartas que das quedan reservadas. El dinero no se reserva: se vuelve a comprobar al aceptar.", "Si votre ami accepte sous 72 heures, les cartes s’échangent aussitôt. D’ici là, les cartes que vous donnez sont réservées. L’argent n’est pas réservé : il est revérifié à l’acceptation.", "Se seu amigo aceitar em 72 horas, as cartas são trocadas na hora. Até lá, as cartas que você dá ficam reservadas. O dinheiro não fica reservado: é verificado de novo ao aceitar.") }
    var noFriendsYet: String { t("아직 친구가 없어요", "No friends yet", "まだフレンドがいません", "Aún no tienes amigos", "Pas encore d’amis", "Ainda sem amigos") }
    var addFriendHint: String { t("「친구」 탭에서 친구 코드로 신청해 보세요.", "Send a request with a friend code in the Friends tab.", "「フレンド」タブでフレンドコードを使って申請してみましょう。", "Envía una solicitud con un código de amigo en la pestaña Amigos.", "Envoyez une demande avec un code ami dans l’onglet Amis.", "Envie um pedido com um código de amigo na aba Amigos.") }
    var withWhom: String { t("누구와", "With", "相手", "Con", "Avec", "Com") }
    var chooseFriend: String { t("친구 고르기", "Choose a friend", "フレンドを選ぶ", "Elegir amigo", "Choisir un ami", "Escolher amigo") }
    var cardsIGive: String { t("내가 줄 카드", "Cards I give", "渡すカード", "Cartas que doy", "Cartes que je donne", "Cartas que dou") }
    var cardsIWant: String { t("받고 싶은 카드", "Cards I want", "欲しいカード", "Cartas que quiero", "Cartes que je veux", "Cartas que quero") }
    var cardsIGet: String { t("받을 카드", "Cards I get", "受け取るカード", "Cartas que recibo", "Cartes que je reçois", "Cartas que recebo") }
    var sendOffer: String { t("제안 보내기", "Send offer", "提案を送る", "Enviar oferta", "Envoyer l’offre", "Enviar proposta") }
    var mutualMatches: String { t("서로 필요한 카드가 있어요", "You each have cards the other wants", "お互いに欲しいカードがあります", "Tenéis cartas que el otro quiere", "Vous avez chacun des cartes que l’autre veut", "Vocês têm cartas que o outro quer") }
    var mutualMatchesNote: String { t("위시리스트를 보고 맞춰 봤어요.", "Matched from wishlists.", "ウィッシュリストから照合しました。", "Coincidencias según las listas de deseos.", "Correspondances d’après les listes d’envies.", "Combinado pelas listas de desejos.") }
    func matchSummary(give: Int, get: Int) -> String {
        t("줄 수 있는 카드 \(give)종, 받을 수 있는 카드 \(get)종", "You can give \(give), get \(get) kinds", "渡せるカード\(give)種、もらえるカード\(get)種",
          "Puedes dar \(give) y recibir \(get) tipos", "Vous pouvez donner \(give) et recevoir \(get) types", "Você pode dar \(give) e receber \(get) tipos")
    }
    var draftFromMatch: String { t("이걸로 제안 만들기", "Draft an offer from this", "これで提案を作る", "Crear oferta con esto", "Préparer une offre", "Criar proposta com isto") }
    var offersToAnswer: String { t("답해야 할 제안", "Offers to answer", "返事が必要な提案", "Ofertas por responder", "Offres à traiter", "Propostas a responder") }
    var tradeHistory: String { t("교환 기록", "Trade history", "交換履歴", "Historial de intercambios", "Historique des échanges", "Histórico de trocas") }
    var noTradesYet: String { t("아직 교환한 적이 없어요.", "No trades yet.", "まだ交換したことはありません。", "Aún no has intercambiado.", "Aucun échange pour l’instant.", "Nenhuma troca ainda.") }
    var addCardsToGive: String { t("내가 줄 카드 담기", "Add cards to give", "渡すカードを入れる", "Añadir cartas para dar", "Ajouter des cartes à donner", "Adicionar cartas para dar") }
    var addCardsWanted: String { t("받고 싶은 카드 담기", "Add cards you want", "欲しいカードを入れる", "Añadir cartas que quieres", "Ajouter des cartes souhaitées", "Adicionar cartas desejadas") }
    var addAction: String { t("담기", "Add", "入れる", "Añadir", "Ajouter", "Adicionar") }
    var confirmOffer: String { t("이렇게 제안할까요?", "Send this offer?", "この内容で提案しますか？", "¿Enviar esta oferta?", "Envoyer cette offre ?", "Enviar esta proposta?") }
    var confirmOfferNote: String { t("친구가 수락할 때 서버가 양쪽 카드를 다시 확인해요. 72시간이 지나면 제안은 사라지고 카드는 풀려요.", "When your friend accepts, the server checks both sides again. After 72 hours the offer disappears and your cards are released.", "フレンドが承認するとき、サーバーが双方のカードを再確認します。72時間を過ぎると提案は消え、カードの確保も解除されます。", "Cuando tu amigo acepte, el servidor revisará ambas partes. A las 72 horas la oferta desaparece y tus cartas se liberan.", "Quand votre ami accepte, le serveur revérifie les deux côtés. Après 72 heures, l’offre disparaît et vos cartes sont libérées.", "Quando seu amigo aceitar, o servidor confere os dois lados. Após 72 horas a proposta some e suas cartas são liberadas.") }
    func toFriend(_ name: String) -> String { t("\(name)님에게", "To \(name)", "\(name)さんへ", "Para \(name)", "À \(name)", "Para \(name)") }
    var acceptTradeQuestion: String { t("교환을 수락할까요?", "Accept this trade?", "交換を承認しますか？", "¿Aceptar el intercambio?", "Accepter l’échange ?", "Aceitar a troca?") }
    var acceptAction: String { t("수락하기", "Accept", "承認する", "Aceptar", "Accepter", "Aceitar") }
    var acceptTradeNote: String { t("수락하면 바로 카드가 바뀌어요.", "Accepting swaps the cards right away.", "承認するとすぐにカードが交換されます。", "Al aceptar, las cartas se intercambian al momento.", "Accepter échange les cartes immédiatement.", "Ao aceitar, as cartas são trocadas na hora.") }
    func tradeWith(_ name: String) -> String { t("\(name)님과의 교환", "Trade with \(name)", "\(name)さんとの交換", "Intercambio con \(name)", "Échange avec \(name)", "Troca com \(name)") }
    func trayCount(kinds: Int, cards: Int) -> String { "\(kindsCount(kinds)), \(cardsCount(cards))" }
    var addCards: String { t("카드 담기", "Add cards", "カードを入れる", "Añadir cartas", "Ajouter des cartes", "Adicionar cartas") }
    var trayEmpty: String { t("아직 담은 카드가 없어요.", "No cards added yet.", "まだカードを入れていません。", "Aún no has añadido cartas.", "Aucune carte ajoutée.", "Nenhuma carta adicionada.") }
    func offerFrom(_ name: String) -> String { t("\(name)님이 보낸 제안", "Offer from \(name)", "\(name)さんからの提案", "Oferta de \(name)", "Offre de \(name)", "Proposta de \(name)") }
    func offerTo(_ name: String) -> String { t("\(name)님에게 보낸 제안", "Offer to \(name)", "\(name)さんへの提案", "Oferta para \(name)", "Offre à \(name)", "Proposta para \(name)") }
    var declineAction: String { t("거절", "Decline", "断る", "Rechazar", "Refuser", "Recusar") }
    var cancelOffer: String { t("제안 취소", "Cancel offer", "提案を取り消す", "Cancelar oferta", "Annuler l’offre", "Cancelar proposta") }
    var friendFallback: String { t("친구", "Friend", "フレンド", "Amigo", "Ami", "Amigo") }
}

// MARK: 로테이션 (서버가 마켓에 올리는 카드)

extension L {
    /// 로테이션 매물의 판매자 자리에 적는 이름. 파는 쪽이 사람이 아니라 게임이다.
    /// 카드 칸 한 줄에 「이름, 수량」이 들어가야 해서 짧게 쓴다. 봇 매물이라는 것은 표시가 따로 말한다.
    var rotationSeller: String { t("로테이션 봇", "Bot", "ボット", "Bot", "Bot", "Bot") }
    /// 카드 아래 표시. 트레이너가 올린 것이 아니라는 것을 바로 알게 한다.
    var rotationBadge: String { t("봇 매물", "Bot listing", "ボット出品", "Venta de bot", "Vente du bot", "Venda do bot") }
    var sellerLabel: String { t("판매자", "Seller", "出品者", "Vendedor", "Vendeur", "Vendedor") }
    var allSellers: String {
        t("모든 판매자", "All sellers", "すべての出品者", "Todos los vendedores", "Tous les vendeurs", "Todos os vendedores")
    }
    var trainerListings: String {
        t("트레이너 매물", "Trainer listings", "トレーナーの出品",
          "Ventas de entrenadores", "Ventes des dresseurs", "Vendas de treinadores")
    }
    var botListings: String {
        t("봇 매물", "Bot listings", "ボット出品", "Ventas de bot", "Ventes du bot", "Vendas do bot")
    }
    var rotationBought: String { t("샀어요", "Bought", "購入済み", "Comprada", "Achetée", "Comprada") }
    var rotationBuyNote: String {
        t("봇 매물은 계정마다 한 장씩 살 수 있어요. 매일 새 카드로 바뀌어요.",
          "Each account can buy one copy of a bot listing. New cards arrive every day.",
          "ボット出品は1アカウントにつき1枚まで買えます。毎日新しいカードに替わります。",
          "Cada cuenta puede comprar una copia de cada venta de bot. Cambian cada día.",
          "Chaque compte peut acheter un exemplaire de chaque vente du bot. Elles changent chaque jour.",
          "Cada conta pode comprar uma cópia de cada venda do bot. Elas mudam todo dia.")
    }
}

// MARK: 친구, 위시리스트, 바인더 (OnlineSocialView)

extension L {
    var friendsTitle: String { t("친구", "Friends", "フレンド", "Amigos", "Amis", "Amigos") }
    var wishlistTitle: String { t("위시리스트", "Wishlist", "ウィッシュリスト", "Lista de deseos", "Liste d’envies", "Lista de desejos") }
    var binderTitle: String { t("바인더", "Binder", "バインダー", "Carpeta", "Classeur", "Fichário") }
    var myCardsTitle: String { t("내 카드", "My cards", "自分のカード", "Mis cartas", "Mes cartes", "Minhas cartas") }
    var myProfileTitle: String { t("내 프로필", "My profile", "マイプロフィール", "Mi perfil", "Mon profil", "Meu perfil") }
    var addToWishlist: String { t("위시리스트에 추가", "Add to wishlist", "ウィッシュリストに追加", "Añadir a la lista de deseos", "Ajouter à la liste d’envies", "Adicionar à lista de desejos") }
    var addConfirm: String { t("추가하기", "Add", "追加する", "Añadir", "Ajouter", "Adicionar") }
    var profilePrivacyNote: String { t("잔액, 사용량, 개봉 기록은 친구에게 보이지 않아요.", "Friends can’t see your balance, usage or opening history.", "残高、使用量、開封履歴はフレンドには見えません。", "Tus amigos no ven tu saldo, uso ni historial de aperturas.", "Vos amis ne voient pas votre solde, votre usage ni votre historique.", "Seus amigos não veem seu saldo, uso nem histórico de aberturas.") }
    var nicknameLabel: String { t("닉네임", "Nickname", "ニックネーム", "Apodo", "Pseudo", "Apelido") }
    var nicknamePlaceholder: String { t("친구에게 보일 이름", "Name your friends see", "フレンドに表示される名前", "Nombre que verán tus amigos", "Nom visible par vos amis", "Nome que seus amigos veem") }
    var saveAction: String { t("저장", "Save", "保存", "Guardar", "Enregistrer", "Salvar") }
    var friendCodeLabel: String { t("친구 코드", "Friend code", "フレンドコード", "Código de amigo", "Code ami", "Código de amigo") }
    var newFriendCode: String { t("새 코드 받기", "Get a new code", "新しいコードを取得", "Obtener código nuevo", "Obtenir un nouveau code", "Gerar novo código") }
    var newFriendCodeHelp: String { t("예전 코드로는 더 이상 친구 신청을 받을 수 없어요.", "Your old code will no longer accept friend requests.", "古いコードではフレンド申請を受け付けなくなります。", "El código anterior ya no aceptará solicitudes.", "L’ancien code n’acceptera plus de demandes d’ami.", "O código antigo não aceitará mais pedidos.") }
    var showToFriends: String { t("친구에게 보여 줄 것", "Visible to friends", "フレンドに見せるもの", "Visible para amigos", "Visible par vos amis", "Visível para amigos") }
    var myCollectionToggle: String { t("내 컬렉션", "My collection", "自分のコレクション", "Mi colección", "Ma collection", "Minha coleção") }
    var enterFriendCode: String { t("친구 코드 입력", "Enter a friend code", "フレンドコードを入力", "Introduce un código", "Saisir un code ami", "Digite um código") }
    var sendFriendRequest: String { t("친구 신청", "Send request", "フレンド申請", "Enviar solicitud", "Envoyer la demande", "Enviar pedido") }
    var myFriendCode: String { t("내 친구 코드", "My friend code", "自分のフレンドコード", "Mi código de amigo", "Mon code ami", "Meu código de amigo") }
    var sentYouRequest: String { t("나에게 친구 신청을 보냈어요", "Sent you a friend request", "フレンド申請が届いています", "Te envió una solicitud", "Vous a envoyé une demande", "Enviou um pedido para você") }
    var acceptShort: String { t("수락", "Accept", "承認", "Aceptar", "Accepter", "Aceitar") }
    var viewBinder: String { t("바인더 보기", "View binder", "バインダーを見る", "Ver carpeta", "Voir le classeur", "Ver fichário") }
    var unfriend: String { t("친구 끊기", "Remove friend", "フレンドを解除", "Eliminar amigo", "Retirer l’ami", "Remover amigo") }
    var blockUser: String { t("차단하기", "Block", "ブロックする", "Bloquear", "Bloquer", "Bloquear") }
    /// 친구 줄에서 바로 교환 탭으로. 줄이 좁아 짧게 적는다.
    var proposeTradeShort: String { t("교환 제안", "Trade", "交換する", "Intercambiar", "Échanger", "Trocar") }
    func unfriendQuestion(_ name: String) -> String {
        t("\(name) 님과 친구를 끊을까요?", "Remove \(name) from your friends?", "\(name)さんとのフレンドを解除しますか？",
          "¿Eliminar a \(name) de tus amigos?", "Retirer \(name) de vos amis ?", "Remover \(name) dos seus amigos?")
    }
    var unfriendNote: String {
        t("주고받던 교환 제안도 함께 취소돼요. 다시 친구가 되려면 친구 신청부터 해야 해요.",
          "Pending trade offers between you are cancelled too. To be friends again, one of you has to send a new request.",
          "やり取り中の交換の提案も取り消されます。もう一度フレンドになるには申請からやり直します。",
          "También se cancelan las ofertas de intercambio pendientes entre ustedes. Para volver a ser amigos hay que enviar otra solicitud.",
          "Les offres d’échange en cours entre vous sont aussi annulées. Pour redevenir amis, il faudra renvoyer une demande.",
          "As propostas de troca pendentes entre vocês também são canceladas. Para voltarem a ser amigos, é preciso enviar um novo pedido.")
    }
    func blockQuestion(_ name: String) -> String {
        t("\(name) 님을 차단할까요?", "Block \(name)?", "\(name)さんをブロックしますか？", "¿Bloquear a \(name)?",
          "Bloquer \(name) ?", "Bloquear \(name)?")
    }
    var blockNote: String {
        t("친구가 끊기고 주고받던 교환 제안이 취소돼요. 서로의 마켓 판매 글도 보이지 않아요. 차단 목록에서 다시 풀 수 있어요.",
          "You stop being friends, pending trade offers between you are cancelled, and you no longer see each other’s market listings. You can undo this from the blocked list.",
          "フレンドが解除され、やり取り中の交換の提案が取り消されます。お互いのマーケット出品も表示されなくなります。ブロックリストから解除できます。",
          "Dejan de ser amigos, se cancelan las ofertas de intercambio pendientes y ya no verán las ventas del otro en el mercado. Puedes deshacerlo desde la lista de bloqueados.",
          "Vous n’êtes plus amis, les offres d’échange en cours sont annulées et vous ne voyez plus vos annonces respectives. Vous pouvez annuler depuis la liste des bloqués.",
          "Vocês deixam de ser amigos, as propostas de troca pendentes são canceladas e não veem mais os anúncios um do outro. Dá para desfazer na lista de bloqueados.")
    }
    var awaitingAcceptance: String { t("수락을 기다리는 중", "Waiting for them to accept", "承認待ち", "Esperando que acepte", "En attente d’acceptation", "Aguardando aceitação") }
    var cancelRequest: String { t("신청 취소", "Cancel request", "申請を取り消す", "Cancelar solicitud", "Annuler la demande", "Cancelar pedido") }
    var friendsEmptyHint: String { t("친구 코드를 받아 신청해 보세요. 상대가 수락하면 서로 바인더를 보고 교환할 수 있어요.", "Get a friend code and send a request. Once they accept, you can see each other’s binders and trade.", "フレンドコードをもらって申請してみましょう。承認されると、お互いのバインダーを見て交換できます。", "Pide un código de amigo y envía una solicitud. Cuando acepte, podréis ver vuestras carpetas e intercambiar.", "Demandez un code ami et envoyez une demande. Une fois acceptée, vous verrez vos classeurs et pourrez échanger.", "Peça um código de amigo e envie um pedido. Quando aceitar, vocês poderão ver os fichários e trocar.") }
    func blockedUsers(_ n: Int) -> String { t("차단한 사용자 \(n)명", "Blocked users (\(n))", "ブロックしたユーザー \(n)人", "Usuarios bloqueados (\(n))", "Utilisateurs bloqués (\(n))", "Usuários bloqueados (\(n))") }
    var unblock: String { t("차단 풀기", "Unblock", "ブロック解除", "Desbloquear", "Débloquer", "Desbloquear") }
    var wishlistNote: String { t("갖고 싶은 카드를 적어 두면 마켓에 올라왔을 때 알려 드리고, 교환 상대도 찾아 드려요.", "Add cards you want and we’ll tell you when they’re listed, and find trade partners too.", "欲しいカードを登録しておくと、出品されたときにお知らせし、交換相手も探します。", "Añade las cartas que quieres y te avisaremos cuando se pongan a la venta; también buscaremos con quién intercambiar.", "Ajoutez les cartes voulues : nous vous préviendrons quand elles seront en vente et trouverons des partenaires d’échange.", "Adicione as cartas que você quer e avisaremos quando forem colocadas à venda, além de achar parceiros de troca.") }
    var addCard: String { t("카드 추가", "Add card", "カードを追加", "Añadir carta", "Ajouter une carte", "Adicionar carta") }
    var wishlistEmpty: String { t("아직 적어 둔 카드가 없어요.", "No cards added yet.", "まだ登録したカードはありません。", "Aún no has añadido cartas.", "Aucune carte ajoutée.", "Nenhuma carta adicionada.") }
    var collectedAll: String { t("다 모았어요", "Complete", "コンプリート", "Completa", "Complète", "Completa") }
    func wishProgress(owned: Int, target: Int, anyFinish: Bool) -> String {
        let count = t("\(owned)/\(target)장", "\(owned)/\(target)", "\(owned)/\(target)枚", "\(owned)/\(target)", "\(owned)/\(target)", "\(owned)/\(target)")
        return anyFinish ? "\(self.anyFinish), \(count)" : count
    }
    var myBinder: String { t("내 바인더", "My binder", "マイバインダー", "Mi carpeta", "Mon classeur", "Meu fichário") }
    func binderNote(_ capacity: Int) -> String { t("친구에게 자랑할 카드를 최대 \(capacity)장까지 꽂아 두세요.", "Show off up to \(capacity) cards to your friends.", "フレンドに見せたいカードを最大\(capacity)枚まで入れておけます。", "Presume ante tus amigos de hasta \(capacity) cartas.", "Montrez jusqu’à \(capacity) cartes à vos amis.", "Mostre até \(capacity) cartas aos seus amigos.") }
    var chooseCards: String { t("카드 고르기", "Choose cards", "カードを選ぶ", "Elegir cartas", "Choisir des cartes", "Escolher cartas") }
    var binderEmptyHint: String { t("아직 꽂은 카드가 없어요. 「카드 고르기」에서 시세 높은 카드부터 골라 한 번에 꽂을 수 있어요.", "Your binder is empty. Use Choose cards to pick your most valuable cards in one go.", "まだカードを入れていません。「カードを選ぶ」で相場の高いカードからまとめて入れられます。", "Tu carpeta está vacía. Con Elegir cartas puedes poner de una vez las más valiosas.", "Votre classeur est vide. Avec Choisir des cartes, ajoutez d’un coup les plus précieuses.", "Seu fichário está vazio. Em Escolher cartas, adicione de uma vez as mais valiosas.") }
    var moveEarlier: String { t("앞으로", "Move earlier", "前へ移動", "Mover antes", "Avancer", "Mover para antes") }
    var myCardsNote: String { t("판매나 교환에 걸려 있는 카드는 그 거래가 끝날 때까지 쓸 수 없어요.", "Cards in a listing or trade can’t be used until it ends.", "販売中や交換中のカードは、その取引が終わるまで使えません。", "Las cartas en venta o intercambio no se pueden usar hasta que termine.", "Les cartes en vente ou en échange sont indisponibles jusqu’à la fin.", "Cartas em venda ou troca ficam indisponíveis até o fim.") }
    var searchByName: String { t("이름으로 찾기", "Search by name", "名前で検索", "Buscar por nombre", "Rechercher par nom", "Buscar por nome") }
    var noServerCards: String { t("서버에 올라간 카드가 아직 없어요.", "No cards on the server yet.", "サーバーにはまだカードがありません。", "Aún no hay cartas en el servidor.", "Aucune carte sur le serveur pour l’instant.", "Ainda não há cartas no servidor.") }
    var noMatchingCardsSentence: String { t("맞는 카드가 없어요.", "No matching cards.", "一致するカードがありません。", "No hay cartas que coincidan.", "Aucune carte correspondante.", "Nenhuma carta encontrada.") }
    func reservedCount(quantity: Int, reserved: Int) -> String { t("\(quantity)장, \(reserved)장 거래 중", "\(quantity), \(reserved) in trades", "\(quantity)枚、\(reserved)枚取引中", "\(quantity), \(reserved) en tratos", "\(quantity), \(reserved) en transaction", "\(quantity), \(reserved) em negociação") }
    var inBinder: String { t("바인더에 있어요", "In binder", "バインダーにあります", "En la carpeta", "Dans le classeur", "No fichário") }
    var putInBinder: String { t("바인더에 꽂기", "Add to binder", "バインダーに入れる", "Añadir a la carpeta", "Ajouter au classeur", "Adicionar ao fichário") }
    var chooseBinder: String { t("바인더 고르기", "Choose binder cards", "バインダーを選ぶ", "Elegir cartas de la carpeta", "Choisir les cartes du classeur", "Escolher cartas do fichário") }
    var binderEditorNote: String { t("시세 높은 카드부터 보여요. 누르면 담기고, 다시 누르면 빠져요. 위 줄에서 끌어 순서를 바꿔요.", "Most valuable cards first. Click to add, click again to remove. Drag in the top row to reorder.", "相場の高いカードから表示します。押すと入り、もう一度押すと外れます。上の列でドラッグして順番を変えます。", "Primero las más valiosas. Pulsa para añadir y otra vez para quitar. Arrastra en la fila superior para reordenar.", "Les plus précieuses d’abord. Cliquez pour ajouter, recliquez pour retirer. Faites glisser en haut pour réordonner.", "As mais valiosas primeiro. Clique para adicionar e de novo para remover. Arraste na fileira de cima para reordenar.") }
    func binderFill(_ count: Int, _ capacity: Int) -> String { t("\(count)/\(capacity)장", "\(count)/\(capacity)", "\(count)/\(capacity)枚", "\(count)/\(capacity)", "\(count)/\(capacity)", "\(count)/\(capacity)") }
    func binderSlotHelp(_ name: String) -> String { t("\(name) 빼기. 끌어서 순서를 바꿔요.", "Remove \(name). Drag to reorder.", "\(name)を外す。ドラッグで順番を変えます。", "Quitar \(name). Arrastra para reordenar.", "Retirer \(name). Faites glisser pour réordonner.", "Remover \(name). Arraste para reordenar.") }
    var fillWithTop: String { t("비싼 카드로 채우기", "Fill with top cards", "高いカードで埋める", "Llenar con las mejores", "Remplir avec les meilleures", "Preencher com as melhores") }
    var fillWithTopHelp: String { t("남은 칸을 시세 높은 카드로 채워요. 같은 카드는 한 장만 넣어요.", "Fills the remaining slots with your most valuable cards, one of each.", "残りの枠を相場の高いカードで埋めます。同じカードは1枚だけ入れます。", "Llena los huecos con tus cartas más valiosas, una de cada.", "Remplit les places restantes avec vos cartes les plus précieuses, une de chaque.", "Preenche as vagas com suas cartas mais valiosas, uma de cada.") }
    var removeAll: String { t("모두 빼기", "Remove all", "すべて外す", "Quitar todas", "Tout retirer", "Remover todas") }
    var noCardsOwned: String { t("가진 카드가 없어요", "You don’t have any cards", "カードを持っていません", "No tienes cartas", "Vous n’avez aucune carte", "Você não tem cartas") }
    var openPacksToSee: String { t("팩을 열면 여기에 나타나요.", "Open packs and they’ll show up here.", "パックを開けるとここに表示されます。", "Abre sobres y aparecerán aquí.", "Ouvrez des boosters pour les voir ici.", "Abra pacotes e elas aparecerão aqui.") }
    var noMarketPrice: String { t("시세 없음", "No price", "相場なし", "Sin precio", "Sans cote", "Sem preço") }
    func priceEach(_ amount: String) -> String { t("장당 시세 \(amount)", "\(amount) each", "1枚あたり相場 \(amount)", "\(amount) cada una", "\(amount) l’unité", "\(amount) cada") }
    func priceTotal(_ n: Int, _ amount: String) -> String { t("\(n)장 합계 \(amount)", "\(n) cards, \(amount) in total", "\(n)枚 合計 \(amount)", "\(n) cartas, \(amount) en total", "\(n) cartes, \(amount) au total", "\(n) cartas, \(amount) no total") }
    var sortPriceHigh: String { t("시세 높은 순", "Highest price", "相場の高い順", "Precio más alto", "Prix décroissant", "Maior preço") }
    var sortPriceLow: String { t("시세 낮은 순", "Lowest price", "相場の低い順", "Precio más bajo", "Prix croissant", "Menor preço") }
    var sortName: String { t("이름순", "By name", "名前順", "Por nombre", "Par nom", "Por nome") }
    var saveToBinder: String { t("바인더에 저장", "Save to binder", "バインダーに保存", "Guardar en la carpeta", "Enregistrer dans le classeur", "Salvar no fichário") }
    var loading: String { t("불러오는 중…", "Loading…", "読み込み中…", "Cargando…", "Chargement…", "Carregando…") }
    func friendsCards(_ name: String) -> String { t("\(name)님의 카드", "\(name)’s cards", "\(name)さんのカード", "Cartas de \(name)", "Cartes de \(name)", "Cartas de \(name)") }
    var binderPrivate: String { t("바인더를 공개하지 않았어요.", "This binder isn’t shared.", "バインダーは公開されていません。", "Esta carpeta no es pública.", "Ce classeur n’est pas partagé.", "Este fichário não é público.") }
    var binderEmpty: String { t("바인더가 비어 있어요.", "The binder is empty.", "バインダーは空です。", "La carpeta está vacía.", "Le classeur est vide.", "O fichário está vazio.") }
    var cardsTheyWant: String { t("갖고 싶어 하는 카드", "Cards they want", "欲しがっているカード", "Cartas que quiere", "Cartes recherchées", "Cartas que quer") }
    var noWishes: String { t("적어 둔 카드가 없어요.", "No cards listed.", "登録したカードはありません。", "No ha añadido cartas.", "Aucune carte listée.", "Nenhuma carta listada.") }
    func moreNeeded(_ n: Int) -> String { t("\(n)장 더 필요", "Needs \(n) more", "あと\(n)枚必要", "Le faltan \(n)", "Encore \(n)", "Faltam \(n)") }
    var collectionTitle: String { t("컬렉션", "Collection", "コレクション", "Colección", "Collection", "Coleção") }
    var viewCollection: String { t("컬렉션 보기", "View collection", "コレクションを見る", "Ver colección", "Voir la collection", "Ver coleção") }
    func asOf(_ date: String) -> String { t("\(date) 기준", "As of \(date)", "\(date)時点", "Al \(date)", "Au \(date)", "Em \(date)") }
    var viewPriceSource: String { t("가격 출처 보기", "View price source", "価格の出典を見る", "Ver fuente del precio", "Voir la source du prix", "Ver fonte do preço") }
}

// MARK: 계정 창 (OnlineSettingsView)

extension L {
    func accountTab(_ tab: OnlineSettingsView.AccountTab) -> String {
        switch tab {
        case .profile: t("프로필", "Profile", "プロフィール", "Perfil", "Profil", "Perfil")
        case .connection: t("연결", "Connection", "接続", "Conexión", "Connexion", "Conexão")
        case .security: t("보안", "Security", "セキュリティ", "Seguridad", "Sécurité", "Segurança")
        case .devices: t("기기", "Devices", "デバイス", "Dispositivos", "Appareils", "Dispositivos")
        case .server: t("서버 상태", "Server status", "サーバー状態", "Estado del servidor", "État du serveur", "Status do servidor")
        }
    }
    var nicknameNote: String { t("마켓, 교환, 친구 목록에서 다른 사람에게 보이는 이름이에요. 40자까지 쓸 수 있어요.", "The name others see in the market, trades and friend lists. Up to 40 characters.", "マーケット、交換、フレンド一覧でほかの人に表示される名前です。40文字まで使えます。", "El nombre que ven los demás en el mercado, los intercambios y las listas de amigos. Hasta 40 caracteres.", "Le nom que les autres voient dans le marché, les échanges et les listes d’amis. 40 caractères au maximum.", "O nome que os outros veem no mercado, nas trocas e nas listas de amigos. Até 40 caracteres.") }
    var nicknameNeedsSignIn: String { t("온라인 모드에서 로그인하면 닉네임을 바꿀 수 있어요.", "Sign in with online mode on to change your nickname.", "オンラインモードでログインするとニックネームを変更できます。", "Inicia sesión con el modo en línea activado para cambiar tu apodo.", "Connectez-vous en mode en ligne pour changer votre pseudo.", "Entre com o modo online ativado para mudar seu apelido.") }
    var nicknameSaved: String { t("닉네임을 바꿨어요.", "Nickname changed.", "ニックネームを変更しました。", "Apodo cambiado.", "Pseudo modifié.", "Apelido alterado.") }
    var nicknameSaveFailed: String { t("닉네임을 바꾸지 못했어요. 잠시 뒤에 다시 해 주세요.", "Couldn’t change the nickname. Try again shortly.", "ニックネームを変更できませんでした。しばらくしてからもう一度お試しください。", "No se pudo cambiar el apodo. Inténtalo de nuevo en un momento.", "Impossible de changer le pseudo. Réessayez dans un instant.", "Não foi possível mudar o apelido. Tente de novo daqui a pouco.") }
    var profileLoadFailed: String { t("프로필을 불러오지 못했어요.", "Couldn’t load your profile.", "プロフィールを読み込めませんでした。", "No se pudo cargar tu perfil.", "Impossible de charger votre profil.", "Não foi possível carregar seu perfil.") }
    var changeNicknameEllipsis: String { t("닉네임 바꾸기…", "Change nickname…", "ニックネームを変更…", "Cambiar apodo…", "Changer de pseudo…", "Mudar apelido…") }
    var friendSettingsTitle: String { t("친구 설정", "Friend settings", "フレンド設定", "Ajustes de amigos", "Réglages des amis", "Configurações de amigos") }
    var accountAndServerTitle: String { t("계정 및 서버", "Account and server", "アカウントとサーバー", "Cuenta y servidor", "Compte et serveur", "Conta e servidor") }
    var accountSubtitle: String { t("로그인하면 여러 Mac에서 같은 컬렉션을 써요", "Sign in to use the same collection on several Macs", "ログインすると複数のMacで同じコレクションを使えます", "Inicia sesión para usar la misma colección en varios Mac", "Connectez-vous pour utiliser la même collection sur plusieurs Mac", "Entre para usar a mesma coleção em vários Macs") }
    var accountSections: String { t("계정 관리 분류", "Account sections", "アカウント管理の分類", "Secciones de la cuenta", "Sections du compte", "Seções da conta") }
    var restartNow: String { t("지금 다시 시작", "Restart now", "今すぐ再起動", "Reiniciar ahora", "Redémarrer maintenant", "Reiniciar agora") }
    var revokeDeviceQuestion: String { t("이 기기의 연결을 해제할까요?", "Disconnect this device?", "このデバイスの接続を解除しますか？", "¿Desconectar este dispositivo?", "Déconnecter cet appareil ?", "Desconectar este dispositivo?") }
    var disconnect: String { t("연결 해제", "Disconnect", "接続を解除", "Desconectar", "Déconnecter", "Desconectar") }
    var disconnectEllipsis: String { t("연결 해제…", "Disconnect…", "接続を解除…", "Desconectar…", "Déconnecter…", "Desconectar…") }
    var revokeDeviceNote: String { t("그 기기는 다시 로그인해야 해요. 카드와 잔액은 지워지지 않아요.", "That device will need to sign in again. Cards and balance aren’t deleted.", "そのデバイスは再ログインが必要になります。カードと残高は消えません。", "Ese dispositivo tendrá que volver a iniciar sesión. Las cartas y el saldo no se borran.", "Cet appareil devra se reconnecter. Les cartes et le solde ne sont pas supprimés.", "Esse dispositivo precisará entrar de novo. Cartas e saldo não são apagados.") }
    var issueRecoveryQuestion: String { t("새 복구 코드를 발급할까요?", "Issue a new recovery code?", "新しい復旧コードを発行しますか？", "¿Emitir un código de recuperación nuevo?", "Émettre un nouveau code de récupération ?", "Emitir um novo código de recuperação?") }
    var issue: String { t("발급", "Issue", "発行", "Emitir", "Émettre", "Emitir") }
    var issueRecoveryNote: String { t("기존 코드는 바로 못 쓰게 돼요. 새 코드는 한 번만 보여 주니 비밀번호 관리자에 보관해 주세요.", "Your old code stops working right away. The new code is shown only once, so keep it in a password manager.", "既存のコードはすぐに使えなくなります。新しいコードは一度しか表示されないので、パスワード管理アプリに保管してください。", "El código anterior deja de funcionar al momento. El nuevo solo se muestra una vez: guárdalo en un gestor de contraseñas.", "L’ancien code cesse aussitôt de fonctionner. Le nouveau n’est affiché qu’une fois : gardez-le dans un gestionnaire de mots de passe.", "O código antigo para de funcionar na hora. O novo aparece só uma vez: guarde-o em um gerenciador de senhas.") }
    var changeTokenPolicyQuestion: String { t("토큰 적립 방식을 바꿀까요?", "Change how tokens are credited?", "トークンの積み立て方法を変更しますか？", "¿Cambiar cómo se acreditan los tokens?", "Changer le mode de crédit des jetons ?", "Mudar como os tokens são creditados?") }
    var change: String { t("변경", "Change", "変更", "Cambiar", "Modifier", "Alterar") }
    var tokenPolicyNote: String { t("바꾼 뒤 각 기기의 첫 사용량 보고는 기준값으로만 저장하고 적립하지 않아요. 그 뒤에 늘어난 만큼부터 새 방식으로 적립해요. 지금 잔액은 그대로예요.", "After the change, each device’s first usage report is stored as a baseline and not credited. Growth after that is credited the new way. Your balance stays as it is.", "変更後、各デバイスの最初の使用量報告は基準値として保存するだけで、積み立てません。その後に増えた分から新しい方法で積み立てます。現在の残高はそのままです。", "Tras el cambio, el primer informe de uso de cada dispositivo se guarda como base y no se acredita. Lo que aumente después se acredita con el nuevo método. Tu saldo no cambia.", "Après le changement, le premier relevé d’usage de chaque appareil sert de référence et n’est pas crédité. La hausse suivante est créditée selon le nouveau mode. Votre solde ne change pas.", "Depois da mudança, o primeiro relatório de uso de cada dispositivo vira base e não é creditado. O que aumentar depois é creditado do novo jeito. Seu saldo continua igual.") }
    var usageMode: String { t("사용 모드", "Mode", "利用モード", "Modo de uso", "Mode d’utilisation", "Modo de uso") }
    var onlineModeToggle: String { t("온라인 모드 (카드와 잔액을 서버 계정에 저장)", "Online mode (cards and balance saved to your server account)", "オンラインモード（カードと残高をサーバーのアカウントに保存）", "Modo en línea (cartas y saldo en tu cuenta del servidor)", "Mode en ligne (cartes et solde enregistrés sur votre compte serveur)", "Modo online (cartas e saldo salvos na conta do servidor)") }
    var separateSavesNote: String { t("이 Mac의 로컬 세이브와 온라인 계정은 따로 있어요. 모드를 바꿔도 옮기거나 합치지 않아요.", "This Mac’s local save and your online account are separate. Switching modes doesn’t move or merge them.", "このMacのローカルセーブとオンラインアカウントは別々です。モードを切り替えても移したり統合したりしません。", "La partida local de este Mac y tu cuenta en línea son independientes. Cambiar de modo no las mueve ni las une.", "La sauvegarde locale de ce Mac et votre compte en ligne sont distincts. Changer de mode ne les déplace ni ne les fusionne.", "O salvamento local deste Mac e a conta online são separados. Mudar de modo não os move nem os junta.") }
    var saveAndApply: String { t("저장하고 적용", "Save and apply", "保存して適用", "Guardar y aplicar", "Enregistrer et appliquer", "Salvar e aplicar") }
    var serverAddressAdvanced: String { t("서버 주소와 고급 연결", "Server address and advanced", "サーバーアドレスと詳細設定", "Dirección del servidor y opciones avanzadas", "Adresse du serveur et options avancées", "Endereço do servidor e opções avançadas") }
    var serverURL: String { t("서버 URL", "Server URL", "サーバーURL", "URL del servidor", "URL du serveur", "URL do servidor") }
    var sameServerNote: String { t("다른 기기와 같은 서버 주소를 써야 연결돼요. 원격 주소는 HTTPS여야 해요.", "Use the same server address as your other devices. Remote addresses must use HTTPS.", "ほかのデバイスと同じサーバーアドレスを使う必要があります。リモートのアドレスはHTTPSにしてください。", "Usa la misma dirección que tus otros dispositivos. Las direcciones remotas deben usar HTTPS.", "Utilisez la même adresse que vos autres appareils. Les adresses distantes doivent utiliser HTTPS.", "Use o mesmo endereço dos seus outros dispositivos. Endereços remotos precisam usar HTTPS.") }
    var linkedAccount: String { t("연결된 계정", "Signed-in account", "接続中のアカウント", "Cuenta conectada", "Compte connecté", "Conta conectada") }
    var accountTabsNote: String { t("기기별 연결 해제와 비밀번호 변경은 위쪽 탭에서 할 수 있어요.", "Disconnect devices and change your password in the tabs above.", "デバイスごとの接続解除とパスワード変更は上のタブでできます。", "Desconecta dispositivos y cambia la contraseña en las pestañas de arriba.", "Déconnectez des appareils et changez le mot de passe dans les onglets ci-dessus.", "Desconecte dispositivos e mude a senha nas abas acima.") }
    var openOnlineCollection: String { t("온라인 컬렉션 열기", "Open online collection", "オンラインコレクションを開く", "Abrir colección en línea", "Ouvrir la collection en ligne", "Abrir coleção online") }
    var renewOrSwitch: String { t("로그인 갱신 / 다른 계정", "Sign in again / other account", "ログイン更新 / 別のアカウント", "Volver a entrar / otra cuenta", "Se reconnecter / autre compte", "Entrar de novo / outra conta") }
    func runningState(ready: Bool, revision: Int) -> String {
        let state = ready
            ? t("온라인 연결됨", "online, connected", "オンライン接続済み", "en línea, conectado", "en ligne, connecté", "online, conectado")
            : t("온라인 연결 확인 필요", "online, connection not confirmed", "オンライン接続の確認が必要", "en línea, conexión sin confirmar", "en ligne, connexion non confirmée", "online, conexão não confirmada")
        return t("현재 실행: \(state), 상태 버전 \(revision)", "Running: \(state), state version \(revision)", "現在の実行: \(state)、状態バージョン \(revision)",
                 "En ejecución: \(state), versión de estado \(revision)", "En cours : \(state), version d’état \(revision)", "Em execução: \(state), versão do estado \(revision)")
    }
    var recoverAndSync: String { t("미확인 요청 복구 및 동기화", "Recover unconfirmed requests and sync", "未確認リクエストの復旧と同期", "Recuperar solicitudes y sincronizar", "Récupérer les requêtes et synchroniser", "Recuperar solicitações e sincronizar") }
    var syncNow: String { t("지금 동기화", "Sync now", "今すぐ同期", "Sincronizar ahora", "Synchroniser maintenant", "Sincronizar agora") }
    var runningLocally: String { t("지금은 로컬 모드로 실행 중이에요.", "Running in local mode.", "現在はローカルモードで実行中です。", "Funcionando en modo local.", "Fonctionne en mode local.", "Rodando no modo local.") }
    var emailAccount: String { t("이메일 계정", "Email account", "メールアカウント", "Cuenta de correo", "Compte e-mail", "Conta de e-mail") }
    var logIn: String { t("로그인", "Sign in", "ログイン", "Iniciar sesión", "Connexion", "Entrar") }
    var createAccount: String { t("새 계정 만들기", "Create account", "新しいアカウントを作成", "Crear cuenta", "Créer un compte", "Criar conta") }
    var emailField: String { t("이메일", "Email", "メールアドレス", "Correo", "E-mail", "E-mail") }
    var passwordField: String { t("비밀번호", "Password", "パスワード", "Contraseña", "Mot de passe", "Senha") }
    func confirmPasswordField(_ rule: String) -> String { t("비밀번호 확인 (\(rule))", "Confirm password (\(rule))", "パスワードの確認（\(rule)）", "Confirmar contraseña (\(rule))", "Confirmer le mot de passe (\(rule))", "Confirmar senha (\(rule))") }
    var linkLegacyAccount: String { t("초대 코드나 기존 계정 연결 (선택)", "Invite code or existing account (optional)", "招待コードまたは既存アカウントの連携（任意）", "Código de invitación o cuenta existente (opcional)", "Code d’invitation ou compte existant (facultatif)", "Código de convite ou conta existente (opcional)") }
    var useLinkCode: String { t("일회용 연결 코드 사용", "Use a one-time link code", "ワンタイム連携コードを使う", "Usar un código de enlace de un solo uso", "Utiliser un code de liaison à usage unique", "Usar um código de vínculo de uso único") }
    var linkCodeField: String { t("운영자에게 받은 일회용 코드", "One-time code from the operator", "運営者から受け取ったワンタイムコード", "Código de un solo uso del operador", "Code à usage unique de l’opérateur", "Código de uso único do operador") }
    var linkCodeNote: String { t("가입에는 필요 없어요. 운영자가 계정을 미리 만들어 줬거나 예전 UUID 계정을 이어 쓸 때만 넣어요. 그 계정의 카드와 잔액은 그대로 남아요.", "Not needed to sign up. Enter it only if the operator created your account in advance or you are continuing an old UUID account. Its cards and balance stay.", "登録には不要です。運営者が事前にアカウントを作成した場合や、以前のUUIDアカウントを引き継ぐ場合だけ入力します。そのアカウントのカードと残高はそのまま残ります。", "No hace falta para registrarte. Úsalo solo si el operador creó tu cuenta o si continúas una cuenta UUID anterior. Sus cartas y saldo se conservan.", "Inutile pour s’inscrire. À saisir seulement si l’opérateur a créé votre compte ou si vous reprenez un ancien compte UUID. Ses cartes et son solde sont conservés.", "Não é preciso para se cadastrar. Use só se o operador criou sua conta ou se você continua uma conta UUID antiga. As cartas e o saldo dela continuam.") }
    /// 아직 초대 코드를 요구하도록 설정된 서버가 가입을 거절했을 때.
    var registrationNeedsCode: String { t("이 서버는 아직 초대 코드가 있어야 가입할 수 있어요. 운영자에게 코드를 받아 「초대 코드나 기존 계정 연결」에 넣어 주세요.", "This server still requires an invite code to sign up. Ask the operator for one and enter it under Invite code or existing account.", "このサーバーはまだ招待コードがないと登録できません。運営者からコードを受け取り、「招待コードまたは既存アカウントの連携」に入力してください。", "Este servidor todavía pide un código de invitación. Pídeselo al operador e introdúcelo en Código de invitación o cuenta existente.", "Ce serveur exige encore un code d’invitation. Demandez-le à l’opérateur et saisissez-le dans Code d’invitation ou compte existant.", "Este servidor ainda exige um código de convite. Peça ao operador e informe em Código de convite ou conta existente.") }
    var createAndConnect: String { t("계정 만들고 연결", "Create and connect", "アカウントを作成して接続", "Crear y conectar", "Créer et connecter", "Criar e conectar") }
    var sameEmailNote: String { t("같은 서버에서 같은 이메일로 로그인하면 다른 Mac에서도 카드와 잔액을 함께 써요. 이메일 인증은 하지 않고, 이 Mac의 로컬 세이브는 올리지 않아요.", "Sign in with the same email on the same server to share cards and balance across Macs. Email isn’t verified, and this Mac’s local save isn’t uploaded.", "同じサーバーで同じメールアドレスでログインすると、ほかのMacでもカードと残高を共有できます。メール認証は行わず、このMacのローカルセーブはアップロードしません。", "Inicia sesión con el mismo correo en el mismo servidor para compartir cartas y saldo entre Mac. No se verifica el correo y no se sube la partida local.", "Connectez-vous avec le même e-mail sur le même serveur pour partager cartes et solde entre Mac. L’e-mail n’est pas vérifié et la sauvegarde locale n’est pas envoyée.", "Entre com o mesmo e-mail no mesmo servidor para compartilhar cartas e saldo entre Macs. O e-mail não é verificado e o salvamento local não é enviado.") }
    var signInSessions: String { t("로그인 세션", "Sign-in sessions", "ログインセッション", "Sesiones", "Sessions", "Sessões") }
    var logOutThisDevice: String { t("이 기기 로그아웃", "Sign out this device", "このデバイスからログアウト", "Cerrar sesión en este dispositivo", "Déconnecter cet appareil", "Sair neste dispositivo") }
    var logOutAllDevices: String { t("모든 기기 로그아웃", "Sign out all devices", "すべてのデバイスからログアウト", "Cerrar sesión en todos", "Déconnecter tous les appareils", "Sair em todos os dispositivos") }
    var currentPasswordForChanges: String { t("현재 비밀번호 (변경, 복구 코드 발급 시 확인)", "Current password (to change it or issue a recovery code)", "現在のパスワード（変更や復旧コード発行時に確認）", "Contraseña actual (para cambiarla o emitir un código)", "Mot de passe actuel (pour le changer ou émettre un code)", "Senha atual (para alterar ou emitir um código)") }
    var changePassword: String { t("비밀번호 변경", "Change password", "パスワードを変更", "Cambiar contraseña", "Changer le mot de passe", "Alterar senha") }
    var changePasswordNote: String { t("바꾸면 모든 기기에서 로그아웃되고 기존 복구 코드도 못 쓰게 돼요.", "Changing it signs out every device and invalidates your recovery code.", "変更するとすべてのデバイスからログアウトし、既存の復旧コードも使えなくなります。", "Al cambiarla se cierran todas las sesiones y el código de recuperación deja de valer.", "Le changer déconnecte tous les appareils et invalide le code de récupération.", "Alterar encerra a sessão em todos os dispositivos e invalida o código de recuperação.") }
    func newPasswordField(_ rule: String) -> String { t("새 비밀번호 (\(rule))", "New password (\(rule))", "新しいパスワード（\(rule)）", "Nueva contraseña (\(rule))", "Nouveau mot de passe (\(rule))", "Nova senha (\(rule))") }
    var confirmNewPassword: String { t("새 비밀번호 확인", "Confirm new password", "新しいパスワードの確認", "Confirmar nueva contraseña", "Confirmer le nouveau mot de passe", "Confirmar nova senha") }
    var changePasswordAndSignOut: String { t("비밀번호 변경 및 전체 로그아웃", "Change password and sign out everywhere", "パスワードを変更して全デバイスからログアウト", "Cambiar contraseña y cerrar todas las sesiones", "Changer le mot de passe et tout déconnecter", "Alterar senha e sair de tudo") }
    var recoveryCodeTitle: String { t("일회용 계정 복구 코드", "One-time recovery code", "ワンタイム復旧コード", "Código de recuperación de un solo uso", "Code de récupération à usage unique", "Código de recuperação de uso único") }
    var recoveryCodeActive: String { t("쓸 수 있는 복구 코드가 있어요.", "You have a usable recovery code.", "使える復旧コードがあります。", "Tienes un código de recuperación válido.", "Vous avez un code de récupération valide.", "Você tem um código de recuperação válido.") }
    var recoveryCodeSuggest: String { t("비밀번호를 잊을 때를 대비해 복구 코드를 받아 두세요.", "Get a recovery code in case you forget your password.", "パスワードを忘れたときに備えて復旧コードを取得しておきましょう。", "Consigue un código por si olvidas la contraseña.", "Obtenez un code au cas où vous oublieriez le mot de passe.", "Gere um código caso esqueça a senha.") }
    var recoveryCodeWarning: String { t("이 코드를 아는 사람은 비밀번호를 바꿀 수 있어요. 앱은 코드를 저장하지 않아서 화면을 닫으면 다시 볼 수 없어요.", "Anyone with this code can change your password. The app doesn’t store it, so you can’t see it again after closing.", "このコードを知っている人はパスワードを変更できます。アプリはコードを保存しないため、画面を閉じると再表示できません。", "Quien tenga este código puede cambiar tu contraseña. La app no lo guarda, así que no podrás volver a verlo al cerrar.", "Toute personne ayant ce code peut changer votre mot de passe. L’app ne le conserve pas : il disparaît à la fermeture.", "Quem tiver este código pode mudar sua senha. O app não o guarda, então não dá para vê-lo de novo depois de fechar.") }
    var reissueRecoveryCode: String { t("복구 코드 재발급…", "Reissue recovery code…", "復旧コードを再発行…", "Volver a emitir el código…", "Réémettre le code…", "Reemitir código…") }
    var issueRecoveryCode: String { t("복구 코드 발급…", "Issue recovery code…", "復旧コードを発行…", "Emitir código…", "Émettre un code…", "Emitir código…") }
    var savedItHide: String { t("안전한 곳에 보관했어요, 숨기기", "I saved it, hide", "安全な場所に保管しました、隠す", "Ya lo guardé, ocultar", "Je l’ai enregistré, masquer", "Já guardei, ocultar") }
    var forgotPassword: String { t("비밀번호를 잊었나요?", "Forgot your password?", "パスワードを忘れましたか？", "¿Olvidaste la contraseña?", "Mot de passe oublié ?", "Esqueceu a senha?") }
    var forgotPasswordNote: String { t("미리 받아 둔 일회용 복구 코드로 비밀번호를 다시 정해요. 코드가 없으면 서버 운영자에게 재설정을 부탁해야 해요.", "Reset your password with a recovery code you saved earlier. Without one, ask the server operator to reset it.", "事前に取得したワンタイム復旧コードでパスワードを再設定します。コードがない場合はサーバー管理者に再設定を依頼してください。", "Restablece la contraseña con un código que guardaste. Si no tienes, pide al administrador del servidor que la restablezca.", "Réinitialisez avec un code enregistré auparavant. Sans code, demandez à l’administrateur du serveur.", "Redefina a senha com um código salvo antes. Sem código, peça ao administrador do servidor.") }
    var savedRecoveryCode: String { t("저장해 둔 복구 코드", "Saved recovery code", "保存した復旧コード", "Código de recuperación guardado", "Code de récupération enregistré", "Código de recuperação salvo") }
    var resetPasswordAndSignOut: String { t("비밀번호 재설정 및 전체 로그아웃", "Reset password and sign out everywhere", "パスワードを再設定して全デバイスからログアウト", "Restablecer contraseña y cerrar todas las sesiones", "Réinitialiser et tout déconnecter", "Redefinir senha e sair de tudo") }
    var signInBeforeOnline: String { t("온라인 모드를 켜려면 먼저 로그인해 주세요.", "Sign in before turning on online mode.", "オンラインモードをオンにするには、先にログインしてください。", "Inicia sesión antes de activar el modo en línea.", "Connectez-vous avant d’activer le mode en ligne.", "Entre antes de ativar o modo online.") }
    var syncPendingFirst: String { t("처리 중이거나 결과를 확인하지 못한 요청을 먼저 동기화해 주세요.", "Sync requests that are in progress or unconfirmed first.", "処理中または結果を確認できていないリクエストを先に同期してください。", "Sincroniza primero las solicitudes en curso o sin confirmar.", "Synchronisez d’abord les requêtes en cours ou non confirmées.", "Sincronize primeiro as solicitações em andamento ou sem confirmação.") }
    var savedRestartToApply: String { t("저장했어요. 앱을 다시 시작하면 적용돼요.", "Saved. It takes effect when the app restarts.", "保存しました。アプリを再起動すると適用されます。", "Guardado. Se aplicará al reiniciar la app.", "Enregistré. Prend effet au redémarrage de l’app.", "Salvo. Vale quando o app reiniciar.") }
    var signedInDevices: String { t("현재 로그인한 기기", "Signed-in devices", "ログイン中のデバイス", "Dispositivos con sesión", "Appareils connectés", "Dispositivos conectados") }
    var signedInDevicesNote: String { t("최근 로그인 시각이고 지금 접속 중인지는 아니에요. 연결을 해제해도 그 기기에서 비밀번호로 다시 로그인할 수 있어요.", "Shows the last sign-in, not whether the device is online now. A disconnected device can sign in again with the password.", "最後にログインした時刻で、今接続中かどうかではありません。接続を解除しても、そのデバイスでパスワードを使って再ログインできます。", "Muestra el último inicio de sesión, no si está conectado ahora. Un dispositivo desconectado puede volver a entrar con la contraseña.", "Indique la dernière connexion, pas la présence actuelle. Un appareil déconnecté peut se reconnecter avec le mot de passe.", "Mostra o último acesso, não se está online agora. Um dispositivo desconectado pode entrar de novo com a senha.") }
    var tokenCollector: String { t("토큰 적립 담당", "Token crediting", "トークン積み立て担当", "Acreditación de tokens", "Crédit des jetons", "Crédito de tokens") }
    var tokenPolicyAll: String { t("현재: 모든 기기의 독립 사용량 합산", "Now: usage from every device is added up", "現在: すべてのデバイスの使用量を合算", "Ahora: se suma el uso de todos los dispositivos", "Actuellement : l’usage de tous les appareils est additionné", "Agora: o uso de todos os dispositivos é somado") }
    var tokenPolicySingle: String { t("현재: 지정한 한 기기만 적립", "Now: only one chosen device is credited", "現在: 指定した1台だけ積み立て", "Ahora: solo se acredita un dispositivo elegido", "Actuellement : un seul appareil choisi est crédité", "Agora: só um dispositivo escolhido é creditado") }
    var tokenPolicyHint: String { t("같은 사용량을 여러 Mac에서 읽는다면 한 대만 지정해 주세요. 적립 경로를 하나로 묶을 뿐, 보고한 사용량이 진짜인지 확인하지는 않아요.", "If several Macs read the same usage, pick just one. This only funnels crediting through one device; it doesn’t verify the reported usage.", "複数のMacで同じ使用量を読み取るなら、1台だけを指定してください。積み立て経路を1つにまとめるだけで、報告された使用量が本物かは確認しません。", "Si varios Mac leen el mismo uso, elige solo uno. Solo canaliza la acreditación por un dispositivo; no verifica el uso informado.", "Si plusieurs Mac lisent le même usage, choisissez-en un seul. Cela ne fait que centraliser le crédit ; l’usage déclaré n’est pas vérifié.", "Se vários Macs leem o mesmo uso, escolha só um. Isso apenas centraliza o crédito; não verifica o uso informado.") }
    var passwordForPolicy: String { t("정책 변경 확인용 현재 비밀번호", "Current password to confirm", "変更確認用の現在のパスワード", "Contraseña actual para confirmar", "Mot de passe actuel pour confirmer", "Senha atual para confirmar") }
    var onlyThisMac: String { t("이 Mac만 적립…", "Credit only this Mac…", "このMacだけ積み立て…", "Solo este Mac…", "Seulement ce Mac…", "Só este Mac…") }
    var allDevicesSum: String { t("모든 기기 합산…", "Add up all devices…", "全デバイスを合算…", "Sumar todos…", "Additionner tous…", "Somar todos…") }
    var signInOnConnectionTab: String { t("연결 탭에서 먼저 로그인해 주세요.", "Sign in on the Connection tab first.", "先に接続タブでログインしてください。", "Inicia sesión primero en la pestaña Conexión.", "Connectez-vous d’abord dans l’onglet Connexion.", "Entre primeiro na aba Conexão.") }
    var noSignedInDevices: String { t("로그인된 기기가 없어요. 다시 로그인해 주세요.", "No signed-in devices. Please sign in again.", "ログイン中のデバイスはありません。もう一度ログインしてください。", "No hay dispositivos con sesión. Vuelve a iniciar sesión.", "Aucun appareil connecté. Reconnectez-vous.", "Nenhum dispositivo conectado. Entre novamente.") }
    var deviceName: String { t("기기 이름", "Device name", "デバイス名", "Nombre del dispositivo", "Nom de l’appareil", "Nome do dispositivo") }
    var thisDevice: String { t("이 기기", "This device", "このデバイス", "Este dispositivo", "Cet appareil", "Este dispositivo") }
    func lastSignIn(_ date: String) -> String { t("최근 로그인: \(date)", "Last sign-in: \(date)", "最終ログイン: \(date)", "Último inicio: \(date)", "Dernière connexion : \(date)", "Último acesso: \(date)") }
    var saveName: String { t("이름 저장", "Save name", "名前を保存", "Guardar nombre", "Enregistrer le nom", "Salvar nome") }
    var backgroundJobs: String { t("자동 작업 상태", "Background jobs", "自動処理の状態", "Tareas automáticas", "Tâches automatiques", "Tarefas automáticas") }
    var signInForServerStatus: String { t("서버 상태를 보려면 먼저 로그인해 주세요.", "Sign in to see the server status.", "サーバー状態を見るには、先にログインしてください。", "Inicia sesión para ver el estado del servidor.", "Connectez-vous pour voir l’état du serveur.", "Entre para ver o status do servidor.") }
    func lastSuccess(_ date: String) -> String { t("마지막 성공: \(date)", "Last success: \(date)", "最終成功: \(date)", "Último éxito: \(date)", "Dernier succès : \(date)", "Último sucesso: \(date)") }
    func nextRun(_ date: String) -> String { t("다음 실행: \(date)", "Next run: \(date)", "次回実行: \(date)", "Próxima ejecución: \(date)", "Prochaine exécution : \(date)", "Próxima execução: \(date)") }
    var serverJobsNote: String { t("서버가 꺼져 있으면 자동 작업도 멈춰요. 백업은 서버 디스크에 있어서 디스크 고장에 대비한 외부 백업은 따로 해야 해요.", "Jobs stop while the server is off. Backups live on the server’s disk, so keep a separate off-site backup in case the disk fails.", "サーバーが停止していると自動処理も止まります。バックアップはサーバーのディスクにあるため、ディスク故障に備えた外部バックアップは別に必要です。", "Las tareas se detienen si el servidor está apagado. Las copias están en su disco, así que guarda otra copia externa por si falla.", "Les tâches s’arrêtent quand le serveur est éteint. Les sauvegardes sont sur son disque : gardez une copie externe en cas de panne.", "As tarefas param com o servidor desligado. Os backups ficam no disco dele, então mantenha outra cópia externa caso o disco falhe.") }
    var diagnostics: String { t("진단 정보", "Diagnostics", "診断情報", "Diagnóstico", "Diagnostic", "Diagnóstico") }
    var tokenTrustNote: String { t("토큰 적립: 앱이 보고한 사용량을 그대로 믿어요. 실제 사용량인지는 확인하지 않아요.", "Token crediting trusts the usage the app reports. It isn’t checked against real usage.", "トークン積み立て: アプリが報告した使用量をそのまま信用します。実際の使用量かは確認しません。", "Acreditación: se confía en el uso que informa la app. No se comprueba el uso real.", "Crédit des jetons : l’usage déclaré par l’app est accepté tel quel, sans vérification.", "Crédito de tokens: confia no uso informado pelo app. O uso real não é verificado.") }
    func latencyLine(_ name: String, p50: Double, p95: Double, samples: Int) -> String {
        let p50 = p50.formatted(.number.precision(.fractionLength(1))), p95 = p95.formatted(.number.precision(.fractionLength(1)))
        return t("\(name): P50 \(p50)ms / P95 \(p95)ms (\(samples)회)", "\(name): P50 \(p50)ms / P95 \(p95)ms (\(samples) samples)",
                 "\(name): P50 \(p50)ms / P95 \(p95)ms（\(samples)回）", "\(name): P50 \(p50) ms / P95 \(p95) ms (\(samples) muestras)",
                 "\(name) : P50 \(p50) ms / P95 \(p95) ms (\(samples) mesures)", "\(name): P50 \(p50) ms / P95 \(p95) ms (\(samples) amostras)")
    }
    var latencyNote: String { t("응답한 서버 프로세스의 최근 200회 기준이고, 서버를 다시 시작하면 처음부터 다시 재요. 앱에서 느끼는 시간이 이보다 훨씬 길면 서버 처리보다 전송 구간이 느린 거예요.", "Based on the last 200 requests to the responding server process, reset when the server restarts. If the app feels much slower than this, the network is the slow part.", "応答したサーバープロセスの直近200回に基づき、サーバーを再起動すると最初から測り直します。アプリでの体感がこれよりずっと長いなら、サーバー処理より通信区間が遅いということです。", "Según las últimas 200 solicitudes del proceso que respondió; se reinicia con el servidor. Si la app va mucho más lenta, la red es la parte lenta.", "Sur les 200 dernières requêtes du processus qui a répondu ; remis à zéro au redémarrage. Si l’app paraît bien plus lente, c’est le réseau.", "Com base nas últimas 200 solicitações do processo que respondeu; zera ao reiniciar o servidor. Se o app parecer bem mais lento, a rede é a parte lenta.") }
    func accountID(_ id: String) -> String { t("계정 ID: \(id)", "Account ID: \(id)", "アカウントID: \(id)", "ID de cuenta: \(id)", "ID du compte : \(id)", "ID da conta: \(id)") }
    var noRecord: String { t("기록 없음", "Never", "記録なし", "Nunca", "Jamais", "Nunca") }
    var deviceNameLength: String { t("기기 이름은 1~80자로 입력해 주세요.", "Device names must be 1 to 80 characters.", "デバイス名は1〜80文字で入力してください。", "El nombre debe tener entre 1 y 80 caracteres.", "Le nom doit compter de 1 à 80 caractères.", "O nome deve ter de 1 a 80 caracteres.") }
    var recoveryIssued: String { t("새 복구 코드를 안전한 곳에 보관해 주세요. 기존 코드는 이제 못 써요.", "Keep the new recovery code somewhere safe. The old code no longer works.", "新しい復旧コードを安全な場所に保管してください。既存のコードはもう使えません。", "Guarda el nuevo código en un lugar seguro. El anterior ya no sirve.", "Conservez le nouveau code en lieu sûr. L’ancien ne fonctionne plus.", "Guarde o novo código em local seguro. O antigo não funciona mais.") }
    func recoveryIssueFailed(_ error: String) -> String { t("\(error) 응답을 받지 못했다면 다시 받아 주세요. 이전 코드는 못 쓰게 됐을 수 있어요.", "\(error) If no reply arrived, issue it again. The old code may have stopped working.", "\(error) 応答がなかった場合はもう一度発行してください。以前のコードは使えなくなっている可能性があります。", "\(error) Si no llegó respuesta, vuelve a emitirlo. El código anterior puede haber dejado de valer.", "\(error) Sans réponse, émettez-le à nouveau. L’ancien code peut ne plus fonctionner.", "\(error) Se não houve resposta, emita de novo. O código antigo pode ter parado de funcionar.") }
    var tokenPolicyChanged: String { t("적립 방식을 바꿨어요. 각 기기의 첫 보고를 기준으로, 그 뒤에 늘어난 만큼부터 적립해요.", "Crediting changed. Each device’s first report is the baseline; growth after that is credited.", "積み立て方法を変更しました。各デバイスの最初の報告を基準に、その後に増えた分から積み立てます。", "Se cambió la acreditación. El primer informe de cada dispositivo es la base y se acredita lo que aumente después.", "Mode de crédit modifié. Le premier relevé de chaque appareil sert de référence ; la hausse suivante est créditée.", "Crédito alterado. O primeiro relatório de cada dispositivo é a base; o que aumentar depois é creditado.") }
    func tokenPolicyFailed(_ error: String) -> String { t("\(error) 새로고침해서 지금 방식을 확인해 주세요.", "\(error) Refresh to check the current setting.", "\(error) 更新して現在の方法を確認してください。", "\(error) Actualiza para ver la configuración actual.", "\(error) Actualisez pour vérifier le réglage actuel.", "\(error) Atualize para conferir a configuração atual.") }
    func newPasswordTwice(_ rule: String) -> String { t("\(rule)의 새 비밀번호를 두 칸에 똑같이 입력해 주세요.", "Enter the same new password (\(rule)) in both fields.", "\(rule)の新しいパスワードを2つの欄に同じように入力してください。", "Escribe la misma contraseña nueva (\(rule)) en ambos campos.", "Saisissez le même nouveau mot de passe (\(rule)) dans les deux champs.", "Digite a mesma nova senha (\(rule)) nos dois campos.") }
    func passwordTwice(_ rule: String) -> String { t("\(rule)의 비밀번호를 두 칸에 똑같이 입력해 주세요.", "Enter the same password (\(rule)) in both fields.", "\(rule)のパスワードを2つの欄に同じように入力してください。", "Escribe la misma contraseña (\(rule)) en ambos campos.", "Saisissez le même mot de passe (\(rule)) dans les deux champs.", "Digite a mesma senha (\(rule)) nos dois campos.") }
    var passwordResetDone: String { t("다시 정했어요. 새 비밀번호로 로그인하고 복구 코드를 다시 받아 주세요.", "Password reset. Sign in with the new password and get a new recovery code.", "再設定しました。新しいパスワードでログインし、復旧コードを取得し直してください。", "Contraseña restablecida. Entra con la nueva y consigue otro código de recuperación.", "Mot de passe réinitialisé. Connectez-vous avec le nouveau et obtenez un nouveau code.", "Senha redefinida. Entre com a nova e gere outro código de recuperação.") }
    func passwordResetFailed(_ error: String) -> String { t("\(error) 응답을 받지 못했다면 새 비밀번호로 먼저 로그인해 보세요.", "\(error) If no reply arrived, try signing in with the new password first.", "\(error) 応答がなかった場合は、まず新しいパスワードでログインしてみてください。", "\(error) Si no llegó respuesta, prueba primero a entrar con la nueva contraseña.", "\(error) Sans réponse, essayez d’abord de vous connecter avec le nouveau mot de passe.", "\(error) Se não houve resposta, tente primeiro entrar com a nova senha.") }
    var checkServerAddress: String { t("서버 주소를 확인해 주세요. 원격 서버는 HTTPS여야 해요.", "Check the server address. Remote servers must use HTTPS.", "サーバーアドレスを確認してください。リモートサーバーはHTTPSにしてください。", "Revisa la dirección del servidor. Los servidores remotos deben usar HTTPS.", "Vérifiez l’adresse du serveur. Les serveurs distants doivent utiliser HTTPS.", "Confira o endereço do servidor. Servidores remotos precisam usar HTTPS.") }
    var linkCodeRequired: String { t("연결 코드가 필요해요.", "A link code is required.", "連携コードが必要です。", "Se necesita un código de enlace.", "Un code de liaison est requis.", "É preciso um código de vínculo.") }
    var signInToPendingAccount: String { t("확인하지 못한 요청이 있는 기존 계정으로 먼저 로그인해서 복구해 주세요.", "Sign in to the account with the unconfirmed request first to recover it.", "未確認のリクエストがある既存のアカウントに先にログインして復旧してください。", "Primero entra en la cuenta con la solicitud sin confirmar para recuperarla.", "Connectez-vous d’abord au compte ayant la requête non confirmée pour la récupérer.", "Entre primeiro na conta com a solicitação não confirmada para recuperá-la.") }
    var signedInSynced: String { t("로그인했어요. 계정 상태를 동기화했어요.", "Signed in and synced your account.", "ログインしました。アカウントの状態を同期しました。", "Sesión iniciada y cuenta sincronizada.", "Connecté, compte synchronisé.", "Conectado e conta sincronizada.") }
    var signedInSwitching: String { t("로그인했어요. 이 계정으로 앱을 다시 여는 중이에요.", "Signed in. Reopening the app with this account.", "ログインしました。このアカウントでアプリを開き直しています。", "Sesión iniciada. Reabriendo la app con esta cuenta.", "Connecté. Réouverture de l’app avec ce compte.", "Conectado. Reabrindo o app com esta conta.") }
    var signedInRestart: String { t("로그인했어요. 앱을 다시 시작하면 이 계정에 연결돼요.", "Signed in. Restart the app to connect to this account.", "ログインしました。アプリを再起動するとこのアカウントに接続します。", "Sesión iniciada. Reinicia la app para conectar esta cuenta.", "Connecté. Redémarrez l’app pour utiliser ce compte.", "Conectado. Reinicie o app para usar esta conta.") }
    var passwordChangedSignedOut: String { t("비밀번호를 바꾸고 모든 기기에서 로그아웃했어요. 새 비밀번호로 다시 로그인해 주세요.", "Password changed and every device signed out. Sign in with the new password.", "パスワードを変更し、すべてのデバイスからログアウトしました。新しいパスワードで再ログインしてください。", "Contraseña cambiada y sesiones cerradas. Entra con la nueva contraseña.", "Mot de passe changé, tous les appareils déconnectés. Reconnectez-vous avec le nouveau.", "Senha alterada e todos os dispositivos desconectados. Entre com a nova senha.") }
    var signedOutNote: String { t("로그아웃했어요. 온라인 카드와 잔액은 그대로 있고, 다시 로그인하기 전까지는 바꿀 수 없어요.", "Signed out. Your online cards and balance are kept, and can’t change until you sign in again.", "ログアウトしました。オンラインのカードと残高はそのままで、再ログインするまで変更できません。", "Sesión cerrada. Tus cartas y saldo en línea se conservan y no cambiarán hasta que vuelvas a entrar.", "Déconnecté. Vos cartes et votre solde en ligne sont conservés et ne changeront pas avant la reconnexion.", "Sessão encerrada. Suas cartas e saldo online ficam guardados e não mudam até você entrar de novo.") }
    func latencyName(_ key: String) -> String {
        switch key {
        case "rules": t("규칙 실행", "Rules", "ルール実行", "Reglas", "Règles", "Regras")
        case "command_prepare": t("명령 준비", "Command prep", "コマンド準備", "Preparación", "Préparation", "Preparação")
        case "rules_compute": t("명령 계산", "Command compute", "コマンド計算", "Cálculo", "Calcul", "Cálculo")
        case "write_lock": t("DB 쓰기 대기", "DB write wait", "DB書き込み待ち", "Espera de escritura", "Attente d’écriture", "Espera de gravação")
        case "write_transaction": t("DB 저장", "DB save", "DB保存", "Guardado en BD", "Enregistrement BD", "Gravação no BD")
        default: key
        }
    }
    func serverJobName(_ name: String) -> String {
        switch name {
        case "backup": t("자동 백업과 복원 검사", "Backup and restore check", "自動バックアップと復元チェック", "Copia y prueba de restauración", "Sauvegarde et test de restauration", "Backup e teste de restauração")
        case "prices": t("시세 갱신", "Price refresh", "相場の更新", "Actualización de precios", "Mise à jour des prix", "Atualização de preços")
        case "expiry": t("거래 만료 처리", "Trade expiry", "取引の期限処理", "Caducidad de tratos", "Expiration des échanges", "Expiração de negociações")
        default: name
        }
    }
    func serverJobState(_ state: String) -> String {
        switch state {
        case "ok": t("정상", "OK", "正常", "Correcto", "OK", "OK")
        case "failed": t("실패", "Failed", "失敗", "Error", "Échec", "Falhou")
        case "stale": t("지연", "Delayed", "遅延", "Retrasada", "En retard", "Atrasada")
        case "running": t("진행 중", "Running", "実行中", "En curso", "En cours", "Em andamento")
        case "waiting": t("첫 실행 대기", "Waiting for first run", "初回実行待ち", "Esperando la primera ejecución", "En attente de la première exécution", "Aguardando a primeira execução")
        case "disabled": t("비활성", "Disabled", "無効", "Desactivada", "Désactivée", "Desativada")
        default: state
        }
    }
}

// MARK: 설정 탭과 나머지

extension L {
    func settingsTab(_ tab: SettingsView.SettingsTab) -> String {
        switch tab {
        case .general: generalSectionTitle
        case .display: t("표시", "Display", "表示", "Pantalla", "Affichage", "Exibição")
        case .data: t("데이터", "Data", "データ", "Datos", "Données", "Dados")
        case .advanced: advancedSectionTitle
        }
    }
    var settingsSections: String { t("설정 분류", "Settings sections", "設定の分類", "Secciones de ajustes", "Sections des réglages", "Seções de ajustes") }
    var connectionSection: String { t("연결", "Connection", "接続", "Conexión", "Connexion", "Conexão") }
    var onlineModeLabel: String { t("온라인 모드", "Online mode", "オンラインモード", "Modo en línea", "Mode en ligne", "Modo online") }
    var localModeLabel: String { t("로컬 모드", "Local mode", "ローカルモード", "Modo local", "Mode local", "Modo local") }
    var accountSummaryLine: String { t("로그인, 기기, 복구, 서버 상태", "Sign-in, devices, recovery, server status", "ログイン、デバイス、復旧、サーバー状態", "Sesión, dispositivos, recuperación, estado del servidor", "Connexion, appareils, récupération, état du serveur", "Login, dispositivos, recuperação, status do servidor") }
    var accountAndServerEllipsis: String { t("계정 및 서버…", "Account and server…", "アカウントとサーバー…", "Cuenta y servidor…", "Compte et serveur…", "Conta e servidor…") }
    var onlinePricesNote: String { t("온라인 시세는 서버에서 자동 갱신돼요. 마지막 정상 시세를 쓰고, 앱을 다시 설치할 필요는 없어요.", "Online prices refresh automatically on the server. The last good prices are used; no reinstall needed.", "オンライン相場はサーバーで自動更新されます。最後の正常な相場を使い、アプリの再インストールは不要です。", "Los precios en línea se actualizan solos en el servidor. Se usan los últimos válidos; no hace falta reinstalar.", "Les prix en ligne se mettent à jour sur le serveur. Les derniers prix valides sont utilisés ; aucune réinstallation n’est nécessaire.", "Os preços online se atualizam sozinhos no servidor. Os últimos válidos são usados; não é preciso reinstalar.") }
    func showAllDexes(_ n: Int) -> String { t("이 카드가 들어가는 도감 \(n)개 모두 보기", "Show all \(n) dexes with this card", "このカードが入る図鑑\(n)件をすべて見る", "Ver las \(n) Dex con esta carta", "Voir les \(n) Dex avec cette carte", "Ver as \(n) Dex com esta carta") }
}

// MARK: 서버와 로그인 오류 (Core)

extension L {
    /// 메인 액터 밖에서 만드는 오류 설명용. 화면과 같은 언어를 쓴다.
    static var current: L { L(AppLanguage.current) }

    var passwordLengthRule: String { t("8~128자", "8 to 128 characters", "8〜128文字", "8 a 128 caracteres", "8 à 128 caractères", "8 a 128 caracteres") }
    var credentialUnreadable: String { t("로그인 정보를 읽지 못했어요. 계정 창에서 다시 로그인해 주세요.", "Couldn’t read your sign-in. Sign in again from the account window.", "ログイン情報を読み取れませんでした。アカウント画面で再ログインしてください。", "No se pudo leer tu sesión. Vuelve a entrar desde la ventana de cuenta.", "Impossible de lire votre connexion. Reconnectez-vous depuis la fenêtre du compte.", "Não foi possível ler seu login. Entre de novo pela janela da conta.") }
    var credentialMismatch: String { t("이 Mac과 로그인 정보가 맞지 않아요. 다시 로그인해 주세요.", "This sign-in doesn’t match this Mac. Please sign in again.", "このMacとログイン情報が一致しません。もう一度ログインしてください。", "La sesión no coincide con este Mac. Vuelve a iniciar sesión.", "Cette connexion ne correspond pas à ce Mac. Reconnectez-vous.", "O login não corresponde a este Mac. Entre novamente.") }
    var credentialSaveFailed: String { t("로그인 파일을 저장하지 못했어요.", "Couldn’t save the session file.", "ログインファイルを保存できませんでした。", "No se pudo guardar el archivo de sesión.", "Impossible d’enregistrer le fichier de session.", "Não foi possível salvar o arquivo de sessão.") }
    var credentialDeleteFailed: String { t("로그인 파일을 삭제하지 못했어요.", "Couldn’t remove the session file.", "ログインファイルを削除できませんでした。", "No se pudo borrar el archivo de sesión.", "Impossible de supprimer le fichier de session.", "Não foi possível remover o arquivo de sessão.") }
    var importLegacySignIn: String { t("이전 로그인 가져오기", "Import previous sign-in", "以前のログインを取り込む", "Importar sesión anterior", "Importer l’ancienne connexion", "Importar login anterior") }
    var importLegacySignInNote: String { t("이 버튼을 누를 때만 이전 Keychain 로그인을 읽어요. macOS 승인이 한 번 필요할 수 있어요. 이후에는 로그인 파일을 사용합니다.", "Only this button reads the old Keychain session. macOS may ask once; later launches use the session file.", "このボタンだけが以前のキーチェーンを読みます。macOSの許可が一度必要な場合があります。以降はログインファイルを使います。", "Solo este botón lee la sesión anterior del llavero. macOS puede pedir permiso una vez; después se usa el archivo.", "Seul ce bouton lit l’ancienne session du trousseau. macOS peut demander une autorisation ; les lancements suivants utilisent le fichier.", "Só este botão lê a sessão antiga do Keychain. O macOS pode pedir permissão uma vez; depois é usado o arquivo.") }
    var localSessionNote: String { t("로그인 토큰은 이 Mac의 앱 전용 파일에 저장합니다. 비밀번호는 저장하지 않으며 Keychain보다 보호가 약합니다.", "Your session token is stored in an app-local file on this Mac. Passwords are not saved; protection is weaker than Keychain.", "トークンはこのMacのアプリ専用ファイルに保存します。パスワードは保存せず、保護はキーチェーンより弱くなります。", "El token se guarda en un archivo local de la app. No se guarda la contraseña; la protección es menor que en el llavero.", "Le jeton est stocké dans un fichier local de l’app. Aucun mot de passe n’est enregistré ; la protection est moindre que dans le trousseau.", "O token fica em um arquivo local do app. A senha não é salva; a proteção é menor que no Keychain.") }
    func serverUnreachable(_ reason: String) -> String { t("서버에 연결하지 못했어요. 인터넷 연결을 확인하고 다시 시도해 주세요. (\(reason))", "Couldn’t reach the server. Check your internet connection and try again. (\(reason))", "サーバーに接続できませんでした。インターネット接続を確認して、もう一度お試しください。（\(reason)）", "No se pudo conectar con el servidor. Revisa tu conexión e inténtalo de nuevo. (\(reason))", "Impossible de joindre le serveur. Vérifiez votre connexion et réessayez. (\(reason))", "Não foi possível conectar ao servidor. Verifique a internet e tente de novo. (\(reason))") }
    var loginDeviceMismatch: String { t("로그인 응답의 기기 정보가 맞지 않아요.", "The sign-in reply was for a different device.", "ログイン応答のデバイス情報が一致しません。", "La respuesta de inicio de sesión es de otro dispositivo.", "La réponse de connexion concerne un autre appareil.", "A resposta de login é de outro dispositivo.") }
    var loginRequiredMessage: String { t("로그인이 필요하거나 로그인이 만료됐어요. 같은 계정으로 다시 로그인해 주세요.", "You need to sign in, or your sign-in expired. Sign in again with the same account.", "ログインが必要か、ログインの有効期限が切れました。同じアカウントで再ログインしてください。", "Debes iniciar sesión o tu sesión caducó. Vuelve a entrar con la misma cuenta.", "Connexion requise ou expirée. Reconnectez-vous avec le même compte.", "É preciso entrar ou sua sessão expirou. Entre de novo com a mesma conta.") }
    var remoteNeedsHTTPS: String { t("원격 서버 주소는 HTTPS여야 해요.", "Remote server addresses must use HTTPS.", "リモートサーバーのアドレスはHTTPSにしてください。", "Las direcciones remotas deben usar HTTPS.", "Les adresses distantes doivent utiliser HTTPS.", "Endereços remotos precisam usar HTTPS.") }
    var invalidCredentials: String { t("이메일이나 비밀번호가 맞지 않아요.", "The email or password is incorrect.", "メールアドレスまたはパスワードが正しくありません。", "El correo o la contraseña no son correctos.", "E-mail ou mot de passe incorrect.", "E-mail ou senha incorretos.") }
    var invalidRecovery: String { t("이메일이나 복구 코드가 맞지 않거나 이미 쓴 코드예요.", "The email or recovery code is wrong, or the code was already used.", "メールアドレスか復旧コードが正しくないか、使用済みのコードです。", "El correo o el código no son correctos, o el código ya se usó.", "E-mail ou code incorrect, ou code déjà utilisé.", "E-mail ou código incorretos, ou o código já foi usado.") }
    var deviceListChanged: String { t("기기 목록이 바뀌었어요. 새로고침해 주세요.", "The device list changed. Please refresh.", "デバイス一覧が変わりました。更新してください。", "La lista de dispositivos cambió. Actualiza.", "La liste des appareils a changé. Actualisez.", "A lista de dispositivos mudou. Atualize.") }
    var linkCodeInvalid: String { t("연결 코드가 만료됐거나 이미 쓴 코드예요. 서버에서 새 코드를 받아 주세요.", "The link code expired or was already used. Get a new one from the server.", "連携コードの期限が切れたか、使用済みです。サーバーで新しいコードを取得してください。", "El código caducó o ya se usó. Pide uno nuevo al servidor.", "Code de liaison expiré ou déjà utilisé. Obtenez-en un nouveau sur le serveur.", "O código expirou ou já foi usado. Gere um novo no servidor.") }
    var registrationUnavailable: String { t("이 정보로는 가입할 수 없어요. 이미 계정이 있다면 로그인해 주세요.", "Can’t sign up with these details. If you already have an account, sign in.", "この情報では登録できません。すでにアカウントがある場合はログインしてください。", "No se puede registrar con estos datos. Si ya tienes cuenta, inicia sesión.", "Inscription impossible avec ces informations. Si vous avez un compte, connectez-vous.", "Não é possível cadastrar com esses dados. Se já tem conta, entre.") }
    var tooManyAttempts: String { t("시도가 너무 많아요. 1분 뒤에 다시 해 주세요.", "Too many attempts. Try again in a minute.", "試行回数が多すぎます。1分後にもう一度お試しください。", "Demasiados intentos. Prueba dentro de un minuto.", "Trop de tentatives. Réessayez dans une minute.", "Tentativas demais. Tente de novo em um minuto.") }
    func checkEmailAndLength(_ rule: String) -> String { t("이메일 형식과 비밀번호 길이(가입할 때 \(rule))를 확인해 주세요.", "Check the email format and password length (\(rule) when signing up).", "メールアドレスの形式とパスワードの長さ（登録時は\(rule)）を確認してください。", "Revisa el formato del correo y la longitud de la contraseña (\(rule) al registrarte).", "Vérifiez le format de l’e-mail et la longueur du mot de passe (\(rule) à l’inscription).", "Confira o formato do e-mail e o tamanho da senha (\(rule) no cadastro).") }
    func authServerStatus(_ status: Int, request: String) -> String { t("인증 서버가 \(status) 응답을 보냈어요. 주소와 서버 상태를 확인해 주세요. (요청 번호 \(request))", "The sign-in server replied \(status). Check the address and server status. (Request \(request))", "認証サーバーが\(status)を返しました。アドレスとサーバー状態を確認してください。（リクエスト番号 \(request)）", "El servidor de inicio de sesión respondió \(status). Revisa la dirección y su estado. (Solicitud \(request))", "Le serveur de connexion a répondu \(status). Vérifiez l’adresse et l’état du serveur. (Requête \(request))", "O servidor de login respondeu \(status). Confira o endereço e o status. (Solicitação \(request))") }

    var priceCacheCorrupt: String { t("시세 캐시가 손상되어 서버에서 다시 받아야 해요.", "The price cache is damaged and must be downloaded again from the server.", "相場キャッシュが破損しているため、サーバーから取得し直す必要があります。", "La caché de precios está dañada y debe descargarse de nuevo.", "Le cache des prix est endommagé et doit être retéléchargé.", "O cache de preços está danificado e precisa ser baixado de novo.") }
    var rulesVersionMismatch: String { t("서버와 앱의 게임 규칙과 시세 버전이 달라요. 같은 빌드로 업데이트해 주세요.", "The server and app use different rules or price versions. Update to the same build.", "サーバーとアプリでゲームルールと相場のバージョンが異なります。同じビルドに更新してください。", "El servidor y la app usan versiones distintas de reglas o precios. Actualiza a la misma versión.", "Le serveur et l’app n’utilisent pas les mêmes règles ou prix. Mettez à jour vers la même version.", "Servidor e app usam versões diferentes de regras ou preços. Atualize para a mesma versão.") }
    var priceVerificationFailed: String { t("시세 데이터 검증에 실패했어요.", "Price data failed verification.", "相場データの検証に失敗しました。", "Falló la verificación de los precios.", "La vérification des prix a échoué.", "A verificação dos preços falhou.") }
    var recoverOnlineTradeFirst: String { t("미확인 온라인 거래를 먼저 복구해 주세요.", "Recover the unconfirmed online trade first.", "未確認のオンライン取引を先に復旧してください。", "Primero recupera el trato en línea sin confirmar.", "Récupérez d’abord la transaction en ligne non confirmée.", "Recupere primeiro a negociação online não confirmada.") }
    var anotherRequestRunning: String { t("다른 서버 요청을 처리하고 있어요.", "Another server request is in progress.", "別のサーバーリクエストを処理しています。", "Hay otra solicitud en curso.", "Une autre requête est en cours.", "Outra solicitação está em andamento.") }
    var checkServerFirst: String { t("서버 연결을 먼저 확인해 주세요. 로컬 자원은 바꾸지 않았어요.", "Check the server connection first. Local resources weren’t changed.", "先にサーバー接続を確認してください。ローカルの資源は変更していません。", "Revisa primero la conexión. No se cambió nada local.", "Vérifiez d’abord la connexion. Rien n’a changé en local.", "Confira primeiro a conexão. Nada local foi alterado.") }
    var retryPendingFirst: String { t("응답을 확인하지 못한 요청이 있어요. 먼저 다시 시도해 주세요.", "A request is still unconfirmed. Retry it first.", "応答を確認できていないリクエストがあります。先に再試行してください。", "Hay una solicitud sin confirmar. Reinténtala primero.", "Une requête n’est pas confirmée. Réessayez-la d’abord.", "Há uma solicitação sem confirmação. Tente-a de novo primeiro.") }
    var stateChangedResync: String { t("가격이나 계정 상태가 바뀌었어요. 동기화한 뒤 금액을 다시 확인해 주세요.", "Prices or your account changed. Sync and check the amount again.", "価格かアカウントの状態が変わりました。同期してから金額をもう一度確認してください。", "Cambiaron los precios o tu cuenta. Sincroniza y revisa el importe.", "Les prix ou votre compte ont changé. Synchronisez puis revérifiez le montant.", "Preços ou conta mudaram. Sincronize e confira o valor de novo.") }
    var quoteMismatch: String { t("확인한 금액과 서버 견적이 달라요. 새로고침한 뒤 바뀐 금액을 다시 확인해 주세요.", "The amount you confirmed differs from the server quote. Refresh and check the new amount.", "確認した金額とサーバーの見積もりが異なります。更新して変わった金額を確認してください。", "El importe confirmado no coincide con el del servidor. Actualiza y revisa el nuevo importe.", "Le montant confirmé diffère du devis du serveur. Actualisez et vérifiez le nouveau montant.", "O valor confirmado difere da cotação do servidor. Atualize e confira o novo valor.") }
    var invalidServerReply: String { t("잘못된 서버 응답", "Invalid server reply", "不正なサーバー応答", "Respuesta del servidor no válida", "Réponse du serveur invalide", "Resposta inválida do servidor") }
    var requestRefused: String { t("서버가 요청을 거절했어요. 다른 기기에서 상태가 바뀌었거나 조건에 맞지 않아요. 새로고침한 뒤 다시 시도해 주세요.", "The server refused the request. Something changed on another device or a condition wasn’t met. Refresh and try again.", "サーバーがリクエストを拒否しました。別のデバイスで状態が変わったか、条件を満たしていません。更新してからもう一度お試しください。", "El servidor rechazó la solicitud. Algo cambió en otro dispositivo o no se cumple una condición. Actualiza e inténtalo de nuevo.", "Le serveur a refusé la requête. Un autre appareil a modifié l’état ou une condition n’est pas remplie. Actualisez et réessayez.", "O servidor recusou a solicitação. Algo mudou em outro dispositivo ou uma condição não foi atendida. Atualize e tente de novo.") }
    func serverReplyKept(_ status: Int) -> String { t("서버 응답 \(status). 요청 ID를 보존했어요. 같은 요청으로 다시 시도할 수 있어요.", "Server replied \(status). The request ID was kept, so the same request can be retried.", "サーバー応答 \(status)。リクエストIDを保持しました。同じリクエストで再試行できます。", "El servidor respondió \(status). Se guardó el ID para reintentar la misma solicitud.", "Le serveur a répondu \(status). L’ID de requête est conservé pour réessayer.", "O servidor respondeu \(status). O ID foi guardado para tentar a mesma solicitação de novo.") }
    var replyMissingState: String { t("서버 응답에 계정 상태가 없어요.", "The server reply had no account state.", "サーバー応答にアカウントの状態がありません。", "La respuesta no incluía el estado de la cuenta.", "La réponse ne contenait pas l’état du compte.", "A resposta não trazia o estado da conta.") }
    var patchUnreadable: String { t("계정 상태 변경분을 읽지 못했어요.", "Couldn’t read the account state changes.", "アカウント状態の変更分を読み取れませんでした。", "No se pudieron leer los cambios de la cuenta.", "Impossible de lire les changements du compte.", "Não foi possível ler as mudanças da conta.") }
    var replyAccountMismatch: String { t("계정이나 버전이 맞지 않는 응답이에요.", "The reply was for a different account or version.", "アカウントかバージョンが一致しない応答です。", "La respuesta es de otra cuenta o versión.", "La réponse concerne un autre compte ou une autre version.", "A resposta é de outra conta ou versão.") }
    func serverStatusFailed(_ status: Int) -> String { t("서버 상태를 가져오지 못했어요. (HTTP \(status))", "Couldn’t get the server status. (HTTP \(status))", "サーバー状態を取得できませんでした。（HTTP \(status)）", "No se pudo obtener el estado del servidor. (HTTP \(status))", "Impossible d’obtenir l’état du serveur. (HTTP \(status))", "Não foi possível obter o status do servidor. (HTTP \(status))") }
    func serverFailure(_ status: Int, _ detail: String) -> String { t("서버에서 오류가 났어요 (HTTP \(status), \(detail)). 잠시 뒤 다시 시도해 주세요.", "The server ran into an error (HTTP \(status), \(detail)). Try again shortly.", "サーバーでエラーが発生しました（HTTP \(status)、\(detail)）。しばらくしてからもう一度お試しください。", "El servidor tuvo un error (HTTP \(status), \(detail)). Inténtalo en un momento.", "Le serveur a rencontré une erreur (HTTP \(status), \(detail)). Réessayez bientôt.", "O servidor teve um erro (HTTP \(status), \(detail)). Tente de novo em instantes.") }
    func requestNotCompleted(_ detail: String) -> String { t("요청을 완료하지 못했어요: \(detail). 새로고침한 뒤 조건을 다시 확인해 주세요.", "The request couldn’t be completed: \(detail). Refresh and check the conditions again.", "リクエストを完了できませんでした: \(detail)。更新して条件をもう一度確認してください。", "No se pudo completar la solicitud: \(detail). Actualiza y revisa las condiciones.", "La requête n’a pas abouti : \(detail). Actualisez et revérifiez les conditions.", "A solicitação não foi concluída: \(detail). Atualize e confira as condições.") }
    var recoverOtherRequestFirst: String { t("다른 요청이나 미확인 거래를 먼저 복구해 주세요.", "Recover the other request or unconfirmed trade first.", "別のリクエストか未確認の取引を先に復旧してください。", "Primero recupera la otra solicitud o el trato sin confirmar.", "Récupérez d’abord l’autre requête ou la transaction non confirmée.", "Recupere primeiro a outra solicitação ou a negociação não confirmada.") }
}

// MARK: 지갑 오류 (WalletStore)

extension L {
    var invalidOnlineConfig: String { t("온라인 연결 설정이 잘못됐어요. 설정을 고치고 앱을 다시 시작해 주세요. 로컬 세이브는 바꾸지 않았어요.", "The online connection settings are invalid. Fix them and restart the app. Your local save wasn’t changed.", "オンライン接続の設定が正しくありません。設定を直してアプリを再起動してください。ローカルセーブは変更していません。", "La configuración en línea no es válida. Corrígela y reinicia la app. Tu partida local no cambió.", "Les réglages en ligne sont invalides. Corrigez-les puis redémarrez l’app. Votre sauvegarde locale n’a pas changé.", "As configurações online são inválidas. Corrija e reinicie o app. Seu salvamento local não mudou.") }
    var packPriceChanged: String { t("팩 가격이 바뀌었어요. 구매 수량과 금액을 다시 확인해 주세요.", "The pack price changed. Check the quantity and amount again.", "パックの価格が変わりました。購入数と金額をもう一度確認してください。", "El precio del sobre cambió. Revisa la cantidad y el importe.", "Le prix du booster a changé. Vérifiez la quantité et le montant.", "O preço do pacote mudou. Confira a quantidade e o valor.") }
    func packsBoughtPartly(_ done: Int, of total: Int, reason: String?) -> String {
        let reason = reason ?? t("요청 실패", "Request failed", "リクエスト失敗", "Solicitud fallida", "Échec de la requête", "Falha na solicitação")
        return t("\(done)/\(total)팩 구매 완료. \(reason)", "Bought \(done) of \(total) packs. \(reason)", "\(total)パック中\(done)パック購入しました。\(reason)",
                 "Comprados \(done) de \(total) sobres. \(reason)", "\(done) boosters achetés sur \(total). \(reason)", "\(done) de \(total) pacotes comprados. \(reason)")
    }
    var noOpeningResult: String { t("개봉 결과가 없어요.", "No opening result came back.", "開封結果がありません。", "No llegó el resultado de la apertura.", "Aucun résultat d’ouverture.", "Nenhum resultado de abertura.") }
    func openingJobPaused(_ done: Int, of total: Int, reason: String) -> String {
        t("\(total)팩 중 \(done)팩을 확인했어요. 온라인 창의 「대량 개봉」에서 이어 열 수 있어요. \(reason)",
          "Confirmed \(done) of \(total) packs. Continue from Bulk opening in the online window. \(reason)",
          "\(total)パック中\(done)パックを確認しました。オンライン画面の「大量開封」から続けられます。\(reason)",
          "Confirmados \(done) de \(total) sobres. Sigue desde Apertura masiva en la ventana en línea. \(reason)",
          "\(done) boosters confirmés sur \(total). Reprenez depuis Ouverture en masse dans la fenêtre en ligne. \(reason)",
          "\(done) de \(total) pacotes confirmados. Continue em Abertura em massa na janela online. \(reason)")
    }
    func packsOpenedPartly(_ done: Int, of total: Int, reason: String?) -> String {
        let reason = reason ?? t("결과 확인 실패", "Couldn’t confirm the result", "結果を確認できませんでした", "No se pudo confirmar el resultado", "Résultat non confirmé", "Não foi possível confirmar o resultado")
        return t("\(total)팩 중 \(done)팩 개봉을 확인했어요. \(reason)", "Confirmed \(done) of \(total) packs opened. \(reason)", "\(total)パック中\(done)パックの開封を確認しました。\(reason)",
                 "Confirmada la apertura de \(done) de \(total) sobres. \(reason)", "Ouverture de \(done) boosters sur \(total) confirmée. \(reason)", "Abertura de \(done) de \(total) pacotes confirmada. \(reason)")
    }
    var onlineChangesThroughServer: String { t("온라인 자원은 서버 명령으로만 바꿀 수 있어요.", "Online resources can only change through server commands.", "オンラインの資源はサーバーのコマンドでのみ変更できます。", "Los recursos en línea solo cambian con órdenes del servidor.", "Les ressources en ligne ne changent que par des commandes serveur.", "Recursos online só mudam por comandos do servidor.") }
}

// MARK: 교환 바인더와 역제안

extension L {
    // MARK: 교환 칸의 「내게 없는 카드」

    var missingFromFriendTitle: String {
        t("내게 없는 카드", "Cards I don’t have", "持っていないカード", "Cartas que no tengo",
          "Cartes que je n’ai pas", "Cartas que não tenho")
    }
    func missingFromFriendCount(_ name: String, _ n: Int) -> String {
        t("\(name) 님에게 남는 카드 중 \(n)종", "\(n) of \(name)’s spare cards", "\(name)さんの余りカードのうち\(n)種",
          "\(n) de las cartas repetidas de \(name)", "\(n) des cartes en double de \(name)",
          "\(n) das cartas repetidas de \(name)")
    }
    func nothingMissingFromFriend(_ name: String) -> String {
        t("\(name) 님에게 남는 카드는 이미 모두 갖고 있어요.", "You already own every card \(name) can spare.",
          "\(name)さんの余りカードはすべて持っています。", "Ya tienes todas las cartas que le sobran a \(name).",
          "Vous avez déjà toutes les cartes que \(name) a en double.",
          "Você já tem todas as cartas que sobram para \(name).")
    }
    func seeAllCards(_ n: Int) -> String {
        t("\(n)종 모두 보기", "See all \(n)", "\(n)種すべて見る", "Ver las \(n)", "Voir les \(n)", "Ver todas as \(n)")
    }
    var checkingFriendSpares: String {
        t("친구에게 남는 카드를 확인하는 중", "Checking your friend’s spare cards", "フレンドの余りカードを確認中",
          "Comprobando las cartas repetidas de tu amigo", "Vérification des cartes en double de votre ami",
          "Verificando as cartas repetidas do seu amigo")
    }
    var addToWantedHint: String {
        t("받고 싶은 카드에 담아요", "Adds it to the cards you want", "欲しいカードに入れます",
          "La añade a las cartas que quieres", "L’ajoute aux cartes que vous voulez", "Adiciona às cartas que você quer")
    }
    /// 검색 칸과 한 줄에 놓이므로 짧게 적는다.
    var missingOnlyToggle: String {
        t("내게 없는 카드만", "Only cards I don’t have", "未所持のみ", "Solo las que me faltan",
          "Manquantes seulement", "Só as que me faltam")
    }
    /// 카드 아래 한 줄에 들어가야 하는 표시. 컬렉션의 「아직 없음」보다 짧게 적는 언어가 있다.
    var missingBadge: String {
        t("아직 없음", "Not owned", "未所持", "Me falta", "Manquante", "Me falta")
    }
    var noMissingCardsTitle: String {
        t("내게 없는 카드는 없어요", "Nothing here you don’t already own", "持っていないカードはありません",
          "No hay cartas que no tengas", "Aucune carte que vous n’ayez déjà", "Não há cartas que você não tenha")
    }
    var noMissingCardsHint: String {
        t("「내게 없는 카드만」을 끄면 친구에게 남는 카드를 모두 볼 수 있어요.",
          "Turn off “Only cards I don’t have” to see everything your friend can spare.",
          "「未所持のみ」をオフにすると、フレンドの余りカードをすべて表示します。",
          "Desactiva «Solo las que me faltan» para ver todo lo que le sobra a tu amigo.",
          "Désactivez « Manquantes seulement » pour voir tout ce que votre ami a en double.",
          "Desative “Só as que me faltam” para ver tudo o que sobra para seu amigo.")
    }

    var friendBinderTitle: String { t("친구의 교환 바인더", "Friend’s trade binder", "フレンドの交換バインダー", "Carpeta de intercambio del amigo", "Classeur d’échange de l’ami", "Fichário de troca do amigo") }
    var searchFriendCards: String { t("친구 카드에서 찾기", "Search friend’s cards", "フレンドのカードから探す", "Buscar en las cartas del amigo", "Chercher dans les cartes de l’ami", "Buscar nas cartas do amigo") }
    var friendBinderEmpty: String { t("친구가 내놓을 수 있는 카드가 없어요", "Your friend has no cards to trade", "フレンドが出せるカードはありません", "Tu amigo no tiene cartas para intercambiar", "Votre ami n’a aucune carte à échanger", "Seu amigo não tem cartas para trocar") }
    var friendBinderEmptyHint: String { t("친구가 같은 카드를 2장 이상 가지고 있어야 교환에 내놓을 수 있어요.", "A friend can trade a card once they own two or more of it.", "フレンドが同じカードを2枚以上持っていると交換に出せます。", "Tu amigo puede intercambiar una carta cuando tiene dos o más.", "Votre ami peut échanger une carte dès qu’il en possède deux ou plus.", "Seu amigo pode trocar uma carta quando tem duas ou mais.") }
    var friendBinderPrivate: String { t("친구가 교환용 카드를 공개하지 않았어요", "Your friend keeps their trade cards private", "フレンドは交換用カードを公開していません", "Tu amigo no comparte sus cartas de intercambio", "Votre ami ne partage pas ses cartes d’échange", "Seu amigo não compartilha as cartas de troca") }
    var friendBinderUnsupported: String { t("이 서버는 아직 교환 바인더를 지원하지 않아요", "This server doesn’t support trade binders yet", "このサーバーはまだ交換バインダーに対応していません", "Este servidor aún no admite carpetas de intercambio", "Ce serveur ne gère pas encore les classeurs d’échange", "Este servidor ainda não suporta fichários de troca") }
    var friendBinderFallbackHint: String { t("전체 카드에서 고를 수 있지만, 친구가 그 카드를 가지고 있는지는 알 수 없어요. 없는 카드면 친구가 수락할 수 없어요.", "You can pick from all cards, but you can’t tell whether your friend owns them. They can’t accept cards they don’t have.", "すべてのカードから選べますが、フレンドが持っているかはわかりません。持っていないカードだと承認できません。", "Puedes elegir entre todas las cartas, pero no sabrás si tu amigo las tiene. No podrá aceptar cartas que no tenga.", "Vous pouvez choisir parmi toutes les cartes, sans savoir si votre ami les possède. Il ne pourra pas accepter des cartes qu’il n’a pas.", "Você pode escolher entre todas as cartas, mas não sabe se seu amigo as tem. Ele não poderá aceitar cartas que não tem.") }
    var searchAllCards: String { t("전체 카드에서 찾기", "Search all cards", "すべてのカードから探す", "Buscar en todas las cartas", "Chercher dans toutes les cartes", "Buscar em todas as cartas") }
    func traySummary(kinds: Int, cards: Int, won: String?, unpriced: Int) -> String {
        var text = "\(kindsCount(kinds)), \(cardsCount(cards))"
        if let won { text += ", " + marketQuote(won) }
        if unpriced > 0 {
            text += " " + t("(시세 없는 카드 \(unpriced)장 제외)", "(\(unpriced) without a price)", "（相場なし\(unpriced)枚を除く）", "(\(unpriced) sin precio)", "(\(unpriced) sans cote)", "(\(unpriced) sem preço)")
        }
        return text
    }
    /// 양쪽 시세 합계의 차이. 받는 쪽 기준으로 말한다.
    func valueBalance(give: String, get: String, difference: Int, gap: String) -> String {
        let head = t("시세로 줄 카드 \(give), 받을 카드 \(get).", "By market value you give \(give) and get \(get).", "相場で渡すカード\(give)、受け取るカード\(get)。", "A precio de mercado das \(give) y recibes \(get).", "À la cote, vous donnez \(give) et recevez \(get).", "Pelo preço de mercado você dá \(give) e recebe \(get).")
        if difference == 0 { return head + " " + t("같아요.", "They match.", "同じです。", "Están igualados.", "C’est équilibré.", "Está equilibrado.") }
        return head + " " + (difference > 0
            ? t("받는 쪽이 \(gap) 더 많아요.", "You get \(gap) more.", "受け取る側が\(gap)多いです。", "Recibes \(gap) más.", "Vous recevez \(gap) de plus.", "Você recebe \(gap) a mais.")
            : t("주는 쪽이 \(gap) 더 많아요.", "You give \(gap) more.", "渡す側が\(gap)多いです。", "Das \(gap) más.", "Vous donnez \(gap) de plus.", "Você dá \(gap) a mais."))
    }
    var counterAction: String { t("역제안", "Counter", "逆提案", "Contraoferta", "Contre-offre", "Contraproposta") }
    func counteringBanner(_ name: String) -> String { t("\(name)님의 제안을 바꿔서 보내요. 보내면 원래 제안은 닫혀요.", "You’re changing \(name)’s offer. Sending it closes the original.", "\(name)さんの提案を変えて送ります。送ると元の提案は閉じます。", "Estás cambiando la oferta de \(name). Al enviarla se cierra la original.", "Vous modifiez l’offre de \(name). L’envoyer ferme l’originale.", "Você está mudando a proposta de \(name). Ao enviar, a original é fechada.") }
    var stopCountering: String { t("역제안 그만두기", "Stop countering", "逆提案をやめる", "Dejar la contraoferta", "Abandonner la contre-offre", "Desistir da contraproposta") }
    var sendCounter: String { t("역제안 보내기", "Send counter", "逆提案を送る", "Enviar contraoferta", "Envoyer la contre-offre", "Enviar contraproposta") }
    var confirmCounter: String { t("이렇게 역제안할까요?", "Send this counter-offer?", "この内容で逆提案しますか？", "¿Enviar esta contraoferta?", "Envoyer cette contre-offre ?", "Enviar esta contraproposta?") }
    var confirmCounterNote: String { t("원래 제안은 닫히고 친구 카드의 잠금도 풀려요. 친구가 72시간 안에 수락하면 바로 바뀌어요.", "The original offer closes and your friend’s cards are released. If they accept within 72 hours, the cards swap right away.", "元の提案は閉じ、フレンドのカードの確保も解除されます。72時間以内に承認されるとすぐに交換されます。", "La oferta original se cierra y se liberan las cartas de tu amigo. Si acepta en 72 horas, se intercambian al momento.", "L’offre d’origine est fermée et les cartes de votre ami sont libérées. S’il accepte sous 72 heures, l’échange est immédiat.", "A proposta original é fechada e as cartas do seu amigo são liberadas. Se ele aceitar em 72 horas, a troca é imediata.") }
    var tradeCountered: String { t("역제안함", "Countered", "逆提案済み", "Contraofertado", "Contre-offre faite", "Contraproposto") }
    func counterFrom(_ name: String) -> String { t("\(name)님의 역제안", "Counter-offer from \(name)", "\(name)さんの逆提案", "Contraoferta de \(name)", "Contre-offre de \(name)", "Contraproposta de \(name)") }
    func counterTo(_ name: String) -> String { t("\(name)님에게 보낸 역제안", "Counter-offer to \(name)", "\(name)さんへの逆提案", "Contraoferta para \(name)", "Contre-offre à \(name)", "Contraproposta para \(name)") }
    var noteTradeCountered: String { t("교환 제안에 역제안이 왔어요", "Your trade offer got a counter-offer", "交換の提案に逆提案が届きました", "Tu oferta recibió una contraoferta", "Votre offre a reçu une contre-offre", "Sua proposta recebeu uma contraproposta") }
    var tradeListToggle: String { t("교환용 카드 (2장 이상인 카드)", "Trade cards (two or more copies)", "交換用カード（2枚以上のカード）", "Cartas de intercambio (dos o más copias)", "Cartes d’échange (deux exemplaires ou plus)", "Cartas de troca (duas ou mais cópias)") }
    var tradeWithFriend: String { t("이 친구와 교환하기", "Trade with this friend", "このフレンドと交換する", "Intercambiar con este amigo", "Échanger avec cet ami", "Trocar com este amigo") }
    var requestedCardsUnavailable: String { t("친구가 그 카드를 지금은 내놓을 수 없어요. 친구의 교환 바인더를 다시 확인해 주세요.", "Your friend can’t spare those cards right now. Check their trade binder again.", "フレンドはそのカードを今は出せません。交換バインダーをもう一度確認してください。", "Tu amigo no puede dar esas cartas ahora. Revisa de nuevo su carpeta de intercambio.", "Votre ami ne peut pas céder ces cartes pour l’instant. Revoyez son classeur d’échange.", "Seu amigo não pode dar essas cartas agora. Confira de novo o fichário de troca dele.") }
}
