import AppKit
import SwiftUI

/// 친구 — 내 프로필, 친구, 위시리스트, 바인더, 서버에 있는 내 카드.
///
/// 서버 경로와 보내는 값은 그대로 두고, 화면만 그림과 쉬운 말로 바꿨다.
@MainActor
struct OnlineSocialView: View {
    @Bindable var model: OnlineHubModel
    @State private var nickname = ""
    @State private var code = ""
    @State private var collectionPublic = false
    @State private var wishlistPublic = false
    @State private var binderPublic = false
    /// 친구가 교환 바인더로 볼 수 있는 남는 카드. 이 설정을 아는 서버에서만 보이고 보낸다.
    @State private var tradeListPublic = true
    @State private var tradeListSupported = false
    @State private var draftLoaded = false
    @State private var addingWish = false
    @State private var editingBinder = false
    @State private var visitingFriend: String?
    @State private var preview: PrintingSelection?
    @State private var copied = false
    /// 끊거나 차단하기 전에 한 번 묻는다. 메뉴에서 누르는 즉시 실행돼, 잘못 누르면 주고받던
    /// 교환 제안까지 함께 사라졌다.
    @State private var confirmingUnfriend: [String: Any]?
    @State private var confirmingBlock: [String: Any]?

    /// 친구 탭의 하위 화면. 프로필 설정부터 내 카드까지 한 페이지에 이어 두니 길어서
    /// 원하는 칸을 찾으려면 계속 내려야 했다. 마켓처럼 위에서 고른다.
    enum Page: String, CaseIterable, Identifiable {
        case friends, wishlist, binder, cards, profile
        var id: String { rawValue }
        @MainActor var title: String {
            switch self {
            case .friends: OnlineText.l.friendsTitle
            case .wishlist: OnlineText.l.wishlistTitle
            case .binder: OnlineText.l.binderTitle
            case .cards: OnlineText.l.myCardsTitle
            case .profile: OnlineText.l.myProfileTitle
            }
        }
    }
    @State private var page: Page = .friends

