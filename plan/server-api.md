# 서버 API 명세

스택은 **Python + Hatch**. 서버 API 를 먼저 만들고, 이미지를 옮기고, 앱 연동은 나중이다.

이 문서는 **엔드포인트를 기능별로 정의한다.** 호스트와 비용은 [server.md](server.md) 에 있다.

## 0. 공통 규약

- 모든 응답은 `application/json`. 시각은 유닉스 초(정수)
- 금액은 **토큰(정수)** 로 주고받는다. 원화 환산은 앱이 한다 — 환율이 시세 파일에 있다
- 인증은 `Authorization: Bearer <세션 토큰>`. 정적 배급만 인증 없이 연다
- 상태를 바꾸는 응답은 **바뀐 뒤의 지갑을 함께 싣는다.** 앱이 다시 물어보지 않게 한다

```json
"wallet": {
  "balance": 412000000,        // 잔액(토큰)
  "usedSinceInstall": 1500000000,
  "spentTokens": 1295815982,
  "refundedTokens": 300000,
  "perkTokens": 434135448
}
```

오류는 코드와 사람이 읽을 문구를 함께 준다.

```json
{ "error": { "code": "insufficient_funds", "message": "잔액이 모자랍니다", "need": 40500 } }
```

| 코드 | 언제 |
|---|---|
| `unauthorized` | 세션 없음·만료 |
| `insufficient_funds` | 잔액 부족 |
| `no_such_set` · `no_such_card` · `no_such_dex` | 모르는 id |
| `no_packs` | 열 팩이 없음 |
| `nothing_to_sell` | 팔 중복이 없음 |
| `already_claimed` | 이미 받은 도감·선물 |
| `save_conflict` | 세이브 버전 불일치 (409) |

## 1. 정적 배급

앱 재배포 없이 시세·인덱스를 갈아 끼우는 것이 목적이다. 인증 없이 연다.

### `GET /v1/manifest`

앱이 기동할 때 이것만 받아 보고, 판번호가 다른 파일만 내려받는다.

```json
{
  "version": 1,
  "data": {
    "cardIndex":  { "revision": "2026-09-01T3", "url": "…/card-index.2026090103.json",
                    "bytes": 572416, "sha256": "…" },
    "cardPrices": { "revision": "2026-09-01",   "url": "…", "bytes": 309908, "sha256": "…" },
    "cardNamesKo":{ "revision": "2026-09-01",   "url": "…", "bytes": 518254, "sha256": "…" },
    "dex":        { "revision": "2026-09-01",   "url": "…", "bytes": 15856,  "sha256": "…" }
  },
  "images": {
    "cardBase": "https://…/cards",      // <base>/<세트ID>/<카드ID>.webp
    "packBase": "https://…/cards/packs" // <base>/<세트ID>.webp
  },
  "minimumAppVersion": "0.6.0"
}
```

- `revision` 이 같으면 앱은 받지 않는다. `sha256` 으로 받은 것을 검사한다
- 이미지는 API 를 타지 않는다. 주소만 알려 주고 앱이 저장소에서 직접 받는다
- `minimumAppVersion` 보다 낮은 앱에는 갱신을 강제할 수 있게 남겨 둔다

### `GET /v1/data/{name}`

`name` 은 `card-index` · `card-prices` · `card-names-ko` · `dex`.

**서버는 파일을 내주지 않는다. 저장소로 302 한다.** 1.4MB 를 서버가 흘려보내면 집 회선을
쓰고, 앞단 캐시도 못 탄다. 판번호가 붙은 주소는 내용이 절대 안 바뀌므로 저장소가
`Cache-Control: immutable` 로 영구 캐시할 수 있다.

## 2. 인증

### `POST /v1/auth/apple`

```json
요청  { "identityToken": "<Sign in with Apple JWT>" }
응답  { "session": "<토큰>", "expiresAt": 1790000000, "userID": "u_7f3a…", "isNew": true }
```

### `POST /v1/auth/refresh` · `POST /v1/auth/signout`

세션 연장과 파기. 응답은 위와 같은 모양.

## 3. 상태

**모든 상태는 서버가 갖는다.** 앱은 상태를 들고 있지 않고, 서버에 물어 그리고 서버에
시켜서 바꾼다. 그래서 「세이브를 올린다」는 동작이 없다 — 올릴 세이브가 앱에 없다.

