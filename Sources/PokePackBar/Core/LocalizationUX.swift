import Foundation

/// 처음 쓰는 사람과 자주 쓰는 사람이 덜 헤매게 하는 문구. 첫 실행 안내, 개봉 설정, 창 크기,
/// 큰 구매 확인, 친구 코드, 서버 거절 이유.

// MARK: 첫 실행 안내

extension L {
    var onboardingTitle: String { t("이렇게 모아요", "How it works", "遊び方", "Cómo funciona", "Comment ça marche", "Como funciona") }
    var onboardingEarn: String {
        t("AI 코딩 도구를 쓰면 쓴 토큰만큼 잔액이 쌓여요",
          "Using AI coding tools adds the tokens you spend to your balance",
          "AIコーディングツールを使うと、使ったトークンの分だけ残高が貯まります",
          "Al usar herramientas de IA para programar, los tokens que gastas se suman a tu saldo",
          "Les jetons dépensés avec vos outils d’IA de code s’ajoutent à votre solde",
          "Usar ferramentas de IA para programar soma ao saldo os tokens que você gasta")
    }
    var onboardingBuy: String {
        t("상점에서 잔액으로 카드팩을 사요",
          "Spend your balance on booster packs in the shop",
          "ショップで残高を使ってパックを買います",
          "Gasta tu saldo en sobres en la tienda",
          "Achetez des boosters avec votre solde dans la boutique",
          "Use o saldo para comprar pacotes na loja")
    }
    var onboardingOpen: String {
        t("팩 탭에서 팩을 뜯어 카드를 모으고 도감을 채워요",
          "Open packs in the Packs tab to collect cards and fill your dex",
          "パックタブでパックを開けてカードを集め、図鑑を埋めます",
          "Abre sobres en la pestaña Sobres para coleccionar cartas y completar la Pokédex",
          "Ouvrez des boosters dans l’onglet Boosters pour collectionner et remplir le Pokédex",
          "Abra pacotes na aba Pacotes para colecionar cartas e completar a Pokédex")
    }
    var onboardingStart: String { t("시작하기", "Got it", "はじめる", "Entendido", "C’est parti", "Entendi") }
}

// MARK: 개봉

extension L {
    var manualTear: String { t("팩 직접 뜯기", "Tear packs by hand", "パックを手で開ける", "Abrir sobres a mano", "Déchirer les boosters à la main", "Rasgar pacotes à mão") }
    var manualTearHint: String {
        t("끄면 팩이 저절로 뜯겨 카드가 바로 나와요",
          "When off, packs tear open by themselves and the cards come right out",
          "オフにするとパックが自動で開き、すぐにカードが出ます",
          "Si lo desactivas, los sobres se abren solos y las cartas salen enseguida",
          "Désactivé, les boosters s’ouvrent tout seuls et les cartes sortent aussitôt",
          "Desligado, os pacotes se abrem sozinhos e as cartas saem na hora")
    }
    var revealKeyboardHint: String {
        t("스페이스 키나 오른쪽 화살표 키로 넘겨요", "Press Space or the right arrow key to flip",
          "スペースキーか右矢印キーでめくれます", "Pulsa Espacio o la flecha derecha para pasar",
          "Espace ou flèche droite pour retourner", "Aperte Espaço ou a seta para a direita para virar")
    }
}

// MARK: 창 크기

extension L {
    var popoverSize: String { t("창 크기", "Window size", "ウィンドウサイズ", "Tamaño de la ventana", "Taille de la fenêtre", "Tamanho da janela") }
    var popoverSizeRegular: String { t("보통", "Regular", "標準", "Normal", "Normale", "Normal") }
    var popoverSizeLarge: String { t("크게", "Large", "大きい", "Grande", "Grande", "Grande") }
    var popoverSizeHint: String {
        t("카드와 격자가 커져요. 다시 시작하면 적용돼요.",
          "Cards and grids get bigger. Takes effect after a restart.",
          "カードとグリッドが大きくなります。再起動すると反映されます。",
          "Las cartas y la cuadrícula se agrandan. Se aplica al reiniciar.",
          "Les cartes et la grille s’agrandissent. Appliqué au redémarrage.",
          "Cartas e grade ficam maiores. Vale depois de reiniciar.")
    }
}

