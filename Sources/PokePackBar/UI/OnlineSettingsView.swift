import SwiftUI

/// Connection changes take effect on restart. Authentication never replaces
/// a live wallet or discards an unresolved resource command.
@MainActor
struct OnlineSettingsView: View {
    let wallet: WalletStore
    private let auditing: Bool
    @State private var enabled = UserDefaults.standard.bool(forKey: "ppb.server.enabled")
    @State private var address = UserDefaults.standard.string(forKey: "ppb.server.url") ?? "https://ppb-api.wonyangs.com"
    @State private var email = ""
    @State private var password = ""
    @State private var confirmation = ""
    @State private var newPassword = ""
    @State private var newPasswordConfirmation = ""
    @State private var linkCode = ""
    @State private var registering = false
    /// 저장한 설정이 다시 시작해야 적용된다. 메시지 옆에 「지금 다시 시작」을 보여 준다.
    @State private var needsRestart = false
    @State private var linking = false
    @State private var busy = false
    @State private var credential: ServerCredential?
    @State private var offersLegacyImport = false
    @State private var message: String?
    /// 계정 창의 탭.
    enum AccountTab: String, CaseIterable, Sendable { case profile, connection, security, devices, server }
    @State private var section: AccountTab = .connection
    @State private var devices: [AccountDevice] = []
    @State private var jobs: [AccountJob] = []
    @State private var recoveryCode = ""
    @State private var recoveryInput = ""
    @State private var recoveryActive = false
    @State private var deviceNames: [String: String] = [:]
    @State private var confirmingRevoke: AccountDevice?
    @State private var confirmingRecovery = false
    @State private var statusLoaded = false
    @State private var tokenPolicy = AccountTokenPolicy(collector_device_id: nil, version: 0)
    @State private var latencies: [String: AccountLatency] = [:]
    @State private var confirmingTokenPolicy: Bool?
    /// 프로필 탭의 닉네임. 저장된 값과 다를 때만 저장할 수 있다.
    @State private var nicknameDraft = ""
    @State private var savedNickname: String?
    private var actionsDisabled: Bool { busy || wallet.remote?.busy == true || wallet.isOpeningPacks }
    private var unconfirmed: Bool { wallet.remote.map { $0.hasPending || $0.hasOnlinePending } ?? false }

