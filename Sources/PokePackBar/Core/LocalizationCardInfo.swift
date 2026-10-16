import Foundation

// MARK: 카드 상세의 출처와 마켓

extension L {
    var pullChanceLabel: String {
        t("뽑힐 확률", "Pull rate", "排出率", "Probabilidad", "Taux de tirage", "Chance")
    }
    func pullOneIn(_ packs: String) -> String {
        t("약 \(packs)팩에 1장", "About 1 in \(packs) packs", "約\(packs)パックに1枚",
          "Aprox. 1 de cada \(packs) sobres", "Environ 1 booster sur \(packs)", "Cerca de 1 a cada \(packs) pacotes")
    }
    var pullEveryPack: String {
        t("팩마다 1장 넘게", "More than 1 per pack", "1パックに1枚以上", "Más de 1 por sobre",
          "Plus d’1 par booster", "Mais de 1 por pacote")
    }
    /// 마켓 줄 이름. 영어는 「시세(Market)」와 겹치지 않게 판매 글이라 적는다.
    var cardListingsLabel: String {
        t("마켓", "Listings", "出品", "Anuncios", "Annonces", "Anúncios")
    }
    /// 이 카드의 판매 글 수와 가장 싼 값. 100건을 넘으면 그 이상이라고만 적는다.
    func cardListings(_ count: Int, more: Bool, lowest: String) -> String {
        t(more ? "매물 \(count)건 넘게, 최저 \(lowest)" : "매물 \(count)건, 최저 \(lowest)",
          "\(count)\(more ? "+" : "") for sale, from \(lowest)",
          "出品\(count)件\(more ? "以上" : "")、最安\(lowest)",
          "\(count)\(more ? "+" : "") en venta, desde \(lowest)",
          "\(count)\(more ? "+" : "") en vente, dès \(lowest)",
          "\(count)\(more ? "+" : "") à venda, a partir de \(lowest)")
    }
    var cardNoListings: String {
        t("지금은 매물이 없어요", "None for sale right now", "現在出品なし", "Nada en venta ahora",
          "Rien en vente pour l’instant", "Nada à venda agora")
    }
    var cardListingsLoading: String {
        t("매물 확인 중", "Checking listings", "出品を確認中", "Buscando anuncios",
          "Recherche d’annonces", "Verificando anúncios")
    }
    var cardListingsUnavailable: String {
        t("매물을 불러오지 못했어요", "Couldn’t load listings", "出品を読み込めませんでした",
          "No se pudieron cargar los anuncios", "Annonces indisponibles", "Não foi possível carregar os anúncios")
    }
    var cardSeeListingsHelp: String {
        t("온라인 마켓에서 이 카드의 판매 글을 봐요.", "See this card’s listings in the online market.",
          "オンラインマーケットでこのカードの出品を見ます。", "Ver los anuncios de esta carta en el mercado en línea.",
          "Voir les annonces de cette carte au marché en ligne.", "Ver os anúncios desta carta no mercado online.")
    }
    var wishlistAddHelp: String {
        t("위시리스트에 넣으면 마켓에 올라올 때 알려 드려요.", "Add to your wishlist to get an alert when it’s listed.",
          "ウィッシュリストに入れると出品されたときに通知します。",
          "Añádela a tu lista de deseos y te avisaremos cuando se ponga a la venta.",
          "Ajoutez-la à votre liste d’envies pour être alerté quand elle est mise en vente.",
          "Adicione à lista de desejos para ser avisado quando for anunciada.")
    }
    var wishlistRemoveHelp: String {
        t("위시리스트에서 빼기", "Remove from wishlist", "ウィッシュリストから外す", "Quitar de la lista de deseos",
          "Retirer de la liste d’envies", "Remover da lista de desejos")
    }
}