// MARK: 큰 구매 확인

extension L {
    /// 잔액의 몇 %를 쓰는지. 1% 아래는 굳이 묻지 않으므로 정수로 충분하다.
    func purchaseConfirmPrompt(_ percent: Int) -> String {
        t("잔액의 \(percent)%를 써요. 살까요?", "This uses \(percent)% of your balance. Buy?",
          "残高の\(percent)%を使います。買いますか？", "Esto usa el \(percent)% de tu saldo. ¿Comprar?",
          "Cela utilise \(percent) % de votre solde. Acheter ?", "Isso usa \(percent)% do seu saldo. Comprar?")
    }
    var purchaseConfirmAction: String { t("살게요", "Buy", "買う", "Comprar", "Acheter", "Comprar") }
}

// MARK: 친구 코드

extension L {
    var shareAction: String { t("공유", "Share", "共有", "Compartir", "Partager", "Compartilhar") }
    var pasteAction: String { t("붙여넣기", "Paste", "ペースト", "Pegar", "Coller", "Colar") }
    func friendCodeShareText(_ code: String) -> String {
        t("PokePackBar 친구 코드: \(code)", "My PokePackBar friend code: \(code)", "PokePackBarのフレンドコード：\(code)",
          "Mi código de amigo de PokePackBar: \(code)", "Mon code ami PokePackBar : \(code)",
          "Meu código de amigo do PokePackBar: \(code)")
    }
    var friendCodeFormatHint: String {
        t("친구 코드는 16자리예요. 띄어쓰기와 대소문자는 상관없어요.",
          "Friend codes have 16 characters. Spaces and letter case don’t matter.",
          "フレンドコードは16文字です。スペースや大文字小文字は気にしなくて大丈夫です。",
          "Los códigos de amigo tienen 16 caracteres. Los espacios y las mayúsculas no importan.",
          "Les codes ami comptent 16 caractères. Espaces et majuscules sans importance.",
          "Códigos de amigo têm 16 caracteres. Espaços e maiúsculas não importam.")
    }
}

// MARK: 알림

extension L {
    var openNotification: String { t("관련 화면 열기", "Open related section", "関連画面を開く", "Abrir sección relacionada", "Ouvrir la section liée", "Abrir seção relacionada") }
}

// MARK: 서버가 거절한 이유

