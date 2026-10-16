import Foundation

// MARK: 교환에 돈 얹기

extension L {
    var moneyToGive: String {
        t("얹어 줄 돈", "Money I add", "追加で払う金額", "Dinero que añado", "Argent que j’ajoute", "Dinheiro que adiciono")
    }
    var moneyToGet: String {
        t("받을 돈", "Money I ask for", "受け取る金額", "Dinero que pido", "Argent demandé", "Dinheiro que peço")
    }
    /// 교환 한쪽의 돈 한 줄. 카드 줄 아래에 붙는다.
    func moneyLine(_ amount: String) -> String {
        t("돈 \(amount)", "Money \(amount)", "金額 \(amount)", "Dinero \(amount)", "Argent \(amount)", "Dinheiro \(amount)")
    }
    var tradeMoneyOneSide: String {
        t("돈은 한쪽에만 넣을 수 있어요.", "Add money to one side only.", "お金は片方にだけ入れられます。",
          "Solo puedes añadir dinero a un lado.", "Ajoutez de l’argent d’un seul côté.", "Adicione dinheiro em um só lado.")
    }
    var tradeNeedsCard: String {
        t("카드를 한 장 이상 담으세요. 돈만 주고받을 수는 없어요.",
          "Add at least one card. A trade can’t be money only.",
          "カードを1枚以上入れてください。お金だけの交換はできません。",
          "Añade al menos una carta. Un intercambio no puede ser solo dinero.",
          "Ajoutez au moins une carte. Un échange ne peut pas être que de l’argent.",
          "Adicione ao menos uma carta. Uma troca não pode ser só dinheiro.")
    }
    var tradeMoneyInvalid: String {
        t("돈은 100원 이상으로 넣어 주세요.", "Enter at least ₩100.", "金額は100円以上にしてください。",
          "Introduce al menos ₩100.", "Saisissez au moins 100 ₩.", "Digite pelo menos ₩100.")
    }
}

// MARK: 마켓 가격 제안

extension L {
    var listingDetailTitle: String { t("판매 글", "Listing", "出品", "Anuncio", "Annonce", "Anúncio") }
    var sentOffers: String { t("보낸 제안", "My offers", "送った提案", "Mis ofertas", "Mes offres", "Minhas ofertas") }
    var buyNow: String { t("바로 사기", "Buy now", "今すぐ買う", "Comprar ya", "Acheter", "Comprar agora") }
    var makeOffer: String { t("가격 제안", "Make an offer", "価格を提案", "Hacer oferta", "Faire une offre", "Fazer oferta") }
    var makeOfferTitle: String {
        t("가격 제안하기", "Make an offer", "価格を提案する", "Hacer una oferta", "Faire une offre", "Fazer uma oferta")
    }
    func sendOffer(_ price: String) -> String {
        t("장당 \(price)에 제안하기", "Offer \(price) each", "1枚 \(price)で提案", "Ofrecer \(price) c/u",
          "Proposer \(price) l’unité", "Oferecer \(price) cada")
    }
    var offerNote: String {
        t("판매자가 수락하면 그 값에 사요. 48시간 안에 답이 없거나 판매가 끝나면 제안은 닫혀요. 같은 카드에 다시 보내면 앞의 제안을 바꿔요.",
          "If the seller accepts, you buy at that price. The offer closes after 48 hours without a reply or when the listing ends. Sending another replaces it.",
          "出品者が承認すると、その価格で購入します。48時間返事がないか出品が終わると提案は閉じます。同じカードに送り直すと前の提案を置き換えます。",
          "Si el vendedor acepta, compras a ese precio. La oferta se cierra a las 48 horas sin respuesta o al terminar la venta. Si envías otra, reemplaza la anterior.",
          "Si le vendeur accepte, vous achetez à ce prix. L’offre se ferme après 48 heures sans réponse ou à la fin de la vente. En envoyer une autre remplace la précédente.",
          "Se o vendedor aceitar, você compra por esse preço. A oferta fecha após 48 horas sem resposta ou quando a venda termina. Enviar outra substitui a anterior.")
    }
    /// 보낼 수 있는 값의 범위. 판매가보다 낮고, 판매가의 절반 이상이다.
    func offerRange(min: String, max: String) -> String {
        t("\(min) 이상, \(max) 이하로 보낼 수 있어요", "Between \(min) and \(max)", "\(min)以上\(max)以下で送れます",
          "Entre \(min) y \(max)", "Entre \(min) et \(max)", "Entre \(min) e \(max)")
    }
    func percentOfPrice(_ percent: Int) -> String {
        t("판매가의 \(percent)%", "\(percent)% of price", "販売価格の\(percent)%", "\(percent) % del precio",
          "\(percent) % du prix", "\(percent)% do preço")
    }
    /// 이미 보낸 제안이 있을 때 판매 글과 구매 창에 적는다.
    func myOffer(_ price: String) -> String {
        t("제안 중, 장당 \(price)", "Offered \(price) each", "提案中、1枚 \(price)", "Ofertado \(price) c/u",
          "Offre \(price) l’unité", "Oferta de \(price) cada")
    }
    /// 카드 칸 한 줄에 들어가는 짧은 꼴.
    func myOfferShort(_ price: String) -> String {
        t("제안 \(price)", "Offer \(price)", "提案 \(price)", "Oferta \(price)", "Offre \(price)", "Oferta \(price)")
    }
    var offerAccepted: String { t("수락됨", "Accepted", "承認済み", "Aceptada", "Acceptée", "Aceita") }
    func offersReceived(_ count: Int) -> String {
        t("받은 제안 \(count)개", count == 1 ? "1 offer" : "\(count) offers", "届いた提案 \(count)件",
          count == 1 ? "1 oferta" : "\(count) ofertas", count == 1 ? "1 offre" : "\(count) offres",
          count == 1 ? "1 oferta" : "\(count) ofertas")
    }
    /// 받은 제안 한 줄: 누가, 몇 장, 장당 얼마, 판매가의 몇 %.
    func offerRow(_ name: String, quantity: Int, price: String, percent: Int) -> String {
        t("\(name), \(quantity)장, 장당 \(price) (판매가의 \(percent)%)",
          "\(name), \(quantity) × \(price) (\(percent)% of price)",
          "\(name)、\(quantity)枚、1枚 \(price)（販売価格の\(percent)%）",
          "\(name), \(quantity) × \(price) (\(percent) % del precio)",
          "\(name), \(quantity) × \(price) (\(percent) % du prix)",
          "\(name), \(quantity) × \(price) (\(percent)% do preço)")
    }
    var acceptOfferTitle: String {
        t("제안을 수락할까요?", "Accept this offer?", "この提案を承認しますか？", "¿Aceptar esta oferta?",
          "Accepter cette offre ?", "Aceitar esta oferta?")
    }
    func acceptOfferNote(quantity: Int, price: String, total: String) -> String {
        t("\(quantity)장을 장당 \(price)에 팔아 \(total)을 받아요. 되돌릴 수 없어요.",
          "You sell \(quantity) at \(price) each and get \(total). This can’t be undone.",
          "\(quantity)枚を1枚 \(price)で売り、\(total)を受け取ります。取り消せません。",
          "Vendes \(quantity) a \(price) c/u y recibes \(total). No se puede deshacer.",
          "Vous vendez \(quantity) à \(price) l’unité et recevez \(total). C’est définitif.",
          "Você vende \(quantity) a \(price) cada e recebe \(total). Não dá para desfazer.")
    }
    var noSentOffers: String {
        t("보낸 제안이 없어요", "No offers sent", "送った提案はありません", "No has enviado ofertas",
          "Aucune offre envoyée", "Nenhuma oferta enviada")
    }
    var noSentOffersHint: String {
        t("「사기」에서 트레이너 매물을 눌러 가격을 제안해 보세요.",
          "Open a trainer listing in Buy to make an offer.",
          "「買う」でトレーナーの出品を開くと価格を提案できます。",
          "Abre una venta de entrenador en Comprar para hacer una oferta.",
          "Ouvrez une vente de dresseur dans Acheter pour faire une offre.",
          "Abra uma venda de treinador em Comprar para fazer uma oferta.")
    }
    /// `count` 는 `cardsCount` 로 만든 장수다. 언어마다 한 장과 여러 장의 꼴이 다르다.
    func sentOfferLine(price: String, asking: String, count: String) -> String {
        t("장당 \(price) 제안, 판매가 \(asking), \(count)",
          "Offered \(price) each, asking \(asking), \(count)",
          "1枚 \(price)で提案、販売価格 \(asking)、\(count)",
          "Ofertaste \(price) c/u, pide \(asking), \(count)",
          "Offre \(price) l’unité, prix \(asking), \(count)",
          "Oferta de \(price) cada, pede \(asking), \(count)")
    }

