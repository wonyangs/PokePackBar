#!/usr/bin/env python3
"""Refresh the numbers and rewards in Resources/dex.json.

The difficulty of a dex comes from pack odds and prices. When either changes,
the stored medianPacks / medianTokens / valueUSD / tier silently go stale. The
app measures them with its own math; this script only writes them back and
derives the rewards from them.

    swift build
    PPB_OFFLINE=1 .build/out/Products/Debug/PokePackBar --dex-metrics > /tmp/dex-metrics.json
    python3 scripts/rebuild_dex.py /tmp/dex-metrics.json

Run without a metrics file first when a set has no dex yet: it adds the
hand-written dexes below with placeholder numbers, so the next build can
measure them.

Reward rules (BundledDexTests holds them):
- Set milestones pay 5% of what reaching them costs: the first in tokens, the
  second 40% in half-price coupons for the set, the third 50% as a card grant
  and 40% in coupons. Tokens fill the rest.
- Theme rewards keep their shape. Reward packs never exceed 45% of the cost
  (plus half a pack for rounding) or 15 packs, and card grants follow the cost.
- Every theme's one-time reward is at least its tier's share of the cost:
  packs for tier 1-3, a card grant and coupons for tier 4-5. A theme with no
  pack, token, coupon or card reward gets that shape. The shares are 1.5 times
  the older hand-tuned medians, raised when perks moved to tier-5 themes.
- Permanent perks go only to tier-5 themes and the ladder. Spread over all 223
  themes, two in three gave under 0.1%. The four kinds alternate by cost, each
  value grows with the log of the cost (a costlier dex never gives less), and
  each kind's budget below is kept, so the caps hold.
- The ladder has fixed steps; each step's perks grow linearly up the ladder
  within the ladder budget. The last step opens when every dex is complete.
"""

import json
import math
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DEX = ROOT / "Sources/PokePackBar/Resources/dex.json"
INDEX = ROOT / "Sources/PokePackBar/Resources/card-index.json"

TOKENS_PER_USD = 292_000
SET_TARGET = 0.05
THEME_TARGET = 0.45
MAX_REWARD_PACKS = 15
FRACTIONS = (0.5, 0.75, 0.9)

