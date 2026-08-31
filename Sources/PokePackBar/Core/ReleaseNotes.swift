import Foundation

/// 한 판올림에서 바뀐 것.
struct ReleaseNote: Identifiable, Sendable, Equatable {
    let version: String
    let items: [String]
    var id: String { version }
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
            ReleaseNote(version: "0.3.3", items: [
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
            ReleaseNote(version: "0.3.2", items: [
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
            ReleaseNote(version: "0.3.1", items: [
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
            ReleaseNote(version: "0.3.0", items: [
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