이 한 줄이 나머지 절을 정한다.

- 팩을 사고 열고 카드를 파는 것은 전부 **서버가 굴린다**. 앱은 결과를 받아 보여 준다
- 앱이 로컬에 두는 것은 **보던 화면과 캐시뿐**이다. 지워도 잃는 것이 없다
- 세이브 충돌이라는 개념이 없다. 두 Mac 이 같은 상태를 본다
- 규칙(확률표·경제·도감)도 서버에 하나만 있다. 앱은 공시용으로 읽기만 한다

### `GET /v1/state`

앱이 기동할 때 한 번, 그리고 되살아날 때 받는다. 화면을 그리는 데 필요한 전부다.

```json
{
  "revision": 128,
  "wallet": { "balance": 412000000, "usedSinceInstall": 1500000000,
              "spentTokens": 1295815982, "refundedTokens": 300000,
              "perkTokens": 434135448 },
  "packs":  [ { "setID": "me1", "count": 1 } ],
  "cards":  [ { "id": "base1-4", "count": 3, "firstAt": 1788000000 } ],
  "oripa":  { "serial": 3, "remaining": 87 },
  "dex":    { "claimed": [ "base1-holo" ],
              "perks": { "tokenGain": 0.083, "packDiscount": 0.108,
                         "dustBonus": 0.150, "hitOdds": 0.042 } },
  "favoriteCardID": "base1-4",
  "stats":  { "packsOpened": 228, "cardsDisenchanted": 807 }
}
```

`revision` 은 상태가 바뀔 때마다 오른다. 모든 변경 응답이 새 `revision` 을 싣는다 —
앱은 그것으로 제 화면이 최신인지 안다.

**앱에 상태를 두지 않으므로 낙관적 갱신도 하지 않는다.** 팩을 사면 응답이 올 때까지
버튼이 기다린다. 네트워크가 없으면 못 산다 — 그것이 「서버가 상태를 갖는다」의 값이다.

## 4. 재화

### `POST /v1/usage/report`

앱이 로컬 로그를 읽어 오늘치를 신고한다.

```json
요청  { "date": "2026-09-01",
       "byProvider": { "claude_code": 246814179, "codex": 168840465 } }
응답  { "accrued": 12000000, "wallet": { … } }
```

- 같은 날 같은 프로바이더는 **늘어난 만큼만** 적립한다(앱의 기준점 규칙 그대로)
- **신고를 그대로 믿는다.** 상한도 이상치 검사도 두지 않는다

막을 수 없는 것을 막는 시늉을 하지 않는다는 뜻이다. 로그가 사용자 Mac 에 있어 서버는
그것을 볼 수 없고, 상한을 걸어 봐야 상한만큼은 여전히 조작된다. 대신 **랭킹을 낸다면
사용량에 기대지 않는 지표**(도감 완성 수, 세트 수집률)로 잡는다.

### `GET /v1/wallet`

지갑만 다시 읽는다. 응답은 공통 규약의 `wallet` 과 같다.

## 5. 팩

### `GET /v1/packs`

```json
{
  "owned": [ { "setID": "me1", "count": 1 } ],          // 최신 세트가 앞
  "prices": [ { "setID": "sv10", "price": 34469000, "cardsPerPack": 10 } ],
  "perks": { "packDiscount": 0.019 }                     // 값에 이미 반영돼 있다
}
```

### `POST /v1/packs/buy`

```json
요청  { "setID": "me1", "count": 2 }
응답  { "bought": 2, "unitPrice": 40500000, "total": 81000000,
       "owned": { "setID": "me1", "count": 3 }, "wallet": { … } }
```

총액을 **한 번에** 차감한다. 개당 차감하면 중간에 실패했을 때 몇 개를 준 건지 흐려진다.

### `POST /v1/packs/open`

```json
요청  { "setID": "sv10" }
응답  {
  "cards": [ { "id": "sv10-231", "tier": "SAR", "isNew": true } ],
  "isGodPack": false,
  "pity": 2,                                   // 이 세트의 다음 천장 카운터
  "completions": [ { "dexID": "sv10-rocket-boss", "tier": 4 } ],
  "owned": { "setID": "sv10", "count": 10 },
  "wallet": { … }
}
```

