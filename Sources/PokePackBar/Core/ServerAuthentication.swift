import Foundation
import Security

enum ServerPasswordPolicy {
    static let lengthRange = 8...128
    static var lengthDescription: String { L.current.passwordLengthRule }

    static func accepts(_ password: String) -> Bool {
        // Match Python's Unicode code-point count without altering the password.
        lengthRange.contains(password.unicodeScalars.count)
    }
}

struct ServerLoginFailure: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

/// Login passwords are transient form input. Only the server's revocable
/// session is persisted in this app's owner-only local file.
struct ServerCredential: Codable, Sendable {
    let access_token: String
    let account_id: UUID
    let device_id: UUID
    let email: String
    let expires_at: Int
}

enum ServerCredentialStore {
    static var directory: URL { AppEnv.supportDirectory.appendingPathComponent("server-credentials", isDirectory: true) }

    static func fileURL(_ configuration: RemoteGameConfiguration, root: URL = directory) -> URL {
        root.appendingPathComponent(configuration.storageKey + ".json")
    }

    /// Automatic startup/account reads use files only, including missing or damaged files.
    static func load(_ configuration: RemoteGameConfiguration, root: URL = directory) throws -> ServerCredential? {
        let data: Data
        do { data = try Data(contentsOf: fileURL(configuration, root: root)) }
        catch CocoaError.fileReadNoSuchFile { return nil }
        catch { throw ServerLoginFailure(message: L.current.credentialUnreadable) }
        guard let credential = try? JSONDecoder().decode(ServerCredential.self, from: data) else {
            throw ServerLoginFailure(message: L.current.credentialUnreadable)
        }
        try validate(credential, configuration: configuration)
        return credential
    }

    private static func validate(_ credential: ServerCredential, configuration: RemoteGameConfiguration) throws {
        guard credential.account_id == configuration.accountID,
              credential.device_id == configuration.deviceID, !credential.access_token.isEmpty else {
            throw ServerLoginFailure(message: L.current.credentialMismatch)
        }
    }

    static func save(_ credential: ServerCredential, configuration: RemoteGameConfiguration, root: URL = directory) throws {
        try validate(credential, configuration: configuration)
        let data = try JSONEncoder().encode(credential)
        let files = FileManager.default
        do {
            // The private directory also protects the temporary atomic-write file.
            try files.createDirectory(at: root, withIntermediateDirectories: true,
                                      attributes: [.posixPermissions: 0o700])
            try files.setAttributes([.posixPermissions: 0o700], ofItemAtPath: root.path)
            let url = fileURL(configuration, root: root)
            try data.write(to: url, options: .atomic)
            try files.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
        } catch {
            throw ServerLoginFailure(message: L.current.credentialSaveFailed)
        }
    }

    static func remove(_ configuration: RemoteGameConfiguration, root: URL = directory) throws {
        do { try FileManager.default.removeItem(at: fileURL(configuration, root: root)) }
        catch CocoaError.fileNoSuchFile { return }
        catch { throw ServerLoginFailure(message: L.current.credentialDeleteFailed) }
    }

    /// Called only by the explicit import action. Preserve the old item for rollback;
    /// ordinary loading/logout never consults it or resurrects it as a fallback.
    static func importLegacy(_ configuration: RemoteGameConfiguration, root: URL = directory,
        read: (RemoteGameConfiguration) throws -> ServerCredential? = LegacyServerCredentialStore.load
    ) throws -> ServerCredential? {
        if let saved = try load(configuration, root: root) { return saved }
        guard let legacy = try read(configuration) else { return nil }
        try save(legacy, configuration: configuration, root: root)
        return legacy
    }
}

private enum LegacyServerCredentialStore {
    static func load(_ configuration: RemoteGameConfiguration) throws -> ServerCredential? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "dev.local.pokepackbar.server-session",
            kSecAttrAccount as String: configuration.storageKey,
            kSecAttrSynchronizable as String: false,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: CFTypeRef?
        let status = KeychainReader.copyMatching(query, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = result as? Data,
              let credential = try? JSONDecoder().decode(ServerCredential.self, from: data) else {
            throw ServerLoginFailure(message: L.current.credentialUnreadable)
        }
        return credential
    }
}