# Hand-written dexes for sets that arrived after the last rebuild, and for the
# subsets (Trainer Gallery, Shiny Vault, Galarian Gallery, Classic Collection)
# that open from their parent set's packs. Cards are listed by number in the
# keyed set, or by full card ID when they come from a subset or another set.
# The script sorts them by rarity as the dex view expects.
ADDITIONS = {
    "me2pt5": [
        ("me2pt5-regi-trio", "레지 삼총사", "The Regi Trio",
         "얼음, 바위, 강철. 세 거인이 한 세트에 ex 로 모였다.",
         "Ice, rock and steel. The three giants share one set as ex.",
         ["48", "107", "145"]),
        ("me2pt5-mega-dragonite", "메가망나뇽 세 장", "Mega Dragonite Three Ways",
         "메가어택, 스페셜아트, 메가 하이퍼레어. 같은 망나뇽의 세 판본이라 마지막 한 장이 늘 제일 멀다.",
         "Mega Attack, special art and Mega Hyper Rare. One Dragonite in three printings, and the last one is always the farthest.",
         ["271", "290", "295"]),
        ("me2pt5-mega-starters", "메가로 돌아온 스타터 넷", "Four Starters Gone Mega",
         "세 세대의 스타터 넷이 메가진화 ex 로 돌아왔다. 성도에서 둘, 관동과 하나에서 하나씩이다.",
         "Four starters from three generations return as Mega ex: two from Johto, one each from Kanto and Unova.",
         ["10", "22", "31", "43"]),
        ("me2pt5-named-ex", "이름을 달고 나온 ex 여덟", "Eight Trainers' ex",
         "카드 이름 앞에 트레이너 이름이 붙은 ex 여덟 장. 민화부터 청목까지 주인이 다 다르다.",
         "Eight ex that carry a trainer's name, from Erika's to Larry's. No two share an owner.",
         ["3", "26", "68", "70", "76", "111", "137", "164"]),
        ("me2pt5-rocket-executives", "로켓단 간부 다섯", "Five Team Rocket Executives",
         "총수 비주기와 간부 넷이 서포트로 들어 있다. 「로켓단 간부 3인」보다 두 사람이 많다.",
         "The boss Giovanni and four executives as Supporters. Two more people than the Destined Rivals trio.",
         ["201", "202", "204", "207", "208"]),
        ("me2pt5-erika-garden", "민화의 정원", "Erika's Garden",
         "뚜벅쵸와 모다피의 두 갈래에 덩쿠리까지, 민화가 키우는 풀 일곱 장.",
         "The Oddish and Bellsprout lines plus Tangela: seven plants that Erika raises.",
         ["1", "2", "3", "4", "5", "6", "7"]),
        ("me2pt5-mega-attack", "메가어택 일곱 장", "Seven Mega Attacks",
         "이 세트에만 있는 등급인 메가어택 일곱 장을 전부 모은다.",
         "All seven cards of the Mega Attack rarity, which only this set has.",
         ["265", "266", "267", "268", "269", "270", "271"]),
    ],
    "me3": [
        ("me3-four-megas", "질서의 메가 넷", "Four Megas of Order",
         "별, 요정, 질서, 강철. 이 세트의 메가진화 네 마리다.",
         "Star, fairy, order and steel: the set's four Mega Evolutions.",
         ["21", "31", "47", "55"]),
        ("me3-zygarde", "메가지가르데 네 장", "Mega Zygarde Four Ways",
         "같은 메가지가르데가 네 판본으로 들어 있다. 하이퍼레어 한 장이 끝까지 남는다.",
         "One Mega Zygarde in four printings. The hyper rare is the one that holds out.",
         ["47", "104", "120", "124"]),
        ("me3-grass-starters", "풀 스타터 두 줄", "Two Grass Starter Lines",
         "하나의 주리비얀과 알로라의 나몰빼미가 세 단계씩. 끝은 샤로다와 모크나이퍼 ex 다.",
         "Snivy from Unova and Rowlet from Alola, three stages each, ending in Serperior and Decidueye ex.",
         ["4", "5", "6", "10", "11", "12"]),
        ("me3-kalos-fossils", "칼로스 화석 둘", "Kalos Fossils",
         "턱화석과 지느러미화석, 그리고 거기서 깨어나는 두 갈래. 화석 카드까지 여섯 장이다.",
         "The Jaw and Sail Fossils and the two lines that wake from them. Six cards with the fossils.",
         ["23", "24", "44", "45", "68", "69"]),
        ("me3-honedge-line", "검이 되는 셋", "Sword to Shield",
         "한 자루가 두 자루가 되고, 마지막에는 방패를 든 왕이 된다.",
         "One blade becomes two, then a king with a shield.",
         ["56", "57", "58"]),
    ],
    "me4": [
        ("me4-kalos-starters", "칼로스 스타터", "Kalos Starters",
         "브리가론, 마폭시, 그리고 메가개굴닌자. 셋 중 둘이 레어라 금방 모인다.",
         "Chesnaught, Delphox and Mega Greninja ex. Two of the three are plain rares.",
         ["7", "13", "22"]),
        ("me4-greninja", "메가개굴닌자 네 장", "Mega Greninja Four Ways",
         "같은 메가개굴닌자가 네 판본으로 들어 있다. 하이퍼레어 한 장이 끝까지 남는다.",
         "One Mega Greninja in four printings. The hyper rare is the one that holds out.",
         ["22", "100", "116", "122"]),
        ("me4-deoxys-forms", "테오키스 네 장", "Deoxys Four Times",
         "테오키스는 네 가지 폼을 가진 포켓몬이다. 같은 이름 네 장을 다 찾아야 한다.",
         "Deoxys has four forms. Find all four cards that share its name.",
         ["31", "32", "33", "34"]),
        ("me4-kalos-lines", "칼로스 스타터 세 줄", "Three Kalos Starter Lines",
         "도치마론, 푸호꼬, 개구마르가 세 단계씩. 물 쪽 끝만 메가진화다.",
         "Chespin, Fennekin and Froakie, three stages each. Only the water line ends in a Mega.",
         ["5", "6", "7", "11", "12", "13", "20", "21", "22"]),
        ("me4-five-megas", "카오스의 메가 다섯", "Five Megas of Chaos Rising",
         "화염레오, 개굴닌자, 플라엣테, 엘레이드, 드래캄. 이 세트의 메가진화 ex 다섯 장이다.",
         "Pyroar, Greninja, Floette, Gallade and Dragalge: the set's five Mega ex.",
         ["15", "22", "35", "48", "65"]),
    ],
    "me5": [
        ("me5-night-megas", "칠흑의 메가 셋", "Megas of the Dark",
         "다크라이, 샹델라, 제라오라. 밤에 어울리는 메가진화 셋이다.",
         "Darkrai, Chandelure and Zeraora: three Megas made for the night.",
         ["27", "38", "48"]),
        ("me5-darkrai", "메가다크라이 네 장", "Mega Darkrai Four Ways",
         "같은 메가다크라이가 네 판본으로 들어 있다. 하이퍼레어 한 장이 끝까지 남는다.",
         "One Mega Darkrai in four printings. The hyper rare is the one that holds out.",
         ["48", "101", "116", "120"]),
        ("me5-sinnoh-fossils", "신오 화석 둘", "Sinnoh Fossils",
         "두개의화석과 방패의화석, 그리고 거기서 나오는 두 갈래. 한쪽은 ex 까지 간다.",
         "The Skull and Armor Fossils and their two lines. One of them reaches ex.",
         ["44", "45", "61", "62", "72", "73"]),
        ("me5-six-megas", "칠흑의 메가 여섯", "All Six Megas",
         "이 세트의 메가진화 ex 여섯 장 전부. 「칠흑의 메가 셋」보다 세 장 많다.",
         "Every Mega ex in the set, three more than Megas of the Dark.",
         ["8", "27", "31", "38", "48", "65"]),
        ("me5-gladion", "글라디오의 결전", "Gladion's Final Battle",
         "타입:널과 실버디, 그리고 둘을 키운 글라디오의 서포트 한 장.",
         "Type: Null, Silvally, and a Supporter from Gladion, who raised them.",
         ["69", "70", "77"]),
    ],
    "cel30": [
        ("cel30-generations", "여덟 세대의 전설", "Legends of Eight Generations",
         "2세대부터 9세대까지 세대마다 전설 하나. 전부 레어 칸이라 꾸준히 열면 모인다.",
         "One legend from each generation, two through nine. All from the Rare position, so steady opening gets there.",
         ["121", "82", "103", "14", "100", "80", "107", "62"]),
        ("cel30-mew-mewtwo", "뮤와 뮤츠", "Mew and Mewtwo",
         "원조와 복제가 더블레어와 스페셜아트로 두 장씩 들어 있다.",
         "The original and the copy, each as a Double Rare and as special art.",
         ["64", "66", "151", "152"]),
        ("cel30-thirty-pikachu", "피카츄 서른 마리", "Thirty Pikachu",
         "30주년이라 피카츄도 서른 장. 피카츄 칸에서만 나오는 그림을 전부 모은다.",
         "Thirty years, thirty Pikachu. Every illustration from the Pikachu position.",
         ["23", "24", "25", "26", "27", "28", "29", "30", "31", "32", "33", "34", "35", "36", "37", "38", "39", "40", "41", "42", "43", "44", "45", "46", "47", "48", "49", "50", "51", "52"]),
        ("cel30-three-charizards", "세 번 찍힌 리자몽", "Charizard, Printed Three Times",
         "1999년 베이스 세트의 리자몽이 25주년과 30주년에 다시 찍혔다. 세 장 모두 같은 그림이다.",
         "The 1999 Base Set Charizard, reprinted for the 25th and the 30th. The same art all three times.",
         ["base1-4", "cel25c-4_A", "cel30c-1"]),
        ("cel30-anniversary-magikarp", "기념판 잉어킹 둘", "Anniversary Magikarp",
         "25주년에는 빛나는 잉어킹이, 30주년에는 보통 잉어킹이 클래식 컬렉션에 들어갔다.",
         "Shining Magikarp for the 25th, plain Magikarp for the 30th, both in a Classic Collection.",
         ["cel25c-66_A", "cel30c-30"]),
        ("cel30-eevee-family", "30주년 이브이 가족", "Eevee Family at Thirty",
         "이브이 세 장, 보통과 ex 두 장씩인 에브이와 블래키, 그리고 님피아 ex.",
         "Three Eevee, Espeon and Umbreon as both regular and ex, and Sylveon ex.",
         ["116", "117", "118", "69", "70", "91", "92", "71"]),
        ("cel30-legendary-birds", "전설의 새, 두 번씩", "Legendary Birds, Twice Each",
         "프리져, 썬더, 파이어를 보통 카드와 일러스트레어로 한 장씩.",
         "Articuno, Zapdos and Moltres, each as a common and as an illustration rare.",
         ["11", "18", "55", "130", "132", "133"]),
        ("cel30-three-meowth", "세 지방의 나옹", "Meowth of Three Regions",
         "관동, 알로라, 가라르의 나옹을 보통 카드와 일러스트레어로 한 장씩.",
         "Kanto, Alolan and Galarian Meowth, each as a common and as an illustration rare.",
         ["113", "89", "101", "144", "139", "141"]),
        ("cel30-classic-legends", "클래식 컬렉션의 전설", "Legends of the Classic Collection",
         "30주년 클래식 컬렉션에 다시 찍힌 전설 포켓몬 여덟 장. 시대도 규칙도 제각각이다.",
         "Eight legendary reprints from the 30th Classic Collection, from different eras and rule boxes.",
         ["cel30c-16", "cel30c-17", "cel30c-19", "cel30c-20", "cel30c-22", "cel30c-27", "cel30c-28", "cel30c-29"]),
        ("cel30-future-mew-mewtwo", "미래에서 온 뮤와 뮤츠", "Mew and Mewtwo from the Future",
         "퓨처울트라레어로 다시 나온 뮤 ex 와 뮤츠 ex.",
         "Mew ex and Mewtwo ex again, this time as Futuristic Ultra Rares.",
         ["157", "158"]),
        ("cel30-rgb-mew", "빛의 삼원색 뮤", "Mew in Red, Green and Blue",
         "빨강, 초록, 파랑 판의 뮤 세 장. 클래식 컬렉션 칸에서 만 팩에 세 번꼴로 나와 도감에서 손꼽히게 먼 목표다.",
         "Mew in red, green and blue. They come from the Classic Collection position about three times in ten thousand packs, one of the longest goals in the dex.",
         ["R_RGB", "G_RGB", "B_RGB"]),
    ],
    "cel25": [
        ("cel25-base-trio", "1999년의 세 장, 다시", "Base Set Trio, Again",
         "베이스 세트의 이상해꽃, 리자몽, 거북왕이 25주년 클래식 컬렉션으로 다시 나왔다.",
         "Base Set Venusaur, Charizard and Blastoise, reprinted in the 25th Classic Collection.",
         ["cel25c-15_A1", "cel25c-4_A", "cel25c-2_A"]),
        ("cel25-rocket-classics", "로켓단 클래식", "Team Rocket Classics",
         "로켓단이 나오는 옛 카드 넷이 25주년 클래식 컬렉션에 다시 실렸다.",
         "Four old Team Rocket cards, reprinted in the 25th Classic Collection.",
         ["cel25c-15_A2", "cel25c-15_A3", "cel25c-86_A", "cel25c-8_A"]),
    ],
    "swsh9": [
        ("swsh9-gallery-eevee", "갤러리의 이브이 가족", "Eevee Family in the Gallery",
         "트레이너 갤러리에 실린 이브이와 진화형 여덟 장. 님피아와 블래키는 V 와 VMAX 둘 다 있다.",
         "Eight Trainer Gallery cards of Eevee and its evolutions. Sylveon and Umbreon come as both V and VMAX.",
         ["swsh9tg-TG01", "swsh9tg-TG02", "swsh9tg-TG04", "swsh9tg-TG11", "swsh9tg-TG14", "swsh9tg-TG15", "swsh9tg-TG22", "swsh9tg-TG23"]),
        ("swsh9-gallery-urshifu", "일격과 연격", "Single Strike and Rapid Strike",
         "우라오스의 두 유파가 V 와 VMAX 로, VMAX 는 두 판본씩 들어 있다. 두 유파의 스승 마스터드도 두 장이다.",
         "Both Urshifu styles as V and VMAX, two VMAX printings each, plus their teacher Mustard in both styles.",
         ["swsh9tg-TG18", "swsh9tg-TG19", "swsh9tg-TG20", "swsh9tg-TG21", "swsh9tg-TG27", "swsh9tg-TG28", "swsh9tg-TG29", "swsh9tg-TG30"]),
    ],
    "swsh10": [
        ("swsh10-gallery-calyrex", "버드렉스의 두 말", "Calyrex and Its Two Steeds",
         "백마와 흑마를 탄 버드렉스가 V 와 VMAX 로, VMAX 는 두 판본씩 들어 있다.",
         "Ice Rider and Shadow Rider Calyrex as V and VMAX, two VMAX printings each.",
         ["swsh10tg-TG14", "swsh10tg-TG15", "swsh10tg-TG17", "swsh10tg-TG18", "swsh10tg-TG29", "swsh10tg-TG30"]),
        ("swsh10-gallery-galarian-birds", "가라르의 세 새", "Galarian Birds",
         "가라르에서 모습이 바뀐 프리져, 썬더, 파이어가 트레이너 갤러리 V 로 모였다.",
         "Galarian Articuno, Zapdos and Moltres together as Trainer Gallery V.",
         ["swsh10tg-TG16", "swsh10tg-TG19", "swsh10tg-TG20"]),
        ("swsh10-gallery-sword-shield", "검과 방패", "Sword and Shield",
         "자시안과 자마젠타가 트레이너 갤러리 V 로 나란히 들어 있다.",
         "Zacian and Zamazenta side by side as Trainer Gallery V.",
         ["swsh10tg-TG21", "swsh10tg-TG22"]),
        ("galar-gym-leaders", "가라르 체육관 관장 열 명", "Ten Galar Gym Leaders",
         "세 세트의 트레이너 갤러리에 흩어진 가라르 관장 열 명. 세 세트의 팩을 모두 열어야 한다.",
         "All ten Galar Gym Leaders, spread over three sets' Trainer Galleries. All three sets' packs are needed.",
         ["swsh10tg-TG24", "swsh10tg-TG25", "swsh10tg-TG26", "swsh10tg-TG27", "swsh10tg-TG28", "swsh11tg-TG26", "swsh11tg-TG27", "swsh11tg-TG28", "swsh12tg-TG24", "swsh12tg-TG27"]),
    ],
    "swsh11": [
        ("swsh11-gallery-pikachu", "갤러리의 피카츄 넷", "Gallery Pikachu",
         "보통 피카츄와 V, 그리고 두 판본의 VMAX. 트레이너와 함께 그려진 피카츄 네 장이다.",
         "Pikachu, Pikachu V and two Pikachu VMAX, each drawn with a trainer.",
         ["swsh11tg-TG05", "swsh11tg-TG16", "swsh11tg-TG17", "swsh11tg-TG29"]),
        ("swsh11-gallery-ghosts", "갤러리의 유령 넷", "Gallery Ghosts",
         "샹델라, 팬텀, 다크펫, 화강돌. 이 트레이너 갤러리의 유령 포켓몬 넷이다.",
         "Chandelure, Gengar, Banette and Spiritomb: the four ghost Pokémon in this Trainer Gallery.",
         ["swsh11tg-TG04", "swsh11tg-TG06", "swsh11tg-TG07", "swsh11tg-TG09"]),
    ],
    "swsh12": [
        ("swsh12-gallery-dragons", "갤러리의 두 용", "Two Gallery Dragons",
         "레쿠쟈 VMAX 와 두랄루돈 VMAX 가 두 판본씩 들어 있다.",
         "Rayquaza VMAX and Duraludon VMAX, two printings each.",
         ["swsh12tg-TG20", "swsh12tg-TG21", "swsh12tg-TG29", "swsh12tg-TG30"]),
    ],
    "swsh12pt5": [
        ("swsh12pt5-gallery-creation", "창조의 신화 넷", "Four Myths of Creation",
         "디아루가, 펄기아, 기라티나, 그리고 셋을 만들었다는 아르세우스. 갈라리안 갤러리 VSTAR 네 장이다.",
         "Dialga, Palkia, Giratina and Arceus, said to have made them. Four Galarian Gallery VSTARs.",
         ["swsh12pt5gg-GG67", "swsh12pt5gg-GG68", "swsh12pt5gg-GG69", "swsh12pt5gg-GG70"]),
        ("swsh12pt5-gallery-beasts", "성도의 전설 셋", "Legendary Beasts",
         "앤테이, 스이쿤, 라이코. 불탄 탑에서 되살아난 셋이 갈라리안 갤러리 V 로 모였다.",
         "Entei, Suicune and Raikou, revived at the Burned Tower, together as Galarian Gallery V.",
         ["swsh12pt5gg-GG36", "swsh12pt5gg-GG38", "swsh12pt5gg-GG41"]),
        ("swsh12pt5-gallery-deoxys", "갤러리의 테오키스", "Deoxys in the Gallery",
         "테오키스와 VMAX, VSTAR. 갈라리안 갤러리에 같은 포켓몬이 세 장 있다.",
         "Deoxys, Deoxys VMAX and Deoxys VSTAR: three Galarian Gallery cards of one Pokémon.",
         ["swsh12pt5gg-GG12", "swsh12pt5gg-GG45", "swsh12pt5gg-GG46"]),
        ("swsh12pt5-gallery-moon-sun", "해와 달의 바위", "Moon and Sun Rocks",
         "루나톤과 솔록. 늘 짝으로 나오는 둘이 갈라리안 갤러리에서도 나란히 있다.",
         "Lunatone and Solrock, a pair as always, side by side in the Galarian Gallery.",
         ["swsh12pt5gg-GG11", "swsh12pt5gg-GG15"]),
    ],
    "swsh45": [
        ("swsh45-shiny-galar-starters", "빛나는 가라르 스타터", "Shiny Galar Starters",
         "흥나숭, 염버니, 울머기가 세 단계 모두 이로치로 들어 있다. 아홉 장이다.",
         "Grookey, Scorbunny and Sobble, all three stages shiny. Nine cards.",
         ["swsh45sv-SV004", "swsh45sv-SV005", "swsh45sv-SV006", "swsh45sv-SV015", "swsh45sv-SV016", "swsh45sv-SV017", "swsh45sv-SV025", "swsh45sv-SV026", "swsh45sv-SV027"]),
        ("swsh45-shiny-galar-evolutions", "가라르에서만 진화하는 여섯", "Six Galar-Only Evolutions",
         "가라르의 모습에서만 이어지는 진화 여섯. 마임꽁꽁부터 나이킹까지 전부 이로치다.",
         "Six evolutions that exist only for Galarian forms, from Mr. Rime to Perrserker, all shiny.",
         ["swsh45sv-SV021", "swsh45sv-SV050", "swsh45sv-SV064", "swsh45sv-SV066", "swsh45sv-SV080", "swsh45sv-SV087"]),
        ("swsh45-shiny-dragapult", "빛나는 드래펄트", "Shiny Dragapult Line",
         "드라꼰, 드래런치, 드래펄트가 이로치로 세 단계 모두.",
         "Dreepy, Drakloak and Dragapult, all three stages shiny.",
         ["swsh45sv-SV060", "swsh45sv-SV061", "swsh45sv-SV062"]),
    ],
    "sm115": [
        ("sm115-shiny-tapu", "빛나는 수호신 넷", "Shiny Guardians",
         "알로라 네 섬의 수호신이 이로치 GX 로 모였다.",
         "The guardian deities of Alola's four islands, together as shiny GX.",
         ["sma-SV91", "sma-SV92", "sma-SV93", "sma-SV94"]),
        ("sm115-shiny-ultra-beasts", "빛나는 울트라비스트 일곱", "Shiny Ultra Beasts",
         "다른 세계에서 온 일곱이 이로치로 들어 있다. GX 가 아닌 보통 이로치라 꾸준히 열면 모인다.",
         "Seven visitors from other worlds, all shiny. None are GX, so steady opening gets there.",
         ["sma-SV5", "sma-SV14", "sma-SV19", "sma-SV24", "sma-SV26", "sma-SV32", "sma-SV33"]),
        ("sm115-shiny-eevee", "빛나는 이브이 가족", "Shiny Eevee Family",
         "이로치 이브이와 다섯 진화형 GX. 리피아부터 님피아까지다.",
         "Shiny Eevee and five of its evolutions as GX, from Leafeon to Sylveon.",
         ["sma-SV41", "sma-SV46", "sma-SV55", "sma-SV60", "sma-SV69", "sma-SV76"]),
        ("sm115-shiny-charizard", "빛나는 리자몽 진화", "Shiny Charizard Line",
         "파이리, 리자드, 그리고 검은 리자몽 GX. 이 세트를 대표하는 한 장이 마지막이다.",
         "Charmander, Charmeleon and the black Charizard-GX, the card this set is known for.",
         ["sma-SV6", "sma-SV7", "sma-SV49"]),
    ],
    "me1": [
        ("mega-hyper-rares", "메가 하이퍼레어 여덟", "Eight Mega Hyper Rares",
         "메가진화 시리즈 여섯 세트에 흩어진 메가 하이퍼레어 여덟 장. 세트마다 한두 장뿐인 금빛 카드다.",
         "All eight Mega Hyper Rares, spread over six Mega Evolution sets. Each set has only one or two of these gold cards.",
         ["me1-187", "me1-188", "me2-130", "me2pt5-294", "me2pt5-295", "me3-124", "me4-122", "me5-120"]),
    ],
    "ex7": [
        ("gold-star-all", "골드스타 스물다섯 장", "All Twenty-Five Gold Stars",
         "팀 로켓 리턴즈부터 파워 키퍼스까지, EX 시리즈 아홉 세트에 흩어진 골드스타 전부.",
         "Every Gold Star from Team Rocket Returns to Power Keepers, spread over nine EX sets.",
         ["ex7-107", "ex7-108", "ex7-109", "ex8-105", "ex8-106", "ex8-107", "ex10-113", "ex10-114", "ex10-115", "ex11-111", "ex11-112", "ex11-113", "ex12-90", "ex12-91", "ex12-92", "ex13-102", "ex13-103", "ex13-104", "ex14-99", "ex14-100", "ex15-100", "ex15-101", "ex16-100", "ex16-101", "ex16-102"]),
        ("ex7-gold-star-starters", "골드스타 호연 스타터", "Gold Star Hoenn Starters",
         "나무지기, 아차모, 물짱이. 골드스타가 처음 나온 세트에 셋이 함께 들어 있다.",
         "Treecko, Torchic and Mudkip, together in the set where Gold Stars began.",
         ["107", "108", "109"]),
    ],
    "ecard3": [
        ("crystal-nine", "크리스탈 포켓몬 아홉", "Nine Crystal Pokémon",
         "e카드 시리즈 마지막 두 세트에만 나온 크리스탈 포켓몬 아홉 장 전부.",
         "All nine Crystal Pokémon, which appeared only in the last two e-Card sets.",
         ["ecard2-148", "ecard2-149", "ecard2-150", "ecard3-145", "ecard3-146", "ecard3-147", "ecard3-148", "ecard3-149", "ecard3-150"]),
    ],
    "sv3": [
        ("charizard-ten-eras", "열 시대의 리자몽", "Charizard Across Ten Eras",
         "네오부터 메가진화까지, 시대마다 손꼽히는 리자몽 한 장씩. 열 세트의 팩을 모두 열어야 한다.",
         "One standout Charizard from each era, Neo to Mega Evolution. Packs from ten sets are needed.",
         ["neo4-107", "ecard3-146", "ex15-100", "dp7-103", "bw8-136", "xy2-108", "sm3-150", "swsh35-74", "sv3-228", "me2-130"]),
    ],
    "sv8pt5": [
        ("sv8pt5-eevee-sar", "프리즘 이브이 SAR 아홉", "Nine Prismatic Eevee SARs",
         "이브이와 여덟 진화형의 스페셜아트 아홉 장 전부.",
         "The special art cards of Eevee and all eight of its evolutions.",
         ["167", "144", "146", "149", "150", "153", "155", "156", "161"]),
    ],
    "swsh7": [
        ("umbreon-by-moonlight", "달빛의 블래키 여섯", "Umbreon by Moonlight",
         "여섯 세트에 흩어진 블래키의 귀한 판본 여섯 장. 금색 별부터 스페셜아트까지 다 모은다.",
         "Six prized Umbreon printings from six sets, from the Gold Star reprint to special art.",
         ["swsh7-215", "sv8pt5-161", "sm1-154", "sma-SV69", "swsh9tg-TG23", "cel25c-17_A"]),
    ],
    "ex13": [
        ("pikachu-seven-eras", "일곱 시대의 피카츄", "Pikachu Across Seven Eras",
         "EX 의 골드스타부터 메가진화의 스페셜아트까지, 시대마다 손꼽히는 피카츄 한 장씩.",
         "One standout Pikachu from each era, from the EX Gold Star to Mega Evolution special art.",
         ["ex13-104", "pl2-112", "bw1-115", "sm12-241", "swsh4-188", "sv8-238", "me2pt5-276"]),
    ],
    "neo4": [
        ("neo-shining-ten", "빛나는 포켓몬 열 마리", "Ten Shining Pokémon",
         "네오 레벌루션과 네오 데스티니의 빛나는 포켓몬 열 장 전부. 이로치 포켓몬이 처음 카드가 된 시리즈다.",
         "All ten Shining Pokémon from Neo Revelation and Neo Destiny, the series that first put shiny Pokémon on cards.",
         ["neo3-65", "neo3-66", "neo4-106", "neo4-107", "neo4-108", "neo4-109", "neo4-110", "neo4-111", "neo4-112", "neo4-113"]),
    ],
    "sm35": [
        ("sm35-shining-six", "빛나는 전설 여섯 전부", "All Six Shining Legends",
         "샤이닝 레전드의 빛나는 포켓몬 여섯 장 전부. 「다시 빛나는 것들」의 세 장에 셋이 더 붙는다.",
         "All six Shining Pokémon in Shining Legends: the three from Shining Again plus three more.",
         ["9", "27", "40", "42", "56", "57"]),
    ],
    "ex10": [
        ("ex10-gold-star-beasts", "골드스타 전설의 셋", "Gold Star Legendary Beasts",
         "앤테이, 라이코, 스이쿤이 모두 골드스타로 한 세트에 들어 있다.",
         "Entei, Raikou and Suicune, all three as Gold Stars in one set.",
         ["113", "114", "115"]),
    ],
    "sv3pt5": [
        ("sv3pt5-special-arts", "151의 스페셜아트와 금빛 뮤", "151 Special Arts and Gold Mew",
         "151에 들어 있는 스페셜아트 일곱 장과 금빛 뮤 ex 한 장.",
         "The seven special art cards in 151 and the gold Mew ex.",
         ["198", "199", "200", "201", "202", "203", "204", "205"]),
    ],
    "zsv10pt5": [
        ("black-white-rares", "블랙 화이트 레어 둘", "The Two Black White Rares",
         "블랙 볼트와 화이트 플레어에 한 장씩 있는 블랙 화이트 레어. 두 세트를 다 열어야 짝이 맞는다.",
         "The Black White Rare in Black Bolt and the one in White Flare. Both sets are needed to pair them.",
         ["zsv10pt5-172", "rsv10pt5-173"]),
    ],
}
SET_TIER_FLOOR = "SAR"


