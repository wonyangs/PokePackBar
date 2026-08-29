import SwiftUI

/// 판올림 기록. 설정과 같은 방식으로 팝오버를 덮는 한 화면이다
/// (`.sheet` 를 쓰면 팝오버가 닫힌 뒤 고아 창이 남는다).
///
/// 열어 본 시점의 버전을 적어 두고, 그 뒤로는 안내 줄을 띄우지 않는다.
@MainActor
struct ReleaseNotesView: View {
    let wallet: WalletStore
    let store: UsageStore
    let onClose: () -> Void

    private var l: L { wallet.l }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    ForEach(l.releaseNotes) { note in
                        section(note)
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(height: 460)
        .onAppear { store.lastSeenReleaseVersion = ReleaseNotes.runningVersion ?? "" }
    }

    private var header: some View {
        HStack(spacing: 6) {
            Button(action: onClose) {
                HStack(spacing: 2) {
                    Image(systemName: "chevron.backward")
                    Text(l.back)
                }
            }
            .buttonStyle(.plain)
            .foregroundStyle(Color.accentColor)
            .keyboardShortcut(.cancelAction)
            Spacer()
            Text(l.releaseNotesTitle).font(.headline)
            Spacer()
            // 좌측 뒤로 버튼과 시각적 균형 (제목 중앙 정렬 유지)
            Text(l.back).opacity(0).accessibilityHidden(true)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private func section(_ note: ReleaseNote) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text("v\(note.version)")
                    .font(.callout.weight(.semibold)).monospacedDigit()
                if note.version == ReleaseNotes.runningVersion {
                    Text(l.releaseNotesCurrentBadge)
                        .font(.system(size: 9, weight: .semibold))
                        .padding(.horizontal, 5).padding(.vertical, 2)
                        .background(Color.accentColor.opacity(0.16),
                                    in: Capsule())
                        .foregroundStyle(Color.accentColor)
                }
                Spacer(minLength: 0)
            }
            ForEach(Array(note.items.enumerated()), id: \.offset) { _, item in
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("•").font(.caption).foregroundStyle(.tertiary)
                    Text(item)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
