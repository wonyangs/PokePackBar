import Foundation

/// 판올림 항목 하나. 아래에 딸린 세부가 있을 수 있다.
///
/// 큰 개편은 제목 한 줄로는 무엇이 바뀌었는지 알 수 없고, 세부를 같은 층에 늘어놓으면
/// 열 줄이 평평하게 이어져 어디까지가 한 덩이인지 읽히지 않는다.
struct ReleaseNoteItem: Sendable, Equatable {
    let text: String
    var details: [String] = []

    /// 제목과 세부를 합친 전체 문구. 번역 누락 검사가 한 줄씩 훑을 때 쓴다.
    var lines: [String] { [text] + details }
}

/// 한 판올림에서 바뀐 것.
struct ReleaseNote: Identifiable, Sendable, Equatable {
    let version: String
    let items: [ReleaseNoteItem]
    var id: String { version }

    init(version: String, items: [ReleaseNoteItem]) {
        self.version = version
        self.items = items
    }

    /// 세부가 없는 목록. 예전 판올림은 전부 이 모양이다.
    init(version: String, lines: [String]) {
        self.init(version: version, items: lines.map { ReleaseNoteItem(text: $0) })
    }
}

/// 판올림 기록. 새 버전을 내기 전에 여기에 먼저 적는다 —
/// `ReleaseNotesTests` 가 배포 버전에 해당하는 항목이 없으면 실패시킨다.
///
/// 문구는 `L` 이 들고 있어 언어를 따라간다. 목록은 최신이 앞이다.
enum ReleaseNotes {
    /// 지금 돌고 있는 앱의 버전. 없으면 nil — 개발 빌드나 테스트 러너가 그렇다.
    static var runningVersion: String? {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
    }

    /// 버전을 숫자 묶음으로 바꾼다. 문자열 비교로는 0.3.10 이 0.3.2 보다 앞이 된다.
    static func ordering(_ version: String) -> [Int] {
        version.split(separator: ".").map { Int($0) ?? 0 }
    }

    /// 최신이 앞인가. 뒤엣것이 앞엣것보다 반드시 작아야 한다.
    static func isDescending(_ notes: [ReleaseNote]) -> Bool {
        zip(notes, notes.dropFirst()).allSatisfy {
            ordering($1.version).lexicographicallyPrecedes(ordering($0.version))
        }
    }
}

extension L {

