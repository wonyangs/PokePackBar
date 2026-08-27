#!/usr/bin/env bash
#
# release-internal.sh — 내부 테스터 배포용 산출물 생성.
#
# 하는 일: 테스트 → 버전 범프 → 빌드 → zip → sha256 → cask 갱신.
# 하지 않는 일: GitHub 릴리스 발행과 tap push. 그 두 개는 계정이 필요하므로
#               스크립트가 명령을 출력하고, 사람이 확인한 뒤 직접 실행한다.
#
# 사용:
#   ./scripts/release-internal.sh 0.2.0
#
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="${1:-}"
[[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || {
  echo "사용법: ./scripts/release-internal.sh <x.y.z>" >&2; exit 1; }

APP_NAME="PokePackBar"
CASK_FILE="Casks/poke-pack-bar.rb"
PREV=$(grep -o 'VERSION="[0-9.]*"' scripts/build-app.sh | head -1 | tr -d 'VERSION="')

# AppLinks 가 단일 출처다. 여기서 다시 적지 않고 읽어 온다 —
# 두 곳에 적으면 배포 대상과 앱이 확인하는 곳이 갈라진다.
REPO=$(grep -o 'githubRepo: String? = "[^"]*"' Sources/PokePackBar/Core/AppLinks.swift \
       | sed 's/.*= "//;s/"//' || true)
if [[ -z "$REPO" ]]; then
  echo "✗ AppLinks.githubRepo 가 비어 있다. 배포할 저장소를 먼저 정한다." >&2
  echo "  Sources/PokePackBar/Core/AppLinks.swift 에서 githubRepo 를 설정하세요." >&2
  exit 1
fi

echo "=== $APP_NAME 내부 릴리스 $PREV → $VERSION ==="
echo "    저장소 $REPO"

echo "▶ 1/5 테스트"
swift test >/dev/null
echo "  ✓ 통과"

echo "▶ 2/5 버전 범프"
sed -i '' "s/^VERSION=\"$PREV\"/VERSION=\"$VERSION\"/" scripts/build-app.sh
grep -q "VERSION=\"$VERSION\"" scripts/build-app.sh || { echo "✗ 범프 실패" >&2; exit 1; }

echo "▶ 3/5 빌드"
./scripts/build-app.sh >/dev/null
echo "  ✓ /Applications 에 설치됨"

echo "▶ 4/5 zip + 체크섬"
rm -f "build/$APP_NAME.zip"
# ditto 로 묶는다 — zip 은 심볼릭 링크와 리소스 포크를 잃어 서명이 깨진다.
ditto -c -k --sequesterRsrc --keepParent "build/$APP_NAME.app" "build/$APP_NAME.zip"
SHA=$(shasum -a 256 "build/$APP_NAME.zip" | cut -d' ' -f1)
echo "  $(du -h "build/$APP_NAME.zip" | cut -f1)  sha256 ${SHA:0:16}…"

echo "▶ 5/5 cask 갱신"
mkdir -p Casks
cat > "$CASK_FILE" <<CASK
cask "poke-pack-bar" do
  version "$VERSION"
  sha256 "$SHA"

  url "https://github.com/$REPO/releases/download/v#{version}/$APP_NAME.zip"
  name "$APP_NAME"
  desc "Turn your AI coding tokens into Pokemon card packs"
  homepage "https://github.com/$REPO"

  # 내부 배포라 공증(notarization)을 하지 않는다. Gatekeeper 격리 속성을 떼어
  # 테스터가 매번 우클릭으로 열지 않게 한다.
  postflight do
    system_command "/usr/bin/xattr",
                   args: ["-dr", "com.apple.quarantine", "#{appdir}/$APP_NAME.app"],
                   sudo: false
  end

  app "$APP_NAME.app"

  zap trash: [
    "~/Library/Application Support/$APP_NAME",
    "~/Library/Logs/$APP_NAME.log",
  ]
end
CASK
echo "  ✓ $CASK_FILE"

cat <<NEXT

── 남은 단계 (직접 실행) ─────────────────────────────────────────────
계정이 필요한 작업이라 스크립트가 대신하지 않는다.

1) 버전 커밋과 태그
   git add scripts/build-app.sh $CASK_FILE
   git commit -m "release: bump version to $VERSION"
   git tag v$VERSION && git push origin HEAD --tags

2) 릴리스에 zip 올리기 (웹 또는 개인 계정의 gh)
   https://github.com/$REPO/releases/new?tag=v$VERSION
   첨부: build/$APP_NAME.zip

3) tap 저장소에 cask 반영
   $CASK_FILE 를 tap 저장소의 Casks/ 로 복사하고 push

테스터 설치:
   brew tap <소유자>/tap && brew install --cask poke-pack-bar
업데이트:
   앱의 업데이트 버튼, 또는 brew upgrade --cask poke-pack-bar
──────────────────────────────────────────────────────────────────
NEXT