def load_index():
    index = json.loads(INDEX.read_text())
    order = index["tierOrder"]
    tiers = {card[0]: card[2] for card in index["cards"]}
    names = {s["id"]: s["name"] for s in index["sets"]}
    parents = index["subsetParents"]
    species = {}
    for card in index["cards"]:
        sid = card[0].rsplit("-", 1)[0]
        sid = parents.get(sid, sid)
        species[sid] = species.get(sid, 0) + 1
    return order, tiers, names, species


def empty_reward():
    return {"packs": 0, "perks": [], "tokens": 0, "coupons": [], "card": None}


def add_missing(data):
    order, tiers, names, species = load_index()
    dexes = data["dexes"]
    have = {dex["id"] for dex in dexes}
    added = []
    for sid in ADDITIONS:
        set_id = f"set-{sid}"
        if set_id not in have:
            count = species[sid]
            dexes.append({
                "id": set_id, "kind": "set",
                "name": {"ko": f"{names[sid]} 수집", "en": f"{names[sid]} Collection"},
                "blurb": {"ko": "", "en": ""}, "homeSet": sid, "cards": [],
                "tier": 1, "medianPacks": 1, "medianTokens": 1, "valueUSD": 0, "hardPacks": 1,
                "reward": {"packs": 0, "perks": [], "tokens": 0, "boosters": [], "card": None,
                           "skinSet": None},
                "milestones": [
                    {"fraction": f, "need": math.floor(f * count), "medianPacks": 1,
                     "medianTokens": 1, "reward": dict(empty_reward(), tokens=1)}
                    for f in FRACTIONS
                ],
            })
            added.append(set_id)
        for dex_id, name_ko, name_en, blurb_ko, blurb_en, numbers in ADDITIONS[sid]:
            if dex_id in have:
                continue
            cards = [n if "-" in n else f"{sid}-{n}" for n in numbers]
            assert all(card in tiers for card in cards), dex_id
            cards.sort(key=lambda card: -order.index(tiers[card]))
            dexes.append({
                "id": dex_id, "kind": "theme",
                "name": {"ko": name_ko, "en": name_en},
                "blurb": {"ko": blurb_ko, "en": blurb_en},
                "homeSet": sid, "cards": cards,
                "tier": 1, "medianPacks": 1, "medianTokens": 1, "valueUSD": 0, "hardPacks": 1,
                "reward": empty_reward(), "milestones": [],
            })
            added.append(dex_id)
    return added