- 카드는 **뽑힌 순서**로 준다. 연출 순서(등급 오름차순)는 앱이 정한다
- 보유량을 먼저 줄이고 뽑는다. 실패하면 팩도 카드도 그대로다
- 천장은 세트별로 센다. 갓팩은 1/300

### `GET /v1/packs/{setID}/odds`

상점 확률 공시. 그 세트에 **있는 등급만** 싣는다.

```json
{ "setID": "sv10", "cardsPerPack": 10, "era": "scarletViolet",
  "odds": [ { "tier": "UR", "probability": 0.0020 } ],
  "guaranteedSlots": 1, "pityThreshold": 5, "godPackOneIn": 300 }
```

## 6. 카드

### `GET /v1/cards`

```json
{ "owned": [ { "id": "base1-4", "count": 3, "firstAt": 1788000000 } ],
  "collectionValueUSD": 12345.67 }
```

전체 카드 목록은 주지 않는다 — 그건 `card-index` 정적 파일이다.

### `POST /v1/cards/sell`

```json
요청  { "cardID": "base1-4", "count": 2 }
응답  { "sold": 2, "refund": 2377200000, "remaining": 1, "wallet": { … } }
```

**마지막 한 장은 팔 수 없다.** `count` 가 중복분을 넘으면 `nothing_to_sell`.

### `POST /v1/cards/sell-bulk`

```json
요청  { "maxWon": 1000, "setID": null, "tier": null }
응답  { "kinds": 164, "copies": 807, "refund": 12000000,
       "soldIDs": [ … ], "wallet": { … } }
```

`setID`·`tier` 는 앱 화면의 필터를 그대로 넘기는 자리다 — **화면에 안 보이는 카드가
팔리면 안 된다.** 미리보기는 같은 요청에 `"dryRun": true` 를 붙인다.

### `PUT /v1/cards/favorite`

```json
요청  { "cardID": "base1-4" }   // null 이면 해제
응답  { "cardID": "base1-4" }
```

## 7. 오리파

### `GET /v1/oripa`

```json
{ "serial": 3, "remaining": 87, "slots": [ "sv8pt5-1", … ],
  "slotPrice": 799700000,
  "remainingByTier": [ { "tier": "UR", "count": 13 } ] }
```

박스 안을 **전부 공개한다.** 그것이 이 뽑기의 약속이다.

### `POST /v1/oripa/pull`

```json
응답  { "card": { "id": "sv8pt5-32", "tier": "SAR", "isNew": true },
       "remaining": 86,
       "completions": [ … ], "wallet": { … } }
```

빈 박스에서 뽑으면 새 박스를 채우고 뽑는다. `serial` 이 오른다.

### `POST /v1/oripa/replace`

값은 안 받지만 되돌릴 수 없다. 응답은 `GET /v1/oripa` 와 같다.

## 8. 도감

### `GET /v1/dex`

```json
{ "entries": [ { "dexID": "base1-holo", "tier": 5,
                 "ownedCount": 12, "total": 16, "missing": [ … ],
                 "isFilled": false, "claimed": false } ],
  "perks": { "tokenGain": 0.083, "packDiscount": 0.108,
             "dustBonus": 0.150, "hitOdds": 0.042 },
  "caps": { "tokenGain": 0.25, "packDiscount": 0.15,
            "dustBonus": 0.15, "hitOdds": 0.20 } }
```

도감의 이름·구성 카드·보상은 `dex.json` 정적 파일에 있다. 여기서는 **내 진행도**만 준다.

### `POST /v1/dex/claim`

```json
요청  { "dexID": "base1-holo" }
응답  { "dexID": "base1-holo",
       "reward": { "packs": 10, "setID": "base1",
                   "perks": [ { "kind": "packDiscount", "value": 0.055 } ] },
       "perks": { … 갱신된 총합 … }, "wallet": { … } }
```

완성되지 않았으면 `no_such_dex`, 이미 받았으면 `already_claimed`.

## 9. 보상

### `GET /v1/grants`

아직 안 알린 보상. 앱이 알림을 띄우고 `POST /v1/grants/ack` 로 지운다.

```json
{ "gifts": [ { "id": "v0.6.0-patch", "tokens": 213370000,
               "packsPerSet": 0, "kind": "celebration" } ],
  "bonusPacks": [ { "windowKey": "claude_5h", "windowName": "Claude 5시간 세션",
                    "setID": "sv10", "count": 10 } ] }
```