    init(wallet: WalletStore, auditSection: AccountTab? = nil, signedIn: Bool = false,
         initialSection: AccountTab? = nil) {
        self.wallet = wallet
        auditing = auditSection != nil
        if let initialSection { _section = State(initialValue: initialSection) }
        if let auditSection {
            _offersLegacyImport = State(initialValue: auditSection == .connection)
            if auditSection == .profile {
                _savedNickname = State(initialValue: "Layout Trainer")
                _nicknameDraft = State(initialValue: "Layout Trainer")
            }
            _section = State(initialValue: auditSection)
            _enabled = State(initialValue: false)
            _address = State(initialValue: "http://127.0.0.1:8000")
            _statusLoaded = State(initialValue: true)
            if signedIn {
                _credential = State(initialValue: ServerCredential(access_token: "layout-fixture-not-a-token",
                    account_id: UUID(), device_id: UUID(), email: "layout@example.invalid", expires_at: 0))
            }
            _devices = State(initialValue: AccountLayoutAudit.fixtureDevices)
            _jobs = State(initialValue: AccountLayoutAudit.fixtureJobs)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(OnlineText.l.accountAndServerTitle).font(Typography.heading)
                    Text(credential?.email ?? OnlineText.l.accountSubtitle)
                        .font(Typography.body).foregroundStyle(.secondary)
                }
                Spacer()
                if busy { ProgressView().controlSize(.small) }
            }
            Picker(OnlineText.l.accountSections, selection: $section) {
                ForEach(AccountTab.allCases, id: \.self) { Text(OnlineText.l.accountTab($0)).tag($0) }
            }.pickerStyle(.segmented).labelsHidden().frame(maxWidth: .infinity, alignment: .leading).disabled(busy)
                .onChange(of: section) {
                    clearSecrets()
                    if section == .profile { if !auditing { loadNickname() } }
                    else if section != .connection && !auditing { refreshAccount() }
                }
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if section == .profile { profile }
                    else if section == .connection { connection }
                    else if section == .security { security }
                    else if section == .devices { deviceList }
                    else { serverStatus }
                }.frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 4)
            }.disabled(busy)
            if let message {
                Divider()
                HStack(alignment: .firstTextBaseline) {
                    Text(message).font(Typography.body).textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    // 예전에는 「앱을 완전히 종료하고 다시 실행하세요」라고만 적었다.
                    if needsRestart {
                        Button(OnlineText.l.restartNow) { AppRelauncher.relaunch() }
                            .buttonStyle(.borderedProminent)
                    }
                }
            }
        }
        .task {
            if !auditing { loadSavedLogin() }
            if section == .profile && !auditing { loadNickname() }
        }
        .onDisappear { clearSecrets(); devices = []; jobs = []; credential = nil }
        .alert(OnlineText.l.revokeDeviceQuestion, isPresented: Binding(
            get: { confirmingRevoke != nil }, set: { if !$0 { confirmingRevoke = nil } })) {
            Button(OnlineText.l.cancel, role: .cancel) { confirmingRevoke = nil }
            Button(OnlineText.l.disconnect, role: .destructive) {
                if let device = confirmingRevoke { revoke(device) }; confirmingRevoke = nil
            }
        } message: { Text(OnlineText.l.revokeDeviceNote) }
        .alert(OnlineText.l.issueRecoveryQuestion, isPresented: $confirmingRecovery) {
            Button(OnlineText.l.cancel, role: .cancel) { }
            Button(OnlineText.l.issue) { issueRecovery() }
        } message: { Text(OnlineText.l.issueRecoveryNote) }
        .alert(OnlineText.l.changeTokenPolicyQuestion, isPresented: Binding(
            get: { confirmingTokenPolicy != nil }, set: { if !$0 { confirmingTokenPolicy = nil } })) {
            Button(OnlineText.l.cancel, role: .cancel) { confirmingTokenPolicy = nil }
            Button(OnlineText.l.change) { if let single = confirmingTokenPolicy { updateTokenPolicy(single: single) }; confirmingTokenPolicy = nil }
        } message: {
            Text(OnlineText.l.tokenPolicyNote)
        }
    }

    // MARK: 프로필

    /// 닉네임은 계정에 속한다. 예전에는 친구 탭의 「내 프로필」에서만 바꿀 수 있었다.
    private var profile: some View {
        GroupBox(OnlineText.l.nicknameLabel) {
            VStack(alignment: .leading, spacing: 10) {
                if wallet.remote == nil && !auditing {
                    Text(OnlineText.l.nicknameNeedsSignIn)
                        .font(Typography.body).foregroundStyle(.secondary)
                } else {
                    HStack(spacing: 10) {
                        TextField(OnlineText.l.nicknamePlaceholder, text: $nicknameDraft)
                            .textFieldStyle(.roundedBorder).frame(maxWidth: 280)
                            .onSubmit { saveNickname() }
                        Button(OnlineText.l.saveAction) { saveNickname() }
                            .disabled(!canSaveNickname)
                    }
                    Text(OnlineText.l.nicknameNote)
                        .font(Typography.label).foregroundStyle(.secondary)
                }
            }.padding(6).frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var trimmedNickname: String { nicknameDraft.trimmingCharacters(in: .whitespacesAndNewlines) }

    private var canSaveNickname: Bool {
        !busy && savedNickname != nil && !trimmedNickname.isEmpty && trimmedNickname.count <= 40
            && trimmedNickname != savedNickname
    }

    private func loadNickname() {
        guard let remote = wallet.remote, !busy else { return }
        busy = true
        Task {
            defer { busy = false }
            do {
                let profile = try JSONSerialization.jsonObject(with: try await remote.api("v1/profile")) as? [String: Any] ?? [:]
                let name = (profile["profile"] as? [String: Any])?.string("nickname") ?? ""
                savedNickname = name
                nicknameDraft = name
            } catch {
                message = OnlineText.l.profileLoadFailed
                AppLog.write("[online] profile load failed: \(error.localizedDescription)")
            }
        }
    }

    /// 서버의 프로필 저장은 닉네임과 공개 범위를 함께 덮어쓴다. 공개 범위를 꺼 버리지 않게
    /// 보내기 직전에 프로필을 다시 읽어 지금 값을 그대로 보낸다.
    private func saveNickname() {
        guard canSaveNickname, let remote = wallet.remote else { return }
        let name = trimmedNickname
        busy = true
        Task {
            defer { busy = false }
            do {
                let fresh = try JSONSerialization.jsonObject(with: try await remote.api("v1/profile")) as? [String: Any] ?? [:]
                let body = try Self.nicknameMutation(name, from: fresh)
                for _ in 0..<30 where remote.busy { try await Task.sleep(for: .milliseconds(100)) }
                _ = try await remote.onlineMutation(path: "v1/profile",
                                                    body: JSONSerialization.data(withJSONObject: body, options: [.sortedKeys]))
                savedNickname = name
                nicknameDraft = name
                message = OnlineText.l.nicknameSaved
                NotificationCenter.default.post(name: .onlineProfileChanged, object: nil)
            } catch {
                message = OnlineText.l.nicknameSaveFailed
                AppLog.write("[online] nickname save failed: \(error.localizedDescription)")
            }
        }
    }

    /// Keep privacy choices and their concurrency revision from the same read.
    static func nicknameMutation(_ name: String, from reply: [String: Any]) throws -> [String: Any] {
        guard let profile = reply["profile"] as? [String: Any],
              let revision = reply["revision"] as? Int,
              let collection = profile["collection_public"] as? Bool,
              let wishlist = profile["wishlist_public"] as? Bool,
              let binder = profile["binder_public"] as? Bool else {
            throw RemoteGameSession.Failure(message: OnlineText.l.profileLoadFailed)
        }
        var body: [String: Any] = [
            "action": "profile", "nickname": name, "collection_public": collection,
            "wishlist_public": wishlist, "binder_public": binder,
            "expected_revision": revision, "request_id": UUID().uuidString,
        ]
        if let tradeList = profile["trade_list_public"] as? Bool { body["trade_list_public"] = tradeList }
        return body
    }

    private var connection: some View {
        VStack(alignment: .leading, spacing: 14) {
            GroupBox(OnlineText.l.usageMode) {
                VStack(alignment: .leading, spacing: 10) {
            Toggle(OnlineText.l.onlineModeToggle, isOn: $enabled)
                        .disabled(actionsDisabled || unconfirmed)
                    Text(OnlineText.l.separateSavesNote)
                        .font(Typography.label).foregroundStyle(.secondary)
                    Button(OnlineText.l.saveAndApply) { saveConfiguration() }.disabled(actionsDisabled)
                }.padding(6).frame(maxWidth: .infinity, alignment: .leading)
            }
            DisclosureGroup(OnlineText.l.serverAddressAdvanced) {
            TextField(OnlineText.l.serverURL, text: $address).textFieldStyle(.roundedBorder)
                .disabled(busy)
                .onChange(of: address) { credential = nil; devices = []; jobs = []; clearSecrets() }
                Text(OnlineText.l.sameServerNote)
                    .font(Typography.label).foregroundStyle(.secondary)
            }
            if credential == nil {
                loginForm
            } else {
                GroupBox(OnlineText.l.linkedAccount) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(credential?.email ?? "").textSelection(.enabled)
                        Text(OnlineText.l.accountTabsNote)
                            .font(Typography.label).foregroundStyle(.secondary)
                        Button(OnlineText.l.openOnlineCollection) { OnlineWindow.shared.show(wallet: wallet) }
                        Button(OnlineText.l.renewOrSwitch) { credential = nil; devices = []; jobs = []; clearSecrets() }
                            .disabled(actionsDisabled)
                    }.padding(6).frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            if let remote = wallet.remote {
                Text(OnlineText.l.runningState(ready: remote.ready, revision: remote.revision))
                    .font(Typography.label).foregroundStyle(.secondary)
                Button(unconfirmed ? OnlineText.l.recoverAndSync : OnlineText.l.syncNow) {
                    Task { await remote.synchronize() }
                }.disabled(remote.busy)
                if let error = remote.error { Text(error).font(Typography.label).foregroundStyle(.orange) }
            } else { Text(OnlineText.l.runningLocally).font(Typography.label).foregroundStyle(.secondary) }
        }
    }

    private var loginForm: some View {
        GroupBox(OnlineText.l.emailAccount) {
            VStack(alignment: .leading, spacing: 10) {
            // 로그인과 가입을 체크박스 하나로 오가면 지금 어느 쪽인지 놓치기 쉬웠다.
            Picker("", selection: $registering) {
                Text(OnlineText.l.logIn).tag(false)
                Text(OnlineText.l.createAccount).tag(true)
            }
            .pickerStyle(.segmented).labelsHidden().fixedSize().disabled(busy)
            TextField(OnlineText.l.emailField, text: $email).textFieldStyle(.roundedBorder)
                .textContentType(.username).disabled(busy)
            SecureField(OnlineText.l.passwordField, text: $password).textFieldStyle(.roundedBorder)
                .textContentType(.password).disabled(busy)
            if registering {
                SecureField(OnlineText.l.confirmPasswordField(ServerPasswordPolicy.lengthDescription), text: $confirmation).textFieldStyle(.roundedBorder)
                DisclosureGroup(OnlineText.l.linkLegacyAccount) {
                    Toggle(OnlineText.l.useLinkCode, isOn: $linking).disabled(busy)
                    if linking {
                    SecureField(OnlineText.l.linkCodeField, text: $linkCode).textFieldStyle(.roundedBorder)
                    Text(OnlineText.l.linkCodeNote)
                        .font(Typography.label).foregroundStyle(.secondary)
                    }
                }
            }
            HStack {
                Button(registering ? OnlineText.l.createAndConnect : OnlineText.l.logIn) { authenticate() }
                    .buttonStyle(.borderedProminent)
                    .disabled(actionsDisabled || email.isEmpty || password.isEmpty)
            }
            Text(OnlineText.l.sameEmailNote)
                .font(Typography.label).foregroundStyle(.secondary)
            Text(OnlineText.l.localSessionNote)
                .font(Typography.label).foregroundStyle(.secondary)
            if offersLegacyImport && !registering {
                Divider()
                Button(OnlineText.l.importLegacySignIn) { importLegacySignIn() }
                    .disabled(actionsDisabled)
                Text(OnlineText.l.importLegacySignInNote)
                    .font(Typography.label).foregroundStyle(.secondary)
            }
            }
            .padding(6)
        }
    }

    private var security: some View {
        VStack(alignment: .leading, spacing: 16) {
            if credential != nil {
                GroupBox(OnlineText.l.signInSessions) {
                HStack {
                    Button(OnlineText.l.logOutThisDevice) { logout(all: false) }
                    Button(OnlineText.l.logOutAllDevices) { logout(all: true) }
                }.disabled(actionsDisabled || unconfirmed)
                    .padding(6).frame(maxWidth: .infinity, alignment: .leading)
                }
                SecureField(OnlineText.l.currentPasswordForChanges, text: $password)
                    .textFieldStyle(.roundedBorder).disabled(busy)
                DisclosureGroup(OnlineText.l.changePassword) {
                    Text(OnlineText.l.changePasswordNote)
                        .font(Typography.label).foregroundStyle(.secondary)
                    SecureField(OnlineText.l.newPasswordField(ServerPasswordPolicy.lengthDescription), text: $newPassword).textFieldStyle(.roundedBorder)
                    SecureField(OnlineText.l.confirmNewPassword, text: $newPasswordConfirmation).textFieldStyle(.roundedBorder)
                    Button(OnlineText.l.changePasswordAndSignOut) { changePassword() }
                        .disabled(actionsDisabled || password.isEmpty || unconfirmed)
                }
                GroupBox(OnlineText.l.recoveryCodeTitle) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(recoveryActive ? OnlineText.l.recoveryCodeActive : OnlineText.l.recoveryCodeSuggest)
                        Text(OnlineText.l.recoveryCodeWarning)
                            .font(Typography.label).foregroundStyle(.secondary)
                        Button(recoveryActive ? OnlineText.l.reissueRecoveryCode : OnlineText.l.issueRecoveryCode) { confirmingRecovery = true }
                            .disabled(actionsDisabled || password.isEmpty || unconfirmed)
                        if !recoveryCode.isEmpty {
                            Text(recoveryCode).font(.system(.body, design: .monospaced)).textSelection(.enabled)
                                .padding(10).background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
                            Button(OnlineText.l.savedItHide) { recoveryCode = "" }
                        }
                    }.padding(6).frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                Text(OnlineText.l.forgotPassword).font(.headline)
                Text(OnlineText.l.forgotPasswordNote)
                    .font(Typography.body).foregroundStyle(.secondary)
                TextField(OnlineText.l.emailField, text: $email).textFieldStyle(.roundedBorder)
                SecureField(OnlineText.l.savedRecoveryCode, text: $recoveryInput).textFieldStyle(.roundedBorder)
                SecureField(OnlineText.l.newPasswordField(ServerPasswordPolicy.lengthDescription), text: $newPassword).textFieldStyle(.roundedBorder)
                SecureField(OnlineText.l.confirmNewPassword, text: $newPasswordConfirmation).textFieldStyle(.roundedBorder)
                Button(OnlineText.l.resetPasswordAndSignOut) { recoverAccount() }
                    .disabled(actionsDisabled || recoveryInput.isEmpty)
            }
        }
    }

    private func saveConfiguration() {
        guard !enabled || credential != nil else {
            message = OnlineText.l.signInBeforeOnline
            return
        }
        guard !unconfirmed, wallet.remote?.busy != true else {
            message = OnlineText.l.syncPendingFirst
            return
        }
        let defaults = UserDefaults.standard
        defaults.set(enabled, forKey: "ppb.server.enabled")
        message = OnlineText.l.savedRestartToApply
        needsRestart = enabled != (wallet.remote != nil)
    }

    private var deviceList: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(OnlineText.l.signedInDevices).font(.headline)
            Text(OnlineText.l.signedInDevicesNote)
                .font(Typography.label).foregroundStyle(.secondary)
            Button(OnlineText.l.refresh) { refreshAccount() }.disabled(busy || credential == nil)
            if credential != nil {
                DisclosureGroup(OnlineText.l.tokenCollector) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(tokenPolicy.collector_device_id == nil ? OnlineText.l.tokenPolicyAll : OnlineText.l.tokenPolicySingle)
                        Text(OnlineText.l.tokenPolicyHint)
                            .font(Typography.label).foregroundStyle(.secondary)
                        SecureField(OnlineText.l.passwordForPolicy, text: $password).textFieldStyle(.roundedBorder)
                        HStack {
                            Button(OnlineText.l.onlyThisMac) { confirmingTokenPolicy = true }
                            Button(OnlineText.l.allDevicesSum) { confirmingTokenPolicy = false }
                        }.disabled(actionsDisabled || unconfirmed || password.isEmpty || !statusLoaded)
                    }.padding(.top, 8)
                }
            }
            if credential == nil { Text(OnlineText.l.signInOnConnectionTab) }
            else if statusLoaded && devices.isEmpty { Text(OnlineText.l.noSignedInDevices) }
            ForEach(devices) { device in
                GroupBox {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            TextField(OnlineText.l.deviceName, text: Binding(get: { deviceNames[device.id] ?? device.name },
                                set: { deviceNames[device.id] = $0 })).textFieldStyle(.roundedBorder)
                            if device.current { Text(OnlineText.l.thisDevice).font(Typography.label).foregroundStyle(.secondary) }
                        }
                        Text(OnlineText.l.lastSignIn(dateText(device.last_login))).font(Typography.label).foregroundStyle(.secondary)
                        HStack {
                            Button(OnlineText.l.saveName) { rename(device) }
                            Spacer()
                            Button(OnlineText.l.disconnectEllipsis, role: .destructive) { confirmingRevoke = device }
                        }.disabled(actionsDisabled || unconfirmed)
                    }.padding(6)
                }
            }
        }
    }

    private var serverStatus: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(OnlineText.l.backgroundJobs).font(.headline)
                Spacer()
                Button(OnlineText.l.refresh) { refreshAccount() }.disabled(busy || credential == nil)
            }
            if credential == nil { Text(OnlineText.l.signInForServerStatus) }
            ForEach(jobs) { job in
                GroupBox {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(job.title).font(.headline)
                            Spacer()
                            Label(job.label, systemImage: job.needsAttention ? "exclamationmark.triangle" : "clock")
                                .foregroundStyle(job.needsAttention ? Color.orange : Color.secondary)
                        }
                        Text(OnlineText.l.lastSuccess(dateText(job.last_success))).font(Typography.label)
                        Text(OnlineText.l.nextRun(dateText(job.next_run))).font(Typography.label).foregroundStyle(.secondary)
                        if let error = job.error { Text(error).font(Typography.body).foregroundStyle(.orange) }
                    }.padding(6).frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            Text(OnlineText.l.serverJobsNote)
                .font(Typography.label).foregroundStyle(.secondary)
            DisclosureGroup(OnlineText.l.diagnostics) {
                Text(OnlineText.l.tokenTrustNote)
                ForEach(latencies.keys.sorted(), id: \.self) { key in
                    if let metric = latencies[key] {
                        Text(OnlineText.l.latencyLine(Self.latencyName(key), p50: metric.p50_ms, p95: metric.p95_ms, samples: metric.samples))
                    }
                }
                Text(OnlineText.l.latencyNote)
                if let credential { Text(OnlineText.l.accountID(credential.account_id.uuidString)).textSelection(.enabled) }
                Text(address).textSelection(.enabled)
            }.font(Typography.label)
        }
    }

    private func dateText(_ value: Int?) -> String {
        guard let value, value > 0 else { return OnlineText.l.noRecord }
        return Date(timeIntervalSince1970: Double(value)).formatted(date: .abbreviated, time: .shortened)
    }

    private func clearSecrets() {
        password = ""; confirmation = ""; newPassword = ""; newPasswordConfirmation = ""
        linkCode = ""; recoveryCode = ""; recoveryInput = ""
    }

    private func refreshAccount() {
        guard !busy, let credential else { return }
        busy = true; statusLoaded = false
        Task {
            defer { busy = false }
            do {
                let url = try validatedURL()
                if section == .devices {
                    let data = try await ServerAuthentication.request(url: url, path: "auth/devices", credential: credential, method: "GET")
                    devices = try JSONDecoder().decode(AccountDeviceList.self, from: data).items
                    deviceNames = [:]
                    let policyData = try await ServerAuthentication.request(url: url, path: "auth/token-policy", credential: credential, method: "GET")
                    tokenPolicy = try JSONDecoder().decode(AccountTokenPolicy.self, from: policyData)
                } else if section == .server {
                    let data = try await ServerAuthentication.request(url: url, path: "v1/server/status", credential: credential, method: "GET")
                    let status = try JSONDecoder().decode(AccountJobList.self, from: data)
                    jobs = status.jobs; latencies = status.latency_worker_recent ?? [:]
                } else if section == .security {
                    let data = try await ServerAuthentication.request(url: url, path: "auth/recovery", credential: credential, method: "GET")
                    recoveryActive = try JSONDecoder().decode(AccountRecoveryStatus.self, from: data).active
                }
                statusLoaded = true; message = nil
            } catch {
                devices = []; jobs = []; message = OnlineText.message(for: error)
                if error.localizedDescription == ServerAuthentication.loginRequired { self.credential = nil; clearSecrets() }
            }
        }
    }

    private func rename(_ device: AccountDevice) {
        let name = (deviceNames[device.id] ?? device.name).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, name.unicodeScalars.count <= 80 else { message = OnlineText.l.deviceNameLength; return }
        accountAction(path: "auth/devices/\(device.id)/rename", body: ["name": name])
    }

    private func revoke(_ device: AccountDevice) {
        if device.current { logout(all: false); return }
        accountAction(path: "auth/devices/\(device.id)/revoke")
    }

    private func accountAction(path: String, body: [String: String] = [:]) {
        guard !actionsDisabled, !unconfirmed, let credential else { return }
        busy = true
        Task {
            do {
                _ = try await ServerAuthentication.request(url: validatedURL(), path: path, body: body, credential: credential)
                busy = false; refreshAccount()
            } catch { busy = false; message = OnlineText.message(for: error) }
        }
    }

    private func issueRecovery() {
        guard !actionsDisabled, !unconfirmed, let credential else { return }
        busy = true; recoveryCode = ""
        Task {
            defer { busy = false; password = "" }
            do {
                let data = try await ServerAuthentication.request(url: validatedURL(), path: "auth/recovery", body: ["password": password], credential: credential)
                recoveryCode = try JSONDecoder().decode(AccountIssuedRecovery.self, from: data).code
                recoveryActive = true; message = OnlineText.l.recoveryIssued
            } catch { message = OnlineText.l.recoveryIssueFailed(OnlineText.message(for: error)) }
        }
    }

    private func updateTokenPolicy(single: Bool) {
        guard !actionsDisabled, !unconfirmed, let credential else { return }
        busy = true
        Task {
            defer { busy = false; password = "" }
            do {
                let body: [String: Any] = ["password": password, "expected_version": tokenPolicy.version,
                    "collector_device_id": single ? credential.device_id.uuidString as Any : NSNull()]
                let data = try await ServerAuthentication.request(url: validatedURL(), path: "auth/token-policy", body: body, credential: credential)
                tokenPolicy = try JSONDecoder().decode(AccountTokenPolicy.self, from: data)
                message = OnlineText.l.tokenPolicyChanged
            } catch { message = OnlineText.l.tokenPolicyFailed(OnlineText.message(for: error)) }
        }
    }

    private func recoverAccount() {
        // Password recovery must remain available when an expired login has a pending draw.
        // The pending resource request is preserved and replayed after same-account login.
        guard !actionsDisabled else { return }
        guard ServerPasswordPolicy.accepts(newPassword), newPassword == newPasswordConfirmation else {
            message = OnlineText.l.newPasswordTwice(ServerPasswordPolicy.lengthDescription); return
        }
        busy = true
        Task {
            defer { busy = false; clearSecrets() }
            do {
                _ = try await ServerAuthentication.request(url: validatedURL(), path: "auth/recover",
                    body: ["email": email, "code": recoveryInput, "new_password": newPassword])
                section = .connection; message = OnlineText.l.passwordResetDone
            } catch { message = OnlineText.l.passwordResetFailed(OnlineText.message(for: error)) }
        }
    }

    private func validatedURL() throws -> URL {
        guard let url = URL(string: address.trimmingCharacters(in: .whitespacesAndNewlines)),
              RemoteGameConfiguration.validURL(url) else {
            throw ServerLoginFailure(message: OnlineText.l.checkServerAddress)
        }
        return url
    }

    private func configuration(for credential: ServerCredential) throws -> RemoteGameConfiguration {
        .init(baseURL: try validatedURL(), accountID: credential.account_id, deviceID: credential.device_id)
    }

    private func loadSavedLogin() {
        guard let account = UUID(uuidString: UserDefaults.standard.string(forKey: "ppb.server.account") ?? ""),
              let url = try? validatedURL() else { return }
        let config = RemoteGameConfiguration(baseURL: url, accountID: account, deviceID: ServerAuthentication.deviceID())
        // Opening this form reads only the local session file.
        Task {
            let saved = await Task.detached(priority: .userInitiated) { try? ServerCredentialStore.load(config) }.value
            if let saved { credential = saved; email = saved.email }
            offersLegacyImport = saved == nil
        }
    }

    private func importLegacySignIn() {
        guard !actionsDisabled,
              let account = UUID(uuidString: UserDefaults.standard.string(forKey: "ppb.server.account") ?? ""),
              let url = try? validatedURL() else { return }
        let config = RemoteGameConfiguration(baseURL: url, accountID: account, deviceID: ServerAuthentication.deviceID())
        if unconfirmed, wallet.remote?.configuration.storageKey != config.storageKey {
            message = OnlineText.l.signInToPendingAccount
            return
        }
        busy = true
        Task {
            defer { busy = false }
            do {
                // This explicit button is the only remaining server-session Keychain read.
                guard let saved = try await Task.detached(priority: .userInitiated, operation: {
                    try ServerCredentialStore.importLegacy(config)
                }).value else {
                    message = OnlineText.l.credentialUnreadable
                    return
                }
                credential = saved
                email = saved.email
                offersLegacyImport = false
                if let remote = wallet.remote, remote.configuration.storageKey == config.storageKey {
                    remote.forgetCredential()
                    await remote.synchronize()
                    message = remote.error ?? OnlineText.l.signedInSynced
                } else {
                    message = OnlineText.l.signedInRestart
                    needsRestart = true
                }
            } catch { message = OnlineText.message(for: error) }
        }
    }

    private func authenticate() {
        guard !actionsDisabled else { return }
        if registering && (!ServerPasswordPolicy.accepts(password) || password != confirmation) {
            message = OnlineText.l.passwordTwice(ServerPasswordPolicy.lengthDescription)
            return
        }
        // 복사하며 붙은 앞뒤 공백 때문에 맞는 코드가 "만료됐거나 이미 쓴 코드" 로 거절되지 않게 한다.
        let code = linkCode.trimmingCharacters(in: .whitespacesAndNewlines)
        if registering && linking && code.isEmpty { message = OnlineText.l.linkCodeRequired; return }
        busy = true
        Task {
            defer { busy = false; password = ""; confirmation = ""; linkCode = "" }
            do {
                let url = try validatedURL()
                let result = try await ServerAuthentication.login(url: url, email: email, password: password,
                    register: registering, linkCode: registering && linking ? code : "",
                    deviceID: ServerAuthentication.deviceID())
                let config = RemoteGameConfiguration(baseURL: url, accountID: result.account_id, deviceID: result.device_id)
                if let remote = wallet.remote, unconfirmed,
                   remote.configuration.storageKey != config.storageKey {
                    // A new session was created but must not replace the account
                    // that owns the durable pending request.
                    _ = try? await ServerAuthentication.request(url: url, path: "auth/logout", credential: result)
                    throw ServerLoginFailure(message: OnlineText.l.signInToPendingAccount)
                }
                try ServerCredentialStore.save(result, configuration: config)
                credential = result
                let defaults = UserDefaults.standard
                defaults.set(url.absoluteString, forKey: "ppb.server.url")
                defaults.set(result.account_id.uuidString.lowercased(), forKey: "ppb.server.account")
                defaults.set(true, forKey: "ppb.server.enabled")
                enabled = true
                if let remote = wallet.remote, remote.configuration.storageKey == config.storageKey {
                    remote.forgetCredential()
                    await remote.synchronize()
                    message = OnlineText.l.signedInSynced
                } else {
                    // 다른 계정(새로 가입한 계정 포함)이나 처음 연결이다. 지갑과 온라인 창은 기동할 때
                    // 계정이 정해져서, 다시 시작하기 전까지는 로그아웃한 계정의 카드가 그대로 보였다.
                    // 실행 중에 갈아 끼우면 친구, 마켓, 알림 화면에 이전 계정 것이 남을 수 있어
                    // 바로 다시 시작하고 온라인 창을 연다.
                    message = OnlineText.l.signedInSwitching
                    if !AppRelauncher.relaunch(openingOnline: true) {
                        message = OnlineText.l.signedInRestart
                        needsRestart = true
                    }
                }
            } catch { message = OnlineText.message(for: error) }
        }
    }

    private func logout(all: Bool) {
        guard let credential, !actionsDisabled, !unconfirmed else { return }
        busy = true
        Task {
            defer { busy = false }
            do {
                try await ServerAuthentication.logout(configuration: configuration(for: credential), credential: credential, all: all)
                finishLogout()
            } catch { message = OnlineText.message(for: error) }
        }
    }

    private func changePassword() {
        guard let credential, !actionsDisabled, !unconfirmed else { return }
        guard ServerPasswordPolicy.accepts(newPassword), newPassword == newPasswordConfirmation else {
            message = OnlineText.l.newPasswordTwice(ServerPasswordPolicy.lengthDescription); return
        }
        busy = true
        Task {
            defer { busy = false; password = ""; newPassword = ""; newPasswordConfirmation = "" }
            do {
                try await ServerAuthentication.changePassword(configuration: configuration(for: credential), credential: credential,
                    current: password, new: newPassword)
                finishLogout()
                message = OnlineText.l.passwordChangedSignedOut
            } catch { message = OnlineText.message(for: error) }
        }
    }

    private func finishLogout() {
        credential = nil
        clearSecrets(); devices = []; jobs = []; recoveryActive = false
        wallet.remote?.invalidateAuthentication()
        // Keep online mode selected: logout must not silently switch wallets.
        message = OnlineText.l.signedOutNote
    }
}

