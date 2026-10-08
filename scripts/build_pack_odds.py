#!/usr/bin/env python3
"""Turn the pull-rate research into Sources/PokePackBar/Resources/pack-odds.json.

Inputs live in plan/pull-rates/:
- research.json: measured English booster rates per set, with sources.
- tables-before.json: the era tables each set used before this data existed.
  Tiers the research does not measure keep their old share from here.

Every number is a per-slot probability. A tier that only comes from one slot
of count 1 takes the measured "at least one per pack" rate directly. Fill tiers
(R in the rare slot, C/U/R in reverse slots) absorb the remainder.

Run from the repository root: python3 scripts/build_pack_odds.py
"""

import json
import re
from collections import defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "Sources/PokePackBar/Resources/pack-odds.json"

index = json.loads((ROOT / "Sources/PokePackBar/Resources/card-index.json").read_text())
TIER_ORDER = index["tierOrder"]
RARITIES = index["rarities"]
PARENTS = index["subsetParents"]
tables_before = json.loads((ROOT / "plan/pull-rates/tables-before.json").read_text())
research = {
    s["id"]: s
    for s in json.loads((ROOT / "plan/pull-rates/research.json").read_text())["sets"]
}

cards_by_set = defaultdict(list)  # parent set -> [(id, tier, rarity)]
for c in index["cards"]:
    cid, tier, rarity = c[0], c[2], RARITIES[c[3]]
    sid = cid.rsplit("-", 1)[0]
    cards_by_set[PARENTS.get(sid, sid)].append((cid, tier, rarity))


def pool(sid, tier, only=None, exclude=None):
    out = []
    for cid, t, rarity in cards_by_set[sid]:
        if t != tier:
            continue
        if sid == "cel30" and rarity == "Pikachu Rare":
            continue
        if only and not (cid in only.get("ids", ()) or rarity in only.get("rarities", ())):
            continue
        if exclude and (cid in exclude.get("ids", ()) or rarity in exclude.get("rarities", ())):
            continue
        out.append(cid)
    return out


def real(sid, tier):
    v = research.get(sid, {}).get("real", {}).get(tier)
    return None if v is None else v.get("atLeastOnePerPack")


def current(sid, kind):
    """The era table the set used before, as fractions."""
    tiers = tables_before.get(sid, {}).get(kind)
    return None if tiers is None else {t: p for t, p in tiers.items() if p > 0}


def fill(sid, kind, targets, fill_tiers, keep=(), drop=(), rules=None, fill_shares=None):
    """targets: tier -> fraction. Fill tiers share the remainder in proportion
    to `fill_shares` (or the app's current shares). Other current tiers keep
    their current share unless dropped."""
    rules = rules or {}
    base = current(sid, kind) or {}
    shares = {}
    for t, p in base.items():
        if t in targets or t in fill_tiers or t in drop:
            continue
        if not pool(sid, t, **rules.get(t, {})):
            continue
        shares[t] = p
    for t, p in targets.items():
        if p and p > 0 and pool(sid, t, **rules.get(t, {})):
            shares[t] = p
    remainder = 1 - sum(shares.values())
    assert remainder > 0, (sid, kind, shares)
    source = fill_shares or {t: base.get(t, 0) for t in fill_tiers}
    source = {t: p for t, p in source.items() if p > 0 and pool(sid, t, **rules.get(t, {}))}
    total = sum(source.values())
    assert total > 0, (sid, kind, source)
    for t, p in source.items():
        shares[t] = remainder * p / total
    return shares


def to_weights(shares):
    """Fractions -> integer weights summing to 10,000, largest remainder."""
    raw = {t: p * 10_000 for t, p in shares.items()}
    floors = {t: int(v) for t, v in raw.items()}
    left = 10_000 - sum(floors.values())
    for t in sorted(raw, key=lambda t: raw[t] - floors[t], reverse=True)[:left]:
        floors[t] += 1
    # A measured but tiny tier must stay reachable.
    for t, v in list(floors.items()):
        if v == 0:
            floors[t] = 1
            biggest = max(floors, key=floors.get)
            floors[biggest] -= 1
    return [[t, floors[t]] for t in sorted(floors, key=TIER_ORDER.index)]


