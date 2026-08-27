#!/bin/bash
# 잔액을 넉넉히 채운 격리 상태로 앱을 띄운다. 실제 세이브는 건드리지 않는다.
#
# 설치 시점부터 누적하는 설계라 갓 설치한 상태의 잔액은 0 이다. 구매·개봉·수집을
# 바로 시험하려면 잔액이 필요하므로, WalletStore 의 PPB_STATE_DIR 격리를 그대로 쓴다.
set -euo pipefail
cd "$(dirname "$0")/.."

APP="/Applications/PokePackBar.app"
STATE_DIR="${PPB_DEMO_DIR:-$HOME/Library/Application Support/PokePackBar-demo}"
BALANCE="${1:-5000000000}"   # 기본 50억 — 팩 200개어치

[ -d "$APP" ] || { echo "앱이 없다. ./scripts/build-app.sh 를 먼저 실행한다." >&2; exit 1; }

mkdir -p "$STATE_DIR"
cat > "$STATE_DIR/game-state.json" <<JSON
{
  "installBaselineSet": true,
  "usedSinceInstall": $BALANCE,
  "spentTokens": 0,
  "lastDate": "",
  "packs": {},
  "cards": {},
  "packsOpened": 0,
  "packGrantTier": {},
  "packGrantSeeded": true,
  "language": "ko"
}
JSON

pkill -x PokePackBar 2>/dev/null || true
sleep 1
PPB_STATE_DIR="$STATE_DIR" open -n "$APP" --args --demo

echo "데모 실행: 잔액 $(printf "%'d" "$BALANCE") 토큰"
echo "  상태 파일: $STATE_DIR/game-state.json"
echo "  되돌리기:  pkill -x PokePackBar && open $APP"