    var body: some View {
        let incoming = model.items("friends").filter { $0.string("status") == "pending" && $0.bool("incoming") }.count
        VStack(alignment: .leading, spacing: 16) {
            Picker("", selection: $page) {
                ForEach(Page.allCases) { option in
                    Text(option == .friends && incoming > 0 ? "\(option.title) \(incoming)" : option.title).tag(option)
                }
            }
            .pickerStyle(.segmented).labelsHidden().fixedSize()
            ScrollViewReader { scroller in
                ScrollView {
                    VStack(alignment: .leading, spacing: 30) {
                        switch page {
                        case .friends: friends
                        case .wishlist: wishlist
                        case .binder: binder
                        case .cards: inventory
                        case .profile: profile
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.bottom, 12)
                    .padding(.horizontal, OnlineFocus.gutter)
                }
                .padding(.horizontal, -OnlineFocus.gutter)
                .revealsOnlineFocus(model, in: model.items("friends"), with: scroller)
            }
        }
        .onAppear { loadDraft() }
        // 친구 알림을 눌러 들어왔으면 친구 목록부터 보여 준다.
        .onChange(of: model.focusID, initial: true) { if model.focusID != nil { page = .friends } }
        .alert(OnlineText.l.unfriendQuestion(confirmingUnfriend?.string("nickname") ?? ""), isPresented: Binding(
            get: { confirmingUnfriend != nil }, set: { if !$0 { confirmingUnfriend = nil } })) {
            Button(OnlineText.l.cancel, role: .cancel) { confirmingUnfriend = nil }
            Button(OnlineText.l.unfriend, role: .destructive) {
                if let item = confirmingUnfriend { friendAction("friend_remove", item) }; confirmingUnfriend = nil
            }
        } message: { Text(OnlineText.l.unfriendNote) }
        .alert(OnlineText.l.blockQuestion(confirmingBlock?.string("nickname") ?? ""), isPresented: Binding(
            get: { confirmingBlock != nil }, set: { if !$0 { confirmingBlock = nil } })) {
            Button(OnlineText.l.cancel, role: .cancel) { confirmingBlock = nil }
            Button(OnlineText.l.blockUser, role: .destructive) {
                if let item = confirmingBlock { act("friends", ["action": "block", "target_id": item.string("public_id")]) }
                confirmingBlock = nil
            }
        } message: { Text(OnlineText.l.blockNote) }
        .onChange(of: model.generation) { loadDraft() }
        .sheet(item: $preview) { OnlinePrintingDetail(printing: $0.id) }
        .sheet(isPresented: $addingWish) {
            OnlineCatalogueSearch(title: OnlineText.l.addToWishlist, actionTitle: OnlineText.l.addConfirm, allowsAnyFinish: true, maxQuantity: 1000) { cardID, finish, target in
                var wishes = currentWishes
                wishes.append(["card_id": cardID, "finish": finish.map { $0.rawValue as Any } ?? NSNull(), "target": target])
                act("wishlist", ["action": "wishlist", "wishes": wishes])
            }
        }
        .sheet(item: Binding(get: { visitingFriend.map(PrintingSelection.init) }, set: { visitingFriend = $0?.id })) { _ in
            FriendBinderSheet(model: model)
        }
        .sheet(isPresented: $editingBinder) {
            BinderEditorSheet(wallet: model.wallet, current: model.profile["binder"] as? [String] ?? []) { keys in
                act("binder", ["action": "binder", "binder": keys])
            }
        }
    }

    // MARK: 내 프로필

    private var profile: some View {
        OnlineSection(title: OnlineText.l.myProfileTitle, subtitle: OnlineText.l.profilePrivacyNote) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    Text(OnlineText.l.nicknameLabel).font(Typography.labelSemibold).frame(width: 64, alignment: .leading)
                    TextField(OnlineText.l.nicknamePlaceholder, text: $nickname).textFieldStyle(.roundedBorder).frame(maxWidth: 240)
                    Button(OnlineText.l.saveAction) { saveProfile() }
                        .disabled(!model.canWrite || nickname.isEmpty || nickname == model.profile.string("nickname"))
                }
                HStack(spacing: 10) {
                    Text(OnlineText.l.friendCodeLabel).font(Typography.labelSemibold).frame(width: 64, alignment: .leading)
                    Text(OnlineText.groupedFriendCode(myFriendCode))
                        .font(.system(size: 15, weight: .medium, design: .monospaced)).textSelection(.enabled)
                    Button(copied ? OnlineText.l.copiedAction : OnlineText.l.copyAction, action: copyFriendCode)
                        .disabled(myFriendCode.isEmpty)
                    shareFriendCode
                    Button(OnlineText.l.newFriendCode) { act("profile", ["action": "rotate_code"]) }
                        .buttonStyle(.borderless).disabled(!model.canWrite)
                        .help(OnlineText.l.newFriendCodeHelp)
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text(OnlineText.l.showToFriends).font(Typography.labelSemibold)
                    Toggle(OnlineText.l.myCollectionToggle, isOn: $collectionPublic)
                    Toggle(OnlineText.l.wishlistTitle, isOn: $wishlistPublic)
                    Toggle(OnlineText.l.binderTitle, isOn: $binderPublic)
                    if tradeListSupported {
                        Toggle(OnlineText.l.tradeListToggle, isOn: $tradeListPublic)
                    }
                }
                .onChange(of: collectionPublic) { if draftLoaded { saveProfile() } }
                .onChange(of: wishlistPublic) { if draftLoaded { saveProfile() } }
                .onChange(of: binderPublic) { if draftLoaded { saveProfile() } }
                .onChange(of: tradeListPublic) { if draftLoaded { saveProfile() } }
            }
        }
    }

    // MARK: 친구

    private var friends: some View {
        let items = model.items("friends")
        let incoming = items.filter { $0.string("status") == "pending" && $0.bool("incoming") }
        let outgoing = items.filter { $0.string("status") == "pending" && !$0.bool("incoming") }
        let accepted = items.filter { $0.string("status") == "accepted" }
        return OnlineSection(title: OnlineText.l.friendsTitle) {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 10) {
                        TextField(OnlineText.l.enterFriendCode, text: $code).textFieldStyle(.roundedBorder).frame(maxWidth: 240)
                            .font(.system(size: 14, weight: .medium, design: .monospaced))
                            .onSubmit(sendRequest)
                        // 받은 코드는 대개 메신저에 있다. 칸을 눌러 붙여 넣는 수고를 줄인다.
                        Button(OnlineText.l.pasteAction) {
                            guard let text = NSPasteboard.general.string(forType: .string) else { return }
                            code = OnlineText.groupedFriendCode(OnlineText.normalizedFriendCode(text))
                        }
                        Button(OnlineText.l.sendFriendRequest, action: sendRequest)
                            .disabled(!model.canWrite || OnlineText.normalizedFriendCode(code).count < 8)
                    }
                    // 자리 수가 맞지 않으면 보내기 전에 알려 준다. 서버까지 갔다가 「찾지 못했어요」 를
                    // 듣는 것보다 빠르다.
                    if !code.isEmpty, OnlineText.normalizedFriendCode(code).count != 16 {
                        Text(OnlineText.l.friendCodeFormatHint)
                            .font(Typography.label).foregroundStyle(.secondary)
                    }
                }
                // 친구를 맺으려면 내 코드도 건네야 한다. 프로필 탭까지 가지 않게 여기에도 둔다.
                HStack(spacing: 8) {
                    Text(OnlineText.l.myFriendCode).font(Typography.label).foregroundStyle(.secondary)
                    Text(OnlineText.groupedFriendCode(myFriendCode))
                        .font(.system(size: 14, weight: .medium, design: .monospaced)).textSelection(.enabled)
                    Button(copied ? OnlineText.l.copiedAction : OnlineText.l.copyAction, action: copyFriendCode)
                        .buttonStyle(.link).font(Typography.label)
                        .disabled(myFriendCode.isEmpty)
                    shareFriendCode
                        .buttonStyle(.link).font(Typography.label)
                }
                ForEach(incoming, id: \.onlineID) { item in
                    friendRow(item, note: OnlineText.l.sentYouRequest) {
                        Button(OnlineText.l.declineAction) { friendAction("friend_reject", item) }
                        Button(OnlineText.l.acceptShort) { friendAction("friend_accept", item) }.buttonStyle(.borderedProminent)
                    }
                }
                ForEach(accepted, id: \.onlineID) { item in
                    friendRow(item, note: nil) {
                        // 교환 탭으로 가서 이 친구를 다시 고르지 않아도 되게 한다.
                        Button(OnlineText.l.proposeTradeShort) {
                            model.tradeDraft = ["public_id": item.string("public_id")]
                            model.section = .trades
                        }
                        Button(OnlineText.l.viewBinder) {
                            model.documents["friend"] = nil; model.documents["friendInventory"] = nil
                            model.selectedFriend = item.string("public_id")
                            visitingFriend = item.string("public_id")
                            Task { await model.refresh(full: false) }
                        }
                        Menu {
                            Button(OnlineText.l.unfriend) { confirmingUnfriend = item }
                            Button(OnlineText.l.blockUser, role: .destructive) { confirmingBlock = item }
                        } label: { Image(systemName: "ellipsis") }
                        .menuStyle(.borderlessButton).fixedSize()
                    }
                }
                ForEach(outgoing, id: \.onlineID) { item in
                    friendRow(item, note: OnlineText.l.awaitingAcceptance) {
                        Button(OnlineText.l.cancelRequest) { friendAction("friend_remove", item) }
                    }
                }
                if items.isEmpty {
                    Text(OnlineText.l.friendsEmptyHint)
                        .font(Typography.label).foregroundStyle(.secondary)
                }
                let blocks = model.items("blocks")
                if !blocks.isEmpty {
                    DisclosureGroup(OnlineText.l.blockedUsers(blocks.count)) {
                        ForEach(blocks, id: \.onlineID) { item in
                            HStack {
                                Text(item.string("nickname"))
                                Spacer()
                                Button(OnlineText.l.unblock) { act("friends", ["action": "unblock", "target_id": item.string("public_id")]) }
                                    .disabled(!model.canWrite)
                            }
                        }
                    }
                    .font(Typography.label)
                }
            }
        }
    }

    private func friendRow<Actions: View>(_ item: [String: Any], note: String?,
                                          @ViewBuilder actions: () -> Actions) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "person.crop.circle").font(.system(size: 22)).foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 6) {
                    Text(item.string("nickname")).font(Typography.bodySemibold)
                    // 레벨을 모르는 예전 서버는 값을 보내지 않는다. 그때는 적지 않는다.
                    if item["level"] != nil {
                        Text(OnlineText.l.levelShort(item.int("level")))
                            .font(Typography.caption).foregroundStyle(.secondary)
                            .padding(.horizontal, 5).padding(.vertical, 1)
                            .background(Color.secondary.opacity(0.12), in: Capsule())
                    }
                }
                if let note { Text(note).font(Typography.caption).foregroundStyle(.secondary) }
            }
            Spacer()
            actions().disabled(!model.canWrite)
        }
        .padding(.vertical, 4)
        .onlineFocusRing(model.focusID == item.string("id"), cornerRadius: 8, outset: 6)
        .id(item.onlineID)
    }

    // MARK: 위시리스트

    private var currentWishes: [[String: Any]] {
        (model.profile["wishlist"] as? [[String: Any]] ?? []).map { wish in
            ["card_id": wish.string("card_id"), "finish": wish["finish"] ?? NSNull(), "target": wish.int("target")]
        }
    }

    static func wishPrice(cardID: String, finish: String) -> Int? {
        guard let finish = CardFinish(rawValue: finish) else { return OnlineText.cardReferenceWon(cardID) }
        return OnlineText.referenceWon(CardPrintingKey(cardID: cardID, finish: finish).storageKey)
    }

    private var wishlist: some View {
        let wishes = model.profile["wishlist"] as? [[String: Any]] ?? []
        return OnlineSection(title: OnlineText.l.wishlistTitle, subtitle: OnlineText.l.wishlistNote) {
            Button { addingWish = true } label: { Label(OnlineText.l.addCard, systemImage: "plus") }
                .disabled(!model.canWrite)
        } content: {
            if wishes.isEmpty {
                Text(OnlineText.l.wishlistEmpty).font(Typography.label).foregroundStyle(.secondary)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 116), spacing: 14)], alignment: .leading, spacing: 16) {
                    ForEach(Array(wishes.enumerated()), id: \.offset) { position, wish in
                        let finish = wish.string("finish")
                        OnlineCardTile(cardID: wish.string("card_id"), finish: finish, width: 104,
                                       badge: wish.int("missing") == 0 ? (OnlineText.l.collectedAll, .green) : nil) {
                            Text(OnlineText.l.wishProgress(owned: wish.int("owned"), target: wish.int("target"), anyFinish: finish.isEmpty))
                                .font(Typography.caption).foregroundStyle(.secondary).monospacedDigit()
                            // 마켓에서 얼마쯤에 살 수 있는지. 판형을 정하지 않았으면 대표 시세다.
                            Text(Self.wishPrice(cardID: wish.string("card_id"), finish: finish)
                                .map { OnlineText.l.marketQuote(OnlineText.wonText($0)) } ?? OnlineText.l.noMarketPrice)
                                .font(Typography.caption).foregroundStyle(.secondary).monospacedDigit().lineLimit(1)
                            Button(OnlineText.l.removeCard) {
                                let next = currentWishes.enumerated().filter { $0.offset != position }.map(\.element)
                                act("wishlist", ["action": "wishlist", "wishes": next])
                            }
                            .buttonStyle(.borderless).font(Typography.caption).disabled(!model.canWrite)
                        }
                    }
                }
            }
        }
    }

    // MARK: 바인더

    private var binder: some View {
        let keys = model.profile["binder"] as? [String] ?? []
        return OnlineSection(title: OnlineText.l.myBinder, subtitle: OnlineText.l.binderNote(BinderEditorSheet.capacity)) {
            Button { editingBinder = true } label: { Label(OnlineText.l.chooseCards, systemImage: "rectangle.stack.badge.plus") }
                .buttonStyle(.borderedProminent)
                .disabled(!model.canWrite)
        } content: {
            if keys.isEmpty {
                Text(OnlineText.l.binderEmptyHint)
                    .font(Typography.label).foregroundStyle(.secondary)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 116), spacing: 14)], alignment: .leading, spacing: 16) {
                    ForEach(Array(keys.enumerated()), id: \.offset) { i, key in
                        let printing = CardPrintingKey(storageKey: key)
                        OnlineCardTile(cardID: printing.cardID, finish: printing.finish.rawValue, width: 104) {
                            HStack(spacing: 8) {
                                Button { var next = keys; next.swapAt(i, i - 1); act("binder", ["action": "binder", "binder": next]) } label: {
                                    Image(systemName: "arrow.left")
                                }
                                .help(OnlineText.l.moveEarlier).disabled(!model.canWrite || i == 0)
                                Button(OnlineText.l.removeCard) { var next = keys; next.remove(at: i); act("binder", ["action": "binder", "binder": next]) }
                                    .disabled(!model.canWrite)
                            }
                            .buttonStyle(.borderless).font(Typography.caption)
                        }
                        .onTapGesture { preview = PrintingSelection(id: key) }
                        // 끌어다 다른 카드 위에 놓으면 그 자리로 옮기고 바로 저장한다.
                        .draggable(key)
                        .dropDestination(for: String.self) { items, _ in
                            guard model.canWrite, let moving = items.first, moving != key else { return false }
                            act("binder", ["action": "binder", "binder": BinderOrder.moving(moving, onto: key, in: keys)])
                            return true
                        }
                    }
                }
            }
        }
    }

    // MARK: 서버에 있는 내 카드

    private var inventory: some View {
        let binderKeys = model.profile["binder"] as? [String] ?? []
        let items = model.items("inventory")
        return OnlineSection(title: OnlineText.l.myCardsTitle, subtitle: OnlineText.l.myCardsNote) {
            TextField(OnlineText.l.searchByName, text: $model.search)
                .textFieldStyle(.roundedBorder).frame(width: 220)
                .onSubmit { model.offset = 0; Task { await model.refresh(full: false) } }
        } content: {
            if items.isEmpty {
                Text(model.search.isEmpty ? OnlineText.l.noServerCards : OnlineText.l.noMatchingCardsSentence)
                    .font(Typography.label).foregroundStyle(.secondary)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 116), spacing: 14)], alignment: .leading, spacing: 16) {
                    ForEach(items, id: \.onlineID) { item in
                        let key = item.string("printing")
                        let printing = CardPrintingKey(storageKey: key)
                        OnlineCardTile(cardID: printing.cardID, finish: printing.finish.rawValue, width: 104) {
                            Text(item.int("reserved") > 0 ? OnlineText.l.reservedCount(quantity: item.int("quantity"), reserved: item.int("reserved")) : OnlineText.l.cardsCount(item.int("quantity")))
                                .font(Typography.caption).foregroundStyle(.secondary).monospacedDigit()
                            if binderKeys.contains(key) {
                                Text(OnlineText.l.inBinder).font(Typography.caption).foregroundStyle(.secondary)
                            } else {
                                Button(OnlineText.l.putInBinder) { act("binder", ["action": "binder", "binder": binderKeys + [key]]) }
                                    .buttonStyle(.borderless).font(Typography.caption)
                                    .disabled(!model.canWrite || binderKeys.count >= BinderEditorSheet.capacity)
                            }
                        }
                        .onTapGesture { preview = PrintingSelection(id: key) }
                    }
                }
                OnlinePagination(model: model, key: "inventory")
            }
        }
    }

    // MARK: 동작

    private func sendRequest() {
        let normalized = OnlineText.normalizedFriendCode(code)
        guard normalized.count >= 8 else { return }
        act("friends", ["action": "friend_request", "friend_code": normalized])
        code = ""
    }

    private var myFriendCode: String { model.profile.string("friend_code") }

    /// 복사는 끊지 않은 원래 코드로 한다. 예전 앱은 띄어쓰기를 빼지 않고 그대로 보낸다.
    private func copyFriendCode() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(myFriendCode, forType: .string)
        copied = true
    }

    /// 메시지, 메일, 메모로 바로 보낸다. 복사해 다른 앱을 열고 붙여 넣는 세 단계를 하나로 줄인다.
    @ViewBuilder
    private var shareFriendCode: some View {
        if !myFriendCode.isEmpty {
            ShareLink(item: OnlineText.l.friendCodeShareText(OnlineText.groupedFriendCode(myFriendCode))) {
                Text(OnlineText.l.shareAction)
            }
        }
    }

    private func saveProfile() {
        var values: [String: Any] = ["action": "profile", "nickname": nickname.isEmpty ? model.profile.string("nickname") : nickname,
                                     "collection_public": collectionPublic, "wishlist_public": wishlistPublic, "binder_public": binderPublic]
        // 이 설정을 모르는 옛 서버는 모르는 값이 오면 요청 전체를 거절한다.
        if tradeListSupported { values["trade_list_public"] = tradeListPublic }
        act("profile", values)
    }

    private func loadDraft() {
        guard !draftLoaded, !model.profile.isEmpty else { return }
        nickname = model.profile.string("nickname")
        collectionPublic = model.profile.bool("collection_public")
        wishlistPublic = model.profile.bool("wishlist_public")
        binderPublic = model.profile.bool("binder_public")
        tradeListSupported = model.profile["trade_list_public"] != nil
        tradeListPublic = tradeListSupported ? model.profile.bool("trade_list_public") : true
        // 토글의 onChange 가 불러오기를 저장으로 착각하지 않게 다음 틱에 연다.
        Task { @MainActor in draftLoaded = true }
    }

    private func friendAction(_ action: String, _ item: [String: Any]) {
        act("friends", ["action": action, "target_id": item.string("id"), "target_version": item.int("version")])
    }

    private func act(_ route: String, _ values: [String: Any]) { Task { await model.mutate(route, values) } }
}