    var releaseNotes: [ReleaseNote] {
        [
            ReleaseNote(version: "0.4.0", items: [
                ReleaseNoteItem(text: t("시세 연동 대개편",
                                         "Market prices, everywhere",
                                         "相場連動の大改編",
                                         "Precios de mercado en todo",
                                         "Prix du marché partout",
                                         "Preços de mercado em tudo"), details: [
                    t("실제 카드 시세가 카드에 표시됨",
                      "Every card shows its real market price",
                      "カードに実際の相場を表示",
                      "Cada carta muestra su precio real de mercado",
                      "Chaque carte affiche son prix réel du marché",
                      "Cada carta mostra seu preço real de mercado"),
                    t("실제 카드 팩 가격에 맞게 반영",
                      "Pack prices follow the real market",
                      "パック価格を実際の相場に合わせた",
                      "El precio de los sobres sigue el mercado real",
                      "Le prix des boosters suit le marché réel",
                      "O preço dos pacotes segue o mercado real"),
                    t("거래 단위가 토큰 → 원화로 변경",
                      "Prices are shown in won, not tokens",
                      "取引単位をトークンからウォンに変更",
                      "Los precios se muestran en wones, no en tokens",
                      "Les prix sont affichés en wons, plus en tokens",
                      "Os preços aparecem em wones, não em tokens"),
                    t("컬렉션 총 가치 표기",
                      "Your collection's total value in the header",
                      "コレクションの総価値を表示",
                      "Valor total de tu colección en la cabecera",
                      "Valeur totale de ta collection dans l'en-tête",
                      "Valor total da sua coleção no topo"),
                    t("컬렉션 정렬을 카드 가치 순으로 변경",
                      "The collection is sorted by card value",
                      "コレクションをカード価値順に並べ替え",
                      "La colección se ordena por valor de carta",
                      "La collection est triée par valeur de carte",
                      "A coleção é ordenada por valor da carta"),
                    t("도감 난이도는 카드 가치 기준으로 재산정",
                      "Dex difficulty is recalculated from card value",
                      "図鑑の難易度をカード価値基準に再計算",
                      "La dificultad del dex se recalcula por valor de carta",
                      "La difficulté des dex est recalculée par valeur de carte",
                      "A dificuldade do dex é recalculada por valor da carta"),
                ]),
                ReleaseNoteItem(text: t("카드 뽑기 시 카드명과 시세가 함께 표기되도록 UI 추가",
                                         "Opening a pack now shows each card's name and price",
                                         "開封中にカード名と相場を一緒に表示",
                                         "Al abrir un sobre se ve el nombre y el precio de cada carta",
                                         "À l'ouverture, le nom et le prix de chaque carte s'affichent",
                                         "Ao abrir, aparecem o nome e o preço de cada carta"), details: [
                    t("뽑기 완료 시 해당 뽑기에서 나온 카드의 총 가치 표시",
                      "The summary adds up what the pack was worth",
                      "開封結果にそのパックの総価値を表示",
                      "El resumen suma cuánto valía el sobre",
                      "Le résumé additionne la valeur du booster",
                      "O resumo soma quanto o pacote valia"),
                ]),
                ReleaseNoteItem(text: t("컬렉션에서 보유한 카드만 보기 ON/OFF 기능 추가",
                                         "Collection: show only the cards you own, on or off",
                                         "コレクションに「所持カードのみ」の切り替えを追加",
                                         "Colección: mostrar solo tus cartas, activable",
                                         "Collection : n'afficher que tes cartes, activable",
                                         "Coleção: mostrar só suas cartas, com liga/desliga")),
                ReleaseNoteItem(text: t("전반적인 앱 UI 개편",
                                         "The whole interface has been reworked",
                                         "アプリ全体の UI を刷新",
                                         "Toda la interfaz ha sido rediseñada",
                                         "Toute l'interface a été revue",
                                         "Toda a interface foi reformulada")),
            ]),
            ReleaseNote(version: "0.3.3", lines: [
                t("카드깡 시 뒤에 카드 보이도록 UI 수정",
                  "The next card now sits under the one in your hand",
                  "次のカードが手にしているカードの下に見えるように",
                  "La siguiente carta ahora asoma bajo la que tienes",
                  "La carte suivante apparaît sous celle que tu tiens",
                  "A próxima carta agora aparece sob a que você segura"),
                t("오리파 카드깡 시 확인 문구 추가, 가림막 추가",
                  "Oripa asks before drawing, and the card comes out under a cover",
                  "オリパは引く前に確認し、カードは覆いの下から出てくる",
                  "El oripa pregunta antes de tirar y la carta sale bajo una tapa",
                  "L'oripa demande avant de tirer, et la carte sort sous un cache",
                  "O oripa pergunta antes de tirar, e a carta sai sob uma capa"),
                t("카드깡 시 카드 크기가 기존보다 20% 더 커짐",
                  "Cards are about 20% bigger while you open",
                  "開封中のカードが約20%大きく",
                  "Las cartas son un 20% más grandes al abrir",
                  "Les cartes sont environ 20% plus grandes à l'ouverture",
                  "As cartas ficam cerca de 20% maiores na abertura"),
            ]),
            ReleaseNote(version: "0.3.2", lines: [
                t("카드명 한글화",
                  "Korean card names",
                  "カード名を韓国語表記に",
                  "Nombres de cartas en coreano",
                  "Noms de cartes en coréen",
                  "Nomes das cartas em coreano"),
                t("앱에 패치 노트 추가",
                  "Release notes now live in the app",
                  "アプリに更新履歴を追加",
                  "Notas de versión dentro de la app",
                  "Notes de version dans l'app",
                  "Notas de versão dentro do app"),
                t("메뉴바 아이콘이 내 카드로 바뀜 (최애 카드 지정 가능)",
                  "The menu bar icon is now your card — pick a favourite",
                  "メニューバーのアイコンが自分のカードに（お気に入り指定可）",
                  "El icono de la barra de menús ahora es tu carta (elige favorita)",
                  "L'icône de la barre de menus est ta carte (choisis ta favorite)",
                  "O ícone da barra de menus agora é a sua carta (escolha a favorita)"),
                t("카드깡 방식 변경",
                  "Reworked how packs are built",
                  "パックの構成を変更",
                  "Nueva composición de los sobres",
                  "Composition des boosters revue",
                  "Nova composição dos pacotes"),
                t("오리파 뽑기 UI 개선",
                  "Better oripa draw screen",
                  "オリパの抽選画面を改善",
                  "Pantalla de tirada de oripa mejorada",
                  "Écran de tirage oripa amélioré",
                  "Tela de sorteio do oripa melhorada"),
            ]),
            ReleaseNote(version: "0.3.1", lines: [
                t("오리파 뽑기 시 효과 부족한 부분 수정",
                  "Added the missing oripa draw animation",
                  "オリパ抽選時の演出不足を修正",
                  "Se añadió la animación que faltaba al tirar oripa",
                  "Ajout de l'animation manquante au tirage oripa",
                  "Adicionada a animação que faltava no sorteio do oripa"),
                t("업데이트 확인이 느린 현상 수정",
                  "Fixed slow update checks",
                  "アップデート確認が遅い問題を修正",
                  "Se corrigió la lentitud al buscar actualizaciones",
                  "Correction de la lenteur des vérifications de mise à jour",
                  "Corrigida a lentidão na verificação de atualizações"),
            ]),
            ReleaseNote(version: "0.3.0", lines: [
                t("갓팩 추가 (1/300 확률로 갓-팩이 등장)",
                  "God Pack added — 1 in 300 packs",
                  "ゴッドパックを追加（1/300で出現）",
                  "Sobre divino añadido: 1 de cada 300",
                  "God Pack ajouté — 1 booster sur 300",
                  "God Pack adicionado — 1 a cada 300 pacotes"),
                t("오리파 추가",
                  "Oripa added",
                  "オリパを追加",
                  "Oripa añadido",
                  "Oripa ajouté",
                  "Oripa adicionado"),
                t("도감이 난이도순으로 정렬",
                  "Dex now sorts by difficulty",
                  "図鑑を難易度順に並べ替え",
                  "El dex ahora se ordena por dificultad",
                  "Le dex se trie désormais par difficulté",
                  "A dex agora ordena por dificuldade"),
                t("토큰수 표기 편의성 개선 (억/만 단위 추가)",
                  "Token counts are easier to read",
                  "トークン表記を読みやすく（億・万単位）",
                  "Las cifras de tokens se leen mejor",
                  "Les nombres de tokens sont plus lisibles",
                  "Contagens de tokens mais legíveis"),
                t("잔버그 수정",
                  "Minor bug fixes",
                  "細かな不具合を修正",
                  "Correcciones menores",
                  "Corrections mineures",
                  "Correções menores"),
            ]),
        ]
    }
}