out = {}
notes = defaultdict(list)


def put(sid, kind, shares, rules=None, finishes=None):
    for tier in shares:
        assert pool(sid, tier, **(rules or {}).get(tier, {})), (sid, kind, tier)
    entry = out.setdefault(sid, {"slots": {}})
    entry["slots"][kind] = to_weights(shares)
    if rules:
        entry.setdefault("pools", {})[kind] = rules
    if finishes:
        entry.setdefault("finishes", {})[kind] = finishes


# Box toppers and theme-deck-only cards never come from real packs, but every
# card in a set must stay collectable here. They keep a 1-in-1,000 pack rate.
TOKEN = 0.001

# ---------------------------------------------------------------- WotC
for sid in ["base1", "base2", "base3", "base4", "base5", "gym1", "gym2",
            "neo1", "neo2", "neo3", "neo4", "base6"]:
    t = {}
    for tier in ("RR", "SH", "UR"):
        p = real(sid, tier)
        if p is not None:
            t[tier] = p
    if sid == "base6":
        t["RR"] = 1 / 3  # the rare position only; the reverse holo slot is not modelled
    put(sid, "rare", fill(sid, "rare", t, ["R"]))

# ---------------------------------------------------------------- e-Card / EX
# Holo-sheet share of the rare position (holos + ex per 36-pack box), from the
# box tallies in the research. Reverse-holo copies of holo rares are not here.
EX_RARE_RR = {
    "ecard1": 1 / 3, "ecard2": 0.3061, "ecard3": 0.2909,
    "ex1": 1 / 3, "ex2": 1 / 3, "ex3": 1 / 6 + 4.9 / 36, "ex4": 11.3 / 36,
    "ex5": 12 / 36, "ex6": 11 / 36, "ex7": 11.5 / 36, "ex8": 11.7 / 36,
    "ex9": 12 / 36, "ex10": 11.5 / 36, "ex11": (12 - 1 / 3) / 36, "ex12": 11.65 / 36,
    "ex13": 12 / 36 - 0.012, "ex14": 10.86 / 36, "ex15": 11.75 / 36, "ex16": 12 / 36,
}
EX_RARE_UR = {"ecard3": 1 / 23.6}
for sid, rr in EX_RARE_RR.items():
    t = {"RR": rr}
    sr = real(sid, "SR")
    if sr is not None:
        t["SR"] = sr
    ur = EX_RARE_UR.get(sid, real(sid, "UR"))
    if ur is not None:
        t["UR"] = ur if ur > 0 else TOKEN
        if ur == 0:
            notes[sid].append("UR secret was a box topper; kept at 1 in 1,000 packs")
    put(sid, "rare", fill(sid, "rare", t, ["R"]))
# Expedition's basic Energy came only in theme decks.
put("ecard1", "common", {"C": 1 - (1 - (1 - TOKEN) ** (1 / 5)), "E": 1 - (1 - TOKEN) ** (1 / 5)})
notes["ecard1"].append("basic Energy was theme-deck only; kept at 1 in 1,000 packs")


# ---------------------------------------------------------------- DP / Pt / HGSS / CoL
def numbers(text, label):
    m = re.search(label + r"([^;]*)", text)
    if not m:
        return []
    return [float(x) for x in re.findall(r"(?<![\d.])(0\.\d+)", m.group(1))]


DP_SETS = ["dp1", "dp2", "dp3", "dp4", "dp5", "dp6", "dp7", "pl1", "pl2", "pl3", "pl4",
           "hgss1", "hgss2", "hgss3", "hgss4", "col1"]
SHINING = {"dp7": ["dp7-SH1", "dp7-SH2", "dp7-SH3"], "pl1": ["pl1-SH4", "pl1-SH5", "pl1-SH6"],
           "pl3": ["pl3-SH7", "pl3-SH8", "pl3-SH9"], "pl4": ["pl4-SH10", "pl4-SH11", "pl4-SH12"]}