/// No disk HTTP cache/cookies, and never forward credentials on redirects.
final class ServerTransport: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    static let delegate = ServerTransport()
    static let session = URLSession(configuration: .ephemeral, delegate: delegate, delegateQueue: nil)
    func urlSession(_ session: URLSession, task: URLSessionTask,
                    willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest,
                    completionHandler: @escaping @Sendable (URLRequest?) -> Void) {
        completionHandler(nil)
    }

    /// 모든 서버 요청이 지나는 길. 요청마다 번호(X-Request-ID)를 붙여 보내고, 서버는 같은 번호로
    /// 자기 로그를 남기고 응답에 돌려준다. 실패하거나 오래 걸린 요청은 앱 로그에 방법, 경로,
    /// 상태, 서버가 준 이유, 걸린 시간, 번호만 적는다. 토큰, 헤더, 본문, 쿼리는 적지 않는다.
    static func exchange(_ request: URLRequest) async throws -> ServerExchange {
        var request = request
        let requestID = UUID().uuidString.lowercased()
        request.setValue(requestID, forHTTPHeaderField: "X-Request-ID")
        let method = request.httpMethod ?? "GET"
        let path = request.url?.path ?? ""
        let started = Date()
        func elapsed() -> Int { Int(Date().timeIntervalSince(started) * 1000) }
        do {
            let (data, response) = try await session.data(for: request)
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            let failed = !(200..<300).contains(status) && status != 304
            if failed || elapsed() > slowMilliseconds {
                let reason = failed ? " \(detail(data) ?? "")" : " slow"
                AppLog.write("[server] \(method) \(path) -> \(status)\(reason), \(elapsed())ms, request \(requestID)")
            }
            return ServerExchange(data: data, status: status, requestID: requestID)
        } catch let error as URLError where error.code == .cancelled {
            throw error
        } catch {
            let code = (error as NSError).code
            AppLog.write("[server] \(method) \(path) -> no response (\((error as NSError).domain) \(code)) \(error.localizedDescription), \(elapsed())ms, request \(requestID)")
            throw ServerUnreachable(reason: error.localizedDescription, requestID: requestID, status: nil)
        }
    }

    /// 이보다 오래 걸리면 성공해도 적는다. 타임아웃 직전까지 끌다 실패하는 요청을 미리 본다.
    private static let slowMilliseconds = 8_000

    /// 서버가 준 이유. 서버의 detail 은 정해진 코드 문자열이고, 입력 검증 실패는 필드 위치만 온다.
    static func detail(_ data: Data) -> String? {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        if let text = object["detail"] as? String { return String(text.prefix(120)) }
        if let entries = object["detail"] as? [[String: Any]] {
            let fields = entries.compactMap { ($0["loc"] as? [Any])?.map { "\($0)" }.joined(separator: ".") }
            return String("invalid \(fields.joined(separator: ", "))".prefix(120))
        }
        return nil
    }
}

/// 서버와 주고받은 한 번. `requestID` 는 서버 로그의 request_id 와 같다.
struct ServerExchange: Sendable {
    let data: Data
    let status: Int
    let requestID: String
}

/// 화면에 실패를 보여 줄 때 서버 로그와 맞춰 볼 수 있는 실패. 응답이 없었으면 `status` 가 비어 있다.
protocol ServerTraceable: Error {
    var requestID: String? { get }
    var status: Int? { get }
}

/// 서버까지 닿지 못했거나 응답을 받지 못한 요청.
struct ServerUnreachable: LocalizedError, ServerTraceable {
    let reason: String
    let requestID: String?
    let status: Int?
    var errorDescription: String? { L.current.serverUnreachable(reason) }
}