/// 바인더 고르기. 내 카드 전체를 시세 높은 순으로 보여 주고 여러 장을 골라 한 번에 저장한다.
///
/// 예전에는 서버의 「내 카드」 목록(이름순, 50장씩)에서 카드마다 「바인더에 꽂기」를 눌러야
/// 해서, 좋은 카드를 찾으려면 쪽을 계속 넘겨야 했다. 가진 카드와 시세는 앱에 이미 있다.
@MainActor
struct BinderEditorSheet: View {
    /// 서버가 받는 바인더 최대 장수.
    nonisolated static let capacity = 36

    private struct Entry: Identifiable {
        let key: String
        let cardID: String
        let finish: CardFinish
        let won: Int?
        var id: String { key }
    }

    private let entries: [Entry]
    private let initial: [String]
    private let onSave: ([String]) -> Void
    @State private var picked: [String]
    @State private var query = ""
    /// 끌어다 놓을 자리. 놓일 곳을 테두리로 보여 준다.
    @State private var dropTarget: String?
    @State private var appliedQuery = ""
    @Environment(\.dismiss) private var dismiss

    init(wallet: WalletStore, current: [String], onSave: @escaping ([String]) -> Void) {
        let index = CardIndex.shared
        entries = wallet.state.printingCards.compactMap { key, count -> Entry? in
            let printing = CardPrintingKey(storageKey: key)
            guard count > 0, index?.card(printing.cardID) != nil else { return nil }
            return Entry(key: key, cardID: printing.cardID, finish: printing.finish,
                         won: OnlineText.referenceWon(key))
        }
        .sorted { left, right in
            left.won != right.won ? (left.won ?? -1) > (right.won ?? -1) : left.key < right.key
        }
        // 이제 없는 카드는 서버가 거절하므로 담아 두지 않는다.
        let ownedKeys = Set(entries.map(\.key))
        let kept = current.filter(ownedKeys.contains)
        initial = kept
        _picked = State(initialValue: kept)
        self.onSave = onSave
    }