ROTOM = [f"pl2-RT{n}" for n in range(1, 7)]
ARCEUS = [f"pl4-AR{n}" for n in range(1, 10)]
SHINY_LEGENDS = [f"col1-SL{n}" for n in range(1, 12)]
for sid in DP_SETS:
    s = research[sid]
    rr_basis = s["real"]["RR"]["basis"]
    rare_rr = sum(numbers(rr_basis, r"rare slot:"))
    reverse_rr = numbers(rr_basis, r"reverse slot:")
    t = {"RR": rare_rr}
    ur = real(sid, "UR")
    if ur:
        t["UR"] = ur
    rare_rules = {}
    if sid.startswith("hgss"):
        rare_rules["RR"] = {"exclude": {"rarities": ["Rare Prime"]}}
    if sid == "col1":
        rare_rules["RR"] = {"exclude": {"ids": SHINY_LEGENDS}}
    special_r = SHINING.get(sid, []) + (ROTOM if sid == "pl2" else []) + (ARCEUS if sid == "pl4" else [])
    if special_r:
        rare_rules["R"] = {"exclude": {"ids": special_r}}
    pool_kwargs = {k: v for k, v in rare_rules.items()}
    put(sid, "rare", fill(sid, "rare", t, ["R"], rules=pool_kwargs), rules=rare_rules or None)

    # Reverse slot: measured C / R shares, the holo-rare reverse share, U the rest.
    c_share = s["reverseShares"].get("C")
    r_share = s["reverseShares"].get("R")
    if r_share is None:
        m = re.search(r"reverse-rare share ([\d.]+)", s["real"]["R"]["basis"])
        r_share = float(m.group(1)) if m else None
    u_share = s["reverseShares"].get("U")
    rev_rules, rev_finish = {}, {}
    rev = {}
    if sid.startswith("hgss"):
        # Primes replace the reverse holo. Reverse copies of holo rares share
        # the RR tier but need a reverse finish, so they are left out here.
        rev["RR"] = float(re.search(r"Prime ([\d.]+)", rr_basis).group(1))
        rev_rules["RR"] = {"only": {"rarities": ["Rare Prime"]}}
        notes[sid].append("reverse-holo copies of holo rares not modelled (Primes take the RR tier)")
    elif sid == "col1":
        rev["RR"] = real(sid, "SH")
        rev_rules["RR"] = {"only": {"ids": SHINY_LEGENDS}}
        notes[sid].append("reverse-holo copies of holo rares not modelled (Shiny Legendaries take the RR tier)")
    else:
        rev["RR"] = reverse_rr[0]
        rev_rules["RR"] = {"only": {"rarities": ["Rare Holo"]}}
        rev_finish["RR"] = "reverseHolo"
    if sid == "pl2":
        rev["R"] = 1 / 18
        rev_rules["R"] = {"only": {"ids": ROTOM}}
        rev_finish["R"] = "defaultForCard"
        notes[sid].append("reverse slot R is the Rotom RT subset; reverse-holo Rares not modelled")
    elif sid == "pl4":
        rev["R"] = 0.25 + real(sid, "SH")
        rev_rules["R"] = {"only": {"ids": ARCEUS + SHINING["pl4"]}}
        rev_finish["R"] = "defaultForCard"
        notes[sid].append("reverse slot R is the Arceus AR subset and Shining; reverse-holo Rares not modelled")
    shares = {}
    rest = 1 - sum(rev.values())
    known = {"C": c_share, "R": r_share if "R" not in rev else None, "U": u_share}
    known = {k: v for k, v in known.items() if v is not None}
    unknown = [k for k in ("C", "U", "R") if k not in known and k not in rev]
    scale_known = sum(known.values())
    if unknown:
        leftover = max(rest - scale_known, 0.05)
        base = current(sid, "reverseHolo")
        tot = sum(base[k] for k in unknown)
        for k in unknown:
            known[k] = leftover * base[k] / tot
    total = sum(known.values())
    for k, v in known.items():
        shares[k] = rest * v / total
    shares.update(rev)
    put(sid, "reverseHolo", shares, rules=rev_rules, finishes=rev_finish or None)