def coupons(target, price, share, budget):
    """Half-price coupons worth about `share` of the target, never above `budget`."""
    if not price:
        return [], 0
    count = min(round(share * target / (0.5 * price)), math.floor(budget / (0.5 * price)), 20)
    count = max(0, count)
    return ([{"value": 0.5, "count": count}] if count else []), count * 0.5 * price


def set_rewards(dex, row, price):
    for step, (milestone, measured) in enumerate(zip(dex["milestones"], row["milestones"])):
        assert milestone["need"] == measured["need"], dex["id"]
        milestone["medianPacks"] = measured["medianPacks"]
        milestone["medianTokens"] = measured["medianTokens"]
        target = SET_TARGET * measured["medianTokens"]
        reward = milestone["reward"]
        reward["packs"] = 0
        reward["perks"] = []
        card_value = 0
        if step == len(dex["milestones"]) - 1:
            usd = round(0.5 * target / TOKENS_PER_USD, 4)
            floor = (reward.get("card") or {}).get("tierFloor", SET_TIER_FLOOR)
            reward["card"] = {"targetUSD": usd, "tierFloor": floor}
            card_value = usd * TOKENS_PER_USD
        else:
            reward["card"] = None
        reward["coupons"], coupon_value = (
            ([], 0) if step == 0 else coupons(target, price, 0.4, target - card_value)
        )
        reward["tokens"] = max(1, round(target - coupon_value - card_value))