    private var visible: [Entry] {
        let needle = DexCardSearch.normalized(appliedQuery)
        guard !needle.isEmpty else { return entries }
        return entries.filter {
            DexCardSearch.names(cardID: $0.cardID).contains { $0.contains(needle) }
        }
    }

    var body: some View {
        let chosen = Set(picked)
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(OnlineText.l.chooseBinder).font(Typography.heading)
                    Text(OnlineText.l.binderEditorNote)
                        .font(Typography.label).foregroundStyle(.secondary)
                }
                Spacer()
                Text(OnlineText.l.binderFill(picked.count, Self.capacity)).font(Typography.bodySemibold).monospacedDigit()
            }
            if !picked.isEmpty {
                ScrollView(.horizontal) {
                    HStack(spacing: 8) {
                        ForEach(picked, id: \.self) { key in
                            Button { toggle(key) } label: {
                                CardImageView(cardID: CardPrintingKey(storageKey: key).cardID, width: 50)
                                    .overlay(alignment: .topTrailing) {
                                        Image(systemName: "minus.circle.fill")
                                            .font(.system(size: 15))
                                            .foregroundStyle(.white, .black.opacity(0.55))
                                            .padding(2)
                                    }
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 4)
                                            .strokeBorder(Color.accentColor, lineWidth: dropTarget == key ? 2 : 0)
                                    }
                            }
                            .buttonStyle(.plain)
                            .help(OnlineText.l.binderSlotHelp(OnlineText.cardName(CardPrintingKey(storageKey: key).cardID)))
                            .draggable(key)
                            .dropDestination(for: String.self) { items, _ in
                                guard let moving = items.first else { return false }
                                picked = BinderOrder.moving(moving, onto: key, in: picked)
                                return true
                            } isTargeted: { dropTarget = $0 ? key : (dropTarget == key ? nil : dropTarget) }
                        }
                    }
                    .padding(.vertical, 2)
                }
                .frame(height: 76)
            }
            HStack(spacing: 10) {
                TextField(OnlineText.l.searchByName, text: $query).textFieldStyle(.roundedBorder)
                    .debouncedSearch(query, into: $appliedQuery)
                Button { fillTop() } label: { Label(OnlineText.l.fillWithTop, systemImage: "sparkles") }
                    .disabled(picked.count >= Self.capacity)
                    .help(OnlineText.l.fillWithTopHelp)
                Button(OnlineText.l.removeAll) { picked = [] }.disabled(picked.isEmpty)
            }
            ScrollView {
                if visible.isEmpty {
                    OnlineEmptyState(icon: "rectangle.stack",
                                     title: entries.isEmpty ? OnlineText.l.noCardsOwned : OnlineText.l.noMatchingCards,
                                     message: entries.isEmpty ? OnlineText.l.openPacksToSee : nil)
                } else {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: 12)], spacing: 14) {
                        ForEach(visible) { entry in
                            let selected = chosen.contains(entry.key)
                            Button { toggle(entry.key) } label: {
                                OnlineCardTile(cardID: entry.cardID, finish: entry.finish.rawValue, width: 92) {
                                    Text(entry.won.map(OnlineText.wonText) ?? OnlineText.l.noMarketPrice)
                                        .font(Typography.caption).foregroundStyle(.secondary).monospacedDigit()
                                }
                                .padding(5)
                                .background(selected ? Color.accentColor.opacity(0.14) : .clear,
                                            in: RoundedRectangle(cornerRadius: 9))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 9)
                                        .strokeBorder(Color.accentColor, lineWidth: selected ? 2 : 0)
                                }
                                // 카드 그림 위 글자에 묻히지 않게 흰 테두리가 있는 체크로 표시한다.
                                .overlay(alignment: .topTrailing) {
                                    if selected {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.system(size: 22, weight: .semibold))
                                            .foregroundStyle(.white, Color.accentColor)
                                            .shadow(color: .black.opacity(0.35), radius: 2)
                                            .padding(2)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                            .disabled(!selected && picked.count >= Self.capacity)
                            .accessibilityAddTraits(selected ? .isSelected : [])
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .frame(height: 380)
            HStack {
                Button(OnlineText.l.cancel) { dismiss() }.keyboardShortcut(.cancelAction)
                Spacer()
                Button(OnlineText.l.saveToBinder) { dismiss(); onSave(picked) }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                    .disabled(picked == initial)
            }
        }
        .padding(24)
        .frame(width: 660)
    }

    private func toggle(_ key: String) {
        if let at = picked.firstIndex(of: key) { picked.remove(at: at) }
        else if picked.count < Self.capacity { picked.append(key) }
    }

    /// 남은 칸을 시세 높은 카드로. 같은 카드의 다른 판형으로 칸이 채워지지 않게 카드마다 한 장.
    private func fillTop() {
        var next = picked
        var cards = Set(next.map { CardPrintingKey(storageKey: $0).cardID })
        for entry in entries where next.count < Self.capacity {
            guard entry.won != nil, !cards.contains(entry.cardID) else { continue }
            next.append(entry.key)
            cards.insert(entry.cardID)
        }
        picked = next
    }
}