# ---------------------------------------------------------------- BW / XY
BW_SETS = ["bw1", "bw2", "bw3", "bw4", "bw5", "bw6", "bw7", "bw8", "bw9", "bw10",
           "xy1", "xy2", "xy3", "xy4", "xy5", "xy6", "xy7", "xy8", "xy9", "xy10", "xy11", "xy12"]
BREAK_PER_BOX = {"xy8": 2.8, "xy9": 2.4, "xy10": 2.4, "xy11": 2.4, "xy12": 2.0}
for sid in BW_SETS:
    s = research[sid]
    t = {}
    for tier in ("RR", "SR", "UR"):
        p = real(sid, tier)
        if p is not None:
            t[tier] = p
    rare_rules = {}
    drop = ["ACE"]
    if sid in BREAK_PER_BOX:
        rare_rules["RR"] = {"exclude": {"rarities": ["Rare BREAK"]}}
    if sid == "xy12":
        t.pop("UR", None)
        drop.append("UR")
    put(sid, "rare", fill(sid, "rare", t, ["R"], drop=drop, rules=rare_rules), rules=rare_rules or None)
    rev = {}
    rev_rules = {}
    ace = real(sid, "ACE")
    if ace:
        rev["ACE"] = ace
    if sid in BREAK_PER_BOX:
        rev["RR"] = BREAK_PER_BOX[sid] / 36
        rev_rules["RR"] = {"only": {"rarities": ["Rare BREAK"]}}
    m = re.search(r"reverse-slot rares ([\d.]+)", s["real"].get("R", {}).get("basis", ""))
    rev_r = float(m.group(1)) if m else None
    base = current(sid, "reverseHolo")
    rest = 1 - sum(rev.values())
    shares = dict(rev)
    if rev_r is not None:
        shares["R"] = rev_r * rest
        cu = rest - shares["R"]
        tot = base["C"] + base["U"]
        shares["C"] = cu * base["C"] / tot
        shares["U"] = cu * base["U"] / tot
    else:
        tot = base["C"] + base["U"] + base["R"]
        for k in ("C", "U", "R"):
            shares[k] = rest * base[k] / tot
    put(sid, "reverseHolo", shares, rules=rev_rules or None)
# Evolutions' five secret rares sit on the uncommon sheet, one copy each of 121.
put("xy12", "uncommon", {"U": 116 / 121, "UR": 5 / 121})

# ---------------------------------------------------------------- Sun & Moon
SM_SETS = ["sm1", "sm2", "sm3", "sm35", "sm4", "sm5", "sm6", "sm7", "sm75", "sm8", "sm9",
           "sm10", "sm11", "sm115", "sm12"]
SM12_CHARACTER = [f"sm12-{n}" for n in range(237, 249)]
for sid in SM_SETS:
    t = {}
    for tier in ("SR", "HR", "UR", "SH"):
        p = real(sid, tier)
        if p is not None:
            t[tier] = p
    no_plain_rare = sid in ("sm35", "sm75")
    rules = {}
    if sid == "sm12":
        t["UR"] = 0.0089
        rules["UR"] = {"exclude": {"ids": SM12_CHARACTER}}
    if no_plain_rare:
        shares = fill(sid, "rare", t, ["RR"], drop=["PR", "R", "RRR"], rules=rules)
    else:
        t["RR"] = real(sid, "RR")
        shares = fill(sid, "rare", t, ["R"], drop=["PR", "RRR"], rules=rules)
    put(sid, "rare", shares, rules=rules or None)
    rev = {}
    rev_rules = {}
    pr = real(sid, "PR")
    if pr:
        rev["PR"] = pr
    if sid == "sm12":
        rev["UR"] = 0.1011
        rev_rules["UR"] = {"only": {"ids": SM12_CHARACTER}}
    if sid == "sm115":
        rev["S"] = real(sid, "S")
        rev["SSR"] = real(sid, "SSR")
    if rev:
        put(sid, "reverseHolo", fill(sid, "reverseHolo", rev, ["C", "U", "R"], rules=rev_rules),
            rules=rev_rules or None)