def theme_rewards(dex, row, price, before):
    reward = dex["reward"]
    ratio = row["medianTokens"] / before if before > 1 else 1
    cap = math.floor((THEME_TARGET * row["medianTokens"] + price / 2) / price) if price else 0
    reward["packs"] = max(0, min(reward.get("packs", 0), MAX_REWARD_PACKS, cap))
    if reward.get("tokens"):
        reward["tokens"] = round(reward["tokens"] * ratio)
    if reward.get("card"):
        reward["card"]["targetUSD"] = round(reward["card"]["targetUSD"] * ratio, 4)


# Rewards for a hand-written theme that has only its perk, by measured tier.
# Shares are the medians of the older hand-tuned themes: easy themes give a
# perk, middle ones a few packs, hard ones a card grant and coupons.
SHAPED_PACKS = {1: 0.12, 2: 0.10, 3: 0.06}
SHAPED_CARD = {4: (0.024, 0.13), 5: (0.016, 0.12)}
GRANT_FLOOR = "BWR"


def shape_theme(dex, price):
    """Raise a theme's one-time reward to its tier's share; never lower it.

    Taking the larger of the stored and the computed value keeps reruns stable.
    """
    reward = dex["reward"]
    cost = dex["medianTokens"]
    tier = dex["tier"]
    empty = not (reward.get("packs") or reward.get("tokens") or reward.get("card")
                 or reward.get("coupons"))
    if tier in SHAPED_PACKS and price and (empty or reward.get("packs")):
        cap = math.floor((THEME_TARGET * cost + price / 2) / price)
        packs = min(MAX_REWARD_PACKS, cap, max(1, round(SHAPED_PACKS[tier] * cost / price)))
        if packs > 0:
            reward["packs"] = max(reward.get("packs") or 0, packs)
        elif empty:
            reward["coupons"], _ = coupons(cost, price, 0.15, THEME_TARGET * cost)
    elif tier in SHAPED_CARD and (empty or reward.get("card")):
        card_share, coupon_share = SHAPED_CARD[tier]
        card = reward.get("card") or {"targetUSD": 0, "tierFloor": GRANT_FLOOR}
        card["targetUSD"] = max(card["targetUSD"], round(card_share * cost / TOKENS_PER_USD, 4))
        reward["card"] = card
        wanted, _ = coupons(cost, price, coupon_share, THEME_TARGET * cost)
        have = sum(c["count"] for c in reward.get("coupons") or [])
        if sum(c["count"] for c in wanted) > have:
            reward["coupons"] = wanted


