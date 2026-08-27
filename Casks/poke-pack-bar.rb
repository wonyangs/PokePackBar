cask "poke-pack-bar" do
  version "0.1.2"
  sha256 "9b11ec652201b88572cd61753c4df13a40957393fd101c390f5df6e154b57c6c"

  url "https://github.com/wonyangs/PokePackBar/releases/download/v#{version}/PokePackBar.zip"
  name "PokePackBar"
  desc "Turn your AI coding tokens into Pokemon card packs"
  homepage "https://github.com/wonyangs/PokePackBar"

  # 내부 배포라 공증(notarization)을 하지 않는다. Gatekeeper 격리 속성을 떼어
  # 테스터가 매번 우클릭으로 열지 않게 한다.
  postflight do
    system_command "/usr/bin/xattr",
                   args: ["-dr", "com.apple.quarantine", "#{appdir}/PokePackBar.app"],
                   sudo: false
  end

  app "PokePackBar.app"

  zap trash: [
    "~/Library/Application Support/PokePackBar",
    "~/Library/Logs/PokePackBar.log",
  ]
end
