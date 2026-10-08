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
- Theme rewards keep their shape. Reward packs never exceed 30% of the cost
  (plus half a pack for rounding), and card grants follow the cost.
- Theme perks keep each kind's total. Values are reassigned so a costlier dex
  never gives less of the same perk.
- The last ladder step opens when every dex is complete.
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
THEME_TARGET = 0.30
MAX_REWARD_PACKS = 10
FRACTIONS = (0.5, 0.75, 0.9)

# Hand-written dexes for sets that arrived after the last rebuild. Cards are
# listed by number; the script sorts them by rarity as the dex view expects.
ADDITIONS = {
    "me2pt5": [
        ("me2pt5-regi-trio", "레지 삼총사", "The Regi Trio",
         "얼음, 바위, 강철. 세 거인이 한 세트에 ex 로 모였다.",
         "Ice, rock and steel. The three giants share one set as ex.",
         ["48", "107", "145"]),
        ("me2pt5-mega-dragonite", "메가망나뇽 세 장", "Mega Dragonite Three Ways",
         "메가어택, 스페셜아트, 메가 하이퍼레어. 같은 망나뇽의 세 판본이라 마지막 한 장이 늘 제일 멀다.",
         "Mega Attack, special art and Mega Hyper Rare. One Dragonite in three printings, "
         "and the last one is always the farthest.",
         ["271", "290", "295"]),
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
    ],
    "cel30": [
        ("cel30-generations", "여덟 세대의 전설", "Legends of Eight Generations",
         "2세대부터 9세대까지 세대마다 전설 하나. 전부 레어 칸이라 꾸준히 열면 모인다.",
         "One legend from each generation, two through nine. All from the Rare position, "
         "so steady opening gets there.",
         ["121", "82", "103", "14", "100", "80", "107", "62"]),
        ("cel30-mew-mewtwo", "뮤와 뮤츠", "Mew and Mewtwo",
         "원조와 복제가 더블레어와 스페셜아트로 두 장씩 들어 있다.",
         "The original and the copy, each as a Double Rare and as special art.",
         ["64", "66", "151", "152"]),
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
            cards = [f"{sid}-{n}" for n in numbers]
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


def spread_perks(dexes):
    themes = [dex for dex in dexes if dex["kind"] == "theme"]
    kinds = ["tokenGain", "packDiscount", "dustBonus", "hitOdds"]
    count = {kind: sum(1 for dex in themes for p in dex["reward"]["perks"] if p["kind"] == kind)
             for kind in kinds}
    # Every theme gives one perk. A new one takes the kind with the fewest dexes so far.
    for dex in themes:
        if not dex["reward"]["perks"]:
            kind = min(kinds, key=lambda k: (count[k], kinds.index(k)))
            count[kind] += 1
            dex["reward"]["perks"] = [{"kind": kind, "value": None}]
    for kind in kinds:
        holders = [dex for dex in themes for p in dex["reward"]["perks"] if p["kind"] == kind]
        old = [p["value"] for dex in holders for p in dex["reward"]["perks"]
               if p["kind"] == kind and p["value"] is not None]
        total = round(sum(old) * 10_000)
        filler = sorted(old)[len(old) // 2]
        values = sorted(old + [filler] * (len(holders) - len(old)))
        scale = total / (sum(values) * 10_000)
        units = [math.floor(v * 10_000 * scale) for v in values]
        units = [max(1, u) for u in units]
        # Spend any leftover on the costliest dexes so the order never inverts.
        i = len(units) - 1
        while sum(units) < total:
            units[i] += 1
            i = i - 1 if i > 0 else len(units) - 1
        assert sum(units) <= total, kind
        holders.sort(key=lambda dex: (dex["medianTokens"], dex["id"]))
        for dex, unit in zip(holders, units):
            for perk in dex["reward"]["perks"]:
                if perk["kind"] == kind:
                    perk["value"] = round(unit / 10_000, 4)


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
    data["ladder"][-1]["completed"] = len(data["dexes"])
    DEX.write_text(json.dumps(data, indent=1, ensure_ascii=False))
    print(f"updated {len(data['dexes'])} dexes")


if __name__ == "__main__":
    main()