PERK_KINDS = ["tokenGain", "packDiscount", "dustBonus", "hitOdds"]
PERK_TIER = 5
# Budgets fixed at the totals before perks moved to tier-5 themes (2026-10-23),
# so reruns do not shave them by rounding. Themes plus ladder sit at the caps.
# Token gain's cap rose from 25% to 40% (2026-10-23); the extra 15 points all go to
# tier-5 themes. Pack discount, resale and hit odds stay put: raising them could
# make opening packs and selling the cards pay for itself.
THEME_PERK_BUDGET = {"tokenGain": 0.296, "packDiscount": 0.085, "dustBonus": 0.084, "hitOdds": 0.114}
LADDER_PERK_BUDGET = {"tokenGain": 0.1038, "packDiscount": 0.0645, "dustBonus": 0.0657,
                      "hitOdds": 0.0855}
# (completed dexes, Korean title, English title). The last step's count is the
# number of dexes. 225 and 275 fill the long gap between 175 and the end.
LADDER = [
    (10, "첫 수집가", "First Collector"),
    (25, "책장 정리", "Shelf Keeper"),
    (50, "반절 사냥꾼", "Halfway Hunter"),
    (100, "백권 서고", "Hundred Binders"),
    (175, "세트 사냥꾼", "Set Hunter"),
    (225, "조합 연구가", "Combo Scholar"),
    (275, "끝판을 넘보는 자", "Endgame Seeker"),
    (None, "도감 완성자", "Dex Completionist"),
]