    // 알림

    var noteOfferReceived: String {
        t("가격 제안이 왔어요", "New price offer", "価格の提案が届きました", "Nueva oferta de precio",
          "Nouvelle offre de prix", "Nova oferta de preço")
    }
    var noteOfferAccepted: String {
        t("가격 제안이 수락됐어요", "Your offer was accepted", "提案が承認されました", "Aceptaron tu oferta",
          "Votre offre a été acceptée", "Sua oferta foi aceita")
    }
    var noteOfferRejected: String {
        t("가격 제안이 거절됐어요", "Your offer was declined", "提案が断られました", "Rechazaron tu oferta",
          "Votre offre a été refusée", "Sua oferta foi recusada")
    }
    var noteOfferExpired: String {
        t("가격 제안이 닫혔어요", "Your offer closed", "提案が締め切られました", "Tu oferta se cerró",
          "Votre offre est close", "Sua oferta foi encerrada")
    }
    func noteOfferReceivedCard(_ name: String, card: String, price: String) -> String {
        t("\(name)님이 \(card)에 장당 \(price)을 제안했어요", "\(name) offered \(price) each for \(card)",
          "\(name)さんが\(card)に1枚 \(price)を提案しました", "\(name) ofreció \(price) c/u por \(card)",
          "\(name) propose \(price) l’unité pour \(card)", "\(name) ofereceu \(price) cada por \(card)")
    }
    func noteOfferAcceptedCard(_ name: String, card: String, price: String) -> String {
        t("\(name)님이 \(card) 제안을 수락했어요 (장당 \(price))", "\(name) accepted your offer for \(card) (\(price) each)",
          "\(name)さんが\(card)の提案を承認しました（1枚 \(price)）",
          "\(name) aceptó tu oferta por \(card) (\(price) c/u)",
          "\(name) a accepté votre offre pour \(card) (\(price) l’unité)",
          "\(name) aceitou sua oferta por \(card) (\(price) cada)")
    }
    func noteOfferRejectedCard(_ name: String, card: String) -> String {
        t("\(name)님이 \(card) 제안을 거절했어요", "\(name) declined your offer for \(card)",
          "\(name)さんが\(card)の提案を断りました", "\(name) rechazó tu oferta por \(card)",
          "\(name) a refusé votre offre pour \(card)", "\(name) recusou sua oferta por \(card)")
    }
    func noteOfferExpiredCard(_ card: String) -> String {
        t("\(card) 가격 제안이 닫혔어요", "Your offer for \(card) closed", "\(card)の提案が締め切られました",
          "Se cerró tu oferta por \(card)", "Votre offre pour \(card) est close", "Sua oferta por \(card) foi encerrada")
    }
}
