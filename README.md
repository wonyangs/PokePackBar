# PokePackBar

AI 코딩 도구로 태운 토큰을 포켓몬 카드팩으로 바꿔 주는 macOS 메뉴바 앱.

코딩하면 토큰이 쌓이고, 쌓인 토큰으로 카드팩을 산다. 팩을 뜯어 카드를 모은다.

## 어떻게 동작하나

Claude Code, Codex, Gemini CLI 등 11개 도구의 로컬 로그에서 사용량을 읽는다.
별도로 실행할 것은 없고, 외부로 데이터를 보내지 않는다.

- **상점** — 세트별 카드팩을 산다. 1999년 초판부터 최신 세트까지 10종
- **팩** — 산 팩을 뜯는다. 한 장씩 크게 나오고, 등급에 따라 카드 뒤에서 빛이 퍼진다
- **컬렉션** — 모은 카드를 본다. 세트와 등급으로 거르고, 눌러서 크게 본다

공식 사용 한도(5시간·주간)를 다 채우면 보너스 팩을 하나 받는다.

등급은 국내 커뮤니티에서 쓰는 약칭을 따른다 — C · U · R · RR · RRR · AR · SR · SAR · UR.

## 설치

```bash
brew tap wonyangs/tap
brew install --cask poke-pack-bar
```

macOS 14 이상.

업데이트는 앱 안의 업데이트 버튼을 누르거나 `brew upgrade --cask poke-pack-bar`.

## 개발

```bash
swift build          # 빌드
swift test           # 테스트
./scripts/build-app.sh   # .app 조립 후 /Applications 설치
```

배포 절차는 [RELEASE.md](RELEASE.md), 코드 규약은 [CLAUDE.md](CLAUDE.md).

카드 이미지는 앱에 넣지 않고 필요할 때 받아서 캐시한다. 카드 목록과 판매 세트의
팩 아트만 번들에 들어 있다.

## 출처와 라이선스

[chattymin/PokeTokenBar](https://github.com/chattymin/PokeTokenBar) 에서 갈라져 나왔다.
사용량을 읽는 부분은 원본의 것을 쓰고, 포켓몬 육성 기능을 걷어낸 자리에 카드 게임을 넣었다.
MIT 라이선스이며 원저작권 고지를 유지한다.

카드 데이터는 [Pokémon TCG API](https://pokemontcg.io), 팩 아트는
[Pokemon Symbols](https://pokesymbols.com) 를 출처로 한다.

비공식 비상업 팬 프로젝트다. Pokémon 과 관련 상표는 The Pokémon Company International 의 것이다.