extension L {
    /// 서버가 준 이유 코드를 사람이 읽을 문장으로. 모르는 코드면 `nil` 이다 — 그때는 예전처럼
    /// 코드를 그대로 붙여, 적어도 무엇이 거절됐는지 찾아볼 수 있게 한다.
    func serverReason(_ code: String) -> String? {
        switch code {
        case "friend_code_unavailable", "profile_not_found":
            return t("그 친구 코드를 찾지 못했어요. 코드를 다시 확인해 주세요.",
                     "No one has that friend code. Check the code and try again.",
                     "そのフレンドコードは見つかりませんでした。コードを確認してください。",
                     "Nadie tiene ese código de amigo. Revísalo e inténtalo de nuevo.",
                     "Aucun joueur n’a ce code ami. Vérifiez-le et réessayez.",
                     "Ninguém tem esse código de amigo. Confira e tente de novo.")
        case "friend_request_already_exists":
            return t("이미 친구 요청을 보냈어요.", "You already sent a friend request.",
                     "すでにフレンド申請を送っています。", "Ya enviaste una solicitud de amistad.",
                     "Vous avez déjà envoyé une demande d’ami.", "Você já enviou um pedido de amizade.")
        case "friend_request_unavailable":
            return t("지금은 이 사람에게 친구 요청을 보낼 수 없어요.",
                     "You can’t send this player a friend request right now.",
                     "今はこのプレイヤーにフレンド申請を送れません。",
                     "Ahora no puedes enviar una solicitud a este jugador.",
                     "Impossible d’envoyer une demande à ce joueur pour le moment.",
                     "Não é possível enviar um pedido a este jogador agora.")
        case "friends_required", "friend_not_found", "friendship_not_found":
            return t("친구끼리만 할 수 있어요. 친구 목록을 새로 고친 뒤 확인해 주세요.",
                     "Only friends can do this. Refresh your friends list and check again.",
                     "フレンド同士でのみできます。フレンド一覧を更新して確認してください。",
                     "Solo los amigos pueden hacer esto. Actualiza tu lista de amigos y revísala.",
                     "Réservé aux amis. Actualisez votre liste d’amis puis vérifiez.",
                     "Só amigos podem fazer isso. Atualize a lista de amigos e confira.")
        case "collection_private", "trade_list_private":
            return t("상대가 공개하지 않은 목록이에요.", "This player keeps that list private.",
                     "相手が公開していないリストです。", "Este jugador mantiene esa lista en privado.",
                     "Ce joueur garde cette liste privée.", "Este jogador mantém essa lista privada.")
        case "insufficient_balance":
            return t("잔액이 모자라요.", "Not enough balance.", "残高が足りません。",
                     "No tienes saldo suficiente.", "Solde insuffisant.", "Saldo insuficiente.")
        case "not_enough_packs":
            return t("팩이 모자라요.", "Not enough packs.", "パックが足りません。",
                     "No tienes suficientes sobres.", "Pas assez de boosters.", "Pacotes insuficientes.")
        case "not_enough_duplicate_printings", "offered_cards_unavailable", "reserved_printing_protected":
            return t("내놓을 수 있는 카드가 모자라요. 한 장은 늘 남고, 다른 거래에 걸린 카드는 쓸 수 없어요.",
                     "Not enough spare cards. One copy always stays with you, and cards in other deals can’t be used.",
                     "出せるカードが足りません。1枚は必ず手元に残り、ほかの取引中のカードは使えません。",
                     "No tienes suficientes cartas repetidas. Siempre conservas una copia y las cartas de otros tratos no cuentan.",
                     "Pas assez de cartes en double. Un exemplaire vous reste toujours et les cartes déjà engagées ne comptent pas.",
                     "Cartas repetidas insuficientes. Uma cópia sempre fica com você e cartas em outras negociações não contam.")
        case "listing_unavailable", "listing_not_found", "listing_stock_inconsistent", "listing_reservation_inconsistent":
            return t("이미 팔렸거나 내려간 물건이에요.", "This listing was already sold or removed.",
                     "この出品はすでに売れたか、取り下げられました。", "Esta oferta ya se vendió o se retiró.",
                     "Cette annonce a déjà été vendue ou retirée.", "Este anúncio já foi vendido ou removido.")
        case "trade_unavailable", "trade_not_found":
            return t("이미 끝났거나 취소된 교환이에요.", "This trade has already ended or was cancelled.",
                     "この交換はすでに終了したか、取り消されました。", "Este intercambio ya terminó o se canceló.",
                     "Cet échange est déjà terminé ou annulé.", "Esta troca já terminou ou foi cancelada.")
        case "price_or_stock_changed", "quote_changed", "price_version_changed", "revision_conflict",
             "target_version_changed", "reserved_printings_changed", "opening_job_changed",
             "invalid_resource_state", "game_precondition_failed":
            return t("그사이 내용이 바뀌었어요. 새로 고친 뒤 다시 해 주세요.",
                     "Something changed in the meantime. Refresh and try again.",
                     "その間に内容が変わりました。更新してからもう一度お試しください。",
                     "Algo cambió mientras tanto. Actualiza e inténtalo de nuevo.",
                     "Quelque chose a changé entre-temps. Actualisez et réessayez.",
                     "Algo mudou nesse meio tempo. Atualize e tente de novo.")
        case "money_on_both_sides":
            return tradeMoneyOneSide
        case "cards_required":
            return tradeNeedsCard
        case "offered_tokens_unavailable":
            return t("제안한 쪽의 잔액이 모자라 교환할 수 없어요.",
                     "The other side no longer has the money they offered.",
                     "提案した側の残高が足りず交換できません。",
                     "La otra parte ya no tiene el dinero que ofreció.",
                     "L’autre partie n’a plus l’argent proposé.",
                     "A outra parte não tem mais o dinheiro oferecido.")
        case "offer_not_below_price":
            return t("판매가보다 낮은 값만 제안할 수 있어요. 그 값이면 바로 사 주세요.",
                     "Offer less than the asking price, or just buy it.",
                     "販売価格より低い値段だけ提案できます。その値段ならそのまま買ってください。",
                     "Ofrece menos que el precio o cómprala directamente.",
                     "Proposez moins que le prix demandé, ou achetez directement.",
                     "Ofereça menos que o preço pedido ou compre direto.")
        case "offer_too_low":
            return t("판매가의 절반 이상만 제안할 수 있어요.",
                     "Offers must be at least half the asking price.",
                     "販売価格の半分以上で提案してください。",
                     "La oferta debe ser al menos la mitad del precio.",
                     "L’offre doit valoir au moins la moitié du prix.",
                     "A oferta deve ser pelo menos metade do preço.")
        case "offer_not_accepted":
            return t("봇 매물은 정해진 값에만 팔아요.",
                     "Bot listings sell at a fixed price.",
                     "ボット出品は決まった価格でのみ販売します。",
                     "Las ventas de bot tienen precio fijo.",
                     "Les ventes du bot sont à prix fixe.",
                     "As vendas do bot têm preço fixo.")
        case "offer_not_allowed":
            return t("이 판매 글에는 제안할 수 없어요.",
                     "You can’t make an offer on this listing.",
                     "この出品には提案できません。",
                     "No puedes ofertar en esta venta.",
                     "Vous ne pouvez pas faire d’offre sur cette vente.",
                     "Você não pode fazer oferta nesta venda.")
        case "buyer_cannot_pay":
            return t("구매자의 잔액이 모자라 수락할 수 없어요.",
                     "The buyer no longer has enough money.",
                     "購入者の残高が足りず承認できません。",
                     "El comprador ya no tiene dinero suficiente.",
                     "L’acheteur n’a plus assez d’argent.",
                     "O comprador não tem mais dinheiro suficiente.")
        case "offer_unavailable", "offer_not_found", "offer_quantity_unavailable":
            return t("이미 닫혔거나 더는 채울 수 없는 제안이에요.",
                     "This offer has closed or can no longer be filled.",
                     "この提案はすでに閉じたか、応じられなくなりました。",
                     "Esta oferta ya se cerró o no se puede cumplir.",
                     "Cette offre est close ou ne peut plus être remplie.",
                     "Esta oferta foi encerrada ou não pode mais ser atendida.")
        case "rotation_limit_reached":
            return t("봇 매물은 계정마다 한 장씩만 살 수 있어요.",
                     "Each account can buy one copy of a bot listing.",
                     "ボット出品は1アカウントにつき1枚までです。",
                     "Cada cuenta puede comprar una sola copia de una venta de bot.",
                     "Chaque compte ne peut acheter qu’un exemplaire d’une vente du bot.",
                     "Cada conta pode comprar só uma cópia de uma venda do bot.")
        case "too_many_attempts":
            return t("너무 자주 시도했어요. 잠시 뒤 다시 해 주세요.", "Too many attempts. Wait a moment and try again.",
                     "試行回数が多すぎます。少し待ってからもう一度お試しください。",
                     "Demasiados intentos. Espera un momento e inténtalo de nuevo.",
                     "Trop de tentatives. Patientez un instant puis réessayez.",
                     "Tentativas demais. Aguarde um pouco e tente de novo.")
        case "nickname_required":
            return t("닉네임을 입력해 주세요.", "Enter a nickname.", "ニックネームを入力してください。",
                     "Escribe un apodo.", "Saisissez un pseudo.", "Digite um apelido.")
        case "cannot_block_self":
            return t("자기 자신은 차단할 수 없어요.", "You can’t block yourself.", "自分自身はブロックできません。",
                     "No puedes bloquearte a ti mismo.", "Vous ne pouvez pas vous bloquer.", "Você não pode bloquear a si mesmo.")
        case "duplicate_wish":
            return t("이미 위시리스트에 있어요.", "Already on your wishlist.", "すでにウィッシュリストにあります。",
                     "Ya está en tu lista de deseos.", "Déjà dans votre liste de souhaits.", "Já está na sua lista de desejos.")
        case "binder_requires_owned_printing":
            return t("가지고 있는 카드만 바인더에 넣을 수 있어요.", "Only cards you own can go in your binder.",
                     "持っているカードだけをバインダーに入れられます。",
                     "Solo puedes poner en la carpeta cartas que tienes.",
                     "Seules vos cartes peuvent aller dans le classeur.",
                     "Só cartas que você tem podem ir para o fichário.")
        case "purchase_not_allowed", "seller_required", "sender_required", "recipient_required":
            return t("이 거래에서는 할 수 없는 동작이에요.", "You can’t do that in this deal.",
                     "この取引ではその操作はできません。", "No puedes hacer eso en este trato.",
                     "Action impossible dans cette transaction.", "Você não pode fazer isso nesta negociação.")
        case "retry_same_request", "database_unavailable_retry_same_request",
             "database_migration_or_rules_not_ready", "rules_engine_failed", "rules_engine_invalid_output",
             "rules_engine_timeout", "rules_engine_unavailable", "rules_data_unavailable", "prices_unavailable":
            return t("서버가 잠시 바빠요. 조금 뒤 다시 시도해 주세요.",
                     "The server is busy right now. Try again in a moment.",
                     "サーバーが混み合っています。少し待ってからもう一度お試しください。",
                     "El servidor está ocupado. Inténtalo de nuevo en un momento.",
                     "Le serveur est occupé. Réessayez dans un instant.",
                     "O servidor está ocupado. Tente de novo em instantes.")
        default:
            return nil
        }
    }