/// 친구의 공개 바인더, 위시리스트, 컬렉션.
@MainActor
private struct FriendBinderSheet: View {
    @Bindable var model: OnlineHubModel
    @State private var preview: PrintingSelection?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let friend = model.documents["friend"] ?? [:]
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text(friend.isEmpty ? OnlineText.l.loading : OnlineText.l.friendsCards(friend.string("nickname"))).font(Typography.heading)
                Spacer()
                if !friend.isEmpty {
                    // 교환 탭의 만들기 칸에 이 친구를 골라 둔다. 받고 싶은 카드는 거기서 친구의
                    // 교환 바인더를 열어 담는다.
                    Button(OnlineText.l.tradeWithFriend) {
                        model.tradeDraft = ["public_id": friend.string("public_id")]
                        model.selectedFriend = ""; model.documents["friend"] = nil; model.documents["friendInventory"] = nil
                        model.section = .trades
                        dismiss()
                    }
                    .disabled(!model.canWrite)
                }
                Button(OnlineText.l.close) {
                    model.selectedFriend = ""; model.documents["friend"] = nil; model.documents["friendInventory"] = nil
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    OnlineSection(title: OnlineText.l.binderTitle) {
                        let keys = friend["binder"] as? [String] ?? []
                        if !friend.bool("binder_public") {
                            Text(OnlineText.l.binderPrivate).font(Typography.label).foregroundStyle(.secondary)
                        } else if keys.isEmpty {
                            Text(OnlineText.l.binderEmpty).font(Typography.label).foregroundStyle(.secondary)
                        } else {
                            grid(keys.map { ($0, nil) })
                        }
                    }
                    if friend.bool("wishlist_public") {
                        OnlineSection(title: OnlineText.l.cardsTheyWant) {
                            let wishes = friend["wishlist"] as? [[String: Any]] ?? []
                            if wishes.isEmpty {
                                Text(OnlineText.l.noWishes).font(Typography.label).foregroundStyle(.secondary)
                            } else {
                                LazyVGrid(columns: [GridItem(.adaptive(minimum: 104), spacing: 12)], alignment: .leading, spacing: 14) {
                                    ForEach(Array(wishes.enumerated()), id: \.offset) { _, wish in
                                        OnlineCardTile(cardID: wish.string("card_id"), finish: wish.string("finish"), width: 96) {
                                            Text(OnlineText.l.moreNeeded(wish.int("missing"))).font(Typography.caption).foregroundStyle(.secondary)
                                        }
                                    }
                                }
                            }
                        }
                    }
                    if friend.bool("collection_public") {
                        OnlineSection(title: OnlineText.l.collectionTitle) {
                            let items = model.items("friendInventory")
                            if items.isEmpty {
                                Button(OnlineText.l.viewCollection) { load(offset: 0) }
                            } else {
                                grid(items.map { ($0.string("printing"), OnlineText.l.cardsCount($0.int("quantity"))) })
                                if let next = model.documents["friendInventory"]?["next_offset"] as? Int {
                                    Button(OnlineText.l.showMore) { load(offset: next) }.frame(maxWidth: .infinity)
                                }
                            }
                        }
                    }
                }
            }
        }
        .padding(24)
        .frame(width: 640, height: 600)
        .sheet(item: $preview) { OnlinePrintingDetail(printing: $0.id) }
    }

    private func grid(_ entries: [(key: String, note: String?)]) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 104), spacing: 12)], alignment: .leading, spacing: 14) {
            ForEach(Array(entries.enumerated()), id: \.offset) { _, entry in
                let printing = CardPrintingKey(storageKey: entry.key)
                OnlineCardTile(cardID: printing.cardID, finish: printing.finish.rawValue, width: 96) {
                    if let note = entry.note { Text(note).font(Typography.caption).foregroundStyle(.secondary) }
                }
                .onTapGesture { preview = PrintingSelection(id: entry.key) }
            }
        }
    }

    private func load(offset: Int) {
        Task {
            do { model.documents["friendInventory"] = try await model.read("v1/inventory?target=\(model.selectedFriend)&offset=\(offset)") }
            catch { model.message = OnlineText.message(for: error) }
        }
    }
}