def spread_perks(dexes):
    themes = [dex for dex in dexes if dex["kind"] == "theme"]
    holders = sorted((dex for dex in themes if dex["tier"] >= PERK_TIER),
                     key=lambda dex: (dex["medianTokens"], dex["id"]))
    for dex in themes:
        dex["reward"]["perks"] = []
    for offset, kind in enumerate(PERK_KINDS):
        group = holders[offset::len(PERK_KINDS)]
        weights = [math.log10(dex["medianTokens"]) for dex in group]
        total = round(THEME_PERK_BUDGET[kind] * 10_000)
        # Floor only: equal costs get equal values, and the sum never passes the budget.
        for dex, weight in zip(group, weights):
            unit = math.floor(total * weight / sum(weights))
            dex["reward"]["perks"] = [{"kind": kind, "value": round(unit / 10_000, 4)}]


def build_ladder(dex_count):
    # Weights 2, 3, ... 9: each step is thicker than the last, and the first is
    # not thinned to nothing by the extra steps (about 0.47% token gain at 10).
    weights = [index + 1 for index in range(1, len(LADDER) + 1)]
    share = sum(weights)
    ladder = []
    for weight, (completed, title_ko, title_en) in zip(weights, LADDER):
        ladder.append({
            "completed": completed if completed is not None else dex_count,
            "title": {"ko": title_ko, "en": title_en},
            "perks": [{"kind": kind,
                       "value": round(math.floor(LADDER_PERK_BUDGET[kind] * 10_000 * weight / share)
                                      / 10_000, 4)}
                      for kind in PERK_KINDS],
        })
    return ladder