# ---------------------------------------------------------------- Sword & Shield
SWSH_SETS = ["swsh1", "swsh2", "swsh3", "swsh35", "swsh4", "swsh45", "swsh5", "swsh6", "swsh7",
             "swsh8", "swsh9", "swsh10", "pgo", "swsh11", "swsh12", "swsh12pt5"]
for sid in SWSH_SETS:
    t = {}
    for tier in ("RRR", "SR", "HR", "UR"):
        p = real(sid, tier)
        if p is not None:
            t[tier] = p
    if sid == "pgo":
        # 871 packs: secret rares 3.21% combined; split by the 371-pack tally (12:2).
        t["HR"], t["UR"] = 0.0321 * 12 / 14, 0.0321 * 2 / 14
    no_plain_rare = sid in ("swsh35", "pgo")
    if no_plain_rare:
        shares = fill(sid, "rare", t, ["RR"], drop=["R"])
    else:
        rr = real(sid, "RR")
        if rr is not None:
            t["RR"] = rr
        shares = fill(sid, "rare", t, ["R"])
    put(sid, "rare", shares)
    rev = {}
    for tier in ("A", "K", "CHR", "AR", "SAR", "S", "SSR"):
        p = real(sid, tier)
        if p is not None:
            rev[tier] = p
    put(sid, "reverseHolo", fill(sid, "reverseHolo", rev, ["C", "U", "R"], drop=["RRR"]))

# ---------------------------------------------------------------- Scarlet & Violet / Mega
SV_SETS = ["sv1", "sv2", "sv3", "sv3pt5", "sv4", "sv4pt5", "sv5", "sv6", "sv6pt5", "sv7", "sv8",
           "sv8pt5", "sv9", "sv10", "rsv10pt5", "zsv10pt5", "me1", "me2", "me2pt5", "me3", "me4", "me5"]
for sid in SV_SETS:
    t = {}
    for tier in ("RR", "SR", "MA"):
        p = real(sid, tier)
        if p is not None:
            t[tier] = p
    put(sid, "rare", fill(sid, "rare", t, ["R"], drop=["ACE"]))
    first = {}
    for tier in ("ACE", "S", "SSR"):
        p = real(sid, tier)
        if p:
            first[tier] = p
    if first:
        put(sid, "reverseHolo", fill(sid, "reverseHolo", first, ["C", "U", "R"]))
    hit = {}
    for tier in ("AR", "SAR", "UR", "MUR", "BWR"):
        p = real(sid, tier)
        if p is not None:
            hit[tier] = p
    drop = ["S", "SSR", "MA"]
    put(sid, "reverseHoloHit", fill(sid, "reverseHoloHit", hit, ["C", "U", "R"], drop=drop))

# ---------------------------------------------------------------- 30th Celebration
RGB = ["cel30-R_RGB", "cel30-G_RGB", "cel30-B_RGB"]
put("cel30", "allFoil", {"C": 1.0})
put("cel30", "classicCollection",
    {"AR": 0.1972, "CHR": 0.1015, "FUR": 0.0003, "C": 1 - 0.1972 - 0.1015 - 0.0003},
    rules={"FUR": {"only": {"ids": RGB}}})
put("cel30", "celebrationsRare",
    {"RR": 0.25, "SAR": 0.0488, "FUR": 0.0085, "R": 1 - 0.25 - 0.0488 - 0.0085},
    rules={"FUR": {"exclude": {"ids": RGB}}})
notes["cel30"].append("RGB Mew is drawn in position 3 so it can keep its own 1-in-3,300 rate")

result = {"version": "2026-10-08", "sets": {k: out[k] for k in sorted(out)}}
OUT.write_text(json.dumps(result, indent=1, ensure_ascii=False) + "\n")
for sid in sorted(notes):
    for note in notes[sid]:
        print(f"{sid}: {note}")
print(f"wrote {len(out)} sets")