struct PrintingSelection: Identifiable { let id: String }

@MainActor
struct OnlinePrintingArt: View {
    let printing: String
    var width: CGFloat = 180
    var body: some View {
        let key = CardPrintingKey(storageKey: printing)
        if let card = CardIndex.shared?.card(key.cardID) {
            // 온라인 창에서 카드를 크게 보는 자리는 모두 이것을 쓴다. 기울이고 끌어서 돌려 본다.
            HolographicCardView(cardID: card.id, tier: card.tier, finish: key.finish, setID: card.setID,
                                originalRarity: card.rarity, width: width, spinnable: true)
        } else { Image(systemName: "rectangle.portrait").frame(width: width, height: width / 0.717) }
    }
}

/// 카드 한 장을 크게. 판형과 참고 시세를 원화로 보여 준다.
@MainActor
struct OnlinePrintingDetail: View {
    let printing: String
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        let key = CardPrintingKey(storageKey: printing)
        VStack(spacing: 12) {
            Text(OnlineText.cardName(key.cardID)).font(Typography.heading)
            Text("\(OnlineText.l.cardFinishName(key.finish)), \(CardIndex.shared?.card(key.cardID).flatMap { CardIndex.shared?.set($0.setID)?.name } ?? "")")
                .font(Typography.label).foregroundStyle(.secondary)
            OnlinePrintingArt(printing: printing, width: 260)
            if let won = OnlineText.referenceWon(printing), let prices = CardPrices.shared {
                Text(OnlineText.l.referencePrice(OnlineText.wonText(won))).font(Typography.bodySemibold).monospacedDigit()
                Text(OnlineText.l.asOf(prices.sourceDate(cardID: key.cardID, finish: key.finish)))
                    .font(Typography.caption).foregroundStyle(.secondary)
                if let source = prices.sourceURL(cardID: key.cardID, finish: key.finish), let url = URL(string: source), ["https", "http"].contains(url.scheme) {
                    Link(OnlineText.l.viewPriceSource, destination: url).font(Typography.label)
                }
            }
            Button(OnlineText.l.close) { dismiss() }.keyboardShortcut(.cancelAction).padding(.top, 4)
        }
        .padding(24)
    }
}

/// 바인더 순서 바꾸기. 오른쪽으로 끌면 놓은 카드 뒤에, 왼쪽으로 끌면 앞에 둔다.
enum BinderOrder {
    static func moving(_ key: String, onto target: String, in order: [String]) -> [String] {
        guard key != target, let from = order.firstIndex(of: key), let to = order.firstIndex(of: target) else {
            return order
        }
        var next = order
        next.remove(at: from)
        let landing = next.firstIndex(of: target) ?? next.endIndex
        next.insert(key, at: from < to ? landing + 1 : landing)
        return next
    }
}