def main():
    data = json.loads(DEX.read_text())
    added = add_missing(data)
    if len(sys.argv) < 2:
        DEX.write_text(json.dumps(data, indent=1, ensure_ascii=False))
        print(f"added {len(added)} dexes; build, run --dex-metrics, then run again with it")
        return
    metrics = json.loads(Path(sys.argv[1]).read_text())
    rows = {row["id"]: row for row in metrics["dexes"]}
    prices = metrics["packPrices"]
    missing = [dex["id"] for dex in data["dexes"] if dex["id"] not in rows]
    assert not missing, f"metrics lack {missing}; rebuild the app before measuring"
    for dex in data["dexes"]:
        row = rows[dex["id"]]
        before = dex["medianTokens"]
        dex["tier"] = row["tier"]
        dex["medianPacks"] = row["medianPacks"]
        dex["medianTokens"] = row["medianTokens"]
        dex["valueUSD"] = round(row["valueUSD"], 2)
        dex["hardPacks"] = row["hardPacks"]
        price = prices[dex["homeSet"]]
        if dex["kind"] == "set":
            set_rewards(dex, row, price)
        else:
            theme_rewards(dex, row, price, before)
    spread_perks(data["dexes"])
    for dex in data["dexes"]:
        # Themes that lost their perk, or never had another reward, get packs or a card.
        if dex["kind"] == "theme":
            shape_theme(dex, prices[dex["homeSet"]])
    data["ladder"] = build_ladder(len(data["dexes"]))
    DEX.write_text(json.dumps(data, indent=1, ensure_ascii=False))
    print(f"updated {len(data['dexes'])} dexes")


if __name__ == "__main__":
    main()