    /// 화면에 그대로 올리기 어려운 실패(응답 해석 실패 등)를 대신할 한 줄.
    var unexpectedProblem: String {
        t("뜻밖의 문제가 생겼어요. 잠시 뒤 다시 시도해 주세요.",
          "Something unexpected went wrong. Try again in a moment.",
          "予期しない問題が起きました。少し待ってからもう一度お試しください。",
          "Ocurrió un problema inesperado. Inténtalo de nuevo en un momento.",
          "Un problème inattendu est survenu. Réessayez dans un instant.",
          "Algo inesperado deu errado. Tente de novo em instantes.")
    }
}

// MARK: 로컬 실패

extension L {
    var saveInvalid: String {
        t("저장 파일을 읽지 못했어요. 원래 파일은 그대로 두었어요.",
          "Couldn’t read the save file. The original file was kept as is.",
          "セーブファイルを読めませんでした。元のファイルはそのまま残しています。",
          "No se pudo leer el archivo de guardado. El original se conservó tal cual.",
          "Impossible de lire la sauvegarde. Le fichier d’origine est conservé.",
          "Não foi possível ler o salvamento. O arquivo original foi mantido.")
    }
    var saveUnrecoverable: String {
        t("저장 파일도 백업도 읽지 못해서, 원본을 지키려고 저장을 멈췄어요. 설정의 데이터 탭에서 백업 폴더를 열 수 있어요.",
          "Neither the save nor a backup could be read, so saving is paused to protect the original. Open the backup folder from Settings > Data.",
          "セーブもバックアップも読めないため、元データを守るために保存を止めています。設定のデータタブからバックアップフォルダを開けます。",
          "No se pudo leer ni el guardado ni una copia, así que se pausó el guardado para proteger el original. Abre la carpeta de copias en Ajustes > Datos.",
          "Ni la sauvegarde ni une copie ne sont lisibles : l’enregistrement est suspendu pour protéger l’original. Ouvrez le dossier des copies dans Réglages > Données.",
          "Nem o salvamento nem um backup puderam ser lidos, então salvar foi pausado para proteger o original. Abra a pasta de backups em Ajustes > Dados.")
    }
    var saveNewerVersion: String {
        t("더 새 버전의 앱이 만든 저장 파일이에요. 덮어쓰지 않도록 저장을 멈췄어요. 앱을 업데이트해 주세요.",
          "This save was made by a newer version of the app. Saving is paused so it isn’t overwritten. Please update the app.",
          "新しいバージョンのアプリで作られたセーブです。上書きしないよう保存を止めています。アプリを更新してください。",
          "Este guardado es de una versión más nueva de la app. Se pausó el guardado para no sobrescribirlo. Actualiza la app.",
          "Cette sauvegarde vient d’une version plus récente. L’enregistrement est suspendu pour ne pas l’écraser. Mettez l’app à jour.",
          "Este salvamento é de uma versão mais nova do app. Salvar foi pausado para não sobrescrevê-lo. Atualize o app.")
    }
    var priceSnapshotInvalid: String {
        t("시세 파일 형식이 맞지 않아요. 쓰던 시세를 그대로 두었어요.",
          "The price file isn’t in the expected format. The current prices were kept.",
          "相場ファイルの形式が正しくありません。今の相場をそのまま使います。",
          "El archivo de precios no tiene el formato esperado. Se conservaron los precios actuales.",
          "Le fichier de prix n’a pas le format attendu. Les prix actuels sont conservés.",
          "O arquivo de preços não está no formato esperado. Os preços atuais foram mantidos.")
    }
    var packCatalogueIncomplete: String {
        t("팩 구성 정보를 다 읽지 못해서 열지 않았어요. 팩은 그대로예요.",
          "The pack’s card list couldn’t be read completely, so it wasn’t opened. Your packs are untouched.",
          "パックの構成を読み切れなかったため開けませんでした。パックはそのままです。",
          "No se pudo leer toda la lista de cartas del sobre, así que no se abrió. Tus sobres siguen intactos.",
          "La liste des cartes du booster est incomplète : il n’a pas été ouvert. Vos boosters sont intacts.",
          "A lista de cartas do pacote não pôde ser lida por completo, então ele não foi aberto. Seus pacotes estão intactos.")
    }
    var openingStateChanged: String {
        t("여는 동안 컬렉션이나 개봉 설정이 바뀌어서 열지 않았어요. 팩은 그대로예요. 다시 열어 주세요.",
          "Your collection or opening settings changed while opening, so nothing was opened. Your packs are untouched; try again.",
          "開けている間にコレクションか開封設定が変わったため、開けませんでした。パックはそのままです。もう一度開けてください。",
          "Tu colección o los ajustes de apertura cambiaron mientras se abría, así que no se abrió nada. Tus sobres siguen intactos; inténtalo de nuevo.",
          "Votre collection ou vos réglages d’ouverture ont changé pendant l’ouverture : rien n’a été ouvert. Vos boosters sont intacts, réessayez.",
          "Sua coleção ou os ajustes de abertura mudaram durante a abertura, então nada foi aberto. Seus pacotes estão intactos; tente de novo.")
    }
    var problemDiskFull: String {
        t("디스크 공간이 모자라 저장하지 못했어요. 공간을 비운 뒤 다시 시도해 주세요.",
          "Not enough disk space to save. Free up some space and try again.",
          "ディスクの空き容量が足りず保存できませんでした。空きを作ってからもう一度お試しください。",
          "No hay espacio en disco para guardar. Libera espacio e inténtalo de nuevo.",
          "Espace disque insuffisant pour enregistrer. Libérez de l’espace et réessayez.",
          "Sem espaço em disco para salvar. Libere espaço e tente de novo.")
    }
    var problemNoPermission: String {
        t("이 위치에 읽거나 쓸 권한이 없어요. 다른 위치를 골라 주세요.",
          "No permission to read or write here. Choose another location.",
          "この場所を読み書きする権限がありません。別の場所を選んでください。",
          "No hay permiso para leer o escribir aquí. Elige otra ubicación.",
          "Pas d’autorisation de lecture ou d’écriture ici. Choisissez un autre emplacement.",
          "Sem permissão para ler ou gravar aqui. Escolha outro local.")
    }
    var problemFileMissing: String {
        t("파일을 찾지 못했어요. 옮겨졌거나 지워졌을 수 있어요.",
          "The file wasn’t found. It may have been moved or deleted.",
          "ファイルが見つかりませんでした。移動されたか削除された可能性があります。",
          "No se encontró el archivo. Puede que se haya movido o eliminado.",
          "Fichier introuvable. Il a peut-être été déplacé ou supprimé.",
          "O arquivo não foi encontrado. Ele pode ter sido movido ou apagado.")
    }
    var problemFileUnreadable: String {
        t("파일을 읽지 못했어요. 손상됐거나 이 앱의 파일이 아닐 수 있어요.",
          "The file couldn’t be read. It may be damaged or not a file from this app.",
          "ファイルを読めませんでした。破損しているか、このアプリのファイルではない可能性があります。",
          "No se pudo leer el archivo. Puede estar dañado o no ser de esta app.",
          "Impossible de lire le fichier. Il est peut-être endommagé ou ne vient pas de cette app.",
          "Não foi possível ler o arquivo. Ele pode estar danificado ou não ser deste app.")
    }
}
