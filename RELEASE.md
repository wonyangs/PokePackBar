# 내부 배포

테스터에게 Homebrew 로 배포하고, 앱의 업데이트 버튼으로 갱신받게 한다.

## 처음 한 번만

1. **저장소를 정한다.** `Sources/PokePackBar/Core/AppLinks.swift` 의 `githubRepo` 와
   `brewTap` 을 채운다. 이 값이 단일 출처다 — 설정 화면 링크, 업데이트 확인,
   릴리스 스크립트가 모두 여기를 본다.

2. **tap 저장소를 만든다.** 이름은 `homebrew-tap` 이어야 한다.
   Homebrew 가 `<소유자>/tap` 을 `<소유자>/homebrew-tap` 으로 찾는다.

3. **서명 신원을 만든다.** `./scripts/create-signing-cert.sh`
   없이도 배포는 되지만 ad-hoc 서명이라 빌드마다 Keychain 승인을 다시 묻는다.

## 매 배포

```bash
./scripts/release-internal.sh 0.2.0
```

테스트 → 버전 범프 → 빌드 → zip → 체크섬 → cask 갱신까지 한다.
그 뒤 계정이 필요한 세 단계(커밋·태그, 릴리스 업로드, tap push)는
스크립트가 명령을 출력하고 사람이 실행한다.

## 테스터

```bash
brew tap <소유자>/tap
brew install --cask poke-pack-bar
```

갱신은 앱의 업데이트 버튼을 누르거나 `brew upgrade --cask poke-pack-bar`.

## 알아 둘 것

**공증하지 않는다.** 내부 배포라 Apple 공증을 거치지 않으므로 cask 가 설치 후
격리 속성을 떼어 낸다. 이게 없으면 테스터가 매번 우클릭으로 열어야 한다.

**zip 은 `ditto` 로 묶는다.** 일반 `zip` 은 심볼릭 링크와 리소스 포크를 잃어
코드 서명이 깨진다.

**업데이트 버튼은 brew 로 설치했을 때만 brew 를 쓴다.** 그 외에는 릴리스 페이지를 연다.
