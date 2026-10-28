cask "poke-pack-bar" do
  version "0.25.0"
  sha256 "7e6e164eeff6d90475c0fcced62bf2287f108413c504cca131e8c22c5fb45965"

  url "https://github.com/wonyangs/PokePackBar/releases/download/v#{version}/PokePackBar.zip"
  name "PokePackBar"
  desc "Turn your AI coding tokens into Pokemon card packs"
  homepage "https://github.com/wonyangs/PokePackBar"

  depends_on macos: :sonoma

  app "PokePackBar.app"

  # 내부 배포라 공증(notarization)을 하지 않는다. Gatekeeper 격리 속성을 떼어
  # 테스터가 매번 우클릭으로 열지 않게 한다.
  postflight_steps do
    run "/usr/bin/xattr", args: ["-dr", "com.apple.quarantine", "{{appdir}}/PokePackBar.app"]
  end

  zap trash: [
    "~/Library/Application Support/PokePackBar",
    "~/Library/Logs/PokePackBar.log",
  ]
end
