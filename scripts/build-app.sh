#!/bin/bash
# PokePackBar.app 번들 조립 + /Applications 설치
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="0.1.2"
APP_NAME="PokePackBar"
BUILD_DIR="build"
# 원본과 겹치면 로그인 항목·Keychain ACL·LaunchServices 상태가 섞인다.
# 공개 배포 전에 본인 도메인으로 바꾼다.
BUNDLE_ID="dev.local.pokepackbar"
APP="$BUILD_DIR/$APP_NAME.app"

echo "==> swift build -c release"
swift build -c release

echo "==> $APP 조립"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp ".build/release/$APP_NAME" "$APP/Contents/MacOS/$APP_NAME"
# 심볼 strip — 릴리스 바이너리 1.84MB → 0.80MB(-57%). codesign 전에 수행(서명 무효화 방지).
strip -rSTx "$APP/Contents/MacOS/$APP_NAME" 2>/dev/null || strip -rSx "$APP/Contents/MacOS/$APP_NAME"
cp assets/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"

# SPM 리소스 번들 — 카드 목록이 여기 들어 있다. Bundle.module 이 Contents/Resources 에서 찾는다.
# 빼먹으면 빌드도 테스트도 통과하는데(테스트는 .build 에서 직접 읽는다) 설치된 앱만
# "카드 목록을 불러올 수 없어요" 가 된다. 그래서 아래에서 존재를 확인한다.
cp -R ".build/release/${APP_NAME}_${APP_NAME}.bundle" "$APP/Contents/Resources/"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key><string>$BUNDLE_ID</string>
    <key>CFBundleName</key><string>$APP_NAME</string>
    <key>CFBundleExecutable</key><string>$APP_NAME</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>$VERSION</string>
    <key>CFBundleVersion</key><string>$VERSION</string>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>CFBundleIconFile</key><string>AppIcon</string>
    <key>LSUIElement</key><true/>
    <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST

# 크래시/OOM(exit≠0) 시 자동 재실행 LaunchAgent(KeepAlive) — SMAppService.agent 가 등록해 launchd 가
# 워치독으로 동작. 정상 종료(exit 0: 사용자 종료·업데이트)엔 재실행 안 함(SuccessfulExit=false).
# ProgramArguments 는 brew 설치 경로(/Applications) 고정. codesign 전에 생성해 서명 seal 에 포함.
mkdir -p "$APP/Contents/Library/LaunchAgents"
cat > "$APP/Contents/Library/LaunchAgents/$BUNDLE_ID.login.plist" <<AGENT
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key><string>$BUNDLE_ID.login</string>
    <key>ProgramArguments</key>
    <array>
        <string>/Applications/$APP_NAME.app/Contents/MacOS/$APP_NAME</string>
    </array>
    <key>RunAtLoad</key><true/>
    <key>KeepAlive</key>
    <dict>
        <key>SuccessfulExit</key><false/>
    </dict>
    <key>ThrottleInterval</key><integer>10</integer>
    <key>LimitLoadToSessionType</key><string>Aqua</string>
    <key>ProcessType</key><string>Interactive</string>
</dict>
</plist>
AGENT

echo "==> 리소스 확인"
# 서명 전에 확인한다 — 서명 후에 넣으면 서명이 깨진다.
CARD_INDEX="$APP/Contents/Resources/${APP_NAME}_${APP_NAME}.bundle/card-index.json"
if [ ! -f "$CARD_INDEX" ]; then
    echo "   \u2717 카드 목록이 번들에 없다: $CARD_INDEX" >&2
    echo "     Package.swift 의 resources 선언과 이 스크립트의 복사 단계를 확인한다." >&2
    exit 1
fi
echo "   card-index.json $(wc -c < "$CARD_INDEX" | tr -d ' ') bytes"

# 팩 아트 — 판매 세트 수만큼 있어야 한다. 빠지면 상점이 빈 상자로 뜬다.
PACK_DIR="$APP/Contents/Resources/${APP_NAME}_${APP_NAME}.bundle/packs"
PACK_COUNT=$(ls "$PACK_DIR"/*.webp 2>/dev/null | wc -l | tr -d ' ')
EXPECTED_PACKS=$(ls Sources/PokePackBar/Resources/packs/*.webp | wc -l | tr -d ' ')
if [ "$PACK_COUNT" != "$EXPECTED_PACKS" ]; then
    echo "   ✗ 팩 아트가 $PACK_COUNT/$EXPECTED_PACKS 개만 들어갔다: $PACK_DIR" >&2
    exit 1
fi
echo "   팩 아트 ${PACK_COUNT}종"

# 조립된 앱에게 직접 물어본다. 위 검사는 "파일이 거기 있나" 이고, 이건 "앱이 그걸 여나" 다.
# 앱이 보는 위치와 스크립트가 검사하는 위치가 어긋나 배포된 적이 있어 둘 다 둔다.
if ! VERIFY_OUT=$("$APP/Contents/MacOS/$APP_NAME" --verify-resources 2>&1); then
    echo "   ✗ 조립된 앱이 리소스를 열지 못한다: $VERIFY_OUT" >&2
    exit 1
fi
echo "   $VERIFY_OUT"

echo "==> codesign"
SIGN_IDENTITY="${CODESIGN_IDENTITY:-PokePackBar Local}"
# 안정적 Keychain ACL 을 위해서는 인증서 존재가 아니라 유효한 codesigning identity 가 필요하다.
if security find-identity -v -p codesigning | grep -F "\"$SIGN_IDENTITY\"" >/dev/null; then
    # 안정적 자체 서명 신원 → 재빌드해도 Keychain "항상 허용" 유지
    codesign --force -s "$SIGN_IDENTITY" "$APP"
else
    # 인증서 없음 → ad-hoc (빌드마다 cdhash 변경 = Keychain 재프롬프트 가능)
    if [[ "${PTB_REQUIRE_STABLE_SIGN:-0}" == "1" ]]; then
        # 릴리스 경로(release.sh 가 세팅). ad-hoc 릴리스는 사용자 Keychain 승인을 깨므로 절대 금지.
        echo "   ✗ PTB_REQUIRE_STABLE_SIGN=1 인데 '$SIGN_IDENTITY' 유효 identity 없음 → ad-hoc 금지, 중단." >&2
        echo "     ./scripts/create-signing-cert.sh 실행 후 다시 시도하세요." >&2
        exit 1
    fi
    echo "   ('$SIGN_IDENTITY' 유효 codesigning identity 없음 → ad-hoc 서명 — 로컬 개발용)"
    echo "   반복 Keychain 허용 프롬프트를 줄이려면 ./scripts/create-signing-cert.sh 실행 후 다시 빌드하세요."
    codesign --force -s - "$APP"
fi

echo "==> 기존 인스턴스 종료 + /Applications 설치"
pkill -x "$APP_NAME" 2>/dev/null || true
rm -rf "/Applications/$APP_NAME.app"
cp -R "$APP" /Applications/

echo "완료: open /Applications/$APP_NAME.app"