@MainActor
enum ServerAuthentication {
    static func deviceID() -> UUID {
        if let value = UUID(uuidString: UserDefaults.standard.string(forKey: "ppb.server.device") ?? "") {
            return value
        }
        let value = UUID()
        UserDefaults.standard.set(value.uuidString, forKey: "ppb.server.device")
        return value
    }

    static func login(url: URL, email: String, password: String, register: Bool,
                      linkCode: String = "", deviceID: UUID) async throws -> ServerCredential {
        var body = ["email": email, "password": password, "device_id": deviceID.uuidString]
        body["device_name"] = String((Host.current().localizedName ?? "Mac").prefix(60))
        if register && !linkCode.isEmpty { body["link_code"] = linkCode }
        let data = try await request(url: url, path: register ? "auth/register" : "auth/login", body: body)
        let credential = try JSONDecoder().decode(ServerCredential.self, from: data)
        guard credential.device_id == deviceID, !credential.access_token.isEmpty else {
            throw ServerLoginFailure(message: L.current.loginDeviceMismatch)
        }
        return credential
    }

    static func logout(configuration: RemoteGameConfiguration, credential: ServerCredential,
                       all: Bool = false) async throws {
        do {
            _ = try await request(url: configuration.baseURL, path: all ? "auth/logout-all" : "auth/logout",
                                  credential: credential)
        } catch let error as ServerLoginFailure where error.message == loginRequired {
            // An expired/revoked session cannot be used again; clear local credentials.
        }
        try ServerCredentialStore.remove(configuration)
    }

    static func changePassword(configuration: RemoteGameConfiguration, credential: ServerCredential,
                               current: String, new: String) async throws {
        _ = try await request(url: configuration.baseURL, path: "auth/change-password",
            body: ["current_password": current, "new_password": new], credential: credential)
        try ServerCredentialStore.remove(configuration)
    }

    nonisolated static var loginRequired: String { L.current.loginRequiredMessage }

    static func request(url: URL, path: String, body: [String: Any] = [:],
                        credential: ServerCredential? = nil, method: String = "POST") async throws -> Data {
        guard RemoteGameConfiguration.validURL(url) else {
            throw ServerLoginFailure(message: L.current.remoteNeedsHTTPS)
        }
        var request = URLRequest(url: url.appendingPathComponent(path), cachePolicy: .reloadIgnoringLocalCacheData)
        request.httpMethod = method
        request.timeoutInterval = 30
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if method != "GET" { request.httpBody = try JSONSerialization.data(withJSONObject: body) }
        if let credential {
            request.setValue("Bearer \(credential.access_token)", forHTTPHeaderField: "Authorization")
            request.setValue(credential.device_id.uuidString, forHTTPHeaderField: "X-PPB-Device-ID")
        }
        if let gateway = AppEnv.value("PPB_GATEWAY_KEY"), !gateway.isEmpty {
            request.setValue(gateway, forHTTPHeaderField: "X-PPB-Gateway-Key")
        }
        let reply = try await ServerTransport.exchange(request)
        let data = reply.data, status = reply.status
        guard (200..<300).contains(status) else {
            let detail = ServerTransport.detail(data)
            let message: String
            switch detail {
            case "invalid_credentials": message = L.current.invalidCredentials
            case "invalid_recovery": message = L.current.invalidRecovery
            case "device_not_found": message = L.current.deviceListChanged
            case "login_required": message = loginRequired
            case "link_code_invalid": message = L.current.linkCodeInvalid
            case "registration_unavailable": message = L.current.registrationUnavailable
            case "registration_requires_link_code": message = L.current.registrationNeedsCode
            case "too_many_attempts": message = L.current.tooManyAttempts
            default:
                message = status == 422 ? L.current.checkEmailAndLength(ServerPasswordPolicy.lengthDescription)
                    : L.current.authServerStatus(status, request: String(reply.requestID.prefix(8)))
            }
            throw ServerLoginFailure(message: message)
        }
        return data
    }
}