- **선물은 id 로 한 번만 나간다.** 버전이 아니라 보상마다 id 를 붙인다
- 보너스 팩은 사용 한도 창을 채웠을 때 나온다. 창마다 한 번씩

### `POST /v1/grants/ack`

```json
요청  { "giftIDs": [ "v0.6.0-patch" ], "windowKeys": [ "claude_5h" ] }
```

## 10. 규칙은 어디에 있나

`packs/open` · `cards/sell` · `oripa/pull` · `dex/claim` 이 굴리는 규칙은 전부 서버가
가져야 한다. 그 모델의 절반은 **이미 파이썬에 있다** — `scripts/build_dex.py` 에 시대별
칸 구성, 등급 가중치, 갓팩·특별 팩 표, 경제 상수가 앱과 같은 값으로 들어 있다.

서버의 `rules/` 는 그것을 옮겨 심는 자리이고, 옮긴 뒤에는 파이프라인 스크립트도 그 모듈을
import 해서 쓴다 — 지금처럼 두 벌로 두지 않는다.

| 모듈 | 담는 것 | 지금 어디에 |
|---|---|---|
| `rules/economy.py` | 토큰 환산, 100원 단위, 팩값·판매값 | `MarketEconomy.swift` · `build_dex.py` |
| `rules/packs.py` | 시대 구분, 칸 구성, 확률표, 뽑기, 천장, 갓팩 | `PackOpening.swift` · `build_dex.py` |
| `rules/oripa.py` | 값 구간 박스 구성, 슬롯값 | `Oripa.swift` |
| `rules/dex.py` | 완성 판정, 혜택 합산과 상한 | `DexProgress.swift` · `DexIndex.swift` |
| `rules/rng.py` | 씨앗 난수 | `SeededGenerator` |

## 11. 정한 것

- **정적 파일은 302.** 서버가 흘려보내지 않는다
- **`usage/report` 는 신고를 그대로 믿는다.** 상한 없음
- **모든 상태를 서버가 갖는다.** 세이브 동기화도 충돌도 없다 — 앱에 상태가 없다

## 12. 구현 상태

서버 API 를 `pokemon-card/server` 에 구현했다. 앱은 아직 부르지 않는다.

### 만든 것

| 자리 | 담은 것 |
|---|---|
| `rules/` | 등급 사다리·시대 구분·확률표·뽑기·천장·갓팩, 경제, 오리파, 도감, 씨앗 난수 |
| `catalog.py` | 정적 데이터를 읽어 세트별 카드 풀·오리파 선반·팩값을 세워 둔다 |
| `store/` | SQLite. 상태·팩·카드·천장·수령·사용량 신고·보상·한도 창 |
| `service.py` | 규칙을 상태에 적용한다. 함수 하나가 화면의 버튼 하나다 |
| `api/app.py` | 이 문서의 1~9절 엔드포인트 전부 |

명세와 다르게 간 곳은 세 군데다.

- `POST /v1/usage/report` 가 **한도 창 상태를 함께 받는다.** 서버는 사용자 Mac 의 한도를
  볼 수 없어 보너스 팩 판정을 할 수 없다. 신고를 그대로 믿기로 한 것과 같은 결론이다
- `POST /v1/oripa/pull` 응답에 `serial` 을 실었다. 빈 박스에서 뽑으면 새 박스가 들어오는데,
  앱이 그때 박스가 바뀐 것을 알 방법이 없었다
- 오류 코드에 `save_conflict` 가 없다. 세이브가 없으니 충돌도 없다

### 규칙은 한 벌이 됐다

`scripts/build_dex.py` 가 갖고 있던 확률표·경제 상수·도감 상한을 지우고 서버 모듈을
import 하게 바꿨다. 같은 `dex.json` 이 나오는 것을 확인했다. 앱(Swift) 쪽은 API 연동 때
정리한다 — 그때까지는 두 벌이고, 테스트가 값을 대조한다.

### 남은 것

- **Apple 토큰을 검증하지 않는다.** 지금은 토큰 문자열이 곧 사용자다. 공개 전에 Apple
  공개키로 서명을 검증해야 한다
- 정적 파일을 올릴 저장소가 아직 없다. 302 가 가리키는 주소는 설정값이다
- 이미지 이전과 앱 연동