extension OnlineSettingsView {
    /// 서버가 재는 구간 이름. 예전에는 규칙 실행이 아니면 모두 "DB 쓰기 대기"로 적어
    /// 명령 계산이나 저장 시간까지 잠금 대기처럼 보였다.
    static func latencyName(_ key: String) -> String { OnlineText.l.latencyName(key) }
}

struct AccountDevice: Decodable, Identifiable {
    let device_id: String
    let name: String
    let last_login: Int?
    let current: Bool
    var id: String { device_id }
}
struct AccountDeviceList: Decodable { let items: [AccountDevice] }
struct AccountRecoveryStatus: Decodable { let active: Bool }
struct AccountIssuedRecovery: Decodable { let code: String }
struct AccountJobList: Decodable { let jobs: [AccountJob]; let latency_worker_recent: [String: AccountLatency]? }
struct AccountLatency: Decodable { let samples: Int; let p50_ms: Double; let p95_ms: Double }
struct AccountTokenPolicy: Decodable { let collector_device_id: String?; let version: Int }
struct AccountJob: Decodable, Identifiable {
    let name: String
    let state: String
    let last_success: Int?
    let next_run: Int?
    let error: String?
    var id: String { name }
    @MainActor var title: String { OnlineText.l.serverJobName(name) }
    @MainActor var label: String { OnlineText.l.serverJobState(state) }
    var needsAttention: Bool { ["failed", "stale", "disabled"].contains(state) }
}

extension Notification.Name {
    /// 계정 창에서 닉네임을 바꿨다. 온라인 창이 열려 있으면 머리글과 프로필을 다시 읽는다.
    static let onlineProfileChanged = Notification.Name("ppb.online.profileChanged")
}
